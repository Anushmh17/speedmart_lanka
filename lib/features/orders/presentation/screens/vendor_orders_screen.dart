import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:speedmart_lanka/core/theme/app_colors.dart';
import 'package:speedmart_lanka/core/theme/app_spacing.dart';
import 'package:speedmart_lanka/core/theme/app_radius.dart';
import 'package:speedmart_lanka/core/theme/app_text_styles.dart';
import 'package:speedmart_lanka/core/widgets/theme3/theme3_app_card.dart';
import 'package:speedmart_lanka/core/widgets/theme3/theme3_empty_state.dart';
import 'package:speedmart_lanka/features/orders/models/order_model.dart';
import 'package:speedmart_lanka/features/orders/providers/order_provider.dart';
import 'package:speedmart_lanka/features/auth/providers/theme_provider.dart';
import 'package:speedmart_lanka/core/widgets/app_state_widgets.dart';

class VendorOrdersScreen extends ConsumerStatefulWidget {
  const VendorOrdersScreen({super.key, this.initialTabIndex = 0});
  final int initialTabIndex;

  @override
  ConsumerState<VendorOrdersScreen> createState() => _VendorOrdersScreenState();
}

class _VendorOrdersScreenState extends ConsumerState<VendorOrdersScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this, initialIndex: widget.initialTabIndex);
    Future.microtask(() {
      ref.read(orderProvider.notifier).loadVendorOrders();
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primaryText = isDark ? AppColors.textPrimaryDark : AppColors.textPrimaryLight;
    final secondaryText = isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight;
    final bg = isDark ? AppColors.backgroundDark : AppColors.backgroundLight;

    final orderState = ref.watch(orderProvider);
    final allOrders = orderState.orders;

    // Active orders: Anything that is not delivered, completed, or cancelled
    final activeOrders = allOrders
        .where((o) => o.status != OrderStatus.delivered && o.status != OrderStatus.completed && o.status != OrderStatus.cancelled)
        .toList();

    // Completed orders: successfully delivered/completed or cancelled
    final completedOrders = allOrders
        .where((o) => o.status == OrderStatus.delivered || o.status == OrderStatus.completed || o.status == OrderStatus.cancelled)
        .toList();

    return Scaffold(
      backgroundColor: bg,
      appBar: AppBar(
        backgroundColor: bg,
        elevation: 0,
        surfaceTintColor: Colors.transparent,
        leading: IconButton(
          icon: Icon(Icons.arrow_back_rounded, color: primaryText),
          onPressed: () => context.pop(),
        ),
        title: Text(
          'Manage Orders',
          style: AppTextStyles.h2(primaryText).copyWith(fontWeight: FontWeight.w700),
        ),
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: AppColors.vendorColor,
          indicatorWeight: 3,
          labelColor: AppColors.vendorColor,
          unselectedLabelColor: secondaryText,
          labelStyle: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15),
          tabs: [
            Tab(text: 'Active (${activeOrders.length})'),
            Tab(text: 'Completed (${completedOrders.length})'),
          ],
        ),
      ),
      body: orderState.isLoading
          ? const Center(child: CircularProgressIndicator(color: AppColors.vendorColor))
          : TabBarView(
              controller: _tabController,
              children: [
                _buildOrderList(activeOrders, isDark, primaryText, secondaryText, true),
                _buildOrderList(completedOrders, isDark, primaryText, secondaryText, false),
              ],
            ),
    );
  }

  Widget _buildOrderList(List<OrderModel> orders, bool isDark, Color primaryText, Color secondaryText, bool isActiveList) {
    if (orders.isEmpty) {
      return Theme3EmptyState(
        icon: Icons.receipt_long_rounded,
        title: isActiveList ? 'No active orders' : 'No completed orders',
        subtitle: isActiveList 
            ? 'When customers accept your proposals, orders will appear here.'
            : 'Your past and completed orders will be shown here.',
      );
    }

    return RefreshIndicator(
      color: AppColors.vendorColor,
      onRefresh: () async {
        await ref.read(orderProvider.notifier).loadVendorOrders();
      },
      child: ListView.builder(
        padding: const EdgeInsets.all(AppSpacing.md),
        itemCount: orders.length,
        itemBuilder: (context, index) {
          final order = orders[index];
          final isCompleted = order.status == OrderStatus.delivered || order.status == OrderStatus.completed;
          final isCancelled = order.status == OrderStatus.cancelled;

          return Theme3AppCard(
            margin: const EdgeInsets.only(bottom: AppSpacing.md),
            onTap: () => context.push('/vendor/orders/manage', extra: order),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'ID: ${order.id}',
                      style: AppTextStyles.labelMedium(primaryText).copyWith(fontWeight: FontWeight.w700),
                    ),
                    _buildStatusChip(order.status),
                  ],
                ),
                const SizedBox(height: AppSpacing.md),
                
                // Content
                Row(
                  children: [
                    Builder(
                      builder: (context) {
                        String? displayImageUrl;
                        if (order.items.isNotEmpty) {
                          final firstItem = order.items.first;
                          displayImageUrl = firstItem.vendorImageUrls.isNotEmpty 
                              ? firstItem.vendorImageUrls.first 
                              : firstItem.imageUrl;
                        }
                        final hasImage = displayImageUrl != null && displayImageUrl.isNotEmpty;
                        final isNetwork = hasImage && (displayImageUrl!.startsWith('http://') || displayImageUrl.startsWith('https://'));
                        
                        return Container(
                          width: 52,
                          height: 52,
                          decoration: BoxDecoration(
                            color: isCompleted 
                                ? AppColors.success.withValues(alpha: 0.12)
                                : (isCancelled ? AppColors.error.withValues(alpha: 0.12) : AppColors.vendorColor.withValues(alpha: 0.12)),
                            borderRadius: BorderRadius.circular(14),
                          ),
                          child: hasImage
                              ? ClipRRect(
                                  borderRadius: BorderRadius.circular(14),
                                  child: isNetwork
                                      ? Image.network(displayImageUrl!, width: 52, height: 52, fit: BoxFit.cover,
                                          errorBuilder: (_, __, ___) => Icon(isCompleted ? Icons.check_circle_rounded : (isCancelled ? Icons.cancel_rounded : Icons.local_shipping_rounded),
                                              color: isCompleted ? AppColors.success : (isCancelled ? AppColors.error : AppColors.vendorColor), size: 24))
                                      : Image.file(File(displayImageUrl!), width: 52, height: 52, fit: BoxFit.cover,
                                          errorBuilder: (_, __, ___) => Icon(isCompleted ? Icons.check_circle_rounded : (isCancelled ? Icons.cancel_rounded : Icons.local_shipping_rounded),
                                              color: isCompleted ? AppColors.success : (isCancelled ? AppColors.error : AppColors.vendorColor), size: 24)),
                                )
                              : Icon(
                                  isCompleted ? Icons.check_circle_rounded : (isCancelled ? Icons.cancel_rounded : Icons.local_shipping_rounded),
                                  color: isCompleted ? AppColors.success : (isCancelled ? AppColors.error : AppColors.vendorColor),
                                  size: 24,
                                ),
                        );
                      }
                    ),
                    const SizedBox(width: AppSpacing.md),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            order.customerName,
                            style: AppTextStyles.subtitle(primaryText),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 4),
                          Row(
                            children: [
                              Icon(Icons.location_on_rounded, size: 14, color: secondaryText),
                              const SizedBox(width: 4),
                              Expanded(
                                child: Text(
                                  order.deliveryAddress,
                                  style: AppTextStyles.caption(secondaryText),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                
                const SizedBox(height: AppSpacing.md),
                const Divider(height: 1),
                const SizedBox(height: AppSpacing.md),
                
                // Footer
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Total Amount', style: AppTextStyles.caption(secondaryText)),
                        const SizedBox(height: 2),
                        Text(
                          'Rs. ${order.totalPrice.toStringAsFixed(2)}',
                          style: AppTextStyles.subtitle(primaryText).copyWith(color: AppColors.vendorColor, fontWeight: FontWeight.w800),
                        ),
                      ],
                    ),
                    ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: isDark ? AppColors.surfaceElevatedDark : AppColors.surfaceLight,
                        foregroundColor: AppColors.vendorColor,
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(AppRadius.md),
                          side: BorderSide(color: AppColors.vendorColor.withValues(alpha: 0.5)),
                        ),
                        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 0),
                        minimumSize: const Size(0, 38),
                      ),
                      onPressed: () => context.push('/vendor/orders/manage', extra: order),
                      child: Text(isCompleted || isCancelled ? 'View Summary' : 'Manage', style: const TextStyle(fontWeight: FontWeight.w700)),
                    ),
                  ],
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildStatusChip(OrderStatus status) {
    Color bgColor;
    Color textColor;
    
    switch (status) {
      case OrderStatus.delivered:
      case OrderStatus.completed:
        bgColor = AppColors.success.withValues(alpha: 0.15);
        textColor = AppColors.success;
        break;
      case OrderStatus.cancelled:
        bgColor = AppColors.error.withValues(alpha: 0.15);
        textColor = AppColors.error;
        break;
      default:
        bgColor = AppColors.warning.withValues(alpha: 0.15);
        textColor = AppColors.warning;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        status.displayName.toUpperCase(),
        style: TextStyle(
          color: textColor,
          fontSize: 10,
          fontWeight: FontWeight.w800,
          letterSpacing: 0.5,
        ),
      ),
    );
  }
}
