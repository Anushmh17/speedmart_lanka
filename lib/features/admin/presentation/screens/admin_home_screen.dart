import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/routes/route_names.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../core/widgets/app_logo.dart';
import '../../../../core/widgets/app_state_widgets.dart';
import '../../../auth/providers/auth_provider.dart';
import '../../../auth/providers/theme_provider.dart';
import '../../../../shared/models/user_role.dart';
import '../../../requests/providers/request_provider.dart';
import '../../../orders/models/order_model.dart';
import '../../../orders/providers/order_provider.dart';
import '../../providers/admin_provider.dart';
import '../../../../core/widgets/shared_floating_bottom_nav.dart';

class AdminHomeScreen extends ConsumerStatefulWidget {
  const AdminHomeScreen({super.key});

  @override
  ConsumerState<AdminHomeScreen> createState() => _AdminHomeScreenState();
}

class _AdminHomeScreenState extends ConsumerState<AdminHomeScreen> {
  int _currentIndex = 0;

  @override
  void initState() {
    super.initState();
    Future.microtask(() {
      ref.read(adminProvider.notifier).loadAllUsers();
      ref.read(requestProvider.notifier).loadNearbyRequests();
      ref.read(orderProvider.notifier).loadCustomerOrders(); // Just to load mock database orders if any
    });
  }

  void _switchTab(int index) {
    setState(() {
      _currentIndex = index;
    });
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

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
            icon: Icon(Icons.logout_rounded,
                color: isDark ? AppColors.textPrimaryDark : AppColors.textPrimaryLight),
            tooltip: 'Logout',
            onPressed: () async {
              await ref.read(authProvider.notifier).logout();
              if (context.mounted) context.go(RouteNames.roleSelection);
            },
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: IndexedStack(
        index: _currentIndex,
        children: [
          _AdminDashboardTab(isDark: isDark, switchTab: _switchTab),
          _VendorApprovalsTab(isDark: isDark),
          _UsersManagementTab(isDark: isDark),
          _OrdersMonitoringTab(isDark: isDark),
          _PlatformSettingsTab(isDark: isDark),
        ],
      ),
      bottomNavigationBar: SharedFloatingBottomNav(
        currentIndex: _currentIndex,
        onTap: _switchTab,
        activeColor: AppColors.adminColor,
        items: const [
          SharedFloatingBottomNavItem(
            unselectedIcon: Icons.dashboard_outlined,
            selectedIcon: Icons.dashboard_rounded,
            label: 'Dashboard',
          ),
          SharedFloatingBottomNavItem(
            unselectedIcon: Icons.verified_user_outlined,
            selectedIcon: Icons.verified_user_rounded,
            label: 'Vendors',
          ),
          SharedFloatingBottomNavItem(
            unselectedIcon: Icons.people_outline_rounded,
            selectedIcon: Icons.people_rounded,
            label: 'Users',
          ),
          SharedFloatingBottomNavItem(
            unselectedIcon: Icons.receipt_long_outlined,
            selectedIcon: Icons.receipt_long_rounded,
            label: 'Orders',
          ),
          SharedFloatingBottomNavItem(
            unselectedIcon: Icons.settings_outlined,
            selectedIcon: Icons.settings_rounded,
            label: 'Settings',
          ),
        ],
      ),
    );
  }
}

class _AdminDashboardTab extends ConsumerWidget {
  const _AdminDashboardTab({required this.isDark, required this.switchTab});
  final bool isDark;
  final ValueChanged<int> switchTab;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final primaryText = isDark ? AppColors.textPrimaryDark : AppColors.textPrimaryLight;

    final adminState = ref.watch(adminProvider);
    final requestState = ref.watch(requestProvider);
    final orderState = ref.watch(orderProvider);

    // Live calculations
    final totalUsers = adminState.users.length.toString();
    final totalVendors = adminState.users.where((u) => u.role == UserRole.vendor).length.toString();
    final pendingApprovals = adminState.users.where((u) => u.role == UserRole.vendor && u.vendorApproved == false).length.toString();
    
    // Requests total (mock customer lists + nearby vendor requests feed)
    final totalRequests = (requestState.requests.length + requestState.nearbyRequests.length).toString();
    final totalOrders = orderState.orders.length.toString();

