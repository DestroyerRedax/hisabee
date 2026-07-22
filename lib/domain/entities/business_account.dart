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

  factory BusinessAccount.fromMap(Map<String, dynamic> map) {
    return BusinessAccount(
      id: map['id'] as String,
      category: map['category'] as String,
      title: map['title'] as String,
      number: map['number'] as String?,
      openingBalance: Money.fromMinorUnits(map['opening_minor'] as int),
      closingBalance: Money.fromMinorUnits(map['closing_minor'] as int),
      createdAt: map['created_at'] as int,
      updatedAt: map['updated_at'] as int,
      deletedAt: map['deleted_at'] as int?,
    );
  }
}
