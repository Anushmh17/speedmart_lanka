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

class _VendorOrdersScreenState extends ConsumerState<VendorOrdersScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';

  static const _groupOrder = [
    'Today', 'Yesterday', 'This Week', 'Last Week', 'This Month', 'Last Month', 'Older'
  ];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this, initialIndex: widget.initialTabIndex);
    Future.microtask(() => ref.read(orderProvider.notifier).loadVendorOrders());
    _searchController.addListener(() {
      setState(() => _searchQuery = _searchController.text.trim().toLowerCase());
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  List<OrderModel> _filterByProductId(List<OrderModel> orders) {
    if (_searchQuery.isEmpty) return orders;
    return orders.where((o) => o.items.any((item) =>
        item.id.toLowerCase().contains(_searchQuery) ||
        item.requestItemId.toLowerCase().contains(_searchQuery))).toList();
  }

  String _dateGroup(DateTime date) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final d = DateTime(date.year, date.month, date.day);
    final diff = today.difference(d).inDays;
    if (diff == 0) return 'Today';
    if (diff == 1) return 'Yesterday';
    final startOfWeek = today.subtract(Duration(days: today.weekday - 1));
    if (!d.isBefore(startOfWeek)) return 'This Week';
    final startOfLastWeek = startOfWeek.subtract(const Duration(days: 7));
    if (!d.isBefore(startOfLastWeek)) return 'Last Week';
    if (d.year == now.year && d.month == now.month) return 'This Month';
    final lastMonthDate = DateTime(now.year, now.month - 1);
    if (d.year == lastMonthDate.year && d.month == lastMonthDate.month) return 'Last Month';
    return 'Older';
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primaryText = isDark ? AppColors.textPrimaryDark : AppColors.textPrimaryLight;
    final secondaryText = isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight;
    final bg = isDark ? AppColors.backgroundDark : AppColors.backgroundLight;

    final orderState = ref.watch(orderProvider);
    final allOrders = orderState.orders;

    final activeOrders = _filterByProductId(allOrders
        .where((o) => o.status != OrderStatus.delivered &&
            o.status != OrderStatus.completed &&
            o.status != OrderStatus.cancelled)
        .toList());

    final completedOrders = _filterByProductId(allOrders
        .where((o) =>
            o.status == OrderStatus.delivered ||
            o.status == OrderStatus.completed ||
            o.status == OrderStatus.cancelled)
        .toList());

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
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(96),
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(12, 0, 12, 8),
                child: TextField(
                  controller: _searchController,
                  style: AppTextStyles.bodyMedium(primaryText),
                  decoration: InputDecoration(
                    hintText: 'Search by product ID…',
                    hintStyle: AppTextStyles.caption(secondaryText),
                    prefixIcon: Icon(Icons.search_rounded, color: secondaryText, size: 20),
                    suffixIcon: _searchQuery.isNotEmpty
                        ? IconButton(
                            icon: Icon(Icons.clear_rounded, color: secondaryText, size: 18),
                            onPressed: () => _searchController.clear(),
                          )
                        : null,
                    isDense: true,
                    contentPadding: const EdgeInsets.symmetric(vertical: 10),
                    filled: true,
                    fillColor: isDark ? AppColors.surfaceElevatedDark : AppColors.surfaceLight,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: BorderSide.none,
                    ),
                  ),
                ),
              ),
              TabBar(
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
            ],
          ),
        ),
      ),
      body: orderState.isLoading
          ? const Center(child: CircularProgressIndicator(color: AppColors.vendorColor))
          : TabBarView(
              controller: _tabController,
              children: [
                _buildActiveList(activeOrders, isDark, primaryText, secondaryText),
                _buildGroupedCompletedList(completedOrders, isDark, primaryText, secondaryText),
              ],
            ),
    );
  }

  Widget _buildActiveList(List<OrderModel> orders, bool isDark, Color primaryText, Color secondaryText) {
    if (orders.isEmpty) {
      return Theme3EmptyState(
        icon: Icons.receipt_long_rounded,
        title: _searchQuery.isNotEmpty ? 'No orders match that product ID' : 'No active orders',
        subtitle: _searchQuery.isNotEmpty
            ? 'Try a different product ID.'
            : 'When customers accept your proposals, orders will appear here.',
      );
    }
    return RefreshIndicator(
      color: AppColors.vendorColor,
      onRefresh: () async => ref.read(orderProvider.notifier).loadVendorOrders(),
      child: ListView.builder(
        padding: const EdgeInsets.all(AppSpacing.md),
        itemCount: orders.length,
        itemBuilder: (context, index) =>
            _buildOrderCard(orders[index], isDark, primaryText, secondaryText),
      ),
    );
  }

  Widget _buildGroupedCompletedList(List<OrderModel> orders, bool isDark, Color primaryText, Color secondaryText) {
    if (orders.isEmpty) {
      return Theme3EmptyState(
        icon: Icons.receipt_long_rounded,
        title: _searchQuery.isNotEmpty ? 'No orders match that product ID' : 'No completed orders',
        subtitle: _searchQuery.isNotEmpty
            ? 'Try a different product ID.'
            : 'Your past and completed orders will be shown here.',
      );
    }

    final Map<String, List<OrderModel>> grouped = {};
    for (final o in orders) {
      grouped.putIfAbsent(_dateGroup(o.createdAt), () => []).add(o);
    }
    final groupKeys = _groupOrder.where(grouped.containsKey).toList();

    final items = <dynamic>[];
    for (final key in groupKeys) {
      items.add(key);
      items.addAll(grouped[key]!);
    }

    return RefreshIndicator(
      color: AppColors.vendorColor,
      onRefresh: () async => ref.read(orderProvider.notifier).loadVendorOrders(),
      child: ListView.builder(
        padding: const EdgeInsets.all(AppSpacing.md),
        itemCount: items.length,
        itemBuilder: (context, index) {
          final item = items[index];
          if (item is String) {
            return Padding(
              padding: const EdgeInsets.only(top: AppSpacing.sm, bottom: 6),
              child: Text(
                item,
                style: AppTextStyles.labelMedium(AppColors.vendorColor)
                    .copyWith(fontWeight: FontWeight.w800, letterSpacing: 0.4),
              ),
            );
          }
          return _buildOrderCard(item as OrderModel, isDark, primaryText, secondaryText);
        },
      ),
    );
  }

  Widget _buildOrderCard(OrderModel order, bool isDark, Color primaryText, Color secondaryText) {
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
              Builder(builder: (context) {
                String? displayImageUrl;
                if (order.items.isNotEmpty) {
                  final firstItem = order.items.first;
                  displayImageUrl = firstItem.vendorImageUrls.isNotEmpty
                      ? firstItem.vendorImageUrls.first
                      : firstItem.imageUrl;
                }
                final hasImage = displayImageUrl != null && displayImageUrl.isNotEmpty;
                final isNetwork = hasImage &&
                    (displayImageUrl!.startsWith('http://') ||
                        displayImageUrl.startsWith('https://'));

                return Container(
                  width: 52,
                  height: 52,
                  decoration: BoxDecoration(
                    color: isCompleted
                        ? AppColors.success.withValues(alpha: 0.12)
                        : (isCancelled
                            ? AppColors.error.withValues(alpha: 0.12)
                            : AppColors.vendorColor.withValues(alpha: 0.12)),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: hasImage
                      ? ClipRRect(
                          borderRadius: BorderRadius.circular(14),
                          child: isNetwork
                              ? Image.network(displayImageUrl!, width: 52, height: 52, fit: BoxFit.cover,
                                  errorBuilder: (_, __, ___) => Icon(
                                      isCompleted ? Icons.check_circle_rounded : (isCancelled ? Icons.cancel_rounded : Icons.local_shipping_rounded),
                                      color: isCompleted ? AppColors.success : (isCancelled ? AppColors.error : AppColors.vendorColor),
                                      size: 24))
                              : Image.file(File(displayImageUrl!), width: 52, height: 52, fit: BoxFit.cover,
                                  errorBuilder: (_, __, ___) => Icon(
                                      isCompleted ? Icons.check_circle_rounded : (isCancelled ? Icons.cancel_rounded : Icons.local_shipping_rounded),
                                      color: isCompleted ? AppColors.success : (isCancelled ? AppColors.error : AppColors.vendorColor),
                                      size: 24)),
                        )
                      : Icon(
                          isCompleted ? Icons.check_circle_rounded : (isCancelled ? Icons.cancel_rounded : Icons.local_shipping_rounded),
                          color: isCompleted ? AppColors.success : (isCancelled ? AppColors.error : AppColors.vendorColor),
                          size: 24,
                        ),
                );
              }),
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
          // Product IDs
          if (order.items.isNotEmpty)
            Wrap(
              spacing: 6,
              runSpacing: 4,
              children: order.items.map((item) => Container(
                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                decoration: BoxDecoration(
                  color: AppColors.vendorColor.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(color: AppColors.vendorColor.withValues(alpha: 0.2)),
                ),
                child: Text(
                  'ID: ${item.id}',
                  style: AppTextStyles.labelSmall(AppColors.vendorColor),
                ),
              )).toList(),
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
                    style: AppTextStyles.subtitle(primaryText)
                        .copyWith(color: AppColors.vendorColor, fontWeight: FontWeight.w800),
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
                child: Text(
                  isCompleted || isCancelled ? 'View Summary' : 'Manage',
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
              ),
            ],
          ),
        ],
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
