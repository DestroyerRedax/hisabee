import 'package:test/test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:hisabee/core/money/money.dart';
import 'package:hisabee/domain/entities/business_account.dart';
import 'package:hisabee/domain/entities/business_entry.dart';
import 'package:hisabee/domain/entities/profile.dart';
import 'package:hisabee/domain/entities/transaction_record.dart';
import 'package:hisabee/domain/entities/expense.dart';
import 'package:hisabee/domain/entities/reminder.dart';
import 'package:hisabee/infrastructure/database/app_database.dart';
import 'package:hisabee/infrastructure/repositories/business_repository_impl.dart';
import 'package:hisabee/infrastructure/repositories/profile_repository_impl.dart';
import 'package:hisabee/infrastructure/repositories/transaction_repository_impl.dart';
import 'package:hisabee/infrastructure/repositories/expense_repository_impl.dart';
import 'package:hisabee/infrastructure/repositories/reminder_repository_impl.dart';

void main() {
  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  group('Accounting Domain Repositories Integration Tests', () {
    late AppDatabase appDb;
    late BusinessRepositoryImpl businessRepo;
    late ProfileRepositoryImpl profileRepo;
    late TransactionRepositoryImpl txRepo;
    late ExpenseRepositoryImpl expenseRepo;
    late ReminderRepositoryImpl reminderRepo;

    setUp(() async {
      appDb = AppDatabase();
      await appDb.initialize(path: inMemoryDatabasePath);
      businessRepo = BusinessRepositoryImpl(appDatabase: appDb);
      profileRepo = ProfileRepositoryImpl(appDatabase: appDb);
      txRepo = TransactionRepositoryImpl(appDatabase: appDb);
      expenseRepo = ExpenseRepositoryImpl(appDatabase: appDb);
      reminderRepo = ReminderRepositoryImpl(appDatabase: appDb);
    });

    tearDown(() async {
      await appDb.close();
    });

    test('1. Business: One active cash account constraint', () async {
      const cash1 = BusinessAccount(
        id: 'c1',
        category: 'cash',
        title: 'Cash Drawer 1',
        openingBalance: Money.zero,
        closingBalance: Money.zero,
        createdAt: 100,
        updatedAt: 100,
      );

      final saveRes1 = await businessRepo.saveAccount(cash1);
      expect(saveRes1.isSuccess, isTrue);

      const cash2 = BusinessAccount(
        id: 'c2',
        category: 'cash',
        title: 'Cash Drawer 2',
        openingBalance: Money.zero,
        closingBalance: Money.zero,
        createdAt: 200,
        updatedAt: 200,
      );

      final saveRes2 = await businessRepo.saveAccount(cash2);
      expect(saveRes2.isFailure, isTrue);
      expect(saveRes2.errorMessageOrNull, contains('cash'));
    });

    test('2. Business: Account cascade soft-delete soft-deletes linked entries & outbox', () async {
      const bkashAcc = BusinessAccount(
        id: 'b_acc1',
        category: 'bkash',
        title: 'bKash Merchant',
        openingBalance: Money.zero,
        closingBalance: Money.zero,
        createdAt: 100,
        updatedAt: 100,
      );
      await businessRepo.saveAccount(bkashAcc);

      final entry = BusinessEntry(
        id: 'b_entry1',
        accountId: 'b_acc1',
        direction: 'receive',
        name: 'Cust A',
        amount: Money.fromMinorUnits(5000),
        note: '',
        localDate: '2026-07-22',
        category: 'Sales',
        createdAt: 200,
        updatedAt: 200,
      );
      await businessRepo.saveEntry(entry);

      // Soft delete account
      final delRes = await businessRepo.softDeleteAccount('b_acc1', 300);
      expect(delRes.isSuccess, isTrue);

      // Verify active account list and entry list are empty
      final activeAccs = await businessRepo.getActiveAccounts();
      final activeEntries = await businessRepo.getActiveEntries();
      expect(activeAccs.dataOrNull, isEmpty);
      expect(activeEntries.dataOrNull, isEmpty);

      // Verify sync_outbox contains delete records for both account and linked entry
      final db = appDb.database;
      final outboxRows = await db.query('sync_outbox', where: 'operation = ?', whereArgs: ['delete']);
      expect(outboxRows.length, equals(2));
    });

    test('3. Profile: First profile activation & prevent last profile deletion', () async {
      const p1 = Profile(
        id: 'prof_1',
        name: 'Personal Profile',
        createdAt: 100,
        updatedAt: 100,
      );
      await profileRepo.saveProfile(p1);

      // Verify first saved profile becomes active_profile_id
      final activeId = await profileRepo.getActiveProfileId();
      expect(activeId.dataOrNull, equals('prof_1'));

      // Attempt deleting the only active profile -> Failure
      final delRes = await profileRepo.softDeleteProfile(
        profileId: 'prof_1',
        deletedAtMicroseconds: 200,
      );
      expect(delRes.isFailure, isTrue);
      expect(delRes.errorMessageOrNull, contains('last active profile'));
    });

    test('4. Profile deletion reassigns active transactions to target profile', () async {
      const p1 = Profile(id: 'prof_1', name: 'P1', createdAt: 100, updatedAt: 100);
      const p2 = Profile(id: 'prof_2', name: 'P2', createdAt: 200, updatedAt: 200);
      await profileRepo.saveProfile(p1);
      await profileRepo.saveProfile(p2);

      final tx = TransactionRecord(
        id: 'tx_1',
        profileId: 'prof_1',
        amount: Money.fromMinorUnits(2000),
        localDate: '2026-07-22',
        method: 'bkash',
        direction: 'received',
        createdAt: 300,
        updatedAt: 300,
      );
      await txRepo.saveTransaction(tx);

      // Soft delete prof_1 with reassignment target prof_2
      final delRes = await profileRepo.softDeleteProfile(
        profileId: 'prof_1',
        deletedAtMicroseconds: 400,
        targetReassignProfileId: 'prof_2',
      );
      expect(delRes.isSuccess, isTrue);

      // Verify tx_1 is now assigned to prof_2
      final p2Txs = await txRepo.getActiveTransactionsForProfile('prof_2');
      expect(p2Txs.dataOrNull?.length, equals(1));
      expect(p2Txs.dataOrNull?.first.id, equals('tx_1'));
    });

    test('5. Transaction: "gave" direction requires phone number', () async {
      const p1 = Profile(id: 'prof_1', name: 'P1', createdAt: 100, updatedAt: 100);
      await profileRepo.saveProfile(p1);

      final invalidGaveTx = TransactionRecord(
        id: 'tx_inv',
        profileId: 'prof_1',
        number: null, // Missing number for gave!
        amount: Money.fromMinorUnits(1000),
        localDate: '2026-07-22',
        method: 'bkash',
        direction: 'gave',
        createdAt: 200,
        updatedAt: 200,
      );

      final saveRes = await txRepo.saveTransaction(invalidGaveTx);
      expect(saveRes.isFailure, isTrue);
      expect(saveRes.errorMessageOrNull, contains('phone number'));
    });

    test('6. Expenses & Reminders CRUD & state transitions', () async {
      final exp = Expense(
        id: 'ex_1',
        amount: Money.fromMinorUnits(1500),
        category: 'Travel',
        note: 'Taxi',
        localDate: '2026-07-22',
        createdAt: 100,
        updatedAt: 100,
      );
      expect((await expenseRepo.saveExpense(exp)).isSuccess, isTrue);
      expect((await expenseRepo.getActiveExpenses()).dataOrNull?.length, equals(1));

      const rem = Reminder(
        id: 'rem_1',
        title: 'Pay Tax',
        note: 'Annual tax',
        scope: 'general',
        dueAt: 1700000000000000,
        repeatRule: 'monthly',
        isFired: false,
        isEnabled: true,
        createdAt: 100,
        updatedAt: 100,
      );
      expect((await reminderRepo.saveReminder(rem)).isSuccess, isTrue);

      final updateRes = await reminderRepo.updateState(
        id: 'rem_1',
        isFired: true,
        isEnabled: true,
        updatedAtMicroseconds: 200,
      );
      expect(updateRes.isSuccess, isTrue);

      final rems = await reminderRepo.getActiveReminders();
      expect(rems.dataOrNull?.first.isFired, isTrue);
    });
  });
}
