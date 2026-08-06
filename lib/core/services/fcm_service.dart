import 'dart:convert';

import 'package:firebase_core/firebase_core.dart';
import 'package:speedmart_lanka/firebase_options.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
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
      // persist token locally
      try {
        StorageService.saveFcmToken(token);
      } catch (e) {
        debugPrint('[FCM] failed to persist token: $e');
      }
      // notify auth repo to upload if a user is logged in
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

  static void _handleMessageOpened(RemoteMessage message) {
    try {
      final data = message.data;
      final route = data['route'] as String? ?? data['deep_link'] as String?;
      if (route != null && rootNavigatorKey.currentContext != null) {
        // Use GoRouter to navigate
        WidgetsBinding.instance.addPostFrameCallback((_) {
          try {
            final uri = Uri.parse(route);
            // If route contains query or path with id, just go to it
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
