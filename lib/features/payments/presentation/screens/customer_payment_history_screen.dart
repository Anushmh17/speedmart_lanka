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

  void _showPaymentDetail(
    BuildContext context,
    PaymentModel payment,
    bool isDark,
    Color primaryText,
    Color secondaryText,
    Color cardColor,
    Color borderColor,
  ) {
    final commission = payment.platformCommission != 0
        ? payment.platformCommission
        : payment.serviceFee;
    final customerSubtotal = payment.subtotal + commission;
    final bg = isDark ? AppColors.cardDark : Colors.white;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => DraggableScrollableSheet(
        initialChildSize: 0.7,
        minChildSize: 0.4,
        maxChildSize: 0.92,
        expand: false,
        builder: (_, scrollController) => Container(
          decoration: BoxDecoration(
            color: bg,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
          ),
          child: Column(
            children: [
              const SizedBox(height: 12),
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: borderColor,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 16),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: AppColors.customerColor.withValues(alpha: 0.12),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.receipt_long_rounded, color: AppColors.customerColor, size: 22),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Payment Receipt', style: AppTextStyles.h3(primaryText)),
                          Text(payment.receiptNumber,
                              style: AppTextStyles.caption(secondaryText)),
                        ],
                      ),
                    ),
                    _statusBadge(payment.paymentStatus.displayName),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              const Divider(height: 1),
              Expanded(
                child: ListView(
                  controller: scrollController,
                  padding: const EdgeInsets.fromLTRB(20, 20, 20, 32),
                  children: [
                    // Amount highlight
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: AppColors.customerColor.withValues(alpha: 0.08),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: AppColors.customerColor.withValues(alpha: 0.2)),
                      ),
                      child: Column(
                        children: [
                          Text('Total Paid', style: AppTextStyles.caption(secondaryText)),
                          const SizedBox(height: 6),
                          Text(
                            'Rs. ${payment.amount.toStringAsFixed(2)}',
                            style: AppTextStyles.h1(AppColors.customerColor),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            payment.paymentMethod.displayName,
                            style: AppTextStyles.bodySmall(AppColors.customerColor),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 20),
                    // Breakdown
                    _sectionTitle('Payment Breakdown', primaryText),
                    const SizedBox(height: 10),
                    _detailCard(cardColor, borderColor, [
                      _detailRow('Subtotal (incl. fees)', 'Rs. ${customerSubtotal.toStringAsFixed(2)}', primaryText, secondaryText),
                      _detailRow('Delivery Fee', 'Rs. ${payment.deliveryFee.toStringAsFixed(2)}', primaryText, secondaryText),
                      _divider(borderColor),
                      _detailRow('Total', 'Rs. ${payment.amount.toStringAsFixed(2)}', AppColors.customerColor, secondaryText, bold: true),
                    ]),
                    const SizedBox(height: 20),
                    // Order info
                    _sectionTitle('Order Information', primaryText),
                    const SizedBox(height: 10),
                    _detailCard(cardColor, borderColor, [
                      _detailRow('Order ID', payment.orderId.isNotEmpty ? payment.orderId : 'Pending', primaryText, secondaryText),
                      _detailRow('Fulfilled by', 'Verified Partner', primaryText, secondaryText),
                      _detailRow('Receipt Number', payment.receiptNumber, primaryText, secondaryText),
                    ]),
                    const SizedBox(height: 20),
                    // Dates
                    _sectionTitle('Timeline', primaryText),
                    const SizedBox(height: 10),
                    _detailCard(cardColor, borderColor, [
                      _detailRow('Created', payment.createdAt.toLocal().toString().split('.').first, primaryText, secondaryText),
                      if (payment.paidAt != null)
                        _detailRow('Paid At', payment.paidAt!.toLocal().toString().split('.').first, primaryText, secondaryText),
                    ]),
                    const SizedBox(height: 24),
                    if (payment.orderId.isNotEmpty)
                      SizedBox(
                        width: double.infinity,
                        height: 52,
                        child: OutlinedButton.icon(
                          onPressed: () {
                            Navigator.of(context).pop();
                            context.go(RouteNames.customerOrders);
                          },
                          icon: const Icon(Icons.local_shipping_outlined),
                          label: const Text('View in My Orders'),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: AppColors.customerColor,
                            side: const BorderSide(color: AppColors.customerColor),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _statusBadge(String status) {
    final isPositive = status.toLowerCase().contains('paid') ||
        status.toLowerCase().contains('confirmed') ||
        status.toLowerCase().contains('cod');
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: isPositive
            ? AppColors.success.withValues(alpha: 0.12)
            : Colors.orange.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        status,
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w600,
          color: isPositive ? AppColors.success : Colors.orange,
        ),
      ),
    );
  }

  Widget _sectionTitle(String title, Color color) =>
      Text(title, style: AppTextStyles.subtitle(color));

  Widget _detailCard(Color cardColor, Color borderColor, List<Widget> children) =>
      Container(
        decoration: BoxDecoration(
          color: cardColor,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: borderColor),
        ),
        child: Column(children: children),
      );

  Widget _detailRow(String label, String value, Color valueColor, Color labelColor, {bool bold = false}) =>
      Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(label, style: AppTextStyles.bodyMedium(labelColor)),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                value,
                textAlign: TextAlign.right,
                style: AppTextStyles.bodyMedium(valueColor)
                    .copyWith(fontWeight: bold ? FontWeight.w700 : FontWeight.w600),
              ),
            ),
          ],
        ),
      );

  Widget _divider(Color color) => Divider(height: 1, color: color);

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
                          return Material(
                            color: Colors.transparent,
                            child: InkWell(
                              borderRadius: BorderRadius.circular(18),
                              onTap: () => _showPaymentDetail(
                                context, payment, isDark, primaryText,
                                secondaryText, cardColor, borderColor,
                              ),
                              child: Ink(
                                decoration: BoxDecoration(
                                  color: cardColor,
                                  borderRadius: BorderRadius.circular(18),
                                  border: Border.all(color: borderColor),
                                ),
                                child: Padding(
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
                                              style: AppTextStyles.subtitle(primaryText)
                                                  .copyWith(fontWeight: FontWeight.bold),
                                            ),
                                          ),
                                          Text(
                                            'Rs. ${payment.amount.toStringAsFixed(2)}',
                                            style: AppTextStyles.h3(AppColors.customerColor),
                                          ),
                                        ],
                                      ),
                                      const SizedBox(height: 10),
                                      _historyRow('Order ID',
                                          payment.orderId.isNotEmpty ? payment.orderId : 'Pending',
                                          secondaryText),
                                      _historyRow('Method', payment.paymentMethod.displayName, secondaryText),
                                      _historyRow('Status', payment.paymentStatus.displayName, secondaryText),
                                      _historyRow('Date',
                                          date.toLocal().toString().split('.').first, secondaryText),
                                      const SizedBox(height: 6),
                                      Row(
                                        mainAxisAlignment: MainAxisAlignment.end,
                                        children: [
                                          Text(
                                            'Tap for details',
                                            style: AppTextStyles.caption(AppColors.customerColor)
                                                .copyWith(fontStyle: FontStyle.italic),
                                          ),
                                          const SizedBox(width: 4),
                                          const Icon(Icons.arrow_forward_ios_rounded,
                                              size: 12, color: AppColors.customerColor),
                                        ],
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          );
                        },
                      ),
      ),
    );
  }

  Widget _historyRow(String label, String value, Color color) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
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
            Text(
              'Your confirmed COD and online payments will appear here once completed.',
              style: AppTextStyles.bodyMedium(secondaryText),
              textAlign: TextAlign.center,
            ),
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
            const Icon(Icons.error_outline_rounded, size: 48, color: Colors.redAccent),
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
