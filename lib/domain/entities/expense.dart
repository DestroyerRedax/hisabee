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

  factory Expense.fromMap(Map<String, dynamic> map) {
    return Expense(
      id: map['id'] as String,
      amount: Money.fromMinorUnits(map['amount_minor'] as int),
      category: map['category'] as String,
      note: map['note'] as String,
      localDate: map['local_date'] as String,
      attachmentRef: map['attachment_ref'] as String?,
      createdAt: map['created_at'] as int,
      updatedAt: map['updated_at'] as int,
      deletedAt: map['deleted_at'] as int?,
    );
  }
}
