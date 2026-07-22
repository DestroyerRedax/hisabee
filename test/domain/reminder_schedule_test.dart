import 'package:test/test.dart';
import 'package:hisabee/domain/entities/reminder.dart';

void main() {
  group('PRD Section 8 Reminder Schedule Algorithm Tests', () {
    test('1. Disabled reminder returns null next due date', () {
      final nextDue = Reminder.calculateNextDueTimestamp(
        dueAtMicroseconds: DateTime(2026, 1, 15, 10, 0).microsecondsSinceEpoch,
        repeatRule: 'daily',
        isEnabled: false,
        comparisonMicroseconds: DateTime(2026, 1, 15, 9, 0).microsecondsSinceEpoch,
      );
      expect(nextDue, isNull);
    });

    test('2. Non-repeating reminder returns dueAt only if strictly after comparison', () {
      final due = DateTime(2026, 1, 15, 10, 0).microsecondsSinceEpoch;
      final beforeComp = DateTime(2026, 1, 15, 9, 0).microsecondsSinceEpoch;
      final afterComp = DateTime(2026, 1, 15, 11, 0).microsecondsSinceEpoch;

      expect(
        Reminder.calculateNextDueTimestamp(
          dueAtMicroseconds: due,
          repeatRule: 'none',
          isEnabled: true,
          comparisonMicroseconds: beforeComp,
        ),
        equals(due),
      );

      expect(
        Reminder.calculateNextDueTimestamp(
          dueAtMicroseconds: due,
          repeatRule: 'none',
          isEnabled: true,
          comparisonMicroseconds: afterComp,
        ),
        isNull,
      );
    });

    test('3. Daily repeating reminder advances day by day', () {
      final due = DateTime(2026, 1, 15, 10, 0).microsecondsSinceEpoch;
      final comp = DateTime(2026, 1, 15, 10, 0).microsecondsSinceEpoch;

      final nextDueUs = Reminder.calculateNextDueTimestamp(
        dueAtMicroseconds: due,
        repeatRule: 'daily',
        isEnabled: true,
        comparisonMicroseconds: comp,
      );

      expect(
        DateTime.fromMicrosecondsSinceEpoch(nextDueUs!),
        equals(DateTime(2026, 1, 16, 10, 0)),
      );
    });

    test('4. Monthly repeating reminder clamps 31 Jan to 28 Feb (non-leap year)', () {
      final jan31 = DateTime(2026, 1, 31, 14, 30).microsecondsSinceEpoch;
      final comp = DateTime(2026, 1, 31, 14, 30).microsecondsSinceEpoch;

      final febNext = Reminder.calculateNextDueTimestamp(
        dueAtMicroseconds: jan31,
        repeatRule: 'monthly',
        isEnabled: true,
        comparisonMicroseconds: comp,
      );

      final resultDt = DateTime.fromMicrosecondsSinceEpoch(febNext!);
      expect(resultDt, equals(DateTime(2026, 2, 28, 14, 30)));
    });

    test('5. Monthly repeating reminder clamps 31 Jan to 29 Feb (leap year 2028)', () {
      final jan31Leap = DateTime(2028, 1, 31, 14, 30).microsecondsSinceEpoch;
      final comp = DateTime(2028, 1, 31, 14, 30).microsecondsSinceEpoch;

      final febNext = Reminder.calculateNextDueTimestamp(
        dueAtMicroseconds: jan31Leap,
        repeatRule: 'monthly',
        isEnabled: true,
        comparisonMicroseconds: comp,
      );

      final resultDt = DateTime.fromMicrosecondsSinceEpoch(febNext!);
      expect(resultDt, equals(DateTime(2028, 2, 29, 14, 30)));
    });

    test('6. Monthly repeating reminder advances through 30-day and 31-day months', () {
      final aug31 = DateTime(2026, 8, 31, 9, 0).microsecondsSinceEpoch;
      final comp = DateTime(2026, 8, 31, 9, 0).microsecondsSinceEpoch;

      final sepNext = Reminder.calculateNextDueTimestamp(
        dueAtMicroseconds: aug31,
        repeatRule: 'monthly',
        isEnabled: true,
        comparisonMicroseconds: comp,
      );

      // Sept has 30 days -> Clamps to Sept 30
      expect(
        DateTime.fromMicrosecondsSinceEpoch(sepNext!),
        equals(DateTime(2026, 9, 30, 9, 0)),
      );
    });
  });
}
