import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../models/payment.dart';
import '../../../orders/models/order_model.dart';

class PaymentReceiptScreen extends ConsumerWidget {
  const PaymentReceiptScreen({super.key, required this.order, required this.payment});

  final OrderModel order;
  final PaymentModel payment;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primaryText = isDark ? AppColors.textPrimaryDark : AppColors.textPrimaryLight;
    final secondaryText = isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight;
    final cardColor = isDark ? AppColors.cardDark : AppColors.cardLight;
    final borderColor = isDark ? AppColors.borderDark : AppColors.borderLight;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Payment Receipt'),
        backgroundColor: AppColors.customerColor,
      ),
      backgroundColor: isDark ? AppColors.backgroundDark : AppColors.backgroundLight,
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: AppColors.customerColor,
                borderRadius: BorderRadius.circular(20),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Speedmart Lanka', style: AppTextStyles.h1(Colors.white)),
                  const SizedBox(height: 8),
                  Text('Payment Receipt', style: AppTextStyles.subtitle(Colors.white70)),
                ],
              ),
            ),
            const SizedBox(height: 20),
            Text('Receipt #${payment.receiptNumber}', style: AppTextStyles.subtitle(primaryText)),
            const SizedBox(height: 6),
            Text('Order ID: ${order.id}', style: AppTextStyles.bodyMedium(secondaryText)),
            const SizedBox(height: 4),
            Text('Date: ${payment.createdAt.toLocal()}', style: AppTextStyles.caption(secondaryText)),
            const SizedBox(height: 20),
            Container(
              decoration: BoxDecoration(
                color: cardColor,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: borderColor),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _receiptRow('Shop', order.vendorBusinessName, primaryText),
                  _receiptRow('Payment Status', payment.paymentStatus.displayName, primaryText),
                  _receiptRow('Payment Method', payment.paymentMethod.displayName, primaryText),
                  _receiptRow('Subtotal', 'Rs. ${payment.subtotal.toStringAsFixed(2)}', primaryText),
                  _receiptRow('Delivery Fee', 'Rs. ${payment.deliveryFee.toStringAsFixed(2)}', primaryText),
                  const Divider(),
                  _receiptRow('Total Paid', 'Rs. ${payment.amount.toStringAsFixed(2)}', AppColors.customerColor),
                ],
              ),
            ),
            const SizedBox(height: 20),
            Text('Delivery Information', style: AppTextStyles.h2(primaryText)),
            const SizedBox(height: 10),
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
                  Text('Customer', style: AppTextStyles.caption(secondaryText)),
                  const SizedBox(height: 4),
                  Text(order.customerName, style: AppTextStyles.bodyMedium(primaryText)),
                  const SizedBox(height: 12),
                  Text('Phone', style: AppTextStyles.caption(secondaryText)),
                  const SizedBox(height: 4),
                  Text(order.customerPhone, style: AppTextStyles.bodyMedium(primaryText)),
                  const SizedBox(height: 12),
                  Text('Address', style: AppTextStyles.caption(secondaryText)),
                  const SizedBox(height: 4),
                  Text(order.deliveryAddress, style: AppTextStyles.bodyMedium(primaryText)),
                ],
              ),
            ),
            const SizedBox(height: 30),
            SizedBox(
              width: double.infinity,
              height: 52,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.customerColor,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                ),
                onPressed: () {
                  Navigator.popUntil(context, (route) => route.isFirst);
                },
                child: const Text('Return to Dashboard', style: TextStyle(color: Colors.white)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _receiptRow(String label, String value, Color valueColor) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: AppTextStyles.bodyMedium(Colors.grey)),
          Expanded(
            child: Text(
              value,
              textAlign: TextAlign.right,
              style: AppTextStyles.bodyMedium(valueColor).copyWith(fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
  }
}

