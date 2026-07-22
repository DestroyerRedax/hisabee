import 'package:test/test.dart';
import 'package:hisabee/domain/parser/transaction_message_parser.dart';

void main() {
  group('Transaction Message Parser Regression Corpus Tests', () {
    late TransactionMessageParser parser;

    setUp(() {
      parser = const TransactionMessageParser();
    });

    test('1. Bengali digits conversion and bKash received SMS parsing', () {
      const sms = 'You have received Tk 1,500.00 from 01712345678 via bKash. Ref 123. Fee Tk 0.00. Balance Tk 5,500.00. 2026-07-22 14:30';
      final res = parser.parse(sms);

      expect(res.candidates.length, equals(1));
      final candidate = res.candidates.first;

      expect(candidate.direction, equals('received'));
      expect(candidate.method, equals('bkash'));
      expect(candidate.phone, equals('01712345678'));
      expect(candidate.amount?.minorUnits, equals(150000)); // 1,500.00 Taka
      expect(candidate.localDate, equals('2026-07-22'));
      expect(candidate.localTime, equals('14:30'));
      expect(candidate.canSave, isTrue);
      expect(candidate.confidence, greaterThanOrEqualTo(0.8));
    });

    test('2. Nagad Cash Out (Gave) SMS with Bengali digits parsing', () {
      const sms = 'Cash Out Tk ২,০০০.০০ to 01812345678 via Nagad is successful. 22/07/2026 09:15 AM. TxnID 9876';
      final res = parser.parse(sms);

      expect(res.candidates.length, equals(1));
      final candidate = res.candidates.first;

      expect(candidate.direction, equals('gave'));
      expect(candidate.phone, equals('01812345678'));
      expect(candidate.amount?.minorUnits, equals(200000)); // 2000.00
      expect(candidate.localDate, equals('2026-07-22'));
      expect(candidate.localTime, equals('09:15'));
      expect(candidate.canSave, isTrue);
    });

    test('3. Gave transaction without phone number fails canSave predicate', () {
      const sms = 'Sent Tk 500.00 via Rocket. 2026-07-22';
      final res = parser.parse(sms);

      expect(res.candidates.length, equals(1));
      final candidate = res.candidates.first;

      expect(candidate.direction, equals('gave'));
      expect(candidate.phone, isNull);
      expect(candidate.canSave, isFalse); // Gave direction REQUIRES phone number!
    });

    test('4. Bank Name party fallback for Received transaction', () {
      const sms = 'Deposit BDT 10,000.00 from Islami Bank. Date: 2026-07-22 11:00 AM';
      final res = parser.parse(sms);

      expect(res.candidates.length, equals(1));
      final candidate = res.candidates.first;

      expect(candidate.direction, equals('received'));
      expect(candidate.method, equals('bank'));
      expect(candidate.bankName, equals('Islami Bank'));
      expect(candidate.phone, isNull);
      expect(candidate.canSave, isTrue); // Received transaction can use Bank name fallback without phone
    });

    test('5. 32,000 character limit truncation warning', () {
      final longText = 'A' * 35000;
      final res = parser.parse(longText);

      expect(res.globalWarnings, contains('Input text truncated to 32,000 characters'));
    });

    test('6. Calendar overflow date rejection (invalid 31 Feb)', () {
      const sms = 'Received Tk 100 from 01912345678 via bKash on 31-02-2026';
      final res = parser.parse(sms);

      final candidate = res.candidates.first;
      expect(candidate.localDate, isNull); // 31 Feb rejected
    });
  });
}
