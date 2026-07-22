import 'package:test/test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:hisabee/infrastructure/database/app_database.dart';

void main() {
  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  group('Database Schema & Foreign-Key Integrity Tests', () {
    late AppDatabase appDb;

    setUp(() async {
      appDb = AppDatabase();
      await appDb.initialize(path: inMemoryDatabasePath);
    });

    tearDown(() async {
      await appDb.close();
    });

    test('1. Foreign-key constraints are active PRAGMA check', () async {
      final db = appDb.database;
      final result = await db.rawQuery('PRAGMA foreign_keys;');
      expect(result.first.values.first, equals(1));
    });

    test('2. Foreign-key enforcement blocks inserting invalid foreign key', () async {
      final db = appDb.database;

      // Inserting business_entry referencing non-existent account_id should fail
      expect(
        () async {
          await db.insert('business_entries', {
            'id': 'entry_1',
            'account_id': 'non_existent_account',
            'direction': 'send',
            'name': 'Test Entry',
            'amount_minor': 1000,
            'note': 'Note',
            'local_date': '2026-07-22',
            'category': 'cash',
            'created_at': 100000,
            'updated_at': 100000,
          });
        },
        throwsA(isA<DatabaseException>()),
      );
    });
  });
}
