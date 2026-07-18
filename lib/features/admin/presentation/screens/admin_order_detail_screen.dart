import 'package:flutter/material.dart';
import 'package:speedmart_lanka/core/theme/app_colors.dart';
import 'package:speedmart_lanka/core/theme/app_text_styles.dart';
import 'package:speedmart_lanka/features/orders/models/order_model.dart';
import 'package:speedmart_lanka/features/payments/models/payment.dart';
import '../widgets/admin_screen_header.dart';

class AdminOrderDetailScreen extends StatelessWidget {
  const AdminOrderDetailScreen({super.key, required this.order});
  final OrderModel order;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primaryText =
        isDark ? AppColors.textPrimaryDark : AppColors.textPrimaryLight;
    final secondaryText =
        isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight;
    final cardColor = isDark ? AppColors.cardDark : AppColors.cardLight;
    final borderColor = isDark ? AppColors.borderDark : AppColors.borderLight;

    return Scaffold(
      backgroundColor:
          isDark ? AppColors.backgroundDark : AppColors.backgroundLight,
      body: Column(
        children: [
          AdminScreenHeader(
            title: 'Order Details',
            subtitle: order.id,
            icon: Icons.receipt_long_rounded,
            isDark: isDark,
          ),
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _infoCard(cardColor, borderColor, [
                    _row('Order ID', order.id, primaryText, secondaryText),
                    _divider(),
                    _row('Status', order.status.displayName, primaryText,
                        secondaryText),
                    _divider(),
                    _row(
                        'Date',
                        '${order.createdAt.day}/${order.createdAt.month}/${order.createdAt.year}',
                        primaryText,
                        secondaryText),
                    _divider(),
                    _row('Payment Method', order.paymentMethod.displayName,
                        primaryText, secondaryText),
                    _divider(),
                    _row('Payment Status',
                        order.paymentStatus.name.toUpperCase(), primaryText,
                        secondaryText),
                  ]),
                  const SizedBox(height: 16),
                  Text('Shop Owner', style: AppTextStyles.h2(primaryText)),
                  const SizedBox(height: 8),
                  _infoCard(cardColor, borderColor, [
                    _row('Business', order.vendorBusinessName, primaryText,
                        secondaryText),
                    _divider(),
                    _row('Phone', order.vendorPhone, primaryText, secondaryText),
                  ]),
                  const SizedBox(height: 16),
                  Text('Customer', style: AppTextStyles.h2(primaryText)),
                  const SizedBox(height: 8),
                  _infoCard(cardColor, borderColor, [
                    _row('Name', order.customerName, primaryText, secondaryText),
                    _divider(),
                    _row('Phone', order.customerPhone, primaryText,
                        secondaryText),
                    _divider(),
                    _row('Address', order.deliveryAddress, primaryText,
                        secondaryText),
                  ]),
                  const SizedBox(height: 16),
                  Text('Order Items', style: AppTextStyles.h2(primaryText)),
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: cardColor,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: borderColor),
                    ),
                    child: Column(
                      children: [
                        ...order.items.map((item) => Padding(
                              padding:
                                  const EdgeInsets.symmetric(vertical: 6),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      Expanded(
                                          child: Text(item.requestItemName,
                                              style: AppTextStyles.bodyMedium(
                                                  primaryText))),
                                      Text('x${item.quantity}',
                                          style: AppTextStyles.bodySmall(
                                              secondaryText)),
                                      const SizedBox(width: 12),
                                      Text(
                                          'Rs. ${item.totalPrice.toStringAsFixed(2)}',
                                          style: AppTextStyles.bodyMedium(
                                              primaryText)),
                                    ],
                                  ),
                                  const SizedBox(height: 3),
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 6, vertical: 2),
                                    decoration: BoxDecoration(
                                      color: AppColors.adminColor
                                          .withOpacity(0.08),
                                      borderRadius: BorderRadius.circular(5),
                                      border: Border.all(
                                          color: AppColors.adminColor
                                              .withOpacity(0.2)),
                                    ),
                                    child: Text('ID: ${item.id}',
                                        style: AppTextStyles.labelSmall(
                                            AppColors.adminColor)),
                                  ),
                                ],
                              ),
                            )),
                        const Divider(height: 20),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text('Delivery Charge',
                                style:
                                    AppTextStyles.bodyMedium(secondaryText)),
                            Text(
                                'Rs. ${order.deliveryCharge.toStringAsFixed(2)}',
                                style:
                                    AppTextStyles.bodyMedium(primaryText)),
                          ],
                        ),
                        const SizedBox(height: 6),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text('Order Total',
                                style: AppTextStyles.subtitle(primaryText)),
                            Text(
                                'Rs. ${order.totalPrice.toStringAsFixed(2)}',
                                style: AppTextStyles.subtitle(primaryText)),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 32),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _infoCard(
      Color cardColor, Color borderColor, List<Widget> children) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: borderColor),
      ),
      child: Column(
          crossAxisAlignment: CrossAxisAlignment.start, children: children),
    );
  }

  Widget _row(
      String label, String value, Color primary, Color secondary) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: AppTextStyles.bodyMedium(secondary)),
        Flexible(
            child: Text(value,
                style: AppTextStyles.bodyMedium(primary),
                textAlign: TextAlign.end)),
      ],
    );
  }

  Widget _divider() => const Divider(height: 16);
}
