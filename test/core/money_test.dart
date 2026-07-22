import 'package:test/test.dart';
import 'package:hisabee/core/money/money.dart';

void main() {
  group('Money Value Object Tests', () {
    test('1. Minor units initialization and equality', () {
      final m1 = Money.fromMinorUnits(1500); // 15.00 Taka
      final m2 = Money.fromMinorUnits(1500);
      expect(m1, equals(m2));
      expect(m1.minorUnits, equals(1500));
    });

    test('2. Parse valid taka text format', () {
      expect(Money.parse('100').minorUnits, equals(10000));
      expect(Money.parse('12.5').minorUnits, equals(1250)); // Pads .5 to .50
      expect(Money.parse('12.50').minorUnits, equals(1250));
      expect(Money.parse('  1,000.50 ').minorUnits, equals(100050));
      expect(Money.parse('-50.25').minorUnits, equals(-5025));
    });

    test('3. Parse invalid format throws FormatException', () {
      expect(() => Money.parse('12.505'), throwsFormatException); // > 2 decimal places
      expect(() => Money.parse('abc'), throwsFormatException);
      expect(() => Money.parse(''), throwsFormatException);
      expect(() => Money.parse('12.3.4'), throwsFormatException);
    });

    test('4. Exceeding max supported limit (999,999,999,900) throws error', () {
      expect(
        () => Money.fromMinorUnits(999999999901),
        throwsArgumentError,
      );
    });

    test('5. Operational record positivity check', () {
      expect(Money.fromMinorUnits(100).isPositive, isTrue);
      expect(Money.fromMinorUnits(0).isPositive, isFalse);
      expect(Money.fromMinorUnits(-100).isPositive, isFalse);
    });

    test('6. Arithmetic operations on integer minor units', () {
      final a = Money.fromMinorUnits(500);
      final b = Money.fromMinorUnits(250);

      expect((a + b).minorUnits, equals(750));
      expect((a - b).minorUnits, equals(250));
      expect((a * 3).minorUnits, equals(1500));
      expect(a > b, isTrue);
      expect(b < a, isTrue);
    });

    test('7. Formatting with Taka symbol and 2 decimal places', () {
      final m = Money.fromMinorUnits(1250);
      expect(m.toDecimalString(), equals('12.50'));
      expect(m.formatTaka(), equals('৳ 12.50'));

      final neg = Money.fromMinorUnits(-500);
      expect(neg.toDecimalString(), equals('-5.00'));
      expect(neg.formatTaka(), equals('-৳ 5.00'));
    });
  });
}
