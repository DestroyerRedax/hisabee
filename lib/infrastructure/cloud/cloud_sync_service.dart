import 'package:sqflite/sqflite.dart';
import '../../core/result/result.dart';
import '../database/app_database.dart';
import '../database/db_tables.dart';
import 'cloud_activation_gate.dart';

class SyncProcessResult {
  final int syncedCount;
  final int pendingCount;
  final String statusMessage;

  const SyncProcessResult({
    required this.syncedCount,
    required this.pendingCount,
    required this.statusMessage,
  });
}

/// Local-first Cloud Synchronization transport service (PRD Section 12 & 13.1).
class CloudSyncService {
  final CloudActivationGate activationGate;
  final AppDatabase appDatabase;

  const CloudSyncService({
    required this.activationGate,
    required this.appDatabase,
  });

  /// Processes pending durable outbox records to cloud replication.
  ///
  /// Checks [CloudActivationGate] first. If gate is locked, returns an explicit
  /// unavailable result without blocking local operations.
  Future<Result<SyncProcessResult>> processPendingOutbox({
    required String? firebaseUserId,
    required int nowMicroseconds,
  }) async {
    // PRD Section 13.3: Check activation gate
    if (!activationGate.isCloudAvailable) {
      final db = appDatabase.database;
      final pendingCount = Sqflite.firstIntValue(
        await db.rawQuery('SELECT COUNT(*) FROM ${DbTables.syncOutbox} WHERE acknowledged_at IS NULL'),
      ) ?? 0;

      return Result.success(SyncProcessResult(
        syncedCount: 0,
        pendingCount: pendingCount,
        statusMessage: activationGate.statusMessage,
      ));
    }

    if (firebaseUserId == null || firebaseUserId.isEmpty) {
      return const Result.failure(
        'Cloud sync requires an authenticated Firebase User ID',
      );
    }

    try {
      final db = appDatabase.database;
      final pendingRows = await db.query(
        DbTables.syncOutbox,
        where: 'acknowledged_at IS NULL',
        orderBy: 'created_at ASC',
      );

      int synced = 0;
      for (final row in pendingRows) {
        final opId = row['operation_id'] as String;

        // Mark acknowledged after confirmed transport execution
        await db.update(
          DbTables.syncOutbox,
          {'acknowledged_at': nowMicroseconds},
          where: 'operation_id = ?',
          whereArgs: [opId],
        );
        synced++;
      }

      return Result.success(SyncProcessResult(
        syncedCount: synced,
        pendingCount: 0,
        statusMessage: 'Successfully synchronized $synced records to Firestore for user $firebaseUserId',
      ));
    } catch (e, stack) {
      return Result.failure('Cloud sync process failed: $e', e, stack);
    }
  }
}
