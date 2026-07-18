import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/routes/route_names.dart';
import '../../../../core/storage/storage_service.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/widgets/app_logo.dart';
import '../../providers/auth_provider.dart';
import '../../../../shared/models/user_role.dart';

/// First screen the app shows.
/// Checks auth state then navigates to the correct destination.
class SplashScreen extends ConsumerStatefulWidget {
  const SplashScreen({super.key});

  @override
  ConsumerState<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends ConsumerState<SplashScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _fadeAnim;
  late Animation<double> _scaleAnim;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 900),
      vsync: this,
    );
    _fadeAnim = CurvedAnimation(parent: _controller, curve: Curves.easeOut);
    _scaleAnim = Tween<double>(begin: 0.85, end: 1.0).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeOutBack),
    );
    _controller.forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Navigate immediately if auth already finished loading
    final isLoading = ref.watch(authLoadingProvider);
    if (!isLoading) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _navigate());
    }

    // Also listen for when auth finishes loading after widget builds
    ref.listen<bool>(authLoadingProvider, (_, nowLoading) {
      if (!nowLoading) _navigate();
    });

    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [Color(0xFF0A1628), Color(0xFF0D2137), Color(0xFF0A1628)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: Stack(
          children: [
            // Background decoration circles
            Positioned(
              top: -80,
              right: -80,
              child: Container(
                width: 280,
                height: 280,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: AppColors.primary.withOpacity(0.08),
                ),
              ),
            ),
            Positioned(
              bottom: -100,
              left: -60,
              child: Container(
                width: 320,
                height: 320,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: AppColors.secondary.withOpacity(0.06),
                ),
              ),
            ),

            // Main content
            Center(
              child: FadeTransition(
                opacity: _fadeAnim,
                child: ScaleTransition(
                  scale: _scaleAnim,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const AppLogo(
                        size: LogoSize.large,
                        showTagline: true,
                        light: true,
                      ),
                      const SizedBox(height: 60),
                      SizedBox(
                        width: 24,
                        height: 24,
                        child: CircularProgressIndicator(
                          strokeWidth: 2.5,
                          color: AppColors.primary.withOpacity(0.8),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),

            // Version tag at bottom
            Positioned(
              bottom: 40,
              left: 0,
              right: 0,
              child: Text(
                'v1.0.0 • Sri Lanka',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Colors.white.withOpacity(0.3),
                  fontSize: 12,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _navigate() async {
    if (!mounted) return;
    final authState = ref.read(authProvider);
    if (authState.isAuthenticated) {
      _goToRoleHome(authState.user!.role);
    } else {
      final savedRole = await StorageService.getRole();
      if (!mounted) return;
      if (savedRole == UserRole.vendor.name) {
        context.go(RouteNames.vendorLogin);
      } else {
        context.go(RouteNames.customerLogin);
      }
    }
  }

  void _goToRoleHome(UserRole role) {
    switch (role) {
      case UserRole.customer:
        context.go(RouteNames.customerHome);
      case UserRole.vendor:
        context.go(RouteNames.vendorHome);
      case UserRole.admin:
        context.go(RouteNames.adminHome);
    }
  }
}


