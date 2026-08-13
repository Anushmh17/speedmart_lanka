
import 'package:firebase_app_check/firebase_app_check.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:speedmart_lanka/firebase_options.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:speedmart_lanka/core/routes/app_router.dart';
import 'package:speedmart_lanka/core/storage/storage_service.dart';
import 'package:speedmart_lanka/features/auth/data/auth_repository.dart';

/// FCM helper: initialize, obtain token, handle taps and token refresh.
class FcmService {
  FcmService._();

  static final FirebaseMessaging _messaging = FirebaseMessaging.instance;

  static Future<void> initialize() async {
    try {
      await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
      await FirebaseAppCheck.instance.activate(
        androidProvider: kDebugMode ? AndroidProvider.debug : AndroidProvider.playIntegrity,
      );
    } catch (_) {}

    // Request permission on iOS
    await _messaging.requestPermission(alert: true, badge: true, sound: true);

    // Handle background/message taps when app is terminated
    FirebaseMessaging.instance.getInitialMessage().then((message) {
      if (message != null) _handleMessageOpened(message);
    });

    // When app is in background and opened from a notification
    FirebaseMessaging.onMessageOpenedApp.listen(_handleMessageOpened);

    // Token refresh handling
    FirebaseMessaging.instance.onTokenRefresh.listen((token) {
      debugPrint('[FCM] token refreshed: $token');
      try {
        StorageService.saveFcmToken(token);
      } catch (e) {
        debugPrint('[FCM] failed to persist token: $e');
      }
      try {
        AuthRepository.instance.handleFcmTokenRefresh(token);
      } catch (e) {
        debugPrint('[FCM] AuthRepository not ready: $e');
      }
    });
  }

  static Future<String?> getToken() async {
    try {
      final token = await _messaging.getToken();
      debugPrint('[FCM] getToken: $token');
      return token;
    } catch (e) {
      debugPrint('[FCM] getToken error: $e');
      return null;
    }
  }

  // ── Topic Management ────────────────────────────────────────────────────────

  /// Normalises a district string to the same slug format used server-side.
  /// e.g. "Colombo District" → "colombo_district"
  static String _toTopicSlug(String district) =>
      district.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]'), '_');

  /// Subscribe an approved vendor to their district request topic + global fallback.
  /// Call this immediately after vendor login / session restore.
  ///
  /// [shopDistrict] – the vendor's assigned district (e.g. "Colombo").
  ///                  Pass null to subscribe only to the global topic.
  static Future<void> subscribeVendorToTopics({String? shopDistrict}) async {
    try {
      // Always subscribe to the global catch-all topic
      await _messaging.subscribeToTopic('vendor_requests_all');
      debugPrint('[FCM] Subscribed to topic: vendor_requests_all');

      if (shopDistrict != null && shopDistrict.isNotEmpty) {
        final slug = _toTopicSlug(shopDistrict);
        await _messaging.subscribeToTopic('vendor_requests_$slug');
        debugPrint('[FCM] Subscribed to topic: vendor_requests_$slug');
      }
    } catch (e) {
      debugPrint('[FCM] subscribeVendorToTopics error: $e');
    }
  }

  /// Unsubscribe the vendor from all request topics on logout.
  /// [shopDistrict] – same district string used when subscribing.
  static Future<void> unsubscribeVendorFromTopics({String? shopDistrict}) async {
    try {
      await _messaging.unsubscribeFromTopic('vendor_requests_all');
      debugPrint('[FCM] Unsubscribed from topic: vendor_requests_all');

      if (shopDistrict != null && shopDistrict.isNotEmpty) {
        final slug = _toTopicSlug(shopDistrict);
        await _messaging.unsubscribeFromTopic('vendor_requests_$slug');
        debugPrint('[FCM] Unsubscribed from topic: vendor_requests_$slug');
      }
    } catch (e) {
      debugPrint('[FCM] unsubscribeVendorFromTopics error: $e');
    }
  }

  static void _handleMessageOpened(RemoteMessage message) {
    try {
      final data = message.data;
      final route = data['route'] as String? ?? data['deep_link'] as String?;
      if (route != null && rootNavigatorKey.currentContext != null) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          try {
            GoRouter.of(rootNavigatorKey.currentContext!).go(route);
          } catch (_) {
            GoRouter.of(rootNavigatorKey.currentContext!).go(route);
          }
        });
      }
    } catch (e) {
      debugPrint('[FCM] onOpen error: $e');
    }
  }
}
