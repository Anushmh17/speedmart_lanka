import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../core/widgets/app_logo.dart';
import '../../../../core/widgets/app_state_widgets.dart';
import '../../../auth/providers/auth_provider.dart';
import '../../../auth/providers/theme_provider.dart';
import '../../request_feed/presentation/vendor_request_feed_screen.dart';
import '../../request_feed/providers/vendor_request_feed_provider.dart';
import '../../request_feed/widgets/vendor_request_card.dart';
import '../../../proposals/models/proposal.dart';
import '../../../proposals/providers/proposal_provider.dart';
import '../../../orders/models/order_model.dart';
import '../../../orders/providers/order_provider.dart';
import '../../../shared/presentation/screens/profile_screen.dart';
import '../../../../core/widgets/shared_floating_bottom_nav.dart';
import '../../../../core/navigation/bottom_nav_visibility.dart';

class VendorHomeScreen extends ConsumerStatefulWidget {
  const VendorHomeScreen({super.key});

  @override
  ConsumerState<VendorHomeScreen> createState() => _VendorHomeScreenState();
}

class _VendorHomeScreenState extends ConsumerState<VendorHomeScreen> {
  int _currentIndex = 0;

  void _switchTab(int index) {
    setState(() => _currentIndex = index);
  }

  @override
  void initState() {
    super.initState();
    // Load data asynchronously on screen entry
    Future.microtask(() {
      ref.read(vendorRequestFeedProvider.notifier).loadFeed();
      ref.read(proposalProvider.notifier).loadVendorProposals();
      ref.read(orderProvider.notifier).loadVendorOrders();
    });
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final user = ref.watch(currentUserProvider);
    final isPending = user?.vendorApproved == false;

    // Watch central bottom navigation visibility provider
    final showBottomNav = ref.watch(bottomNavVisibilityProvider);

    return Scaffold(
      backgroundColor: isDark ? AppColors.backgroundDark : AppColors.backgroundLight,
      appBar: AppBar(
        title: const AppBarLogo(),
        actions: [
          IconButton(
            icon: Icon(
              isDark ? Icons.light_mode_outlined : Icons.dark_mode_outlined,
              color: isDark ? AppColors.textPrimaryDark : AppColors.textPrimaryLight,
            ),
            onPressed: () => ref.read(themeProvider.notifier).toggleTheme(),
          ),
          IconButton(
            icon: Icon(Icons.notifications_outlined,
                color: isDark ? AppColors.textPrimaryDark : AppColors.textPrimaryLight),
            onPressed: () {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Notifications are fully set up for proposals and orders.'),
                  behavior: SnackBarBehavior.floating,
                ),
              );
            },
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: isPending
          ? _PendingApprovalView(isDark: isDark)
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
      bottomNavigationBar: AnimatedBottomNavWrapper(
        visible: !isPending && showBottomNav,
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
    );
  }
}

class _DashboardTab extends ConsumerWidget {
  const _DashboardTab({required this.user, required this.isDark});
  final dynamic user;
  final bool isDark;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final primaryText = isDark ? AppColors.textPrimaryDark : AppColors.textPrimaryLight;
    final secondaryText = isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight;
    final cardColor = isDark ? AppColors.cardDark : AppColors.cardLight;
    final borderColor = isDark ? AppColors.borderDark : AppColors.borderLight;

    final feedState = ref.watch(vendorRequestFeedProvider);
    final proposalState = ref.watch(proposalProvider);
    final orderState = ref.watch(orderProvider);

    final newRequestsCount = feedState.items.length.toString();
    final proposalsSentCount = proposalState.proposals.length.toString();
    
    final activeOrders = orderState.orders.where((o) => o.status != OrderStatus.delivered).toList();
    final activeOrdersCount = activeOrders.length.toString();

    // Calculate completed earnings from mock orders
    final earnings = orderState.orders
        .where((o) => o.status == OrderStatus.delivered && o.paymentStatus == PaymentStatus.paid)
        .fold<double>(0, (sum, o) => sum + o.totalPrice);

    return RefreshIndicator(
      onRefresh: () async {
        await ref.read(vendorRequestFeedProvider.notifier).refresh();
        await ref.read(proposalProvider.notifier).loadVendorProposals();
        await ref.read(orderProvider.notifier).loadVendorOrders();
      },
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 100),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Banner
            Container(
              width: double.infinity,
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
                    color: AppColors.vendorColor.withOpacity(0.3),
                    blurRadius: 20,
                    offset: const Offset(0, 8),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(user?.businessName ?? 'Your Shop', style: AppTextStyles.h2(Colors.white)),
                  const SizedBox(height: 4),
                  Text('Welcome back, ${user?.firstName ?? ''}',
                      style: AppTextStyles.bodyMedium(Colors.white70)),
                  const SizedBox(height: 14),
                  StatusBadge(label: 'â— Active & Verified', color: Colors.white),
                ],
              ),
            ),
            const SizedBox(height: 24),

