import 'package:meta/meta.dart';
import '../../core/money/money.dart';

/// Represents a personal receivable or payment entry (PRD Section 5.2).
@immutable
class PersonalEntry {
  final String id;
  final String direction; // 'receive' or 'pay'
  final String name;
  final String normalizedName;
  final String? phone;
  final String? normalizedPhone;
  final Money amount; // Operational amount must be > 0
  final String note;
  final String localDate; // YYYY-MM-DD
  final String category;
  final String? attachmentRef;
  final int createdAt; // Microseconds since epoch
  final int updatedAt;
  final int? deletedAt;

  const PersonalEntry({
    required this.id,
    required this.direction,
    required this.name,
    required this.normalizedName,
    this.phone,
    this.normalizedPhone,
    required this.amount,
    required this.note,
    required this.localDate,
    required this.category,
    this.attachmentRef,
    required this.createdAt,
    required this.updatedAt,
    this.deletedAt,
  });

  /// Validates personal entry invariants per PRD section 5.2.
  static String? validate({
    required String name,
    required String direction,
    required Money amount,
    required String note,
    required String category,
    String? phone,
  }) {
    final trimmedName = name.trim();
    if (trimmedName.isEmpty || trimmedName.length > 80) {
      return 'Name length must be between 1 and 80 characters';
    }
    if (direction != 'receive' && direction != 'pay') {
      return 'Direction must be either "receive" or "pay"';
    }
    if (!amount.isPositive) {
      return 'Amount must be greater than zero';
    }
    if (note.length > 300) {
      return 'Note maximum length is 300 characters';
    }
    final trimmedCat = category.trim();
    if (trimmedCat.isEmpty || trimmedCat.length > 24) {
      return 'Category length must be between 1 and 24 characters';
    }
    if (phone != null && phone.trim().isNotEmpty) {
      final normalized = normalizePhone(phone);
      final bdPhoneRegex = RegExp(r'^(?:\+?8801|01)[3-9]\d{8}$');
      if (!bdPhoneRegex.hasMatch(normalized)) {
        return 'Invalid Bangladesh phone number format';
      }
    }
    return null;
  }

  static String normalizePhone(String rawPhone) {
    return rawPhone.replaceAll(RegExp(r'[\s\-]'), '');
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'direction': direction,
      'name': name,
      'normalized_name': normalizedName,
      'phone': phone,
      'normalized_phone': normalizedPhone,
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

  factory PersonalEntry.fromMap(Map<String, dynamic> map) {
    return PersonalEntry(
      id: map['id']?.toString() ?? '',
      direction: map['direction']?.toString() ?? '',
      name: map['name']?.toString() ?? '',
      normalizedName: map['normalized_name']?.toString() ?? '',
      phone: map['phone']?.toString(),
      normalizedPhone: map['normalized_phone']?.toString(),
      amount: Money.fromMinorUnits(_parseInt(map['amount_minor'])),
      note: map['note']?.toString() ?? '',
      localDate: map['local_date']?.toString() ?? '',
      category: map['category']?.toString() ?? '',
      attachmentRef: map['attachment_ref']?.toString(),
      createdAt: _parseInt(map['created_at']),
      updatedAt: _parseInt(map['updated_at']),
      deletedAt: _parseNullableInt(map['deleted_at']),
    );
  }
}
