import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:speedmart_lanka/core/theme/app_colors.dart';
import 'package:speedmart_lanka/core/routes/app_router.dart';
import 'package:go_router/go_router.dart';

/// Initializes Android local notifications with the app drawable icon.
class LocalNotificationService {
  LocalNotificationService._();

  static final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();

  static bool _initialized = false;

  /// Must match android/app/src/main/res/drawable/ic_notification.png
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
      await _plugin.initialize(
        settings,
        onDidReceiveNotificationResponse: (response) {
          try {
            final payload = response.payload;
            if (payload != null && payload.isNotEmpty) {
              final Map<String, dynamic> map = jsonDecode(payload);
              final route = map['route'] as String?;
              final extra = map['extra'];
              if (route != null && rootNavigatorKey.currentContext != null) {
                GoRouter.of(rootNavigatorKey.currentContext!).go(route, extra: extra);
              }
            }
          } catch (e) {
            debugPrint('[LocalNotificationService] onResponse error: $e');
          }
        },
      );

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

  /// Show a platform notification with an optional JSON payload.
  static Future<void> showNotification({
    required int id,
    required String title,
    required String body,
    Map<String, dynamic>? payload,
  }) async {
    await initialize();

    final androidDetails = AndroidNotificationDetails(
      'speedmart_default',
      'Speedmart Notifications',
      channelDescription: 'Order and request updates',
      importance: Importance.defaultImportance,
      playSound: true,
      icon: androidIcon,
      color: AppColors.primary,
    );

    final details = NotificationDetails(android: androidDetails);

    await _plugin.show(
      id,
      title,
      body,
      details,
      payload: payload != null ? jsonEncode(payload) : null,
    );
  }
}
