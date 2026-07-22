// ignore_for_file: avoid_print
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

  group('Performance Test Harness', () {
    test('1. Database startup and table creation latency baseline', () async {
      final stopwatch = Stopwatch()..start();
      final appDb = AppDatabase();
      await appDb.initialize(path: inMemoryDatabasePath);
      stopwatch.stop();

      print('Database startup latency: ${stopwatch.elapsedMicroseconds} µs (${stopwatch.elapsedMilliseconds} ms)');
      expect(stopwatch.elapsedMilliseconds, lessThan(500)); // Baseline startup under 500ms

      await appDb.close();
    });

    test('2. Atomic write latency baseline (100 mutations + outbox writes)', () async {
      final appDb = AppDatabase();
      await appDb.initialize(path: inMemoryDatabasePath);
      final repository = PersonalEntryRepositoryImpl(appDatabase: appDb);

      final stopwatch = Stopwatch()..start();
      for (int i = 0; i < 100; i++) {
        final entry = PersonalEntry(
          id: 'perf_$i',
          direction: 'receive',
          name: 'User $i',
          normalizedName: 'user $i',
          amount: Money.fromMinorUnits((i + 1) * 100),
          note: 'Performance measurement test item $i',
          localDate: '2026-07-22',
          category: 'Cash',
          createdAt: 1700000000000000 + i,
          updatedAt: 1700000000000000 + i,
        );
        final res = await repository.save(entry);
        expect(res.isSuccess, isTrue);
      }
      stopwatch.stop();

      final avgLatencyUs = stopwatch.elapsedMicroseconds / 100;
      print('100 Atomic Writes Total: ${stopwatch.elapsedMilliseconds} ms');
      print('Average Atomic Write Latency: $avgLatencyUs µs');

      final activeEntriesRes = await repository.getActiveEntries();
      expect(activeEntriesRes.dataOrNull?.length, equals(100));

      await appDb.close();
    });
  });
}
