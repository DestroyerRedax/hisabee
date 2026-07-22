import 'dart:convert';
import 'dart:math';
import 'package:crypto/crypto.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class PinVerificationResult {
  final bool isSuccess;
  final bool isLockedOut;
  final int remainingLockoutSeconds;
  final String? errorMessage;

  const PinVerificationResult({
    required this.isSuccess,
    this.isLockedOut = false,
    this.remainingLockoutSeconds = 0,
    this.errorMessage,
  });
}

/// Handles PIN hashing, verifier storage, constant-time comparison, and 5-failure lockout policy (PRD Section 11).
class PinSecurityService {
  final FlutterSecureStorage _secureStorage;

  static const String _pinVerifierKey = 'hisabee_pin_verifier';
  static const String _failedAttemptsKey = 'hisabee_pin_failed_attempts';
  static const String _lockoutExpiryKey = 'hisabee_pin_lockout_expiry';

  PinSecurityService({FlutterSecureStorage? secureStorage})
      : _secureStorage = secureStorage ?? const FlutterSecureStorage();

  /// Sets a new 4-digit PIN using PBKDF2-HMAC-SHA-256 at 210,000 iterations with 32-byte salt.
  Future<bool> setPin(String pin) async {
    if (!RegExp(r'^\d{4}$').hasMatch(pin)) {
      return false; // Must be exactly 4 ASCII digits
    }

    final saltBytes = _generate32ByteSalt();
    final verifierBytes = _pbkdf2(pin, saltBytes, iterations: 210000, keyLength: 32);

    final saltBase64 = base64Url.encode(saltBytes).replaceAll('=', '');
    final verifierBase64 = base64Url.encode(verifierBytes).replaceAll('=', '');
    final storedValue = '$saltBase64:$verifierBase64';

    await _secureStorage.write(key: _pinVerifierKey, value: storedValue);
    await clearLockoutState();
    return true;
  }

  /// Verifies entered PIN against stored verifier using constant-time comparison.
  Future<PinVerificationResult> verifyPin(String pin, {int? currentMicroseconds}) async {
    final nowMs = currentMicroseconds ?? DateTime.now().microsecondsSinceEpoch;

    // Check lockout state
    final lockoutExpiryStr = await _secureStorage.read(key: _lockoutExpiryKey);
    if (lockoutExpiryStr != null) {
      final lockoutExpiry = int.tryParse(lockoutExpiryStr) ?? 0;
      if (nowMs < lockoutExpiry) {
        final remainingUs = lockoutExpiry - nowMs;
        final remainingSec = (remainingUs / 1000000).ceil();
        return PinVerificationResult(
          isSuccess: false,
          isLockedOut: true,
          remainingLockoutSeconds: remainingSec,
          errorMessage: 'PIN verification locked for 30 seconds due to 5 failed attempts',
        );
      }
    }

    final storedValue = await _secureStorage.read(key: _pinVerifierKey);
    if (storedValue == null) {
      return const PinVerificationResult(
        isSuccess: false,
        errorMessage: 'No PIN is set',
      );
    }

    final parts = storedValue.split(':');
    if (parts.length != 2) {
      return const PinVerificationResult(
        isSuccess: false,
        errorMessage: 'Malformed PIN verifier data',
      );
    }

    List<int> saltBytes;
    List<int> storedVerifierBytes;
    try {
      saltBytes = base64Url.decode(base64Url.normalize(parts[0]));
      storedVerifierBytes = base64Url.decode(base64Url.normalize(parts[1]));
    } catch (_) {
      return const PinVerificationResult(
        isSuccess: false,
        errorMessage: 'Corrupted PIN verifier storage',
      );
    }

    final computedVerifierBytes = _pbkdf2(pin, saltBytes, iterations: 210000, keyLength: 32);
    final isValid = _constantTimeCompare(computedVerifierBytes, storedVerifierBytes);

    if (isValid) {
      await clearLockoutState();
      return const PinVerificationResult(isSuccess: true);
    } else {
      // Increment failed attempt count
      final attemptsStr = await _secureStorage.read(key: _failedAttemptsKey);
      final currentAttempts = (int.tryParse(attemptsStr ?? '0') ?? 0) + 1;
      await _secureStorage.write(key: _failedAttemptsKey, value: currentAttempts.toString());

      if (currentAttempts >= 5) {
        // Lock for 30 seconds (30,000,000 microseconds)
        final lockoutExpiry = nowMs + 30000000;
        await _secureStorage.write(key: _lockoutExpiryKey, value: lockoutExpiry.toString());
        return const PinVerificationResult(
          isSuccess: false,
          isLockedOut: true,
          remainingLockoutSeconds: 30,
          errorMessage: '5 failed PIN attempts. Verification locked for 30 seconds.',
        );
      }

      return PinVerificationResult(
        isSuccess: false,
        errorMessage: 'Invalid PIN. Remaining attempts before lockout: ${5 - currentAttempts}',
      );
    }
  }

  Future<bool> hasPin() async {
    final stored = await _secureStorage.read(key: _pinVerifierKey);
    return stored != null && stored.isNotEmpty;
  }

  Future<void> clearPin() async {
    await _secureStorage.delete(key: _pinVerifierKey);
    await clearLockoutState();
  }

  Future<void> clearLockoutState() async {
    await _secureStorage.delete(key: _failedAttemptsKey);
    await _secureStorage.delete(key: _lockoutExpiryKey);
  }

  List<int> _generate32ByteSalt() {
    final random = Random.secure();
    return List<int>.generate(32, (_) => random.nextInt(256));
  }

  /// PBKDF2-HMAC-SHA-256 implementation
  List<int> _pbkdf2(String password, List<int> salt, {required int iterations, required int keyLength}) {
    final passwordBytes = utf8.encode(password);
    final hmac = Hmac(sha256, passwordBytes);

    final numBlocks = (keyLength / 32).ceil();
    final result = <int>[];

    for (int i = 1; i <= numBlocks; i++) {
      final blockSalt = List<int>.from(salt)
        ..addAll([(i >> 24) & 0xff, (i >> 16) & 0xff, (i >> 8) & 0xff, i & 0xff]);

      var u = hmac.convert(blockSalt).bytes;
      final t = List<int>.from(u);

      for (int iter = 1; iter < iterations; iter++) {
        u = hmac.convert(u).bytes;
        for (int k = 0; k < t.length; k++) {
          t[k] ^= u[k];
        }
      }
      result.addAll(t);
    }

    return result.sublist(0, keyLength);
  }

  /// Constant-time comparison to prevent timing side-channel attacks.
  bool _constantTimeCompare(List<int> a, List<int> b) {
    if (a.length != b.length) return false;
    int result = 0;
    for (int i = 0; i < a.length; i++) {
      result |= a[i] ^ b[i];
    }
    return result == 0;
  }
}
