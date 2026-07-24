import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:speedmart_lanka/core/theme/app_colors.dart';
import 'package:speedmart_lanka/core/theme/app_spacing.dart';
import 'package:speedmart_lanka/core/theme/app_radius.dart';
import 'package:speedmart_lanka/core/theme/app_text_styles.dart';
import 'package:speedmart_lanka/core/widgets/theme3/theme3_app_card.dart';
import 'package:speedmart_lanka/core/widgets/theme3/theme3_empty_state.dart';
import 'package:speedmart_lanka/core/widgets/app_state_widgets.dart';
import 'package:speedmart_lanka/core/guards/vendor_status_guard.dart';
import 'package:speedmart_lanka/features/auth/providers/auth_provider.dart';
import 'package:speedmart_lanka/features/auth/providers/theme_provider.dart';
import 'package:speedmart_lanka/core/providers/notification_provider.dart';
import 'package:speedmart_lanka/shared/models/user_role.dart';
import 'package:speedmart_lanka/features/vendor/request_feed/presentation/vendor_request_feed_screen.dart';
import 'package:speedmart_lanka/features/vendor/request_feed/providers/vendor_request_feed_provider.dart';
import 'package:speedmart_lanka/features/vendor/request_feed/widgets/vendor_request_card.dart';
import 'package:speedmart_lanka/features/proposals/models/proposal.dart';
import 'package:speedmart_lanka/features/proposals/providers/proposal_provider.dart';
import 'package:speedmart_lanka/features/orders/models/order_model.dart';
import 'package:speedmart_lanka/features/orders/providers/order_provider.dart';
import 'package:speedmart_lanka/core/widgets/theme3/request_image_carousel.dart';
import 'package:speedmart_lanka/features/requests/models/shopping_request.dart';
import 'package:speedmart_lanka/features/shared/presentation/screens/profile_screen.dart';
import 'package:speedmart_lanka/core/widgets/shared_floating_bottom_nav.dart';
import 'package:speedmart_lanka/core/navigation/bottom_nav_visibility.dart';
import 'package:speedmart_lanka/features/payments/models/payment.dart';
import 'vendor_status_screen.dart';
import 'package:speedmart_lanka/features/requests/data/mock_request_repository.dart';

class VendorHomeScreen extends ConsumerStatefulWidget {
  const VendorHomeScreen({super.key});

  @override
  ConsumerState<VendorHomeScreen> createState() => _VendorHomeScreenState();
}

