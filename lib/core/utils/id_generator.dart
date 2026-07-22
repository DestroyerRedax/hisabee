import 'package:uuid/uuid.dart';

/// Secure UUID generator for entity identifiers and idempotency keys.
class IdGenerator {
  static const _uuid = Uuid();

  /// Generates a cryptographically secure UUID v4 string.
  static String generateId() {
    return _uuid.v4();
  }
}
