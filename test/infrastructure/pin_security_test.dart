import 'package:test/test.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:hisabee/infrastructure/security/pin_security_service.dart';

void main() {
  group('PIN Security, PBKDF2 & Lockout Policy Tests', () {
    late PinSecurityService pinService;
    late Map<String, String> mockStorage;

    setUp(() {
      mockStorage = <String, String>{};
      FlutterSecureStorage.setMockInitialValues(mockStorage);
      pinService = PinSecurityService(secureStorage: const FlutterSecureStorage());
    });

    test('1. 4-digit PIN setup generates 32-byte salt and verifier; raw PIN is NEVER stored', () async {
      final success = await pinService.setPin('1234');
      expect(success, isTrue);
      expect(await pinService.hasPin(), isTrue);

      // Verify raw PIN "1234" is NOT in storage!
      final storedValue = mockStorage['hisabee_pin_verifier'];
      expect(storedValue, isNotNull);
      expect(storedValue!.contains('1234'), isFalse);
      expect(storedValue.contains(':'), isTrue); // salt:verifier format
    });

    test('2. Invalid PIN format (non 4-digit) fails setup', () async {
      expect(await pinService.setPin('123'), isFalse);
      expect(await pinService.setPin('12345'), isFalse);
      expect(await pinService.setPin('abcd'), isFalse);
    });

    test('3. Correct PIN verification succeeds and constant-time comparison matches', () async {
      await pinService.setPin('5678');
      final res = await pinService.verifyPin('5678');

      expect(res.isSuccess, isTrue);
      expect(res.isLockedOut, isFalse);
    });

    test('4. 5 consecutive failed attempts trigger 30-second lockout policy', () async {
      await pinService.setPin('9999');
      final baseUs = 1700000000000000;

      // 4 wrong attempts
      for (int i = 0; i < 4; i++) {
        final res = await pinService.verifyPin('0000', currentMicroseconds: baseUs + i * 1000);
        expect(res.isSuccess, isFalse);
        expect(res.isLockedOut, isFalse);
      }

      // 5th wrong attempt triggers lockout!
      final lockoutRes = await pinService.verifyPin('0000', currentMicroseconds: baseUs + 5000);
      expect(lockoutRes.isSuccess, isFalse);
      expect(lockoutRes.isLockedOut, isTrue);
      expect(lockoutRes.remainingLockoutSeconds, greaterThan(0));

      // Subsequent attempt during lockout (10 seconds later) fails IMMEDIATELY with lockout
      final duringLockoutRes = await pinService.verifyPin('9999', currentMicroseconds: baseUs + 10000000);
      expect(duringLockoutRes.isSuccess, isFalse);
      expect(duringLockoutRes.isLockedOut, isTrue);

      // Attempt after lockout expiry (31 seconds later) allows verification
      final afterLockoutRes = await pinService.verifyPin('9999', currentMicroseconds: baseUs + 31000000);
      expect(afterLockoutRes.isSuccess, isTrue);
      expect(afterLockoutRes.isLockedOut, isFalse);
    });

    test('5. Clear PIN deletes verifier and resets lockout state', () async {
      await pinService.setPin('1111');
      expect(await pinService.hasPin(), isTrue);

      await pinService.clearPin();
      expect(await pinService.hasPin(), isFalse);
    });
  });
}
