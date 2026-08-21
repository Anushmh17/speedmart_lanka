import 'dart:io';
import 'package:flutter/services.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:speedmart_lanka/core/theme/app_colors.dart';
import 'package:speedmart_lanka/core/theme/app_text_styles.dart';
import 'package:speedmart_lanka/core/widgets/theme3/theme3_app_button.dart';
import 'package:speedmart_lanka/features/proposals/models/proposal.dart';
import 'package:speedmart_lanka/features/proposals/providers/proposal_provider.dart';
import 'package:speedmart_lanka/features/orders/data/order_repository.dart';
import 'package:speedmart_lanka/features/orders/data/order_workflow_service.dart';
import 'package:speedmart_lanka/features/orders/models/order_model.dart';
import 'package:speedmart_lanka/features/orders/providers/order_provider.dart';
import 'package:speedmart_lanka/features/orders/services/vendor_delivery_access_service.dart';
import 'package:speedmart_lanka/core/services/connectivity_service.dart';
import 'package:speedmart_lanka/core/providers/notification_provider.dart';
import 'package:speedmart_lanka/features/notifications/models/notification_type.dart';
import 'package:speedmart_lanka/features/notifications/providers/notification_provider.dart'
    as notification_feature;
import 'package:speedmart_lanka/features/payments/models/payment.dart';
import 'package:speedmart_lanka/features/payments/data/payment_repository.dart';
import 'package:speedmart_lanka/features/requests/models/request_category_fulfillment.dart';
import 'package:speedmart_lanka/features/requests/data/request_repository.dart';
import 'package:speedmart_lanka/features/location/services/location_service.dart';
import 'package:speedmart_lanka/features/vendor/proposals/widgets/image_gallery_viewer.dart';
import 'package:speedmart_lanka/core/utils/error_translator.dart';

class VendorOrderDetailsScreen extends ConsumerStatefulWidget {
  const VendorOrderDetailsScreen({super.key, required this.order});
  final OrderModel order;

  @override
  ConsumerState<VendorOrderDetailsScreen> createState() => _VendorOrderDetailsScreenState();
}

class _VendorOrderDetailsScreenState extends ConsumerState<VendorOrderDetailsScreen> with SingleTickerProviderStateMixin {
  final Map<String, bool> _packedItems = {};
  late final AnimationController _packedPulseController;
  bool _isUpdatingStatus = false;

