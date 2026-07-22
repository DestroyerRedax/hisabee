import '../../core/money/money.dart';
import '../entities/personal_entry.dart';
import '../entities/business_account.dart';
import '../entities/business_entry.dart';
import '../entities/transaction_record.dart';
import '../entities/expense.dart';

/// Pure domain calculators enforcing authoritative PRD Section 6 formulas.
class PersonalCalculations {
  /// PRD Section 6.2: Personal Totals
  /// - received = SUM(amount_minor where direction = receive and deleted_at is null)
  /// - paid = SUM(amount_minor where direction = pay and deleted_at is null)
  /// - net = received - paid
  static PersonalTotals calculate(List<PersonalEntry> activeEntries) {
    int receivedMinor = 0;
    int paidMinor = 0;

    for (final entry in activeEntries) {
      if (entry.deletedAt != null) continue; // Exclude deleted
      if (entry.direction == 'receive') {
        receivedMinor += entry.amount.minorUnits;
      } else if (entry.direction == 'pay') {
        paidMinor += entry.amount.minorUnits;
      }
    }

    final received = Money.fromMinorUnits(receivedMinor);
    final paid = Money.fromMinorUnits(paidMinor);
    final net = received - paid;

    return PersonalTotals(
      received: received,
      paid: paid,
      net: net,
      count: activeEntries.where((e) => e.deletedAt == null).length,
    );
  }
}

class PersonalTotals {
  final Money received;
  final Money paid;
  final Money net;
  final int count;

  const PersonalTotals({
    required this.received,
    required this.paid,
    required this.net,
    required this.count,
  });
}

class BusinessCalculations {
  /// PRD Section 6.3: Authoritative Business Totals & Profit Equation
  /// - opening = SUM(opening_minor for active business accounts)
  /// - closing = SUM(closing_minor for active business accounts)
  /// - sent = SUM(amount_minor where active business entry direction = send)
  /// - received = SUM(amount_minor where active business entry direction = receive)
  /// - profit = closing + sent - (opening + received)
  static BusinessTotals calculate({
    required List<BusinessAccount> activeAccounts,
    required List<BusinessEntry> activeEntries,
  }) {
    int openingMinor = 0;
    int closingMinor = 0;
    for (final acc in activeAccounts) {
      if (acc.deletedAt != null) continue;
      openingMinor += acc.openingBalance.minorUnits;
      closingMinor += acc.closingBalance.minorUnits;
    }

    int sentMinor = 0;
    int receivedMinor = 0;
    for (final entry in activeEntries) {
      if (entry.deletedAt != null) continue;
      if (entry.direction == 'send') {
        sentMinor += entry.amount.minorUnits;
      } else if (entry.direction == 'receive') {
        receivedMinor += entry.amount.minorUnits;
      }
    }

    final opening = Money.fromMinorUnits(openingMinor);
    final closing = Money.fromMinorUnits(closingMinor);
    final sent = Money.fromMinorUnits(sentMinor);
    final received = Money.fromMinorUnits(receivedMinor);

    // Authoritative PRD Equation: profit = closing + sent - (opening + received)
    final profitMinor = closingMinor + sentMinor - (openingMinor + receivedMinor);
    final profit = Money.fromMinorUnits(profitMinor);

    return BusinessTotals(
      opening: opening,
      closing: closing,
      sent: sent,
      received: received,
      profit: profit,
      entryCount: activeEntries.where((e) => e.deletedAt == null).length,
    );
  }
}

class BusinessTotals {
  final Money opening;
  final Money closing;
  final Money sent;
  final Money received;
  final Money profit;
  final int entryCount;

  const BusinessTotals({
    required this.opening,
    required this.closing,
    required this.sent,
    required this.received,
    required this.profit,
    required this.entryCount,
  });
}

class TransactionCalculations {
  /// PRD Section 6.4: Profile Transaction Totals
  /// - received = SUM(amount_minor where direction = received and active)
  /// - gave = SUM(amount_minor where direction = gave and active)
  /// - net = received - gave
  static TransactionTotals calculate(List<TransactionRecord> activeTransactions) {
    int receivedMinor = 0;
    int gaveMinor = 0;

    for (final tx in activeTransactions) {
      if (tx.deletedAt != null) continue;
      if (tx.direction == 'received') {
        receivedMinor += tx.amount.minorUnits;
      } else if (tx.direction == 'gave') {
        gaveMinor += tx.amount.minorUnits;
      }
    }

    final received = Money.fromMinorUnits(receivedMinor);
    final gave = Money.fromMinorUnits(gaveMinor);
    final net = received - gave;

    return TransactionTotals(
      received: received,
      gave: gave,
      net: net,
      count: activeTransactions.where((t) => t.deletedAt == null).length,
    );
  }
}

class TransactionTotals {
  final Money received;
  final Money gave;
  final Money net;
  final int count;

  const TransactionTotals({
    required this.received,
    required this.gave,
    required this.net,
    required this.count,
  });
}

class ExpenseCalculations {
  /// PRD Section 6.5: Monthly Expense Total
  /// For month M [year-month], half-open calendar interval [first day of M, first day of M+1).
  static Money calculateMonthlyExpense({
    required List<Expense> activeExpenses,
    required int year,
    required int month,
  }) {
    final startLocalDate = '$year-${month.toString().padLeft(2, '0')}-01';
    final nextYear = month == 12 ? year + 1 : year;
    final nextMonth = month == 12 ? 1 : month + 1;
    final endLocalDate = '$nextYear-${nextMonth.toString().padLeft(2, '0')}-01';

    int monthlyMinor = 0;
    for (final expense in activeExpenses) {
      if (expense.deletedAt != null) continue;
      // Half-open interval check: localDate >= startLocalDate && localDate < endLocalDate
      if (expense.localDate.compareTo(startLocalDate) >= 0 &&
          expense.localDate.compareTo(endLocalDate) < 0) {
        monthlyMinor += expense.amount.minorUnits;
      }
    }

    return Money.fromMinorUnits(monthlyMinor);
  }
}
