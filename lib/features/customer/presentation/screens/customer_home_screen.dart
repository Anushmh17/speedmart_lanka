import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:speedmart_lanka/core/routes/route_names.dart';
import 'package:speedmart_lanka/core/theme/app_colors.dart';
import 'package:speedmart_lanka/core/theme/app_text_styles.dart';
import 'package:speedmart_lanka/core/theme/app_spacing.dart';
import 'package:speedmart_lanka/core/theme/app_radius.dart';
import 'package:speedmart_lanka/core/widgets/app_logo.dart';
import 'package:speedmart_lanka/core/widgets/theme3/theme3_widgets.dart';
import 'package:speedmart_lanka/core/navigation/bottom_nav_visibility.dart';
import 'package:speedmart_lanka/features/auth/providers/auth_provider.dart';
import 'package:speedmart_lanka/features/auth/providers/theme_provider.dart';
import 'package:speedmart_lanka/features/vendor/providers/nearby_vendors_provider.dart';
import 'package:speedmart_lanka/core/widgets/theme3/request_image_carousel.dart';
import 'package:speedmart_lanka/features/requests/presentation/screens/request_details_screen.dart';
import 'package:speedmart_lanka/features/requests/providers/request_provider.dart';
import 'package:speedmart_lanka/features/requests/models/shopping_request.dart';
import 'package:speedmart_lanka/features/orders/models/order_model.dart';
import 'package:speedmart_lanka/features/orders/providers/order_provider.dart';
import 'package:speedmart_lanka/features/notifications/providers/notification_provider.dart' as notification_feature;
import 'package:speedmart_lanka/shared/models/user_role.dart';

class CustomerHomeScreen extends ConsumerStatefulWidget {
  final Widget child;
  const CustomerHomeScreen({super.key, required this.child});

  @override
  ConsumerState<CustomerHomeScreen> createState() => _CustomerHomeScreenState();
}

