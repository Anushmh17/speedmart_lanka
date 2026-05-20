import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../core/widgets/app_state_widgets.dart';
import '../../../../core/providers/notification_provider.dart';
import '../../../proposals/models/proposal.dart';
import '../../../requests/providers/request_provider.dart';
import '../../models/order_model.dart';
import '../../providers/order_provider.dart';
import '../widgets/order_tracking_map.dart';

class OrderTrackingScreen extends ConsumerStatefulWidget {
  const OrderTrackingScreen({super.key, required this.order});
  final OrderModel order;

  @override
  ConsumerState<OrderTrackingScreen> createState() =>
      _OrderTrackingScreenState();
}

class _OrderTrackingScreenState extends ConsumerState<OrderTrackingScreen> {
  double _riderProgress = 0.0;
  Timer? _riderTimer;
  bool _autoDelivered = false;

  static const double _timerDurationSeconds = 30.0;

  @override
  void initState() {
    super.initState();
    // Defer timer setup until after first frame so ref.read is valid
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _syncTimerWithStatus();
    });
  }

  @override
  void dispose() {
    _riderTimer?.cancel();
    super.dispose();
  }

  /// Starts / stops the rider simulation timer based on the current order status.
  void _syncTimerWithStatus() {
    final orderState = ref.read(orderProvider);
    final activeOrder = orderState.orders.firstWhere(
      (o) => o.id == widget.order.id,
      orElse: () => widget.order,
    );

    if (activeOrder.status == OrderStatus.outForDelivery &&
        _riderTimer == null &&
        !_autoDelivered) {
      _startRiderSimulation();
    }
  }

  void _startRiderSimulation() {
    _riderTimer?.cancel();
    const tickInterval = Duration(milliseconds: 500);
    final incrementPerTick = 0.5 / _timerDurationSeconds; // each 500ms tick

    _riderTimer = Timer.periodic(tickInterval, (timer) async {
      if (!mounted) {
        timer.cancel();
        return;
      }

      final newProgress = (_riderProgress + incrementPerTick).clamp(0.0, 1.0);

      setState(() {
        _riderProgress = newProgress;
      });

      if (newProgress >= 1.0 && !_autoDelivered) {
        _autoDelivered = true;
        timer.cancel();
        await _completeDelivery();
      }
    });
  }

  Future<void> _completeDelivery() async {
    final orderState = ref.read(orderProvider);
    final activeOrder = orderState.orders.firstWhere(
      (o) => o.id == widget.order.id,
      orElse: () => widget.order,
    );

    // Only auto-complete if still outForDelivery
    if (activeOrder.status != OrderStatus.outForDelivery) return;

    await ref
        .read(orderProvider.notifier)
        .updateOrderStatus(activeOrder.id, OrderStatus.delivered);

    ref.read(notificationProvider.notifier).triggerNotification(
          title: '🎉 Order Delivered!',
          body:
              'Your order ${activeOrder.id} has arrived! Enjoy your items from ${activeOrder.vendorBusinessName}.',
          icon: Icons.task_alt_rounded,
          color: AppColors.customerColor,
        );

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Row(
            children: [
              Icon(Icons.check_circle_rounded, color: Colors.white, size: 20),
              SizedBox(width: 10),
              Text('🎉 Order delivered successfully!'),
            ],
          ),
          backgroundColor: AppColors.success,
          behavior: SnackBarBehavior.floating,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          duration: const Duration(seconds: 4),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primaryText =
        isDark ? AppColors.textPrimaryDark : AppColors.textPrimaryLight;
    final secondaryText =
        isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight;
    final cardColor = isDark ? AppColors.cardDark : AppColors.cardLight;
    final borderColor = isDark ? AppColors.borderDark : AppColors.borderLight;

    // Live order state from provider
    final orderState = ref.watch(orderProvider);
    final activeOrder = orderState.orders.firstWhere(
      (o) => o.id == widget.order.id,
      orElse: () => widget.order,
    );

    // Kick off rider timer reactively whenever status flips to outForDelivery
    final isOutForDelivery = activeOrder.status == OrderStatus.outForDelivery;
    if (isOutForDelivery && _riderTimer == null && !_autoDelivered) {
      WidgetsBinding.instance
          .addPostFrameCallback((_) => _startRiderSimulation());
    }

    // ---------- Coordinate Resolution ----------
    // Customer coordinates: look up the original request by requestId
    final requestState = ref.watch(requestProvider);
    final matchedRequest = requestState.requests
        .where((r) => r.id == activeOrder.requestId)
        .firstOrNull;
    final customerLat = matchedRequest?.latitude ?? 6.9145; // Colombo 03 default
    final customerLon = matchedRequest?.longitude ?? 79.8510;

    // Vendor coordinates: use the vendor coordinates stored directly in activeOrder
    final vendorLat = activeOrder.vendorLatitude;
    final vendorLon = activeOrder.vendorLongitude;
    // ------------------------------------------

    return Scaffold(
      backgroundColor:
          isDark ? AppColors.backgroundDark : AppColors.backgroundLight,
      appBar: AppBar(
        title: Text('Track ${activeOrder.id}'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded),
          onPressed: () => context.pop(),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ─────────────────────────────────────────────────────────────
            // SECTION 1 — Interactive Live Map
            // ─────────────────────────────────────────────────────────────
            _MapSection(
              isDark: isDark,
              primaryText: primaryText,
              activeOrder: activeOrder,
              customerLat: customerLat,
              customerLon: customerLon,
              vendorLat: vendorLat,
              vendorLon: vendorLon,
              riderProgress: isOutForDelivery
                  ? _riderProgress
                  : activeOrder.status == OrderStatus.delivered
                      ? 1.0
                      : 0.0,
            ),
            const SizedBox(height: 24),

            // ─────────────────────────────────────────────────────────────
            // SECTION 2 — Delivery Timeline
            // ─────────────────────────────────────────────────────────────
            Text('Delivery Timeline', style: AppTextStyles.h2(primaryText)),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: cardColor,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: borderColor),
              ),
              child: Column(
                children: [
                  _StatusStep(
                    title: 'Order Confirmed',
                    subtitle: 'Merchant has accepted and confirmed your bid.',
                    isCompleted: true,
                    isActive: activeOrder.status == OrderStatus.preparing,
                  ),
                  _StatusLine(isCompleted: true),
                  _StatusStep(
                    title: 'Preparing Order',
                    subtitle: 'Merchant is gathering and packaging your items.',
                    isCompleted: activeOrder.status == OrderStatus.preparing ||
                        activeOrder.status == OrderStatus.outForDelivery ||
                        activeOrder.status == OrderStatus.delivered,
                    isActive: activeOrder.status == OrderStatus.preparing,
                  ),
                  _StatusLine(
                      isCompleted:
                          activeOrder.status == OrderStatus.outForDelivery ||
                              activeOrder.status == OrderStatus.delivered),
                  _StatusStep(
                    title: 'Out for Delivery',
                    subtitle: 'Rider is on the way to your location.',
                    isCompleted:
                        activeOrder.status == OrderStatus.outForDelivery ||
                            activeOrder.status == OrderStatus.delivered,
                    isActive: activeOrder.status == OrderStatus.outForDelivery,
                  ),
                  _StatusLine(
                      isCompleted:
                          activeOrder.status == OrderStatus.delivered),
                  _StatusStep(
                    title: 'Delivered',
                    subtitle: 'Package successfully delivered. Thank you!',
                    isCompleted:
                        activeOrder.status == OrderStatus.delivered,
                    isActive: activeOrder.status == OrderStatus.delivered,
                    isLast: true,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),

            // ─────────────────────────────────────────────────────────────
            // SECTION 3 — Merchant Contact
            // ─────────────────────────────────────────────────────────────
            Text('Merchant Contact Details',
                style: AppTextStyles.h2(primaryText)),
            const SizedBox(height: 12),
            InkWell(
              onTap: () {
                context.push(
                  '/customer/vendor/shopfront',
                  extra: {
                    'vendorName': activeOrder.vendorBusinessName,
                    'vendorPhone': activeOrder.vendorPhone,
                  },
                );
              },
              borderRadius: BorderRadius.circular(16),
              child: Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: cardColor,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: borderColor),
                ),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: AppColors.customerColor.withOpacity(0.15),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.storefront_rounded,
                          color: AppColors.customerColor, size: 28),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(activeOrder.vendorBusinessName,
                              style: AppTextStyles.subtitle(primaryText)),
                          const SizedBox(height: 4),
                          Row(
                            children: [
                              const Icon(Icons.phone,
                                  size: 14,
                                  color: AppColors.customerColor),
                              const SizedBox(width: 6),
                              Text(activeOrder.vendorPhone,
                                  style:
                                      AppTextStyles.bodyMedium(secondaryText)),
                            ],
                          ),
                          const SizedBox(height: 6),
                          Text(
                            'Tap to view Storefront & Catalog ➔',
                            style: AppTextStyles.caption(AppColors.customerColor)
                                .copyWith(fontWeight: FontWeight.bold),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      style: IconButton.styleFrom(
                        backgroundColor:
                            AppColors.customerColor.withOpacity(0.12),
                      ),
                      icon: const Icon(Icons.chat_bubble_outline_rounded,
                          color: AppColors.customerColor),
                      onPressed: () {
                        context.push(
                          '/chat',
                          extra: {
                            'proposalId': activeOrder.proposalId,
                            'vendorName': activeOrder.vendorBusinessName,
                            'isUnlocked': true,
                          },
                        );
                      },
                    ),
                    const SizedBox(width: 8),
                    IconButton(
                      style: IconButton.styleFrom(
                        backgroundColor:
                            AppColors.customerColor.withOpacity(0.12),
                      ),
                      icon: const Icon(Icons.call,
                          color: AppColors.customerColor),
                      onPressed: () {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(
                                'Calling ${activeOrder.vendorBusinessName} at ${activeOrder.vendorPhone}...'),
                            behavior: SnackBarBehavior.floating,
                          ),
                        );
                      },
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 24),

            // ─────────────────────────────────────────────────────────────
            // SECTION 4 — Items Summary
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
                            Text(itemName,
                                style: AppTextStyles.bodyLarge(primaryText)),
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
            // SECTION 5 — Payment & Receipt
            // ─────────────────────────────────────────────────────────────
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
                      Text('Payment Status:',
                          style: AppTextStyles.bodyMedium(secondaryText)),
                      StatusBadge(
                        label: activeOrder.paymentStatus.name.toUpperCase(),
                        color: activeOrder.paymentStatus == PaymentStatus.paid
                            ? AppColors.success
                            : AppColors.warning,
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
                  const Divider(height: 24),
                  ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.customerColor,
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12)),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      minimumSize: const Size(double.infinity, 44),
                      elevation: 0,
                    ),
                    icon:
                        const Icon(Icons.download_rounded, color: Colors.white),
                    label: Text('Download LKR Receipt (PDF)',
                        style: AppTextStyles.button(Colors.white)),
                    onPressed: () => _showReceiptDialog(
                        context, activeOrder, isDark),
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

  // ── Receipt dialog extracted for readability ──────────────────────────
  void _showReceiptDialog(
      BuildContext context, OrderModel activeOrder, bool isDark) {
    showDialog(
      context: context,
      builder: (ctx) {
        final isDarkCtx = Theme.of(ctx).brightness == Brightness.dark;
        final txtColor = isDarkCtx ? Colors.white : Colors.black;
        final subtotal =
            activeOrder.totalPrice / 1.22 - activeOrder.deliveryCharge / 1.22;
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
            ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.customerColor,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10)),
              ),
              icon: const Icon(Icons.share_rounded, size: 16, color: Colors.white),
              label: const Text('Share Receipt',
                  style: TextStyle(color: Colors.white, fontSize: 12)),
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
                  fontSize: 12, color: color.withOpacity(0.7))),
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

