import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/routes/route_names.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../payments/models/payment.dart';
import '../../providers/payment_provider.dart';
import '../../../../features/auth/providers/auth_provider.dart';
import '../../../../shared/models/user_role.dart';

class CustomerPaymentHistoryScreen extends ConsumerStatefulWidget {
  const CustomerPaymentHistoryScreen({super.key});

  @override
  ConsumerState<CustomerPaymentHistoryScreen> createState() => _CustomerPaymentHistoryScreenState();
}

class _CustomerPaymentHistoryScreenState extends ConsumerState<CustomerPaymentHistoryScreen> {
  bool _hasLoaded = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_hasLoaded) {
      final user = ref.read(currentUserProvider);
      if (user?.role != UserRole.customer) {
        debugPrint('[CustomerPaymentHistory] Skipping payment load for non-customer user');
        return;
      }
      _hasLoaded = true;
      Future.microtask(() => ref.read(paymentProvider.notifier).loadCustomerPayments());
    }
  }

  @override
  Widget build(BuildContext context) {
    final paymentState = ref.watch(paymentProvider);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primaryText = isDark ? AppColors.textPrimaryDark : AppColors.textPrimaryLight;
    final secondaryText = isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight;
    final cardColor = isDark ? AppColors.cardDark : AppColors.cardLight;
    final borderColor = isDark ? AppColors.borderDark : AppColors.borderLight;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Payment History'),
        backgroundColor: AppColors.customerColor,
        leading: BackButton(onPressed: () {
          if (context.canPop()) {
            context.pop();
          } else {
            context.go(RouteNames.customerProfile);
          }
        }),
      ),
      backgroundColor: isDark ? AppColors.backgroundDark : AppColors.backgroundLight,
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: paymentState.isLoading
            ? const Center(child: CircularProgressIndicator())
            : paymentState.error != null
                ? _buildErrorState(paymentState.error!, primaryText, secondaryText, cardColor, borderColor)
                : paymentState.payments.isEmpty
                    ? _buildEmptyState(primaryText, secondaryText, cardColor, borderColor)
                    : ListView.separated(
                        itemCount: paymentState.payments.length,
                        separatorBuilder: (_, __) => const SizedBox(height: 14),
                        itemBuilder: (context, index) {
                          final payment = paymentState.payments[index];
                          final date = payment.paidAt ?? payment.createdAt;
                          return Container(
                            decoration: BoxDecoration(
                              color: cardColor,
                              borderRadius: BorderRadius.circular(18),
                              border: Border.all(color: borderColor),
                            ),
                            padding: const EdgeInsets.all(16),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    Expanded(
                                      child: Text(
                                        payment.receiptNumber,
                                        style: AppTextStyles.subtitle(primaryText).copyWith(fontWeight: FontWeight.bold),
                                      ),
                                    ),
                                    Text('Rs. ${payment.amount.toStringAsFixed(2)}', style: AppTextStyles.h3(AppColors.customerColor)),
                                  ],
                                ),
                                const SizedBox(height: 10),
                                _historyRow('Order ID', payment.orderId.isNotEmpty ? payment.orderId : 'Pending', secondaryText),
                                _historyRow('Shop', payment.vendorBusinessName.isNotEmpty ? payment.vendorBusinessName : payment.vendorId, secondaryText),
                                _historyRow('Method', payment.paymentMethod.displayName, secondaryText),
                                _historyRow('Status', payment.paymentStatus.displayName, secondaryText),
                                _historyRow('Date', date.toLocal().toString().split('.').first, secondaryText),
                              ],
                            ),
                          );
                        },
                      ),
      ),
    );
  }

  Widget _historyRow(String label, String value, Color color) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: AppTextStyles.caption(color)),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              value,
              textAlign: TextAlign.right,
              style: AppTextStyles.bodyMedium(color).copyWith(fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState(Color primaryText, Color secondaryText, Color cardColor, Color borderColor) {
    return Center(
      child: Container(
        padding: const EdgeInsets.all(22),
        decoration: BoxDecoration(
          color: cardColor,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: borderColor),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.history_edu_rounded, size: 48, color: AppColors.customerColor),
            const SizedBox(height: 16),
            Text('No payments yet', style: AppTextStyles.h2(primaryText)),
            const SizedBox(height: 8),
            Text('Your confirmed COD and mock online payments will appear here once completed.',
                style: AppTextStyles.bodyMedium(secondaryText), textAlign: TextAlign.center),
          ],
        ),
      ),
    );
  }

  Widget _buildErrorState(String error, Color primaryText, Color secondaryText, Color cardColor, Color borderColor) {
    return Center(
      child: Container(
        padding: const EdgeInsets.all(22),
        decoration: BoxDecoration(
          color: cardColor,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: borderColor),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.error_outline_rounded, size: 48, color: Colors.redAccent),
            const SizedBox(height: 16),
            Text('Unable to load payments', style: AppTextStyles.h2(primaryText)),
            const SizedBox(height: 8),
            Text(error, style: AppTextStyles.bodyMedium(secondaryText), textAlign: TextAlign.center),
            const SizedBox(height: 16),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: AppColors.customerColor),
              onPressed: () => ref.read(paymentProvider.notifier).loadCustomerPayments(),
              child: const Text('Try Again'),
            ),
          ],
        ),
      ),
    );
  }
}

