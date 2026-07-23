import 'package:meta/meta.dart';
import '../../core/money/money.dart';

/// Permitted business account categories (PRD Section 5.3).
enum BusinessAccountCategory { bkash, nagad, rocket, bank, cash, flexiload }

/// Business Account domain entity (PRD Section 5.3).
@immutable
class BusinessAccount {
  final String id;
  final String category; // bkash, nagad, rocket, bank, cash, flexiload
  final String title;
  final String? number;
  final Money openingBalance;
  final Money closingBalance;
  final int createdAt;
  final int updatedAt;
  final int? deletedAt;

  const BusinessAccount({
    required this.id,
    required this.category,
    required this.title,
    this.number,
    required this.openingBalance,
    required this.closingBalance,
    required this.createdAt,
    required this.updatedAt,
    this.deletedAt,
  });

  static const List<String> validCategories = [
    'bkash',
    'nagad',
    'rocket',
    'bank',
    'cash',
    'flexiload'
  ];

  /// Validates business account properties per PRD Section 5.3.
  static String? validate({
    required String category,
    required String title,
  }) {
    if (!validCategories.contains(category)) {
      return 'Invalid account category: $category';
    }
    final trimmedTitle = title.trim();
    if (trimmedTitle.isEmpty || trimmedTitle.length > 80) {
      return 'Title length must be between 1 and 80 characters';
    }
    return null;
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'category': category,
      'title': title,
      'number': number,
      'opening_minor': openingBalance.minorUnits,
      'closing_minor': closingBalance.minorUnits,
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

  factory BusinessAccount.fromMap(Map<String, dynamic> map) {
    return BusinessAccount(
      id: map['id']?.toString() ?? '',
      category: map['category']?.toString() ?? '',
      title: map['title']?.toString() ?? '',
      number: map['number']?.toString(),
      openingBalance: Money.fromMinorUnits(_parseInt(map['opening_minor'])),
      closingBalance: Money.fromMinorUnits(_parseInt(map['closing_minor'])),
      createdAt: _parseInt(map['created_at']),
      updatedAt: _parseInt(map['updated_at']),
      deletedAt: map['deleted_at'] != null ? _parseInt(map['deleted_at']) : null,
    );
  }
}
