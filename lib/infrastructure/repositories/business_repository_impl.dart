import 'package:sqflite/sqflite.dart';
import '../../core/result/result.dart';
import '../../domain/entities/business_account.dart';
import '../../domain/entities/business_entry.dart';
import '../../domain/repositories/business_repository.dart';
import '../database/app_database.dart';
import '../database/db_tables.dart';
import '../outbox/durable_outbox_writer.dart';

class BusinessRepositoryImpl implements BusinessRepository {
  final AppDatabase _appDatabase;
  final DurableOutboxWriter _outboxWriter;

  BusinessRepositoryImpl({
    required AppDatabase appDatabase,
    DurableOutboxWriter outboxWriter = const DurableOutboxWriter(),
  })  : _appDatabase = appDatabase,
        _outboxWriter = outboxWriter;

  @override
  Future<Result<void>> saveAccount(BusinessAccount account) async {
    final err = BusinessAccount.validate(
      category: account.category,
      title: account.title,
    );
    if (err != null) return Result.failure(err);

    try {
      final db = _appDatabase.database;
      await db.transaction((txn) async {
        // Enforce "Only one active account of category cash may exist"
        if (account.category == 'cash' && account.deletedAt == null) {
          final existingCash = await txn.query(
            DbTables.businessAccounts,
            where: 'category = ? AND deleted_at IS NULL AND id != ?',
            whereArgs: ['cash', account.id],
          );
          if (existingCash.isNotEmpty) {
            throw Exception('Only one active account of category "cash" may exist');
          }
        }

        final map = account.toMap();
        final idempotencyKey =
            'business_account:${account.id}:upsert:${account.updatedAt}';

        await _outboxWriter.executeAtomicMutation(
          txn: txn,
          entityType: 'business_account',
          entityId: account.id,
          operation: 'upsert',
          payload: map,
          idempotencyKey: idempotencyKey,
          createdAtMicroseconds: account.updatedAt,
          localMutation: (t) async {
            await t.insert(
              DbTables.businessAccounts,
              map,
              conflictAlgorithm: ConflictAlgorithm.replace,
            );
          },
        );
      });
      return const Result.success(null);
    } catch (e, stack) {
      return Result.failure('Failed to save business account: $e', e, stack);
    }
  }

  @override
  Future<Result<void>> saveEntry(BusinessEntry entry) async {
    final err = BusinessEntry.validate(
      name: entry.name,
      direction: entry.direction,
      amount: entry.amount,
      note: entry.note,
      category: entry.category,
    );
    if (err != null) return Result.failure(err);

    try {
      final db = _appDatabase.database;
      await db.transaction((txn) async {
        // PRD Section 5.3: "The referenced account must be active when an entry is saved."
        final activeAccount = await txn.query(
          DbTables.businessAccounts,
          where: 'id = ? AND deleted_at IS NULL',
          whereArgs: [entry.accountId],
        );
        if (activeAccount.isEmpty) {
          throw Exception(
              'Cannot save entry: Referenced business account "${entry.accountId}" is not active or does not exist');
        }

        final map = entry.toMap();
        final idempotencyKey =
            'business_entry:${entry.id}:upsert:${entry.updatedAt}';

        await _outboxWriter.executeAtomicMutation(
          txn: txn,
          entityType: 'business_entry',
          entityId: entry.id,
          operation: 'upsert',
          payload: map,
          idempotencyKey: idempotencyKey,
          createdAtMicroseconds: entry.updatedAt,
          localMutation: (t) async {
            await t.insert(
              DbTables.businessEntries,
              map,
              conflictAlgorithm: ConflictAlgorithm.replace,
            );
          },
        );
      });
      return const Result.success(null);
    } catch (e, stack) {
      return Result.failure('Failed to save business entry: $e', e, stack);
    }
  }

