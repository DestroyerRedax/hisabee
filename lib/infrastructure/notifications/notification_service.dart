import 'package:flutter_local_notifications/flutter_local_notifications.dart';

/// Action-triggered local notification permission and scheduling service (PRD Section 4.2).
class NotificationService {
  final FlutterLocalNotificationsPlugin _notificationsPlugin;

  NotificationService({FlutterLocalNotificationsPlugin? notificationsPlugin})
      : _notificationsPlugin = notificationsPlugin ?? FlutterLocalNotificationsPlugin();

  Future<bool> initialize() async {
    const androidInit = AndroidInitializationSettings('@mipmap/ic_launcher');
    const initSettings = InitializationSettings(android: androidInit);

    try {
      final initialized = await _notificationsPlugin.initialize(initSettings) ?? false;
      return initialized;
    } catch (_) {
      return false;
    }
  }

  Future<bool> requestPermission() async {
    try {
      final androidPlatform = _notificationsPlugin.resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin>();
      if (androidPlatform != null) {
        final granted = await androidPlatform.requestNotificationsPermission();
        return granted ?? false;
      }
      return false;
    } catch (_) {
      return false;
    }
  }
}
