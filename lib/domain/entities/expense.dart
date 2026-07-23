import 'package:meta/meta.dart';
import '../../core/money/money.dart';

/// Expense domain entity (PRD Section 5.5).
@immutable
class Expense {
  final String id;
  final Money amount; // Positive amount required (> 0)
  final String category;
  final String note;
  final String localDate; // YYYY-MM-DD
  final String? attachmentRef;
  final int createdAt;
  final int updatedAt;
  final int? deletedAt;

  const Expense({
    required this.id,
    required this.amount,
    required this.category,
    required this.note,
    required this.localDate,
    this.attachmentRef,
    required this.createdAt,
    required this.updatedAt,
    this.deletedAt,
  });

  /// Validates expense properties per PRD Section 5.5.
  static String? validate({
    required Money amount,
    required String category,
    required String note,
  }) {
    if (!amount.isPositive) {
      return 'Expense amount must be positive (> 0)';
    }
    final trimmedCat = category.trim();
    if (trimmedCat.isEmpty || trimmedCat.length > 24) {
      return 'Category is required and must be between 1 and 24 characters';
    }
    if (note.length > 300) {
      return 'Note maximum length is 300 characters';
    }
    return null;
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'amount_minor': amount.minorUnits,
      'category': category,
      'note': note,
      'local_date': localDate,
      'attachment_ref': attachmentRef,
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

  factory Expense.fromMap(Map<String, dynamic> map) {
    return Expense(
      id: map['id']?.toString() ?? '',
      amount: Money.fromMinorUnits(_parseInt(map['amount_minor'])),
      category: map['category']?.toString() ?? '',
      note: map['note']?.toString() ?? '',
      localDate: map['local_date']?.toString() ?? '',
      attachmentRef: map['attachment_ref']?.toString(),
      createdAt: _parseInt(map['created_at']),
      updatedAt: _parseInt(map['updated_at']),
      deletedAt: _parseNullableInt(map['deleted_at']),
    );
  }
}
