import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:speedmart_lanka/core/theme/app_colors.dart';
import 'package:speedmart_lanka/core/theme/app_text_styles.dart';
import 'package:speedmart_lanka/core/theme/app_radius.dart';
import 'package:speedmart_lanka/core/widgets/theme3/theme3_app_bar.dart';
import 'package:speedmart_lanka/core/widgets/theme3/theme3_app_button.dart';
import 'package:speedmart_lanka/core/widgets/theme3/theme3_app_card.dart';
import 'package:speedmart_lanka/core/widgets/theme3/theme3_status_chip.dart';
import 'package:speedmart_lanka/features/proposals/models/proposal.dart';
import 'package:speedmart_lanka/features/orders/models/order_model.dart';
import 'package:speedmart_lanka/features/orders/providers/order_provider.dart';
import 'package:speedmart_lanka/features/orders/presentation/widgets/order_timeline_widget.dart';
import 'package:speedmart_lanka/features/payments/models/payment.dart';

class OrderTrackingScreen extends ConsumerStatefulWidget {
  const OrderTrackingScreen({super.key, required this.order});
  final OrderModel order;

  @override
  ConsumerState<OrderTrackingScreen> createState() =>
      _OrderTrackingScreenState();
}

class _OrderTrackingScreenState extends ConsumerState<OrderTrackingScreen> {

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primaryText =
        isDark ? AppColors.textPrimaryDark : AppColors.textPrimaryLight;
    final secondaryText =
        isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight;

    final orderState = ref.watch(orderProvider);
    final activeOrder = orderState.orders.firstWhere(
      (o) => o.id == widget.order.id,
      orElse: () => widget.order,
    );

