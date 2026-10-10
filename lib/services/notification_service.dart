// Local notifications: budget 80% / 100% alerts + foreground FCM messages.
// Uses flutter_local_notifications (no external service required) with an
// Android notification channel "budget_alerts".

import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

import '../utils/constants.dart';
import 'firebase_service.dart';

abstract final class NotificationService {
  static final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();

  static const String _channelId = 'budget_alerts';
  static const String _channelName = 'تنبيهات الميزانية';
  static const String _channelDesc = 'تنبيهات عند اقتراب أو تجاوز الميزانية';

  static bool _initialized = false;

  static Future<void> init() async {
    if (_initialized) return;
    try {
      const AndroidInitializationSettings android =
          AndroidInitializationSettings('@mipmap/launcher_icon');
      const InitializationSettings settings =
          InitializationSettings(android: android);
      await _plugin.initialize(settings);
      // Android 13+ runtime permission.
      await _plugin
          .resolvePlatformSpecificImplementation<
              AndroidFlutterLocalNotificationsPlugin>()
          ?.requestNotificationsPermission();
      _initialized = true;
    } catch (_) {
      // Notification permission denied — the in-app alerts still work.
    }
  }

  static Future<void> show({
    required int id,
    required String title,
    required String body,
  }) async {
    if (!_initialized) await init();
    try {
      const AndroidNotificationDetails android = AndroidNotificationDetails(
        _channelId,
        _channelName,
        channelDescription: _channelDesc,
        importance: Importance.high,
        priority: Priority.high,
        color: AppColors.green,
        ledColor: AppColors.green,
        ledOnMs: 300,
        ledOffMs: 500,
      );
      const NotificationDetails details = NotificationDetails(android: android);
      await _plugin.show(id, title, body, details);
    } catch (_) {}
  }

  /// Bridges FCM foreground messages into local notifications.
  static Future<void> initFcmForegroundBridge() async {
    await FcmService.onMessageHandler((RemoteMessage message) async {
      final String title = message.notification?.title ?? 'المحاسب الذكي';
      final String body =
          message.notification?.body ?? message.data['body'] ?? '';
      await show(
        id: message.messageId?.hashCode ?? DateTime.now().millisecond,
        title: title,
        body: body,
      );
    });
  }

  /// Unique-but-stable notification id per category+threshold per month.
  static int budgetAlertId(String category, int percent) =>
      ('budget_${DateTime.now().month}_$category$percent').hashCode &
      0x7fffffff;
}