  Widget _buildSummaryChip(String label, Color secondaryText) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: AppColors.vendorColor.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: AppColors.vendorColor.withValues(alpha: 0.18)),
      ),
      child: Text(label, style: AppTextStyles.caption(secondaryText)),
    );
  }

  String _formatDateTime(DateTime value) {
    final local = value.toLocal();
    final day = local.day.toString().padLeft(2, '0');
    final month = local.month.toString().padLeft(2, '0');
    final hour = local.hour.toString().padLeft(2, '0');
    final minute = local.minute.toString().padLeft(2, '0');
    return '$day/$month/${local.year} at $hour:$minute';
  }

  @override
  void initState() {
    super.initState();
    _packedPulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 700),
    );
    _loadPackedItems();
  }

  Future<void> _loadPackedItems() async {
    final saved = await OrderRepository.instance.loadPackedItems(widget.order.id);
    if (mounted) {
      setState(() => _packedItems.addAll(saved));
    }
  }

  Future<void> _savePackedItem(String itemId, bool value) async {
    setState(() => _packedItems[itemId] = value);
    await OrderRepository.instance.savePackedItems(widget.order.id, Map.from(_packedItems));
  }

  @override
  void dispose() {
    _packedPulseController.dispose();
    super.dispose();
  }

  Future<void> _handleMarkCashCollected(
    BuildContext context,
    OrderModel order,
  ) async {
    final online = await ConnectivityService.instance.isOnline();
    if (!online) {
      if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No network. Check your connection and try again.')),
      );
      return;
    }
    await OrderWorkflowService.instance.completeCodDelivery(order.id);

    // Notify customer
    ref.read(notificationProvider.notifier).triggerNotification(
      title: 'Payment Received! ðŸ’°',
      body: 'Vendor confirmed cash collection for order ${order.id}.',
      icon: Icons.paid_rounded,
      color: AppColors.success,
    );

    // Reload vendor orders
    await ref.read(orderProvider.notifier).loadVendorOrders();

    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Cash collected and payment confirmed!'),
          backgroundColor: AppColors.success,
        ),
      );
      context.pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primaryText = isDark ? AppColors.textPrimaryDark : AppColors.textPrimaryLight;
    final secondaryText = isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight;
    final cardColor = isDark ? AppColors.cardDark : AppColors.cardLight;
    final borderColor = isDark ? AppColors.borderDark : AppColors.borderLight;

    // Listen to order state in real-time
    final orderState = ref.watch(orderProvider);
    final activeOrder = orderState.orders.firstWhere(
      (o) => o.id == widget.order.id,
      orElse: () => widget.order,
    );
    final isSummaryOnly = activeOrder.status == OrderStatus.delivered ||
        activeOrder.status == OrderStatus.completed ||
        activeOrder.status == OrderStatus.cancelled;

    return Scaffold(
      backgroundColor: isDark ? AppColors.backgroundDark : AppColors.backgroundLight,
      appBar: AppBar(
        title: Text(isSummaryOnly ? 'Order Summary' : 'Manage ${activeOrder.id}'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded),
          onPressed: () => context.pop(),
        ),
      ),
      body: Column(
        children: [
          Expanded(
            child: RefreshIndicator(
              onRefresh: () async => ref.read(orderProvider.notifier).loadVendorOrders(),
              color: AppColors.vendorColor,
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
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
                            Text(activeOrder.status.displayName, style: AppTextStyles.bodyMedium(primaryText)),
                          ],
                        ),
                        const SizedBox(height: 6),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text('Order Date:', style: AppTextStyles.bodyMedium(secondaryText)),
                            Text(
                              _formatDateTime(activeOrder.createdAt),
                              style: AppTextStyles.bodyMedium(primaryText),
                            ),
                          ],
                        ),
                        if (activeOrder.updatedAt != null) ...[
                          const SizedBox(height: 6),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text('Last Updated:', style: AppTextStyles.bodyMedium(secondaryText)),
                              Text(
                                _formatDateTime(activeOrder.updatedAt!),
                                style: AppTextStyles.bodyMedium(primaryText),
                              ),
                            ],
                          ),
                        ],
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),

                  if (isSummaryOnly) ...[
                    Text('Items Ordered', style: AppTextStyles.h2(primaryText)),
                    const SizedBox(height: 12),
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: cardColor,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: borderColor),
                      ),
                      child: activeOrder.items.isEmpty
                          ? Text(
                              'No items were listed for this order.',
                              style: AppTextStyles.bodyMedium(secondaryText),
                            )
                          : Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: activeOrder.items.map((item) {
                                final itemName = item.status == ProposalItemStatus.alternative
                                    ? '${item.alternativeName} (Alternative)'
                                    : item.requestItemName;
                                final allUrls = [
                                  if (item.imageUrl != null && item.imageUrl!.isNotEmpty) item.imageUrl!,
                                  ...item.vendorImageUrls.where((u) => u.isNotEmpty),
                                ];

                                return Container(
                                  margin: const EdgeInsets.only(bottom: 12),
                                  padding: const EdgeInsets.all(12),
                                  decoration: BoxDecoration(
                                    color: AppColors.vendorColor.withValues(alpha: 0.05),
                                    borderRadius: BorderRadius.circular(12),
                                    border: Border.all(color: AppColors.vendorColor.withValues(alpha: 0.18)),
                                  ),
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Row(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Expanded(
                                            child: Column(
                                              crossAxisAlignment: CrossAxisAlignment.start,
                                              children: [
                                                Text(
                                                  itemName,
                                                  style: AppTextStyles.bodyLarge(primaryText),
                                                ),
                                                const SizedBox(height: 4),
                                                Text(
                                                  'Product ID: ${item.id}',
                                                  style: AppTextStyles.caption(AppColors.vendorColor).copyWith(fontWeight: FontWeight.w700),
                                                ),
                                              ],
                                            ),
                                          ),
                                          Text(
                                            'Rs. ${item.totalPrice.toStringAsFixed(2)}',
                                            style: AppTextStyles.bodyMedium(primaryText).copyWith(fontWeight: FontWeight.w700),
                                          ),
                                        ],
                                      ),
                                      const SizedBox(height: 8),
                                      Wrap(
                                        spacing: 8,
                                        runSpacing: 6,
                                        children: [
                                          _buildSummaryChip('Qty: ${item.quantity}', secondaryText),
                                          _buildSummaryChip('Status: ${item.status.name}', secondaryText),
                                        ],
                                      ),
                                      if (allUrls.isNotEmpty) ...[
                                        const SizedBox(height: 10),
                                        Text('Attached photos', style: AppTextStyles.caption(secondaryText)),
                                        const SizedBox(height: 6),
                                        SizedBox(
                                          height: 88,
                                          child: ListView.builder(
                                            scrollDirection: Axis.horizontal,
                                            itemCount: allUrls.length,
                                            itemBuilder: (context, index) {
                                              final url = allUrls[index];
                                              final isNetwork = url.startsWith('http://') || url.startsWith('https://');
                                              return GestureDetector(
                                                onTap: () => Navigator.of(context).push(
                                                  MaterialPageRoute(
                                                    builder: (_) => ImageGalleryViewer(imagePaths: allUrls, initialIndex: index),
                                                  ),
                                                ),
                                                child: Container(
                                                  width: 88,
                                                  height: 88,
                                                  margin: EdgeInsets.only(right: index < allUrls.length - 1 ? 8 : 0),
                                                  decoration: BoxDecoration(
                                                    color: borderColor,
                                                    borderRadius: BorderRadius.circular(10),
                                                  ),
                                                  child: ClipRRect(
                                                    borderRadius: BorderRadius.circular(10),
                                                    child: isNetwork
                                                        ? Image.network(
                                                            url,
                                                            width: 88,
                                                            height: 88,
                                                            fit: BoxFit.cover,
                                                            errorBuilder: (_, __, ___) => const Icon(Icons.broken_image_outlined, color: Colors.white54),
                                                          )
                                                        : Image.file(
                                                            File(url),
                                                            width: 88,
                                                            height: 88,
                                                            fit: BoxFit.cover,
                                                            errorBuilder: (_, __, ___) => const Icon(Icons.broken_image_outlined, color: Colors.white54),
                                                          ),
                                                  ),
                                                ),
                                              );
                                            },
                                          ),
                                        ),
                                      ],
                                    ],
                                  ),
                                );
                              }).toList(),
                            ),
                    ),
                    const SizedBox(height: 24),
                  ],

                  // COD Order Indicator
                  if (activeOrder.paymentMethod == PaymentMethod.cashOnDelivery)
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: activeOrder.paymentStatus == PaymentStatus.paid
                            ? AppColors.success.withValues(alpha: 0.1)
                            : AppColors.warning.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: activeOrder.paymentStatus == PaymentStatus.paid
                              ? AppColors.success.withValues(alpha: 0.3)
                              : AppColors.warning.withValues(alpha: 0.3),
                        ),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Icon(
                                activeOrder.paymentStatus == PaymentStatus.paid
                                    ? Icons.check_circle_rounded
                                    : Icons.local_shipping_rounded,
                                color: activeOrder.paymentStatus == PaymentStatus.paid
                                    ? AppColors.success
                                    : AppColors.warning,
                                size: 24,
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Text(
                                  activeOrder.paymentStatus == PaymentStatus.paid
                                      ? 'COD Payment Received'
                                      : 'Cash on Delivery Order',
                                  style: AppTextStyles.h3(
                                    activeOrder.paymentStatus == PaymentStatus.paid
                                        ? AppColors.success
                                        : AppColors.warning,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Text(
                            activeOrder.paymentStatus == PaymentStatus.paid
                                ? 'Cash has been collected from customer'
                                : 'Collect cash Rs. ${activeOrder.totalPrice.toStringAsFixed(2)} upon delivery',
                            style: AppTextStyles.bodyMedium(
                              activeOrder.paymentStatus == PaymentStatus.paid
                                  ? AppColors.success
                                  : secondaryText,
                            ),
                          ),
                        ],
                      ),
                    ),
                  if (activeOrder.paymentMethod == PaymentMethod.cashOnDelivery)
                    const SizedBox(height: 24),

                  // â”€â”€ Bank Transfer Payment Panel â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
                  // Shown when customer chose bank transfer. Vendor can view
                  // the uploaded receipt and confirm the payment before
                  // advancing the order through the delivery stages.
                  if (activeOrder.paymentMethod == PaymentMethod.bankTransfer)
                    _BankTransferPanel(
                      order: activeOrder,
                      secondaryText: secondaryText,
                      primaryText: primaryText,
                      cardColor: cardColor,
                      borderColor: borderColor,
                    ),
                  if (activeOrder.paymentMethod == PaymentMethod.bankTransfer)
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
                        if (activeOrder.customerFormattedAddress.isNotEmpty) ...[
                          const SizedBox(height: 16),
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Icon(Icons.map_outlined, color: AppColors.vendorColor, size: 20),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text('Delivery Area', style: AppTextStyles.caption(secondaryText)),
                                    Text(activeOrder.customerFormattedAddress, style: AppTextStyles.bodyMedium(primaryText)),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ],
                        if (VendorDeliveryAccessService.canViewLocationAccuracy(activeOrder) && activeOrder.accuracy != null) ...[
                          const SizedBox(height: 16),
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Icon(Icons.gps_fixed_rounded, color: AppColors.vendorColor, size: 20),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text('GPS Accuracy', style: AppTextStyles.caption(secondaryText)),
                                    Text('Â±${activeOrder.accuracy!.toStringAsFixed(1)}m', style: AppTextStyles.bodyMedium(primaryText)),
                                    if (activeOrder.accuracy! > 150)
                                      Text('Low accuracy - move outdoors for better precision', style: AppTextStyles.caption(Colors.orange)),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ] else if (!VendorDeliveryAccessService.canViewLocationAccuracy(activeOrder))
                          Container(
                            margin: const EdgeInsets.only(top: 16),
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: AppColors.warning.withOpacity(0.08),
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: AppColors.warning.withOpacity(0.2)),
                            ),
                            child: Row(
                              children: [
                                const Icon(Icons.lock_outlined, color: AppColors.warning, size: 16),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    'GPS accuracy hidden until payment confirmed',
                                    style: AppTextStyles.caption(AppColors.warning),
                                  ),
                                ),
                              ],
                            ),
                          ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),

                  Text('Delivery & Export Tools', style: AppTextStyles.h2(primaryText)),
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
                        if (VendorDeliveryAccessService.canViewFullAddress(activeOrder) && activeOrder.customerLatitude != 0.0 && activeOrder.customerLongitude != 0.0)
                          ElevatedButton.icon(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.blue.shade600,
                              foregroundColor: Colors.white,
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                              minimumSize: const Size(double.infinity, 45),
                              elevation: 0,
                            ),
                            icon: const Icon(Icons.navigation_rounded),
                            label: const Text('Open Google Maps Navigation'),
                            onPressed: () => _launchMaps(
                              activeOrder.customerLatitude,
                              activeOrder.customerLongitude,
                              context,
                            ),
                          ),
                        if (!VendorDeliveryAccessService.canViewFullAddress(activeOrder))
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: Colors.orange.withOpacity(0.08),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: Colors.orange.withOpacity(0.2)),
                            ),
                            child: const Row(
                              children: [
                                Icon(Icons.lock_outlined, color: Colors.orange, size: 18),
                                SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    'Waiting for payment confirmation to unlock navigation',
                                    style: TextStyle(fontSize: 12, color: Colors.orange, fontWeight: FontWeight.w500),
                                  ),
                                ),
                              ],
                            ),
                          )
                        else if (activeOrder.customerLatitude == 0.0 || activeOrder.customerLongitude == 0.0)
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: Colors.orange.withOpacity(0.08),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: Colors.orange.withOpacity(0.2)),
                            ),
                            child: const Row(
                              children: [
                                Icon(Icons.info_outline, color: Colors.orange, size: 18),
                                SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    'GPS coordinates not available. Customer entered location manually.',
                                    style: TextStyle(fontSize: 12, color: Colors.orange, fontWeight: FontWeight.w500),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            Expanded(
                              child: OutlinedButton.icon(
                                style: OutlinedButton.styleFrom(
                                  side: BorderSide(color: AppColors.vendorColor),
                                  foregroundColor: AppColors.vendorColor,
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                  minimumSize: const Size(0, 45),
                                ),
                                icon: const Icon(Icons.share_rounded, size: 18),
                                label: const Text('Share Rider Info', style: TextStyle(fontSize: 12)),
                                onPressed: () {
                                  final text = _generateRiderShareText(activeOrder);
                                  Clipboard.setData(ClipboardData(text: text));
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(
                                      content: Text('Rider delivery info copied to Clipboard!'),
                                      behavior: SnackBarBehavior.floating,
                                    ),
                                  );
                                },
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: OutlinedButton.icon(
                                style: OutlinedButton.styleFrom(
                                  side: BorderSide(color: AppColors.vendorColor),
                                  foregroundColor: AppColors.vendorColor,
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                  minimumSize: const Size(0, 45),
                                ),
                                icon: const Icon(Icons.receipt_long_rounded, size: 18),
                                label: const Text('Export Invoice', style: TextStyle(fontSize: 12)),
                                onPressed: () {
                                  final text = _generateInvoiceText(activeOrder);
                                  Clipboard.setData(ClipboardData(text: text));
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(
                                      content: Text('Full structured invoice copied to Clipboard!'),
                                      behavior: SnackBarBehavior.floating,
                                    ),
                                  );
                                },
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),

                  if (!isSummaryOnly) ...[
                    // Packing Checklist
                    Text('Packing Checklist', style: AppTextStyles.h2(primaryText)),
                    const SizedBox(height: 4),
                    Text('Check items off as you prepare and pack them.', style: AppTextStyles.caption(secondaryText)),
                    const SizedBox(height: 12),
                    StatefulBuilder(
                      builder: (context, setStateChecklist) {
                        final packableItems = activeOrder.items.where((item) => item.status != ProposalItemStatus.unavailable).toList();
                        final totalPackable = packableItems.length;
                        final packedCount = packableItems.where((item) => (_packedItems[item.requestItemId] ?? false)).length;

                        final isComplete = totalPackable > 0 && packedCount == totalPackable;
                        if (isComplete) {
                          if (!_packedPulseController.isAnimating) {
                            _packedPulseController.repeat(reverse: true);
                          }
                        } else if (_packedPulseController.isAnimating) {
                          _packedPulseController.stop();
                        }

                        return AnimatedBuilder(
                          animation: _packedPulseController,
                          builder: (context, child) {
                            final pulseValue = _packedPulseController.isAnimating ? _packedPulseController.value : 0.0;
                            final pulseAlpha = 0.28 + (pulseValue * 0.22);
                            final pulseBorderAlpha = 0.44 + (pulseValue * 0.20);
                            final pulseShadowAlpha = 0.38 + (pulseValue * 0.24);
                            final pulseScale = 1.0 + (pulseValue * 0.18);

                            return Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                AnimatedContainer(
                                  duration: const Duration(milliseconds: 260),
                                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 8),
                                  decoration: BoxDecoration(
                                    color: isComplete
                                        ? AppColors.success.withValues(alpha: isDark ? pulseAlpha : pulseAlpha * 0.9)
                                        : Colors.transparent,
                                    borderRadius: BorderRadius.circular(8),
                                    border: isComplete
                                        ? Border.all(color: AppColors.success.withValues(alpha: pulseBorderAlpha), width: 1.4)
                                        : null,
                                    boxShadow: isComplete
                                        ? [
                                            BoxShadow(
                                              color: AppColors.success.withValues(alpha: isDark ? pulseShadowAlpha : pulseShadowAlpha * 0.9),
                                              blurRadius: 34,
                                              spreadRadius: 5,
                                            ),
                                            BoxShadow(
                                              color: AppColors.success.withValues(alpha: isDark ? pulseShadowAlpha * 0.7 : pulseShadowAlpha * 0.55),
                                              blurRadius: 18,
                                              spreadRadius: 2,
                                            ),
                                          ]
                                        : null,
                                  ),
                                  child: Row(
                                    children: [
                                      Text('$packedCount of $totalPackable packed', style: AppTextStyles.caption(primaryText)),
                                      const SizedBox(width: 10),
                                      Expanded(
                                        child: ClipRRect(
                                          borderRadius: BorderRadius.circular(6),
                                          child: LayoutBuilder(
                                            builder: (ctx, constraints) {
                                              final fullWidth = constraints.maxWidth;
                                              final ratio = totalPackable == 0 ? 0.0 : (packedCount / totalPackable);
                                              final filledWidth = fullWidth * ratio;
                                              return Container(
                                                height: 8,
                                                color: borderColor.withOpacity(0.6),
                                                child: Stack(
                                                  children: [
                                                    AnimatedContainer(
                                                      duration: const Duration(milliseconds: 360),
                                                      width: filledWidth,
                                                      height: 8,
                                                      decoration: BoxDecoration(
                                                        color: AppColors.vendorColor,
                                                        borderRadius: BorderRadius.circular(6),
                                                        boxShadow: (totalPackable > 0 && packedCount == totalPackable)
                                                            ? [
                                                                BoxShadow(
                                                                  color: AppColors.success.withValues(alpha: isDark ? 0.72 : 0.46),
                                                                  blurRadius: 36,
                                                                  spreadRadius: 5,
                                                                ),
                                                                BoxShadow(
                                                                  color: AppColors.success.withValues(alpha: isDark ? 0.42 : 0.28),
                                                                  blurRadius: 18,
                                                                  spreadRadius: 2,
                                                                ),
                                                              ]
                                                            : null,
                                                      ),
                                                    ),
                                                  ],
                                                ),
                                              );
                                            },
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
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

                                    final isChecked = _packedItems[item.requestItemId] ?? false;

                                    return Container(
                                      margin: const EdgeInsets.only(bottom: 10),
                                      padding: const EdgeInsets.all(14),
                                      decoration: BoxDecoration(
                                        color: cardColor,
                                        borderRadius: BorderRadius.circular(12),
                                        border: Border.all(
                                          color: isChecked
                                              ? AppColors.vendorColor.withOpacity(0.5)
                                              : borderColor,
                                        ),
                                      ),
                                      child: Row(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Checkbox(
                                            value: isChecked,
                                            activeColor: AppColors.vendorColor,
                                            onChanged: (val) {
                                              setStateChecklist(() {
                                                _savePackedItem(item.requestItemId, val ?? false);
                                              });
                                            },
                                          ),
                                          const SizedBox(width: 8),
                                          Expanded(
                                            child: GestureDetector(
                                              behavior: HitTestBehavior.translucent,
                                              onTap: () {
                                                setStateChecklist(() {
                                                  _savePackedItem(item.requestItemId, !isChecked);
                                                });
                                              },
                                              child: Column(
                                                crossAxisAlignment: CrossAxisAlignment.start,
                                                children: [
                                                  Row(
                                                    children: [
                                                      Expanded(
                                                        child: Column(
                                                          crossAxisAlignment: CrossAxisAlignment.start,
                                                          children: [
                                                            Text(
                                                              itemName,
                                                              style: AppTextStyles.bodyLarge(primaryText).copyWith(
                                                                decoration: isChecked ? TextDecoration.lineThrough : null,
                                                                color: isChecked ? secondaryText : primaryText,
                                                              ),
                                                            ),
                                                            Text('Product ID: ${item.id}', style: AppTextStyles.caption(AppColors.vendorColor).copyWith(fontWeight: FontWeight.w600)),
                                                            Text('Quantity to Pack: ${item.quantity}', style: AppTextStyles.caption(secondaryText)),
                                                          ],
                                                        ),
                                                      ),
                                                      Text('Rs. ${item.totalPrice.toStringAsFixed(2)}', style: AppTextStyles.bodyMedium(primaryText)),
                                                    ],
                                                  ),
                                                  Builder(builder: (ctx) {
                                                    final allUrls = [
                                                      if (item.imageUrl != null && item.imageUrl!.isNotEmpty) item.imageUrl!,
                                                      ...item.vendorImageUrls.where((u) => u.isNotEmpty),
                                                    ];
                                                    if (allUrls.isEmpty) return const SizedBox.shrink();
                                                    return Column(
                                                      crossAxisAlignment: CrossAxisAlignment.start,
                                                      children: [
                                                        const SizedBox(height: 10),
                                                        Text(
                                                          'Product photos (${allUrls.length})',
                                                          style: AppTextStyles.caption(secondaryText),
                                                        ),
                                                        const SizedBox(height: 6),
                                                        SizedBox(
                                                          height: 90,
                                                          child: ListView.builder(
                                                            scrollDirection: Axis.horizontal,
                                                            itemCount: allUrls.length,
                                                            itemBuilder: (_, i) {
                                                              final url = allUrls[i];
                                                              final isNetwork = url.startsWith('http://') || url.startsWith('https://');
                                                              return GestureDetector(
                                                                onTap: () => Navigator.of(ctx).push(MaterialPageRoute(
                                                                  builder: (_) => ImageGalleryViewer(imagePaths: allUrls, initialIndex: i),
                                                                )),
                                                                child: Container(
                                                                  width: 90,
                                                                  height: 90,
                                                                  margin: EdgeInsets.only(right: i < allUrls.length - 1 ? 8 : 0),
                                                                  decoration: BoxDecoration(
                                                                    color: borderColor,
                                                                    borderRadius: BorderRadius.circular(8),
                                                                  ),
                                                                  child: ClipRRect(
                                                                    borderRadius: BorderRadius.circular(8),
                                                                    child: isNetwork
                                                                        ? Image.network(url, width: 90, height: 90, fit: BoxFit.cover,
                                                                            errorBuilder: (_, __, ___) => const Icon(Icons.broken_image_outlined, color: Colors.white54))
                                                                        : Image.file(File(url), width: 90, height: 90, fit: BoxFit.cover,
                                                                            errorBuilder: (_, __, ___) => const Icon(Icons.broken_image_outlined, color: Colors.white54)),
                                                                  ),
                                                                ),
                                                              );
                                                            },
                                                          ),
                                                        ),
                                                      ],
                                                    );
                                                  }),
                                                ],
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                    );
                                  },
                                ),
                              ],
                            );
                          },
                        );
                      },
                    ),
                    const SizedBox(height: 30),
                  ],
                ],
              ),
              ),
            ),
          ),

          // Order status state management actions
          if (activeOrder.status != OrderStatus.delivered && activeOrder.status != OrderStatus.completed && activeOrder.status != OrderStatus.cancelled)
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: cardColor,
                border: Border(top: BorderSide(color: borderColor)),
              ),
              child: SafeArea(
                child: Column(
                  children: [
                    // COD Cash Collection Button
                    if (activeOrder.paymentMethod == PaymentMethod.cashOnDelivery &&
                        activeOrder.paymentStatus != PaymentStatus.paid &&
                        activeOrder.status == OrderStatus.outForDelivery)
                      Column(
                        children: [
                          Container(
                            width: double.infinity,
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: AppColors.warning.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: AppColors.warning.withValues(alpha: 0.3)),
                            ),
                            child: Row(
                              children: [
                                const Icon(Icons.local_shipping_rounded, color: AppColors.warning, size: 20),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Text(
                                    'COD Order - Collect cash on delivery',
                                    style: AppTextStyles.bodyMedium(AppColors.warning).copyWith(
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 12),
                          SizedBox(
                            width: double.infinity,
                            height: 52,
                            child: ElevatedButton.icon(
                              style: ElevatedButton.styleFrom(
                                backgroundColor: AppColors.success,
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                                elevation: 0,
                              ),
                              icon: const Icon(Icons.paid_rounded, color: Colors.white),
                              label: Text(
                                'Mark Cash Collected / Delivered',
                                style: AppTextStyles.button(Colors.white),
                              ),
                              onPressed: () => _handleMarkCashCollected(context, activeOrder),
                            ),
                          ),
                        ],
                      )
                    else
                      SizedBox(
                        width: double.infinity,
                        height: 52,
                        child: Theme3AppButton(
                          label: activeOrder.status == OrderStatus.submitted
                              ? 'Accept Order Request'
                              : activeOrder.status == OrderStatus.accepted
                                  ? 'Start Preparing Order'
                                  : activeOrder.status == OrderStatus.preparing
                                      ? 'Mark Ready For Delivery'
                                      : activeOrder.status == OrderStatus.readyForDelivery
                                          ? 'Mark Out For Delivery'
                                          : 'Mark Order as Delivered',
                          isLoading: _isUpdatingStatus,
                          type: Theme3ButtonType.primary,
                          onPressed: () async {
                      if (_isUpdatingStatus) return;
                      final online = await ConnectivityService.instance.isOnline();
                      if (!online) {
                        if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('No network. Check your connection and try again.')),
                        );
                        return;
                      }
                      
                      setState(() => _isUpdatingStatus = true);
                      
                      try {
                        OrderStatus nextStatus = OrderStatus.accepted;

                      if (activeOrder.status == OrderStatus.submitted) {
                        nextStatus = OrderStatus.accepted;
                      } else if (activeOrder.status == OrderStatus.accepted) {
                        nextStatus = OrderStatus.preparing;
                      } else if (activeOrder.status == OrderStatus.preparing) {
                        nextStatus = OrderStatus.readyForDelivery;
                      } else if (activeOrder.status == OrderStatus.readyForDelivery) {
                        nextStatus = OrderStatus.outForDelivery;
                      } else if (activeOrder.status == OrderStatus.outForDelivery) {
                        nextStatus = OrderStatus.delivered;
                      } else if (activeOrder.status == OrderStatus.delivered) {
                        nextStatus = OrderStatus.completed;
                      }

                      // Enforce: vendor must check ALL packing checklist items before marking as ready for delivery
                      if (nextStatus == OrderStatus.readyForDelivery) {
                        final unchecked = activeOrder.items.where((item) => item.status != ProposalItemStatus.unavailable && (_packedItems[item.requestItemId] ?? false) == false).toList();
                        if (unchecked.isNotEmpty) {
                          if (context.mounted) {
                            await showDialog<void>(
                              context: context,
                              builder: (ctx) => AlertDialog(
                                title: const Text('Complete Packing Checklist'),
                                content: Text('Please check all ${unchecked.length} item(s) in the packing checklist to confirm they are packed before marking the order as ready for delivery.'),
                                actions: [
                                  TextButton(
                                    onPressed: () => Navigator.of(ctx).pop(),
                                    child: const Text('OK'),
                                  ),
                                ],
                              ),
                            );
                          }
                          return;
                        }
                      }

                      await ref.read(orderProvider.notifier).updateOrderStatus(activeOrder.id, nextStatus);

                      // NOTE: Push notification for every status change is handled
                      // server-side by the onOrderStatusChanged Cloud Function.
                      // No local notification trigger needed here - it would duplicate.

                      // Special: for bank transfer, notify customer of delivery + verification
                      if (nextStatus == OrderStatus.delivered &&
                          activeOrder.paymentMethod == PaymentMethod.bankTransfer) {
                        await ref
                            .read(notification_feature.notificationProvider.notifier)
                            .createNotification(
                              type: NotificationType.orderDelivered,
                              title: 'Order Delivered & Bank Transfer Verified âœ…',
                              body: 'Your bank transfer was verified and order ${activeOrder.id} has been delivered.',
                              userId: activeOrder.customerId,
                              relatedId: activeOrder.id,
                            );
                      }

                        await ref.read(orderProvider.notifier).loadVendorOrders();

                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text('Order status updated to ${nextStatus.displayName}!'),
                              backgroundColor: AppColors.success,
                            ),
                          );
                          context.pop();
                        }
                      } finally {
                        if (mounted) setState(() => _isUpdatingStatus = false);
                      }
                    },
                  ),
                ),
              ],
            ),
          ),
        )
        ],
      ),
    );
  }
}