class _CustomerHomeScreenState extends ConsumerState<CustomerHomeScreen>
    with WidgetsBindingObserver {
  String? _lastSyncedLocation;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    Future.microtask(() {
      if (!mounted) return;
      final user = ref.read(currentUserProvider);
      if (user?.role != UserRole.customer) {
        debugPrint('[CustomerHome] Skipping customer data load for non-customer user');
        return;
      }
      ref.read(requestProvider.notifier).loadMyRequests();
      ref.read(orderProvider.notifier).loadCustomerOrders();
      // Seed nav visibility immediately on mount — avoids race with postFrameCallback
      final loc = _getTrueLocation(context);
      ref.read(bottomNavVisibilityProvider.notifier).updateLocation(loc);
    });
  }

  bool _isExitDialogShowing = false;

  String _getTrueLocation(BuildContext context) {
    try {
      final String path = GoRouter.of(context).routeInformationProvider.value.uri.path;
      if (path.isNotEmpty) return path;
    } catch (_) {}
    try {
      final String path = GoRouter.of(context).routerDelegate.currentConfiguration.uri.path;
      if (path.isNotEmpty) return path;
    } catch (_) {}
    return RouteNames.customerHome;
  }

  void _showExitDialog(BuildContext context) {
    if (_isExitDialogShowing) return;
    _isExitDialogShowing = true;

    showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (dialogCtx) => AlertDialog(
        title: const Text('Exit SpeedMart Lanka?'),
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
    ).then((confirmed) {
      _isExitDialogShowing = false;
      if (confirmed == true && mounted) {
        SystemNavigator.pop();
      }
    });
  }

  @override
  Future<bool> didPopRoute() async {
    if (!mounted) return false;

    // If profile screen is in edit mode, let it cancel edit instead.
    final cancelEdit = profileEditingNotifier.value;
    if (cancelEdit != null) {
      cancelEdit();
      return true;
    }

    final loc = _getTrueLocation(context);
    final cleanLoc = (loc.endsWith('/') && loc.length > 1)
        ? loc.substring(0, loc.length - 1)
        : loc;

    final isShellTab = cleanLoc == RouteNames.customerHome ||
        cleanLoc == RouteNames.customerRequests ||
        cleanLoc == RouteNames.customerOrders ||
        cleanLoc == RouteNames.customerProfile;

    if (!isShellTab) return false;

    if (cleanLoc != RouteNames.customerHome) {
      context.go(RouteNames.customerHome);
      return true;
    }

    _showExitDialog(context);
    return true;
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }





  Widget _buildBottomNav(BuildContext context, int currentIndex) {
    final user = ref.watch(currentUserProvider);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final profileImageUrl = user?.profileImageUrl;
    final hasLocalImage = profileImageUrl != null &&
        (profileImageUrl.startsWith('/') ||
            profileImageUrl.contains(':\\') ||
            profileImageUrl.contains(':/'));
    final hasNetworkImage = profileImageUrl != null &&
        (profileImageUrl.startsWith('http://') ||
            profileImageUrl.startsWith('https://'));

    ImageProvider? avatarImage;
    if (hasLocalImage) avatarImage = FileImage(File(profileImageUrl));
    else if (hasNetworkImage) avatarImage = NetworkImage(profileImageUrl);

    final activeColor = AppColors.primary;
    final inactiveColor = isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight;
    final isProfileSelected = currentIndex == 3;

    return Padding(
      padding: EdgeInsets.fromLTRB(20, 0, 20, MediaQuery.of(context).padding.bottom + 14),
      child: Container(
        height: 72,
        decoration: BoxDecoration(
          color: isDark ? AppColors.surfaceElevatedDark : Colors.white,
          borderRadius: BorderRadius.circular(32),
          border: Border.all(
            color: isDark
                ? AppColors.borderDark.withValues(alpha: 0.6)
                : AppColors.borderLight.withValues(alpha: 0.8),
          ),
          boxShadow: [
            BoxShadow(
              color: activeColor.withValues(alpha: isDark ? 0.18 : 0.12),
              blurRadius: 24,
              offset: const Offset(0, 6),
            ),
            BoxShadow(
              color: Colors.black.withValues(alpha: isDark ? 0.35 : 0.07),
              blurRadius: 16,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8),
          child: Row(
            children: [
              _navItem(context, icon: Icons.grid_view_rounded, label: 'Home', index: 0, currentIndex: currentIndex, activeColor: activeColor, inactiveColor: inactiveColor, isDark: isDark),
              _navItem(context, icon: Icons.list_alt_rounded, label: 'Lists', index: 1, currentIndex: currentIndex, activeColor: activeColor, inactiveColor: inactiveColor, isDark: isDark),
              _navItem(context, icon: currentIndex == 2 ? Icons.shopping_bag_rounded : Icons.shopping_bag_outlined, label: 'Orders', index: 2, currentIndex: currentIndex, activeColor: activeColor, inactiveColor: inactiveColor, isDark: isDark),
              Expanded(
                child: GestureDetector(
                  onTap: () => context.go(RouteNames.customerProfile),
                  behavior: HitTestBehavior.opaque,
                  child: Center(
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 260),
                      curve: Curves.easeInOut,
                      padding: const EdgeInsets.symmetric(vertical: 7, horizontal: 14),
                      decoration: BoxDecoration(
                        color: isProfileSelected
                            ? activeColor.withValues(alpha: isDark ? 0.18 : 0.11)
                            : Colors.transparent,
                        borderRadius: BorderRadius.circular(22),
                      ),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          CircleAvatar(
                            radius: 11,
                            backgroundColor: isProfileSelected
                                ? activeColor.withValues(alpha: 0.2)
                                : inactiveColor.withValues(alpha: 0.15),
                            backgroundImage: avatarImage,
                            child: avatarImage == null
                                ? Icon(
                                    isProfileSelected ? Icons.person_rounded : Icons.person_outline_rounded,
                                    color: isProfileSelected ? activeColor : inactiveColor,
                                    size: 14,
                                  )
                                : null,
                          ),
                          const SizedBox(height: 3),
                          Text(
                            'Profile',
                            style: TextStyle(
                              color: isProfileSelected ? activeColor : inactiveColor,
                              fontWeight: isProfileSelected ? FontWeight.w700 : FontWeight.w500,
                              fontSize: 10,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _navItem(
    BuildContext context, {
    required IconData icon,
    required String label,
    required int index,
    required int currentIndex,
    required Color activeColor,
    required Color inactiveColor,
    required bool isDark,
  }) {
    final isSelected = currentIndex == index;
    final color = isSelected ? activeColor : inactiveColor;
    return Expanded(
      child: GestureDetector(
        onTap: () {
          switch (index) {
            case 0: context.go(RouteNames.customerHome); break;
            case 1: context.go(RouteNames.customerRequests); break;
            case 2: context.go(RouteNames.customerOrders); break;
          }
        },
        behavior: HitTestBehavior.opaque,
        child: Center(
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 260),
            curve: Curves.easeInOut,
            padding: const EdgeInsets.symmetric(vertical: 7, horizontal: 14),
            decoration: BoxDecoration(
              color: isSelected
                  ? activeColor.withValues(alpha: isDark ? 0.18 : 0.11)
                  : Colors.transparent,
              borderRadius: BorderRadius.circular(22),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(icon, color: color, size: 22),
                const SizedBox(height: 3),
                Text(
                  label,
                  style: TextStyle(
                    color: color,
                    fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                    fontSize: 10,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    // Force rebuild when router location changes so nav visibility updates
    try { GoRouterState.of(context); } catch (_) {}

    final shellLocation = _getTrueLocation(context);

    // Update nav visibility synchronously when location changes — never via
    // postFrameCallback, which can fire with a stale route during auth transitions.
    if (_lastSyncedLocation != shellLocation) {
      _lastSyncedLocation = shellLocation;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          ref.read(bottomNavVisibilityProvider.notifier).updateLocation(shellLocation);
        }
      });
    }

    final showBottomNav = ref.watch(bottomNavVisibilityProvider);
    final notificationState = ref.watch(notification_feature.notificationProvider);
    final unreadCount = notificationState.unreadCount;

    int currentIndex = 0;
    if (shellLocation.startsWith(RouteNames.customerRequests)) {
      currentIndex = 1;
    } else if (shellLocation.startsWith(RouteNames.customerOrders)) {
      currentIndex = 2;
    } else if (shellLocation.startsWith(RouteNames.customerProfile)) {
      currentIndex = 3;
    }

    final cleanLoc = (shellLocation.endsWith('/') && shellLocation.length > 1)
        ? shellLocation.substring(0, shellLocation.length - 1)
        : shellLocation;

    final isStrictShellTab = cleanLoc == RouteNames.customerHome ||
        cleanLoc == RouteNames.customerRequests ||
        cleanLoc == RouteNames.customerOrders ||
        cleanLoc == RouteNames.customerProfile;

    return PopScope(
      canPop: !isStrictShellTab,
      onPopInvokedWithResult: (didPop, _) {
        if (didPop) return;
        if (currentIndex != 0) {
          context.go(RouteNames.customerHome);
          return;
        }
        _showExitDialog(context);
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
                isLabelVisible: unreadCount > 0,
                label: unreadCount > 0 ? Text('$unreadCount') : null,
                child: Icon(
                  Icons.notifications_outlined,
                  color: isDark ? AppColors.textPrimaryDark : AppColors.textPrimaryLight,
                ),
              ),
              onPressed: () async {
                await ref.read(notification_feature.notificationProvider.notifier).loadNotifications();
                if (!context.mounted) return;
                context.push(RouteNames.customerNotifications);
              },
            ),
            const SizedBox(width: 8),
          ],
        ),
        extendBody: true,
        body: widget.child,
        bottomNavigationBar: AnimatedBottomNavWrapper(
            visible: showBottomNav,
            child: _buildBottomNav(context, currentIndex),
          ),
      ),
    );
  }
}

// ── Home Tab ──────────────────────────────────────────────────────────────
class CustomerHomeTab extends ConsumerStatefulWidget {
  const CustomerHomeTab({super.key});

  @override
  ConsumerState<CustomerHomeTab> createState() => _CustomerHomeTabState();
}

class _CustomerHomeTabState extends ConsumerState<CustomerHomeTab> {
  Future<void> _onRefresh() async {
    await Future.wait([
      ref.read(requestProvider.notifier).loadMyRequests(),
      ref.read(orderProvider.notifier).loadCustomerOrders(),
    ]);
  }

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(currentUserProvider);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primaryText = isDark ? AppColors.textPrimaryDark : AppColors.textPrimaryLight;
    final secondaryText = isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight;

    final requestState = ref.watch(requestProvider);
    final orderState = ref.watch(orderProvider);

    return RefreshIndicator(
      onRefresh: _onRefresh,
      color: AppColors.primary,
      child: SingleChildScrollView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(AppSpacing.lg, AppSpacing.lg, AppSpacing.lg, 120),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Premium Header ────────────────────────────────────────────
          _buildHeader(context, user, isDark, primaryText, secondaryText),
          const SizedBox(height: AppSpacing.xl),

          // ── Premium Hero Action Card ──────────────────────────────────
          _buildHeroActionCard(context, isDark),
          const SizedBox(height: AppSpacing.lg),

          // ── Vendor Activity Banner ────────────────────────────────────
          _buildVendorActivityBanner(isDark, primaryText, secondaryText, ref),
          const SizedBox(height: AppSpacing.lg),

          // ── Quick Actions Row (Compact) ───────────────────────────────
          _buildQuickActionsRow(context, isDark, primaryText, secondaryText),
          const SizedBox(height: AppSpacing.xxxl),

          // ── Recent Requests Section ───────────────────────────────────
          if (requestState.isLoading && requestState.requests.isEmpty)
            _buildSectionSkeleton('Recent Requests', isDark, primaryText, secondaryText)
          else
            _buildRecentRequestsSection(context, ref, requestState, isDark, primaryText, secondaryText),
          const SizedBox(height: 44),

          // ── Recent Orders Section ─────────────────────────────────────
          if (orderState.isLoading && orderState.orders.isEmpty)
            _buildSectionSkeleton('Recent Orders', isDark, primaryText, secondaryText)
          else
            _buildRecentOrdersSection(context, ref, orderState, isDark, primaryText, secondaryText),
          const SizedBox(height: AppSpacing.lg),
        ],
      ),
    ),
    );
  }

  Widget _buildSectionSkeleton(String title, bool isDark, Color primaryText, Color secondaryText) {
    final shimmerBase = isDark ? AppColors.cardDark : AppColors.cardLight;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: AppTextStyles.h2(primaryText)),
        const SizedBox(height: AppSpacing.md),
        ...List.generate(2, (i) => Container(
          margin: const EdgeInsets.only(bottom: AppSpacing.sm),
          height: 80,
          decoration: BoxDecoration(
            color: shimmerBase,
            borderRadius: BorderRadius.circular(AppRadius.lg),
          ),
          child: const Center(child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.primary)),
        )),
      ],
    );
  }

  Widget _buildHeader(BuildContext context, dynamic user, bool isDark, Color primaryText, Color secondaryText) {
    final primaryColor = isDark ? AppColors.primaryDark : AppColors.primary;
    final profileImageUrl = user?.profileImageUrl as String?;
    final hasLocalImage = profileImageUrl != null &&
        (profileImageUrl.startsWith('/') ||
            profileImageUrl.contains(':\\') ||
            profileImageUrl.contains(':/'));
    final hasNetworkImage = profileImageUrl != null &&
        (profileImageUrl.startsWith('http://') ||
            profileImageUrl.startsWith('https://'));

    ImageProvider? avatarImage;
    if (hasLocalImage) {
      avatarImage = FileImage(File(profileImageUrl));
    } else if (hasNetworkImage) {
      avatarImage = NetworkImage(profileImageUrl);
    }

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Welcome, ${user?.firstName ?? 'Customer'}',
              style: TextStyle(
                fontSize: 26,
                fontWeight: FontWeight.w700,
                color: primaryText,
                fontFamily: 'SF Pro',
                fontFamilyFallback: const ['San Francisco', '.SF Pro Text', 'sans-serif'],
              ),
            ),
            const SizedBox(height: 5),
            Text(
              _formatDate(DateTime.now()),
              style: AppTextStyles.bodySmall(secondaryText),
            ),
          ],
        ),
        GestureDetector(
          onTap: () => _showProfilePreview(context, user, avatarImage, primaryColor),
          child: CircleAvatar(
            radius: 24,
            backgroundColor: primaryColor.withValues(alpha: 0.15),
            backgroundImage: avatarImage,
            child: avatarImage == null
                ? Text(
                    user?.initials ?? 'C',
                    style: AppTextStyles.h3(primaryColor),
                  )
                : null,
          ),
        ),
      ],
    );
  }

  void _showProfilePreview(BuildContext context, dynamic user, ImageProvider? avatarImage, Color primaryColor) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bgColor = isDark ? AppColors.surfaceDark : AppColors.surfaceLight;
    final primaryText = isDark ? AppColors.textPrimaryDark : AppColors.textPrimaryLight;
    final secondaryText = isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight;
    final borderColor = isDark ? AppColors.borderDark : AppColors.borderLight;

    showDialog(
      context: context,
      builder: (ctx) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        backgroundColor: Colors.transparent,
        elevation: 0,
        child: Container(
          decoration: BoxDecoration(
            color: bgColor,
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: isDark ? 0.5 : 0.18),
                blurRadius: 32,
                spreadRadius: 0,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // ── Header band with avatar ──────────────────────────────
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 28),
                decoration: BoxDecoration(
                  color: primaryColor.withValues(alpha: isDark ? 0.18 : 0.08),
                  borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
                  border: Border(
                    bottom: BorderSide(color: primaryColor.withValues(alpha: 0.15), width: 1),
                  ),
                ),
                child: Column(
                  children: [
                    GestureDetector(
                      onTap: avatarImage == null ? null : () {
                        showDialog(
                          context: ctx,
                          builder: (imgCtx) => Dialog(
                            backgroundColor: Colors.black,
                            insetPadding: EdgeInsets.zero,
                            child: Stack(
                              children: [
                                InteractiveViewer(
                                  child: SizedBox(
                                    width: double.infinity,
                                    height: double.infinity,
                                    child: Image(image: avatarImage, fit: BoxFit.contain),
                                  ),
                                ),
                                Positioned(
                                  top: 48,
                                  right: 12,
                                  child: GestureDetector(
                                    onTap: () => Navigator.of(imgCtx).pop(),
                                    child: Container(
                                      padding: const EdgeInsets.all(6),
                                      decoration: BoxDecoration(
                                        color: Colors.black.withValues(alpha: 0.5),
                                        shape: BoxShape.circle,
                                      ),
                                      child: const Icon(Icons.close, color: Colors.white, size: 20),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                      child: Container(
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          border: Border.all(color: primaryColor.withValues(alpha: 0.35), width: 3),
                          boxShadow: [
                            BoxShadow(
                              color: primaryColor.withValues(alpha: 0.2),
                              blurRadius: 16,
                              spreadRadius: 2,
                            ),
                          ],
                        ),
                        child: Stack(
                          alignment: Alignment.bottomRight,
                          children: [
                            CircleAvatar(
                              radius: 44,
                              backgroundColor: primaryColor.withValues(alpha: 0.15),
                              backgroundImage: avatarImage,
                              child: avatarImage == null
                                  ? Text(
                                      user?.initials ?? 'C',
                                      style: TextStyle(
                                        fontSize: 32,
                                        fontWeight: FontWeight.w700,
                                        color: primaryColor,
                                      ),
                                    )
                                  : null,
                            ),
                            if (avatarImage != null)
                              Container(
                                padding: const EdgeInsets.all(3),
                                decoration: const BoxDecoration(
                                  color: Colors.black54,
                                  shape: BoxShape.circle,
                                ),
                                child: const Icon(Icons.zoom_in, color: Colors.white, size: 14),
                              ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 14),
                    Text(
                      user?.fullName ?? 'Customer',
                      style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700, color: primaryText),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      user?.email ?? '',
                      style: TextStyle(fontSize: 12, color: secondaryText),
                    ),
                  ],
                ),
              ),
              // ── Info row ─────────────────────────────────────────────
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                child: Row(
                  children: [
                    Icon(Icons.phone_outlined, size: 14, color: secondaryText),
                    const SizedBox(width: 6),
                    Text(
                      user?.phone ?? 'No phone added',
                      style: TextStyle(fontSize: 13, color: secondaryText),
                    ),
                    const Spacer(),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: AppColors.success.withValues(alpha: 0.12),
                        border: Border.all(color: AppColors.success.withValues(alpha: 0.3)),
                      ),
                      child: Text(
                        'Customer',
                        style: TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: AppColors.success),
                      ),
                    ),
                  ],
                ),
              ),
              Divider(color: borderColor, height: 1),
              // ── Buttons ───────────────────────────────────────────────
              IntrinsicHeight(
                child: Row(
                  children: [
                    Expanded(
                      child: TextButton(
                        onPressed: () => Navigator.of(ctx).pop(),
                        style: TextButton.styleFrom(
                          foregroundColor: secondaryText,
                          shape: const RoundedRectangleBorder(borderRadius: BorderRadius.only(bottomLeft: Radius.circular(16))),
                          padding: const EdgeInsets.symmetric(vertical: 16),
                        ),
                        child: const Text('Cancel', style: TextStyle(fontWeight: FontWeight.w600)),
                      ),
                    ),
                    VerticalDivider(color: borderColor, width: 1),
                    Expanded(
                      child: TextButton(
                        onPressed: () {
                          Navigator.of(ctx).pop();
                          context.go(RouteNames.customerProfile);
                        },
                        style: TextButton.styleFrom(
                          foregroundColor: primaryColor,
                          shape: const RoundedRectangleBorder(borderRadius: BorderRadius.only(bottomRight: Radius.circular(16))),
                          padding: const EdgeInsets.symmetric(vertical: 16),
                        ),
                        child: const Text('View Profile', style: TextStyle(fontWeight: FontWeight.w700)),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeroActionCard(BuildContext context, bool isDark) {
    return Container(
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFFF59E0B), Color(0xFFFF6B00)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(26),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFFF59E0B).withValues(alpha: 0.38),
            blurRadius: 22,
            spreadRadius: 0,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Left: text + button
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Privacy badge
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.22),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.lock_rounded,
                            size: 11, color: Colors.white),
                        const SizedBox(width: 4),
                        Text(
                          'Shop identity hidden until payment',
                          style: AppTextStyles.caption(Colors.white).copyWith(
                            fontSize: 9.5,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    'Post What You Need',
                    style: AppTextStyles.h2(Colors.white).copyWith(
                      fontWeight: FontWeight.w800,
                      fontSize: 18,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Compare proposals safely.\nVendor details unlock after payment.',
                    style: AppTextStyles.bodySmall(
                            Colors.white.withValues(alpha: 0.88))
                        .copyWith(height: 1.4),
                  ),
                  const SizedBox(height: 16),
                  // White pill button
                  GestureDetector(
                    onTap: () =>
                        context.push(RouteNames.customerCreateRequest),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 18, vertical: 10),
                      decoration: BoxDecoration(
                        color: isDark ? Colors.white : const Color(0xFFE6FFFF),
                        borderRadius: BorderRadius.circular(24),
                        boxShadow: [
                          BoxShadow(
                            color:
                                Colors.blue.withValues(alpha: 0.10),
                            blurRadius: 8,
                            offset: const Offset(0, 3),
                          ),
                        ],
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.add_rounded,
                              size: 16,
                              color: isDark ? const Color(0xFFF59E0B) : const Color(0xFFF59E0B)),
                          const SizedBox(width: 6),
                          Text(
                            'Create Request',
                            style: AppTextStyles.labelMedium(
                                    const Color(0xFFF59E0B))
                                .copyWith(fontWeight: FontWeight.w700),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            // Right: decorative illustration
            Column(
              children: [
                Container(
                  width: 64,
                  height: 64,
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.18),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.storefront_rounded,
                    size: 32,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 8),
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.13),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.local_shipping_rounded,
                    size: 22,
                    color: Colors.white,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildVendorActivityBanner(bool isDark, Color primaryText, Color secondaryText, WidgetRef ref) {
    return Theme3AppCard(
      type: Theme3CardType.standard,
      padding: const EdgeInsets.all(AppSpacing.lg),
      child: Row(
        children: [
          SizedBox(
            width: 88,
            height: 40,
            child: Stack(
              clipBehavior: Clip.none,
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
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                ref.watch(nearbyActiveVendorCountProvider).when(
                  data: (count) => Text(
                    count == 0
                        ? 'No Active Vendors Nearby'
                        : '$count Active Vendor${count == 1 ? '' : 's'} Nearby',
                    style: AppTextStyles.labelLarge(primaryText),
                  ),
                  loading: () => Text(
                    'Finding vendors nearby...',
                    style: AppTextStyles.labelLarge(primaryText),
                  ),
                  error: (_, __) => Text(
                    'No Active Vendors Nearby',
                    style: AppTextStyles.labelLarge(primaryText),
                  ),
                ),
                const SizedBox(height: 2),
                ref.watch(nearbyActiveVendorCountProvider).when(
                  data: (count) => Text(
                    count == 0
                        ? 'Set your delivery location to find vendors'
                        : 'Ready to fulfill your requests',
                    style: AppTextStyles.caption(secondaryText),
                  ),
                  loading: () => Text('Ready to fulfill your requests', style: AppTextStyles.caption(secondaryText)),
                  error: (_, __) => Text('Set your delivery location to find vendors', style: AppTextStyles.caption(secondaryText)),
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
      ('Categories', Icons.category_outlined, () => context.push(RouteNames.customerCreateRequest, extra: {'openCategoryPicker': true}), const Color(0xFF8B5CF6)),
      ('Orders', Icons.shopping_bag_outlined, () => context.go(RouteNames.customerOrders), const Color(0xFF0EA5E9)),
      ('Offers', Icons.local_offer_outlined, () => context.go(RouteNames.customerRequests), const Color(0xFF10B981)),
      ('Messages', Icons.mail_outline_rounded, () => context.push('/chats'), const Color(0xFFF59E0B)),
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
                        color: action.$4,
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
    const orderStatuses = {
      RequestStatus.paid,
      RequestStatus.cashOnDeliveryConfirmed,
      RequestStatus.preparingOrder,
      RequestStatus.readyForDelivery,
      RequestStatus.outForDelivery,
      RequestStatus.delivered,
    };
    final activeRequests = (requestState.requests as List<ShoppingRequest>)
        .where((r) => !orderStatuses.contains(r.status))
        .toList();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text('Recent Requests', style: AppTextStyles.h2(primaryText)),
            if (activeRequests.isNotEmpty)
              TextButton(
                onPressed: () => context.go(RouteNames.customerRequests),
                style: TextButton.styleFrom(padding: EdgeInsets.zero, minimumSize: Size.zero, tapTargetSize: MaterialTapTargetSize.shrinkWrap),
                child: Text(
                  'View All →',
                  style: AppTextStyles.labelMedium(isDark ? AppColors.primaryDark : AppColors.primary),
                ),
              ),
          ],
        ),
        const SizedBox(height: AppSpacing.md),
        if (activeRequests.isEmpty)
          Theme3EmptyState(
            icon: Icons.shopping_basket_rounded,
            title: 'No Requests Yet',
            subtitle: 'Create your first request to get started',
          )
        else
          ListView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            padding: EdgeInsets.zero,
            itemCount: activeRequests.length > 4 ? 4 : activeRequests.length,
            itemBuilder: (context, index) {
              final request = activeRequests[index];
              final statusType = request.status == RequestStatus.submitted
                  ? Theme3StatusType.pending
                  : (request.status == RequestStatus.delivered ? Theme3StatusType.completed : Theme3StatusType.inProgress);
              
              final primaryCategory = request.categories.isNotEmpty ? request.categories.first : '';
              final proposalCount = request.categoryFulfillments.length;
              final requestImages = _getRequestImages(request);
              
              return Theme3AppCard(
                onTap: () {
                  Navigator.of(context, rootNavigator: true).push(
                    MaterialPageRoute(
                      builder: (context) => RequestDetailsScreen(request: request),
                    ),
                  );
                },
                padding: const EdgeInsets.all(AppSpacing.md),
                margin: index < (activeRequests.length > 4 ? 3 : activeRequests.length - 1)
                    ? const EdgeInsets.only(bottom: AppSpacing.sm)
                    : EdgeInsets.zero,
                child: Row(
                  children: [
                    // LEFT: Smart Thumbnail (Customer Image or Category Icon)
                    _buildRequestCarousel(
                      images: requestImages,
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
                          Row(
                            children: [
                              Expanded(
                                child: Text(
                                  request.isMultiCategory
                                      ? 'Multiple Category Order'
                                      : (request.items.isNotEmpty ? request.items.first.name : 'Request'),
                                  style: AppTextStyles.labelLarge(primaryText).copyWith(
                                    fontWeight: request.isMultiCategory ? FontWeight.bold : FontWeight.w600,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              if (request.isMultiCategory) ...[
                                const SizedBox(width: 6),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                  decoration: BoxDecoration(
                                    gradient: const LinearGradient(
                                      colors: [Color(0xFF7C3AED), Color(0xFF9D4EDD)],
                                    ),
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                  child: const Text(
                                    'Mixed',
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontSize: 9,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                              ],
                            ],
                          ),
                          const SizedBox(height: 2),
                          _CategoryChips(categories: request.categories, secondaryText: secondaryText),
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
                style: TextButton.styleFrom(padding: EdgeInsets.zero, minimumSize: Size.zero, tapTargetSize: MaterialTapTargetSize.shrinkWrap),
                child: Text(
                  'View All →',
                  style: AppTextStyles.labelMedium(isDark ? AppColors.primaryDark : AppColors.primary),
                ),
              ),
          ],
        ),
        const SizedBox(height: AppSpacing.sm),
        if (orderState.orders.isEmpty)
          Theme3EmptyState(
            icon: Icons.shopping_bag_outlined,
            title: 'No Orders Yet',
            subtitle: 'Your accepted shop owner orders will appear here.',
          )
        else
          ListView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: orderState.orders.length > 5 ? 5 : orderState.orders.length,
            itemBuilder: (context, index) {
              final order = orderState.orders[index];
              final orderStatusType = order.status == OrderStatus.delivered
                  ? Theme3StatusType.completed
                  : (order.status == OrderStatus.cancelled ? Theme3StatusType.cancelled : Theme3StatusType.inProgress);
              
              final primaryCategory = _getOrderPrimaryCategory(order);
              final statusColor = _getOrderStatusColor(order.status);
              final orderImages = _getOrderImages(order, ref);
              
              return Theme3AppCard(
                onTap: () => context.push('/customer/orders/track', extra: order),
                padding: const EdgeInsets.all(AppSpacing.md),
                margin: index < (orderState.orders.length > 5 ? 4 : orderState.orders.length - 1)
                    ? const EdgeInsets.only(bottom: AppSpacing.sm)
                    : EdgeInsets.zero,
                child: Row(
                  children: [
                    // LEFT: Smart Order Thumbnail
                    _buildRequestCarousel(
                      images: orderImages,
                      category: primaryCategory,
                      size: 64,
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

  /// Collect all non-empty images across all items in a request.
  List<String> _getRequestImages(ShoppingRequest request) {
    final images = <String>[];
    for (final item in request.items) {
      for (final url in item.imageUrls) {
        final t = url.trim();
        if (t.isNotEmpty) images.add(t);
      }
    }
    return images;
  }

  /// Collect all non-empty images from an order (vendor images first, then request images).
  List<String> _getOrderImages(OrderModel order, WidgetRef ref) {
    final images = <String>[];
    for (final item in order.items) {
      final url = item.imageUrl?.trim() ?? '';
      if (url.isNotEmpty) images.add(url);
    }
    if (images.isEmpty) {
      final requestState = ref.read(requestProvider);
      try {
        final request = requestState.requests.firstWhere((r) => r.id == order.requestId);
        images.addAll(_getRequestImages(request));
      } catch (_) {}
    }
    return images;
  }

  /// Build a carousel thumbnail for requests.
  Widget _buildRequestCarousel({
    required List<String> images,
    required String category,
    required double size,
    required bool isDark,
    Color? statusColor,
  }) {
    final normalized = category.toLowerCase().trim().replaceAll(' ', '_');
    final categoryColor = statusColor ?? _getRequestCategoryColor(normalized);
    final categoryIcon = _getRequestCategoryIcon(normalized);
    final iconFallback = Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: categoryColor.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(AppRadius.md),
        border: Border.all(color: categoryColor.withValues(alpha: 0.35), width: 1),
      ),
      child: Icon(categoryIcon, color: categoryColor, size: size * 0.47),
    );
    return RequestImageCarousel(images: images, fallback: iconFallback, size: size);
  }

  Color _getRequestCategoryColor(String normalized) {
    if (normalized.isEmpty) return const Color(0xFFF59E0B);
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
    if (normalized.isEmpty) return Icons.inventory_2_rounded;
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
    const days = ['Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday', 'Sunday'];
    const months = ['January', 'February', 'March', 'April', 'May', 'June', 'July', 'August', 'September', 'October', 'November', 'December'];
    final dayName = days[date.weekday - 1];
    final monthName = months[date.month - 1];
    return '$dayName, ${date.day} $monthName ${date.year}';
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

// ── Category chips with +N overflow ─────────────────────────────────────
class _CategoryChips extends StatelessWidget {
  const _CategoryChips({required this.categories, required this.secondaryText});
  final List<String> categories;
  final Color secondaryText;

  static const int _maxVisible = 2;

  @override
  Widget build(BuildContext context) {
    if (categories.isEmpty) {
      return Text('GENERAL', style: AppTextStyles.caption(secondaryText));
    }
    final visible = categories.take(_maxVisible).toList();
    final overflow = categories.length - _maxVisible;
    return Wrap(
      spacing: 4,
      runSpacing: 2,
      children: [
        ...visible.map((cat) => _chip(cat, secondaryText)),
        if (overflow > 0) _chip('+$overflow more', secondaryText),
      ],
    );
  }

  Widget _chip(String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        label.replaceAll('_', ' ').toUpperCase(),
        style: AppTextStyles.caption(color).copyWith(fontSize: 9),
      ),
    );
  }
}

// ── Customer Orders Tab ──────────────────────────────────────────────────
class CustomerOrdersTab extends ConsumerWidget {
  const CustomerOrdersTab({super.key});

  List<String> _getOrderImages(OrderModel order, WidgetRef ref) {
    final images = <String>[];
    for (final item in order.items) {
      final url = item.imageUrl?.trim() ?? '';
      if (url.isNotEmpty) images.add(url);
    }
    if (images.isEmpty) {
      final requestState = ref.read(requestProvider);
      try {
        final request = requestState.requests.firstWhere((r) => r.id == order.requestId);
        for (final item in request.items) {
          for (final url in item.imageUrls) {
            final t = url.trim();
            if (t.isNotEmpty) images.add(t);
          }
        }
      } catch (_) {}
    }
    return images;
  }

  Widget _buildOrderCarousel(OrderModel order, WidgetRef ref) {
    final statusColor = _getOrderStatusColor(order.status);
    final category = _getOrderPrimaryCategory(order);
    final images = _getOrderImages(order, ref);
    const size = 56.0;
    final iconFallback = Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: statusColor.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(AppRadius.md),
      ),
      child: Icon(_getCategoryIcon(category), color: statusColor, size: 28),
    );
    return RequestImageCarousel(images: images, fallback: iconFallback, size: size);
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

    return Scaffold(
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
                                          _buildOrderCarousel(order, ref),
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
    );
  }
}

