import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:speedmart_lanka/core/routes/route_names.dart';
import 'package:speedmart_lanka/core/theme/app_colors.dart';
import 'package:speedmart_lanka/core/theme/app_text_styles.dart';
import 'package:speedmart_lanka/features/notifications/models/notification_model.dart';
import 'package:speedmart_lanka/features/notifications/models/notification_type.dart';
import 'package:speedmart_lanka/features/notifications/providers/notification_provider.dart' as notification_feature;
import 'package:speedmart_lanka/features/chat/providers/chat_provider.dart';

class CustomerNotificationCenterScreen extends ConsumerStatefulWidget {
  const CustomerNotificationCenterScreen({super.key});

  @override
  ConsumerState<CustomerNotificationCenterScreen> createState() => _CustomerNotificationCenterScreenState();
}

class _CustomerNotificationCenterScreenState extends ConsumerState<CustomerNotificationCenterScreen> {
  @override
  void initState() {
    super.initState();
    Future.microtask(() {
      if (!mounted) return;
      ref.read(notification_feature.notificationProvider.notifier).loadNotifications();
    });
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final background = isDark ? AppColors.backgroundDark : AppColors.backgroundLight;
    final surface = isDark ? AppColors.surfaceDark : AppColors.surfaceLight;
    final primaryText = isDark ? AppColors.textPrimaryDark : AppColors.textPrimaryLight;
    final secondaryText = isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight;
    final state = ref.watch(notification_feature.notificationProvider);

    final quickActions = <_QuickAction>[
      _QuickAction(
        title: 'Inbox',
        icon: Icons.inbox_outlined,
        color: AppColors.primary,
        onTap: () {},
      ),
      _QuickAction(
        title: 'Chats',
        icon: Icons.chat_bubble_outline_rounded,
        color: AppColors.info,
        onTap: () {
          context.push('/chats');
        },
      ),
      _QuickAction(
        title: 'Orders',
        icon: Icons.local_shipping_outlined,
        color: AppColors.success,
        onTap: () => context.go(RouteNames.customerOrders),
      ),
      _QuickAction(
        title: 'Alerts',
        icon: Icons.warning_amber_rounded,
        color: AppColors.warning,
        onTap: () {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Alerts center coming soon')),
          );
        },
      ),
    ];

