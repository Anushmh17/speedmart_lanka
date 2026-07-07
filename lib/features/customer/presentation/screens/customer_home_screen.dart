import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:speedmart_lanka/core/routes/route_names.dart';
import 'package:speedmart_lanka/core/theme/app_colors.dart';
import 'package:speedmart_lanka/core/theme/app_text_styles.dart';
import 'package:speedmart_lanka/core/theme/app_spacing.dart';
import 'package:speedmart_lanka/core/theme/app_radius.dart';
import 'package:speedmart_lanka/core/widgets/app_logo.dart';
import 'package:speedmart_lanka/core/widgets/shared_floating_bottom_nav.dart';
import 'package:speedmart_lanka/core/widgets/theme3/theme3_widgets.dart';
import 'package:speedmart_lanka/core/navigation/bottom_nav_visibility.dart';
import 'package:speedmart_lanka/features/auth/providers/auth_provider.dart';
import 'package:speedmart_lanka/features/auth/providers/theme_provider.dart';
import 'package:speedmart_lanka/features/requests/presentation/screens/request_details_screen.dart';
import 'package:speedmart_lanka/features/requests/providers/request_provider.dart';
import 'package:speedmart_lanka/features/requests/models/shopping_request.dart';
import 'package:speedmart_lanka/features/orders/models/order_model.dart';
import 'package:speedmart_lanka/features/orders/providers/order_provider.dart';
import 'package:speedmart_lanka/shared/models/user_role.dart';

class CustomerHomeScreen extends ConsumerStatefulWidget {
  final Widget child;
  const CustomerHomeScreen({super.key, required this.child});

  @override
  ConsumerState<CustomerHomeScreen> createState() => _CustomerHomeScreenState();
}

