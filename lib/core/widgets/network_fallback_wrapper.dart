import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../services/connectivity_service.dart';
import '../theme/app_colors.dart';
import '../theme/app_text_styles.dart';

class NetworkFallbackWrapper extends ConsumerStatefulWidget {
  const NetworkFallbackWrapper({super.key, required this.child});

  final Widget child;

  @override
  ConsumerState<NetworkFallbackWrapper> createState() =>
      _NetworkFallbackWrapperState();
}

class _NetworkFallbackWrapperState
    extends ConsumerState<NetworkFallbackWrapper>
    with TickerProviderStateMixin {
  late final AnimationController _offlineController;
  late final Animation<Offset> _offlineSlide;

  late final AnimationController _onlineController;
  late final Animation<Offset> _onlineSlide;

  bool? _previousOnline;
  bool _showOfflineBanner = false;
  bool _showOnlineBanner = false;

  @override
  void initState() {
    super.initState();
    _offlineController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 350),
    );
    _offlineSlide = Tween<Offset>(
      begin: const Offset(0, -1),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _offlineController, curve: Curves.easeOutCubic));

    _onlineController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 350),
    );
    _onlineSlide = Tween<Offset>(
      begin: const Offset(0, -1),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _onlineController, curve: Curves.easeOutCubic));
  }

  @override
  void dispose() {
    _offlineController.dispose();
    _onlineController.dispose();
    super.dispose();
  }

  void _handleConnectivityChange(bool isOnline) {
    if (_previousOnline == null) {
      if (!isOnline) _showOfflineBannerAnim();
      _previousOnline = isOnline;
      return;
    }

    if (!isOnline && _previousOnline == true) {
      _showOfflineBannerAnim();
    } else if (isOnline && _previousOnline == false) {
      _hideOfflineBannerAnim();
      _showBackOnlineBanner();
    }

    _previousOnline = isOnline;
  }

  Future<void> _showOfflineBannerAnim() async {
    if (!mounted) return;
    setState(() => _showOfflineBanner = true);
    _offlineController.forward();
  }

  Future<void> _hideOfflineBannerAnim() async {
    await _offlineController.reverse();
    if (mounted) setState(() => _showOfflineBanner = false);
  }

  Future<void> _showBackOnlineBanner() async {
    if (!mounted) return;
    setState(() => _showOnlineBanner = true);
    await _onlineController.forward();
    await Future.delayed(const Duration(seconds: 3));
    if (!mounted) return;
    await _onlineController.reverse();
    if (mounted) setState(() => _showOnlineBanner = false);
  }

  @override
  Widget build(BuildContext context) {
    ref.listen<AsyncValue<bool>>(connectivityProvider, (_, next) {
      next.whenData(_handleConnectivityChange);
    });

    final isDark = Theme.of(context).brightness == Brightness.dark;
    final topPadding = MediaQuery.of(context).padding.top;

    return Stack(
      children: [
        widget.child,
        if (_showOfflineBanner)
          Positioned(
            top: topPadding + 10,
            left: 16,
            right: 16,
            child: SlideTransition(
              position: _offlineSlide,
              child: _NetworkBanner(
                isDark: isDark,
                isOnline: false,
              ),
            ),
          ),
        if (_showOnlineBanner)
          Positioned(
            top: topPadding + 10,
            left: 16,
            right: 16,
            child: SlideTransition(
              position: _onlineSlide,
              child: _NetworkBanner(
                isDark: isDark,
                isOnline: true,
              ),
            ),
          ),
      ],
    );
  }
}

class _NetworkBanner extends StatelessWidget {
  const _NetworkBanner({required this.isDark, required this.isOnline});

  final bool isDark;
  final bool isOnline;

  @override
  Widget build(BuildContext context) {
    final color = isOnline ? AppColors.success : AppColors.error;
    final icon = isOnline ? Icons.wifi_rounded : Icons.wifi_off_rounded;
    final title = isOnline ? 'Back online' : 'No internet connection';
    final subtitle = isOnline
        ? 'Your connection has been restored'
        : 'Some features may be unavailable';

    return Material(
      color: Colors.transparent,
      child: DefaultTextStyle(
        style: const TextStyle(decoration: TextDecoration.none),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          decoration: BoxDecoration(
            color: isDark ? AppColors.surfaceDark : AppColors.surfaceLight,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: color.withOpacity(0.4),
              width: 1.5,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(isDark ? 0.4 : 0.12),
                blurRadius: 16,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.12),
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, color: color, size: 24),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: AppTextStyles.bodyLarge(
                        isDark
                            ? AppColors.textPrimaryDark
                            : AppColors.textPrimaryLight,
                      ).copyWith(fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      style: AppTextStyles.bodySmall(
                        isDark
                            ? AppColors.textSecondaryDark
                            : AppColors.textSecondaryLight,
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
}