// ─────────────────────────────────────────────────────────────────────────────
// Map Section Widget
// ─────────────────────────────────────────────────────────────────────────────
class _MapSection extends StatelessWidget {
  const _MapSection({
    required this.isDark,
    required this.primaryText,
    required this.activeOrder,
    required this.customerLat,
    required this.customerLon,
    required this.vendorLat,
    required this.vendorLon,
    required this.riderProgress,
  });

  final bool isDark;
  final Color primaryText;
  final OrderModel activeOrder;
  final double customerLat;
  final double customerLon;
  final double vendorLat;
  final double vendorLon;
  final double riderProgress;

  @override
  Widget build(BuildContext context) {
    // Only show the live map card if order is in a delivery-relevant state
    final bool showMap = activeOrder.status == OrderStatus.outForDelivery ||
        activeOrder.status == OrderStatus.delivered ||
        activeOrder.status == OrderStatus.preparing;

    if (!showMap) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Section header with status badge
        Row(
          children: [
            Text('Live Tracking Map', style: AppTextStyles.h2(primaryText)),
            const Spacer(),
            if (activeOrder.status == OrderStatus.outForDelivery)
              _PulsingLiveDot(),
          ],
        ),
        const SizedBox(height: 12),

        // Map widget with premium card wrapper
        Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(24),
            boxShadow: [
              BoxShadow(
                color: AppColors.customerColor.withOpacity(
                    activeOrder.status == OrderStatus.outForDelivery
                        ? 0.18
                        : 0.06),
                blurRadius: 24,
                offset: const Offset(0, 10),
              ),
            ],
          ),
          child: OrderTrackingMap(
            customerLatitude: customerLat,
            customerLongitude: customerLon,
            vendorLatitude: vendorLat,
            vendorLongitude: vendorLon,
            riderProgress: riderProgress,
            vendorBusinessName: activeOrder.vendorBusinessName,
          ),
        ),

        // Progress pill — only visible during active delivery
        if (activeOrder.status == OrderStatus.outForDelivery) ...[
          const SizedBox(height: 14),
          _RiderProgressBar(progress: riderProgress, isDark: isDark),
        ],

        // Delivered celebration banner
        if (activeOrder.status == OrderStatus.delivered) ...[
          const SizedBox(height: 14),
          _DeliveredBanner(isDark: isDark),
        ],
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Rider Progress Bar
// ─────────────────────────────────────────────────────────────────────────────
class _RiderProgressBar extends StatelessWidget {
  const _RiderProgressBar(
      {required this.progress, required this.isDark});

