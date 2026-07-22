import 'package:meta/meta.dart';
import '../../core/money/money.dart';

/// Transaction record entity for a profile (PRD Section 5.4).
@immutable
class TransactionRecord {
  final String id;
  final String profileId;
  final String? displayParty;
  final String? number;
  final Money amount; // Positive amount required (> 0)
  final String localDate; // YYYY-MM-DD
  final String? localTime; // HH:MM
  final String method; // bkash, nagad, rocket, bank, flexiload
  final String direction; // 'received' or 'gave'
  final String? rawSource;
  final int createdAt;
  final int updatedAt;
  final int? deletedAt;

  const TransactionRecord({
    required this.id,
    required this.profileId,
    this.displayParty,
    this.number,
    required this.amount,
    required this.localDate,
    this.localTime,
    required this.method,
    required this.direction,
    this.rawSource,
    required this.createdAt,
    required this.updatedAt,
    this.deletedAt,
  });

  static const List<String> validMethods = [
    'bkash',
    'nagad',
    'rocket',
    'bank',
    'flexiload'
  ];

  /// Validates transaction record invariants per PRD Section 5.4.
  static String? validate({
    required String method,
    required String direction,
    required Money amount,
    String? number,
  }) {
    if (!validMethods.contains(method)) {
      return 'Invalid transaction method: $method';
    }
    if (direction != 'received' && direction != 'gave') {
      return 'Direction must be "received" or "gave"';
    }
    if (!amount.isPositive) {
      return 'Transaction amount must be positive (> 0)';
    }
    if (direction == 'gave' && (number == null || number.trim().isEmpty)) {
      return 'A "gave" transaction requires a non-empty phone number';
    }
    return null;
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'profile_id': profileId,
      'display_party': displayParty,
      'number': number,
      'amount_minor': amount.minorUnits,
      'local_date': localDate,
      'local_time': localTime,
      'method': method,
      'direction': direction,
      'raw_source': rawSource,
      'created_at': createdAt,
      'updated_at': updatedAt,
      'deleted_at': deletedAt,
    };
  }

  factory TransactionRecord.fromMap(Map<String, dynamic> map) {
    return TransactionRecord(
      id: map['id'] as String,
      profileId: map['profile_id'] as String,
      displayParty: map['display_party'] as String?,
      number: map['number'] as String?,
      amount: Money.fromMinorUnits(map['amount_minor'] as int),
      localDate: map['local_date'] as String,
      localTime: map['local_time'] as String?,
      method: map['method'] as String,
      direction: map['direction'] as String,
      rawSource: map['raw_source'] as String?,
      createdAt: map['created_at'] as int,
      updatedAt: map['updated_at'] as int,
      deletedAt: map['deleted_at'] as int?,
    );
  }
}