class _CustomerHomeScreenState extends ConsumerState<CustomerHomeScreen>
    with WidgetsBindingObserver {
  DateTime? _lastBackPressTime;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    Future.microtask(() {
      final user = ref.read(currentUserProvider);
      if (user?.role != UserRole.customer) {
        debugPrint('[CustomerHome] Skipping customer data load for non-customer user');
        return;
      }
      ref.read(requestProvider.notifier).loadMyRequests();
      ref.read(orderProvider.notifier).loadCustomerOrders();
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  Future<bool> didPopRoute() async {
    if (!mounted) return false;

    final String location;
    try {
      location = GoRouter.of(context)
          .routeInformationProvider
          .value
          .uri
          .path;
    } catch (_) {
      return false;
    }

    const customerTabs = {
      '/customer',
      '/customer/requests',
      '/customer/orders',
      '/customer/profile',
    };
    if (!customerTabs.contains(location)) return false;

    if (location != RouteNames.customerHome) {
      context.go(RouteNames.customerHome);
      return true;
    }

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogCtx) => AlertDialog(
        title: const Text('Exit Speedmart Lanka?'),
        content: const Text('Do you want to exit the app?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogCtx, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(dialogCtx, true),
            style: TextButton.styleFrom(foregroundColor: AppColors.error),
            child: const Text('Exit'),
          ),
        ],
      ),
    );

    return confirmed != true;
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final shellLocation = GoRouterState.of(context).matchedLocation;
    
    // Update bottom nav visibility with current location after build completes
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(bottomNavVisibilityProvider.notifier).updateLocation(shellLocation);
    });
    
    final showBottomNav = ref.watch(bottomNavVisibilityProvider);

    int currentIndex = 0;
    if (shellLocation == RouteNames.customerRequests) {
      currentIndex = 1;
    } else if (shellLocation == RouteNames.customerOrders) {
      currentIndex = 2;
    } else if (shellLocation == RouteNames.customerProfile) {
      currentIndex = 3;
    }

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        // didPopRoute() already handled this event.
      },
      child: Scaffold(
        backgroundColor: isDark ? AppColors.backgroundDark : AppColors.backgroundLight,
        appBar: AppBar(
          title: const AppBarLogo(),
          backgroundColor: isDark ? AppColors.surfaceDark : AppColors.surfaceLight,
          elevation: 0,
          actions: [
            IconButton(
              icon: Icon(
                isDark ? Icons.light_mode_outlined : Icons.dark_mode_outlined,
                color: isDark ? AppColors.textPrimaryDark : AppColors.textPrimaryLight,
              ),
              onPressed: () => ref.read(themeProvider.notifier).toggleTheme(),
            ),
            IconButton(
              icon: Badge(
                smallSize: 8,
                child: Icon(
                  Icons.notifications_outlined,
                  color: isDark ? AppColors.textPrimaryDark : AppColors.textPrimaryLight,
                ),
              ),
              onPressed: () {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Notifications are configured and ready.'),
                    behavior: SnackBarBehavior.floating,
                  ),
                );
              },
            ),
            const SizedBox(width: 8),
          ],
        ),
        body: widget.child,
        bottomNavigationBar: AnimatedBottomNavWrapper(
          visible: showBottomNav,
          child: SharedFloatingBottomNav(
            currentIndex: currentIndex,
            onTap: (index) {
              switch (index) {
                case 0:
                  context.go(RouteNames.customerHome);
                  break;
                case 1:
                  context.go(RouteNames.customerRequests);
                  break;
                case 2:
                  context.go(RouteNames.customerOrders);
                  break;
                case 3:
                  context.go(RouteNames.customerProfile);
                  break;
              }
            },
            activeColor: AppColors.primary,
            items: const [
              SharedFloatingBottomNavItem(
                unselectedIcon: Icons.grid_view_rounded,
                selectedIcon: Icons.grid_view_rounded,
                label: 'Home',
              ),
              SharedFloatingBottomNavItem(
                unselectedIcon: Icons.list_alt_rounded,
                selectedIcon: Icons.list_alt_rounded,
                label: 'Lists',
              ),
              SharedFloatingBottomNavItem(
                unselectedIcon: Icons.shopping_bag_outlined,
                selectedIcon: Icons.shopping_bag_rounded,
                label: 'Orders',
              ),
              SharedFloatingBottomNavItem(
                unselectedIcon: Icons.person_outline_rounded,
                selectedIcon: Icons.person_rounded,
                label: 'Profile',
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Home Tab ──────────────────────────────────────────────────────────────
class CustomerHomeTab extends ConsumerWidget {
  const CustomerHomeTab({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(currentUserProvider);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primaryText = isDark ? AppColors.textPrimaryDark : AppColors.textPrimaryLight;
    final secondaryText = isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight;
    
    final requestState = ref.watch(requestProvider);
    final orderState = ref.watch(orderProvider);



    return SingleChildScrollView(
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(AppSpacing.lg, AppSpacing.lg, AppSpacing.lg, 100),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Premium Header ────────────────────────────────────────────
          _buildHeader(user, isDark, primaryText, secondaryText),
          const SizedBox(height: AppSpacing.xl),

          // ── Search Bar ────────────────────────────────────────────────
          _buildSearchBar(context, isDark),
          const SizedBox(height: AppSpacing.xl),

          // ── Premium Hero Action Card ──────────────────────────────────
          _buildHeroActionCard(context, isDark),
          const SizedBox(height: AppSpacing.lg),

          // ── Vendor Activity Banner ────────────────────────────────────
          _buildVendorActivityBanner(isDark, primaryText, secondaryText),
          const SizedBox(height: AppSpacing.xxxl),

          // ── Quick Actions Row (Compact) ───────────────────────────────
          _buildQuickActionsRow(context, isDark, primaryText, secondaryText),
          const SizedBox(height: AppSpacing.xxxl),

          // ── International Mode Warning ────────────────────────────────
          if (user?.countryOverride == true) ...[
            Theme3AppCard(
              type: Theme3CardType.highlighted,
              padding: const EdgeInsets.all(AppSpacing.md),
              child: Row(
                children: [
                  Icon(
                    Icons.warning_amber_rounded,
                    color: AppColors.warning,
                    size: 20,
                  ),
                  const SizedBox(width: AppSpacing.md),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'International Mode',
                          style: AppTextStyles.labelMedium(AppColors.warning),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          'Phone verification required for some features.',
                          style: AppTextStyles.caption(secondaryText),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: AppSpacing.xl)
          ],

          // ── Recent Requests Section ───────────────────────────────────
          _buildRecentRequestsSection(context, ref, requestState, isDark, primaryText, secondaryText),
          const SizedBox(height: AppSpacing.xxxl),

          // ── Recent Orders Section ─────────────────────────────────────
          _buildRecentOrdersSection(context, ref, orderState, isDark, primaryText, secondaryText),
          const SizedBox(height: AppSpacing.xl),
        ],
      ),
    );
  }

  Widget _buildHeader(dynamic user, bool isDark, Color primaryText, Color secondaryText) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Hello, ${user?.firstName ?? 'Customer'} 👋',
              style: AppTextStyles.h2(primaryText),
            ),
            const SizedBox(height: 4),
            Text(
              _formatDate(DateTime.now()),
              style: AppTextStyles.bodySmall(secondaryText),
            ),
          ],
        ),
        CircleAvatar(
          radius: 24,
          backgroundColor: (isDark ? AppColors.primaryDark : AppColors.primary).withValues(alpha: 0.15),
          child: Text(
            user?.initials ?? 'C',
            style: AppTextStyles.h3(isDark ? AppColors.primaryDark : AppColors.primary),
          ),
        ),
      ],
    );
  }

  Widget _buildSearchBar(BuildContext context, bool isDark) {
    return Container(
      decoration: BoxDecoration(
        color: isDark ? AppColors.surfaceElevatedDark : AppColors.surfaceLight,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isDark ? AppColors.borderDark : AppColors.borderLight,
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: (isDark ? AppColors.primaryDark : AppColors.primary).withValues(alpha: 0.1),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: TextField(
        readOnly: true,
        onTap: () => ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Search feature coming soon'),
            behavior: SnackBarBehavior.floating,
          ),
        ),
        decoration: InputDecoration(
          hintText: 'Search for products or services...',
          hintStyle: AppTextStyles.bodyMedium(
            isDark ? AppColors.textHintDark : AppColors.textHintLight,
          ),
          prefixIcon: Icon(
            Icons.search_rounded,
            color: isDark ? AppColors.primaryDark : AppColors.primary,
            size: 20,
          ),
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(vertical: 14),
        ),
      ),
    );
  }

  Widget _buildHeroActionCard(BuildContext context, bool isDark) {
    return Theme3AppCard(
      type: Theme3CardType.highlighted,
      padding: const EdgeInsets.all(AppSpacing.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Post what you need',
            style: AppTextStyles.h2(isDark ? AppColors.textPrimaryDark : AppColors.textPrimaryLight),
          ),
          const SizedBox(height: 4),
          Text(
            'Get proposals from verified vendors',
            style: AppTextStyles.bodySmall(
              isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight,
            ),
          ),
          const SizedBox(height: AppSpacing.lg),
          Theme3AppButton(
            label: 'Create Request',
            onPressed: () => context.push(RouteNames.customerCreateRequest),
            icon: Icons.add_rounded,
            width: double.infinity,
          ),
        ],
      ),
    );
  }

  Widget _buildVendorActivityBanner(bool isDark, Color primaryText, Color secondaryText) {
    return Theme3AppCard(
      type: Theme3CardType.standard,
      padding: const EdgeInsets.all(AppSpacing.lg),
      child: Row(
        children: [
          Stack(
            children: [
              CircleAvatar(
                radius: 20,
                backgroundColor: AppColors.success.withValues(alpha: 0.2),
                child: Icon(Icons.storefront_rounded, size: 18, color: AppColors.success),
              ),
              Positioned(
                left: 24,
                child: CircleAvatar(
                  radius: 20,
                  backgroundColor: AppColors.info.withValues(alpha: 0.2),
                  child: Icon(Icons.local_shipping_rounded, size: 18, color: AppColors.info),
                ),
              ),
              Positioned(
                left: 48,
                child: CircleAvatar(
                  radius: 20,
                  backgroundColor: (isDark ? AppColors.primaryDark : AppColors.primary).withValues(alpha: 0.2),
                  child: Icon(Icons.shopping_bag_rounded, size: 18, color: isDark ? AppColors.primaryDark : AppColors.primary),
                ),
              ),
            ],
          ),
          const SizedBox(width: 80),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '200+ Active Vendors Nearby',
                  style: AppTextStyles.labelLarge(primaryText),
                ),
                const SizedBox(height: 2),
                Text(
                  'Ready to fulfill your requests',
                  style: AppTextStyles.caption(secondaryText),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildQuickActionsRow(BuildContext context, bool isDark, Color primaryText, Color secondaryText) {
    final actions = [
      ('Categories', Icons.category_outlined, () {}),
      ('Orders', Icons.shopping_bag_outlined, () => context.go(RouteNames.customerOrders)),
      ('Offers', Icons.local_offer_outlined, () => context.go(RouteNames.customerRequests)),
      ('Messages', Icons.mail_outline_rounded, () => ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Messages coming soon'), behavior: SnackBarBehavior.floating),
      )),
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Quick Access', style: AppTextStyles.subtitle(primaryText)),
        const SizedBox(height: AppSpacing.md),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: actions.map((action) {
            return Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4),
                child: Theme3AppCard(
                  onTap: action.$3,
                  padding: const EdgeInsets.all(AppSpacing.md),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        action.$2,
                        size: 24,
                        color: isDark ? AppColors.primaryDark : AppColors.primary,
                      ),
                      const SizedBox(height: 6),
                      Text(
                        action.$1,
                        style: AppTextStyles.labelSmall(primaryText),
                        textAlign: TextAlign.center,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
              ),
            );
          }).toList(),
        ),
      ],
    );
  }

  Widget _buildRecentRequestsSection(BuildContext context, WidgetRef ref, dynamic requestState, bool isDark, Color primaryText, Color secondaryText) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text('Recent Requests', style: AppTextStyles.h2(primaryText)),
            if (requestState.requests.isNotEmpty)
              TextButton(
                onPressed: () => context.go(RouteNames.customerRequests),
                child: Text(
                  'View All →',
                  style: AppTextStyles.labelMedium(isDark ? AppColors.primaryDark : AppColors.primary),
                ),
              ),
          ],
        ),
        const SizedBox(height: AppSpacing.md),
        if (requestState.requests.isEmpty)
          Theme3EmptyState(
            icon: Icons.shopping_basket_rounded,
            title: 'No Requests Yet',
            subtitle: 'Create your first request to get started',
            actionLabel: 'Create Request',
            onActionPressed: () => context.push(RouteNames.customerCreateRequest),
          )
        else
          ListView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: requestState.requests.length > 3 ? 3 : requestState.requests.length,
            itemBuilder: (context, index) {
              final request = requestState.requests[index];
              final statusType = request.status == RequestStatus.submitted
                  ? Theme3StatusType.pending
                  : (request.status == RequestStatus.delivered ? Theme3StatusType.completed : Theme3StatusType.inProgress);
              
              final primaryCategory = request.categories.isNotEmpty ? request.categories.first : '';
              final proposalCount = request.categoryFulfillments.length;
              final requestImagePath = _getRequestThumbnailImage(request);
              
              return Theme3AppCard(
                onTap: () {
                  Navigator.of(context, rootNavigator: true).push(
                    MaterialPageRoute(
                      builder: (context) => RequestDetailsScreen(request: request),
                    ),
                  );
                },
                padding: const EdgeInsets.all(AppSpacing.md),
                margin: const EdgeInsets.only(bottom: AppSpacing.md),
                child: Row(
                  children: [
                    // LEFT: Smart Thumbnail (Customer Image or Category Icon)
                    _buildSmartThumbnail(
                      imagePath: requestImagePath,
                      category: primaryCategory,
                      size: 64,
                      isDark: isDark,
                    ),
                    const SizedBox(width: AppSpacing.md),
                    // CENTER: Details
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            request.items.isNotEmpty ? request.items.first.name : 'Request',
                            style: AppTextStyles.labelLarge(primaryText),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 2),
                          Text(
                            primaryCategory.isNotEmpty ? primaryCategory.replaceAll('_', ' ').toUpperCase() : 'GENERAL',
                            style: AppTextStyles.caption(secondaryText),
                          ),
                          const SizedBox(height: 4),
                          Row(
                            children: [
                              Icon(Icons.receipt_long_outlined, size: 12, color: secondaryText),
                              const SizedBox(width: 4),
                              Text(
                                '$proposalCount ${proposalCount == 1 ? 'Proposal' : 'Proposals'}',
                                style: AppTextStyles.caption(secondaryText),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    // RIGHT: Status Chip
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Theme3StatusChip(
                          label: _formatRequestStatus(request.status),
                          status: statusType,
                        ),
                        const SizedBox(height: 8),
                        Text(
                          _formatTimeAgo(request.updatedAt ?? request.createdAt),
                          style: AppTextStyles.caption(secondaryText),
                        ),
                      ],
                    ),
                  ],
                ),
              );
            },
          ),
      ],
    );
  }

  Widget _buildRecentOrdersSection(BuildContext context, WidgetRef ref, dynamic orderState, bool isDark, Color primaryText, Color secondaryText) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text('Recent Orders', style: AppTextStyles.h2(primaryText)),
            if (orderState.orders.isNotEmpty)
              TextButton(
                onPressed: () => context.go(RouteNames.customerOrders),
                child: Text(
                  'View All →',
                  style: AppTextStyles.labelMedium(isDark ? AppColors.primaryDark : AppColors.primary),
                ),
              ),
          ],
        ),
        const SizedBox(height: AppSpacing.md),
        if (orderState.orders.isEmpty)
          Theme3EmptyState(
            icon: Icons.shopping_bag_outlined,
            title: 'No Orders Yet',
            subtitle: 'Your accepted merchant orders will appear here.',
          )
        else
          ListView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: orderState.orders.length > 3 ? 3 : orderState.orders.length,
            itemBuilder: (context, index) {
              final order = orderState.orders[index];
              final orderStatusType = order.status == OrderStatus.delivered
                  ? Theme3StatusType.completed
                  : (order.status == OrderStatus.cancelled ? Theme3StatusType.cancelled : Theme3StatusType.inProgress);
              
              final primaryCategory = _getOrderPrimaryCategory(order);
              final statusColor = _getOrderStatusColor(order.status);
              final orderImagePath = _getOrderThumbnailImage(order, ref);
              
              return Theme3AppCard(
                onTap: () => context.push('/customer/orders/track', extra: order),
                padding: const EdgeInsets.all(AppSpacing.md),
                margin: const EdgeInsets.only(bottom: AppSpacing.md),
                child: Row(
                  children: [
                    // LEFT: Smart Order Thumbnail (Vendor Image -> Customer Image -> Icon)
                    _buildSmartThumbnail(
                      imagePath: orderImagePath,
                      category: primaryCategory,
                      size: 56,
                      isDark: isDark,
                      statusColor: statusColor,
                    ),
                    const SizedBox(width: AppSpacing.md),
                    // CENTER: Details
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Order #${order.id.substring(0, 8)}',
                            style: AppTextStyles.labelLarge(primaryText),
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 2),
                          Text(
                            'from ${order.vendorBusinessName}',
                            style: AppTextStyles.bodySmall(secondaryText),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 6),
                          Theme3StatusChip(
                            label: _formatOrderStatus(order.status),
                            status: orderStatusType,
                          ),
                        ],
                      ),
                    ),
                    // RIGHT: Price & Actions
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(
                          'Rs. ${order.totalPrice.toStringAsFixed(2)}',
                          style: AppTextStyles.labelMedium(isDark ? AppColors.primaryDark : AppColors.primary),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          order.paymentMethod.toString().split('.').last.toUpperCase(),
                          style: AppTextStyles.caption(secondaryText),
                        ),
                      ],
                    ),
                  ],
                ),
              );
            },
          ),
      ],
    );
  }

  String _getOrderPrimaryCategory(OrderModel order) {
    if (order.items.isNotEmpty) {
      final itemName = order.items.first.itemName.toLowerCase();
      if (itemName.contains('rice') || itemName.contains('flour') || itemName.contains('sugar') || itemName.contains('vegetable') || itemName.contains('fruit')) {
        return 'groceries';
      } else if (itemName.contains('medicine') || itemName.contains('tablet') || itemName.contains('syrup')) {
        return 'pharmacy';
      } else if (itemName.contains('phone') || itemName.contains('laptop') || itemName.contains('tv') || itemName.contains('computer')) {
        return 'electronics';
      } else if (itemName.contains('hammer') || itemName.contains('nail') || itemName.contains('screw') || itemName.contains('tool')) {
        return 'hardware';
      } else if (itemName.contains('chair') || itemName.contains('table') || itemName.contains('sofa') || itemName.contains('bed')) {
        return 'furniture';
      }
    }
    return 'groceries';
  }

  Color _getOrderStatusColor(OrderStatus status) {
    switch (status) {
      case OrderStatus.accepted:
        return AppColors.info;
      case OrderStatus.preparing:
        return const Color(0xFF8B5CF6);
      case OrderStatus.outForDelivery:
        return AppColors.success;
      case OrderStatus.delivered:
        return const Color(0xFF059669);
      case OrderStatus.cancelled:
        return AppColors.error;
      default:
        return AppColors.warning;
    }
  }

  IconData _getOrderCategoryIcon(String category) {
    final normalized = category.toLowerCase().replaceAll(' ', '_');
    switch (normalized) {
      case 'groceries':
        return Icons.shopping_basket_rounded;
      case 'pharmacy':
        return Icons.medical_services_rounded;
      case 'electronics':
        return Icons.smartphone_rounded;
      case 'stationery':
        return Icons.edit_note_rounded;
      case 'hardware':
        return Icons.handyman_rounded;
      case 'furniture':
        return Icons.weekend_rounded;
      case 'clothing':
        return Icons.checkroom_rounded;
      case 'vehicle_parts':
        return Icons.directions_car_rounded;
      case 'home_appliances':
        return Icons.kitchen_rounded;
      default:
        return Icons.shopping_bag_rounded;
    }
  }

  /// Check if image path is a network URL
  bool _isNetworkImage(String path) {
    return path.startsWith('http://') || path.startsWith('https://');
  }

  /// Check if image path is an asset
  bool _isAssetImage(String path) {
    return path.startsWith('assets/');
  }

  /// Build image content with proper loader based on path type
  Widget _buildImageContent({
    required String imagePath,
    required double size,
    required Widget fallback,
  }) {
    if (_isNetworkImage(imagePath)) {
      return Image.network(
        imagePath,
        width: size,
        height: size,
        fit: BoxFit.cover,
        errorBuilder: (context, error, stackTrace) => fallback,
        loadingBuilder: (context, child, loadingProgress) {
          if (loadingProgress == null) return child;
          return fallback;
        },
      );
    }

    if (_isAssetImage(imagePath)) {
      return Image.asset(
        imagePath,
        width: size,
        height: size,
        fit: BoxFit.cover,
        errorBuilder: (context, error, stackTrace) => fallback,
      );
    }

    // Local file path
    return Image.file(
      File(imagePath),
      width: size,
      height: size,
      fit: BoxFit.cover,
      errorBuilder: (context, error, stackTrace) => fallback,
    );
  }

  /// Extract first available customer image from request
  String? _getRequestThumbnailImage(ShoppingRequest request) {
    // Priority: First request item image
    if (request.items.isNotEmpty) {
      for (final item in request.items) {
        if (item.imageUrls.isNotEmpty) {
          final firstImage = item.imageUrls.first.trim();
          if (firstImage.isNotEmpty) {
            return firstImage;
          }
        }
      }
    }
    return null;
  }

  /// Extract image from order with priority: vendor image -> customer image -> null
  String? _getOrderThumbnailImage(OrderModel order, WidgetRef ref) {
    // Priority 1: Vendor provided image (ProposalItem.imageUrl)
    if (order.items.isNotEmpty) {
      for (final item in order.items) {
        if (item.imageUrl != null && item.imageUrl!.trim().isNotEmpty) {
          return item.imageUrl;
        }
      }
    }
    
    // Priority 2: Customer uploaded request image (from in-memory request state)
    final requestState = ref.read(requestProvider);
    try {
      final request = requestState.requests.firstWhere((r) => r.id == order.requestId);
      if (request.items.isNotEmpty) {
        for (final item in request.items) {
          if (item.imageUrls.isNotEmpty) {
            final firstImage = item.imageUrls.first.trim();
            if (firstImage.isNotEmpty) {
              return firstImage;
            }
          }
        }
      }
    } catch (e) {
      // Request not found in state
    }
    
    return null;
  }

  /// Build smart thumbnail that shows image if available, otherwise category icon
  Widget _buildSmartThumbnail({
    required String? imagePath,
    required String category,
    required double size,
    required bool isDark,
    Color? statusColor,
  }) {
    final normalized = category.toLowerCase().trim().replaceAll(' ', '_');
    final categoryIcon = _getRequestCategoryIcon(normalized);
    final categoryColor = statusColor ?? _getRequestCategoryColor(normalized);
    
    // Build category icon fallback widget
    final iconFallback = Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: categoryColor.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(AppRadius.md),
        border: Border.all(
          color: categoryColor.withValues(alpha: 0.35),
          width: 1,
        ),
      ),
      child: Icon(
        categoryIcon,
        color: categoryColor,
        size: size * 0.47,
      ),
    );
    
    // If image exists, show image thumbnail
    if (imagePath != null && imagePath.trim().isNotEmpty) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(AppRadius.md),
        child: Container(
          width: size,
          height: size,
          decoration: BoxDecoration(
            color: categoryColor.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(AppRadius.md),
          ),
          child: _buildImageContent(
            imagePath: imagePath.trim(),
            size: size,
            fallback: iconFallback,
          ),
        ),
      );
    }
    
    // No image, show category icon thumbnail
    return iconFallback;
  }

  Color _getRequestCategoryColor(String normalized) {
    switch (normalized) {
      case 'groceries':
        return const Color(0xFF059669); // green
      case 'electronics':
        return const Color(0xFF0EA5E9); // blue
      case 'hardware':
        return const Color(0xFFF59E0B); // orange
      case 'furniture':
        return const Color(0xFF8B5CF6); // purple
      case 'pharmacy':
        return const Color(0xFFDC2626); // red
      case 'vehicle_parts':
        return const Color(0xFF6366F1); // indigo
      case 'home_appliances':
        return const Color(0xFFEC4899); // pink
      case 'books':
        return const Color(0xFF06B6D4); // cyan
      case 'clothing':
        return const Color(0xFFF43F5E); // rose
      case 'stationery':
        return const Color(0xFFFBBF24); // amber
      case 'other':
        return const Color(0xFF6B7280); // gray
      default:
        return const Color(0xFFF59E0B); // orange fallback
    }
  }

  IconData _getRequestCategoryIcon(String normalized) {
    switch (normalized) {
      case 'groceries':
        return Icons.shopping_basket_rounded;
      case 'electronics':
        return Icons.smartphone_rounded;
      case 'hardware':
        return Icons.handyman_rounded;
      case 'furniture':
        return Icons.weekend_rounded;
      case 'pharmacy':
        return Icons.medical_services_rounded;
      case 'vehicle_parts':
        return Icons.directions_car_rounded;
      case 'home_appliances':
        return Icons.kitchen_rounded;
      case 'books':
        return Icons.menu_book_rounded;
      case 'clothing':
        return Icons.checkroom_rounded;
      case 'stationery':
        return Icons.edit_note_rounded;
      case 'other':
        return Icons.inventory_2_rounded;
      default:
        return Icons.inventory_2_rounded; // generic fallback
    }
  }

  String _formatDate(DateTime date) {
    return '${date.day}/${date.month}/${date.year}';
  }

  String _formatTimeAgo(DateTime date) {
    final now = DateTime.now();
    final difference = now.difference(date);

    if (difference.inMinutes < 60) {
      return '${difference.inMinutes}m ago';
    } else if (difference.inHours < 24) {
      return '${difference.inHours}h ago';
    } else if (difference.inDays < 7) {
      return '${difference.inDays}d ago';
    } else {
      return '${date.day}/${date.month}';
    }
  }

  IconData _getCategoryIcon(String category) {
    final normalized = category.toLowerCase().replaceAll(' ', '_');
    switch (normalized) {
      case 'groceries':
        return Icons.shopping_basket_rounded;
      case 'pharmacy':
        return Icons.medical_services_rounded;
      case 'electronics':
        return Icons.smartphone_rounded;
      case 'stationery':
        return Icons.edit_note_rounded;
      case 'hardware':
        return Icons.handyman_rounded;
      case 'bakery':
        return Icons.bakery_dining_rounded;
      case 'meat_&_seafood':
        return Icons.restaurant_rounded;
      case 'clothing':
        return Icons.checkroom_rounded;
      case 'furniture':
        return Icons.weekend_rounded;
      case 'books':
        return Icons.menu_book_rounded;
      case 'home_appliances':
      case 'home appliances':
        return Icons.kitchen_rounded;
      case 'vehicle_parts':
      case 'vehicle parts':
        return Icons.directions_car_rounded;
      default:
        return Icons.shopping_bag_rounded;
    }
  }

  String _formatRequestStatus(dynamic status) {
    final value = status.toString().split('.').last;
    return value
        .replaceAllMapped(
          RegExp(r'([A-Z])'),
          (match) => ' ${match.group(0)}',
        )
        .trim()
        .split('_')
        .map((word) {
          if (word.isEmpty) return word;
          return word[0].toUpperCase() + word.substring(1);
        })
        .join(' ');
  }

  String _formatOrderStatus(dynamic status) {
    final value = status.toString().split('.').last;
    return value
        .replaceAllMapped(
          RegExp(r'([A-Z])'),
          (match) => ' ${match.group(0)}',
        )
        .trim()
        .split('_')
        .map((word) {
          if (word.isEmpty) return word;
          return word[0].toUpperCase() + word.substring(1);
        })
        .join(' ');
  }
}