Future<void> _launchMaps(double lat, double lng, BuildContext context) async {
  try {
    await LocationService.openMap(latitude: lat, longitude: lng);
  } on Exception catch (e) {
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Could not open maps: ${e.toString().replaceFirst('Exception: ', '')}'),
          behavior: SnackBarBehavior.floating,
          backgroundColor: Colors.red.shade400,
        ),
      );
    }
  }
}

String _generateInvoiceText(OrderModel order) {
  final buffer = StringBuffer();
  buffer.writeln('========================================');
  buffer.writeln('SPEEDMART LANKA - VENDOR INVOICE');
  buffer.writeln('========================================');
  buffer.writeln('Order ID:       ${order.id}');
  buffer.writeln('Order Date:     ${order.createdAt.toLocal().toString().split('.')[0]}');
  buffer.writeln('Payment Method: ${order.paymentMethod.displayName}');
  buffer.writeln('Payment Status: ${order.paymentStatus.name.toUpperCase()}');
  buffer.writeln('----------------------------------------');
  buffer.writeln('CUSTOMER DETAILS:');
  buffer.writeln('Name:           ${order.customerName}');
  buffer.writeln('Phone:          ${order.customerPhone}');
  buffer.writeln('Address:        ${order.deliveryAddress}');
  buffer.writeln('----------------------------------------');
  buffer.writeln('ITEMS:');
  for (final item in order.items) {
    if (item.status == ProposalItemStatus.unavailable) continue;
    final name = item.status == ProposalItemStatus.alternative
        ? '${item.alternativeName} (Alternative)'
        : item.requestItemName;
    buffer.writeln('- $name x ${item.quantity}: Rs. ${item.totalPrice.toStringAsFixed(2)}');
  }
  buffer.writeln('----------------------------------------');
  buffer.writeln('Delivery Charge: Rs. ${order.deliveryCharge.toStringAsFixed(2)}');
  buffer.writeln('TOTAL REVENUE:   Rs. ${order.totalPrice.toStringAsFixed(2)}');
  buffer.writeln('========================================');
  return buffer.toString();
}

