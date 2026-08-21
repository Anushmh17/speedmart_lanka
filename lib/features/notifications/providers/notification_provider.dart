import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../auth/providers/auth_provider.dart';
import '../data/notification_repository.dart';
import '../models/notification_model.dart';
import '../models/notification_type.dart';
import 'package:speedmart_lanka/core/services/local_notification_service.dart';
import 'package:speedmart_lanka/core/routes/route_names.dart';
import 'package:speedmart_lanka/core/utils/error_translator.dart';

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
    _repo = NotificationRepository.instance;
  }

  final Ref ref;
  late final NotificationRepository _repo;

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
      state = state.copyWith(isLoading: false, error: ErrorTranslator.friendly(e));
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

      // If the notification is for the current signed-in user, show a platform notification
      final current = ref.read(currentUserProvider);
      if (current != null && current.id == userId) {
        try {
          // Map notification types to deep links / routes
          String? route;
          dynamic extra;
          switch (type) {
            case NotificationType.newNearbyRequest:
              // Open the specific vendor request detail
              route = (relatedId != null && relatedId.isNotEmpty)
                  ? RouteNames.vendorRequestDetail.replaceFirst(':id', relatedId)
                  : RouteNames.vendorNearbyRequests;
              extra = null;
              break;
            case NotificationType.newProposal:
              route = (relatedId != null && relatedId.isNotEmpty)
                  ? RouteNames.customerProposalDetail.replaceFirst(':id', relatedId)
                  : RouteNames.customerProposals;
              extra = null;
              break;
            case NotificationType.proposalAccepted:
            case NotificationType.proposalRejected:
              route = (relatedId != null && relatedId.isNotEmpty)
                  ? RouteNames.vendorProposalDetail.replaceFirst(':id', relatedId)
                  : RouteNames.vendorProposals;
              extra = null;
              break;
            case NotificationType.orderStatusUpdated:
            case NotificationType.receiptGenerated:
              route = (relatedId != null && relatedId.isNotEmpty)
                  ? RouteNames.customerOrderTrack.replaceFirst(':id', relatedId)
                  : RouteNames.customerOrders;
              extra = null;
              break;
            default:
              route = null;
          }

          await LocalNotificationService.showNotification(
            id: DateTime.now().millisecondsSinceEpoch.remainder(100000),
            title: title,
            body: body,
            payload: route != null ? {'route': route, 'extra': extra} : null,
          );
        } catch (_) {}
      }
    } catch (e) {
      state = state.copyWith(error: ErrorTranslator.friendly(e));
    }
  }

  Future<void> markAsRead(String notificationId) async {
    await _repo.ensureInitialized();
    state = state.copyWith(isLoading: true);
    try {
      await _repo.markAsRead(notificationId);
      await loadNotifications();
    } catch (e) {
      state = state.copyWith(isLoading: false, error: ErrorTranslator.friendly(e));
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
      state = state.copyWith(isLoading: false, error: ErrorTranslator.friendly(e));
    }
  }

  Future<void> deleteNotification(String notificationId) async {
    await _repo.ensureInitialized();
    state = state.copyWith(isLoading: true);
    try {
      await _repo.deleteNotification(notificationId);
      await loadNotifications();
    } catch (e) {
      state = state.copyWith(isLoading: false, error: ErrorTranslator.friendly(e));
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
      state = state.copyWith(isLoading: false, error: ErrorTranslator.friendly(e));
    }
  }
}

final notificationProvider =
    StateNotifierProvider<NotificationNotifier, NotificationState>((ref) {
  return NotificationNotifier(ref);
});