    // 3% platform commission on completed/delivered transactions
    final completedOrders = orderState.orders.where((o) => o.status == OrderStatus.delivered);
    final totalSales = completedOrders.fold<double>(0, (sum, o) => sum + o.totalPrice);
    final platformRevenue = totalSales * 0.03;

    return RefreshIndicator(
      onRefresh: () async {
        await ref.read(adminProvider.notifier).loadAllUsers();
        await ref.read(requestProvider.notifier).loadNearbyRequests();
        await ref.read(orderProvider.notifier).loadCustomerOrders();
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
                  colors: [AppColors.adminColor, AppColors.adminColorDark],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(
                    color: AppColors.adminColor.withOpacity(0.3),
                    blurRadius: 20,
                    offset: const Offset(0, 8),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Admin Dashboard', style: AppTextStyles.h2(Colors.white)),
                  const SizedBox(height: 4),
                  Text('Speedmart Lanka Platform Control', style: AppTextStyles.bodyMedium(Colors.white70)),
                  const SizedBox(height: 14),
                  StatusBadge(label: '● Platform Monitoring Online', color: Colors.white),
                ],
              ),
            ),
            const SizedBox(height: 24),

            // Stats grid
            Text('Platform Overview', style: AppTextStyles.h2(primaryText)),
            const SizedBox(height: 14),
            GridView.count(
              crossAxisCount: 2,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              crossAxisSpacing: 12,
              mainAxisSpacing: 12,
              childAspectRatio: 1.4,
              children: [
                _AdminStatCard(label: 'Total Users', value: totalUsers, icon: Icons.people_rounded, color: AppColors.info, isDark: isDark),
                _AdminStatCard(label: 'Total Vendors', value: totalVendors, icon: Icons.storefront_rounded, color: AppColors.vendorColor, isDark: isDark),
                _AdminStatCard(label: 'Pending Approvals', value: pendingApprovals, icon: Icons.pending_actions_rounded, color: AppColors.warning, isDark: isDark),
                _AdminStatCard(label: 'Shopping Lists', value: totalRequests, icon: Icons.list_alt_rounded, color: AppColors.customerColor, isDark: isDark),
                _AdminStatCard(label: 'Platform Orders', value: totalOrders, icon: Icons.shopping_bag_rounded, color: AppColors.accent, isDark: isDark),
                _AdminStatCard(label: 'Comm. LKR (3%)', value: platformRevenue.toStringAsFixed(2), icon: Icons.account_balance_rounded, color: AppColors.success, isDark: isDark),
              ],
            ),
            const SizedBox(height: 28),

            // Quick actions
            Text('Platform Control Actions', style: AppTextStyles.h2(primaryText)),
            const SizedBox(height: 14),
            _quickActionCard(Icons.verified_user_rounded, 'Vendor Approvals', '$pendingApprovals pending applications', AppColors.warning, () => switchTab(1)),
            _quickActionCard(Icons.people_rounded, 'User Directories', 'Suspend/Activate users', AppColors.info, () => switchTab(2)),
            _quickActionCard(Icons.receipt_long_rounded, 'Monitor Orders', 'Commission & Dispatch status', AppColors.success, () => switchTab(3)),
            _quickActionCard(Icons.settings_rounded, 'Platform Config', 'Commission percentages & values', AppColors.accent, () => switchTab(4)),
          ],
        ),
      ),
    );
  }

  Widget _quickActionCard(IconData icon, String title, String subtitle, Color color, VoidCallback onTap) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          decoration: BoxDecoration(
            color: isDark ? AppColors.cardDark : AppColors.cardLight,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: isDark ? AppColors.borderDark : AppColors.borderLight),
          ),
          child: Row(
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: color.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, color: color, size: 20),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, style: AppTextStyles.labelLarge(isDark ? AppColors.textPrimaryDark : AppColors.textPrimaryLight)),
                    Text(subtitle, style: AppTextStyles.caption(isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight)),
                  ],
                ),
              ),
              Icon(Icons.arrow_forward_ios_rounded, size: 14, color: isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight),
            ],
          ),
        ),
      ),
    );
  }
}

