import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../core/widgets/app_state_widgets.dart';
import '../../../proposals/models/proposal.dart';
import '../../data/mock_order_repository.dart';
import '../../models/order_model.dart';
import '../../providers/order_provider.dart';
import '../../../../core/providers/notification_provider.dart';

class VendorOrderDetailsScreen extends ConsumerWidget {
  const VendorOrderDetailsScreen({super.key, required this.order});
  final OrderModel order;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primaryText = isDark ? AppColors.textPrimaryDark : AppColors.textPrimaryLight;
    final secondaryText = isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight;
    final cardColor = isDark ? AppColors.cardDark : AppColors.cardLight;
    final borderColor = isDark ? AppColors.borderDark : AppColors.borderLight;

    // Listen to order state in real-time
    final orderState = ref.watch(orderProvider);
    final activeOrder = orderState.orders.firstWhere(
      (o) => o.id == order.id,
      orElse: () => order,
    );

    return Scaffold(
      backgroundColor: isDark ? AppColors.backgroundDark : AppColors.backgroundLight,
      appBar: AppBar(
        title: Text('Manage ${activeOrder.id}'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded),
          onPressed: () => context.pop(),
        ),
      ),
      body: Column(
        children: [
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Order Summary Card
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: cardColor,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: borderColor),
                    ),
                    child: Column(
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text('Order ID:', style: AppTextStyles.bodyMedium(secondaryText)),
                            Text(activeOrder.id, style: AppTextStyles.subtitle(primaryText)),
                          ],
                        ),
                        const SizedBox(height: 6),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text('Order Status:', style: AppTextStyles.bodyMedium(secondaryText)),
                            StatusBadge(
                              label: activeOrder.status.displayName,
                              color: activeOrder.status == OrderStatus.delivered
                                  ? AppColors.success
                                  : AppColors.vendorColor,
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),

                  // UNLOCKED Customer Details Section (Reveal Privacy Barrier)
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: AppColors.success.withOpacity(0.08),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: AppColors.success.withOpacity(0.2)),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.lock_open_rounded, color: AppColors.success, size: 20),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            'Order confirmed! Customer contact and exact address are unlocked.',
                            style: AppTextStyles.caption(AppColors.success).copyWith(fontWeight: FontWeight.bold),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),

                  Text('Customer Contact Information', style: AppTextStyles.h2(primaryText)),
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: cardColor,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: borderColor),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            const Icon(Icons.person_outline_rounded, color: AppColors.vendorColor, size: 20),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text('Customer Name', style: AppTextStyles.caption(secondaryText)),
                                  Text(activeOrder.customerName, style: AppTextStyles.bodyLarge(primaryText)),
                                ],
                              ),
                            ),
                          ],
                        ),
                        const Divider(height: 24),
                        Row(
                          children: [
                            const Icon(Icons.phone_outlined, color: AppColors.vendorColor, size: 20),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text('Phone Number', style: AppTextStyles.caption(secondaryText)),
                                  Text(activeOrder.customerPhone, style: AppTextStyles.bodyLarge(primaryText)),
                                ],
                              ),
                            ),
                            IconButton(
                              style: IconButton.styleFrom(
                                backgroundColor: AppColors.vendorColor.withOpacity(0.12),
                              ),
                              icon: const Icon(Icons.phone, color: AppColors.vendorColor),
                              onPressed: () {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text('Calling customer ${activeOrder.customerName} at ${activeOrder.customerPhone}...'),
                                    behavior: SnackBarBehavior.floating,
                                  ),
                                );
                              },
                            )
                          ],
                        ),
                        const Divider(height: 24),
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Icon(Icons.location_on_outlined, color: AppColors.vendorColor, size: 20),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text('Exact Delivery Address', style: AppTextStyles.caption(secondaryText)),
                                  Text(activeOrder.deliveryAddress, style: AppTextStyles.bodyMedium(primaryText)),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),

                  // Ordered Items
                  Text('Items for Preparation', style: AppTextStyles.h2(primaryText)),
                  const SizedBox(height: 12),
                  ListView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: activeOrder.items.length,
                    itemBuilder: (context, index) {
                      final item = activeOrder.items[index];
                      if (item.status == ProposalItemStatus.unavailable) return const SizedBox.shrink();

                      final itemName = item.status == ProposalItemStatus.alternative
                          ? '${item.alternativeName} (Alternative)'
                          : item.requestItemName;

                      return Container(
                        margin: const EdgeInsets.only(bottom: 10),
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: cardColor,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: borderColor),
                        ),
                        child: Row(
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(itemName, style: AppTextStyles.bodyLarge(primaryText)),
                                  Text('Quantity to Pack: ${item.quantity}', style: AppTextStyles.caption(secondaryText)),
                                ],
                              ),
                            ),
                            Text('Rs. ${item.totalPrice.toStringAsFixed(2)}', style: AppTextStyles.bodyMedium(primaryText)),
                          ],
                        ),
                      );
                    },
                  ),
                  const SizedBox(height: 30),
                ],
              ),
            ),
          ),

          // Order status state management actions
          if (activeOrder.status != OrderStatus.delivered)
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: cardColor,
                border: Border(top: BorderSide(color: borderColor)),
              ),
              child: SafeArea(
                child: SizedBox(
                  width: double.infinity,
                  height: 52,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.vendorColor,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                      elevation: 0,
                    ),
                    onPressed: () async {
                      OrderStatus nextStatus = OrderStatus.preparing;
                      if (activeOrder.status == OrderStatus.preparing) {
                        nextStatus = OrderStatus.outForDelivery;
                      } else if (activeOrder.status == OrderStatus.outForDelivery) {
                        nextStatus = OrderStatus.delivered;
                      }
                      
                      await ref.read(orderProvider.notifier).updateOrderStatus(activeOrder.id, nextStatus);

                      // Trigger simulated Customer Notifications based on status update!
                      if (nextStatus == OrderStatus.preparing) {
                        ref.read(notificationProvider.notifier).triggerNotification(
                          title: 'Order Preparing! 📦',
                          body: 'Merchant is packing your items for order ${activeOrder.id}.',
                          icon: Icons.inventory_2_rounded,
                          color: AppColors.customerColor,
                        );
                      } else if (nextStatus == OrderStatus.outForDelivery) {
                        ref.read(notificationProvider.notifier).triggerNotification(
                          title: 'Order Out for Delivery! 🛵',
                          body: 'Merchant dispatched your order ${activeOrder.id}. It is on the way!',
                          icon: Icons.delivery_dining_rounded,
                          color: AppColors.customerColor,
                        );
                      } else if (nextStatus == OrderStatus.delivered) {
                        ref.read(notificationProvider.notifier).triggerNotification(
                          title: 'Order Delivered! 🎉',
                          body: 'Thank you! Order ${activeOrder.id} has been delivered successfully.',
                          icon: Icons.task_alt_rounded,
                          color: AppColors.customerColor,
                        );
                      }
                      
                      if (nextStatus == OrderStatus.delivered && activeOrder.paymentMethod == PaymentMethod.cashOnDelivery) {
                        // COD Payment complete upon delivery
                        await MockOrderRepository.instance.updatePaymentStatus(activeOrder.id, PaymentStatus.paid);
                        // Refresh state
                        await ref.read(orderProvider.notifier).loadVendorOrders();
                      }

                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text('Order updated to: ${nextStatus.displayName}'),
                            backgroundColor: AppColors.success,
                            behavior: SnackBarBehavior.floating,
                          ),
                        );
                        context.pop();
                      }
                    },
                    child: Text(
                      activeOrder.status == OrderStatus.preparing
                          ? 'Dispatch (Mark Out for Delivery)'
                          : 'Confirm Delivery (Mark as Delivered)',
                      style: AppTextStyles.button(Colors.white),
                    ),
                  ),
                ),
              ),
            )
        ],
      ),
    );
  }
}
