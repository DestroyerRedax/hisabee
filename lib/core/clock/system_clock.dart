import 'clock.dart';

/// Real system clock implementation.
class SystemClock implements Clock {
  const SystemClock();

  @override
  DateTime now() => DateTime.now();

  @override
  int nowMicroseconds() => DateTime.now().microsecondsSinceEpoch;
}

/// Fixed or controllable clock for deterministic testing.
class TestClock implements Clock {
  DateTime _currentTime;

  TestClock(this._currentTime);

  void setTime(DateTime newTime) {
    _currentTime = newTime;
  }

  void advanceBy(Duration duration) {
    _currentTime = _currentTime.add(duration);
  }

  @override
  DateTime now() => _currentTime;

  @override
  int nowMicroseconds() => _currentTime.microsecondsSinceEpoch;
}
