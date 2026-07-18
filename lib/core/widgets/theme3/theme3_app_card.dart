import 'package:flutter/material.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_radius.dart';
import '../../theme/app_shadows.dart';

enum Theme3CardType { standard, elevated, highlighted }

class Theme3AppCard extends StatelessWidget {
  final Widget child;
  final Theme3CardType type;
  final EdgeInsetsGeometry? padding;
  final EdgeInsetsGeometry? margin;
  final VoidCallback? onTap;

  const Theme3AppCard({
    super.key,
    required this.child,
    this.type = Theme3CardType.standard,
    this.padding,
    this.margin,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    Color getBackgroundColor() {
      switch (type) {
        case Theme3CardType.standard:
          return isDark ? AppColors.cardDark : AppColors.cardLight;
        case Theme3CardType.elevated:
          return isDark ? AppColors.surfaceElevatedDark : AppColors.surfaceLight;
        case Theme3CardType.highlighted:
          return isDark
              ? AppColors.primaryDark.withValues(alpha: 0.1)
              : AppColors.warningContainer;
      }
    }

    BorderSide getBorder() {
      if (type == Theme3CardType.highlighted) {
        return BorderSide(
          color: isDark ? AppColors.primaryDark.withValues(alpha: 0.3) : AppColors.primary.withValues(alpha: 0.2),
          width: 1,
        );
      }
      return BorderSide(
        color: isDark ? AppColors.borderDark : AppColors.borderLight,
        width: 1,
      );
    }

    List<BoxShadow> getShadows() {
      if (isDark) {
        return type == Theme3CardType.elevated ? AppShadows.mdDark : AppShadows.smDark;
      }
      return type == Theme3CardType.elevated ? AppShadows.lg : AppShadows.md;
    }

    final cardWidget = Container(
      margin: margin,
      decoration: BoxDecoration(
        color: getBackgroundColor(),
        borderRadius: AppRadius.lgRadius,
        border: Border.fromBorderSide(getBorder()),
        boxShadow: getShadows(),
      ),
      child: Padding(
        padding: padding ?? const EdgeInsets.all(16),
        child: child,
      ),
    );

    if (onTap != null) {
      return InkWell(
        onTap: onTap,
        borderRadius: AppRadius.lgRadius,
        child: cardWidget,
      );
    }

    return cardWidget;
  }
}