// ── Customer Orders Tab ──────────────────────────────────────────────────
class CustomerOrdersTab extends ConsumerWidget {
  const CustomerOrdersTab({super.key});

  /// Check if image path is a network URL
  bool _isNetworkImage(String path) {
    return path.startsWith('http://') || path.startsWith('https://');
  }

  /// Check if image path is an asset
  bool _isAssetImage(String path) {
    return path.startsWith('assets/');
  }

  /// Build image content with proper loader based on path type
  Widget _buildImageContent({
    required String imagePath,
    required double size,
    required Widget fallback,
  }) {
    if (_isNetworkImage(imagePath)) {
      return Image.network(
        imagePath,
        width: size,
        height: size,
        fit: BoxFit.cover,
        errorBuilder: (context, error, stackTrace) => fallback,
        loadingBuilder: (context, child, loadingProgress) {
          if (loadingProgress == null) return child;
          return fallback;
        },
      );
    }

    if (_isAssetImage(imagePath)) {
      return Image.asset(
        imagePath,
        width: size,
        height: size,
        fit: BoxFit.cover,
        errorBuilder: (context, error, stackTrace) => fallback,
      );
    }

    // Local file path
    return Image.file(
      File(imagePath),
      width: size,
      height: size,
      fit: BoxFit.cover,
      errorBuilder: (context, error, stackTrace) => fallback,
    );
  }