class _VendorHomeScreenState extends ConsumerState<VendorHomeScreen>
    with WidgetsBindingObserver {
  int _currentIndex = 0;
  DateTime? _lastBackPressTime;

  void _switchTab(int index) {
    setState(() => _currentIndex = index);
  }

  @override
  void initState() {
    super.initState();
    debugPrint('[VendorHome] init');
    WidgetsBinding.instance.addObserver(this);

    // Load data asynchronously on screen entry
    Future.microtask(() {
      final user = ref.read(currentUserProvider);
      debugPrint('[VendorHome] current user role: ${user?.role}');

      if (user?.role != UserRole.vendor) {
        debugPrint('[VendorHome] user is not vendor, skipping data load');
        return;
      }

      debugPrint('[VendorHome] loading dashboard data');
      try {
        ref.read(vendorRequestFeedProvider.notifier).loadFeed();
        ref.read(proposalProvider.notifier).loadVendorProposals();
        ref.read(orderProvider.notifier).loadVendorOrders();
        debugPrint('[VendorHome] dashboard data load initiated');
      } catch (e) {
        debugPrint('[VendorHome] dashboard load failed: $e');
      }
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  /// Called by the system BEFORE GoRouter's back-button dispatcher.
  /// Returning [true] consumes the event; [false] lets GoRouter handle it.
  @override
  Future<bool> didPopRoute() async {
    if (!mounted) return false;

    // Get current auth and vendor status
    final user = ref.read(currentUserProvider);
    final shouldShowStatusScreen =
        VendorStatusGuard.shouldShowStatusScreen(user);

    // If showing status screen (inactive vendor), let PopScope in VendorStatusScreen handle it
    if (shouldShowStatusScreen) {
      debugPrint(
          '[VendorHome] Back pressed on inactive vendor status screen, delegating to VendorStatusScreen');
      return false;
    }

    // Only intercept on vendor shell tabs for ACTIVE vendors
    const vendorTabs = {
      '/vendor',
      '/vendor/requests',
      '/vendor/proposals',
      '/vendor/orders',
      '/vendor/earnings',
      '/vendor/profile',
    };

    // Determine current location from GoRouter.
    final String location;
    try {
      location = GoRouter.of(context).routeInformationProvider.value.uri.path;
    } catch (_) {
      return false;
    }

    if (!vendorTabs.contains(location)) return false;

    // Non-home tab: go back to Home tab.
    if (_currentIndex != 0) {
      setState(() => _currentIndex = 0);
      return true;
    }

    // Home tab: double-back to exit.
    final now = DateTime.now();
    if (_lastBackPressTime == null ||
        now.difference(_lastBackPressTime!) > const Duration(seconds: 2)) {
      _lastBackPressTime = now;
      ScaffoldMessenger.of(context)
        ..clearSnackBars()
        ..showSnackBar(
          const SnackBar(
            content: Text('Swipe back again to exit'),
            duration: Duration(seconds: 2),
            behavior: SnackBarBehavior.floating,
          ),
        );
      return true; // consumed – do NOT exit
    }

    // Second press within 2 s → let the system exit.
    return false;
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final user = ref.watch(currentUserProvider);
    final shouldShowStatusScreen =
        VendorStatusGuard.shouldShowStatusScreen(user);

    // Watch central bottom navigation visibility provider
    final shellLocation = GoRouterState.of(context).matchedLocation;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(bottomNavVisibilityProvider.notifier).updateLocation(shellLocation);
    });
    
    final showBottomNav = ref.watch(bottomNavVisibilityProvider);
    final requestFeedState = ref.watch(vendorRequestFeedProvider);

    // PopScope(canPop: false) suppresses the Android 13 predictive-back
    // swipe preview so the UI doesn't flash a "going back" animation.
    // The actual double-back logic lives in didPopRoute() above.
    return PopScope(
      canPop: false,
      child: Scaffold(
        extendBody: true,
        backgroundColor:
            isDark ? AppColors.backgroundDark : AppColors.backgroundLight,
        body: Column(
          children: [
            _buildVendorHeader(context, isDark),
            Expanded(
              child: shouldShowStatusScreen
                  ? (user != null
                      ? VendorStatusScreen(user: user)
                      : _PendingApprovalView(isDark: isDark))
                  : _AnimatedIndexedStack(
                      index: _currentIndex,
                      children: [
                        _DashboardTab(
                          user: user,
                          isDark: isDark,
                          onNavigateTab: _switchTab,
                        ),
                        VendorRequestFeedScreen(isDark: isDark),
                        _MyProposalsTab(isDark: isDark),
                        const _VendorWalletTab(),
                        ProfileScreen(
                          showBackButton: false,
                          onVendorRequestsTap: () => _switchTab(1),
                        ),
                      ],
                    ),
            ),
          ],
        ),
        bottomNavigationBar: AnimatedBottomNavWrapper(
          visible: !shouldShowStatusScreen && showBottomNav,
          child: SharedFloatingBottomNav(
            currentIndex: _currentIndex,
            onTap: _switchTab,
            activeColor: AppColors.vendorColor,
            items: [
              const SharedFloatingBottomNavItem(
                unselectedIcon: Icons.dashboard_outlined,
                selectedIcon: Icons.dashboard_rounded,
                label: 'Dashboard',
              ),
              SharedFloatingBottomNavItem(
                unselectedIcon: Icons.inbox_outlined,
                selectedIcon: Icons.inbox_rounded,
                label: 'Requests',
                badgeCount: requestFeedState.items.length,
              ),
              const SharedFloatingBottomNavItem(
                unselectedIcon: Icons.assignment_outlined,
                selectedIcon: Icons.assignment_rounded,
                label: 'Proposals',
              ),
              const SharedFloatingBottomNavItem(
                unselectedIcon: Icons.account_balance_wallet_outlined,
                selectedIcon: Icons.account_balance_wallet_rounded,
                label: 'Earnings',
              ),
              const SharedFloatingBottomNavItem(
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

class _DashboardTab extends ConsumerWidget {
  const _DashboardTab({
    required this.user,
    required this.isDark,
    this.onNavigateTab,
  });
  final dynamic user;
  final bool isDark;
  final ValueChanged<int>? onNavigateTab;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Role check - critical for preventing blank dashboard
    if (user == null || user.role != UserRole.vendor) {
      debugPrint('[VendorHome] Dashboard: user not vendor');
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.lock_outline, size: 64, color: AppColors.vendorColor),
              const SizedBox(height: 16),
              Text('Shop Owner account required',
                  style: AppTextStyles.h3(isDark
                      ? AppColors.textPrimaryDark
                      : AppColors.textPrimaryLight)),
            ],
          ),
        ),
      );
    }

    final primaryText =
        isDark ? AppColors.textPrimaryDark : AppColors.textPrimaryLight;
    final secondaryText =
        isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight;
    
    

    final feedState = ref.watch(vendorRequestFeedProvider);
    final proposalState = ref.watch(proposalProvider);
    final orderState = ref.watch(orderProvider);

    // Check overall loading state
    final isLoading =
        feedState.isLoading || proposalState.isLoading || orderState.isLoading;
    final hasError = feedState.error != null ||
        proposalState.error != null ||
        orderState.error != null;

    // Show loading state if any provider is loading on first load
    if (isLoading &&
        feedState.items.isEmpty &&
        proposalState.proposals.isEmpty &&
        orderState.orders.isEmpty) {
      debugPrint('[VendorHome] dashboard loading...');
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const CircularProgressIndicator(color: AppColors.vendorColor),
            const SizedBox(height: 16),
            Text('Loading dashboard...',
                style: AppTextStyles.bodyMedium(primaryText)),
          ],
        ),
      );
    }

    // Show error state if there are errors
    if (hasError) {
      debugPrint('[VendorHome] dashboard error state');
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.error_outline, size: 64, color: AppColors.error),
              const SizedBox(height: 16),
              Text('Failed to load dashboard',
                  style: AppTextStyles.h3(primaryText)),
              const SizedBox(height: 8),
              Text(
                feedState.error ??
                    proposalState.error ??
                    orderState.error ??
                    'Unknown error',
                style: AppTextStyles.bodyMedium(secondaryText),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      );
    }

    final newRequestsCount = feedState.items.length.toString();
    final proposalsSentCount = proposalState.proposals.length.toString();

    // Active orders: anything not in completed/cancelled/delivered state
    final activeOrders = orderState.orders
        .where((o) =>
            o.status != OrderStatus.delivered &&
            o.status != OrderStatus.completed &&
            o.status != OrderStatus.cancelled)
        .toList();
    final activeOrdersCount = activeOrders.length.toString();

    // Completed orders: successfully delivered
    final completedOrders = orderState.orders
        .where((o) =>
            o.status == OrderStatus.delivered ||
            o.status == OrderStatus.completed)
        .toList();
    final completedOrdersCount = completedOrders.length.toString();

    final paidOrders = orderState.orders.where((o) =>
        (o.status == OrderStatus.delivered || o.status == OrderStatus.completed) &&
        (o.paymentStatus == PaymentStatus.paid ||
            o.paymentStatus == PaymentStatus.pendingOnDelivery)).toList();
    final pendingOrders = orderState.orders.where((o) =>
        o.status != OrderStatus.cancelled &&
        o.status != OrderStatus.completed &&
        o.status != OrderStatus.delivered).toList();

    final paidGrossEarnings = paidOrders.fold<double>(0, (sum, o) => sum + o.totalPrice);
    final paidNetEarnings = paidOrders.fold<double>(0, (sum, o) => sum + o.vendorNetAmount);
    final pendingGrossEarnings = pendingOrders.fold<double>(0, (sum, o) => sum + o.totalPrice);
    final pendingNetEarnings = pendingOrders.fold<double>(0, (sum, o) => sum + o.vendorNetAmount);

    final hiddenCommissionOwed = paidOrders.fold<double>(0, (sum, o) => sum + o.platformCommission);

    debugPrint(
        '[VendorHome] dashboard rendered with ${feedState.items.length} requests, ${proposalState.proposals.length} proposals, ${orderState.orders.length} orders');

    return RefreshIndicator(
      onRefresh: () async {
        await ref.read(vendorRequestFeedProvider.notifier).refresh();
        await ref.read(proposalProvider.notifier).loadVendorProposals();
        await ref.read(orderProvider.notifier).loadVendorOrders();
      },
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: EdgeInsets.fromLTRB(AppSpacing.md, AppSpacing.md, AppSpacing.md, 100),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _DashboardHeroBanner(
              user: user,
              paidEarnings: paidNetEarnings,
              pendingEarnings: pendingNetEarnings,
              grossPaidEarnings: paidGrossEarnings,
              grossPendingEarnings: pendingGrossEarnings,
              commissionOwed: hiddenCommissionOwed,
              isDark: isDark,
            ),
            SizedBox(height: AppSpacing.lg),
            Text('Today at a glance', style: AppTextStyles.h2(primaryText)),
            SizedBox(height: AppSpacing.sm),
            SizedBox(
              height: 100,
              child: ListView(
                scrollDirection: Axis.horizontal,
                children: [
                  _DashboardMetricTile(
                    label: 'New Requests',
                    value: newRequestsCount,
                    icon: Icons.inbox_rounded,
                    color: AppColors.vendorColor,
                    isDark: isDark,
                  ),
                  SizedBox(width: AppSpacing.sm),
                  _DashboardMetricTile(
                    label: 'Proposals',
                    value: proposalsSentCount,
                    icon: Icons.send_rounded,
                    color: AppColors.info,
                    isDark: isDark,
                  ),
                  SizedBox(width: AppSpacing.sm),
                  _DashboardMetricTile(
                    label: 'Active Orders',
                    value: activeOrdersCount,
                    icon: Icons.local_shipping_outlined,
                    color: AppColors.warning,
                    isDark: isDark,
                  ),
                  SizedBox(width: AppSpacing.sm),
                  _DashboardMetricTile(
                    label: 'Completed',
                    value: completedOrdersCount,
                    icon: Icons.task_alt_rounded,
                    color: AppColors.success,
                    isDark: isDark,
                  ),
                ],
              ),
            ),
            SizedBox(height: AppSpacing.lg),
            Text('Quick access', style: AppTextStyles.h2(primaryText)),
            SizedBox(height: AppSpacing.sm),
            SizedBox(
              height: 104,
              child: ListView(
                scrollDirection: Axis.horizontal,
                children: [
                  _DashboardQuickAction(
                    label: 'Browse Requests',
                    icon: Icons.radar_rounded,
                    color: AppColors.vendorColor,
                    isDark: isDark,
                    badgeCount: feedState.items.length,
                    onTap: () => onNavigateTab?.call(1),
                  ),
                  SizedBox(width: AppSpacing.sm),
                  _DashboardQuickAction(
                    label: 'My Proposals',
                    icon: Icons.assignment_turned_in_outlined,
                    color: AppColors.success,
                    isDark: isDark,
                    onTap: () => onNavigateTab?.call(2),
                  ),
                  SizedBox(width: AppSpacing.sm),
                  _DashboardQuickAction(
                    label: 'Active Orders',
                    icon: Icons.local_shipping_rounded,
                    color: AppColors.warning,
                    isDark: isDark,
                    badgeCount: activeOrders.length,
                    onTap: () => context.push('/vendor/orders'),
                  ),
                  SizedBox(width: AppSpacing.sm),
                  _DashboardQuickAction(
                    label: 'Earnings',
                    icon: Icons.payments_outlined,
                    color: AppColors.accent,
                    isDark: isDark,
                    onTap: () => onNavigateTab?.call(3),
                  ),
                ],
              ),
            ),
            SizedBox(height: AppSpacing.lg),

            if (activeOrders.isNotEmpty) ...[
              _DashboardSectionHeader(
                title: 'Orders in progress',
                subtitle: activeOrders.length > 1
                    ? 'Multiple orders · ${activeOrders.length} active'
                    : '${activeOrders.length} active',
                primaryText: primaryText,
                secondaryText: secondaryText,
              ),
              SizedBox(height: AppSpacing.sm),
              ...activeOrders.map(
                (order) => _DashboardOrderCard(
                  order: order,
                  isDark: isDark,
                  primaryText: primaryText,
                  secondaryText: secondaryText,
                  accentColor: AppColors.vendorColor,
                  isMultipleOrders: activeOrders.length > 1,
                  onManage: () => context.push('/vendor/orders/manage', extra: order),
                ),
              ),
              SizedBox(height: AppSpacing.md),
            ],

            if (completedOrders.isNotEmpty) ...[
              _DashboardSectionHeader(
                title: 'Recently completed',
                subtitle: 'Last ${completedOrders.length > 3 ? 3 : completedOrders.length} orders',
                primaryText: primaryText,
                secondaryText: secondaryText,
              ),
              SizedBox(height: AppSpacing.sm),
              ...completedOrders.take(3).map(
                (order) => _DashboardCompletedOrderCard(
                  order: order,
                  isDark: isDark,
                  primaryText: primaryText,
                  secondaryText: secondaryText,
                ),
              ),
              SizedBox(height: AppSpacing.md),
            ],

            _DashboardSectionHeader(
              title: 'Nearby opportunities',
              subtitle: feedState.items.isEmpty
                  ? 'No requests in your radius'
                  : '${feedState.items.length} open nearby',
              primaryText: primaryText,
              secondaryText: secondaryText,
            ),
            SizedBox(height: AppSpacing.sm),

            if (feedState.isLoading)
              Center(
                child: Padding(
                  padding: EdgeInsets.all(AppSpacing.xxl),
                  child: Column(
                    children: [
                      const CircularProgressIndicator(color: AppColors.vendorColor),
                      SizedBox(height: AppSpacing.sm),
                      Text(
                        'Scanning nearby requests...',
                        style: AppTextStyles.bodyMedium(primaryText),
                      ),
                    ],
                  ),
                ),
              )
            else if (feedState.items.isEmpty)
              Theme3EmptyState(
                icon: Icons.location_searching_rounded,
                title: 'No nearby requests',
                subtitle: 'Active requests in your categories and radius will appear here.',
              )
            else
              ...feedState.items.take(2).map(
                (item) => Padding(
                  padding: EdgeInsets.only(bottom: AppSpacing.sm),
                  child: VendorRequestCard(
                    feedRequest: item,
                    isDark: isDark,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _MyProposalsTab extends ConsumerStatefulWidget {
  const _MyProposalsTab({required this.isDark});
  final bool isDark;

  @override
  ConsumerState<_MyProposalsTab> createState() => _MyProposalsTabState();
}

class _MyProposalsTabState extends ConsumerState<_MyProposalsTab> {
  bool _groupByRequest = true;
  String _statusFilter = 'Active';
  final Map<String, ShoppingRequest?> _requestCache = {};
  bool _isLoadingRequests = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        _loadRequestMetadata(ref.read(proposalProvider).proposals);
      }
    });
  }

  Future<void> _loadRequestMetadata(List<Proposal> proposals) async {
    final uniqueRequestIds = proposals.map((p) => p.requestId).toSet();
    final missingIds = uniqueRequestIds.where((id) => !_requestCache.containsKey(id)).toList();
    if (missingIds.isEmpty) return;

    if (mounted) {
      setState(() {
        _isLoadingRequests = true;
        for (final id in missingIds) {
          _requestCache[id] = null;
        }
      });
    }

    try {
      final results = await Future.wait(
        missingIds.map((id) => MockRequestRepository.instance.getRequestById(id)),
      );

      if (mounted) {
        setState(() {
          for (int i = 0; i < missingIds.length; i++) {
            _requestCache[missingIds[i]] = results[i];
          }
          _isLoadingRequests = false;
        });
      }
    } catch (e) {
      debugPrint('[_MyProposalsTabState] Error loading requests: $e');
      if (mounted) {
        setState(() {
          _isLoadingRequests = false;
        });
      }
    }
  }

  Widget _buildRequestHeader(String requestId, Color primaryText, Color secondaryText) {
    final req = _requestCache[requestId];
    if (req == null) {
      return Row(children: [
        const Icon(Icons.shopping_bag_outlined, color: AppColors.vendorColor),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            'Request: $requestId',
            style: AppTextStyles.subtitle(primaryText).copyWith(fontWeight: FontWeight.bold),
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ]);
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(children: [
              const Icon(Icons.receipt_long_rounded, color: AppColors.vendorColor, size: 20),
              const SizedBox(width: 8),
              Text(
                req.customerName.isNotEmpty ? req.customerName : 'Customer',
                style: AppTextStyles.subtitle(primaryText).copyWith(fontWeight: FontWeight.bold),
              ),
            ]),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: AppColors.vendorColor.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                'REQ: ${req.id}',
                style: AppTextStyles.caption(AppColors.vendorColor).copyWith(fontWeight: FontWeight.bold),
              ),
            ),
          ],
        ),
        if (req.deliveryAddress.isNotEmpty) ...[
          const SizedBox(height: 4),
          Row(children: [
            Icon(Icons.location_on_outlined, color: secondaryText, size: 14),
            const SizedBox(width: 4),
            Expanded(
              child: Text(
                req.deliveryAddress,
                style: AppTextStyles.caption(secondaryText),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ]),
        ],
      ],
    );
  }

  Color _getStatusColor(ProposalStatus status) {
    switch (status) {
      case ProposalStatus.draft:
        return AppColors.warning;
      case ProposalStatus.submitted:
      case ProposalStatus.updated:
        return AppColors.vendorColor;
      case ProposalStatus.accepted:
        return AppColors.success;
      case ProposalStatus.rejected:
      case ProposalStatus.withdrawn:
      case ProposalStatus.expired:
        return AppColors.error;
    }
  }

  bool get isDark => widget.isDark;

  /// Groups proposals by requestId preserving insertion order.
  Map<String, List<Proposal>> _groupByRequestId(List<Proposal> proposals) {
    final map = <String, List<Proposal>>{};
    for (final p in proposals) {
      (map[p.requestId] ??= []).add(p);
    }
    return map;
  }

  Color _getOrderStatusColor(OrderStatus status) {
    switch (status) {
      case OrderStatus.submitted:
      case OrderStatus.accepted:
        return AppColors.vendorColor;
      case OrderStatus.preparing:
      case OrderStatus.readyForDelivery:
        return AppColors.warning;
      case OrderStatus.outForDelivery:
        return Colors.orange;
      case OrderStatus.delivered:
      case OrderStatus.completed:
        return AppColors.success;
      case OrderStatus.cancelled:
        return AppColors.error;
    }
  }

  Widget _buildToggleButton({
    required String label,
    required bool selected,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
        decoration: BoxDecoration(
          color: selected
              ? AppColors.vendorColor
              : Colors.transparent,
          borderRadius: BorderRadius.circular(10),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: selected ? Colors.white : (isDark ? Colors.white60 : Colors.black54),
            fontWeight: selected ? FontWeight.bold : FontWeight.normal,
            fontSize: 13,
          ),
        ),
      ),
    );
  }

  Widget _buildSmallBadge(String label, Color color) {
    return Container(
      margin: const EdgeInsets.only(left: 4),
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        label,
        style: TextStyle(color: color, fontSize: 10, fontWeight: FontWeight.bold),
      ),
    );
  }

  List<Proposal> _filterProposals(List<Proposal> proposals) {
    switch (_statusFilter) {
      case 'Accepted':
        return proposals.where((p) => p.status == ProposalStatus.accepted).toList();
      case 'Rejected':
        return proposals.where((p) => p.status == ProposalStatus.rejected).toList();
      case 'Active':
      default:
        return proposals.where((p) =>
            p.status == ProposalStatus.draft ||
            p.status == ProposalStatus.submitted ||
            p.status == ProposalStatus.updated).toList();
    }
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
  Widget build(BuildContext context) {
    final primaryText = isDark ? AppColors.textPrimaryDark : AppColors.textPrimaryLight;
    final secondaryText = isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight;
    final borderCol = isDark ? AppColors.borderDark : AppColors.borderLight;

    final proposalState = ref.watch(proposalProvider);
    final orderState = ref.watch(orderProvider);
    final orders = orderState.orders;
    final filteredProposals = _filterProposals(proposalState.proposals);

    // Listen for updates to load request metadata
    ref.listen<ProposalState>(proposalProvider, (previous, next) {
      _loadRequestMetadata(next.proposals);
    });

    // Ensure we trigger metadata loading if any missing IDs exist
    final uniqueRequestIds = proposalState.proposals.map((p) => p.requestId).toSet();
    final hasMissing = uniqueRequestIds.any((id) => !_requestCache.containsKey(id));
    if (hasMissing) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          _loadRequestMetadata(proposalState.proposals);
        }
      });
    }

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: RefreshIndicator(
        onRefresh: () => ref.read(proposalProvider.notifier).loadVendorProposals(),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Header + toggle ──────────────────────────────────────────
            Padding(
              padding: EdgeInsets.fromLTRB(AppSpacing.md, AppSpacing.md, AppSpacing.md, AppSpacing.sm),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('Order Proposals', style: AppTextStyles.h2(primaryText)),
                  Container(
                    decoration: BoxDecoration(
                      color: isDark ? Colors.black26 : Colors.grey.shade200,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    padding: const EdgeInsets.all(2),
                    child: Row(
                      children: [
                        _buildToggleButton(
                          label: 'By Request',
                          selected: _groupByRequest,
                          onTap: () => setState(() => _groupByRequest = true),
                        ),
                        _buildToggleButton(
                          label: 'Flat List',
                          selected: !_groupByRequest,
                          onTap: () => setState(() => _groupByRequest = false),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              padding: EdgeInsets.fromLTRB(AppSpacing.md, 0, AppSpacing.md, AppSpacing.sm),
              child: Row(
                children: [
                  for (final filter in const ['Active', 'Accepted', 'Rejected']) ...[
                    _buildToggleButton(
                      label: filter,
                      selected: _statusFilter == filter,
                      onTap: () => setState(() => _statusFilter = filter),
                    ),
                    const SizedBox(width: 4),
                  ],
                ],
              ),
            ),

            // ── Body ────────────────────────────────────────────────────
            Expanded(
              child: proposalState.isLoading
                  ? const Center(child: CircularProgressIndicator(color: AppColors.vendorColor))
                  : filteredProposals.isEmpty
                      ? Theme3EmptyState(
                          icon: Icons.assignment_outlined,
                          title: _statusFilter == 'Rejected' ? 'No Rejected Proposals' : 'No Proposals Found',
                          subtitle: _statusFilter == 'Rejected'
                              ? 'Rejected proposals will appear here.'
                              : 'Submit a proposal to see it in this list.',
                        )
                      : _groupByRequest
                          ? _buildGroupedView(
                              filteredProposals, orders, primaryText, secondaryText, borderCol)
                          : _buildFlatView(
                              filteredProposals, primaryText, secondaryText),
            ),
          ],
        ),
      ),
    );
  }

  // ── BY REQUEST view ────────────────────────────────────────────────────────
  Widget _buildGroupedView(
    List<Proposal> proposals,
    List<OrderModel> orders,
    Color primaryText,
    Color secondaryText,
    Color borderCol,
  ) {
    final groups = _groupByRequestId(proposals);
    final requestIds = groups.keys.toList();

    return ListView.builder(
      padding: EdgeInsets.fromLTRB(AppSpacing.md, 0, AppSpacing.md, 100),
      itemCount: requestIds.length,
      itemBuilder: (context, index) {
        final requestId = requestIds[index];
        final requestProposals = groups[requestId] ?? [];
        if (requestProposals.isEmpty) return const SizedBox.shrink();

        final acceptedCount = requestProposals.where((p) => p.status == ProposalStatus.accepted).length;
        final awaitingCount = requestProposals.where((p) =>
            p.status == ProposalStatus.submitted || p.status == ProposalStatus.updated).length;
        final rejectedCount = requestProposals.where((p) => p.status == ProposalStatus.rejected).length;

        return Theme3AppCard(
          margin: EdgeInsets.only(bottom: AppSpacing.md),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Request header
              _buildRequestHeader(requestId, primaryText, secondaryText),

              const Divider(height: 20),

              // Progress summary
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Bids (${requestProposals.length}):',
                    style: AppTextStyles.caption(secondaryText).copyWith(fontWeight: FontWeight.bold),
                  ),
                  Row(children: [
                    if (acceptedCount > 0) _buildSmallBadge('✓ $acceptedCount Accepted', AppColors.success),
                    if (awaitingCount > 0) _buildSmallBadge('⏳ $awaitingCount Pending', AppColors.vendorColor),
                    if (rejectedCount > 0) _buildSmallBadge('✗ $rejectedCount Rejected', AppColors.error),
                  ]),
                ],
              ),
              const SizedBox(height: 12),

              // Per-proposal rows
              ListView.separated(
                padding: EdgeInsets.zero,
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: requestProposals.length,
                separatorBuilder: (_, __) => const SizedBox(height: 10),
                itemBuilder: (context, idx) {
                  final proposal = requestProposals[idx];
                  final category = proposal.categoryNormalized ?? 'General';
                  final statusColor = _getStatusColor(proposal.status);

                  OrderModel? matchingOrder;
                  if (proposal.status == ProposalStatus.accepted) {
                    try {
                      matchingOrder = orders.firstWhere((o) => o.proposalId == proposal.id);
                    } catch (_) {}
                  }
                  final isCompletedOrder = matchingOrder != null &&
                      (matchingOrder!.status == OrderStatus.delivered ||
                          matchingOrder.status == OrderStatus.completed);

                  return SizedBox(
                    width: double.infinity,
                    child: Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: isDark ? Colors.black12 : Colors.grey.shade50,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: isDark ? AppColors.borderDark : AppColors.borderLight),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              category.toUpperCase(),
                              style: AppTextStyles.labelMedium(primaryText).copyWith(fontWeight: FontWeight.bold),
                            ),
                            StatusBadge(
                              label: matchingOrder != null
                                  ? matchingOrder.status.displayName
                                  : proposal.status.displayName,
                              color: matchingOrder != null
                                  ? _getOrderStatusColor(matchingOrder.status)
                                  : statusColor,
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text('Items: ${proposal.items.length}', style: AppTextStyles.caption(secondaryText)),
                                Text(
                                  'Date: ${_formatDateTime(matchingOrder?.createdAt ?? proposal.createdAt)}',
                                  style: AppTextStyles.caption(secondaryText),
                                ),
                                Text(
                                  'Rs. ${proposal.totalPrice.toStringAsFixed(2)}',
                                  style: AppTextStyles.bodyMedium(primaryText).copyWith(fontWeight: FontWeight.bold),
                                ),
                              ],
                            ),
                            Row(children: [
                              if (matchingOrder != null)
                                ElevatedButton.icon(
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: AppColors.vendorColor,
                                    foregroundColor: Colors.white,
                                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                    minimumSize: const Size(0, 36),
                                  ),
                                  onPressed: () => context.push('/vendor/orders/manage', extra: matchingOrder),
                                  icon: Icon(
                                    isCompletedOrder
                                        ? Icons.receipt_long_rounded
                                        : Icons.delivery_dining_rounded,
                                    size: 16,
                                  ),
                                  label: Text(
                                    isCompletedOrder ? 'View Summary' : 'Manage',
                                    style: const TextStyle(fontSize: 11),
                                  ),
                                )
                              else if (proposal.status == ProposalStatus.submitted ||
                                  proposal.status == ProposalStatus.updated) ...[
                                TextButton(
                                  style: TextButton.styleFrom(
                                    foregroundColor: AppColors.vendorColor,
                                    padding: const EdgeInsets.symmetric(horizontal: 8),
                                  ),
                                  onPressed: () async {
                                    final req = await MockRequestRepository.instance.getRequestById(requestId);
                                    if (req != null && context.mounted) {
                                      context.push('/vendor/proposals/edit', extra: {'proposal': proposal, 'request': req});
                                    }
                                  },
                                  child: const Text('Edit', style: TextStyle(fontSize: 12)),
                                ),
                                TextButton(
                                  style: TextButton.styleFrom(
                                    foregroundColor: AppColors.error,
                                    padding: const EdgeInsets.symmetric(horizontal: 8),
                                  ),
                                  onPressed: () async {
                                    final confirm = await showDialog<bool>(
                                      context: context,
                                      builder: (ctx) => AlertDialog(
                                        title: const Text('Withdraw Bid?'),
                                        content: const Text('This will remove your proposal for this category.'),
                                        actions: [
                                          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
                                          TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Withdraw')),
                                        ],
                                      ),
                                    );
                                    if (confirm == true && context.mounted) {
                                      await ref.read(proposalProvider.notifier).withdrawProposal(proposal.id);
                                    }
                                  },
                                  child: const Text('Withdraw', style: TextStyle(fontSize: 12)),
                                ),
                              ] else
                                TextButton(
                                  style: TextButton.styleFrom(foregroundColor: secondaryText),
                                  onPressed: () => context.push('/vendor/proposals/detail', extra: proposal),
                                  child: const Text('Details', style: TextStyle(fontSize: 12)),
                                ),
                            ]),
                          ],
                        ),
                      ],
                    ),
                  ),
                  );
                },
              ),
            ],
          ),
        );
      },
    );
  }

  // ── FLAT LIST view ─────────────────────────────────────────────────────────
  Widget _buildFlatView(List<Proposal> proposals, Color primaryText, Color secondaryText) {
    return ListView.builder(
      padding: EdgeInsets.fromLTRB(AppSpacing.md, 0, AppSpacing.md, 100),
      itemCount: proposals.length,
      itemBuilder: (context, index) {
        final proposal = proposals[index];
        final statusColor = _getStatusColor(proposal.status);
        final availableCount = proposal.items.where((i) => i.status == ProposalItemStatus.available).length;
        final altCount = proposal.items.where((i) => i.status == ProposalItemStatus.alternative).length;
        final missingCount = proposal.items.where((i) => i.status == ProposalItemStatus.unavailable).length;

        return Material(
          color: Colors.transparent,
          child: InkWell(
            borderRadius: BorderRadius.circular(AppRadius.lg),
            onTap: () => context.push('/vendor/proposals/detail', extra: proposal),
            child: Theme3AppCard(
              margin: EdgeInsets.only(bottom: AppSpacing.sm),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text('BID: ${proposal.id}', style: AppTextStyles.subtitle(primaryText)),
                      StatusBadge(label: proposal.status.displayName, color: statusColor),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text('Request: ${proposal.requestId}', style: AppTextStyles.bodySmall(secondaryText)),
                  if ((proposal.categoryNormalized ?? '').isNotEmpty)
                    Text('Category: ${proposal.categoryNormalized}', style: AppTextStyles.caption(secondaryText)),
                  Text(
                    'Date: ${_formatDateTime(proposal.createdAt)}',
                    style: AppTextStyles.caption(secondaryText),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Summary: $availableCount available, $altCount alternatives, $missingCount missing.',
                    style: AppTextStyles.caption(secondaryText),
                  ),
                  const Divider(height: 16),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Text('Delivery Time:', style: AppTextStyles.caption(secondaryText)),
                        Text(proposal.estimatedDeliveryTime, style: AppTextStyles.bodyMedium(primaryText)),
                      ]),
                      Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
                        Text('Total Bid:', style: AppTextStyles.caption(secondaryText)),
                        Text('Rs. ${proposal.totalPrice.toStringAsFixed(2)}',
                            style: AppTextStyles.subtitle(AppColors.vendorColor)),
                      ]),
                    ],
                  ),
                  if (proposal.status == ProposalStatus.rejected && proposal.rejectionReason != null) ...[
                    const SizedBox(height: 12),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: AppColors.error.withValues(alpha: 0.08),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Row(children: [
                        const Icon(Icons.info_outline, color: AppColors.error, size: 18),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text('Rejection Reason: ${proposal.rejectionReason}',
                              style: AppTextStyles.caption(AppColors.error)),
                        ),
                      ]),
                    ),
                  ],
                  if (proposal.customerResponse != null || proposal.vendorResponse != null) ...[
                    const SizedBox(height: 12),
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: isDark ? Colors.black26 : Colors.grey.shade100,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Message Log:', style: AppTextStyles.caption(secondaryText)),
                          const SizedBox(height: 8),
                          if (proposal.customerResponse != null)
                            Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                              Icon(Icons.person_outline, size: 16, color: primaryText),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text('Customer: ${proposal.customerResponse ?? ''}',
                                    style: AppTextStyles.bodySmall(primaryText)),
                              ),
                            ]),
                          if (proposal.vendorResponse != null) ...[
                            const SizedBox(height: 8),
                            Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                              const Icon(Icons.check_circle_outline, size: 16, color: AppColors.vendorColor),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text('You: ${proposal.vendorResponse ?? ''}',
                                    style: AppTextStyles.bodySmall(AppColors.vendorColor)),
                              ),
                            ]),
                          ],
                        ],
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}
class _DashboardHeroBanner extends StatelessWidget {
  const _DashboardHeroBanner({
    required this.user,
    required this.paidEarnings,
    required this.pendingEarnings,
    required this.grossPaidEarnings,
    required this.grossPendingEarnings,
    required this.commissionOwed,
    required this.isDark,
  });

