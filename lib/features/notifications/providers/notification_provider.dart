import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../auth/providers/auth_provider.dart';
import '../data/mock_notification_repository.dart';
import '../models/notification_model.dart';
import '../models/notification_type.dart';

class NotificationState {
  final bool isLoading;
  final String? error;
  final List<NotificationModel> notifications;
  final int unreadCount;

  const NotificationState({
    this.isLoading = false,
    this.error,
    this.notifications = const [],
    this.unreadCount = 0,
  });

  NotificationState copyWith({
    bool? isLoading,
    String? error,
    List<NotificationModel>? notifications,
    int? unreadCount,
    bool clearError = false,
  }) {
    return NotificationState(
      isLoading: isLoading ?? this.isLoading,
      error: clearError ? null : (error ?? this.error),
      notifications: notifications ?? this.notifications,
      unreadCount: unreadCount ?? this.unreadCount,
    );
  }
}

class NotificationNotifier extends StateNotifier<NotificationState> {
  NotificationNotifier(this.ref) : super(const NotificationState()) {
    _repo = MockNotificationRepository.instance;
  }

  final Ref ref;
  late final MockNotificationRepository _repo;

  Future<void> loadNotifications() async {
    final user = ref.read(currentUserProvider);
    if (user == null) return;

    await _repo.ensureInitialized();
    state = state.copyWith(isLoading: true, clearError: true);
    try {
      final notifications = await _repo.getNotificationsForUser(user.id);
      final unreadCount = _repo.getUnreadCountForUser(user.id);
      state = state.copyWith(
        isLoading: false,
        notifications: notifications,
        unreadCount: unreadCount,
      );
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
    }
  }

  Future<void> createNotification({
    required NotificationType type,
    required String title,
    required String body,
    required String userId,
    String? relatedId,
    Map<String, dynamic>? data,
  }) async {
    await _repo.ensureInitialized();
    try {
      final notification = NotificationModel(
        id: '',
        userId: userId,
        type: type,
        title: title,
        body: body,
        relatedId: relatedId,
        createdAt: DateTime.now(),
        isRead: false,
        data: data,
      );

      await _repo.createNotification(notification);
      await loadNotifications();
    } catch (e) {
      state = state.copyWith(error: e.toString());
    }
  }

  Future<void> markAsRead(String notificationId) async {
    await _repo.ensureInitialized();
    state = state.copyWith(isLoading: true);
    try {
      await _repo.markAsRead(notificationId);
      await loadNotifications();
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
    }
  }

  Future<void> markAllAsRead() async {
    final user = ref.read(currentUserProvider);
    if (user == null) return;

    await _repo.ensureInitialized();
    state = state.copyWith(isLoading: true);
    try {
      await _repo.markAllAsReadForUser(user.id);
      await loadNotifications();
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
    }
  }

  Future<void> deleteNotification(String notificationId) async {
    await _repo.ensureInitialized();
    state = state.copyWith(isLoading: true);
    try {
      await _repo.deleteNotification(notificationId);
      await loadNotifications();
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
    }
  }

  Future<void> deleteAllNotifications() async {
    final user = ref.read(currentUserProvider);
    if (user == null) return;

    await _repo.ensureInitialized();
    state = state.copyWith(isLoading: true);
    try {
      await _repo.deleteAllForUser(user.id);
      state = state.copyWith(isLoading: false, notifications: []);
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
    }
  }
}

final notificationProvider =
    StateNotifierProvider<NotificationNotifier, NotificationState>((ref) {
  return NotificationNotifier(ref);
});