  Widget _buildOrderThumbnail(OrderModel order, WidgetRef ref) {
    final primaryCategory = _getOrderPrimaryCategory(order);
    final statusColor = _getOrderStatusColor(order.status);
    final orderImagePath = _getOrderThumbnailImage(order, ref);
    
    return _buildSmartOrderThumbnail(
      imagePath: orderImagePath,
      category: primaryCategory,
      statusColor: statusColor,
    );
  }

  /// Extract image from order with priority: vendor image -> customer image -> null
  String? _getOrderThumbnailImage(OrderModel order, WidgetRef ref) {
    // Priority 1: Vendor provided image (ProposalItem.imageUrl)
    if (order.items.isNotEmpty) {
      for (final item in order.items) {
        if (item.imageUrl != null && item.imageUrl!.trim().isNotEmpty) {
          return item.imageUrl;
        }
      }
    }
    
    // Priority 2: Customer uploaded request image (from in-memory request state)
    final requestState = ref.read(requestProvider);
    try {
      final request = requestState.requests.firstWhere((r) => r.id == order.requestId);
      if (request.items.isNotEmpty) {
        for (final item in request.items) {
          if (item.imageUrls.isNotEmpty) {
            final firstImage = item.imageUrls.first.trim();
            if (firstImage.isNotEmpty) {
              return firstImage;
            }
          }
        }
      }
    } catch (e) {
      // Request not found in state
    }
    
    return null;
  }