  final dynamic user;
  final double paidEarnings;
  final double pendingEarnings;
  final double grossPaidEarnings;
  final double grossPendingEarnings;
  final double commissionOwed;
  final bool isDark;

  @override
  Widget build(BuildContext context) {
    final total = paidEarnings + pendingEarnings;
    final grossTotal = grossPaidEarnings + grossPendingEarnings;

    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            AppColors.vendorColor,
            AppColors.vendorColor.withValues(alpha: 0.82),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(AppRadius.xl),
        boxShadow: [
          BoxShadow(
            color: AppColors.vendorColor.withValues(alpha: 0.25),
            blurRadius: 18,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.18),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: const Icon(Icons.storefront_rounded, color: Colors.white),
              ),
              SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      user?.businessName ?? 'Your Shop',
                      style: AppTextStyles.h2(Colors.white),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    Text(
                      'Shop Owner dashboard',
                      style: AppTextStyles.bodySmall(Colors.white70),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.16),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.circle, size: 8, color: AppColors.success),
                    SizedBox(width: AppSpacing.xs),
                    Text(
                      'Live',
                      style: AppTextStyles.caption(Colors.white)
                          .copyWith(fontWeight: FontWeight.w600),
                    ),
                  ],
                ),
              ),
            ],
          ),
          SizedBox(height: AppSpacing.lg),
          Text(
            'Estimated payout',
            style: AppTextStyles.bodySmall(Colors.white70),
          ),
          SizedBox(height: AppSpacing.xs),
          Text(
            'Rs. ${total.toStringAsFixed(0)}',
            style: AppTextStyles.display1(Colors.white).copyWith(fontSize: 30),
          ),
          SizedBox(height: AppSpacing.md),
          Text(
            'Gross sales: Rs. ${grossTotal.toStringAsFixed(0)}',
            style: AppTextStyles.caption(Colors.white70),
          ),
          SizedBox(height: AppSpacing.sm),
          Row(
            children: [
              Expanded(
                child: _HeroEarningsPill(
                  label: 'Paid',
                  value: paidEarnings,
                ),
              ),
              SizedBox(width: AppSpacing.sm),
              Expanded(
                child: _HeroEarningsPill(
                  label: 'Pending',
                  value: pendingEarnings,
                ),
              ),
              SizedBox(width: AppSpacing.sm),
              Expanded(
                child: _HeroEarningsPill(
                  label: 'Commission',
                  value: commissionOwed,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _HeroEarningsPill extends StatelessWidget {
  const _HeroEarningsPill({required this.label, required this.value});

  final String label;
  final double value;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: AppSpacing.sm,
        vertical: AppSpacing.sm,
      ),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(AppRadius.md),
        border: Border.all(color: Colors.white24),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: AppTextStyles.caption(Colors.white70)),
          SizedBox(height: AppSpacing.xs),
          Text(
            'Rs. ${value.toStringAsFixed(0)}',
            style: AppTextStyles.subtitle(Colors.white)
                .copyWith(fontWeight: FontWeight.w700),
          ),
        ],
      ),
    );
  }
}

