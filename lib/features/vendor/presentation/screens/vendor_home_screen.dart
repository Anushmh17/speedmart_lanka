import 'package:flutter/material.dart';
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
import 'package:speedmart_lanka/shared/models/user_role.dart';
import 'package:speedmart_lanka/features/vendor/request_feed/presentation/vendor_request_feed_screen.dart';
import 'package:speedmart_lanka/features/vendor/request_feed/providers/vendor_request_feed_provider.dart';
import 'package:speedmart_lanka/features/vendor/request_feed/widgets/vendor_request_card.dart';
import 'package:speedmart_lanka/features/proposals/models/proposal.dart';
import 'package:speedmart_lanka/features/proposals/providers/proposal_provider.dart';
import 'package:speedmart_lanka/features/orders/models/order_model.dart';
import 'package:speedmart_lanka/features/orders/providers/order_provider.dart';
import 'package:speedmart_lanka/features/shared/presentation/screens/profile_screen.dart';
import 'package:speedmart_lanka/core/widgets/shared_floating_bottom_nav.dart';
import 'package:speedmart_lanka/core/navigation/bottom_nav_visibility.dart';
import 'package:speedmart_lanka/features/payments/models/payment.dart';
import 'vendor_status_screen.dart';

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

    // PopScope(canPop: false) suppresses the Android 13 predictive-back
    // swipe preview so the UI doesn't flash a "going back" animation.
    // The actual double-back logic lives in didPopRoute() above.
    return PopScope(
      canPop: false,
      child: Scaffold(
        backgroundColor:
            isDark ? AppColors.backgroundDark : AppColors.backgroundLight,
        body: Column(
          children: [
            _buildVendorHeader(context, isDark, user),
            Expanded(
              child: shouldShowStatusScreen
                  ? (user != null
                      ? VendorStatusScreen(user: user)
                      : _PendingApprovalView(isDark: isDark))
                  : IndexedStack(
                      index: _currentIndex,
                      children: [
                        _DashboardTab(user: user, isDark: isDark),
                        VendorRequestFeedScreen(isDark: isDark),
                        _MyProposalsTab(isDark: isDark),
                        const _VendorWalletTab(),
                        const ProfileScreen(),
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
            items: const [
              SharedFloatingBottomNavItem(
                unselectedIcon: Icons.dashboard_outlined,
                selectedIcon: Icons.dashboard_rounded,
                label: 'Dashboard',
              ),
              SharedFloatingBottomNavItem(
                unselectedIcon: Icons.inbox_outlined,
                selectedIcon: Icons.inbox_rounded,
                label: 'Requests',
              ),
              SharedFloatingBottomNavItem(
                unselectedIcon: Icons.assignment_outlined,
                selectedIcon: Icons.assignment_rounded,
                label: 'Proposals',
              ),
              SharedFloatingBottomNavItem(
                unselectedIcon: Icons.account_balance_wallet_outlined,
                selectedIcon: Icons.account_balance_wallet_rounded,
                label: 'Earnings',
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

class _DashboardTab extends ConsumerWidget {
  const _DashboardTab({required this.user, required this.isDark});
  final dynamic user;
  final bool isDark;

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
              Text('Vendor account required',
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

    // Calculate completed earnings from delivered orders
    final paidEarnings = orderState.orders
        .where((o) =>
            (o.status == OrderStatus.delivered ||
                o.status == OrderStatus.completed) &&
            o.paymentStatus == PaymentStatus.paid)
        .fold<double>(0, (sum, o) => sum + o.totalPrice);

    // Calculate pending earnings from active orders
    final pendingEarnings = orderState.orders
        .where((o) =>
            o.status != OrderStatus.cancelled &&
            o.status != OrderStatus.completed &&
            o.status != OrderStatus.delivered)
        .fold<double>(0, (sum, o) => sum + o.totalPrice);

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
            Text('Business Overview', style: AppTextStyles.h2(primaryText)),
            SizedBox(height: AppSpacing.md),
            Row(children: [
              Expanded(
                  child: _StatCard(
                      label: 'New Requests',
                      value: newRequestsCount,
                      icon: Icons.inbox_rounded,
                      color: AppColors.vendorColor,
                      isDark: isDark)),
              SizedBox(width: AppSpacing.sm),
              Expanded(
                  child: _StatCard(
                      label: 'Active Proposals',
                      value: proposalsSentCount,
                      icon: Icons.send_rounded,
                      color: AppColors.success,
                      isDark: isDark)),
            ]),
            SizedBox(height: AppSpacing.sm),
            Row(children: [
              Expanded(
                  child: _StatCard(
                      label: 'Active Orders',
                      value: activeOrdersCount,
                      icon: Icons.shopping_cart_rounded,
                      color: AppColors.warning,
                      isDark: isDark)),
              SizedBox(width: AppSpacing.sm),
              Expanded(
                  child: _StatCard(
                      label: 'Completed',
                      value: completedOrdersCount,
                      icon: Icons.task_alt_rounded,
                      color: AppColors.success,
                      isDark: isDark)),
            ]),
            SizedBox(height: AppSpacing.sm),
            Row(children: [
              Expanded(
                  child: _StatCard(
                      label: 'Paid (LKR)',
                      value: paidEarnings.toStringAsFixed(0),
                      icon: Icons.account_balance_wallet_rounded,
                      color: AppColors.accent,
                      isDark: isDark)),
              SizedBox(width: AppSpacing.sm),
              Expanded(
                  child: _StatCard(
                      label: 'Pending (LKR)',
                      value: pendingEarnings.toStringAsFixed(0),
                      icon: Icons.schedule_rounded,
                      color: Colors.orange,
                      isDark: isDark)),
            ]),
            SizedBox(height: AppSpacing.lg),

            // Active Customer Orders Section
            if (activeOrders.isNotEmpty) ...[
              Text('Active Customer Orders',
                  style: AppTextStyles.h2(primaryText)),
              SizedBox(height: AppSpacing.sm),
              ListView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: activeOrders.length,
                itemBuilder: (context, index) {
                  final order = activeOrders[index];
                  return Theme3AppCard(
                    margin: EdgeInsets.only(bottom: AppSpacing.sm),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(order.id,
                                  style: AppTextStyles.subtitle(primaryText)),
                              SizedBox(height: AppSpacing.xs),
                              Text('Customer: ${order.customerName}',
                                  style:
                                      AppTextStyles.bodySmall(secondaryText)),
                              Text('Status: ${order.status.displayName}',
                                  style: AppTextStyles.caption(
                                      AppColors.vendorColor)),
                            ],
                          ),
                        ),
                        ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.vendorColor,
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(AppRadius.md)),
                            minimumSize: const Size(0, 44),
                            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                          ),
                          onPressed: () {
                            context.push('/vendor/orders/manage', extra: order);
                          },
                          child: const Text('Manage',
                              style:
                                  TextStyle(color: Colors.white, fontSize: 12)),
                        ),
                      ],
                    ),
                  );
                },
              ),
              SizedBox(height: AppSpacing.md),
            ],

            // Completed Orders Section
            if (completedOrders.isNotEmpty) ...[
              Text('Recently Completed Orders',
                  style: AppTextStyles.h2(primaryText)),
              SizedBox(height: AppSpacing.sm),
              ListView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount:
                    completedOrders.length > 3 ? 3 : completedOrders.length,
                itemBuilder: (context, index) {
                  final order = completedOrders[index];
                  return Theme3AppCard(
                    margin: EdgeInsets.only(bottom: AppSpacing.sm),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(order.id,
                                  style: AppTextStyles.subtitle(primaryText)),
                              SizedBox(height: AppSpacing.xs),
                              Text('Customer: ${order.customerName}',
                                  style:
                                      AppTextStyles.bodySmall(secondaryText)),
                              Text(
                                  'Earned: Rs. ${order.totalPrice.toStringAsFixed(2)}',
                                  style:
                                      AppTextStyles.caption(AppColors.success)),
                            ],
                          ),
                        ),
                        Container(
                          padding: EdgeInsets.symmetric(
                              horizontal: AppSpacing.sm, vertical: AppSpacing.xs),
                          decoration: BoxDecoration(
                            color: AppColors.success.withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(AppRadius.sm),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.check_circle_outline,
                                  size: 14, color: AppColors.success),
                              SizedBox(width: AppSpacing.xs),
                              Text('Completed',
                                  style:
                                      AppTextStyles.caption(AppColors.success)
                                          .copyWith(
                                              fontWeight: FontWeight.bold)),
                            ],
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),
              SizedBox(height: AppSpacing.md),
            ],

            SizedBox(height: AppSpacing.sm),

            if (feedState.isLoading)
              Center(
                child: Padding(
                  padding: EdgeInsets.all(AppSpacing.xxl),
                  child: Column(
                    children: [
                      const CircularProgressIndicator(
                          color: AppColors.vendorColor),
                      SizedBox(height: AppSpacing.sm),
                      Text('Loading requests...',
                          style: AppTextStyles.bodyMedium(primaryText)),
                    ],
                  ),
                ),
              )
            else if (feedState.items.isEmpty)
              Theme3EmptyState(
                icon: Icons.location_searching_rounded,
                title: 'No nearby requests',
                subtitle:
                    'Active requests in your categories and radius will appear here.',
              )
            else
              ListView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount:
                    feedState.items.length > 2 ? 2 : feedState.items.length,
                itemBuilder: (context, index) {
                  return VendorRequestCard(
                    feedRequest: feedState.items[index],
                    isDark: isDark,
                  );
                },
              ),
          ],
        ),
      ),
    );
  }
}

