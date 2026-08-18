import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/routes/route_names.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/services/local_notification_service.dart';
import '../../../../features/orders/data/order_repository.dart';
import '../../../../features/proposals/data/proposal_repository.dart';
import '../../../../features/requests/data/request_repository.dart';
import '../../providers/auth_provider.dart';
import '../../../../shared/models/user_role.dart';

class SplashScreen extends ConsumerStatefulWidget {
  const SplashScreen({super.key});

  @override
  ConsumerState<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends ConsumerState<SplashScreen>
    with TickerProviderStateMixin {
  // Phase 1: logo + tagline fade/scale in
  late AnimationController _introController;
  late Animation<double> _introScale;
  late Animation<double> _introOpacity;

  // Tagline
  late AnimationController _taglineController;
  late Animation<double> _taglineOpacity;

  // Phase 2: fade out — only starts when BOTH anim sequence done AND auth ready
  late AnimationController _fadeOutController;
  late Animation<double> _fadeOutOpacity;

  // Loading dots pulse
  late AnimationController _dotsController;

  bool _authReady = false;
  bool _introSequenceDone = false;
  bool _assetsPreloaded = false;
  bool _minDelayDone = false;

  @override
  void initState() {
    super.initState();

    _introController = AnimationController(
      duration: const Duration(milliseconds: 1400),
      vsync: this,
    );
    _introScale = Tween<double>(begin: 0.55, end: 1.0).animate(
      CurvedAnimation(parent: _introController, curve: Curves.easeOutCubic),
    );
    _introOpacity = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _introController,
        curve: const Interval(0.0, 0.6, curve: Curves.easeOut),
      ),
    );

    _taglineController = AnimationController(
      duration: const Duration(milliseconds: 500),
      vsync: this,
    );
    _taglineOpacity = CurvedAnimation(
      parent: _taglineController,
      curve: Curves.easeIn,
    );

    _fadeOutController = AnimationController(
      duration: const Duration(milliseconds: 180),
      vsync: this,
    );
    _fadeOutOpacity = Tween<double>(begin: 1.0, end: 0.0).animate(
      CurvedAnimation(parent: _fadeOutController, curve: Curves.easeOut),
    );

    // Infinite pulsing for loading dots
    _dotsController = AnimationController(
      duration: const Duration(milliseconds: 900),
      vsync: this,
    )..repeat();

