import 'dart:convert';
import 'package:sqflite/sqflite.dart';
import '../../core/result/result.dart';
import '../../core/utils/id_generator.dart';
import '../../domain/entities/sync_conflict_record.dart';
import '../database/app_database.dart';
import '../database/db_tables.dart';
import '../outbox/durable_outbox_writer.dart';

enum ConflictResolutionStrategy { keepLocal, keepCloud, duplicateAsNew }

class ConflictResolver {
  final AppDatabase appDatabase;
  final DurableOutboxWriter outboxWriter;

  const ConflictResolver({
    required this.appDatabase,
    this.outboxWriter = const DurableOutboxWriter(),
  });

  /// Detects and logs a sync conflict into `sync_conflicts` table.
  ///
  /// Prohibits automatic financial field merging.
  Future<SyncConflictRecord> logConflict({
    required String entityType,
    required String entityId,
    required Map<String, dynamic> localPayload,
    required Map<String, dynamic> remotePayload,
    required String reason,
    required int detectedAtMicroseconds,
  }) async {
    final conflictId = IdGenerator.generateId();
    final conflictRecord = SyncConflictRecord(
      id: conflictId,
      entityType: entityType,
      entityId: entityId,
      localPayload: jsonEncode(localPayload),
      remotePayload: jsonEncode(remotePayload),
      reason: reason,
      detectedAt: detectedAtMicroseconds,
    );

    final db = appDatabase.database;
    await db.insert(
      DbTables.syncConflicts,
      conflictRecord.toMap(),
    );

    return conflictRecord;
  }

  /// Resolves an existing conflict with one of the 3 explicit PRD strategies.
  Future<Result<void>> resolveConflict({
    required String conflictId,
    required ConflictResolutionStrategy strategy,
    required int resolvedAtMicroseconds,
  }) async {
    try {
      final db = appDatabase.database;
      await db.transaction((txn) async {
        final conflictRows = await txn.query(
          DbTables.syncConflicts,
          where: 'id = ?',
          whereArgs: [conflictId],
        );

        if (conflictRows.isEmpty) {
          throw Exception('Conflict record not found: $conflictId');
        }

        final conflict = SyncConflictRecord.fromMap(conflictRows.first);
        final localMap = jsonDecode(conflict.localPayload) as Map<String, dynamic>;
        final remoteMap = jsonDecode(conflict.remotePayload) as Map<String, dynamic>;

        final tableName = _tableNameForEntityType(conflict.entityType);

        switch (strategy) {
          case ConflictResolutionStrategy.keepLocal:
            // Re-queue local version to cloud
            final idempotencyKey =
                '${conflict.entityType}:${conflict.entityId}:upsert:$resolvedAtMicroseconds';
            await outboxWriter.executeAtomicMutation(
              txn: txn,
              entityType: conflict.entityType,
              entityId: conflict.entityId,
              operation: 'upsert',
              payload: localMap,
              idempotencyKey: idempotencyKey,
              createdAtMicroseconds: resolvedAtMicroseconds,
              localMutation: (t) async {
                await t.insert(tableName, localMap, conflictAlgorithm: ConflictAlgorithm.replace);
              },
            );
            break;

          case ConflictResolutionStrategy.keepCloud:
            // Apply remote version into SQLite
            await txn.insert(tableName, remoteMap, conflictAlgorithm: ConflictAlgorithm.replace);
            break;

          case ConflictResolutionStrategy.duplicateAsNew:
            // Keep local, and duplicate remote version as a new entity with fresh ID
            final newId = IdGenerator.generateId();
            final duplicatedRemoteMap = Map<String, dynamic>.from(remoteMap)
              ..['id'] = newId
              ..['updated_at'] = resolvedAtMicroseconds;

            await txn.insert(tableName, duplicatedRemoteMap, conflictAlgorithm: ConflictAlgorithm.replace);
            final idempotencyKey =
                '${conflict.entityType}:$newId:upsert:$resolvedAtMicroseconds';
            await outboxWriter.executeAtomicMutation(
              txn: txn,
              entityType: conflict.entityType,
              entityId: newId,
              operation: 'upsert',
              payload: duplicatedRemoteMap,
              idempotencyKey: idempotencyKey,
              createdAtMicroseconds: resolvedAtMicroseconds,
              localMutation: (_) async {},
            );
            break;
        }

        // Update conflict resolution audit
        await txn.update(
          DbTables.syncConflicts,
          {
            'resolution': strategy.name,
            'resolved_at': resolvedAtMicroseconds,
          },
          where: 'id = ?',
          whereArgs: [conflictId],
        );
      });

      return const Result.success(null);
    } catch (e, stack) {
      return Result.failure('Failed to resolve conflict: $e', e, stack);
    }
  }

  String _tableNameForEntityType(String entityType) {
    switch (entityType) {
      case 'personal_entry': return DbTables.personalEntries;
      case 'business_account': return DbTables.businessAccounts;
      case 'business_entry': return DbTables.businessEntries;
      case 'profile': return DbTables.profiles;
      case 'transaction': return DbTables.transactions;
      case 'expense': return DbTables.expenses;
      case 'reminder': return DbTables.reminders;
      default: throw ArgumentError('Unknown entity type: $entityType');
    }
  }
}