  @override
  Future<Result<void>> softDeleteAccount(
      String accountId, int deletedAtMicroseconds) async {
    try {
      final db = _appDatabase.database;
      await db.transaction((txn) async {
        final accRows = await txn.query(
          DbTables.businessAccounts,
          where: 'id = ? AND deleted_at IS NULL',
          whereArgs: [accountId],
        );
        if (accRows.isEmpty) {
          throw Exception('Active business account not found for deletion');
        }

        final account = BusinessAccount.fromMap(accRows.first);
        final updatedAccMap = account.toMap()
          ..['deleted_at'] = deletedAtMicroseconds
          ..['updated_at'] = deletedAtMicroseconds;

        // Soft delete account
        await _outboxWriter.executeAtomicMutation(
          txn: txn,
          entityType: 'business_account',
          entityId: accountId,
          operation: 'delete',
          payload: updatedAccMap,
          idempotencyKey: 'business_account:$accountId:delete:$deletedAtMicroseconds',
          createdAtMicroseconds: deletedAtMicroseconds,
          localMutation: (t) async {
            await t.update(
              DbTables.businessAccounts,
              {'deleted_at': deletedAtMicroseconds, 'updated_at': deletedAtMicroseconds},
              where: 'id = ?',
              whereArgs: [accountId],
            );
          },
        );

        // PRD Section 5.3: "Deleting an active business account soft-deletes all its active entries in the same transaction"
        final linkedEntries = await txn.query(
          DbTables.businessEntries,
          where: 'account_id = ? AND deleted_at IS NULL',
          whereArgs: [accountId],
        );

        for (final entryRow in linkedEntries) {
          final entry = BusinessEntry.fromMap(entryRow);
          final updatedEntryMap = entry.toMap()
            ..['deleted_at'] = deletedAtMicroseconds
            ..['updated_at'] = deletedAtMicroseconds;

          await _outboxWriter.executeAtomicMutation(
            txn: txn,
            entityType: 'business_entry',
            entityId: entry.id,
            operation: 'delete',
            payload: updatedEntryMap,
            idempotencyKey: 'business_entry:${entry.id}:delete:$deletedAtMicroseconds',
            createdAtMicroseconds: deletedAtMicroseconds,
            localMutation: (t) async {
              await t.update(
                DbTables.businessEntries,
                {'deleted_at': deletedAtMicroseconds, 'updated_at': deletedAtMicroseconds},
                where: 'id = ?',
                whereArgs: [entry.id],
              );
            },
          );
        }
      });

      return const Result.success(null);
    } catch (e, stack) {
      return Result.failure('Failed to soft delete business account: $e', e, stack);
    }
  }