String _generateRiderShareText(OrderModel order) {
  return '''
ðŸ›µ SPEEDMART LANKA DELIVERY RIDER INFO ðŸ›µ
Order ID: ${order.id}
Customer Name: ${order.customerName}
Phone: ${order.customerPhone}
Address: ${order.deliveryAddress}
Navigate: https://www.google.com/maps/search/?api=1&query=${order.customerLatitude},${order.customerLongitude}
''';
}

// ── Bank Transfer Payment Panel ──────────────────────────────────────────────
/// Shown on the vendor order details screen when the payment method is bank
/// transfer. Displays the receipt image the customer uploaded, the current
/// payment status, and a confirmation button the vendor uses once they have
/// verified the transfer in their banking app.
class _BankTransferPanel extends ConsumerStatefulWidget {
  const _BankTransferPanel({
    required this.order,
    required this.secondaryText,
    required this.primaryText,
    required this.cardColor,
    required this.borderColor,
  });

  final OrderModel order;
  final Color secondaryText;
  final Color primaryText;
  final Color cardColor;
  final Color borderColor;

  @override
  ConsumerState<_BankTransferPanel> createState() => _BankTransferPanelState();
}

class _BankTransferPanelState extends ConsumerState<_BankTransferPanel> {
  bool _confirming = false;

