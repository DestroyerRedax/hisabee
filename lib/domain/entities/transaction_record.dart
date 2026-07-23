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

  static int _parseInt(dynamic val) {
    if (val == null) return 0;
    if (val is num) return val.toInt();
    if (val is String) {
      return (double.tryParse(val) ?? int.tryParse(val) ?? 0).toInt();
    }
    return 0;
  }

  static int? _parseNullableInt(dynamic val) {
    if (val == null) return null;
    if (val is num) return val.toInt();
    if (val is String) {
      final s = val.trim();
      if (s.isEmpty || s == 'null' || s == 'NULL') return null;
      return (double.tryParse(s) ?? int.tryParse(s))?.toInt();
    }
    return null;
  }

  factory TransactionRecord.fromMap(Map<String, dynamic> map) {
    return TransactionRecord(
      id: map['id']?.toString() ?? '',
      profileId: map['profile_id']?.toString() ?? '',
      displayParty: map['display_party']?.toString(),
      number: map['number']?.toString(),
      amount: Money.fromMinorUnits(_parseInt(map['amount_minor'])),
      localDate: map['local_date']?.toString() ?? '',
      localTime: map['local_time']?.toString(),
      method: map['method']?.toString() ?? '',
      direction: map['direction']?.toString() ?? '',
      rawSource: map['raw_source']?.toString(),
      createdAt: _parseInt(map['created_at']),
      updatedAt: _parseInt(map['updated_at']),
      deletedAt: _parseNullableInt(map['deleted_at']),
    );
  }
}