class _AdminStatCard extends StatelessWidget {
  const _AdminStatCard({
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
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: isDark ? AppColors.cardDark : AppColors.cardLight,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: isDark ? AppColors.borderDark : AppColors.borderLight),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Icon(icon, color: color, size: 20),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(value, style: AppTextStyles.h2(isDark ? AppColors.textPrimaryDark : AppColors.textPrimaryLight)),
              const SizedBox(height: 2),
              Text(label, style: AppTextStyles.caption(isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight)),
            ],
          ),
        ],
      ),
    );
  }
}

class _VendorApprovalsTab extends ConsumerWidget {
  const _VendorApprovalsTab({required this.isDark});
  final bool isDark;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final primaryText = isDark ? AppColors.textPrimaryDark : AppColors.textPrimaryLight;
    final secondaryText = isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight;
    final cardColor = isDark ? AppColors.cardDark : AppColors.cardLight;
    final borderColor = isDark ? AppColors.borderDark : AppColors.borderLight;

    final adminState = ref.watch(adminProvider);
    final vendors = adminState.users.where((u) => u.role == UserRole.vendor).toList();

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: RefreshIndicator(
        onRefresh: () => ref.read(adminProvider.notifier).loadAllUsers(),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 10),
              child: Text('Vendor Account Registrations', style: AppTextStyles.h2(primaryText)),
            ),
            Expanded(
              child: adminState.isLoading
                  ? const Center(child: CircularProgressIndicator(color: AppColors.adminColor))
                  : vendors.isEmpty
                      ? const AppEmptyState(
                          icon: Icons.storefront_rounded,
                          title: 'No Registered Vendors',
                          subtitle: 'New merchant applications will show up here.',
                        )
                      : ListView.builder(
                          padding: const EdgeInsets.fromLTRB(16, 0, 16, 100),
                          itemCount: vendors.length,
                          itemBuilder: (context, index) {
                            final vendor = vendors[index];
                            final isApproved = vendor.vendorApproved == true;

                            return Container(
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
                                      Text(vendor.businessName ?? 'Shop Profile', style: AppTextStyles.subtitle(primaryText)),
                                      StatusBadge(
                                        label: isApproved ? 'Approved' : 'Pending',
                                        color: isApproved ? AppColors.success : AppColors.warning,
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 6),
                                  Text('Merchant Partner: ${vendor.fullName}', style: AppTextStyles.bodyMedium(secondaryText)),
                                  Text('Phone: ${vendor.phone} | Email: ${vendor.email}', style: AppTextStyles.bodySmall(secondaryText)),
                                  if (vendor.vendorCategories != null) ...[
                                    const SizedBox(height: 6),
                                    Text('Categories: ${vendor.vendorCategories!.join(', ')}', style: AppTextStyles.caption(AppColors.vendorColor)),
                                  ],
                                  const Divider(height: 20),
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                    children: [
                                      Text('Joined: ${vendor.createdAt.day}/${vendor.createdAt.month}/${vendor.createdAt.year}', style: AppTextStyles.caption(secondaryText)),
                                      if (!isApproved)
                                        ElevatedButton.icon(
                                          style: ElevatedButton.styleFrom(
                                            backgroundColor: AppColors.adminColor,
                                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                                          ),
                                          onPressed: () async {
                                            await ref.read(adminProvider.notifier).approveVendor(vendor.id);
                                            if (context.mounted) {
                                              ScaffoldMessenger.of(context).showSnackBar(
                                                SnackBar(
                                                  content: Text('Approved vendor ${vendor.businessName}!'),
                                                  backgroundColor: AppColors.success,
                                                  behavior: SnackBarBehavior.floating,
                                                ),
                                              );
                                            }
                                          },
                                          icon: const Icon(Icons.check_circle_outline, color: Colors.white, size: 16),
                                          label: const Text('Approve Access', style: TextStyle(color: Colors.white, fontSize: 12)),
                                        )
                                      else
                                        const Text('✅ Verified merchant partner', style: TextStyle(color: AppColors.success, fontSize: 12, fontWeight: FontWeight.bold)),
                                    ],
                                  )
                                ],
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

class _UsersManagementTab extends ConsumerWidget {
  const _UsersManagementTab({required this.isDark});
  final bool isDark;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final primaryText = isDark ? AppColors.textPrimaryDark : AppColors.textPrimaryLight;
    final secondaryText = isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight;
    final cardColor = isDark ? AppColors.cardDark : AppColors.cardLight;
    final borderColor = isDark ? AppColors.borderDark : AppColors.borderLight;

    final adminState = ref.watch(adminProvider);

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: RefreshIndicator(
        onRefresh: () => ref.read(adminProvider.notifier).loadAllUsers(),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 10),
              child: Text('User Management Center', style: AppTextStyles.h2(primaryText)),
            ),
            Expanded(
              child: adminState.isLoading
                  ? const Center(child: CircularProgressIndicator(color: AppColors.adminColor))
                  : ListView.builder(
                      padding: const EdgeInsets.fromLTRB(16, 0, 16, 100),
                      itemCount: adminState.users.length,
                      itemBuilder: (context, index) {
                        final user = adminState.users[index];
                        final isSuspended = !user.isActive;

                        return Container(
                          margin: const EdgeInsets.only(bottom: 12),
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: cardColor,
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(color: borderColor),
                          ),
                          child: Row(
                            children: [
                              CircleAvatar(
                                radius: 24,
                                backgroundColor: user.role == UserRole.admin
                                    ? AppColors.adminColor.withOpacity(0.15)
                                    : (user.role == UserRole.vendor
                                        ? AppColors.vendorColor.withOpacity(0.15)
                                        : AppColors.customerColor.withOpacity(0.15)),
                                child: Text(
                                  user.initials,
                                  style: TextStyle(
                                    color: user.role == UserRole.admin
                                        ? AppColors.adminColor
                                        : (user.role == UserRole.vendor
                                            ? AppColors.vendorColor
                                            : AppColors.customerColor),
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 14),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      children: [
                                        Text(user.fullName, style: AppTextStyles.subtitle(primaryText)),
                                        const SizedBox(width: 6),
                                        Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                          decoration: BoxDecoration(
                                            color: Colors.grey.withOpacity(0.12),
                                            borderRadius: BorderRadius.circular(6),
                                          ),
                                          child: Text(user.role.name.toUpperCase(), style: const TextStyle(fontSize: 8, fontWeight: FontWeight.bold)),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 2),
                                    Text('Email: ${user.email}', style: AppTextStyles.caption(secondaryText)),
                                    Text('Status: ${isSuspended ? "Suspended" : "Active"}', style: TextStyle(color: isSuspended ? AppColors.error : AppColors.success, fontSize: 10)),
                                  ],
                                ),
                              ),
                              if (user.role != UserRole.admin)
                                OutlinedButton(
                                  style: OutlinedButton.styleFrom(
                                    side: BorderSide(color: isSuspended ? AppColors.success : AppColors.error),
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                    padding: const EdgeInsets.symmetric(horizontal: 10),
                                  ),
                                  onPressed: () async {
                                    await ref.read(adminProvider.notifier).toggleUserActive(user.id);
                                    if (context.mounted) {
                                      ScaffoldMessenger.of(context).showSnackBar(
                                        SnackBar(
                                          content: Text('${isSuspended ? "Activated" : "Suspended"} user ${user.fullName}!'),
                                          behavior: SnackBarBehavior.floating,
                                        ),
                                      );
                                    }
                                  },
                                  child: Text(
                                    isSuspended ? 'Activate' : 'Suspend',
                                    style: TextStyle(color: isSuspended ? AppColors.success : AppColors.error, fontSize: 11),
                                  ),
                                )
                            ],
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

class _OrdersMonitoringTab extends ConsumerWidget {
  const _OrdersMonitoringTab({required this.isDark});
  final bool isDark;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final primaryText = isDark ? AppColors.textPrimaryDark : AppColors.textPrimaryLight;
    final secondaryText = isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight;
    final cardColor = isDark ? AppColors.cardDark : AppColors.cardLight;
    final borderColor = isDark ? AppColors.borderDark : AppColors.borderLight;

    final orderState = ref.watch(orderProvider);

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 10),
            child: Text('Live Order Transactions', style: AppTextStyles.h2(primaryText)),
          ),
          Expanded(
            child: orderState.orders.isEmpty
                ? const AppEmptyState(
                    icon: Icons.receipt_long_outlined,
                    title: 'No Completed Orders',
                    subtitle: 'Transaction volumes will appear when orders are confirmed.',
                  )
                : ListView.builder(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 100),
                    itemCount: orderState.orders.length,
                    itemBuilder: (context, index) {
                      final order = orderState.orders[index];
                      final commissionLkr = order.totalPrice * 0.03;

                      return Container(
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
                                Text(order.id, style: AppTextStyles.subtitle(primaryText)),
                                StatusBadge(label: order.status.displayName, color: AppColors.adminColor),
                              ],
                            ),
                            const SizedBox(height: 6),
                            Text('Customer: ${order.customerName} | Partner: ${order.vendorBusinessName}', style: AppTextStyles.bodyMedium(secondaryText)),
                            Text('Transaction Date: ${order.createdAt.day}/${order.createdAt.month}/${order.createdAt.year}', style: AppTextStyles.bodySmall(secondaryText)),
                            const Divider(height: 20),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text('Speedmart Commission (3%):', style: AppTextStyles.caption(secondaryText)),
                                    Text('Rs. ${commissionLkr.toStringAsFixed(2)}', style: AppTextStyles.bodyLarge(AppColors.success).copyWith(fontWeight: FontWeight.bold)),
                                  ],
                                ),
                                Column(
                                  crossAxisAlignment: CrossAxisAlignment.end,
                                  children: [
                                    Text('Order Value:', style: AppTextStyles.caption(secondaryText)),
                                    Text('Rs. ${order.totalPrice.toStringAsFixed(2)}', style: AppTextStyles.subtitle(primaryText)),
                                  ],
                                ),
                              ],
                            ),
                          ],
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}

