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
  });

  final LogoSize size;
  final bool showTagline;
  final bool light;

  @override
  Widget build(BuildContext context) {
    final iconSize = _iconSize;
    final nameSize = _nameSize;
    final primaryColor = light ? Colors.white : AppColors.primary;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Logo mark: cart icon inside a rounded box
        Container(
          width: iconSize,
          height: iconSize,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [AppColors.primary, AppColors.primaryDark],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(iconSize * 0.25),
            boxShadow: [
              BoxShadow(
                color: AppColors.primary.withOpacity(0.35),
                blurRadius: 16,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: Icon(
            Icons.bolt_rounded,
            color: Colors.white,
            size: iconSize * 0.55,
          ),
        ),
        const SizedBox(height: 12),
        // App name
        RichText(
          text: TextSpan(
            children: [
              TextSpan(
                text: 'Speedmart',
                style: AppTextStyles.display2(primaryColor).copyWith(
                  fontSize: nameSize,
                  fontWeight: FontWeight.w800,
                ),
              ),
              TextSpan(
                text: ' Lanka',
                style: AppTextStyles.display2(
                  light ? Colors.white70 : AppColors.textSecondaryLight,
                ).copyWith(
                  fontSize: nameSize,
                  fontWeight: FontWeight.w400,
                ),
              ),
            ],
          ),
        ),
        if (showTagline) ...[
          const SizedBox(height: 6),
          Text(
            'Your Smart Marketplace',
            style: AppTextStyles.bodyMedium(
              light
                  ? Colors.white60
                  : AppColors.textSecondaryLight,
            ),
          ),
        ],
      ],
    );
  }

  double get _iconSize {
    switch (size) {
      case LogoSize.small:
        return 48;
      case LogoSize.medium:
        return 72;
      case LogoSize.large:
        return 96;
    }
  }

  double get _nameSize {
    switch (size) {
      case LogoSize.small:
        return 18;
      case LogoSize.medium:
        return 24;
      case LogoSize.large:
        return 30;
    }
  }
}

enum LogoSize { small, medium, large }

// ── Small inline logo for AppBar ──────────────────────────────────────────
class AppBarLogo extends StatelessWidget {
  const AppBarLogo({super.key});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 30,
          height: 30,
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [AppColors.primary, AppColors.primaryDark],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(8),
          ),
          child: const Icon(Icons.bolt_rounded, color: Colors.white, size: 18),
        ),
        const SizedBox(width: 8),
        RichText(
          text: TextSpan(
            children: [
              TextSpan(
                text: 'Speedmart',
                style: AppTextStyles.h3(
                  isDark ? AppColors.textPrimaryDark : AppColors.textPrimaryLight,
                ).copyWith(fontWeight: FontWeight.w700),
              ),
              TextSpan(
                text: ' Lanka',
                style: AppTextStyles.h3(
                  isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight,
                ).copyWith(fontWeight: FontWeight.w400),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
