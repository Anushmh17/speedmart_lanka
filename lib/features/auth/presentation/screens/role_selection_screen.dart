import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/routes/route_names.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../core/widgets/app_logo.dart';
import '../../../../shared/models/user_role.dart';
import '../../providers/auth_provider.dart';
import '../../customer_registration/providers/customer_registration_provider.dart';

/// Lets the user pick their role before logging in or registering.
class RoleSelectionScreen extends ConsumerStatefulWidget {
  const RoleSelectionScreen({super.key});

  @override
  ConsumerState<RoleSelectionScreen> createState() => _RoleSelectionScreenState();
}

class _RoleSelectionScreenState extends ConsumerState<RoleSelectionScreen>
    with TickerProviderStateMixin {
  late List<AnimationController> _controllers;
  late List<Animation<double>> _fadeAnims;
  late List<Animation<Offset>> _slideAnims;

  @override
  void initState() {
    super.initState();
    _controllers = List.generate(
      3,
      (i) => AnimationController(
        duration: Duration(milliseconds: 400 + i * 100),
        vsync: this,
      ),
    );
    _fadeAnims = _controllers
        .map((c) => CurvedAnimation(parent: c, curve: Curves.easeOut))
        .toList();
    _slideAnims = _controllers
        .map((c) => Tween<Offset>(
              begin: const Offset(0, 0.3),
              end: Offset.zero,
            ).animate(CurvedAnimation(parent: c, curve: Curves.easeOut)))
        .toList();

    // Staggered entrance
    Future.delayed(const Duration(milliseconds: 100), () {
      for (var i = 0; i < _controllers.length; i++) {
        Future.delayed(Duration(milliseconds: i * 80), () {
          if (mounted) _controllers[i].forward();
        });
      }
    });
  }

  @override
  void dispose() {
    for (final c in _controllers) {
      c.dispose();
    }
    super.dispose();
  }

  void _onRoleSelected(UserRole role) {
    ref.read(authProvider.notifier).clearError();
    ref.read(customerRegistrationProvider.notifier).reset();
    switch (role) {
      case UserRole.customer:
        context.go(RouteNames.customerLogin);
        break;
      case UserRole.vendor:
        context.go(RouteNames.vendorLogin);
        break;
      case UserRole.admin:
        context.go(RouteNames.adminLogin);
        break;
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bg = isDark ? AppColors.backgroundDark : AppColors.backgroundLight;

    return Scaffold(
      backgroundColor: bg,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              const SizedBox(height: 48),
              const AppLogo(size: LogoSize.medium, showTagline: true),
              const SizedBox(height: 48),

              // Heading
              Text(
                'Who are you?',
                style: AppTextStyles.h1(
                  isDark ? AppColors.textPrimaryDark : AppColors.textPrimaryLight,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Choose your role to get started',
                style: AppTextStyles.bodyMedium(
                  isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight,
                ),
              ),
              const SizedBox(height: 36),

              // Role cards with staggered animation
              ..._roleCards(isDark),

              const SizedBox(height: 40),
            ],
          ),
        ),
      ),
    );
  }

  List<Widget> _roleCards(bool isDark) {
    final roles = [
      _RoleCardData(
        role: UserRole.customer,
        icon: Icons.shopping_bag_rounded,
        title: 'Customer',
        subtitle: 'Submit shopping requests & get proposals from nearby shops',
        color: AppColors.customerColor,
        containerColor: AppColors.customerContainer,
        gradient: [const Color(0xFF00C07F), const Color(0xFF009965)],
      ),
      _RoleCardData(
        role: UserRole.vendor,
        icon: Icons.storefront_rounded,
        title: 'Vendor',
        subtitle: 'Receive customer requests & submit product proposals',
        color: AppColors.vendorColor,
        containerColor: AppColors.vendorContainer,
        gradient: [const Color(0xFF1A73E8), const Color(0xFF1254B0)],
      ),
      _RoleCardData(
        role: UserRole.admin,
        icon: Icons.admin_panel_settings_rounded,
        title: 'Admin',
        subtitle: 'Monitor and manage the entire Speedmart Lanka platform',
        color: AppColors.adminColor,
        containerColor: AppColors.adminContainer,
        gradient: [const Color(0xFFE8710A), const Color(0xFFB55708)],
      ),
    ];

    return List.generate(roles.length, (i) {
      final data = roles[i];
      return Padding(
        padding: const EdgeInsets.only(bottom: 16),
        child: FadeTransition(
          opacity: _fadeAnims[i],
          child: SlideTransition(
            position: _slideAnims[i],
            child: _RoleCard(data: data, isDark: isDark, onTap: () => _onRoleSelected(data.role)),
          ),
        ),
      );
    });
  }
}

// ── Role Card Data ────────────────────────────────────────────────────────
class _RoleCardData {
  final UserRole role;
  final IconData icon;
  final String title;
  final String subtitle;
  final Color color;
  final Color containerColor;
  final List<Color> gradient;

  const _RoleCardData({
    required this.role,
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.color,
    required this.containerColor,
    required this.gradient,
  });
}

// ── Role Card Widget ──────────────────────────────────────────────────────
class _RoleCard extends StatefulWidget {
  const _RoleCard({
    required this.data,
    required this.isDark,
    required this.onTap,
  });
  final _RoleCardData data;
  final bool isDark;
  final VoidCallback onTap;

  @override
  State<_RoleCard> createState() => _RoleCardState();
}

class _RoleCardState extends State<_RoleCard> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    final cardBg = widget.isDark ? AppColors.cardDark : AppColors.cardLight;
    final border = widget.isDark ? AppColors.borderDark : AppColors.borderLight;

    return GestureDetector(
      onTapDown: (_) => setState(() => _pressed = true),
      onTapUp: (_) {
        setState(() => _pressed = false);
        widget.onTap();
      },
      onTapCancel: () => setState(() => _pressed = false),
      child: AnimatedScale(
        scale: _pressed ? 0.97 : 1.0,
        duration: const Duration(milliseconds: 100),
        child: Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: cardBg,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: border),
            boxShadow: [
              BoxShadow(
                color: widget.data.color.withOpacity(widget.isDark ? 0.12 : 0.08),
                blurRadius: 20,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: Row(
            children: [
              // Icon box
              Container(
                width: 56,
                height: 56,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: widget.data.gradient,
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: widget.data.color.withOpacity(0.35),
                      blurRadius: 12,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Icon(widget.data.icon, color: Colors.white, size: 28),
              ),
              const SizedBox(width: 16),

              // Text
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      widget.data.title,
                      style: AppTextStyles.h3(
                        widget.isDark
                            ? AppColors.textPrimaryDark
                            : AppColors.textPrimaryLight,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      widget.data.subtitle,
                      style: AppTextStyles.bodySmall(
                        widget.isDark
                            ? AppColors.textSecondaryDark
                            : AppColors.textSecondaryLight,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),

              // Arrow
              Icon(
                Icons.arrow_forward_ios_rounded,
                size: 16,
                color: widget.data.color,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
