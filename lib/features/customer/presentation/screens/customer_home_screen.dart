import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/routes/route_names.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../core/widgets/app_logo.dart';
import '../../../../core/widgets/app_state_widgets.dart';
import '../../../../core/widgets/app_button.dart';
import '../../../../core/widgets/shared_floating_bottom_nav.dart';
import '../../../../core/navigation/bottom_nav_visibility.dart';
import '../../../auth/providers/auth_provider.dart';
import '../../../auth/providers/theme_provider.dart';

import '../../../requests/presentation/screens/request_details_screen.dart';
import '../../../requests/providers/request_provider.dart';
import '../../../requests/models/shopping_request.dart';
import '../../../orders/models/order_model.dart';
import '../../../orders/providers/order_provider.dart';
import '../../../proposals/models/proposal.dart';


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
      ref.read(requestProvider.notifier).loadMyRequests();
      ref.read(orderProvider.notifier).loadCustomerOrders();
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

    // Determine current location from GoRouter.
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

    // Only intercept on customer shell tabs.
    const customerTabs = {
      '/customer',
      '/customer/requests',
      '/customer/orders',
      '/customer/profile',
    };
    if (!customerTabs.contains(location)) return false;

    // Non-home tab: go back to Home tab.
    if (location != RouteNames.customerHome) {
      context.go(RouteNames.customerHome);
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

    // Use GoRouterState directly - guaranteed to rebuild when child route changes
    final shellLocation = GoRouterState.of(context).matchedLocation;

    // Watch central bottom navigation visibility provider
    final showBottomNav = ref.watch(bottomNavVisibilityProvider);

    int currentIndex = 0;
    if (shellLocation == RouteNames.customerRequests) {
      currentIndex = 1;
    } else if (shellLocation == RouteNames.customerOrders) {
      currentIndex = 2;
    } else if (shellLocation == RouteNames.customerProfile) {
      currentIndex = 3;
    }

    // PopScope(canPop: false) suppresses the Android 13 predictive-back
    // swipe preview so the UI doesn't flash a "going back" animation.
    // The actual double-back logic lives in didPopRoute() above.
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
            activeColor: AppColors.customerColor,
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

  Widget _buildHeroStat(String label, String value, IconData icon, Color color, bool isDark) {
    return Column(
      children: [
        Icon(icon, color: color, size: 20),
        const SizedBox(height: 6),
        Text(
          value,
          style: TextStyle(
            color: isDark ? Colors.white : Colors.black,
            fontWeight: FontWeight.bold,
            fontSize: 16,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          label,
          style: TextStyle(
            color: isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight,
            fontSize: 10,
          ),
        ),
      ],
    );
  }

  Widget _buildQuickActionCard(
    BuildContext context,
    String label,
    IconData icon,
    Color color,
    VoidCallback onTap,
    bool isDark,
  ) {
    return Container(
      margin: const EdgeInsets.only(right: 12),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(20),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
            decoration: BoxDecoration(
              color: isDark ? AppColors.cardDark : Colors.white,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: isDark ? AppColors.borderDark : AppColors.borderLight,
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(isDark ? 0.1 : 0.02),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                )
              ],
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: color.withOpacity(0.1),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(icon, color: color, size: 18),
                ),
                const SizedBox(width: 10),
                Text(
                  label,
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 13,
                    color: isDark ? Colors.white : Colors.black,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildTimeline(bool isDark, Color primaryText, Color secondaryText) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: isDark ? AppColors.cardDark : AppColors.cardLight,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: isDark ? AppColors.borderDark : AppColors.borderLight),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.explore_outlined, color: AppColors.customerColor, size: 20),
              const SizedBox(width: 8),
              Text(
                'How It Works',
                style: AppTextStyles.subtitle(primaryText).copyWith(fontWeight: FontWeight.bold),
              ),
            ],
          ),
          const SizedBox(height: 20),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildTimelineStep(1, 'Submit List', 'Add items', Icons.edit_note_rounded, isDark),
              _buildTimelineConnector(isDark),
              _buildTimelineStep(2, 'Get Bids', 'Shop offers', Icons.store_rounded, isDark),
              _buildTimelineConnector(isDark),
              _buildTimelineStep(3, 'Order', 'Pay secure', Icons.check_circle_outline_rounded, isDark),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildTimelineStep(int stepNum, String title, String desc, IconData icon, bool isDark) {
    return Expanded(
      child: Column(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: isDark ? const Color(0xFF0F1A2C) : Colors.grey.shade100,
              border: Border.all(
                color: AppColors.customerColor.withOpacity(0.5),
                width: 1.5,
              ),
              boxShadow: [
                BoxShadow(
                  color: AppColors.customerColor.withOpacity(0.08),
                  blurRadius: 8,
                  spreadRadius: 1,
                )
              ],
            ),
            child: Stack(
              alignment: Alignment.center,
              children: [
                Icon(icon, color: AppColors.customerColor, size: 18),
                Positioned(
                  right: 0,
                  top: 0,
                  child: Container(
                    padding: const EdgeInsets.all(4),
                    decoration: const BoxDecoration(
                      color: AppColors.customerColor,
                      shape: BoxShape.circle,
                    ),
                    child: Text(
                      '$stepNum',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 8,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          Text(
            title,
            style: const TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 11,
            ),
            textAlign: TextAlign.center,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 2),
          Text(
            desc,
            style: const TextStyle(
              color: Colors.grey,
              fontSize: 9,
            ),
            textAlign: TextAlign.center,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }

  Widget _buildTimelineConnector(bool isDark) {
    return Container(
      width: 16,
      margin: const EdgeInsets.only(top: 22),
      height: 1.5,
      child: Row(
        children: List.generate(
          2,
          (index) => Expanded(
            child: Container(
              margin: const EdgeInsets.symmetric(horizontal: 1.5),
              height: 1.5,
              color: AppColors.customerColor.withOpacity(0.3),
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(currentUserProvider);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primaryText = isDark ? AppColors.textPrimaryDark : AppColors.textPrimaryLight;
    final secondaryText = isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight;
    
    final requestState = ref.watch(requestProvider);
    final orderState = ref.watch(orderProvider);

    // Live counts
    final activeRequestsCount = requestState.requests
        .where((r) => r.status == RequestStatus.submitted || 
                      r.status == RequestStatus.waitingForVendor || 
                      r.status == RequestStatus.vendorAccepted || 
                      r.status == RequestStatus.proposalSubmitted)
        .length;
    final activeOrdersCount = orderState.orders
        .where((o) => o.status != OrderStatus.delivered && o.status != OrderStatus.cancelled)
        .length;
    final deliveredOrdersCount = orderState.orders
        .where((o) => o.status == OrderStatus.delivered)
        .length;

    return SingleChildScrollView(
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Premium Hero Card ──────────────────────────────────────────
          Container(
            width: double.infinity,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: isDark 
                    ? [const Color(0xFF0F1A2C), const Color(0xFF0A0E1A)] 
                    : [Colors.white, const Color(0xFFF5F7FA)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(24),
              border: Border.all(
                color: isDark ? AppColors.borderDark : AppColors.borderLight,
              ),
              boxShadow: [
                BoxShadow(
                  color: AppColors.customerColor.withOpacity(isDark ? 0.08 : 0.04),
                  blurRadius: 24,
                  offset: const Offset(0, 10),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Top Welcome Row
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 20, 20, 16),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Text(
                                'Ayubowan, ',
                                style: AppTextStyles.bodyMedium(secondaryText),
                              ),
                              Text(
                                '${user?.firstName ?? 'Customer'} 👋',
                                style: AppTextStyles.bodyMedium(AppColors.customerColor).copyWith(
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'What do you need today?',
                            style: AppTextStyles.h2(primaryText).copyWith(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                      // Glowing User Profile Initials Avatar
                      Container(
                        width: 40,
                        height: 40,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          gradient: const LinearGradient(
                            colors: [AppColors.customerColor, AppColors.customerColorDark],
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: AppColors.customerColor.withOpacity(0.3),
                              blurRadius: 10,
                              offset: const Offset(0, 4),
                            )
                          ],
                        ),
                        child: Center(
                          child: Text(
                            user?.initials ?? 'C',
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                              fontSize: 14,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                // Connected Quick Stats (3 Columns)
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    decoration: BoxDecoration(
                      color: isDark ? Colors.black26 : Colors.grey.shade50,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: isDark ? AppColors.borderDark.withOpacity(0.5) : AppColors.borderLight.withOpacity(0.5),
                      ),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceAround,
                      children: [
                        _buildHeroStat('Active List', '$activeRequestsCount', Icons.receipt_long_rounded, AppColors.customerColor, isDark),
                        _buildHeroStat('Active Orders', '$activeOrdersCount', Icons.local_shipping_rounded, AppColors.info, isDark),
                        _buildHeroStat('Delivered', '$deliveredOrdersCount', Icons.verified_rounded, AppColors.success, isDark),
                      ],
                    ),
                  ),
                ),

                const SizedBox(height: 16),

                // Primary Create Request Button
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
                  child: InkWell(
                    onTap: () => context.push(RouteNames.customerCreateRequest),
                    borderRadius: BorderRadius.circular(16),
                    child: Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [AppColors.customerColor, AppColors.customerColorDark],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        borderRadius: BorderRadius.circular(16),
                        boxShadow: [
                          BoxShadow(
                            color: AppColors.customerColor.withOpacity(isDark ? 0.3 : 0.2),
                            blurRadius: 15,
                            offset: const Offset(0, 6),
                          ),
                        ],
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(Icons.add_rounded, color: Colors.white, size: 20),
                          const SizedBox(width: 8),
                          Text(
                            'Create Shopping Request',
                            style: AppTextStyles.button(Colors.white).copyWith(
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                              letterSpacing: 0.2,
                            ),
                          ),
                          const SizedBox(width: 6),
                          const Icon(Icons.arrow_forward_rounded, color: Colors.white70, size: 16),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),

          // ── Quick Actions Section ──────────────────────────────────────
          Text('Quick Actions', style: AppTextStyles.h2(primaryText)),
          const SizedBox(height: 12),
          SizedBox(
            height: 54,
            child: ListView(
              scrollDirection: Axis.horizontal,
              physics: const BouncingScrollPhysics(),
              children: [
                _buildQuickActionCard(
                  context,
                  'New Request',
                  Icons.post_add_rounded,
                  AppColors.customerColor,
                  () => context.push(RouteNames.customerCreateRequest),
                  isDark,
                ),
                _buildQuickActionCard(
                  context,
                  'Track Orders',
                  Icons.local_shipping_rounded,
                  AppColors.info,
                  () => context.go(RouteNames.customerOrders),
                  isDark,
                ),
                _buildQuickActionCard(
                  context,
                  'My Lists',
                  Icons.analytics_rounded,
                  AppColors.accent,
                  () => context.go(RouteNames.customerRequests),
                  isDark,
                ),
                _buildQuickActionCard(
                  context,
                  'Alerts',
                  Icons.notifications_active_rounded,
                  AppColors.warning,
                  () {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('All security channels and notification relays are running live.'),
                        behavior: SnackBarBehavior.floating,
                      ),
                    );
                  },
                  isDark,
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),

          // ── How It Works Timeline ──────────────────────────────────────
          _buildTimeline(isDark, primaryText, secondaryText),
          const SizedBox(height: 28),

          // ── Recent Activity / Requests Section ─────────────────────────
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Recent Activity', style: AppTextStyles.h2(primaryText)),
              if (requestState.requests.isNotEmpty)
                TextButton(
                  onPressed: () => context.go(RouteNames.customerRequests),
                  child: Row(
                    children: [
                      Text(
                        'View All',
                        style: AppTextStyles.button(AppColors.customerColor),
                      ),
                      const SizedBox(width: 4),
                      const Icon(Icons.arrow_forward_ios_rounded, size: 10, color: AppColors.customerColor),
                    ],
                  ),
                ),
            ],
          ),
          const SizedBox(height: 12),

          if (requestState.requests.isEmpty)
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: isDark ? AppColors.cardDark : AppColors.cardLight,
                borderRadius: BorderRadius.circular(24),
                border: Border.all(color: isDark ? AppColors.borderDark : AppColors.borderLight),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(isDark ? 0.2 : 0.02),
                    blurRadius: 15,
                    offset: const Offset(0, 6),
                  ),
                ],
              ),
              child: Column(
                children: [
                  Container(
                    width: 72,
                    height: 72,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: AppColors.customerColor.withOpacity(0.08),
                    ),
                    child: Center(
                      child: TweenAnimationBuilder<double>(
                        tween: Tween(begin: 0.0, end: 1.0),
                        duration: const Duration(seconds: 1),
                        builder: (context, value, child) {
                          return Transform.scale(
                            scale: 0.9 + (value * 0.1),
                            child: child,
                          );
                        },
                        child: const Icon(
                          Icons.shopping_basket_rounded,
                          color: AppColors.customerColor,
                          size: 32,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Your shopping journey starts here.',
                    style: AppTextStyles.subtitle(primaryText).copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Create your first request and nearby vendors will respond.',
                    style: AppTextStyles.caption(secondaryText),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 20),
                  SizedBox(
                    width: double.infinity,
                    child: AppButton(
                      label: 'Create Your First Request',
                      onPressed: () => context.push(RouteNames.customerCreateRequest),
                      color: AppColors.customerColor,
                    ),
                  ),
                ],
              ),
            )
          else
            ListView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: requestState.requests.length > 2 ? 2 : requestState.requests.length,
              itemBuilder: (context, index) {
                final request = requestState.requests[index];
                final statusColor = request.status == RequestStatus.submitted
                    ? AppColors.warning
                    : (request.status == RequestStatus.delivered ? AppColors.success : AppColors.customerColor);
                
                return Container(
                  margin: const EdgeInsets.only(bottom: 12),
                  decoration: BoxDecoration(
                    color: isDark ? AppColors.cardDark : AppColors.cardLight,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: isDark ? AppColors.borderDark : AppColors.borderLight,
                    ),
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(20),
                    child: InkWell(
                      onTap: () {
                        Navigator.of(context, rootNavigator: true).push(
                          MaterialPageRoute(
                            builder: (context) => RequestDetailsScreen(request: request),
                          ),
                        );
                      },
                      child: Padding(
                        padding: const EdgeInsets.all(16.0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  request.id,
                                  style: AppTextStyles.labelLarge(primaryText).copyWith(fontWeight: FontWeight.bold),
                                ),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                  decoration: BoxDecoration(
                                    color: statusColor.withOpacity(0.1),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Text(
                                    request.status.displayName,
                                    style: AppTextStyles.labelSmall(statusColor).copyWith(fontWeight: FontWeight.bold),
                                  ),
                                ),
                              ],
                            ),
                            const Divider(height: 20),
                            Row(
                              children: [
                                const Icon(Icons.shopping_bag_outlined, color: AppColors.customerColor, size: 16),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    request.items.map((i) => i.name).join(', '),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: AppTextStyles.bodyMedium(primaryText).copyWith(fontWeight: FontWeight.w500),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            Row(
                              children: [
                                const Icon(Icons.location_on_outlined, color: Colors.grey, size: 16),
                                const SizedBox(width: 8),
                                Text(
                                  request.customerArea,
                                  style: AppTextStyles.caption(secondaryText),
                                ),
                                const Spacer(),
                                Text(
                                  '${request.createdAt.day}/${request.createdAt.month} • ${request.createdAt.hour}:${request.createdAt.minute.toString().padLeft(2, '0')}',
                                  style: AppTextStyles.caption(secondaryText),
                                ),
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
        ],
      ),
    );
  }
}

// ── Customer Orders Tab ──────────────────────────────────────────────────
class CustomerOrdersTab extends ConsumerWidget {
  const CustomerOrdersTab({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primaryText = isDark ? AppColors.textPrimaryDark : AppColors.textPrimaryLight;
    final secondaryText = isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight;
    final cardColor = isDark ? AppColors.cardDark : AppColors.cardLight;
    final borderColor = isDark ? AppColors.borderDark : AppColors.borderLight;

    final orderState = ref.watch(orderProvider);

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: RefreshIndicator(
        onRefresh: () => ref.read(orderProvider.notifier).loadCustomerOrders(),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 10),
              child: Text('My Active Orders', style: AppTextStyles.h2(primaryText)),
            ),
            Expanded(
              child: orderState.isLoading
                  ? const Center(child: CircularProgressIndicator(color: AppColors.customerColor))
                  : orderState.orders.isEmpty
                      ? const AppEmptyState(
                          icon: Icons.shopping_bag_outlined,
                          title: 'No Orders Yet',
                          subtitle: 'Your accepted merchant orders will appear here.',
                        )
                      : ListView.builder(
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          itemCount: orderState.orders.length,
                          itemBuilder: (context, index) {
                            final order = orderState.orders[index];
                            return Container(
                              margin: const EdgeInsets.only(bottom: 12),
                              decoration: BoxDecoration(
                                color: cardColor,
                                borderRadius: BorderRadius.circular(16),
                                border: Border.all(color: borderColor),
                              ),
                              child: InkWell(
                                borderRadius: BorderRadius.circular(16),
                                onTap: () {
                                  context.push('/customer/orders/track', extra: order);
                                },
                                child: Padding(
                                  padding: const EdgeInsets.all(16),
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Row(
                                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                        children: [
                                          Text(order.id, style: AppTextStyles.subtitle(primaryText)),
                                          StatusBadge(
                                            label: order.status.displayName,
                                            color: order.status == OrderStatus.delivered
                                                ? AppColors.success
                                                : AppColors.customerColor,
                                          ),
                                        ],
                                      ),
                                      const SizedBox(height: 8),
                                      Text(
                                        'Merchant: ${order.vendorBusinessName}',
                                        style: AppTextStyles.bodyMedium(secondaryText),
                                      ),
                                      Text(
                                        'Payment: ${order.paymentMethod.displayName} (${order.paymentStatus.name.toUpperCase()})',
                                        style: AppTextStyles.caption(secondaryText),
                                      ),
                                      const Divider(height: 20),
                                      Row(
                                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                        children: [
                                          Text(
                                            '${order.items.where((i) => i.status != ProposalItemStatus.unavailable).length} items',
                                            style: AppTextStyles.caption(secondaryText),
                                          ),
                                          Text(
                                            'Rs. ${order.totalPrice.toStringAsFixed(2)}',
                                            style: AppTextStyles.subtitle(AppColors.customerColor),
                                          ),
                                        ],
                                      ),
                                      const SizedBox(height: 8),
                                      Align(
                                        alignment: Alignment.centerRight,
                                        child: Text(
                                          'Track Order Status →',
                                          style: AppTextStyles.caption(AppColors.customerColor).copyWith(fontWeight: FontWeight.bold),
                                        ),
                                      )
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
