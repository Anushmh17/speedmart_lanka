import 'dart:math';
import '../../../core/storage/storage_service.dart';
import '../models/notification_model.dart';

/// Mock notification repository with local persistence.
/// TODO: Replace local mock notification persistence with backend API / Firebase Cloud Messaging.
class MockNotificationRepository {
  MockNotificationRepository._() {
    _initFuture = _initialize();
  }

  static final MockNotificationRepository instance =
      MockNotificationRepository._();

  late final Future<void> _initFuture;
  bool _isInitialized = false;

  final List<NotificationModel> _notifications = [];

  Future<void> ensureInitialized() => _initFuture;

  Future<void> _initialize() async {
    if (_isInitialized) return;

    final saved = await StorageService.getNotifications();
    if (saved.isNotEmpty) {
      _notifications
        ..clear()
        ..addAll(saved.map(NotificationModel.fromJson));
    }

    _isInitialized = true;
  }

  Future<void> _persistNotifications() async {
    await StorageService.saveNotifications(
      _notifications.map((n) => n.toJson()).toList(),
    );
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

