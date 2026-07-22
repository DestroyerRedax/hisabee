import 'package:flutter/services.dart';
import 'package:local_auth/local_auth.dart';

/// Handles platform biometric availability checks and sticky biometric authentication (PRD Section 11).
class BiometricAuthService {
  final LocalAuthentication _localAuth;

  BiometricAuthService({LocalAuthentication? localAuth})
      : _localAuth = localAuth ?? LocalAuthentication();

  Future<bool> isBiometricAvailable() async {
    try {
      final canAuthenticateWithBiometrics = await _localAuth.canCheckBiometrics;
      final isDeviceSupported = await _localAuth.isDeviceSupported();
      return canAuthenticateWithBiometrics && isDeviceSupported;
    } catch (_) {
      return false; // Platform exception returns false, never app crash
    }
  }

  Future<bool> authenticateBiometric({required String reason}) async {
    try {
      final available = await isBiometricAvailable();
      if (!available) return false;

      return await _localAuth.authenticate(
        localizedReason: reason,
        options: const AuthenticationOptions(
          biometricOnly: true, // PRD 11: Biometric-only, sticky authentication
          stickyAuth: true,
          useErrorDialogs: true,
        ),
      );
    } on PlatformException catch (_) {
      return false; // Platform exceptions return failure, not app crash
    } catch (_) {
      return false;
    }
  }
}
