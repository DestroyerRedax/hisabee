import 'package:sqflite/sqflite.dart';
import '../../core/result/result.dart';
import '../../domain/entities/reminder.dart';
import '../../domain/repositories/reminder_repository.dart';
import '../database/app_database.dart';
import '../database/db_tables.dart';
import '../outbox/durable_outbox_writer.dart';

class ReminderRepositoryImpl implements ReminderRepository {
  final AppDatabase _appDatabase;
  final DurableOutboxWriter _outboxWriter;

  ReminderRepositoryImpl({
    required AppDatabase appDatabase,
    DurableOutboxWriter outboxWriter = const DurableOutboxWriter(),
  })  : _appDatabase = appDatabase,
        _outboxWriter = outboxWriter;

  @override
  Future<Result<void>> saveReminder(Reminder reminder) async {
    final err = Reminder.validate(
      title: reminder.title,
      note: reminder.note,
      scope: reminder.scope,
      repeatRule: reminder.repeatRule,
    );
    if (err != null) return Result.failure(err);

    try {
      final db = _appDatabase.database;
      await db.transaction((txn) async {
        final map = reminder.toMap();
        final idempotencyKey =
            'reminder:${reminder.id}:upsert:${reminder.updatedAt}';

        await _outboxWriter.executeAtomicMutation(
          txn: txn,
          entityType: 'reminder',
          entityId: reminder.id,
          operation: 'upsert',
          payload: map,
          idempotencyKey: idempotencyKey,
          createdAtMicroseconds: reminder.updatedAt,
          localMutation: (t) async {
            await t.insert(
              DbTables.reminders,
              map,
              conflictAlgorithm: ConflictAlgorithm.replace,
            );
          },
        );
      });
      return const Result.success(null);
    } catch (e, stack) {
      return Result.failure('Failed to save reminder: $e', e, stack);
    }
  }

  @override
  Future<Result<void>> updateState({
    required String id,
    required bool isFired,
    required bool isEnabled,
    required int updatedAtMicroseconds,
  }) async {
    try {
      final db = _appDatabase.database;
      await db.transaction((txn) async {
        final rows = await txn.query(
          DbTables.reminders,
          where: 'id = ? AND deleted_at IS NULL',
          whereArgs: [id],
        );
        if (rows.isEmpty) throw Exception('Reminder not found');

        final reminder = Reminder.fromMap(rows.first);
        final map = reminder.toMap()
          ..['is_fired'] = isFired ? 1 : 0
          ..['is_enabled'] = isEnabled ? 1 : 0
          ..['updated_at'] = updatedAtMicroseconds;

        await _outboxWriter.executeAtomicMutation(
          txn: txn,
          entityType: 'reminder',
          entityId: id,
          operation: 'upsert',
          payload: map,
          idempotencyKey: 'reminder:$id:upsert:$updatedAtMicroseconds',
          createdAtMicroseconds: updatedAtMicroseconds,
          localMutation: (t) async {
            await t.update(
              DbTables.reminders,
              {
                'is_fired': isFired ? 1 : 0,
                'is_enabled': isEnabled ? 1 : 0,
                'updated_at': updatedAtMicroseconds,
              },
              where: 'id = ?',
              whereArgs: [id],
            );
          },
        );
      });
      return const Result.success(null);
    } catch (e, stack) {
      return Result.failure('Failed to update reminder state: $e', e, stack);
    }
  }

  @override
  Future<Result<void>> softDeleteReminder(
      String id, int deletedAtMicroseconds) async {
    try {
      final db = _appDatabase.database;
      await db.transaction((txn) async {
        final rows = await txn.query(
          DbTables.reminders,
          where: 'id = ? AND deleted_at IS NULL',
          whereArgs: [id],
        );
        if (rows.isEmpty) throw Exception('Reminder not found');

        final rem = Reminder.fromMap(rows.first);
        final map = rem.toMap()
          ..['deleted_at'] = deletedAtMicroseconds
          ..['updated_at'] = deletedAtMicroseconds;

        await _outboxWriter.executeAtomicMutation(
          txn: txn,
          entityType: 'reminder',
          entityId: id,
          operation: 'delete',
          payload: map,
          idempotencyKey: 'reminder:$id:delete:$deletedAtMicroseconds',
          createdAtMicroseconds: deletedAtMicroseconds,
          localMutation: (t) async {
            await t.update(
              DbTables.reminders,
              {'deleted_at': deletedAtMicroseconds, 'updated_at': deletedAtMicroseconds},
              where: 'id = ?',
              whereArgs: [id],
            );
          },
        );
      });
      return const Result.success(null);
    } catch (e, stack) {
      return Result.failure('Failed to soft delete reminder: $e', e, stack);
    }
  }

  @override
  Future<Result<List<Reminder>>> getActiveReminders() async {
    try {
      final db = _appDatabase.database;
      final rows = await db.query(
        DbTables.reminders,
        where: 'deleted_at IS NULL',
        orderBy: 'created_at ASC, id ASC',
      );
      return Result.success(rows.map((r) => Reminder.fromMap(r)).toList());
    } catch (e, stack) {
      return Result.failure('Failed to query active reminders: $e', e, stack);
    }
  }
}
