import 'package:test/test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:hisabee/core/money/money.dart';
import 'package:hisabee/domain/entities/personal_entry.dart';
import 'package:hisabee/domain/entities/business_account.dart';
import 'package:hisabee/domain/entities/business_entry.dart';
import 'package:hisabee/domain/entities/transaction_record.dart';
import 'package:hisabee/domain/entities/expense.dart';
import 'package:hisabee/domain/entities/profile.dart';
import 'package:hisabee/infrastructure/database/app_database.dart';
import 'package:hisabee/infrastructure/repositories/personal_entry_repository_impl.dart';
import 'package:hisabee/infrastructure/repositories/business_repository_impl.dart';
import 'package:hisabee/infrastructure/repositories/profile_repository_impl.dart';
import 'package:hisabee/infrastructure/repositories/transaction_repository_impl.dart';
import 'package:hisabee/infrastructure/repositories/expense_repository_impl.dart';
import 'package:hisabee/infrastructure/repositories/report_repository_impl.dart';

void main() {
  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  group('Unified Report Engine & SQL Aggregation Fixtures', () {
    late AppDatabase appDb;
    late ReportRepositoryImpl reportRepo;
    late PersonalEntryRepositoryImpl personalRepo;
    late BusinessRepositoryImpl businessRepo;
    late ProfileRepositoryImpl profileRepo;
    late TransactionRepositoryImpl txRepo;
    late ExpenseRepositoryImpl expenseRepo;

    setUp(() async {
      appDb = AppDatabase();
      await appDb.initialize(path: inMemoryDatabasePath);
      reportRepo = ReportRepositoryImpl(appDatabase: appDb);
      personalRepo = PersonalEntryRepositoryImpl(appDatabase: appDb);
      businessRepo = BusinessRepositoryImpl(appDatabase: appDb);
      profileRepo = ProfileRepositoryImpl(appDatabase: appDb);
      txRepo = TransactionRepositoryImpl(appDatabase: appDb);
      expenseRepo = ExpenseRepositoryImpl(appDatabase: appDb);
    });

    tearDown(() async {
      await appDb.close();
    });

    test('1. Reversed date range rejects generation', () async {
      final res = await reportRepo.generateUnifiedReport(
        startDate: '2026-07-31',
        endDate: '2026-07-01', // Reversed!
      );
      expect(res.isFailure, isTrue);
      expect(res.errorMessageOrNull, contains('must be on or before'));
    });

    test('2. Aggregates Personal, Business, and Active Profile Transactions; EXCLUDES Expenses', () async {
      // 1. Setup Profile
      const p1 = Profile(id: 'prof_1', name: 'Main Profile', createdAt: 100, updatedAt: 100);
      await profileRepo.saveProfile(p1);

      // 2. Personal Entry (Received 100.00, Paid 30.00)
      await personalRepo.save(PersonalEntry(
        id: 'pe1',
        direction: 'receive',
        name: 'Salary',
        normalizedName: 'salary',
        amount: Money.fromMinorUnits(10000),
        note: '',
        localDate: '2026-07-15',
        category: 'Income',
        createdAt: 100,
        updatedAt: 100,
      ));

      await personalRepo.save(PersonalEntry(
        id: 'pe2',
        direction: 'pay',
        name: 'Loan Repay',
        normalizedName: 'loan repay',
        amount: Money.fromMinorUnits(3000),
        note: '',
        localDate: '2026-07-16',
        category: 'Loan',
        createdAt: 200,
        updatedAt: 200,
      ));

      // 3. Business Entries under active account (Received 200.00, Sent 50.00)
      const bAcc = BusinessAccount(
        id: 'b_acc1',
        category: 'cash',
        title: 'Cash',
        openingBalance: Money.zero,
        closingBalance: Money.zero,
        createdAt: 100,
        updatedAt: 100,
      );
      await businessRepo.saveAccount(bAcc);

      await businessRepo.saveEntry(BusinessEntry(
        id: 'be1',
        accountId: 'b_acc1',
        direction: 'receive',
        name: 'Sales A',
        amount: Money.fromMinorUnits(20000),
        note: '',
        localDate: '2026-07-15',
        category: 'Sales',
        createdAt: 100,
        updatedAt: 100,
      ));

      await businessRepo.saveEntry(BusinessEntry(
        id: 'be2',
        accountId: 'b_acc1',
        direction: 'send',
        name: 'Vendor B',
        amount: Money.fromMinorUnits(5000),
        note: '',
        localDate: '2026-07-16',
        category: 'Vendor',
        createdAt: 200,
        updatedAt: 200,
      ));

      // 4. Transaction of Active Profile (Received 50.00, Gave 10.00)
      await txRepo.saveTransaction(TransactionRecord(
        id: 'tx1',
        profileId: 'prof_1',
        amount: Money.fromMinorUnits(5000),
        localDate: '2026-07-15',
        method: 'bkash',
        direction: 'received',
        createdAt: 100,
        updatedAt: 100,
      ));

      await txRepo.saveTransaction(TransactionRecord(
        id: 'tx2',
        profileId: 'prof_1',
        number: '01712345678',
        amount: Money.fromMinorUnits(1000),
        localDate: '2026-07-16',
        method: 'bkash',
        direction: 'gave',
        createdAt: 200,
        updatedAt: 200,
      ));

      // 5. Add Expense (MUST BE EXCLUDED)
      await expenseRepo.saveExpense(Expense(
        id: 'ex1',
        amount: Money.fromMinorUnits(99900),
        category: 'Food',
        note: 'Big dinner',
        localDate: '2026-07-15',
        createdAt: 100,
        updatedAt: 100,
      ));

      final reportRes = await reportRepo.generateUnifiedReport(
        startDate: '2026-07-01',
        endDate: '2026-07-31',
      );

      expect(reportRes.isSuccess, isTrue);
      final report = reportRes.dataOrNull!;

      // Verify Personal Section
      expect(report.personalReceived.minorUnits, equals(10000));
      expect(report.personalPaid.minorUnits, equals(3000));
      expect(report.personalNet.minorUnits, equals(7000));
      expect(report.personalCount, equals(2));

      // Verify Business Section
      expect(report.businessReceived.minorUnits, equals(20000));
      expect(report.businessSent.minorUnits, equals(5000));
      expect(report.businessNet.minorUnits, equals(15000));
      expect(report.businessCount, equals(2));

      // Verify Transaction Section
      expect(report.transactionReceived.minorUnits, equals(5000));
      expect(report.transactionGave.minorUnits, equals(1000));
      expect(report.transactionNet.minorUnits, equals(4000));
      expect(report.transactionCount, equals(2));

      // Total Received = 10000 + 20000 + 5000 = 35000 (350.00 Taka)
      expect(report.totalReceived.minorUnits, equals(35000));

      // Total Paid = 3000 + 5000 + 1000 = 9000 (90.00 Taka)
      expect(report.totalPaid.minorUnits, equals(9000));

      // Overall Net = 35000 - 9000 = 26000 (260.00 Taka)
      expect(report.overallNet.minorUnits, equals(26000));

      // Total Record Count = 2 + 2 + 2 = 6 (Expense 999.00 Taka is EXCLUDED!)
      expect(report.totalRecordCount, equals(6));
    });
  });
}