class _DashboardMetricTile extends StatelessWidget {
  const _DashboardMetricTile({
    required this.label,
    required this.value,
    required this.icon,
    required this.color,
    required this.isDark,
  });

  final String label;
  final String value;
  final IconData icon;
  final Color color;
  final bool isDark;

  @override
  Widget build(BuildContext context) {
    final primaryText =
        isDark ? AppColors.textPrimaryDark : AppColors.textPrimaryLight;
    final secondaryText =
        isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight;

    return Container(
      width: 128,
      padding: EdgeInsets.all(AppSpacing.sm),
      decoration: BoxDecoration(
        color: isDark ? AppColors.cardDark : AppColors.cardLight,
        borderRadius: BorderRadius.circular(AppRadius.lg),
        border: Border.all(
          color: isDark ? AppColors.borderDark : AppColors.borderLight,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 30,
            height: 30,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: color, size: 16),
          ),
          SizedBox(height: AppSpacing.sm),
          Text(
            value,
            style: AppTextStyles.h2(primaryText).copyWith(fontSize: 18),
          ),
          SizedBox(height: 2),
          Text(
            label,
            style: AppTextStyles.caption(secondaryText),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }
}

class _DashboardQuickAction extends StatelessWidget {
  const _DashboardQuickAction({
    required this.label,
    required this.icon,
    required this.color,
    required this.isDark,
    required this.onTap,
    this.badgeCount,
  });

  final String label;
  final IconData icon;
  final Color color;
  final bool isDark;
  final VoidCallback onTap;
  final int? badgeCount;

  @override
  Widget build(BuildContext context) {
    final primaryText =
        isDark ? AppColors.textPrimaryDark : AppColors.textPrimaryLight;

    return SizedBox(
      width: 108,
      child: Material(
        color: isDark ? AppColors.cardDark : AppColors.cardLight,
        borderRadius: BorderRadius.circular(AppRadius.lg),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(AppRadius.lg),
          child: Container(
            padding: EdgeInsets.symmetric(
              horizontal: AppSpacing.sm,
              vertical: AppSpacing.md,
            ),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(AppRadius.lg),
              border: Border.all(
                color: isDark ? AppColors.borderDark : AppColors.borderLight,
              ),
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Stack(
                  clipBehavior: Clip.none,
                  children: [
                    Container(
                      width: 38,
                      height: 38,
                      decoration: BoxDecoration(
                        color: color.withValues(alpha: 0.12),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(icon, color: color, size: 20),
                    ),
                    if (badgeCount != null && badgeCount! > 0)
                      Positioned(
                        top: -4,
                        right: -4,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 5,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: color,
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Text(
                            badgeCount! > 99 ? '99+' : '$badgeCount',
                            style: AppTextStyles.caption(Colors.white)
                                .copyWith(
                                  fontSize: 9,
                                  fontWeight: FontWeight.w700,
                                ),
                          ),
                        ),
                      ),
                  ],
                ),
                SizedBox(height: AppSpacing.sm),
                Text(
                  label,
                  style: AppTextStyles.caption(primaryText)
                      .copyWith(fontWeight: FontWeight.w600),
                  textAlign: TextAlign.center,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _DashboardSectionHeader extends StatelessWidget {
  const _DashboardSectionHeader({
    required this.title,
    required this.subtitle,
    required this.primaryText,
    required this.secondaryText,
  });

  final String title;
  final String subtitle;
  final Color primaryText;
  final Color secondaryText;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: AppTextStyles.h2(primaryText)),
              SizedBox(height: AppSpacing.xs),
              Text(subtitle, style: AppTextStyles.bodySmall(secondaryText)),
            ],
          ),
        ),
      ],
    );
  }
}

List<String> _collectVendorAcceptedImages(OrderModel order) {
  final images = <String>[];
  for (final item in order.items) {
    for (final url in item.vendorImageUrls) {
      final trimmed = url.trim();
      if (trimmed.isNotEmpty && !images.contains(trimmed)) {
        images.add(trimmed);
      }
    }
    final primary = item.imageUrl?.trim() ?? '';
    if (primary.isNotEmpty && !images.contains(primary)) {
      images.add(primary);
    }
  }
  return images;
}

List<String> _collectCustomerRequestImages(ShoppingRequest? request) {
  final images = <String>[];
  if (request == null) return images;
  for (final item in request.items) {
    for (final url in item.imageUrls) {
      final trimmed = url.trim();
      if (trimmed.isNotEmpty && !images.contains(trimmed)) {
        images.add(trimmed);
      }
    }
  }
  return images;
}

class _DashboardOrderCarousel extends StatefulWidget {
  const _DashboardOrderCarousel({
    required this.order,
    required this.accentColor,
  });