  final double progress;
  final bool isDark;

  @override
  Widget build(BuildContext context) {
    final int etaSeconds =
        ((1.0 - progress) * 30).ceil().clamp(0, 30);
    final String etaText = etaSeconds > 0 ? '~$etaSeconds sec away' : 'Arriving!';

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: isDark ? AppColors.cardDark : AppColors.cardLight,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: AppColors.customerColor.withOpacity(0.35),
          width: 1.5,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.delivery_dining_rounded,
                  color: AppColors.customerColor, size: 18),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Rider En Route',
                  style: AppTextStyles.bodyMedium(
                          isDark
                              ? AppColors.textPrimaryDark
                              : AppColors.textPrimaryLight)
                      .copyWith(fontWeight: FontWeight.bold),
                ),
              ),
              Text(
                etaText,
                style: AppTextStyles.caption(AppColors.customerColor)
                    .copyWith(fontWeight: FontWeight.w600),
              ),
            ],
          ),
          const SizedBox(height: 10),
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: LinearProgressIndicator(
              value: progress,
              minHeight: 8,
              backgroundColor: isDark ? Colors.grey.shade800 : Colors.grey.shade200,
              valueColor:
                  const AlwaysStoppedAnimation<Color>(AppColors.customerColor),
            ),
          ),
          const SizedBox(height: 6),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Merchant',
                  style: TextStyle(
                      fontSize: 10,
                      color: isDark ? Colors.white54 : Colors.black38)),
              Text('Your Door',
                  style: TextStyle(
                      fontSize: 10,
                      color: isDark ? Colors.white54 : Colors.black38)),
            ],
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Delivered Success Banner
// ─────────────────────────────────────────────────────────────────────────────
class _DeliveredBanner extends StatelessWidget {
  const _DeliveredBanner({required this.isDark});
  final bool isDark;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            AppColors.success.withOpacity(0.15),
            AppColors.success.withOpacity(0.05),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.success.withOpacity(0.4)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: AppColors.success.withOpacity(0.15),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.task_alt_rounded,
                color: AppColors.success, size: 26),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '🎉 Order Delivered!',
                  style: AppTextStyles.subtitle(
                      isDark ? AppColors.textPrimaryDark : AppColors.textPrimaryLight)
                    ..copyWith(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 2),
                Text(
                  'Your items have been delivered. Thank you for using Speedmart Lanka!',
                  style: AppTextStyles.caption(
                      isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Pulsing LIVE Dot Indicator
// ─────────────────────────────────────────────────────────────────────────────
class _PulsingLiveDot extends StatefulWidget {
  @override
  State<_PulsingLiveDot> createState() => _PulsingLiveDotState();
}

class _PulsingLiveDotState extends State<_PulsingLiveDot>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _pulseAnim;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    )..repeat(reverse: true);
    _pulseAnim =
        Tween<double>(begin: 0.5, end: 1.0).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _pulseAnim,
      builder: (context, _) {
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          decoration: BoxDecoration(
            color: AppColors.error.withOpacity(0.12),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: AppColors.error.withOpacity(0.5)),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 8,
                height: 8,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: AppColors.error.withOpacity(_pulseAnim.value),
                ),
              ),
              const SizedBox(width: 5),
              Text(
                'LIVE',
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                  color: AppColors.error,
                  letterSpacing: 1,
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Status Timeline Step
// ─────────────────────────────────────────────────────────────────────────────
class _StatusStep extends StatelessWidget {
  const _StatusStep({
    required this.title,
    required this.subtitle,
    required this.isCompleted,
    required this.isActive,
    this.isLast = false,
  });

  final String title;
  final String subtitle;
  final bool isCompleted;
  final bool isActive;
  final bool isLast;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Column(
          children: [
            Container(
              width: 28,
              height: 28,
              decoration: BoxDecoration(
                color: isCompleted
                    ? (isActive ? AppColors.customerColor : AppColors.success)
                    : (isDark ? Colors.grey.shade800 : Colors.grey.shade200),
                shape: BoxShape.circle,
                border: isActive
                    ? Border.all(
                        color: isDark ? Colors.white : Colors.black, width: 2)
                    : null,
              ),
              child: Icon(
                isCompleted ? Icons.check : Icons.circle,
                size: isCompleted ? 16 : 8,
                color: isCompleted ? Colors.white : Colors.grey,
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
                title,
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                  color: isCompleted
                      ? (isDark ? Colors.white : Colors.black)
                      : (isDark ? Colors.grey.shade600 : Colors.grey.shade400),
                ),
              ),
              const SizedBox(height: 2),
              Text(
                subtitle,
                style: TextStyle(
                  fontSize: 11,
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
}

class _StatusLine extends StatelessWidget {
  const _StatusLine({required this.isCompleted});
  final bool isCompleted;

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.only(left: 13),
        width: 2,
        height: 24,
        color: isCompleted ? AppColors.success : Colors.grey.shade300,
      ),
    );
  }
}
