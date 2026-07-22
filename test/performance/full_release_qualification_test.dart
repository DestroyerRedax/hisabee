import 'package:test/test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:hisabee/core/money/money.dart';
import 'package:hisabee/domain/entities/personal_entry.dart';
import 'package:hisabee/domain/parser/transaction_message_parser.dart';
import 'package:hisabee/infrastructure/database/app_database.dart';
import 'package:hisabee/infrastructure/repositories/personal_entry_repository_impl.dart';
import 'package:hisabee/infrastructure/repositories/report_repository_impl.dart';
import 'package:hisabee/infrastructure/transfer/xlsx_exporter.dart';
import 'package:hisabee/infrastructure/transfer/xlsx_importer.dart';

void main() {
  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  group('Phase 06 — Release Performance Qualification & Benchmark Suite', () {
    late AppDatabase appDb;

    setUp(() async {
      appDb = AppDatabase();
      await appDb.initialize(path: inMemoryDatabasePath);
    });

    tearDown(() async {
      await appDb.close();
    });

    test('1. Database Cold Start Latency Qualification (< 500 ms budget)', () async {
      final sw = Stopwatch()..start();
      final dbTest = AppDatabase();
      await dbTest.initialize(path: inMemoryDatabasePath);
      sw.stop();

      print('Cold Start Latency: ${sw.elapsedMicroseconds} µs (${sw.elapsedMilliseconds} ms)');
      expect(sw.elapsedMilliseconds, lessThan(500));
      await dbTest.close();
    });

    test('2. Bulk Record Save Latency Qualification (100 atomic transactions < 1000 ms budget)', () async {
      final repo = PersonalEntryRepositoryImpl(appDatabase: appDb);
      final sw = Stopwatch()..start();

      for (int i = 0; i < 100; i++) {
        final entry = PersonalEntry(
          id: 'qual_$i',
          direction: 'receive',
          name: 'User $i',
          normalizedName: 'user $i',
          amount: Money.fromMinorUnits((i + 1) * 500),
          note: 'Qualification benchmark record $i',
          localDate: '2026-07-22',
          category: 'Cash',
          createdAt: 1700000000000000 + i,
          updatedAt: 1700000000000000 + i,
        );
        final res = await repo.save(entry);
        expect(res.isSuccess, isTrue);
      }
      sw.stop();

      print('100 Save Operations Total Time: ${sw.elapsedMilliseconds} ms');
      expect(sw.elapsedMilliseconds, lessThan(1000));
    });

    test('3. Unified Report Query Latency Qualification (< 100 ms budget)', () async {
      final reportRepo = ReportRepositoryImpl(appDatabase: appDb);
      final sw = Stopwatch()..start();

      final reportRes = await reportRepo.generateUnifiedReport(
        startDate: '2026-07-01',
        endDate: '2026-07-31',
      );
      sw.stop();

      expect(reportRes.isSuccess, isTrue);
      print('Unified Report Query Time: ${sw.elapsedMicroseconds} µs');
      expect(sw.elapsedMilliseconds, lessThan(100));
    });

    test('4. 200-Line Message Parsing Latency Qualification (< 150 ms budget)', () async {
      const parser = TransactionMessageParser();
      final lines = List.generate(200, (i) => 'Line $i: Received Tk ${i + 1}00 from 01712345678 on 2026-07-22');
      final bigText = lines.join('\n');

      final sw = Stopwatch()..start();
      final parseRes = parser.parse(bigText);
      sw.stop();

      print('200-Line Message Parsing Time: ${sw.elapsedMicroseconds} µs (${sw.elapsedMilliseconds} ms)');
      expect(parseRes.candidates, isNotEmpty);
      expect(sw.elapsedMilliseconds, lessThan(150));
    });

    test('5. XLSX Archive Export & Import Round-trip Latency Qualification (< 2000 ms budget)', () async {
      final exporter = XlsxExporter(appDatabase: appDb);
      final importer = XlsxImporter(appDatabase: appDb);

      final swExport = Stopwatch()..start();
      final exportRes = await exporter.exportArchive(createdAtMicroseconds: 1000);
      swExport.stop();
      print('XLSX Export Time: ${swExport.elapsedMilliseconds} ms');

      final swImport = Stopwatch()..start();
      final importRes = await importer.importArchive(
        fileBytes: exportRes.fileBytes,
        filename: exportRes.filename,
        createdAtMicroseconds: 2000,
      );
      swImport.stop();
      print('XLSX Import Time: ${swImport.elapsedMilliseconds} ms');

      expect(importRes.isSuccess, isTrue);
      expect(swExport.elapsedMilliseconds + swImport.elapsedMilliseconds, lessThan(2000));
    });
  });
}