  final OrderModel order;
  final Color accentColor;

  @override
  State<_DashboardOrderCarousel> createState() => _DashboardOrderCarouselState();
}

class _DashboardOrderCarouselState extends State<_DashboardOrderCarousel> {
  static const _size = 64.0;
  List<String> _images = const [];

  @override
  void initState() {
    super.initState();
    _loadImages();
  }

  @override
  void didUpdateWidget(_DashboardOrderCarousel oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.order.id != widget.order.id) {
      _loadImages();
    }
  }

  Future<void> _loadImages() async {
    final vendorImages = _collectVendorAcceptedImages(widget.order);
    if (vendorImages.isNotEmpty) {
      if (mounted) setState(() => _images = vendorImages);
      return;
    }

    final request =
        await MockRequestRepository.instance.getRequestById(widget.order.requestId);
    if (!mounted) return;
    setState(() => _images = _collectCustomerRequestImages(request));
  }

  Widget _buildFallback() {
    return Container(
      width: _size,
      height: _size,
      decoration: BoxDecoration(
        color: widget.accentColor.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(AppRadius.md),
        border: Border.all(
          color: widget.accentColor.withValues(alpha: 0.35),
          width: 1,
        ),
      ),
      child: Icon(
        Icons.local_shipping_rounded,
        color: widget.accentColor,
        size: _size * 0.47,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return RequestImageCarousel(
      images: _images,
      fallback: _buildFallback(),
      size: _size,
    );
  }
}

class _DashboardOrderCard extends StatelessWidget {
  const _DashboardOrderCard({
    required this.order,
    required this.isDark,
    required this.primaryText,
    required this.secondaryText,
    required this.accentColor,
    required this.onManage,
    this.isMultipleOrders = false,
  });

  final OrderModel order;
  final bool isDark;
  final Color primaryText;
  final Color secondaryText;
  final Color accentColor;
  final VoidCallback onManage;
  final bool isMultipleOrders;

  @override
  Widget build(BuildContext context) {
    final hasMultipleItems = order.items.length > 1;

    return Container(
      margin: EdgeInsets.only(bottom: AppSpacing.sm),
      decoration: BoxDecoration(
        color: isDark ? AppColors.cardDark : AppColors.cardLight,
        borderRadius: BorderRadius.circular(AppRadius.lg),
        border: Border.all(
          color: isDark ? AppColors.borderDark : AppColors.borderLight,
        ),
      ),
      child: Padding(
        padding: EdgeInsets.all(AppSpacing.md),
        child: Row(
          children: [
            _DashboardOrderCarousel(
              order: order,
              accentColor: accentColor,
            ),
            SizedBox(width: AppSpacing.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          order.id,
                          style: AppTextStyles.subtitle(primaryText),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      if (isMultipleOrders) ...[
                        const SizedBox(width: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 6,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: accentColor.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            'Multi',
                            style: AppTextStyles.caption(accentColor).copyWith(
                              fontSize: 9,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                  SizedBox(height: AppSpacing.xs),
                  Text(
                    order.customerName,
                    style: AppTextStyles.bodySmall(secondaryText),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  if (hasMultipleItems) ...[
                    SizedBox(height: AppSpacing.xs),
                    Text(
                      '${order.items.length} items',
                      style: AppTextStyles.caption(secondaryText),
                    ),
                  ],
                  SizedBox(height: AppSpacing.xs),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: accentColor.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      order.status.displayName,
                      style: AppTextStyles.caption(accentColor)
                          .copyWith(fontWeight: FontWeight.w600),
                    ),
                  ),
                ],
              ),
            ),
            SizedBox(width: AppSpacing.sm),
            TextButton(
              onPressed: onManage,
              style: TextButton.styleFrom(
                backgroundColor: accentColor,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 10,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(AppRadius.md),
                ),
                minimumSize: const Size(0, 36),
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
              child: const Text('Manage'),
            ),
          ],
        ),
      ),
    );
  }
}

class _DashboardCompletedOrderCard extends StatelessWidget {
  const _DashboardCompletedOrderCard({
    required this.order,
    required this.isDark,
    required this.primaryText,
    required this.secondaryText,
  });

  final OrderModel order;
  final bool isDark;
  final Color primaryText;
  final Color secondaryText;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: EdgeInsets.only(bottom: AppSpacing.sm),
      padding: EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: isDark ? AppColors.surfaceElevatedDark : const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(AppRadius.lg),
        border: Border.all(
          color: isDark ? AppColors.borderDark : AppColors.borderLight,
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: AppColors.success.withValues(alpha: 0.12),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.check_rounded, color: AppColors.success, size: 22),
          ),
          SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(order.id, style: AppTextStyles.subtitle(primaryText)),
                Text(
                  order.customerName,
                  style: AppTextStyles.bodySmall(secondaryText),
                ),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                'Rs. ${order.totalPrice.toStringAsFixed(0)}',
                style: AppTextStyles.labelMedium(AppColors.success)
                    .copyWith(fontWeight: FontWeight.w700),
              ),
              Text('Earned', style: AppTextStyles.caption(secondaryText)),
            ],
          ),
        ],
      ),
    );
  }
}