    return Scaffold(
      backgroundColor:
          isDark ? AppColors.backgroundDark : AppColors.backgroundLight,
      appBar: Theme3AppBar(
        title: 'Track ${activeOrder.id}',
        onBackPressed: () => context.pop(),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ─────────────────────────────────────────────────────────────
            // TOP SECTION — Order Header
            // ─────────────────────────────────────────────────────────────
            Theme3AppCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Order ID',
                            style: AppTextStyles.caption(secondaryText),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            activeOrder.id,
                            style: AppTextStyles.h2(primaryText),
                          ),
                        ],
                      ),
                      Theme3StatusChip(
                        label: activeOrder.status.displayName,
                        status: _mapOrderStatusToTheme3Status(activeOrder.status),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      const Icon(Icons.storefront_rounded,
                          color: AppColors.customerColor, size: 16),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          activeOrder.vendorBusinessName,
                          style: AppTextStyles.bodyMedium(primaryText),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      const Icon(Icons.schedule_rounded,
                          color: AppColors.warning, size: 16),
                      const SizedBox(width: 8),
                      Text(
                        'Est. Delivery: ${_formatEstimatedTime(activeOrder.createdAt)}',
                        style: AppTextStyles.bodyMedium(primaryText),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),

            // ─────────────────────────────────────────────────────────────
            // DELIVERY UPDATES SECTION — Status Details
            // ─────────────────────────────────────────────────────────────
            Text('Delivery Updates', style: AppTextStyles.h2(primaryText)),
            const SizedBox(height: 12),
            Theme3AppCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: AppColors.customerColor.withValues(alpha: 0.15),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(Icons.local_shipping_outlined,
                            color: AppColors.customerColor, size: 24),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Current Status',
                              style: AppTextStyles.caption(secondaryText),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              _getStatusDisplayText(activeOrder.status),
                              style: AppTextStyles.subtitle(primaryText)
                                  .copyWith(fontWeight: FontWeight.bold),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Divider(height: 1, color: isDark ? AppColors.borderDark : AppColors.borderLight),
                  const SizedBox(height: 16),
                  _buildInfoRow(
                    Icons.schedule_rounded,
                    'Last Updated',
                    _formatDateTime(activeOrder.updatedAt ?? activeOrder.createdAt),
                    secondaryText,
                    primaryText,
                  ),
                  const SizedBox(height: 12),
                  _buildInfoRow(
                    Icons.location_on_outlined,
                    'Delivery Address',
                    activeOrder.deliveryAddress,
                    secondaryText,
                    primaryText,
                  ),
                  const SizedBox(height: 12),
                  _buildInfoRow(
                    Icons.access_time_rounded,
                    'Estimated Delivery',
                    _formatEstimatedTime(activeOrder.createdAt),
                    secondaryText,
                    primaryText,
                  ),
                  const SizedBox(height: 16),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: AppColors.warning.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(AppRadius.md),
                      border: Border.all(
                        color: AppColors.warning.withValues(alpha: 0.3),
                      ),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.info_outline,
                            color: AppColors.warning, size: 18),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            'Delivery status is updated by the shop owner. Live rider tracking is not available.',
                            style: AppTextStyles.caption(
                              isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),

            // ─────────────────────────────────────────────────────────────
            // TIMELINE SECTION — Delivery Timeline
            // ─────────────────────────────────────────────────────────────
            Text('Delivery Timeline', style: AppTextStyles.h2(primaryText)),
            const SizedBox(height: 12),
            OrderTimelineWidget(order: activeOrder, isVendorView: false),
            const SizedBox(height: 24),

            // Shop owner contact section removed per UX request.

            // ─────────────────────────────────────────────────────────────
            // ITEMS SECTION — Order Items
            // ─────────────────────────────────────────────────────────────
            Text('Ordered Items', style: AppTextStyles.h2(primaryText)),
            const SizedBox(height: 12),
            ListView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: activeOrder.items.length,
              itemBuilder: (context, index) {
                final item = activeOrder.items[index];
                if (item.status == ProposalItemStatus.unavailable) {
                  return const SizedBox.shrink();
                }

                final itemName =
                    item.status == ProposalItemStatus.alternative
                        ? '${item.alternativeName} (Alternative for ${item.requestItemName})'
                        : item.requestItemName;

                return Theme3AppCard(
                  margin: const EdgeInsets.only(bottom: 10),
                  child: Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(itemName,
                                style: AppTextStyles.bodyLarge(primaryText)),
                            const SizedBox(height: 3),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: AppColors.customerColor.withValues(alpha: 0.08),
                                borderRadius: BorderRadius.circular(5),
                                border: Border.all(color: AppColors.customerColor.withValues(alpha: 0.2)),
                              ),
                              child: Text('ID: ${item.id}', style: AppTextStyles.labelSmall(AppColors.customerColor)),
                            ),
                            const SizedBox(height: 3),
                            Text(
                                'Qty: ${item.quantity} | Unit: Rs. ${item.price.toStringAsFixed(0)}',
                                style: AppTextStyles.caption(secondaryText)),
                          ],
                        ),
                      ),
                      Text('Rs. ${item.totalPrice.toStringAsFixed(2)}',
                          style: AppTextStyles.bodyMedium(primaryText)),
                    ],
                  ),
                );
              },
            ),
            const SizedBox(height: 24),

            // ─────────────────────────────────────────────────────────────
            // RECEIPT SECTION — Payment & Receipt
            // ─────────────────────────────────────────────────────────────
            Theme3AppCard(
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text('Payment Status:',
                          style: AppTextStyles.bodyMedium(secondaryText)),
                      Theme3StatusChip(
                        label: activeOrder.paymentStatus.name.toUpperCase(),
                        status: activeOrder.paymentStatus == PaymentStatus.paid
                            ? Theme3StatusType.completed
                            : Theme3StatusType.pending,
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text('Payment Method:',
                          style: AppTextStyles.bodyMedium(secondaryText)),
                      Text(activeOrder.paymentMethod.displayName,
                          style: AppTextStyles.bodyMedium(primaryText)),
                    ],
                  ),
                  const Divider(height: 24),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text('Total Paid:',
                          style: AppTextStyles.subtitle(primaryText)),
                      Text(
                          'Rs. ${activeOrder.totalPrice.toStringAsFixed(2)}',
                          style: AppTextStyles.subtitle(
                              AppColors.customerColor)),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Theme3AppButton(
                    label: 'Download LKR Receipt (PDF)',
                    onPressed: () => _showReceiptDialog(
                        context, activeOrder, isDark),
                    icon: Icons.download_rounded,
                    width: double.infinity,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 30),
          ],
        ),
      ),
    );
  }

  Theme3StatusType _mapOrderStatusToTheme3Status(OrderStatus status) {
    switch (status) {
      case OrderStatus.submitted:
      case OrderStatus.accepted:
        return Theme3StatusType.pending;
      case OrderStatus.preparing:
      case OrderStatus.readyForDelivery:
      case OrderStatus.outForDelivery:
        return Theme3StatusType.inProgress;
      case OrderStatus.delivered:
      case OrderStatus.completed:
        return Theme3StatusType.completed;
      case OrderStatus.cancelled:
        return Theme3StatusType.cancelled;
    }
  }

  String _formatEstimatedTime(DateTime createdAt) {
    final eta = createdAt.add(const Duration(hours: 2));
    return '${eta.hour}:${eta.minute.toString().padLeft(2, '0')}';
  }

  String _getStatusDisplayText(OrderStatus status) {
    switch (status) {
      case OrderStatus.submitted:
        return 'Order Placed';
      case OrderStatus.accepted:
        return 'Shop Owner Confirmed';
      case OrderStatus.preparing:
        return 'Preparing Your Items';
      case OrderStatus.readyForDelivery:
        return 'Ready for Pickup';
      case OrderStatus.outForDelivery:
        return 'Out for Delivery';
      case OrderStatus.delivered:
        return 'Delivered';
      case OrderStatus.completed:
        return 'Completed';
      case OrderStatus.cancelled:
        return 'Cancelled';
    }
  }

  String _formatDateTime(DateTime dt) {
    final now = DateTime.now();
    final diff = now.difference(dt);
    if (diff.inMinutes < 1) return 'Just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes} min ago';
    if (diff.inHours < 24) return '${diff.inHours} hr ago';
    return '${dt.day}/${dt.month}/${dt.year} at ${dt.hour}:${dt.minute.toString().padLeft(2, '0')}';
  }

  Widget _buildInfoRow(
    IconData icon,
    String label,
    String value,
    Color labelColor,
    Color valueColor,
  ) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 18, color: AppColors.customerColor),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label, style: AppTextStyles.caption(labelColor)),
              const SizedBox(height: 2),
              Text(value, style: AppTextStyles.bodyMedium(valueColor)),
            ],
          ),
        ),
      ],
    );
  }

  void _showReceiptDialog(
      BuildContext context, OrderModel activeOrder, bool isDark) {
    showDialog(
      context: context,
      builder: (ctx) {
        final isDarkCtx = Theme.of(ctx).brightness == Brightness.dark;
        final txtColor = isDarkCtx ? Colors.white : Colors.black;
        final subtotal = activeOrder.totalPrice - activeOrder.deliveryCharge;
        final serviceCharge = subtotal * 0.015;
        final sscl = subtotal * 0.025;
        final vat = subtotal * 0.18;

        return AlertDialog(
          backgroundColor:
              isDarkCtx ? AppColors.surfaceDark : AppColors.surfaceLight,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
          contentPadding: const EdgeInsets.all(24),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.receipt_long_rounded,
                        color: AppColors.customerColor, size: 28),
                    const SizedBox(width: 8),
                    Text('OFFICIAL RECEIPT',
                        style: AppTextStyles.h3(txtColor)),
                  ],
                ),
                const SizedBox(height: 6),
                Text('Speedmart Lanka (Pvt) Ltd.',
                    style: AppTextStyles.caption(
                        isDarkCtx ? Colors.white70 : Colors.black54)),
                Text(
                    'Reg No: PV 00259871 | Colombo 03',
                    style: TextStyle(
                        fontSize: 9,
                        color:
                            isDarkCtx ? Colors.white54 : Colors.black38)),
                const Divider(height: 24, thickness: 1.5),
                _buildReceiptRow(
                    'Invoice Number', activeOrder.id, txtColor,
                    isHeader: true),
                _buildReceiptRow(
                    'Payment Date',
                    '${activeOrder.createdAt.day}/${activeOrder.createdAt.month}/${activeOrder.createdAt.year}',
                    txtColor),
                _buildReceiptRow('Status',
                    activeOrder.paymentStatus.name.toUpperCase(), AppColors.success),
                _buildReceiptRow('Payment Method',
                    activeOrder.paymentMethod.displayName, txtColor),
                const Divider(height: 20),
                _buildReceiptRow('Items Subtotal',
                    'Rs. ${subtotal.toStringAsFixed(2)}', txtColor),
                _buildReceiptRow('Delivery Charge',
                    'Rs. ${activeOrder.deliveryCharge.toStringAsFixed(2)}',
                    txtColor),
                _buildReceiptRow('Platform Service (1.5%)',
                    'Rs. ${serviceCharge.toStringAsFixed(2)}', txtColor),
                _buildReceiptRow('SSCL Tax Levy (2.5%)',
                    'Rs. ${sscl.toStringAsFixed(2)}', txtColor),
                _buildReceiptRow('VAT Regulatory (18%)',
                    'Rs. ${vat.toStringAsFixed(2)}', txtColor),
                const Divider(height: 20),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('Total Amount Paid',
                        style: AppTextStyles.subtitle(txtColor)
                            .copyWith(fontWeight: FontWeight.bold)),
                    Text(
                        'Rs. ${activeOrder.totalPrice.toStringAsFixed(2)}',
                        style: AppTextStyles.bodyLarge(AppColors.customerColor)
                            .copyWith(fontWeight: FontWeight.bold)),
                  ],
                ),
                const SizedBox(height: 20),
                Container(
                  width: 100,
                  height: 100,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.grey.shade300),
                  ),
                  child:
                      const Icon(Icons.qr_code_2_rounded, size: 80, color: Colors.black),
                ),
                const SizedBox(height: 8),
                Text('Scan to verify digital signature',
                    style: TextStyle(
                        fontSize: 8,
                        color:
                            isDarkCtx ? Colors.white54 : Colors.black45)),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: Text('Close',
                  style: TextStyle(color: AppColors.customerColor)),
            ),
            Theme3AppButton(
              label: 'Share Receipt',
              onPressed: () {
                Navigator.pop(ctx);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text(
                        'Receipt successfully downloaded and shared!'),
                    behavior: SnackBarBehavior.floating,
                  ),
                );
              },
              icon: Icons.share_rounded,
              width: 150,
            ),
          ],
        );
      },
    );
  }

  Widget _buildReceiptRow(String label, String value, Color color,
      {bool isHeader = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label,
              style: TextStyle(
                  fontSize: 12, color: color.withValues(alpha: 0.7))),
          Text(value,
              style: TextStyle(
                  fontSize: 12,
                  fontWeight:
                      isHeader ? FontWeight.bold : FontWeight.normal,
                  color: color)),
        ],
      ),
    );
  }
}