  bool get _alreadyPaid =>
      widget.order.paymentStatus == PaymentStatus.paid;

  Future<void> _confirmPayment() async {
    if (_confirming || _alreadyPaid) return;
    final online = await ConnectivityService.instance.isOnline();
    if (!online) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content: Text('No network. Check your connection and try again.')),
        );
      }
      return;
    }

    // Capture context before async gap to satisfy use_build_context_synchronously
    if (!mounted) return;
    final ctx0 = context;
    final confirmed = await showDialog<bool>(
      context: ctx0,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Confirm Bank Transfer?'),
        content: const Text(
            'This will mark the payment as received and notify the customer.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: TextButton.styleFrom(foregroundColor: AppColors.success),
            child: const Text('Yes, Confirm'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    setState(() => _confirming = true);
    try {
      final paymentId = widget.order.paymentId;
      if (paymentId == null || paymentId.isEmpty) {
        throw StateError('This order has no linked payment record.');
      }
      await OrderWorkflowService.instance.confirmBankTransferPayment(paymentId);

      // Notify customer their payment has been verified
      await ref
          .read(notification_feature.notificationProvider.notifier)
          .createNotification(
            type: NotificationType.bankTransferReceiptSubmitted,
            title: 'Bank Transfer Verified ✅',
            body:
                'Your bank transfer for order ${widget.order.id} has been verified. The vendor will now start preparing your order.',
            userId: widget.order.customerId,
            relatedId: widget.order.id,
          );

      // Reload vendor orders so the UI refreshes
      await ref.read(orderProvider.notifier).loadVendorOrders();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Payment confirmed! Customer has been notified.'),
            backgroundColor: AppColors.success,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: ${e.toString().replaceAll('Exception: ', '')}'),
            backgroundColor: Colors.red,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _confirming = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    // Re-read order from provider so status updates live
    final liveOrder = ref.watch(orderProvider).orders.firstWhere(
          (o) => o.id == widget.order.id,
          orElse: () => widget.order,
        );
    final paid = liveOrder.paymentStatus == PaymentStatus.paid;
    final pendingBank =
        liveOrder.paymentStatus == PaymentStatus.pendingBankTransfer;

    final panelColor = paid
        ? AppColors.success
        : pendingBank
            ? AppColors.customerColor
            : AppColors.warning;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: panelColor.withValues(alpha: 0.07),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: panelColor.withValues(alpha: 0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Header ──
          Row(
            children: [
              Icon(
                paid
                    ? Icons.check_circle_rounded
                    : pendingBank
                        ? Icons.hourglass_top_rounded
                        : Icons.account_balance_rounded,
                color: panelColor,
                size: 24,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      paid
                          ? 'Bank Transfer Verified'
                          : pendingBank
                              ? 'Receipt Submitted — Awaiting Verification'
                              : 'Bank Transfer — Awaiting Receipt',
                      style: AppTextStyles.h3(panelColor),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      paid
                          ? 'Payment confirmed. Proceed with delivery.'
                          : pendingBank
                              ? 'Customer uploaded a receipt. Please verify below.'
                              : 'Customer has not yet submitted the transfer receipt.',
                      style: AppTextStyles.caption(widget.secondaryText),
                    ),
                  ],
                ),
              ),
            ],
          ),

          // ── Receipt image (if available) ──
          FutureBuilder<PaymentModel?>(
            future: PaymentRepository.instance
                .getPaymentByOrderId(widget.order.id),
            builder: (context, snap) {
              final receiptUrl = snap.data?.receiptImageUrl;
              if (receiptUrl == null || receiptUrl.isEmpty) {
                return const SizedBox.shrink();
              }
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: 14),
                  Text('Customer Receipt',
                      style: AppTextStyles.caption(widget.secondaryText)),
                  const SizedBox(height: 8),
                  GestureDetector(
                    onTap: () => Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => Scaffold(
                          backgroundColor: Colors.black,
                          appBar: AppBar(
                            backgroundColor: Colors.black,
                            iconTheme:
                                const IconThemeData(color: Colors.white),
                            title: const Text('Payment Receipt',
                                style: TextStyle(color: Colors.white)),
                          ),
                          body: InteractiveViewer(
                            child: Center(
                              child: Image.network(
                                receiptUrl,
                                fit: BoxFit.contain,
                                errorBuilder: (_, __, ___) => const Center(
                                  child: Text('Could not load image',
                                      style:
                                          TextStyle(color: Colors.white70)),
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(12),
                      child: Image.network(
                        receiptUrl,
                        height: 180,
                        width: double.infinity,
                        fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) => Container(
                          height: 80,
                          decoration: BoxDecoration(
                            color: widget.borderColor,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: const Center(
                            child: Icon(Icons.broken_image_outlined,
                                color: Colors.white54, size: 36),
                          ),
                        ),
                        loadingBuilder: (_, child, progress) {
                          if (progress == null) return child;
                          return Container(
                            height: 80,
                            decoration: BoxDecoration(
                              color: widget.borderColor,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: const Center(
                                child: CircularProgressIndicator()),
                          );
                        },
                      ),
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text('Tap image to view full screen',
                      style: AppTextStyles.caption(widget.secondaryText)),
                ],
              );
            },
          ),

          // ── Confirm button (only if not yet paid) ──
          if (!paid) ...[
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              height: 48,
              child: ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.success,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14)),
                  elevation: 0,
                ),
                onPressed: _confirming ? null : _confirmPayment,
                icon: _confirming
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                            strokeWidth: 2, color: Colors.white),
                      )
                    : const Icon(Icons.verified_rounded,
                        color: Colors.white, size: 18),
                label: Text(
                  _confirming ? 'Confirming…' : 'Confirm Payment Received',
                  style: AppTextStyles.button(Colors.white),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