            Text("Today's Overview", style: AppTextStyles.h2(primaryText)),
            const SizedBox(height: 14),
            Row(children: [
              Expanded(child: _StatCard(label: 'New Requests', value: newRequestsCount, icon: Icons.inbox_rounded, color: AppColors.vendorColor, isDark: isDark)),
              const SizedBox(width: 12),
              Expanded(child: _StatCard(label: 'Proposals Sent', value: proposalsSentCount, icon: Icons.send_rounded, color: AppColors.success, isDark: isDark)),
            ]),
            const SizedBox(height: 12),
            Row(children: [
              Expanded(child: _StatCard(label: 'Active Orders', value: activeOrdersCount, icon: Icons.shopping_cart_rounded, color: AppColors.warning, isDark: isDark)),
              const SizedBox(width: 12),
              Expanded(child: _StatCard(label: 'Earnings (LKR)', value: earnings.toStringAsFixed(2), icon: Icons.account_balance_wallet_rounded, color: AppColors.accent, isDark: isDark)),
            ]),
            const SizedBox(height: 28),

            // Active Customer Orders Section
            if (activeOrders.isNotEmpty) ...[
              Text('Active Customer Orders', style: AppTextStyles.h2(primaryText)),
              const SizedBox(height: 12),
              ListView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: activeOrders.length,
                itemBuilder: (context, index) {
                  final order = activeOrders[index];
                  return Container(
                    margin: const EdgeInsets.only(bottom: 12),
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: cardColor,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: borderColor),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(order.id, style: AppTextStyles.subtitle(primaryText)),
                              const SizedBox(height: 4),
                              Text('Customer: ${order.customerName}', style: AppTextStyles.bodySmall(secondaryText)),
                              Text('Status: ${order.status.displayName}', style: AppTextStyles.caption(AppColors.vendorColor)),
                            ],
                          ),
                        ),
                        ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.vendorColor,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          ),
                          onPressed: () {
                            context.push('/vendor/orders/manage', extra: order);
                          },
                          child: const Text('Manage', style: TextStyle(color: Colors.white, fontSize: 12)),
                        ),
                      ],
                    ),
                  );
                },
              ),
              const SizedBox(height: 20),
            ],

            Text('Recent Nearby Requests', style: AppTextStyles.h2(primaryText)),
            const SizedBox(height: 12),

            if (feedState.isLoading)
              const Center(
                child: Padding(
                  padding: EdgeInsets.all(32.0),
                  child: CircularProgressIndicator(color: AppColors.vendorColor),
                ),
              )
            else if (feedState.items.isEmpty)
              const AppEmptyState(
                icon: Icons.location_searching_rounded,
                title: 'No nearby requests',
                subtitle: 'Active requests in your categories and radius will appear here.',
              )
            else
              ListView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: feedState.items.length > 2 ? 2 : feedState.items.length,
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
    final primaryText = isDark ? AppColors.textPrimaryDark : AppColors.textPrimaryLight;
    final secondaryText = isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight;
    final cardColor = isDark ? AppColors.cardDark : AppColors.cardLight;
    final borderColor = isDark ? AppColors.borderDark : AppColors.borderLight;
    final proposalState = ref.watch(proposalProvider);

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: RefreshIndicator(
        onRefresh: () => ref.read(proposalProvider.notifier).loadVendorProposals(),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 10),
              child: Text(
                'My Submitted Bids',
                style: AppTextStyles.h2(primaryText),
              ),
            ),
            Expanded(
              child: proposalState.isLoading
                  ? const Center(child: CircularProgressIndicator(color: AppColors.vendorColor))
                  : proposalState.proposals.isEmpty
                      ? const AppEmptyState(
                          icon: Icons.assignment_outlined,
                          title: 'No Proposals Yet',
                          subtitle: 'Accept a request to submit your first shop bid.',
                        )
                      : ListView.builder(
                          padding: const EdgeInsets.fromLTRB(16, 0, 16, 100),
                          itemCount: proposalState.proposals.length,
                          itemBuilder: (context, index) {
                            final proposal = proposalState.proposals[index];
                            final statusColor = _getStatusColor(proposal.status);
                            
                            // Calculate available items count
                            final availableCount = proposal.items.where((i) => i.status == ProposalItemStatus.available).length;
                            final altCount = proposal.items.where((i) => i.status == ProposalItemStatus.alternative).length;
                            final missingCount = proposal.items.where((i) => i.status == ProposalItemStatus.unavailable).length;

                            return Material(
                              color: Colors.transparent,
                              child: InkWell(
                                borderRadius: BorderRadius.circular(16),
                                onTap: () {
                                  context.push(
                                    '/vendor/proposals/detail',
                                    extra: proposal,
                                  );
                                },
                                child: Container(
                              margin: const EdgeInsets.only(bottom: 12),
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
                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                    children: [
                                      Text(
                                        'BID: ${proposal.id}',
                                        style: AppTextStyles.subtitle(primaryText),
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
                                    style: AppTextStyles.bodySmall(secondaryText),
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
                                      Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            'Delivery Time:',
                                            style: AppTextStyles.caption(secondaryText),
                                          ),
                                          Text(
                                            proposal.estimatedDeliveryTime,
                                            style: AppTextStyles.bodyMedium(primaryText),
                                          ),
                                        ],
                                      ),
                                      Column(
                                        crossAxisAlignment: CrossAxisAlignment.end,
                                        children: [
                                          Text(
                                            'Total Bid:',
                                            style: AppTextStyles.caption(secondaryText),
                                          ),
                                          Text(
                                            'Rs. ${proposal.totalPrice.toStringAsFixed(2)}',
                                            style: AppTextStyles.subtitle(AppColors.vendorColor),
                                          ),
                                        ],
                                      ),
                                    ],
                                  ),
                                  if (proposal.status == ProposalStatus.rejected && proposal.rejectionReason != null) ...[
                                    const SizedBox(height: 12),
                                    Container(
                                      width: double.infinity,
                                      padding: const EdgeInsets.all(10),
                                      decoration: BoxDecoration(
                                        color: AppColors.error.withOpacity(0.08),
                                        borderRadius: BorderRadius.circular(10),
                                      ),
                                      child: Row(
                                        children: [
                                          const Icon(Icons.info_outline, color: AppColors.error, size: 18),
                                          const SizedBox(width: 8),
                                          Expanded(
                                            child: Text(
                                              'Rejection Reason: ${proposal.rejectionReason}',
                                              style: AppTextStyles.caption(AppColors.error),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                  
                                  // Controlled Suggested Chat Feature
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
                                          Text('Suggested Communication Log:', style: AppTextStyles.caption(secondaryText)),
                                          const SizedBox(height: 4),
                                          if (proposal.customerResponse != null)
                                            Text('ðŸ’¬ Customer: "${proposal.customerResponse}"', style: AppTextStyles.bodySmall(primaryText)),
                                          if (proposal.vendorResponse != null)
                                            Text('ðŸ’¬ You: "${proposal.vendorResponse}"', style: AppTextStyles.bodySmall(AppColors.vendorColor)),
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
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? AppColors.cardDark : AppColors.cardLight,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: isDark ? AppColors.borderDark : AppColors.borderLight),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: color, size: 22),
          const SizedBox(height: 10),
          Text(value,
              style: AppTextStyles.h2(isDark ? AppColors.textPrimaryDark : AppColors.textPrimaryLight)),
          const SizedBox(height: 2),
          Text(label,
              style: AppTextStyles.caption(isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight)),
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
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 90,
              height: 90,
              decoration: BoxDecoration(
                color: AppColors.warning.withOpacity(0.12),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.hourglass_top_rounded, color: AppColors.warning, size: 42),
            ),
            const SizedBox(height: 24),
            Text('Pending Approval',
                style: AppTextStyles.h1(isDark ? AppColors.textPrimaryDark : AppColors.textPrimaryLight)),
            const SizedBox(height: 12),
            Text(
              'Your vendor account is under review. You will be notified once approved.',
              style: AppTextStyles.bodyMedium(
                  isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight),
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
    final primaryText = isDark ? AppColors.textPrimaryDark : AppColors.textPrimaryLight;
    final secondaryText = isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight;
    final cardColor = isDark ? AppColors.cardDark : AppColors.cardLight;
    final borderColor = isDark ? AppColors.borderDark : AppColors.borderLight;

    final orderState = ref.watch(orderProvider);
    final completedOrders = orderState.orders
        .where((o) => o.status == OrderStatus.delivered && o.paymentStatus == PaymentStatus.paid)
        .toList();

    final double liveGrossRevenue = completedOrders.fold<double>(0, (sum, o) => sum + o.totalPrice);
    final double liveCommission = liveGrossRevenue * 0.03;
    final double liveNetEarnings = liveGrossRevenue - liveCommission;

    final double totalHistoricGross = _mockPayouts.fold<double>(0.0, (sum, p) => sum + p['payout']);
    final double totalHistoricComm = _mockPayouts.fold<double>(0.0, (sum, p) => sum + p['comm']);
    final double totalHistoricNet = _mockPayouts.fold<double>(0.0, (sum, p) => sum + p['net']);

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
                const Icon(Icons.account_balance_wallet_rounded, color: AppColors.vendorColor, size: 28),
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
                    color: AppColors.vendorColor.withOpacity(0.25),
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
                      Text('Cumulative Net Earnings', style: AppTextStyles.caption(Colors.white70).copyWith(fontWeight: FontWeight.bold)),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.2),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          'Platform Fee: 3%',
                          style: AppTextStyles.caption(Colors.white).copyWith(fontSize: 10, fontWeight: FontWeight.bold),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Rs. ${cumulativeNet.toStringAsFixed(2)}',
                    style: AppTextStyles.h1(Colors.white).copyWith(fontSize: 32, letterSpacing: -0.5),
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
                          Text('Gross Sales', style: AppTextStyles.caption(Colors.white60)),
                          const SizedBox(height: 4),
                          Text('Rs. ${cumulativeGross.toStringAsFixed(0)}', style: AppTextStyles.bodyLarge(Colors.white).copyWith(fontWeight: FontWeight.bold)),
                        ],
                      ),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Comm. Deducted (3%)', style: AppTextStyles.caption(Colors.white60)),
                          const SizedBox(height: 4),
                          Text('Rs. ${cumulativeCommission.toStringAsFixed(2)}', style: AppTextStyles.bodyLarge(Colors.amber).copyWith(fontWeight: FontWeight.bold)),
                        ],
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 28),

            Text('Weekly Sales Distribution', style: AppTextStyles.h2(primaryText)),
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
                  _buildChartBar('Sat', liveGrossRevenue, cumulativeGross, isDark),
                  _buildChartBar('Sun', 0, cumulativeGross, isDark),
                ],
              ),
            ),
            const SizedBox(height: 28),

            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('Earnings Settlement Log', style: AppTextStyles.h2(primaryText)),
                const Icon(Icons.history_toggle_off_rounded, color: AppColors.vendorColor, size: 20),
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
                    border: Border.all(color: AppColors.vendorColor.withOpacity(0.3), width: 1.2),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text('Order Reference: ${order.id}', style: AppTextStyles.bodyMedium(primaryText).copyWith(fontWeight: FontWeight.bold)),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                            decoration: BoxDecoration(
                              color: AppColors.warning.withOpacity(0.12),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              'Pending Settlement',
                              style: AppTextStyles.caption(AppColors.warning).copyWith(fontWeight: FontWeight.bold, fontSize: 10),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text('Customer: ${order.customerName}', style: AppTextStyles.caption(secondaryText)),
                          Text('Today', style: AppTextStyles.caption(secondaryText)),
                        ],
                      ),
                      const Divider(height: 16),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text('Sales: Rs. ${orderGross.toStringAsFixed(0)}', style: AppTextStyles.bodySmall(secondaryText)),
                          Text('Comm (3%): Rs. ${orderComm.toStringAsFixed(0)}', style: AppTextStyles.bodySmall(secondaryText)),
                          Text('Net: Rs. ${orderNet.toStringAsFixed(2)}', style: AppTextStyles.bodyMedium(AppColors.success).copyWith(fontWeight: FontWeight.bold)),
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
                        Text('Order Reference: ${payout['ref']}', style: AppTextStyles.bodyMedium(primaryText).copyWith(fontWeight: FontWeight.bold)),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: AppColors.success.withOpacity(0.12),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            'Settled to Bank',
                            style: AppTextStyles.caption(AppColors.success).copyWith(fontWeight: FontWeight.bold, fontSize: 10),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(payout['bank']!, style: AppTextStyles.caption(secondaryText)),
                        Text(payout['date']!, style: AppTextStyles.caption(secondaryText)),
                      ],
                    ),
                    const Divider(height: 16),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text('Sales: Rs. ${payout['payout'].toStringAsFixed(0)}', style: AppTextStyles.bodySmall(secondaryText)),
                        Text('Comm (3%): Rs. ${payout['comm'].toStringAsFixed(0)}', style: AppTextStyles.bodySmall(secondaryText)),
                        Text('Net: Rs. ${payout['net'].toStringAsFixed(2)}', style: AppTextStyles.bodyMedium(primaryText).copyWith(fontWeight: FontWeight.bold)),
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

  Widget _buildChartBar(String day, double value, double cumulativeMax, bool isDark) {
    final primaryText = isDark ? Colors.white : Colors.black;
    final secondaryText = isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight;
    final maxReference = cumulativeMax > 0 ? cumulativeMax : 1.0;
    final double pct = (value / maxReference).clamp(0.0, 1.0);

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6.0),
      child: Row(
        children: [
          SizedBox(width: 40, child: Text(day, style: AppTextStyles.bodySmall(primaryText).copyWith(fontWeight: FontWeight.bold))),
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