class _MyProposalsTab extends ConsumerWidget {
  const _MyProposalsTab({required this.isDark});
  final bool isDark;

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

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final primaryText =
        isDark ? AppColors.textPrimaryDark : AppColors.textPrimaryLight;
    final secondaryText =
        isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight;
    
    
    final proposalState = ref.watch(proposalProvider);

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: RefreshIndicator(
        onRefresh: () =>
            ref.read(proposalProvider.notifier).loadVendorProposals(),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: EdgeInsets.fromLTRB(AppSpacing.md, AppSpacing.md, AppSpacing.md, AppSpacing.sm),
              child: Text(
                'My Submitted Bids',
                style: AppTextStyles.h2(primaryText),
              ),
            ),
            Expanded(
              child: proposalState.isLoading
                  ? const Center(
                      child: CircularProgressIndicator(
                          color: AppColors.vendorColor))
                  : proposalState.proposals.isEmpty
                      ? Theme3EmptyState(
                          icon: Icons.assignment_outlined,
                          title: 'No Proposals Yet',
                          subtitle:
                              'Accept a request to submit your first shop bid.',
                        )
                      : ListView.builder(
                          padding: EdgeInsets.fromLTRB(AppSpacing.md, 0, AppSpacing.md, 100),
                          itemCount: proposalState.proposals.length,
                          itemBuilder: (context, index) {
                            final proposal = proposalState.proposals[index];
                            final statusColor =
                                _getStatusColor(proposal.status);

                            // Calculate available items count
                            final availableCount = proposal.items
                                .where((i) =>
                                    i.status == ProposalItemStatus.available)
                                .length;
                            final altCount = proposal.items
                                .where((i) =>
                                    i.status == ProposalItemStatus.alternative)
                                .length;
                            final missingCount = proposal.items
                                .where((i) =>
                                    i.status == ProposalItemStatus.unavailable)
                                .length;

                            return Material(
                              color: Colors.transparent,
                              child: InkWell(
                                borderRadius: BorderRadius.circular(AppRadius.lg),
                                onTap: () {
                                  context.push(
                                    '/vendor/proposals/detail',
                                    extra: proposal,
                                  );
                                },
                                child: Theme3AppCard(
                                  margin: EdgeInsets.only(bottom: AppSpacing.sm),
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Row(
                                        mainAxisAlignment:
                                            MainAxisAlignment.spaceBetween,
                                        children: [
                                          Text(
                                            'BID: ${proposal.id}',
                                            style: AppTextStyles.subtitle(
                                                primaryText),
                                          ),
                                          StatusBadge(
                                            label: proposal.status.displayName,
                                            color: statusColor,
                                          ),
                                        ],
                                      ),
                                      const SizedBox(height: 8),
                                      Text(
                                        'For Customer Request: ${proposal.requestId}',
                                        style: AppTextStyles.bodySmall(
                                            secondaryText),
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        'Summary: $availableCount available, $altCount alternatives, $missingCount missing.',
                                        style: AppTextStyles.caption(
                                            secondaryText),
                                      ),
                                      const Divider(height: 16),
                                      Row(
                                        mainAxisAlignment:
                                            MainAxisAlignment.spaceBetween,
                                        children: [
                                          Column(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.start,
                                            children: [
                                              Text(
                                                'Delivery Time:',
                                                style: AppTextStyles.caption(
                                                    secondaryText),
                                              ),
                                              Text(
                                                proposal.estimatedDeliveryTime,
                                                style: AppTextStyles.bodyMedium(
                                                    primaryText),
                                              ),
                                            ],
                                          ),
                                          Column(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.end,
                                            children: [
                                              Text(
                                                'Total Bid:',
                                                style: AppTextStyles.caption(
                                                    secondaryText),
                                              ),
                                              Text(
                                                'Rs. ${proposal.totalPrice.toStringAsFixed(2)}',
                                                style: AppTextStyles.subtitle(
                                                    AppColors.vendorColor),
                                              ),
                                            ],
                                          ),
                                        ],
                                      ),
                                      if (proposal.status ==
                                              ProposalStatus.rejected &&
                                          proposal.rejectionReason != null) ...[
                                        const SizedBox(height: 12),
                                        Container(
                                          width: double.infinity,
                                          padding: const EdgeInsets.all(10),
                                          decoration: BoxDecoration(
                                            color: AppColors.error
                                                .withValues(alpha: 0.08),
                                            borderRadius:
                                                BorderRadius.circular(10),
                                          ),
                                          child: Row(
                                            children: [
                                              const Icon(Icons.info_outline,
                                                  color: AppColors.error,
                                                  size: 18),
                                              const SizedBox(width: 8),
                                              Expanded(
                                                child: Text(
                                                  'Rejection Reason: ${proposal.rejectionReason}',
                                                  style: AppTextStyles.caption(
                                                      AppColors.error),
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                      ],

                                      // Controlled Suggested Chat Feature
                                      if (proposal.customerResponse != null ||
                                          proposal.vendorResponse != null) ...[
                                        const SizedBox(height: 12),
                                        Container(
                                          padding: const EdgeInsets.all(12),
                                          decoration: BoxDecoration(
                                            color: isDark
                                                ? Colors.black26
                                                : Colors.grey.shade100,
                                            borderRadius:
                                                BorderRadius.circular(12),
                                          ),
                                          child: Column(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.start,
                                            children: [
                                              Text('Message Log:',
                                                  style: AppTextStyles.caption(
                                                      secondaryText)),
                                              const SizedBox(height: 8),
                                              if (proposal.customerResponse !=
                                                  null)
                                                Row(
                                                  crossAxisAlignment:
                                                      CrossAxisAlignment.start,
                                                  children: [
                                                    Icon(Icons.person_outline,
                                                        size: 16,
                                                        color: primaryText),
                                                    const SizedBox(width: 8),
                                                    Expanded(
                                                      child: Text(
                                                        'Customer: ${proposal.customerResponse ?? ''}',
                                                        style: AppTextStyles
                                                            .bodySmall(
                                                                primaryText),
                                                      ),
                                                    ),
                                                  ],
                                                ),
                                              if (proposal.vendorResponse !=
                                                  null) ...[
                                                const SizedBox(height: 8),
                                                Row(
                                                  crossAxisAlignment:
                                                      CrossAxisAlignment.start,
                                                  children: [
                                                    Icon(
                                                        Icons
                                                            .check_circle_outline,
                                                        size: 16,
                                                        color: AppColors
                                                            .vendorColor),
                                                    const SizedBox(width: 8),
                                                    Expanded(
                                                      child: Text(
                                                        'You: ${proposal.vendorResponse ?? ''}',
                                                        style: AppTextStyles
                                                            .bodySmall(AppColors
                                                                .vendorColor),
                                                      ),
                                                    ),
                                                  ],
                                                ),
                                              ],
                                            ],
                                          ),
                                        ),
                                      ]
                                    ],
                                  ),
                                ),
                              ),
                            );
                          },
                        ),
            ),
          ],
        ),
      ),
    );
  }
}