  @override
  Future<Result<void>> restoreAccount(
      String accountId, int updatedAtMicroseconds) async {
    try {
      final db = _appDatabase.database;
      await db.transaction((txn) async {
        final accRows = await txn.query(
          DbTables.businessAccounts,
          where: 'id = ? AND deleted_at IS NOT NULL',
          whereArgs: [accountId],
        );
        if (accRows.isEmpty) {
          throw Exception('Soft-deleted account not found');
        }

        final account = BusinessAccount.fromMap(accRows.first);
        if (account.category == 'cash') {
          final existingCash = await txn.query(
            DbTables.businessAccounts,
            where: 'category = ? AND deleted_at IS NULL AND id != ?',
            whereArgs: ['cash', accountId],
          );
          if (existingCash.isNotEmpty) {
            throw Exception('Cannot restore cash account: Another active cash account already exists');
          }
        }

        final restoredAccMap = account.toMap()
          ..['deleted_at'] = null
          ..['updated_at'] = updatedAtMicroseconds;

        await _outboxWriter.executeAtomicMutation(
          txn: txn,
          entityType: 'business_account',
          entityId: accountId,
          operation: 'upsert',
          payload: restoredAccMap,
          idempotencyKey: 'business_account:$accountId:upsert:$updatedAtMicroseconds',
          createdAtMicroseconds: updatedAtMicroseconds,
          localMutation: (t) async {
            await t.update(
              DbTables.businessAccounts,
              {'deleted_at': null, 'updated_at': updatedAtMicroseconds},
              where: 'id = ?',
              whereArgs: [accountId],
            );
          },
        );

        // PRD 5.3: Restoring an account restores its deleted linked entries and queues upsert work
        final deletedLinkedEntries = await txn.query(
          DbTables.businessEntries,
          where: 'account_id = ? AND deleted_at IS NOT NULL',
          whereArgs: [accountId],
        );

        for (final entryRow in deletedLinkedEntries) {
          final entry = BusinessEntry.fromMap(entryRow);
          final restoredEntryMap = entry.toMap()
            ..['deleted_at'] = null
            ..['updated_at'] = updatedAtMicroseconds;

          await _outboxWriter.executeAtomicMutation(
            txn: txn,
            entityType: 'business_entry',
            entityId: entry.id,
            operation: 'upsert',
            payload: restoredEntryMap,
            idempotencyKey: 'business_entry:${entry.id}:upsert:$updatedAtMicroseconds',
            createdAtMicroseconds: updatedAtMicroseconds,
            localMutation: (t) async {
              await t.update(
                DbTables.businessEntries,
                {'deleted_at': null, 'updated_at': updatedAtMicroseconds},
                where: 'id = ?',
                whereArgs: [entry.id],
              );
            },
          );
        }
      });
      return const Result.success(null);
    } catch (e, stack) {
      return Result.failure('Failed to restore business account: $e', e, stack);
    }
  }

  @override
  Future<Result<void>> softDeleteEntry(
      String entryId, int deletedAtMicroseconds) async {
    try {
      final db = _appDatabase.database;
      await db.transaction((txn) async {
        final rows = await txn.query(
          DbTables.businessEntries,
          where: 'id = ? AND deleted_at IS NULL',
          whereArgs: [entryId],
        );
        if (rows.isEmpty) throw Exception('Entry not found');

        final entry = BusinessEntry.fromMap(rows.first);
        final map = entry.toMap()
          ..['deleted_at'] = deletedAtMicroseconds
          ..['updated_at'] = deletedAtMicroseconds;

        await _outboxWriter.executeAtomicMutation(
          txn: txn,
          entityType: 'business_entry',
          entityId: entryId,
          operation: 'delete',
          payload: map,
          idempotencyKey: 'business_entry:$entryId:delete:$deletedAtMicroseconds',
          createdAtMicroseconds: deletedAtMicroseconds,
          localMutation: (t) async {
            await t.update(
              DbTables.businessEntries,
              {'deleted_at': deletedAtMicroseconds, 'updated_at': deletedAtMicroseconds},
              where: 'id = ?',
              whereArgs: [entryId],
            );
          },
        );
      });
      return const Result.success(null);
    } catch (e, stack) {
      return Result.failure('Failed to soft delete business entry: $e', e, stack);
    }
  }

  @override
  Future<Result<List<BusinessAccount>>> getActiveAccounts() async {
    try {
      final db = _appDatabase.database;
      final rows = await db.query(
        DbTables.businessAccounts,
        where: 'deleted_at IS NULL',
        orderBy: 'created_at ASC, id ASC',
      );
      return Result.success(rows.map((r) => BusinessAccount.fromMap(r)).toList());
    } catch (e, stack) {
      return Result.failure('Failed to query active accounts: $e', e, stack);
    }
  }

  @override
  Future<Result<List<BusinessEntry>>> getActiveEntries() async {
    try {
      final db = _appDatabase.database;
      final rows = await db.query(
        DbTables.businessEntries,
        where: 'deleted_at IS NULL',
        orderBy: 'created_at ASC, id ASC',
      );
      return Result.success(rows.map((r) => BusinessEntry.fromMap(r)).toList());
    } catch (e, stack) {
      return Result.failure('Failed to query active entries: $e', e, stack);
    }
  }
}
