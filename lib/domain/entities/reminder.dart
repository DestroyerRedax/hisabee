import 'package:meta/meta.dart';

/// Reminder domain entity (PRD Section 5.5, Section 8).
@immutable
class Reminder {
  final String id;
  final String title;
  final String note;
  final String scope; // general, personal, business, transaction, expense
  final int dueAt; // Microseconds since epoch
  final String repeatRule; // none, daily, weekly, monthly
  final bool isFired;
  final bool isEnabled;
  final int createdAt;
  final int updatedAt;
  final int? deletedAt;

  const Reminder({
    required this.id,
    required this.title,
    required this.note,
    required this.scope,
    required this.dueAt,
    required this.repeatRule,
    required this.isFired,
    required this.isEnabled,
    required this.createdAt,
    required this.updatedAt,
    this.deletedAt,
  });

  static const List<String> validScopes = [
    'general',
    'personal',
    'business',
    'transaction',
    'expense'
  ];

  static const List<String> validRepeatRules = [
    'none',
    'daily',
    'weekly',
    'monthly'
  ];

  /// Validates reminder properties per PRD Section 5.5.
  static String? validate({
    required String title,
    required String note,
    required String scope,
    required String repeatRule,
  }) {
    final trimmedTitle = title.trim();
    if (trimmedTitle.isEmpty || trimmedTitle.length > 120) {
      return 'Title length must be between 1 and 120 characters';
    }
    if (note.length > 300) {
      return 'Note maximum length is 300 characters';
    }
    if (!validScopes.contains(scope)) {
      return 'Invalid reminder scope: $scope';
    }
    if (!validRepeatRules.contains(repeatRule)) {
      return 'Invalid repeat rule: $repeatRule';
    }
    return null;
  }

  /// Calculates the next due timestamp after [comparisonTimestamp] according to PRD Section 8.
  static int? calculateNextDueTimestamp({
    required int dueAtMicroseconds,
    required String repeatRule,
    required bool isEnabled,
    required int comparisonMicroseconds,
  }) {
    if (!isEnabled) return null;

    final normalizedRule =
        validRepeatRules.contains(repeatRule) ? repeatRule : 'none';

    if (normalizedRule == 'none') {
      return dueAtMicroseconds > comparisonMicroseconds
          ? dueAtMicroseconds
          : null;
    }

    var current = DateTime.fromMicrosecondsSinceEpoch(dueAtMicroseconds);
    final comparison =
        DateTime.fromMicrosecondsSinceEpoch(comparisonMicroseconds);

    while (!current.isAfter(comparison)) {
      switch (normalizedRule) {
        case 'daily':
          current = current.add(const Duration(days: 1));
          break;
        case 'weekly':
          current = current.add(const Duration(days: 7));
          break;
        case 'monthly':
          // PRD Section 8: preserve time and select same day number in next month,
          // clamping to that month's final day.
          final targetYear =
              current.month == 12 ? current.year + 1 : current.year;
          final targetMonth = current.month == 12 ? 1 : current.month + 1;
          final daysInTargetMonth =
              DateTime(targetYear, targetMonth + 1, 0).day;
          final targetDay = current.day > daysInTargetMonth
              ? daysInTargetMonth
              : current.day;

          current = DateTime(
            targetYear,
            targetMonth,
            targetDay,
            current.hour,
            current.minute,
            current.second,
            current.millisecond,
            current.microsecond,
          );
          break;
      }
    }

    return current.microsecondsSinceEpoch;
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'title': title,
      'note': note,
      'scope': scope,
      'due_at': dueAt,
      'repeat_rule': repeatRule,
      'is_fired': isFired ? 1 : 0,
      'is_enabled': isEnabled ? 1 : 0,
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

  factory Reminder.fromMap(Map<String, dynamic> map) {
    return Reminder(
      id: map['id']?.toString() ?? '',
      title: map['title']?.toString() ?? '',
      note: map['note']?.toString() ?? '',
      scope: map['scope']?.toString() ?? '',
      dueAt: _parseInt(map['due_at']),
      repeatRule: map['repeat_rule']?.toString() ?? '',
      isFired: _parseInt(map['is_fired']) == 1,
      isEnabled: _parseInt(map['is_enabled']) == 1,
      createdAt: _parseInt(map['created_at']),
      updatedAt: _parseInt(map['updated_at']),
      deletedAt: map['deleted_at'] != null ? _parseInt(map['deleted_at']) : null,
    );
  }
}
