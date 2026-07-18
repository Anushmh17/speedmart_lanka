import 'package:flutter/material.dart';
import '../theme/app_colors.dart';
import '../theme/app_text_styles.dart';

/// Speedmart Lanka brand logo widget.
/// Used in splash, auth, and appbar screens.
class AppLogo extends StatelessWidget {
  const AppLogo({
    super.key,
    this.size = LogoSize.medium,
    this.showTagline = false,
    this.light = false,
    this.useDarkPill = false,
  });

  final LogoSize size;
  final bool showTagline;
  final bool light;
  final bool useDarkPill;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final logoWidth = _logoWidth;

    final logoImage = Image.asset(
      'assets/images/logo.png',
      width: logoWidth,
      fit: BoxFit.contain,
    );

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Logo with optional dark pill for light backgrounds
        if (useDarkPill && !light)
          Container(
            padding: EdgeInsets.symmetric(
              horizontal: logoWidth * 0.12,
              vertical: logoWidth * 0.08,
            ),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF1E293B) : const Color(0xFF1E293B),
              borderRadius: BorderRadius.circular(logoWidth * 0.08),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.08),
                  blurRadius: 12,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: logoImage,
          )
        else
          logoImage,
        if (showTagline) ...[
          const SizedBox(height: 6),
          Text(
            'Your Smart Marketplace',
            style: AppTextStyles.bodyMedium(
              light
                  ? Colors.white60
                  : (isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight),
            ).copyWith(fontWeight: FontWeight.w500),
          ),
        ],
      ],
    );
  }

  double get _logoWidth {
    switch (size) {
      case LogoSize.small:
        return 120;
      case LogoSize.medium:
        return 180;
      case LogoSize.large:
        return 240;
    }
  }
}

enum LogoSize { small, medium, large }

// ── Small inline logo for AppBar ──────────────────────────────────────────
class AppBarLogo extends StatelessWidget {
  const AppBarLogo({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
      decoration: BoxDecoration(
        color: const Color(0xFF161616),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Image.asset(
        'assets/images/logo.png',
        height: 22,
        fit: BoxFit.contain,
      ),
    );
  }
}

