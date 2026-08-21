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
  String _selectedFilter = 'Inbox'; // Inbox | Orders | Alerts

  @override
  void initState() {
    super.initState();
    Future.microtask(() {
      if (!mounted) return;
      ref.read(notification_feature.notificationProvider.notifier).loadNotifications();
    });
  }

  List<NotificationModel> _filteredNotifications(List<NotificationModel> all) {
    switch (_selectedFilter) {
      case 'Orders':
        return all.where((n) =>
          n.type == NotificationType.orderStatusUpdated ||
          n.type == NotificationType.orderReadyForPickup ||
          n.type == NotificationType.orderOutForDelivery ||
          n.type == NotificationType.orderDelivered ||
          n.type == NotificationType.receiptGenerated ||
          n.type == NotificationType.cashOnDeliveryConfirmed
        ).toList();
      case 'Alerts':
        return all.where((n) =>
          n.type == NotificationType.paymentFailed ||
          n.type == NotificationType.proposalRejected
        ).toList();
      case 'Inbox':
      default:
        return all;
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final background = isDark ? AppColors.backgroundDark : AppColors.backgroundLight;
    final surface = isDark ? AppColors.surfaceDark : AppColors.surfaceLight;
    final primaryText = isDark ? AppColors.textPrimaryDark : AppColors.textPrimaryLight;
    final secondaryText = isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight;
    final state = ref.watch(notification_feature.notificationProvider);

    final ordersCount = state.notifications.where((n) =>
      n.type == NotificationType.orderStatusUpdated ||
      n.type == NotificationType.orderReadyForPickup ||
      n.type == NotificationType.orderOutForDelivery ||
      n.type == NotificationType.orderDelivered ||
      n.type == NotificationType.receiptGenerated ||
      n.type == NotificationType.cashOnDeliveryConfirmed
    ).where((n) => !n.isRead).length;

    final alertsCount = state.notifications.where((n) =>
      n.type == NotificationType.paymentFailed ||
      n.type == NotificationType.proposalRejected
    ).where((n) => !n.isRead).length;

    final chatUnread = ref.read(chatProvider.notifier).unreadConversationsCount();

    final quickActions = <Map<String, dynamic>>[
      {'title': 'Inbox',  'icon': Icons.inbox_outlined,             'color': AppColors.primary, 'badge': state.unreadCount},
      {'title': 'Chats',  'icon': Icons.chat_bubble_outline_rounded,'color': AppColors.info,    'badge': chatUnread},
      {'title': 'Orders', 'icon': Icons.local_shipping_outlined,    'color': AppColors.success, 'badge': ordersCount},
      {'title': 'Alerts', 'icon': Icons.warning_amber_rounded,      'color': AppColors.warning, 'badge': alertsCount},
    ];

    final filtered = _filteredNotifications(state.notifications);

    return Scaffold(
      backgroundColor: background,
      body: SafeArea(
        child: Column(
          children: [
            // ── Custom Header ────────────────────────────────────────────────
            Container(
              padding: EdgeInsets.fromLTRB(12, 8, 16, 8),
              decoration: BoxDecoration(
                color: surface,
                border: Border(
                  bottom: BorderSide(
                    color: isDark ? AppColors.borderDark : AppColors.borderLight,
                    width: 1,
                  ),
                ),
              ),
              child: Row(
                children: [
                  GestureDetector(
                    onTap: () => Navigator.of(context).maybePop(),
                    child: Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: isDark ? Colors.white.withValues(alpha: 0.1) : Colors.black.withValues(alpha: 0.06),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: isDark ? Colors.white.withValues(alpha: 0.18) : Colors.black.withValues(alpha: 0.1),
                        ),
                      ),
                      child: Icon(Icons.arrow_back_ios_new_rounded, color: primaryText, size: 18),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Text('Notification Center', style: AppTextStyles.subtitle(primaryText)),
                ],
              ),
            ),

            // ── Filter Buttons ───────────────────────────────────────────────
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
              child: Row(
                children: quickActions.map((action) {
                  final title = action['title'] as String;
                  final icon = action['icon'] as IconData;
                  final color = action['color'] as Color;
                  final badge = action['badge'] as int;
                  final isSelected = _selectedFilter == title && title != 'Chats';

                  return Expanded(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 4),
                      child: Stack(
                        children: [
                          _QuickActionButton(
                            title: title,
                            icon: icon,
                            color: color,
                            isSelected: isSelected,
                            onTap: () {
                              if (title == 'Chats') {
                                context.push('/chats');
                              } else {
                                setState(() => _selectedFilter = title);
                              }
                            },
                          ),
                          if (badge > 0)
                            Positioned(
                              right: 4,
                              top: 4,
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                                decoration: BoxDecoration(color: Colors.red, borderRadius: BorderRadius.circular(12)),
                                child: Text('$badge', style: AppTextStyles.caption(Colors.white).copyWith(fontSize: 10)),
                              ),
                            ),
                        ],
                      ),
                    ),
                  );
                }).toList(),
              ),
            ),

            // ── Notification List ────────────────────────────────────────────
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
                    : filtered.isEmpty
                        ? Center(
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.notifications_none_rounded, size: 48, color: secondaryText.withOpacity(0.4)),
                                const SizedBox(height: 12),
                                Text('No $_selectedFilter notifications', style: AppTextStyles.bodyMedium(secondaryText)),
                              ],
                            ),
                          )
                        : ListView.separated(
                            itemCount: filtered.length,
                            separatorBuilder: (_, __) => const SizedBox(height: 8),
                            itemBuilder: (context, index) {
                              final item = filtered[index];
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
  final String title;
  final IconData icon;
  final Color color;
  final bool isSelected;
  final VoidCallback onTap;

  const _QuickActionButton({
    required this.title,
    required this.icon,
    required this.color,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textColor = isSelected ? color : (isDark ? AppColors.textPrimaryDark : AppColors.textPrimaryLight);

    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeOut,
        padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 16),
        decoration: BoxDecoration(
          color: isSelected
              ? color.withOpacity(isDark ? 0.25 : 0.15)
              : color.withOpacity(isDark ? 0.1 : 0.06),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isSelected
                ? color.withOpacity(0.7)
                : color.withOpacity(isDark ? 0.3 : 0.18),
            width: isSelected ? 1.8 : 1.2,
          ),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: color, size: 26),
            const SizedBox(height: 6),
            Text(
              title,
              style: AppTextStyles.bodySmall(textColor).copyWith(
                fontWeight: isSelected ? FontWeight.w700 : FontWeight.w600,
              ),
            ),
          ],
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
