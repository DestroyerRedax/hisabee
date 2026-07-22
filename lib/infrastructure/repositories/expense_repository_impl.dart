import 'package:sqflite/sqflite.dart';
import '../../core/result/result.dart';
import '../../domain/entities/expense.dart';
import '../../domain/repositories/expense_repository.dart';
import '../database/app_database.dart';
import '../database/db_tables.dart';
import '../outbox/durable_outbox_writer.dart';

class ExpenseRepositoryImpl implements ExpenseRepository {
  final AppDatabase _appDatabase;
  final DurableOutboxWriter _outboxWriter;

  ExpenseRepositoryImpl({
    required AppDatabase appDatabase,
    DurableOutboxWriter outboxWriter = const DurableOutboxWriter(),
  })  : _appDatabase = appDatabase,
        _outboxWriter = outboxWriter;

  @override
  Future<Result<void>> saveExpense(Expense expense) async {
    final err = Expense.validate(
      amount: expense.amount,
      category: expense.category,
      note: expense.note,
    );
    if (err != null) return Result.failure(err);

    try {
      final db = _appDatabase.database;
      await db.transaction((txn) async {
        final map = expense.toMap();
        final idempotencyKey =
            'expense:${expense.id}:upsert:${expense.updatedAt}';

        await _outboxWriter.executeAtomicMutation(
          txn: txn,
          entityType: 'expense',
          entityId: expense.id,
          operation: 'upsert',
          payload: map,
          idempotencyKey: idempotencyKey,
          createdAtMicroseconds: expense.updatedAt,
          localMutation: (t) async {
            await t.insert(
              DbTables.expenses,
              map,
              conflictAlgorithm: ConflictAlgorithm.replace,
            );
          },
        );
      });
      return const Result.success(null);
    } catch (e, stack) {
      return Result.failure('Failed to save expense: $e', e, stack);
    }
  }

  @override
  Future<Result<void>> softDeleteExpense(
      String id, int deletedAtMicroseconds) async {
    try {
      final db = _appDatabase.database;
      await db.transaction((txn) async {
        final rows = await txn.query(
          DbTables.expenses,
          where: 'id = ? AND deleted_at IS NULL',
          whereArgs: [id],
        );
        if (rows.isEmpty) throw Exception('Expense not found');

        final exp = Expense.fromMap(rows.first);
        final map = exp.toMap()
          ..['deleted_at'] = deletedAtMicroseconds
          ..['updated_at'] = deletedAtMicroseconds;

        await _outboxWriter.executeAtomicMutation(
          txn: txn,
          entityType: 'expense',
          entityId: id,
          operation: 'delete',
          payload: map,
          idempotencyKey: 'expense:$id:delete:$deletedAtMicroseconds',
          createdAtMicroseconds: deletedAtMicroseconds,
          localMutation: (t) async {
            await t.update(
              DbTables.expenses,
              {'deleted_at': deletedAtMicroseconds, 'updated_at': deletedAtMicroseconds},
              where: 'id = ?',
              whereArgs: [id],
            );
          },
        );
      });
      return const Result.success(null);
    } catch (e, stack) {
      return Result.failure('Failed to soft delete expense: $e', e, stack);
    }
  }

  @override
  Future<Result<List<Expense>>> getActiveExpenses() async {
    try {
      final db = _appDatabase.database;
      final rows = await db.query(
        DbTables.expenses,
        where: 'deleted_at IS NULL',
        orderBy: 'created_at ASC, id ASC',
      );
      return Result.success(rows.map((r) => Expense.fromMap(r)).toList());
    } catch (e, stack) {
      return Result.failure('Failed to query active expenses: $e', e, stack);
    }
  }
}