  /// Build smart thumbnail for orders (vendor image -> customer image -> icon)
  Widget _buildSmartOrderThumbnail({
    required String? imagePath,
    required String category,
    required Color statusColor,
  }) {
    final categoryIcon = _getCategoryIcon(category);
    const size = 56.0;
    
    // Build category icon fallback widget
    final iconFallback = Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: statusColor.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(AppRadius.md),
      ),
      child: Icon(
        categoryIcon,
        color: statusColor,
        size: 28,
      ),
    );
    
    // If image exists, show it
    if (imagePath != null && imagePath.trim().isNotEmpty) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(AppRadius.md),
        child: Container(
          width: size,
          height: size,
          decoration: BoxDecoration(
            color: statusColor.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(AppRadius.md),
          ),
          child: _buildImageContent(
            imagePath: imagePath.trim(),
            size: size,
            fallback: iconFallback,
          ),
        ),
      );
    }
    
    // No image, show category icon
    return iconFallback;
  }

  String _getOrderPrimaryCategory(OrderModel order) {
    // Try to infer from item names or use generic fallback
    // Since ProposalItem doesn't have category field, use item name patterns
    if (order.items.isNotEmpty) {
      final itemName = order.items.first.itemName.toLowerCase();
      // Simple pattern matching for common items
      if (itemName.contains('rice') || itemName.contains('flour') || itemName.contains('sugar') || itemName.contains('vegetable') || itemName.contains('fruit')) {
        return 'groceries';
      } else if (itemName.contains('medicine') || itemName.contains('tablet') || itemName.contains('syrup')) {
        return 'pharmacy';
      } else if (itemName.contains('phone') || itemName.contains('laptop') || itemName.contains('tv') || itemName.contains('computer')) {
        return 'electronics';
      } else if (itemName.contains('hammer') || itemName.contains('nail') || itemName.contains('screw') || itemName.contains('tool')) {
        return 'hardware';
      } else if (itemName.contains('chair') || itemName.contains('table') || itemName.contains('sofa') || itemName.contains('bed')) {
        return 'furniture';
      }
    }
    // Default fallback
    return 'groceries';
  }

  Color _getOrderStatusColor(OrderStatus status) {
    switch (status) {
      case OrderStatus.accepted:
        return AppColors.info;
      case OrderStatus.preparing:
        return const Color(0xFF8B5CF6);
      case OrderStatus.outForDelivery:
        return AppColors.success;
      case OrderStatus.delivered:
        return const Color(0xFF059669);
      case OrderStatus.cancelled:
        return AppColors.error;
      default:
        return AppColors.warning;
    }
  }

  IconData _getCategoryIcon(String category) {
    final normalized = category.toLowerCase().replaceAll(' ', '_');
    switch (normalized) {
      case 'groceries':
        return Icons.shopping_basket_rounded;
      case 'pharmacy':
        return Icons.medical_services_rounded;
      case 'electronics':
        return Icons.smartphone_rounded;
      case 'stationery':
        return Icons.edit_note_rounded;
      case 'hardware':
        return Icons.handyman_rounded;
      case 'bakery':
        return Icons.bakery_dining_rounded;
      case 'meat_&_seafood':
        return Icons.restaurant_rounded;
      case 'clothing':
        return Icons.checkroom_rounded;
      case 'furniture':
        return Icons.weekend_rounded;
      case 'books':
        return Icons.menu_book_rounded;
      case 'home_appliances':
      case 'home appliances':
        return Icons.kitchen_rounded;
      case 'vehicle_parts':
      case 'vehicle parts':
        return Icons.directions_car_rounded;
      default:
        return Icons.shopping_bag_rounded;
    }
  }

  String _getDateGroup(DateTime date) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final yesterday = today.subtract(const Duration(days: 1));
    final orderDate = DateTime(date.year, date.month, date.day);
    
    if (orderDate == today) return 'Today';
    if (orderDate == yesterday) return 'Yesterday';
    if (now.difference(orderDate).inDays <= 7) return 'Earlier This Week';
    return 'Older Orders';
  }

  Map<String, List<dynamic>> _groupOrdersByDate(List<dynamic> orders) {
    final grouped = <String, List<dynamic>>{
      'Today': [],
      'Yesterday': [],
      'Earlier This Week': [],
      'Older Orders': [],
    };
    
    for (final order in orders) {
      final group = _getDateGroup(order.createdAt);
      grouped[group]!.add(order);
    }
    
    return grouped;
  }

  String _formatOrderStatus(dynamic status) {
    final raw = status.toString().split('.').last;
    return raw
        .replaceAllMapped(
          RegExp(r'([A-Z])'),
          (match) => ' ${match.group(0)}',
        )
        .replaceAll('_', ' ')
        .trim()
        .split(' ')
        .where((word) => word.isNotEmpty)
        .map((word) => word[0].toUpperCase() + word.substring(1))
        .join(' ');
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primaryText = isDark ? AppColors.textPrimaryDark : AppColors.textPrimaryLight;
    final secondaryText = isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight;

    final orderState = ref.watch(orderProvider);
    final groupedOrders = orderState.orders.isNotEmpty
        ? _groupOrdersByDate(orderState.orders)
        : <String, List<dynamic>>{};

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) {
          context.go(RouteNames.customerHome);
        }
      },
      child: Scaffold(
        backgroundColor: Colors.transparent,
        body: RefreshIndicator(
          onRefresh: () => ref.read(orderProvider.notifier).loadCustomerOrders(),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 20, 20, 10),
                child: Text('My Orders', style: AppTextStyles.h2(primaryText)),
              ),
              Expanded(
                child: orderState.isLoading
                    ? const Center(child: CircularProgressIndicator(color: AppColors.primary))
                    : orderState.orders.isEmpty
                        ? Theme3EmptyState(
                            icon: Icons.shopping_bag_outlined,
                            title: 'No Orders Yet',
                            subtitle: 'Your orders will appear here.',
                          )
                        : ListView(
                            padding: const EdgeInsets.all(AppSpacing.lg),
                            children: [
                              for (final groupKey in ['Today', 'Yesterday', 'Earlier This Week', 'Older Orders'])
                                if (groupedOrders[groupKey]?.isNotEmpty ?? false) ...[
                                  Padding(
                                    padding: const EdgeInsets.only(left: 4, bottom: AppSpacing.sm, top: AppSpacing.md),
                                    child: Text(
                                      groupKey,
                                      style: AppTextStyles.subtitle(primaryText),
                                    ),
                                  ),
                                  ...groupedOrders[groupKey]!.map((order) {
                                    final statusColor = _getOrderStatusColor(order.status);
                                    final primaryCategory = _getOrderPrimaryCategory(order);
                                    
                                    return Theme3AppCard(
                                      onTap: () => context.push('/customer/orders/track', extra: order),
                                      padding: const EdgeInsets.all(AppSpacing.lg),
                                      margin: const EdgeInsets.only(bottom: AppSpacing.md),
                                      child: Row(
                                        children: [
                                          _buildOrderThumbnail(order, ref),
                                          const SizedBox(width: AppSpacing.md),
                                          Expanded(
                                            child: Column(
                                              crossAxisAlignment: CrossAxisAlignment.start,
                                              children: [
                                                Text(
                                                  'Order #${order.id.substring(0, 8)}',
                                                  style: AppTextStyles.labelLarge(primaryText),
                                                ),
                                                const SizedBox(height: 2),
                                                Text(
                                                  order.vendorBusinessName,
                                                  style: AppTextStyles.bodySmall(secondaryText),
                                                  maxLines: 1,
                                                  overflow: TextOverflow.ellipsis,
                                                ),
                                                const SizedBox(height: 6),
                                                Row(
                                                  children: [
                                                    Container(
                                                      width: 8,
                                                      height: 8,
                                                      decoration: BoxDecoration(
                                                        color: statusColor,
                                                        shape: BoxShape.circle,
                                                      ),
                                                    ),
                                                    const SizedBox(width: 6),
                                                    Text(
                                                      _formatOrderStatus(order.status),
                                                      style: AppTextStyles.caption(statusColor),
                                                    ),
                                                  ],
                                                ),
                                              ],
                                            ),
                                          ),
                                          Column(
                                            crossAxisAlignment: CrossAxisAlignment.end,
                                            children: [
                                              Text(
                                                'Rs. ${order.totalPrice.toStringAsFixed(2)}',
                                                style: AppTextStyles.labelMedium(
                                                  isDark ? AppColors.primaryDark : AppColors.primary,
                                                ),
                                              ),
                                              const SizedBox(height: 4),
                                              Text(
                                                order.paymentMethod.toString().split('.').last.toUpperCase(),
                                                style: AppTextStyles.caption(secondaryText),
                                              ),
                                            ],
                                          ),
                                        ],
                                      ),
                                    );
                                  }),
                                ],
                            ],
                          ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
