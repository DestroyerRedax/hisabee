import 'package:meta/meta.dart';

/// Value object representing money using integer minor units (Poisha).
/// 
/// 1 Bangladeshi Taka = 100 Poisha.
/// Floating-point types (double, float) are strictly prohibited for financial
/// storage, calculation, or display math.
@immutable
class Money implements Comparable<Money> {
  /// The amount in integer minor units (Poisha).
  final int minorUnits;

  /// Absolute maximum supported minor units: 999,999,999,900 minor units
  /// (9,999,999,999.00 Taka).
  static const int maxSupportedMinorUnits = 999999999900;

  const Money._(this.minorUnits);

  /// Creates a [Money] instance from integer minor units.
  factory Money.fromMinorUnits(int minorUnits) {
    if (minorUnits.abs() > maxSupportedMinorUnits) {
      throw ArgumentError(
        'Amount exceeds maximum supported limit of 999,999,999,900 minor units: $minorUnits',
      );
    }
    return Money._(minorUnits);
  }

  /// Zero money constant.
  static const Money zero = Money._(0);

  /// Parses input string into a [Money] object according to PRD section 6.1.
  ///
  /// Accept format: `-?digits` followed by an optional decimal point and one or two
  /// fractional digits. Commas and leading/trailing spaces are removed.
  /// Throws [FormatException] for invalid inputs, >2 decimal places, or out-of-range values.
  factory Money.parse(String text) {
    final trimmed = text.trim().replaceAll(',', '');
    if (trimmed.isEmpty) {
      throw const FormatException('Cannot parse empty string into Money');
    }

    // Strict regex check for optional negative sign, digits, and optional .D or .DD
    final regex = RegExp(r'^(-?)(\d+)(?:\.(\d{1,2}))?$');
    final match = regex.firstMatch(trimmed);

    if (match == null) {
      throw FormatException('Invalid money format: "$text"');
    }

    final isNegative = match.group(1) == '-';
    final integerPartStr = match.group(2)!;
    final fractionalPartStr = match.group(3);

    final integerPart = int.parse(integerPartStr);
    int fractionalPart = 0;

    if (fractionalPartStr != null) {
      if (fractionalPartStr.length == 1) {
        fractionalPart = int.parse(fractionalPartStr) * 10;
      } else {
        fractionalPart = int.parse(fractionalPartStr);
      }
    }

    final totalMinor = (integerPart * 100) + fractionalPart;
    final finalMinor = isNegative ? -totalMinor : totalMinor;

    if (finalMinor.abs() > maxSupportedMinorUnits) {
      throw FormatException(
        'Parsed amount exceeds maximum supported limit of 999,999,999,900 minor units',
      );
    }

    return Money._(finalMinor);
  }

  /// Validates whether an operational record amount is strictly positive (> 0).
  bool get isPositive => minorUnits > 0;

  /// Returns true if money is negative (< 0).
  bool get isNegative => minorUnits < 0;

  /// Returns true if money is zero (== 0).
  bool get isZero => minorUnits == 0;

  /// Money addition.
  Money operator +(Money other) {
    return Money.fromMinorUnits(minorUnits + other.minorUnits);
  }

  /// Money subtraction.
  Money operator -(Money other) {
    return Money.fromMinorUnits(minorUnits - other.minorUnits);
  }

  /// Money multiplication by integer multiplier.
  Money operator *(int multiplier) {
    return Money.fromMinorUnits(minorUnits * multiplier);
  }

  /// Returns the absolute value of money.
  Money abs() {
    return Money.fromMinorUnits(minorUnits.abs());
  }

  /// Unary negation.
  Money operator -() {
    return Money.fromMinorUnits(-minorUnits);
  }

  bool operator >(Money other) => minorUnits > other.minorUnits;
  bool operator <(Money other) => minorUnits < other.minorUnits;
  bool operator >=(Money other) => minorUnits >= other.minorUnits;
  bool operator <=(Money other) => minorUnits <= other.minorUnits;

  @override
  int compareTo(Money other) => minorUnits.compareTo(other.minorUnits);

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Money &&
          runtimeType == other.runtimeType &&
          minorUnits == other.minorUnits;

  @override
  int get hashCode => minorUnits.hashCode;

  /// Returns a plain decimal string representation (e.g. `12.50` or `-12.50`).
  String toDecimalString() {
    final absMinor = minorUnits.abs();
    final integerPart = absMinor ~/ 100;
    final fractionalPart = (absMinor % 100).toString().padLeft(2, '0');
    final sign = isNegative ? '-' : '';
    return '$sign$integerPart.$fractionalPart';
  }

  /// Formats the money value with Bangladeshi Taka symbol `৳` and 2 decimal places.
  /// Example: `৳ 12.50` or `-৳ 12.50`.
  String formatTaka() {
    final absMinor = minorUnits.abs();
    final integerPart = absMinor ~/ 100;
    final fractionalPart = (absMinor % 100).toString().padLeft(2, '0');
    final sign = isNegative ? '-' : '';
    return '${sign}৳ $integerPart.$fractionalPart';
  }

  @override
  String toString() => 'Money($minorUnits poisha -> ${formatTaka()})';
}