class _StatCard extends StatelessWidget {
  const _StatCard({
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
    return Theme3AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: color, size: 22),
          SizedBox(height: AppSpacing.sm),
          Text(value,
              style: AppTextStyles.h2(isDark
                  ? AppColors.textPrimaryDark
                  : AppColors.textPrimaryLight)),
          SizedBox(height: AppSpacing.xs),
          Text(label,
              style: AppTextStyles.caption(isDark
                  ? AppColors.textSecondaryDark
                  : AppColors.textSecondaryLight)),
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
              'Your vendor account is under review. You will be notified once approved.',
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

class _VendorWalletTab extends ConsumerStatefulWidget {
  const _VendorWalletTab();

  @override
  ConsumerState<_VendorWalletTab> createState() => _VendorWalletTabState();
}

class _VendorWalletTabState extends ConsumerState<_VendorWalletTab> {
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
    final completedOrders = orderState.orders
        .where((o) =>
            o.status == OrderStatus.delivered &&
            o.paymentStatus == PaymentStatus.paid)
        .toList();

    final double liveGrossRevenue =
        completedOrders.fold<double>(0, (sum, o) => sum + o.totalPrice);
    final double liveCommission = liveGrossRevenue * 0.03;
    final double liveNetEarnings = liveGrossRevenue - liveCommission;

    final double totalHistoricGross =
        _mockPayouts.fold<double>(0.0, (sum, p) => sum + p['payout']);
    final double totalHistoricComm =
        _mockPayouts.fold<double>(0.0, (sum, p) => sum + p['comm']);
    final double totalHistoricNet =
        _mockPayouts.fold<double>(0.0, (sum, p) => sum + p['net']);

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
                Text('Vendor LKR Wallet', style: AppTextStyles.h1(primaryText)),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              'Real-time earnings ledger with strict 3% platform commission tracking.',
              style: AppTextStyles.bodyMedium(secondaryText),
            ),
            const SizedBox(height: 24),
            Container(
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
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.2),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          'Platform Fee: 3%',
                          style: AppTextStyles.caption(Colors.white).copyWith(
                              fontSize: 10, fontWeight: FontWeight.bold),
                        ),
                      ),
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
                          Text('Comm. Deducted (3%)',
                              style: AppTextStyles.caption(Colors.white60)),
                          const SizedBox(height: 4),
                          Text('Rs. ${cumulativeCommission.toStringAsFixed(2)}',
                              style: AppTextStyles.bodyLarge(Colors.amber)
                                  .copyWith(fontWeight: FontWeight.bold)),
                        ],
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 28),
            Text('Weekly Sales Distribution',
                style: AppTextStyles.h2(primaryText)),
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
                  _buildChartBar('Mon', 14250, cumulativeGross, isDark),
                  _buildChartBar('Tue', 0, cumulativeGross, isDark),
                  _buildChartBar('Wed', 9800, cumulativeGross, isDark),
                  _buildChartBar('Thu', 0, cumulativeGross, isDark),
                  _buildChartBar('Fri', 22500, cumulativeGross, isDark),
                  _buildChartBar(
                      'Sat', liveGrossRevenue, cumulativeGross, isDark),
                  _buildChartBar('Sun', 0, cumulativeGross, isDark),
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
            if (completedOrders.isNotEmpty) ...[
              ...completedOrders.map((order) {
                final orderGross = order.totalPrice;
                final orderComm = orderGross * 0.03;
                final orderNet = orderGross - orderComm;

                return Container(
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
                          Text('Order Reference: ${order.id}',
                              style: AppTextStyles.bodyMedium(primaryText)
                                  .copyWith(fontWeight: FontWeight.bold)),
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 8, vertical: 3),
                            decoration: BoxDecoration(
                              color: AppColors.warning.withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              'Pending Settlement',
                              style: AppTextStyles.caption(AppColors.warning)
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
                          Text('Today',
                              style: AppTextStyles.caption(secondaryText)),
                        ],
                      ),
                      const Divider(height: 16),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text('Sales: Rs. ${orderGross.toStringAsFixed(0)}',
                              style: AppTextStyles.bodySmall(secondaryText)),
                          Text('Comm (3%): Rs. ${orderComm.toStringAsFixed(0)}',
                              style: AppTextStyles.bodySmall(secondaryText)),
                          Text('Net: Rs. ${orderNet.toStringAsFixed(2)}',
                              style: AppTextStyles.bodyMedium(AppColors.success)
                                  .copyWith(fontWeight: FontWeight.bold)),
                        ],
                      ),
                    ],
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
                            'Comm (3%): Rs. ${payout['comm'].toStringAsFixed(0)}',
                            style: AppTextStyles.bodySmall(secondaryText)),
                        Text('Net: Rs. ${payout['net'].toStringAsFixed(2)}',
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
}


extension _VendorHomeScreenStateExtension on _VendorHomeScreenState {
  Widget _buildVendorHeader(BuildContext context, bool isDark, dynamic user) {
    final primaryText =
        isDark ? AppColors.textPrimaryDark : AppColors.textPrimaryLight;
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
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
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
              SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      user?.businessName ?? 'Your Shop',
                      style: AppTextStyles.h2(primaryText),
                    ),
                    SizedBox(height: AppSpacing.xs),
                    Text(
                      'Welcome back, ${user?.firstName ?? 'Vendor'}',
                      style: AppTextStyles.bodySmall(secondaryText),
                    ),
                  ],
                ),
              ),
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
        ],
      ),
    );
  }
}
