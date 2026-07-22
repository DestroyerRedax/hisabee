import 'package:test/test.dart';
import 'package:hisabee/core/money/money.dart';
import 'package:hisabee/domain/calculators/accounting_calculators.dart';
import 'package:hisabee/domain/entities/personal_entry.dart';
import 'package:hisabee/domain/entities/business_account.dart';
import 'package:hisabee/domain/entities/business_entry.dart';
import 'package:hisabee/domain/entities/transaction_record.dart';
import 'package:hisabee/domain/entities/expense.dart';

void main() {
  group('PRD Section 6 Accounting Domain Calculators', () {
    test('1. Personal totals calculation and soft-deletion exclusion', () {
      final entries = [
        PersonalEntry(
          id: 'p1',
          direction: 'receive',
          name: 'Entry 1',
          normalizedName: 'entry 1',
          amount: Money.fromMinorUnits(10000), // 100.00
          note: '',
          localDate: '2026-07-22',
          category: 'Cash',
          createdAt: 100,
          updatedAt: 100,
        ),
        PersonalEntry(
          id: 'p2',
          direction: 'pay',
          name: 'Entry 2',
          normalizedName: 'entry 2',
          amount: Money.fromMinorUnits(3000), // 30.00
          note: '',
          localDate: '2026-07-22',
          category: 'Cash',
          createdAt: 200,
          updatedAt: 200,
        ),
        PersonalEntry(
          id: 'p3_deleted',
          direction: 'receive',
          name: 'Deleted Entry',
          normalizedName: 'deleted entry',
          amount: Money.fromMinorUnits(50000),
          note: '',
          localDate: '2026-07-22',
          category: 'Cash',
          createdAt: 300,
          updatedAt: 300,
          deletedAt: 400, // Deleted!
        ),
      ];

      final totals = PersonalCalculations.calculate(entries);
      expect(totals.received.minorUnits, equals(10000));
      expect(totals.paid.minorUnits, equals(3000));
      expect(totals.net.minorUnits, equals(7000)); // 100 - 30 = 70
      expect(totals.count, equals(2));
    });

    test('2. Authoritative Business Profit Equation: closing + sent - (opening + received)', () {
      final accounts = [
        BusinessAccount(
          id: 'b1',
          category: 'cash',
          title: 'Cash Store',
          openingBalance: Money.fromMinorUnits(50000), // opening = 500.00
          closingBalance: Money.fromMinorUnits(80000), // closing = 800.00
          createdAt: 100,
          updatedAt: 100,
        ),
      ];

      final entries = [
        BusinessEntry(
          id: 'e1',
          accountId: 'b1',
          direction: 'send',
          name: 'Supplier Pay',
          amount: Money.fromMinorUnits(20000), // sent = 200.00
          note: '',
          localDate: '2026-07-22',
          category: 'Vendor',
          createdAt: 100,
          updatedAt: 100,
        ),
        BusinessEntry(
          id: 'e2',
          accountId: 'b1',
          direction: 'receive',
          name: 'Customer Payment',
          amount: Money.fromMinorUnits(10000), // received = 100.00
          note: '',
          localDate: '2026-07-22',
          category: 'Sales',
          createdAt: 200,
          updatedAt: 200,
        ),
      ];

      final totals = BusinessCalculations.calculate(
        activeAccounts: accounts,
        activeEntries: entries,
      );

      // profit = closing + sent - (opening + received)
      // profit = 80000 + 20000 - (50000 + 10000) = 100000 - 60000 = 40000 minor units (400.00 Taka)
      expect(totals.profit.minorUnits, equals(40000));
      expect(totals.opening.minorUnits, equals(50000));
      expect(totals.closing.minorUnits, equals(80000));
      expect(totals.sent.minorUnits, equals(20000));
      expect(totals.received.minorUnits, equals(10000));
    });

    test('3. Profile Transaction Totals: received, gave, net', () {
      final txs = [
        TransactionRecord(
          id: 't1',
          profileId: 'prof1',
          amount: Money.fromMinorUnits(15000),
          localDate: '2026-07-22',
          method: 'bkash',
          direction: 'received',
          createdAt: 100,
          updatedAt: 100,
        ),
        TransactionRecord(
          id: 't2',
          profileId: 'prof1',
          number: '01700000000',
          amount: Money.fromMinorUnits(5000),
          localDate: '2026-07-22',
          method: 'bkash',
          direction: 'gave',
          createdAt: 200,
          updatedAt: 200,
        ),
      ];

      final totals = TransactionCalculations.calculate(txs);
      expect(totals.received.minorUnits, equals(15000));
      expect(totals.gave.minorUnits, equals(5000));
      expect(totals.net.minorUnits, equals(10000));
      expect(totals.count, equals(2));
    });

    test('4. Monthly Expense calculation with half-open interval [start, end)', () {
      final expenses = [
        Expense(
          id: 'ex1',
          amount: Money.fromMinorUnits(4000), // 40.00
          category: 'Food',
          note: '',
          localDate: '2026-07-01', // Included (start bound)
          createdAt: 100,
          updatedAt: 100,
        ),
        Expense(
          id: 'ex2',
          amount: Money.fromMinorUnits(6000), // 60.00
          category: 'Food',
          note: '',
          localDate: '2026-07-31', // Included
          createdAt: 200,
          updatedAt: 200,
        ),
        Expense(
          id: 'ex3',
          amount: Money.fromMinorUnits(10000),
          category: 'Rent',
          note: '',
          localDate: '2026-08-01', // Excluded (half-open end bound)
          createdAt: 300,
          updatedAt: 300,
        ),
      ];

      final julyExpense = ExpenseCalculations.calculateMonthlyExpense(
        activeExpenses: expenses,
        year: 2026,
        month: 7,
      );

      expect(julyExpense.minorUnits, equals(10000)); // 4000 + 6000 = 10000
    });
  });
}
