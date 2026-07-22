import 'package:flutter/services.dart';

/// Screen capture protection and app-switcher sensitive content redaction helper (PRD Section 11).
class ScreenProtectionService {
  static const MethodChannel _channel = MethodChannel('com.hisabee.app/screen_protection');

  /// Requests the operating system to prevent screenshots and redact app-switcher preview.
  static Future<bool> enableScreenProtection() async {
    try {
      final bool success = await _channel.invokeMethod('enableScreenProtection') ?? false;
      return success;
    } on PlatformException catch (_) {
      return false; // Safely handle unsupported environments
    } on MissingPluginException catch (_) {
      return false;
    }
  }
}
