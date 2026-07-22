import 'package:meta/meta.dart';
import '../../core/money/money.dart';
import '../entities/personal_entry.dart';
import '../entities/business_entry.dart';
import '../entities/transaction_record.dart';

/// Unified Local Accounting Report model (PRD Section 6.6).
@immutable
class UnifiedReport {
  final String startDate;
  final String endDate;
  final Money personalReceived;
  final Money personalPaid;
  final Money personalNet;
  final int personalCount;

  final Money businessReceived;
  final Money businessSent;
  final Money businessNet;
  final int businessCount;

  final Money transactionReceived;
  final Money transactionGave;
  final Money transactionNet;
  final int transactionCount;

  final Money totalReceived;
  final Money totalPaid;
  final Money overallNet;
  final int totalRecordCount;

  const UnifiedReport({
    required this.startDate,
    required this.endDate,
    required this.personalReceived,
    required this.personalPaid,
    required this.personalNet,
    required this.personalCount,
    required this.businessReceived,
    required this.businessSent,
    required this.businessNet,
    required this.businessCount,
    required this.transactionReceived,
    required this.transactionGave,
    required this.transactionNet,
    required this.transactionCount,
    required this.totalReceived,
    required this.totalPaid,
    required this.overallNet,
    required this.totalRecordCount,
  });
}

/// Aggregates active records across Personal, Business, and Active Profile Transactions.
class UnifiedReportEngine {
  static UnifiedReport generateReport({
    required String startDate,
    required String endDate,
    required List<PersonalEntry> personalEntries,
    required List<BusinessEntry> businessEntries,
    required List<TransactionRecord> activeProfileTransactions,
  }) {
    if (startDate.compareTo(endDate) > 0) {
      throw ArgumentError('startDate ($startDate) cannot be after endDate ($endDate)');
    }

    // 1. Personal Section
    int pRecMinor = 0;
    int pPaidMinor = 0;
    int pCount = 0;

    for (final pe in personalEntries) {
      if (pe.deletedAt != null) continue;
      if (pe.localDate.compareTo(startDate) >= 0 && pe.localDate.compareTo(endDate) <= 0) {
        pCount++;
        if (pe.direction == 'receive') {
          pRecMinor += pe.amount.minorUnits;
        } else if (pe.direction == 'pay') {
          pPaidMinor += pe.amount.minorUnits;
        }
      }
    }

    final personalReceived = Money.fromMinorUnits(pRecMinor);
    final personalPaid = Money.fromMinorUnits(pPaidMinor);
    final personalNet = personalReceived - personalPaid;

    // 2. Business Section
    int bRecMinor = 0;
    int bSentMinor = 0;
    int bCount = 0;

    for (final be in businessEntries) {
      if (be.deletedAt != null) continue;
      if (be.localDate.compareTo(startDate) >= 0 && be.localDate.compareTo(endDate) <= 0) {
        bCount++;
        if (be.direction == 'receive') {
          bRecMinor += be.amount.minorUnits;
        } else if (be.direction == 'send') {
          bSentMinor += be.amount.minorUnits;
        }
      }
    }

    final businessReceived = Money.fromMinorUnits(bRecMinor);
    final businessSent = Money.fromMinorUnits(bSentMinor);
    final businessNet = businessReceived - businessSent;

    // 3. Transactions of Active Profile Only
    int txRecMinor = 0;
    int txGaveMinor = 0;
    int txCount = 0;

    for (final tx in activeProfileTransactions) {
      if (tx.deletedAt != null) continue;
      if (tx.localDate.compareTo(startDate) >= 0 && tx.localDate.compareTo(endDate) <= 0) {
        txCount++;
        if (tx.direction == 'received') {
          txRecMinor += tx.amount.minorUnits;
        } else if (tx.direction == 'gave') {
          txGaveMinor += tx.amount.minorUnits;
        }
      }
    }

    final transactionReceived = Money.fromMinorUnits(txRecMinor);
    final transactionGave = Money.fromMinorUnits(txGaveMinor);
    final transactionNet = transactionReceived - transactionGave;

    // 4. Overall Totals (PRD Section 6.6)
    // total received = personal received + business received + transaction received
    final totalReceived = personalReceived + businessReceived + transactionReceived;
    // total paid = personal paid + business sent + transaction gave
    final totalPaid = personalPaid + businessSent + transactionGave;
    // overall net = total received - total paid
    final overallNet = totalReceived - totalPaid;
    final totalRecordCount = pCount + bCount + txCount;

    return UnifiedReport(
      startDate: startDate,
      endDate: endDate,
      personalReceived: personalReceived,
      personalPaid: personalPaid,
      personalNet: personalNet,
      personalCount: pCount,
      businessReceived: businessReceived,
      businessSent: businessSent,
      businessNet: businessNet,
      businessCount: bCount,
      transactionReceived: transactionReceived,
      transactionGave: transactionGave,
      transactionNet: transactionNet,
      transactionCount: txCount,
      totalReceived: totalReceived,
      totalPaid: totalPaid,
      overallNet: overallNet,
      totalRecordCount: totalRecordCount,
    );
  }
}
