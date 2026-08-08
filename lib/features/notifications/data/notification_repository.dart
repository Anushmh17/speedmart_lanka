import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../../core/services/firestore_service.dart';
import '../../../core/storage/storage_service.dart';
import '../models/notification_model.dart';

/// Notification repository — Firestore-backed.
class NotificationRepository {
  NotificationRepository._() {
    _initFuture = _initialize();
  }

  static final NotificationRepository instance =
      NotificationRepository._();

  static const String _notificationsCollectionPath = 'notifications';

  late Future<void> _initFuture;
  bool _isInitialized = false;

  final List<NotificationModel> _notifications = [];

  CollectionReference<Map<String, dynamic>> get _notificationsCollection =>
      FirestoreService.collection(_notificationsCollectionPath);

  Future<List<Map<String, dynamic>>> _fetchNotificationsFromFirestore() async {
    if (FirebaseAuth.instance.currentUser == null) return [];
    try {
      final query = await _notificationsCollection.limit(500).get();
      return query.docs.map((doc) {
        final data = doc.data();
        return {
          ...data,
          'id': doc.id,
        };
      }).toList();
    } catch (e) {
      debugPrint('[Notification] Failed to load notifications from Firestore: $e');
      return [];
    }
  }

  Future<void> _syncNotificationToFirestore(NotificationModel notification) async {
    await FirestoreService.runAuthenticated(() async {
      try {
        await _notificationsCollection.doc(notification.id).set(notification.toJson());
      } catch (e) {
        debugPrint('[Notification] Failed to sync notification ${notification.id} to Firestore: $e');
      }
    });
  }

  Future<void> _syncNotificationsToFirestore(List<NotificationModel> notifications) async {
    for (final notification in notifications) {
      await _syncNotificationToFirestore(notification);
    }
  }

  Future<void> ensureInitialized() => _initFuture;

  void resetForNewSession() {
    _isInitialized = false;
    _notifications.clear();
    _initFuture = _initialize();
  }

  Future<void> _initialize() async {
    if (_isInitialized) return;

    final firestoreNotifications = await _fetchNotificationsFromFirestore();
    if (firestoreNotifications.isNotEmpty) {
      _notifications
        ..clear()
        ..addAll(firestoreNotifications.map(NotificationModel.fromJson));
    } else {
      // Firestore unavailable — fall back to local storage once
      final saved = await StorageService.getNotifications();
      _notifications.addAll(saved.map(NotificationModel.fromJson));
    }

    _isInitialized = true;
  }

  Future<void> _persistNotifications() async {
    await _syncNotificationsToFirestore(_notifications);
  }

  Future<List<NotificationModel>> getNotificationsForUser(String userId) async {
    await ensureInitialized();
    await Future.delayed(const Duration(milliseconds: 200));
    return _notifications
        .where((n) => n.userId == userId)
        .toList()
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
  }

  Future<List<NotificationModel>> getUnreadNotificationsForUser(
    String userId,
  ) async {
    await ensureInitialized();
    await Future.delayed(const Duration(milliseconds: 200));
    return _notifications
        .where((n) => n.userId == userId && !n.isRead)
        .toList()
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
  }

  Future<void> createNotification(NotificationModel notification) async {
    await ensureInitialized();
    await Future.delayed(const Duration(milliseconds: 300));
    final newNotif = notification.copyWith(
      id: notification.id.isEmpty
          ? 'NOTIF-${Random().nextInt(90000) + 10000}'
          : notification.id,
    );
    _notifications.insert(0, newNotif);
    await _persistNotifications();
  }

  Future<void> markAsRead(String notificationId) async {
    await ensureInitialized();
    await Future.delayed(const Duration(milliseconds: 200));
    final index = _notifications.indexWhere((n) => n.id == notificationId);
    if (index != -1) {
      _notifications[index] = _notifications[index].copyWith(isRead: true);
      await _persistNotifications();
    }
  }

  Future<void> markAllAsReadForUser(String userId) async {
    await ensureInitialized();
    await Future.delayed(const Duration(milliseconds: 200));
    for (int i = 0; i < _notifications.length; i++) {
      if (_notifications[i].userId == userId && !_notifications[i].isRead) {
        _notifications[i] = _notifications[i].copyWith(isRead: true);
      }
    }
    await _persistNotifications();
  }

  Future<void> deleteNotification(String notificationId) async {
    await ensureInitialized();
    await Future.delayed(const Duration(milliseconds: 200));
    _notifications.removeWhere((n) => n.id == notificationId);
    await _persistNotifications();
  }

  Future<void> deleteAllForUser(String userId) async {
    await ensureInitialized();
    await Future.delayed(const Duration(milliseconds: 200));
    _notifications.removeWhere((n) => n.userId == userId);
    await _persistNotifications();
  }

  int getUnreadCountForUser(String userId) {
    return _notifications
        .where((n) => n.userId == userId && !n.isRead)
        .length;
  }
}

