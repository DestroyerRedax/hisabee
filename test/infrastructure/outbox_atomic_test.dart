import 'package:test/test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:hisabee/core/money/money.dart';
import 'package:hisabee/domain/entities/personal_entry.dart';
import 'package:hisabee/infrastructure/database/app_database.dart';
import 'package:hisabee/infrastructure/repositories/personal_entry_repository_impl.dart';

void main() {
  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  group('Atomic Mutation & Outbox Enqueueing Tests', () {
    late AppDatabase appDb;
    late PersonalEntryRepositoryImpl repository;

    setUp(() async {
      appDb = AppDatabase();
      await appDb.initialize(path: inMemoryDatabasePath);
      repository = PersonalEntryRepositoryImpl(appDatabase: appDb);
    });

    tearDown(() async {
      await appDb.close();
    });

    test('1. Successful save inserts both local record and outbox entry atomically', () async {
      final entry = PersonalEntry(
        id: 'p_101',
        direction: 'receive',
        name: 'Ashrin',
        normalizedName: 'ashrin',
        amount: Money.fromMinorUnits(5000), // 50.00 Taka
        note: 'Initial deposit',
        localDate: '2026-07-22',
        category: 'Personal',
        createdAt: 1700000000000000,
        updatedAt: 1700000000000000,
      );

      final result = await repository.save(entry);
      expect(result.isSuccess, isTrue);

      final db = appDb.database;
      final localRows = await db.query('personal_entries', where: 'id = ?', whereArgs: ['p_101']);
      expect(localRows.length, equals(1));

      final outboxRows = await db.query('sync_outbox', where: 'entity_id = ?', whereArgs: ['p_101']);
      expect(outboxRows.length, equals(1));
      expect(outboxRows.first['operation'], equals('upsert'));
    });

    test('2. Duplicate idempotency key fails transaction and rolls back local mutation', () async {
      final db = appDb.database;

      // Pre-insert a sync_outbox record with fixed idempotency key
      const fixedKey = 'personal_entry:p_999:upsert:1000';
      await db.insert('sync_outbox', {
        'operation_id': 'op_1',
        'entity_type': 'personal_entry',
        'entity_id': 'p_999',
        'operation': 'upsert',
        'payload': '{}',
        'payload_version': 1,
        'idempotency_key': fixedKey,
        'created_at': 1000,
      });

      // Attempt saving entry with same timestamp -> generates duplicate idempotency key
      final entry = PersonalEntry(
        id: 'p_999',
        direction: 'receive',
        name: 'Test Duplicate',
        normalizedName: 'test duplicate',
        amount: Money.fromMinorUnits(1000),
        note: 'Dup note',
        localDate: '2026-07-22',
        category: 'Personal',
        createdAt: 1000,
        updatedAt: 1000,
      );

      final saveResult = await repository.save(entry);
      expect(saveResult.isFailure, isTrue);

      // Verify local mutation rolled back completely!
      final localRows = await db.query('personal_entries', where: 'id = ?', whereArgs: ['p_999']);
      expect(localRows, isEmpty);
    });
  });
}
