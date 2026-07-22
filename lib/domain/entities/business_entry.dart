import 'package:meta/meta.dart';
import '../../core/money/money.dart';

/// Business Entry domain entity (PRD Section 5.3).
@immutable
class BusinessEntry {
  final String id;
  final String accountId;
  final String direction; // 'send' or 'receive'
  final String name;
  final String? phone;
  final Money amount; // Positive amount required (> 0)
  final String note;
  final String localDate; // YYYY-MM-DD
  final String category;
  final String? attachmentRef;
  final int createdAt;
  final int updatedAt;
  final int? deletedAt;

  const BusinessEntry({
    required this.id,
    required this.accountId,
    required this.direction,
    required this.name,
    this.phone,
    required this.amount,
    required this.note,
    required this.localDate,
    required this.category,
    this.attachmentRef,
    required this.createdAt,
    required this.updatedAt,
    this.deletedAt,
  });

  /// Validates business entry fields per PRD section 5.3.
  static String? validate({
    required String name,
    required String direction,
    required Money amount,
    required String note,
    required String category,
  }) {
    final trimmedName = name.trim();
    if (trimmedName.isEmpty || trimmedName.length > 80) {
      return 'Name length must be between 1 and 80 characters';
    }
    if (direction != 'send' && direction != 'receive') {
      return 'Direction must be either "send" or "receive"';
    }
    if (!amount.isPositive) {
      return 'Amount must be positive (> 0)';
    }
    if (note.length > 300) {
      return 'Note maximum length is 300 characters';
    }
    final trimmedCat = category.trim();
    if (trimmedCat.isEmpty || trimmedCat.length > 24) {
      return 'Category length must be between 1 and 24 characters';
    }
    return null;
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'account_id': accountId,
      'direction': direction,
      'name': name,
      'phone': phone,
      'amount_minor': amount.minorUnits,
      'note': note,
      'local_date': localDate,
      'category': category,
      'attachment_ref': attachmentRef,
      'created_at': createdAt,
      'updated_at': updatedAt,
      'deleted_at': deletedAt,
    };
  }

  factory BusinessEntry.fromMap(Map<String, dynamic> map) {
    return BusinessEntry(
      id: map['id'] as String,
      accountId: map['account_id'] as String,
      direction: map['direction'] as String,
      name: map['name'] as String,
      phone: map['phone'] as String?,
      amount: Money.fromMinorUnits(map['amount_minor'] as int),
      note: map['note'] as String,
      localDate: map['local_date'] as String,
      category: map['category'] as String,
      attachmentRef: map['attachment_ref'] as String?,
      createdAt: map['created_at'] as int,
      updatedAt: map['updated_at'] as int,
      deletedAt: map['deleted_at'] as int?,
    );
  }
}