    return Scaffold(
      backgroundColor: background,
      appBar: AppBar(
        backgroundColor: surface,
        elevation: 0,
        title: Text('Notification Center', style: AppTextStyles.subtitle(primaryText)),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded),
          onPressed: () => Navigator.of(context).maybePop(),
        ),
      ),
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(10, 12, 10, 8),
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final itemWidth = (constraints.maxWidth - 16) / quickActions.length;
                  final itemSize = min(itemWidth, 132.0);

                  return SizedBox(
                    width: double.infinity,
                    height: itemSize,
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: quickActions.map((action) {
                        return SizedBox(
                          width: itemSize,
                          height: itemSize,
                          child: Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 4.0),
                            child: Consumer(builder: (context, wref, _) {
                              final notifState = ref.watch(notification_feature.notificationProvider);
                              final chatUnread = wref.read(chatProvider.notifier).unreadConversationsCount();
                              final inboxCount = notifState.unreadCount;
                              final ordersCount = notifState.notifications
                                  .where((n) =>
                                      n.type == NotificationType.orderStatusUpdated ||
                                      n.type == NotificationType.orderReadyForPickup ||
                                      n.type == NotificationType.orderOutForDelivery ||
                                      n.type == NotificationType.orderDelivered ||
                                      n.type == NotificationType.receiptGenerated ||
                                      n.type == NotificationType.cashOnDeliveryConfirmed)
                                  .where((n) => !n.isRead)
                                  .length;
                              final alertsCount = notifState.notifications
                                  .where((n) =>
                                      n.type == NotificationType.paymentFailed ||
                                      n.type == NotificationType.proposalRejected)
                                  .where((n) => !n.isRead)
                                  .length;

                              int badge = 0;
                              if (action.title == 'Inbox') badge = inboxCount;
                              if (action.title == 'Chats') badge = chatUnread;
                              if (action.title == 'Orders') badge = ordersCount;
                              if (action.title == 'Alerts') badge = alertsCount;

                              return Stack(
                                children: [
                                  _QuickActionButton(action: action),
                                  if (badge > 0)
                                    Positioned(
                                      right: 8,
                                      top: 8,
                                      child: Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                        decoration: BoxDecoration(color: Colors.red, borderRadius: BorderRadius.circular(12)),
                                        child: Text('$badge', style: AppTextStyles.caption(Colors.white)),
                                      ),
                                    ),
                                ],
                              );
                            }),
                          ),
                        );
                      }).toList(),
                    ),
                  );
                },
              ),
            ),
            Expanded(
              child: Container(
                margin: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: surface,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: AppColors.borderLight.withOpacity(0.2)),
                ),
                child: state.isLoading
                    ? const Center(child: CircularProgressIndicator())
                    : state.notifications.isEmpty
                        ? Center(
                            child: Text('No updates yet', style: AppTextStyles.bodyMedium(secondaryText)),
                          )
                        : ListView.separated(
                            itemCount: state.notifications.length,
                            separatorBuilder: (_, __) => const SizedBox(height: 8),
                            itemBuilder: (context, index) {
                              final item = state.notifications[index];
                              return _NotificationListTile(
                                notification: item,
                                onTap: () => _openNotificationDestination(context, item),
                              );
                            },
                          ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _QuickActionButton extends StatelessWidget {
  final _QuickAction action;

  const _QuickActionButton({required this.action});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final surface = isDark ? AppColors.surfaceDark : AppColors.surfaceLight;
    final textColor = isDark ? AppColors.textPrimaryDark : AppColors.textPrimaryLight;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: action.onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          constraints: const BoxConstraints(minHeight: 110, minWidth: 96),
          padding: const EdgeInsets.symmetric(vertical: 18, horizontal: 10),
          decoration: BoxDecoration(
            color: surface,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppColors.borderLight.withOpacity(0.25)),
            boxShadow: [
              BoxShadow(
                color: isDark ? Colors.black26 : const Color(0x0A000000),
                blurRadius: 12,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: action.color.withOpacity(0.12),
                  shape: BoxShape.circle,
                ),
                child: Icon(action.icon, color: action.color),
              ),
              const SizedBox(height: 10),
              Text(action.title, style: AppTextStyles.bodySmall(textColor)),
            ],
          ),
        ),
      ),
    );
  }
}

class _NotificationListTile extends StatelessWidget {
  final NotificationModel notification;
  final VoidCallback onTap;

  const _NotificationListTile({required this.notification, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primaryText = isDark ? AppColors.textPrimaryDark : AppColors.textPrimaryLight;
    final secondaryText = isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: isDark ? AppColors.surfaceDark : AppColors.surfaceLight,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: AppColors.borderLight.withOpacity(0.25)),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(Icons.circle, color: AppColors.primary, size: 10),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(notification.title, style: AppTextStyles.bodyMedium(primaryText)),
                    const SizedBox(height: 4),
                    Text(notification.body, style: AppTextStyles.bodySmall(secondaryText)),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _QuickAction {
  final String title;
  final IconData icon;
  final Color color;
  final VoidCallback onTap;

  const _QuickAction({required this.title, required this.icon, required this.color, required this.onTap});
}

void _openNotificationDestination(BuildContext context, NotificationModel notification) {
  switch (notification.type) {
    case NotificationType.newProposal:
    case NotificationType.proposalAccepted:
    case NotificationType.proposalRejected:
      context.go(RouteNames.customerProposals);
      break;
    case NotificationType.orderStatusUpdated:
    case NotificationType.cashOnDeliveryConfirmed:
    case NotificationType.receiptGenerated:
    case NotificationType.orderReadyForPickup:
    case NotificationType.orderOutForDelivery:
    case NotificationType.orderDelivered:
      context.go(RouteNames.customerOrders);
      break;
    case NotificationType.newNearbyRequest:
    case NotificationType.paymentFailed:
    default:
      context.go(RouteNames.customerHome);
      break;
  }
}