    _runIntroSequence();
  }

  Future<void> _runIntroSequence() async {
    // All heavy init + asset precaching run in parallel with the animation
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _precacheLoginAssets();
      _initServices();
    });
    // Minimum 2.5s so services have time to fully warm up
    Future.delayed(const Duration(milliseconds: 4100), () {
      _minDelayDone = true;
      _tryFadeOut();
    });
    await _introController.forward();
    await Future.delayed(const Duration(milliseconds: 150));
    await _taglineController.forward();
    _introSequenceDone = true;
    _tryFadeOut();
  }

  Future<void> _initServices() async {
    await Future.wait([
      LocalNotificationService.initialize(),
      RequestRepository.instance.ensureInitialized(),
      ProposalRepository.instance.ensureInitialized(),
      OrderRepository.instance.ensureInitialized(),
    ]);
  }

  Future<void> _precacheLoginAssets() async {
    if (!mounted) return;
    await Future.wait([
      precacheImage(const AssetImage('assets/images/logo.png'), context),
      precacheImage(const AssetImage('assets/images/figma/sri_lanka_customer_login/Customerheroimagespeedmart1.png'), context),
      precacheImage(const AssetImage('assets/images/figma/sri_lanka_customer_login/Speedmart_lk_transparent_logo_cropped1.png'), context),
      precacheImage(const AssetImage('assets/images/figma/sri_lanka_customer_login/Expandarrow.png'), context),
      precacheImage(const AssetImage('assets/images/figma/sri_lanka_customer_login/Phoneicon.png'), context),
    ]);
    if (!mounted) return;
    _assetsPreloaded = true;
    _tryFadeOut();
  }

  /// Only fades out when intro done AND auth ready AND assets preloaded AND min delay elapsed.
  void _tryFadeOut() {
    if (!_introSequenceDone || !_authReady || !_assetsPreloaded || !_minDelayDone || !mounted) return;
    _dotsController.stop();
    _navigate(); // start navigation immediately
    _fadeOutController.forward();
  }

  @override
  void dispose() {
    _introController.dispose();
    _taglineController.dispose();
    _fadeOutController.dispose();
    _dotsController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isLoading = ref.watch(authLoadingProvider);
    if (!isLoading && !_authReady) {
      _authReady = true;
      WidgetsBinding.instance.addPostFrameCallback((_) => _tryFadeOut());
    }

    ref.listen<bool>(authLoadingProvider, (_, nowLoading) {
      if (!nowLoading && !_authReady) {
        _authReady = true;
        _tryFadeOut();
      }
    });

    final size = MediaQuery.of(context).size;

    const Color(0xFF0A1628);

    return Scaffold(
      backgroundColor: const Color(0xFF0A1628),
      body: AnimatedBuilder(
        animation: _fadeOutController,
        builder: (context, child) => Opacity(
          opacity: _fadeOutOpacity.value,
          child: child,
        ),
        child: Stack(
          fit: StackFit.expand,
          children: [
            // Background gradient
            Container(
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  colors: [Color(0xFF0A1628), Color(0xFF0D2137), Color(0xFF0A1628)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
              ),
            ),

            // Glow circles
            Positioned(
              top: -80,
              right: -80,
              child: Container(
                width: 280,
                height: 280,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: AppColors.primary.withOpacity(0.07),
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
                  color: AppColors.secondary.withOpacity(0.05),
                ),
              ),
            ),

            // Logo + tagline + loading dots
            Center(
              child: AnimatedBuilder(
                animation: Listenable.merge([_introController, _taglineController]),
                builder: (context, _) => Opacity(
                  opacity: _introOpacity.value.clamp(0.0, 1.0),
                  child: Transform.scale(
                    scale: _introScale.value,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Image.asset(
                          'assets/images/logo.png',
                          width: size.width * 0.58,
                          fit: BoxFit.contain,
                        ),
                        const SizedBox(height: 10),
                        FadeTransition(
                          opacity: _taglineOpacity,
                          child: Text(
                            'Your Smart Marketplace',
                            style: TextStyle(
                              color: Colors.white.withOpacity(0.65),
                              fontSize: 14,
                              fontWeight: FontWeight.w500,
                              letterSpacing: 1.2,
                            ),
                          ),
                        ),
                        const SizedBox(height: 36),
                        FadeTransition(
                          opacity: _taglineOpacity,
                          child: _PulsingDots(controller: _dotsController),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),

            // Version tag
            Positioned(
              bottom: 40,
              left: 0,
              right: 0,
              child: AnimatedBuilder(
                animation: _introController,
                builder: (context, _) => Opacity(
                  opacity: (_introOpacity.value * 0.5).clamp(0.0, 1.0),
                  child: Text(
                    'v1.0.0 • Sri Lanka',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: Colors.white.withOpacity(0.3),
                      fontSize: 12,
                    ),
                  ),
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
      context.go(RouteNames.customerLogin);
    }
  }

  void _goToRoleHome(UserRole role) {
    switch (role) {
      case UserRole.customer:
        context.go(RouteNames.customerHome);
      case UserRole.vendor:
        context.go(RouteNames.vendorHome);
      case UserRole.admin:
        context.go(RouteNames.customerHome);
    }
  }
}

// ── Pulsing dots loading indicator ──────────────────────────────────────────
class _PulsingDots extends StatelessWidget {
  const _PulsingDots({required this.controller});
  final AnimationController controller;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: controller,
      builder: (context, _) {
        return Row(
          mainAxisSize: MainAxisSize.min,
          children: List.generate(3, (i) {
            // Each dot is offset by 0.33 in the animation cycle
            final offset = i * 0.33;
            final t = ((controller.value + offset) % 1.0);
            // Scale: 0.6 → 1.0 → 0.6 using a sine-like curve
            final scale = 0.6 + 0.4 * (1.0 - (2 * t - 1).abs().clamp(0.0, 1.0));
            final opacity = 0.35 + 0.65 * scale;
            return Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4),
              child: Opacity(
                opacity: opacity.clamp(0.0, 1.0),
                child: Transform.scale(
                  scale: scale,
                  child: Container(
                    width: 7,
                    height: 7,
                    decoration: BoxDecoration(
                      color: AppColors.primary,
                      shape: BoxShape.circle,
                    ),
                  ),
                ),
              ),
            );
          }),
        );
      },
    );
  }
}
