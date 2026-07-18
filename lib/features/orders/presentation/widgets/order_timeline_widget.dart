import 'package:flutter/material.dart';
import '../../../../core/theme/app_colors.dart';
import '../../models/order_model.dart';

class OrderTimelineWidget extends StatelessWidget {
  const OrderTimelineWidget({
    super.key,
    required this.order,
    this.isVendorView = false,
  });

  final OrderModel order;
  final bool isVendorView;

  static const List<OrderStatus> _timelineStatuses = [
    OrderStatus.submitted,
    OrderStatus.accepted,
    OrderStatus.preparing,
    OrderStatus.readyForDelivery,
    OrderStatus.outForDelivery,
    OrderStatus.delivered,
  ];

  bool _isStatusCompleted(OrderStatus status) {
    final currentIndex = _timelineStatuses.indexOf(order.status);
    final statusIndex = _timelineStatuses.indexOf(status);
    return statusIndex <= currentIndex || order.status == OrderStatus.completed;
  }

  bool _isStatusActive(OrderStatus status) {
    return order.status == status;
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primaryText = isDark ? AppColors.textPrimaryDark : AppColors.textPrimaryLight;
    final secondaryText = isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight;
    final cardColor = isDark ? AppColors.cardDark : AppColors.cardLight;
    final borderColor = isDark ? AppColors.borderDark : AppColors.borderLight;

    final timelineStatuses = order.status == OrderStatus.cancelled
        ? [OrderStatus.submitted, OrderStatus.cancelled]
        : _timelineStatuses;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: borderColor),
      ),
      child: Column(
        children: List.generate(
          timelineStatuses.length * 2 - 1,
          (index) {
            if (index.isEven) {
              final statusIndex = index ~/ 2;
              final status = timelineStatuses[statusIndex];
              return _TimelineStep(
                status: status,
                isCompleted: _isStatusCompleted(status),
                isActive: _isStatusActive(status),
                primaryText: primaryText,
                secondaryText: secondaryText,
                isDark: isDark,
              );
            } else {
              final statusIndex = index ~/ 2;
              final isCompleted = _isStatusCompleted(timelineStatuses[statusIndex + 1]);
              return _TimelineLine(isCompleted: isCompleted, isDark: isDark);
            }
          },
        ),
      ),
    );
  }
}

class _TimelineStep extends StatelessWidget {
  const _TimelineStep({
    required this.status,
    required this.isCompleted,
    required this.isActive,
    required this.primaryText,
    required this.secondaryText,
    required this.isDark,
  });

  final OrderStatus status;
  final bool isCompleted;
  final bool isActive;
  final Color primaryText;
  final Color secondaryText;
  final bool isDark;

  @override
  Widget build(BuildContext context) {
    final themeColor = isVendorView() ? AppColors.vendorColor : AppColors.customerColor;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Column(
          children: [
            Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                color: isCompleted
                    ? (isActive ? themeColor : AppColors.success)
                    : (isDark ? Colors.grey.shade800 : Colors.grey.shade200),
                shape: BoxShape.circle,
                border: isActive
                    ? Border.all(
                        color: themeColor,
                        width: 3,
                      )
                    : null,
              ),
              child: Center(
                child: Text(
                  status.statusIcon,
                  style: const TextStyle(fontSize: 16),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                status.displayName,
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                  color: isCompleted
                      ? (isDark ? Colors.white : Colors.black)
                      : (isDark ? Colors.grey.shade600 : Colors.grey.shade400),
                ),
              ),
              const SizedBox(height: 4),
              Text(
                _getStatusDescription(status),
                style: TextStyle(
                  fontSize: 12,
                  color: isCompleted
                      ? (isDark ? Colors.white70 : Colors.black54)
                      : (isDark ? Colors.grey.shade600 : Colors.grey.shade400),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  String _getStatusDescription(OrderStatus status) {
    switch (status) {
      case OrderStatus.submitted:
        return 'Order has been submitted and is being reviewed';
      case OrderStatus.accepted:
        return 'Shop Owner has accepted your order';
      case OrderStatus.preparing:
        return 'Shop Owner is preparing and packing your items';
      case OrderStatus.readyForDelivery:
        return 'Order is ready for pickup/delivery';
      case OrderStatus.outForDelivery:
        return 'Order is on the way to you';
      case OrderStatus.delivered:
        return 'Order has been delivered to you';
      case OrderStatus.completed:
        return 'Order completed successfully';
      case OrderStatus.cancelled:
        return 'Order has been cancelled';
    }
  }

  bool isVendorView() => false;
}

class _TimelineLine extends StatelessWidget {
  const _TimelineLine({
    required this.isCompleted,
    required this.isDark,
  });

  final bool isCompleted;
  final bool isDark;

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.only(left: 15),
        width: 2,
        height: 28,
        color: isCompleted ? AppColors.success : Colors.grey.shade300,
      ),
    );
  }
}

