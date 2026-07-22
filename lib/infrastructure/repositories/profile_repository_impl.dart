import 'package:sqflite/sqflite.dart';
import '../../core/result/result.dart';
import '../../domain/entities/profile.dart';
import '../../domain/entities/transaction_record.dart';
import '../../domain/repositories/profile_repository.dart';
import '../database/app_database.dart';
import '../database/db_tables.dart';
import '../outbox/durable_outbox_writer.dart';

class ProfileRepositoryImpl implements ProfileRepository {
  final AppDatabase _appDatabase;
  final DurableOutboxWriter _outboxWriter;

  ProfileRepositoryImpl({
    required AppDatabase appDatabase,
    DurableOutboxWriter outboxWriter = const DurableOutboxWriter(),
  })  : _appDatabase = appDatabase,
        _outboxWriter = outboxWriter;

  @override
  Future<Result<void>> saveProfile(Profile profile) async {
    final err = Profile.validate(name: profile.name);
    if (err != null) return Result.failure(err);

    try {
      final db = _appDatabase.database;
      await db.transaction((txn) async {
        final map = profile.toMap();
        final idempotencyKey =
            'profile:${profile.id}:upsert:${profile.updatedAt}';

        await _outboxWriter.executeAtomicMutation(
          txn: txn,
          entityType: 'profile',
          entityId: profile.id,
          operation: 'upsert',
          payload: map,
          idempotencyKey: idempotencyKey,
          createdAtMicroseconds: profile.updatedAt,
          localMutation: (t) async {
            await t.insert(
              DbTables.profiles,
              map,
              conflictAlgorithm: ConflictAlgorithm.replace,
            );
          },
        );

        // PRD Section 5.4: "The first saved profile becomes the active profile if no active profile exists."
        final activeIdMeta = await txn.query(
          DbTables.appMetadata,
          where: 'key = ?',
          whereArgs: ['active_profile_id'],
        );

        if (activeIdMeta.isEmpty) {
          await txn.insert(
            DbTables.appMetadata,
            {'key': 'active_profile_id', 'value': profile.id},
            conflictAlgorithm: ConflictAlgorithm.replace,
          );
        }
      });
      return const Result.success(null);
    } catch (e, stack) {
      return Result.failure('Failed to save profile: $e', e, stack);
    }
  }

  @override
  Future<Result<String?>> getActiveProfileId() async {
    try {
      final db = _appDatabase.database;
      final rows = await db.query(
        DbTables.appMetadata,
        where: 'key = ?',
        whereArgs: ['active_profile_id'],
      );
      if (rows.isEmpty) return const Result.success(null);
      return Result.success(rows.first['value'] as String);
    } catch (e, stack) {
      return Result.failure('Failed to get active profile ID: $e', e, stack);
    }
  }

