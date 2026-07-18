import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

/// Initializes Android local notifications with the app drawable icon.
class LocalNotificationService {
  LocalNotificationService._();

  static final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();

  static bool _initialized = false;

  /// Must match android/app/src/main/res/drawable/ic_notification.xml
  static const String androidIcon = 'ic_notification';

  static Future<void> initialize() async {
    if (_initialized) return;

    const androidSettings = AndroidInitializationSettings(androidIcon);
    const iosSettings = DarwinInitializationSettings();
    const settings = InitializationSettings(
      android: androidSettings,
      iOS: iosSettings,
    );

    try {
      await _plugin.initialize(settings);

      const channel = AndroidNotificationChannel(
        'speedmart_default',
        'Speedmart Notifications',
        description: 'Order and request updates',
        importance: Importance.defaultImportance,
      );

      await _plugin
          .resolvePlatformSpecificImplementation<
              AndroidFlutterLocalNotificationsPlugin>()
          ?.createNotificationChannel(channel);

      _initialized = true;
    } catch (e, st) {
      debugPrint('[LocalNotificationService] init failed: $e\n$st');
    }
  }
}
