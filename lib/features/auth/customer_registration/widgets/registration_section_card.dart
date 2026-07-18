import 'package:flutter/material.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';

/// A grouped section card used to visually separate form sections.
///
/// Wraps its [children] in a rounded card with an icon + title header,
/// subtle border and shadow for a premium look.
class RegistrationSectionCard extends StatelessWidget {
  const RegistrationSectionCard({
    super.key,
    required this.icon,
    required this.title,
    required this.children,
    this.trailing,
    this.accentColor,
    this.bottomPadding = 20,
  });

  final IconData icon;
  final String title;
  final List<Widget> children;

  /// Optional widget shown on the right of the header row.
  final Widget? trailing;

  /// Accent colour for the icon and title. Defaults to [AppColors.primary].
  final Color? accentColor;

  final double bottomPadding;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final accent = accentColor ?? AppColors.primary;
    final cardBg = isDark ? AppColors.cardDark : AppColors.surfaceLight;
    final borderColor =
        isDark ? AppColors.borderDark : AppColors.borderLight;

    return Container(
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: borderColor),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.18 : 0.06),
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Section header ──────────────────────────────────────────
          Container(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 12),
            decoration: BoxDecoration(
              color: accent.withValues(alpha: isDark ? 0.12 : 0.07),
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(20),
                topRight: Radius.circular(20),
              ),
            ),
            child: Row(
              children: [
                Container(
                  width: 34,
                  height: 34,
                  decoration: BoxDecoration(
                    color: accent.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(icon, color: accent, size: 18),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    title,
                    style: AppTextStyles.labelLarge(
                      isDark
                          ? AppColors.textPrimaryDark
                          : AppColors.textPrimaryLight,
                    ),
                  ),
                ),
                if (trailing != null) trailing!,
              ],
            ),
          ),
          // ── Divider ─────────────────────────────────────────────────
          Divider(height: 1, color: borderColor),
          // ── Content ─────────────────────────────────────────────────
          Padding(
            padding: EdgeInsets.fromLTRB(16, 16, 16, bottomPadding),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: children,
            ),
          ),
        ],
      ),
    );
  }
}