  @override
  Future<Result<void>> setActiveProfileId(String profileId) async {
    try {
      final db = _appDatabase.database;
      final targetProfile = await db.query(
        DbTables.profiles,
        where: 'id = ? AND deleted_at IS NULL',
        whereArgs: [profileId],
      );
      if (targetProfile.isEmpty) {
        return Result.failure('Cannot set active profile: Profile "$profileId" is not active or does not exist');
      }

      await db.insert(
        DbTables.appMetadata,
        {'key': 'active_profile_id', 'value': profileId},
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
      return const Result.success(null);
    } catch (e, stack) {
      return Result.failure('Failed to set active profile ID: $e', e, stack);
    }
  }

  @override
  Future<Result<List<Profile>>> getActiveProfiles() async {
    try {
      final db = _appDatabase.database;
      final rows = await db.query(
        DbTables.profiles,
        where: 'deleted_at IS NULL',
        orderBy: 'created_at ASC, id ASC',
      );
      return Result.success(rows.map((r) => Profile.fromMap(r)).toList());
    } catch (e, stack) {
      return Result.failure('Failed to query active profiles: $e', e, stack);
    }
  }

  @override
  Future<Result<void>> softDeleteProfile({
    required String profileId,
    required int deletedAtMicroseconds,
    String? targetReassignProfileId,
  }) async {
    try {
      final db = _appDatabase.database;
      await db.transaction((txn) async {
        final activeProfiles = await txn.query(
          DbTables.profiles,
          where: 'deleted_at IS NULL',
        );

        // PRD Section 5.4: "At least one active profile must remain."
        if (activeProfiles.length <= 1) {
          throw Exception('Cannot delete the last active profile');
        }

        final profileToDelete = activeProfiles.firstWhere(
          (p) => p['id'] == profileId,
          orElse: () => throw Exception('Profile not found or already deleted: $profileId'),
        );

        // Check if transactions exist linked to this profile
        final activeTxRows = await txn.query(
          DbTables.transactions,
          where: 'profile_id = ? AND deleted_at IS NULL',
          whereArgs: [profileId],
        );

        if (activeTxRows.isNotEmpty) {
          // PRD Section 5.4: "If a profile with active transactions is deleted, all such transactions must first be reassigned to another valid active profile in the same transaction"
          if (targetReassignProfileId == null || targetReassignProfileId.isEmpty) {
            throw Exception(
                'Profile "$profileId" has active transactions. Target reassignment profile ID is required.');
          }

          final targetProfile = await txn.query(
            DbTables.profiles,
            where: 'id = ? AND deleted_at IS NULL',
            whereArgs: [targetReassignProfileId],
          );
          if (targetProfile.isEmpty || targetReassignProfileId == profileId) {
            throw Exception('Invalid target reassignment profile ID: $targetReassignProfileId');
          }

          // Reassign transactions and enqueue upsert outbox record for each reassigned transaction
          for (final txRow in activeTxRows) {
            final tx = TransactionRecord.fromMap(txRow);
            final reassignedTxMap = tx.toMap()
              ..['profile_id'] = targetReassignProfileId
              ..['updated_at'] = deletedAtMicroseconds;

            await _outboxWriter.executeAtomicMutation(
              txn: txn,
              entityType: 'transaction',
              entityId: tx.id,
              operation: 'upsert',
              payload: reassignedTxMap,
              idempotencyKey: 'transaction:${tx.id}:reassign:$deletedAtMicroseconds',
              createdAtMicroseconds: deletedAtMicroseconds,
              localMutation: (t) async {
                await t.update(
                  DbTables.transactions,
                  {'profile_id': targetReassignProfileId, 'updated_at': deletedAtMicroseconds},
                  where: 'id = ?',
                  whereArgs: [tx.id],
                );
              },
            );
          }
        }

        // Soft delete the profile
        final profile = Profile.fromMap(profileToDelete);
        final deletedProfileMap = profile.toMap()
          ..['deleted_at'] = deletedAtMicroseconds
          ..['updated_at'] = deletedAtMicroseconds;

        await _outboxWriter.executeAtomicMutation(
          txn: txn,
          entityType: 'profile',
          entityId: profileId,
          operation: 'delete',
          payload: deletedProfileMap,
          idempotencyKey: 'profile:$profileId:delete:$deletedAtMicroseconds',
          createdAtMicroseconds: deletedAtMicroseconds,
          localMutation: (t) async {
            await t.update(
              DbTables.profiles,
              {'deleted_at': deletedAtMicroseconds, 'updated_at': deletedAtMicroseconds},
              where: 'id = ?',
              whereArgs: [profileId],
            );
          },
        );

        // If the active profile was deleted, switch active profile to another active profile
        final activeIdMeta = await txn.query(
          DbTables.appMetadata,
          where: 'key = ?',
          whereArgs: ['active_profile_id'],
        );
        if (activeIdMeta.isNotEmpty && activeIdMeta.first['value'] == profileId) {
          final remainingProfile = activeProfiles.firstWhere((p) => p['id'] != profileId);
          await txn.insert(
            DbTables.appMetadata,
            {'key': 'active_profile_id', 'value': remainingProfile['id']},
            conflictAlgorithm: ConflictAlgorithm.replace,
          );
        }
      });

      return const Result.success(null);
    } catch (e, stack) {
      return Result.failure('Failed to soft delete profile: $e', e, stack);
    }
  }
}