class _PendingApprovalView extends StatelessWidget {
  const _PendingApprovalView({required this.isDark});
  final bool isDark;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: EdgeInsets.all(AppSpacing.xxl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 90,
              height: 90,
              decoration: BoxDecoration(
                color: AppColors.warning.withValues(alpha: 0.12),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.hourglass_top_rounded,
                  color: AppColors.warning, size: 42),
            ),
            SizedBox(height: AppSpacing.lg),
            Text('Pending Approval',
                style: AppTextStyles.h1(isDark
                    ? AppColors.textPrimaryDark
                    : AppColors.textPrimaryLight)),
            SizedBox(height: AppSpacing.sm),
            Text(
              'Your shop owner account is under review. You will be notified once approved.',
              style: AppTextStyles.bodyMedium(isDark
                  ? AppColors.textSecondaryDark
                  : AppColors.textSecondaryLight),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}

enum _WalletWeekRange { currentWeek, lastWeek }

class _VendorWalletTab extends ConsumerStatefulWidget {
  const _VendorWalletTab();

  @override
  ConsumerState<_VendorWalletTab> createState() => _VendorWalletTabState();
}

class _VendorWalletTabState extends ConsumerState<_VendorWalletTab> {
  _WalletWeekRange _selectedWeekRange = _WalletWeekRange.currentWeek;
  final List<Map<String, dynamic>> _mockPayouts = [
    {
      'date': 'May 18, 2026',
      'ref': '#SL-883A',
      'payout': 14250.0,
      'comm': 427.50,
      'net': 13822.50,
      'bank': 'Commercial Bank - Account ****4892',
      'status': 'Settled to Bank'
    },
    {
      'date': 'May 15, 2026',
      'ref': '#SL-92B4',
      'payout': 9800.0,
      'comm': 294.00,
      'net': 9506.00,
      'bank': 'Commercial Bank - Account ****4892',
      'status': 'Settled to Bank'
    },
    {
      'date': 'May 10, 2026',
      'ref': '#SL-76C1',
      'payout': 22500.0,
      'comm': 675.00,
      'net': 21825.00,
      'bank': 'Commercial Bank - Account ****4892',
      'status': 'Settled to Bank'
    }
  ];

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primaryText =
        isDark ? AppColors.textPrimaryDark : AppColors.textPrimaryLight;
    final secondaryText =
        isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight;
    final cardColor = isDark ? AppColors.cardDark : AppColors.cardLight;
    final borderColor = isDark ? AppColors.borderDark : AppColors.borderLight;
    
    

    final orderState = ref.watch(orderProvider);
    // Include all active vendor orders except cancelled ones.
    // This keeps the wallet ledger in sync with live order activity.
    final walletOrders = orderState.orders
        .where((o) => o.status != OrderStatus.cancelled)
        .toList();

    // Platform commission is folded into the customer-facing proposal total.
    // The vendor net is the item subtotal plus delivery fee.
    final double liveGrossRevenue =
        walletOrders.fold<double>(0, (sum, o) => sum + o.totalPrice);
    final double liveCommission = walletOrders.fold<double>(
        0, (sum, o) => sum + o.platformCommission);
    final double liveNetEarnings = walletOrders.fold<double>(
        0, (sum, o) => sum + o.vendorNetAmount);

    final double totalHistoricGross =
        _mockPayouts.fold<double>(0.0, (sum, p) => sum + p['payout']);
    final double totalHistoricComm =
        _mockPayouts.fold<double>(0.0, (sum, p) => sum + p['comm']);
    final double totalHistoricNet =
        _mockPayouts.fold<double>(0.0, (sum, p) => sum + p['net']);

    final weeklySales = <String, double>{
      'Mon': 0,
      'Tue': 0,
      'Wed': 0,
      'Thu': 0,
      'Fri': 0,
      'Sat': 0,
      'Sun': 0,
    };
    final now = DateTime.now();
    final startOfCurrentWeek = DateTime(now.year, now.month, now.day)
        .subtract(Duration(days: now.weekday - 1));
    final startOfLastWeek = startOfCurrentWeek.subtract(const Duration(days: 7));
    final selectedStartOfWeek = _selectedWeekRange == _WalletWeekRange.currentWeek
        ? startOfCurrentWeek
        : startOfLastWeek;
    final selectedEndOfWeek = selectedStartOfWeek.add(const Duration(days: 7));

    for (final order in walletOrders) {
      final orderDate = DateTime(
        order.createdAt.year,
        order.createdAt.month,
        order.createdAt.day,
      );
      if (orderDate.isBefore(selectedStartOfWeek) || !orderDate.isBefore(selectedEndOfWeek)) {
        continue;
      }
      final day = const ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun']
          [order.createdAt.weekday - 1];
      weeklySales[day] = weeklySales[day]! + order.totalPrice;
    }

    final double currentWeekMax = weeklySales.values.fold<double>(0.0,
        (maxValue, dailyValue) => dailyValue > maxValue ? dailyValue : maxValue);
    final double weeklyChartMax = currentWeekMax > 0 ? currentWeekMax : 1.0;
    final bool hasWeeklySales = weeklySales.values.any((value) => value > 0);

    final double cumulativeGross = liveGrossRevenue + totalHistoricGross;
    final double cumulativeCommission = liveCommission + totalHistoricComm;
    final double cumulativeNet = liveNetEarnings + totalHistoricNet;