class _PlatformSettingsTab extends StatelessWidget {
  const _PlatformSettingsTab({required this.isDark});
  final bool isDark;

  @override
  Widget build(BuildContext context) {
    final primaryText = isDark ? AppColors.textPrimaryDark : AppColors.textPrimaryLight;
    final secondaryText = isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight;
    final cardColor = isDark ? AppColors.cardDark : AppColors.cardLight;
    final borderColor = isDark ? AppColors.borderDark : AppColors.borderLight;

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 100),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Platform Configuration', style: AppTextStyles.h2(primaryText)),
            const SizedBox(height: 16),
            
            // Commission Setting Card
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
                      const Icon(Icons.percent_rounded, color: AppColors.adminColor),
                      const SizedBox(width: 12),
                      Text('Platform Commission Rate', style: AppTextStyles.subtitle(primaryText)),
                    ],
                  ),
                  const SizedBox(height: 12),
                  const TextField(
                    controller: null,
                    decoration: InputDecoration(
                      labelText: 'Flat Commission Percentage',
                      hintText: '10%',
                      suffixText: '%',
                      border: OutlineInputBorder(borderRadius: BorderRadius.all(Radius.circular(12))),
                    ),
                    readOnly: true,
                  ),
                  const SizedBox(height: 8),
                  Text('This flat commission applies to every confirmed order to cover delivery operations and system hosting.', style: AppTextStyles.caption(secondaryText)),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // Sri Lankan Location boundaries
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
                      const Icon(Icons.explore_outlined, color: AppColors.adminColor),
                      const SizedBox(width: 12),
                      Text('Sri Lankan Matching Settings', style: AppTextStyles.subtitle(primaryText)),
                    ],
                  ),
                  const SizedBox(height: 12),
                  const TextField(
                    decoration: InputDecoration(
                      labelText: 'Maximum Vendor Search Radius',
                      hintText: '20 km',
                      suffixText: 'km',
                      border: OutlineInputBorder(borderRadius: BorderRadius.all(Radius.circular(12))),
                    ),
                    readOnly: true,
                  ),
                  const SizedBox(height: 8),
                  Text('Speedmart Lanka limits proposal feeds to 20 km to maintain fresh grocery delivery and auto parts shipping timelines.', style: AppTextStyles.caption(secondaryText)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
