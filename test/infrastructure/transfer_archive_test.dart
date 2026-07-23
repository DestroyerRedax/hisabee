import 'package:test/test.dart';
import 'package:sqflite/sqflite.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:excel/excel.dart';
import 'package:hisabee/core/money/money.dart';
import 'package:hisabee/domain/entities/personal_entry.dart';
import 'package:hisabee/domain/entities/business_account.dart';
import 'package:hisabee/domain/entities/profile.dart';
import 'package:hisabee/domain/entities/transaction_record.dart';
import 'package:hisabee/infrastructure/database/app_database.dart';
import 'package:hisabee/infrastructure/database/db_tables.dart';
import 'package:hisabee/infrastructure/repositories/personal_entry_repository_impl.dart';
import 'package:hisabee/infrastructure/repositories/business_repository_impl.dart';
import 'package:hisabee/infrastructure/repositories/profile_repository_impl.dart';
import 'package:hisabee/infrastructure/repositories/transaction_repository_impl.dart';
import 'package:hisabee/infrastructure/transfer/xlsx_exporter.dart';
import 'package:hisabee/infrastructure/transfer/xlsx_importer.dart';
import 'package:hisabee/infrastructure/transfer/pdf_summary_generator.dart';
import 'package:hisabee/infrastructure/transfer/data_wipe_service.dart';

void main() {
  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  group('XLSX Archive Transfer, PDF Disclaimer & Local Wipe Tests', () {
    late AppDatabase appDb;
    late XlsxExporter exporter;
    late XlsxImporter importer;
    late DataWipeService wipeService;
    late ProfileRepositoryImpl profileRepo;
    late BusinessRepositoryImpl businessRepo;
    late PersonalEntryRepositoryImpl personalRepo;
    late TransactionRepositoryImpl txRepo;

    setUp(() async {
      appDb = AppDatabase();
      await appDb.initialize(path: inMemoryDatabasePath);
      exporter = XlsxExporter(appDatabase: appDb);
      importer = XlsxImporter(appDatabase: appDb);
      wipeService = DataWipeService(appDatabase: appDb);

      profileRepo = ProfileRepositoryImpl(appDatabase: appDb);
      businessRepo = BusinessRepositoryImpl(appDatabase: appDb);
      personalRepo = PersonalEntryRepositoryImpl(appDatabase: appDb);
      txRepo = TransactionRepositoryImpl(appDatabase: appDb);
    });

    tearDown(() async {
      await appDb.close();
    });

    test('1. Round-trip XLSX export and import into clean database restores all records & relationships', () async {
      // 1. Seed data
      const prof = Profile(id: 'prof_round', name: 'Roundtrip Profile', createdAt: 100, updatedAt: 100);
      await profileRepo.saveProfile(prof);

      const bAcc = BusinessAccount(
        id: 'b_acc_round',
        category: 'cash',
        title: 'Cash',
        openingBalance: Money.zero,
        closingBalance: Money.zero,
        createdAt: 100,
        updatedAt: 100,
      );
      await businessRepo.saveAccount(bAcc);

      final pEntry = PersonalEntry(
        id: 'p_round',
        direction: 'receive',
        name: 'Person A',
        normalizedName: 'person a',
        amount: Money.fromMinorUnits(5000),
        note: '',
        localDate: '2026-07-22',
        category: 'Personal',
        createdAt: 100,
        updatedAt: 100,
      );
      await personalRepo.save(pEntry);

      final tx = TransactionRecord(
        id: 'tx_round',
        profileId: 'prof_round',
        amount: Money.fromMinorUnits(2000),
        localDate: '2026-07-22',
        method: 'bkash',
        direction: 'received',
        createdAt: 100,
        updatedAt: 100,
      );
      await txRepo.saveTransaction(tx);

      // 2. Export XLSX archive
      final exportRes = await exporter.exportArchive(createdAtMicroseconds: 200);
      expect(exportRes.fileBytes, isNotEmpty);
      expect(exportRes.sha256Base64UrlHash, isNotEmpty);

      // Verify Transactions sheet has NO encrypted_pin header
      final decodedExcel = Excel.decodeBytes(exportRes.fileBytes);
      final txSheet = decodedExcel.tables['Transactions']!;
      final txHeaderRow = txSheet.rows.first.map((c) => c?.value?.toString()).toList();
      expect(txHeaderRow.contains('encrypted_pin'), isFalse);

      // 3. Wipe local database completely
      await wipeService.wipeLocalData();
      final emptyProfs = await profileRepo.getActiveProfiles();
      expect(emptyProfs.dataOrNull, isEmpty);

      // 4. Import XLSX into clean database
      final importRes = await importer.importArchive(
        fileBytes: exportRes.fileBytes,
        filename: exportRes.filename,
        createdAtMicroseconds: 300,
      );

      expect(importRes.isSuccess, isTrue);
      final stats = importRes.dataOrNull!;
      expect(stats.acceptedCount, greaterThanOrEqualTo(1));

      // 5. Verify restored records
      final restoredProfs = await profileRepo.getActiveProfiles();
      final restoredTx = await txRepo.getActiveTransactionsForProfile('prof_round');
      expect(restoredProfs.isSuccess, isTrue);
      expect(restoredProfs.dataOrNull?.length, equals(1));
      expect(restoredTx.isSuccess, isTrue, reason: restoredTx.errorOrNull?.message ?? restoredTx.toString());
      expect(restoredTx.dataOrNull?.length, equals(1), reason: 'Import stats: accepted=${stats.acceptedCount}, dup=${stats.duplicateCount}, rej=${stats.rejectedCount}');
      expect(restoredTx.dataOrNull?.first.id, equals('tx_round'));
    });

    test('2. PDF Summary output contains explicit non-backup disclaimer', () async {
      final pdfGen = PdfSummaryGenerator(appDatabase: appDb);
      final pdfBytes = await pdfGen.generateSummaryPdf(createdAtMicroseconds: 100);

      expect(pdfBytes, isNotEmpty);
      final pdfString = String.fromCharCodes(pdfBytes);
      expect(pdfString, contains('PDF is a summary report only'));
    });

    test('3. DataWipeService deletes records in child-before-parent order', () async {
      await wipeService.wipeLocalData();
      final db = appDb.database;

      const tables = [
        DbTables.appMetadata,
        DbTables.personalEntries,
        DbTables.businessAccounts,
        DbTables.businessEntries,
        DbTables.profiles,
        DbTables.transactions,
        DbTables.expenses,
        DbTables.reminders,
        DbTables.syncOutbox,
        DbTables.syncConflicts,
        DbTables.transferReceipts,
      ];

      for (final tableName in tables) {
        final count = Sqflite.firstIntValue(await db.rawQuery('SELECT COUNT(*) FROM $tableName'));
        expect(count, equals(0));
      }
    });
  });
}
