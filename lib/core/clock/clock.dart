/// Clock abstraction for deterministic time and timestamp generation during testing.
abstract class Clock {
  /// Returns current DateTime.
  DateTime now();

  /// Returns current Unix epoch timestamp in microseconds.
  int nowMicroseconds() {
    return now().microsecondsSinceEpoch;
  }
}
