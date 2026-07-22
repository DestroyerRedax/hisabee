import 'package:sqflite/sqflite.dart';
import '../../core/result/result.dart';
import '../../domain/entities/transaction_record.dart';
import '../../domain/repositories/transaction_repository.dart';
import '../database/app_database.dart';
import '../database/db_tables.dart';
import '../outbox/durable_outbox_writer.dart';

class TransactionRepositoryImpl implements TransactionRepository {
  final AppDatabase _appDatabase;
  final DurableOutboxWriter _outboxWriter;

  TransactionRepositoryImpl({
    required AppDatabase appDatabase,
    DurableOutboxWriter outboxWriter = const DurableOutboxWriter(),
  })  : _appDatabase = appDatabase,
        _outboxWriter = outboxWriter;

  @override
  Future<Result<void>> saveTransaction(TransactionRecord transaction) async {
    final err = TransactionRecord.validate(
      method: transaction.method,
      direction: transaction.direction,
      amount: transaction.amount,
      number: transaction.number,
    );
    if (err != null) return Result.failure(err);

    try {
      final db = _appDatabase.database;
      await db.transaction((txn) async {
        // PRD Section 5.4: "The referenced profile must be active."
        final profileRows = await txn.query(
          DbTables.profiles,
          where: 'id = ? AND deleted_at IS NULL',
          whereArgs: [transaction.profileId],
        );
        if (profileRows.isEmpty) {
          throw Exception(
              'Cannot save transaction: Referenced profile "${transaction.profileId}" is not active or does not exist');
        }

        final map = transaction.toMap();
        final idempotencyKey =
            'transaction:${transaction.id}:upsert:${transaction.updatedAt}';

        await _outboxWriter.executeAtomicMutation(
          txn: txn,
          entityType: 'transaction',
          entityId: transaction.id,
          operation: 'upsert',
          payload: map,
          idempotencyKey: idempotencyKey,
          createdAtMicroseconds: transaction.updatedAt,
          localMutation: (t) async {
            await t.insert(
              DbTables.transactions,
              map,
              conflictAlgorithm: ConflictAlgorithm.replace,
            );
          },
        );
      });
      return const Result.success(null);
    } catch (e, stack) {
      return Result.failure('Failed to save transaction: $e', e, stack);
    }
  }

  @override
  Future<Result<void>> softDeleteTransaction(
      String id, int deletedAtMicroseconds) async {
    try {
      final db = _appDatabase.database;
      await db.transaction((txn) async {
        final rows = await txn.query(
          DbTables.transactions,
          where: 'id = ? AND deleted_at IS NULL',
          whereArgs: [id],
        );
        if (rows.isEmpty) throw Exception('Transaction record not found');

        final tx = TransactionRecord.fromMap(rows.first);
        final map = tx.toMap()
          ..['deleted_at'] = deletedAtMicroseconds
          ..['updated_at'] = deletedAtMicroseconds;

        await _outboxWriter.executeAtomicMutation(
          txn: txn,
          entityType: 'transaction',
          entityId: id,
          operation: 'delete',
          payload: map,
          idempotencyKey: 'transaction:$id:delete:$deletedAtMicroseconds',
          createdAtMicroseconds: deletedAtMicroseconds,
          localMutation: (t) async {
            await t.update(
              DbTables.transactions,
              {'deleted_at': deletedAtMicroseconds, 'updated_at': deletedAtMicroseconds},
              where: 'id = ?',
              whereArgs: [id],
            );
          },
        );
      });
      return const Result.success(null);
    } catch (e, stack) {
      return Result.failure('Failed to soft delete transaction: $e', e, stack);
    }
  }

  @override
  Future<Result<List<TransactionRecord>>> getActiveTransactionsForProfile(
      String profileId) async {
    try {
      final db = _appDatabase.database;
      final rows = await db.query(
        DbTables.transactions,
        where: 'profile_id = ? AND deleted_at IS NULL',
        whereArgs: [profileId],
        orderBy: 'created_at ASC, id ASC',
      );
      return Result.success(rows.map((r) => TransactionRecord.fromMap(r)).toList());
    } catch (e, stack) {
      return Result.failure('Failed to query active profile transactions: $e', e, stack);
    }
  }
}