    return RefreshIndicator(
      onRefresh: () async {
        await ref.read(orderProvider.notifier).loadVendorOrders();
      },
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 100),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.account_balance_wallet_rounded,
                    color: AppColors.vendorColor, size: 28),
                const SizedBox(width: 10),
                Text('Shop Owner LKR Wallet', style: AppTextStyles.h1(primaryText)),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              'Real-time earnings ledger — customer quote totals are shown as your sales amount. Hidden platform commission is calculated separately from item subtotal.',
              style: AppTextStyles.bodyMedium(secondaryText),
            ),
            const SizedBox(height: 24),
            Material(
              color: Colors.transparent,
              child: InkWell(
                borderRadius: BorderRadius.circular(20),
                onTap: () => _showEarningsSummary(context, cumulativeGross, cumulativeCommission, cumulativeNet),
                child: Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [AppColors.vendorColor, AppColors.vendorColorDark],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(20),
                    boxShadow: [
                      BoxShadow(
                        color: AppColors.vendorColor.withValues(alpha: 0.25),
                        blurRadius: 15,
                        offset: const Offset(0, 8),
                      )
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text('Cumulative Net Earnings',
                              style: AppTextStyles.caption(Colors.white70)
                                  .copyWith(fontWeight: FontWeight.bold)),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Rs. ${cumulativeNet.toStringAsFixed(2)}',
                        style: AppTextStyles.h1(Colors.white)
                            .copyWith(fontSize: 32, letterSpacing: -0.5),
                      ),
                      const SizedBox(height: 16),
                      const Divider(color: Colors.white30, height: 1),
                      const SizedBox(height: 16),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('Gross Sales',
                                  style: AppTextStyles.caption(Colors.white60)),
                              const SizedBox(height: 4),
                              Text('Rs. ${cumulativeGross.toStringAsFixed(0)}',
                                  style: AppTextStyles.bodyLarge(Colors.white)
                                      .copyWith(fontWeight: FontWeight.bold)),
                            ],
                          ),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('Commission Owed',
                                  style: AppTextStyles.caption(Colors.white60)),
                              const SizedBox(height: 4),
                              Text('Rs. ${cumulativeCommission.toStringAsFixed(0)}',
                                  style: AppTextStyles.bodyLarge(Colors.amber)
                                      .copyWith(fontWeight: FontWeight.bold)),
                            ],
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
            const SizedBox(height: 28),
            Text('Weekly Sales Distribution', style: AppTextStyles.h2(primaryText)),
            const SizedBox(height: 12),
            Align(
              alignment: Alignment.centerLeft,
              child: ToggleButtons(
                isSelected: [
                  _selectedWeekRange == _WalletWeekRange.currentWeek,
                  _selectedWeekRange == _WalletWeekRange.lastWeek,
                ],
                onPressed: (index) {
                  setState(() {
                    _selectedWeekRange = index == 0
                        ? _WalletWeekRange.currentWeek
                        : _WalletWeekRange.lastWeek;
                  });
                },
                borderRadius: BorderRadius.circular(12),
                selectedColor: Colors.white,
                fillColor: AppColors.vendorColor,
                color: isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight,
                borderColor: borderColor,
                selectedBorderColor: AppColors.vendorColor,
                children: const [
                  Padding(
                    padding: EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                    child: Text('This Week'),
                  ),
                  Padding(
                    padding: EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                    child: Text('Last Week'),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 14),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: cardColor,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: borderColor),
              ),
              child: Column(
                children: [
                  if (!hasWeeklySales)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 24.0),
                      child: Text(
                        _selectedWeekRange == _WalletWeekRange.currentWeek
                            ? 'No sales recorded for this week yet.'
                            : 'No sales recorded for last week.',
                        style: AppTextStyles.bodyMedium(
                          isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    )
                  else ...[
                    _buildChartBar('Mon', weeklySales['Mon']!, weeklyChartMax, isDark),
                    _buildChartBar('Tue', weeklySales['Tue']!, weeklyChartMax, isDark),
                    _buildChartBar('Wed', weeklySales['Wed']!, weeklyChartMax, isDark),
                    _buildChartBar('Thu', weeklySales['Thu']!, weeklyChartMax, isDark),
                    _buildChartBar('Fri', weeklySales['Fri']!, weeklyChartMax, isDark),
                    _buildChartBar('Sat', weeklySales['Sat']!, weeklyChartMax, isDark),
                    _buildChartBar('Sun', weeklySales['Sun']!, weeklyChartMax, isDark),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 28),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('Earnings Settlement Log',
                    style: AppTextStyles.h2(primaryText)),
                const Icon(Icons.history_toggle_off_rounded,
                    color: AppColors.vendorColor, size: 20),
              ],
            ),
            const SizedBox(height: 12),
            if (walletOrders.isNotEmpty) ...[
              ...walletOrders.map((order) {
                final orderGross = order.totalPrice;
                final orderComm = order.platformCommission;
                final orderNet = order.vendorNetAmount;

                final isCod = order.paymentStatus == PaymentStatus.pendingOnDelivery;
                final isSettledOrder = order.status == OrderStatus.delivered || order.status == OrderStatus.completed;
                final settlementLabel = isSettledOrder
                    ? (isCod ? 'COD – Settled after delivery' : 'Settled (Online)')
                    : (isCod ? 'COD – Pending delivery' : 'Pending settlement');
                final settlementColor = isSettledOrder ? AppColors.success : AppColors.warning;

                return Material(
                  color: Colors.transparent,
                  child: InkWell(
                    borderRadius: BorderRadius.circular(14),
                    onTap: () => _showOrderSettlementSummary(context, order),
                    child: Container(
                      margin: const EdgeInsets.only(bottom: 12),
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: cardColor,
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(
                            color: AppColors.vendorColor.withValues(alpha: 0.3),
                            width: 1.2),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Expanded(
                                child: Text('Order: ${order.id}',
                                    style: AppTextStyles.bodyMedium(primaryText)
                                        .copyWith(fontWeight: FontWeight.bold),
                                    overflow: TextOverflow.ellipsis),
                              ),
                              const SizedBox(width: 8),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 8, vertical: 3),
                                decoration: BoxDecoration(
                                  color: settlementColor.withValues(alpha: 0.12),
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: Text(
                                  settlementLabel,
                                  style: AppTextStyles.caption(settlementColor)
                                      .copyWith(
                                          fontWeight: FontWeight.bold,
                                          fontSize: 10),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text('Customer: ${order.customerName}',
                                  style: AppTextStyles.caption(secondaryText)),
                              Text(
                                order.updatedAt != null
                                    ? '${order.updatedAt!.day}/${order.updatedAt!.month}/${order.updatedAt!.year}'
                                    : '${order.createdAt.day}/${order.createdAt.month}/${order.createdAt.year}',
                                style: AppTextStyles.caption(secondaryText)),
                            ],
                          ),
                          const Divider(height: 16),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Expanded(
                                child: Text('Sales: Rs. ${orderGross.toStringAsFixed(0)}',
                                    style: AppTextStyles.bodySmall(secondaryText)),
                              ),
                              Expanded(
                                child: Text('Comm: Rs. ${orderComm.toStringAsFixed(0)}',
                                    style: AppTextStyles.bodySmall(secondaryText)),
                              ),
                              Expanded(
                                child: Text('Net: Rs. ${orderNet.toStringAsFixed(2)}',
                                    textAlign: TextAlign.end,
                                    style: AppTextStyles.bodyMedium(AppColors.success)
                                        .copyWith(fontWeight: FontWeight.bold)),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              }),
            ],
            ..._mockPayouts.map((payout) {
              return Container(
                margin: const EdgeInsets.only(bottom: 12),
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: cardColor,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: borderColor),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text('Order Reference: ${payout['ref']}',
                            style: AppTextStyles.bodyMedium(primaryText)
                                .copyWith(fontWeight: FontWeight.bold)),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: AppColors.success.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            'Settled to Bank',
                            style: AppTextStyles.caption(AppColors.success)
                                .copyWith(
                                    fontWeight: FontWeight.bold, fontSize: 10),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(payout['bank']!,
                            style: AppTextStyles.caption(secondaryText)),
                        Text(payout['date']!,
                            style: AppTextStyles.caption(secondaryText)),
                      ],
                    ),
                    const Divider(height: 16),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                            'Sales: Rs. ${payout['payout'].toStringAsFixed(0)}',
                            style: AppTextStyles.bodySmall(secondaryText)),
                        Text(
                            'Comm (${(payout['comm'] as double) == 0 ? '0%' : '3%'}): Rs. ${(payout['comm'] as double).toStringAsFixed(0)}',
                            style: AppTextStyles.bodySmall(secondaryText)),
                        Text('Net: Rs. ${(payout['net'] as double).toStringAsFixed(2)}',
                            style: AppTextStyles.bodyMedium(primaryText)
                                .copyWith(fontWeight: FontWeight.bold)),
                      ],
                    ),
                  ],
                ),
              );
            }),
            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }

  Widget _buildChartBar(
      String day, double value, double cumulativeMax, bool isDark) {
    final primaryText = isDark ? Colors.white : Colors.black;
    final secondaryText =
        isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight;
    final maxReference = cumulativeMax > 0 ? cumulativeMax : 1.0;
    final double pct = (value / maxReference).clamp(0.0, 1.0);

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6.0),
      child: Row(
        children: [
          SizedBox(
              width: 40,
              child: Text(day,
                  style: AppTextStyles.bodySmall(primaryText)
                      .copyWith(fontWeight: FontWeight.bold))),
          Expanded(
            child: Container(
              height: 10,
              decoration: BoxDecoration(
                color: isDark ? Colors.grey[850] : Colors.grey[200],
                borderRadius: BorderRadius.circular(5),
              ),
              child: FractionallySizedBox(
                alignment: Alignment.centerLeft,
                widthFactor: pct,
                child: Container(
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [AppColors.vendorColor, AppColors.success],
                    ),
                    borderRadius: BorderRadius.circular(5),
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),
          SizedBox(
            width: 70,
            child: Text(
              value > 0 ? 'Rs. ${value.toStringAsFixed(0)}' : '-',
              style: AppTextStyles.bodySmall(secondaryText),
              textAlign: TextAlign.end,
            ),
          ),
        ],
      ),
    );
  }

  void _showEarningsSummary(
    BuildContext context,
    double gross,
    double commission,
    double net,
  ) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) {
        final theme = Theme.of(context);
        return Padding(
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(context).viewInsets.bottom,
          ),
          child: Container(
            padding: const EdgeInsets.fromLTRB(24, 24, 24, 28),
            decoration: BoxDecoration(
              color: theme.scaffoldBackgroundColor,
              borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: 45,
                    height: 5,
                    decoration: BoxDecoration(
                      color: Colors.grey.shade400,
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
                const SizedBox(height: 20),
                Text('Earnings Summary',
                    style: AppTextStyles.h2(theme.colorScheme.onBackground)),
                const SizedBox(height: 10),
                Text(
                  'Tap any settlement row to see a detailed breakdown of that order.',
                  style: AppTextStyles.bodyMedium(AppColors.textSecondaryLight),
                ),
                const SizedBox(height: 20),
                _buildSummaryRow('Gross Sales', 'Rs. ${gross.toStringAsFixed(2)}'),
                _buildSummaryRow('Platform Commission', 'Rs. ${commission.toStringAsFixed(2)}'),
                const Divider(height: 32),
                _buildSummaryRow(
                  'Vendor Net Earnings',
                  'Rs. ${net.toStringAsFixed(2)}',
                  valueColor: AppColors.success,
                ),
                const SizedBox(height: 8),
                Text(
                  'Net earnings exclude commission and represent the amount available to your wallet.',
                  style: AppTextStyles.caption(AppColors.textSecondaryLight),
                ),
                const SizedBox(height: 18),
              ],
            ),
          ),
        );
      },
    );
  }

  void _showOrderSettlementSummary(BuildContext context, OrderModel order) {
    final bool isCod = order.paymentStatus == PaymentStatus.pendingOnDelivery;
    final bool isSettledOrder = order.status == OrderStatus.delivered || order.status == OrderStatus.completed;
    final String statusLabel = isSettledOrder
        ? (isCod ? 'COD – Settled after delivery' : 'Settled (Online)')
        : (isCod ? 'COD – Pending delivery' : 'Pending settlement');
    final parentContext = context;

    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (sheetContext) {
        final theme = Theme.of(sheetContext);
        return Padding(
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(sheetContext).viewInsets.bottom,
          ),
          child: Container(
            padding: const EdgeInsets.fromLTRB(24, 24, 24, 28),
            decoration: BoxDecoration(
              color: theme.scaffoldBackgroundColor,
              borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: 45,
                    height: 5,
                    decoration: BoxDecoration(
                      color: Colors.grey.shade400,
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
                const SizedBox(height: 20),
                Text('Order Settlement',
                    style: AppTextStyles.h2(theme.colorScheme.onBackground)),
                const SizedBox(height: 8),
                Text('Order ID: ${order.id}',
                    style: AppTextStyles.bodyMedium(AppColors.textSecondaryLight)),
                const SizedBox(height: 12),
                Text('Product IDs',
                    style: AppTextStyles.labelSmall(AppColors.textSecondaryLight)),
                const SizedBox(height: 8),
                if (order.items.isNotEmpty)
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: order.items.map((item) {
                      final productId = item.id.toString();
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 8.0),
                        child: Material(
                          color: Colors.transparent,
                          child: InkWell(
                            borderRadius: BorderRadius.circular(12),
                            onTap: () async {
                              await Clipboard.setData(ClipboardData(text: productId));
                              if (!mounted) return;
                              ref.read(notificationProvider.notifier).triggerNotification(
                                title: 'Copied',
                                body: 'Product ID copied',
                                icon: Icons.copy_rounded,
                                color: AppColors.vendorColor,
                              );
                            },
                            child: Container(
                              width: double.infinity,
                              padding: const EdgeInsets.symmetric(
                                vertical: 10,
                                horizontal: 14,
                              ),
                              decoration: BoxDecoration(
                                color: theme.colorScheme.surfaceVariant.withOpacity(0.14),
                                border: Border.all(
                                  color: theme.colorScheme.onSurface.withOpacity(0.16),
                                ),
                                borderRadius: BorderRadius.circular(14),
                              ),
                              child: Row(
                                children: [
                                  Expanded(
                                    child: Text(
                                      productId,
                                      style: AppTextStyles.bodyMedium(theme.colorScheme.onBackground),
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Icon(
                                    Icons.copy_rounded,
                                    size: 18,
                                    color: theme.colorScheme.onBackground.withOpacity(0.72),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      );
                    }).toList(),
                  )
                else
                  Text('N/A', style: AppTextStyles.bodyMedium(AppColors.textSecondaryLight)),
                const SizedBox(height: 16),
                _buildSummaryRow('Customer', order.customerName),
                _buildSummaryRow('Order Date',
                    '${order.createdAt.day}/${order.createdAt.month}/${order.createdAt.year}'),
                _buildSummaryRow('Status', statusLabel,
                    valueColor: isSettledOrder ? AppColors.success : AppColors.warning),
                const Divider(height: 32),
                _buildSummaryRow('Sales', 'Rs. ${order.totalPrice.toStringAsFixed(2)}'),
                _buildSummaryRow('Commission', 'Rs. ${order.platformCommission.toStringAsFixed(2)}'),
                _buildSummaryRow('Net to Vendor', 'Rs. ${order.vendorNetAmount.toStringAsFixed(2)}',
                    valueColor: AppColors.success),
                if (order.deliveryCharge > 0) ...[
                  const SizedBox(height: 12),
                  _buildSummaryRow('Delivery Fee', 'Rs. ${order.deliveryCharge.toStringAsFixed(2)}'),
                ],
                const SizedBox(height: 8),
                Text(
                  'This summary separates your gross sales, platform commission, and net earnings. Delivery fee is shown separately for transparency.',
                  style: AppTextStyles.caption(AppColors.textSecondaryLight),
                ),
                const SizedBox(height: 18),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildSummaryRow(String label, String value, {Color? valueColor}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(
            child: Text(label,
                style: AppTextStyles.bodyMedium(AppColors.textSecondaryLight)),
          ),
          const SizedBox(width: 12),
          Text(value,
              style: AppTextStyles.bodyMedium(valueColor ?? AppColors.textSecondaryLight)
                  .copyWith(fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }
}


/// Animated tab switcher that fades between tabs while keeping all alive.
class _AnimatedIndexedStack extends StatefulWidget {
  const _AnimatedIndexedStack({
    required this.index,
    required this.children,
  });
  final int index;
  final List<Widget> children;

  @override
  State<_AnimatedIndexedStack> createState() => _AnimatedIndexedStackState();
}

class _AnimatedIndexedStackState extends State<_AnimatedIndexedStack>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final Animation<double> _fade;
  int _currentIndex = 0;

  @override
  void initState() {
    super.initState();
    _currentIndex = widget.index;
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 220),
      value: 1.0,
    );
    _fade = CurvedAnimation(parent: _ctrl, curve: Curves.easeOut);
  }

  @override
  void didUpdateWidget(_AnimatedIndexedStack oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.index != widget.index) {
      _ctrl.forward(from: 0.0).then((_) {
        if (mounted) setState(() => _currentIndex = widget.index);
      });
      setState(() => _currentIndex = widget.index);
    }
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: _fade,
      child: IndexedStack(
        index: _currentIndex,
        children: widget.children,
      ),
    );
  }
}

extension _VendorHomeScreenStateExtension on _VendorHomeScreenState {  Widget _buildVendorHeader(BuildContext context, bool isDark) {
    final secondaryText =
        isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight;

    return Container(
      padding: EdgeInsets.fromLTRB(
        AppSpacing.md,
        MediaQuery.of(context).padding.top + AppSpacing.sm,
        AppSpacing.md,
        AppSpacing.md,
      ),
      decoration: BoxDecoration(
        color: isDark ? AppColors.surfaceDark : AppColors.surfaceLight,
        border: Border(
          bottom: BorderSide(
            color: isDark ? AppColors.borderDark : AppColors.borderLight,
            width: 1,
          ),
        ),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
            decoration: BoxDecoration(
              color: const Color(0xFF161616),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Image.asset(
              'assets/images/logo.png',
              height: 22,
              fit: BoxFit.contain,
            ),
          ),
          const Spacer(),
          IconButton(
            onPressed: () {
              ref.read(themeProvider.notifier).toggleTheme();
            },
            icon: Icon(
              isDark
                  ? Icons.light_mode_outlined
                  : Icons.dark_mode_outlined,
              color: secondaryText,
            ),
            style: IconButton.styleFrom(
              backgroundColor: isDark
                  ? AppColors.surfaceElevatedDark
                  : AppColors.borderLight,
            ),
          ),
          SizedBox(width: AppSpacing.xs),
          IconButton(
            onPressed: () {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(
                    'Notifications are fully set up for proposals and orders.',
                  ),
                  behavior: SnackBarBehavior.floating,
                ),
              );
            },
            icon: Icon(
              Icons.notifications_outlined,
              color: secondaryText,
            ),
            style: IconButton.styleFrom(
              backgroundColor: isDark
                  ? AppColors.surfaceElevatedDark
                  : AppColors.borderLight,
            ),
          ),
        ],
      ),
    );
  }
}

