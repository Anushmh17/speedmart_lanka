import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class AppNotification {
  final String id;
  final String title;
  final String body;
  final IconData icon;
  final Color color;
  final DateTime timestamp;

  AppNotification({
    required this.id,
    required this.title,
    required this.body,
    required this.icon,
    this.color = const Color(0xFFFFB300),
    DateTime? timestamp,
  }) : timestamp = timestamp ?? DateTime.now();
}

class NotificationState {
  final List<AppNotification> notifications;
  final AppNotification? activeBanner;

  const NotificationState({
    this.notifications = const [],
    this.activeBanner,
  });

  NotificationState copyWith({
    List<AppNotification>? notifications,
    AppNotification? activeBanner,
    bool clearBanner = false,
  }) {
    return NotificationState(
      notifications: notifications ?? this.notifications,
      activeBanner: clearBanner ? null : (activeBanner ?? this.activeBanner),
    );
  }
}

class NotificationNotifier extends StateNotifier<NotificationState> {
  NotificationNotifier() : super(const NotificationState());

  Timer? _bannerTimer;

  void triggerNotification({
    required String title,
    required String body,
    required IconData icon,
    Color color = const Color(0xFFFFB300),
  }) {
    final notification = AppNotification(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      title: title,
      body: body,
      icon: icon,
      color: color,
    );

    // Cancel old timer if any
    _bannerTimer?.cancel();

    state = state.copyWith(
      notifications: [notification, ...state.notifications],
      activeBanner: notification,
    );

    // Auto-hide the slide-down banner after 4 seconds
    _bannerTimer = Timer(const Duration(seconds: 4), () {
      state = state.copyWith(clearBanner: true);
    });
  }

  void dismissActiveBanner() {
    _bannerTimer?.cancel();
    state = state.copyWith(clearBanner: true);
  }
}

final notificationProvider = StateNotifierProvider<NotificationNotifier, NotificationState>((ref) {
  return NotificationNotifier();
});

