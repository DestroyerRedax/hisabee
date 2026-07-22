import 'package:sqflite/sqflite.dart';
import '../../core/result/result.dart';
import '../../domain/entities/personal_entry.dart';
import '../../domain/repositories/personal_entry_repository.dart';
import '../database/app_database.dart';
import '../database/db_tables.dart';
import '../outbox/durable_outbox_writer.dart';

/// SQLite implementation of [PersonalEntryRepository].
///
/// Ensures atomic local record mutations and durable outbox writes in a single
/// database transaction.
class PersonalEntryRepositoryImpl implements PersonalEntryRepository {
  final AppDatabase _appDatabase;
  final DurableOutboxWriter _outboxWriter;

  PersonalEntryRepositoryImpl({
    required AppDatabase appDatabase,
    DurableOutboxWriter outboxWriter = const DurableOutboxWriter(),
  })  : _appDatabase = appDatabase,
        _outboxWriter = outboxWriter;

  @override
  Future<Result<void>> save(PersonalEntry entry) async {
    final validationError = PersonalEntry.validate(
      name: entry.name,
      direction: entry.direction,
      amount: entry.amount,
      note: entry.note,
      category: entry.category,
      phone: entry.phone,
    );
    if (validationError != null) {
      return Result.failure(validationError);
    }

    try {
      final db = _appDatabase.database;
      await db.transaction((txn) async {
        final map = entry.toMap();
        final idempotencyKey =
            'personal_entry:${entry.id}:upsert:${entry.updatedAt}';

        await _outboxWriter.executeAtomicMutation(
          txn: txn,
          entityType: 'personal_entry',
          entityId: entry.id,
          operation: 'upsert',
          payload: map,
          idempotencyKey: idempotencyKey,
          createdAtMicroseconds: entry.updatedAt,
          localMutation: (t) async {
            await t.insert(
              DbTables.personalEntries,
              map,
              conflictAlgorithm: ConflictAlgorithm.replace,
            );
          },
        );
      });

      return const Result.success(null);
    } catch (e, stack) {
      return Result.failure('Failed to save personal entry: $e', e, stack);
    }
  }

  @override
  Future<Result<void>> softDelete(String id, int deletedAtMicroseconds) async {
    try {
      final db = _appDatabase.database;
      await db.transaction((txn) async {
        final existingRows = await txn.query(
          DbTables.personalEntries,
          where: 'id = ?',
          whereArgs: [id],
        );
        if (existingRows.isEmpty) {
          throw Exception('Personal entry not found for deletion: $id');
        }

        final existing = PersonalEntry.fromMap(existingRows.first);
        final updatedMap = existing.toMap()
          ..['deleted_at'] = deletedAtMicroseconds
          ..['updated_at'] = deletedAtMicroseconds;

        final idempotencyKey =
            'personal_entry:$id:delete:$deletedAtMicroseconds';

        await _outboxWriter.executeAtomicMutation(
          txn: txn,
          entityType: 'personal_entry',
          entityId: id,
          operation: 'delete',
          payload: updatedMap,
          idempotencyKey: idempotencyKey,
          createdAtMicroseconds: deletedAtMicroseconds,
          localMutation: (t) async {
            await t.update(
              DbTables.personalEntries,
              {
                'deleted_at': deletedAtMicroseconds,
                'updated_at': deletedAtMicroseconds,
              },
              where: 'id = ?',
              whereArgs: [id],
            );
          },
        );
      });

      return const Result.success(null);
    } catch (e, stack) {
      return Result.failure('Failed to delete personal entry: $e', e, stack);
    }
  }

  @override
  Future<Result<PersonalEntry?>> getById(String id) async {
    try {
      final db = _appDatabase.database;
      final rows = await db.query(
        DbTables.personalEntries,
        where: 'id = ? AND deleted_at IS NULL',
        whereArgs: [id],
      );
      if (rows.isEmpty) {
        return const Result.success(null);
      }
      return Result.success(PersonalEntry.fromMap(rows.first));
    } catch (e, stack) {
      return Result.failure('Failed to query personal entry: $e', e, stack);
    }
  }

  @override
  Future<Result<List<PersonalEntry>>> getActiveEntries() async {
    try {
      final db = _appDatabase.database;
      final rows = await db.query(
        DbTables.personalEntries,
        where: 'deleted_at IS NULL',
        orderBy: 'created_at ASC, id ASC',
      );
      final entries = rows.map((e) => PersonalEntry.fromMap(e)).toList();
      return Result.success(entries);
    } catch (e, stack) {
      return Result.failure('Failed to query active personal entries: $e', e, stack);
    }
  }
}
