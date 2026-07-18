import 'package:flutter/material.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_text_styles.dart';
import '../../theme/app_radius.dart';

class Theme3CategoryChip extends StatelessWidget {
  final String label;
  final bool isSelected;
  final bool isDisabled;
  final IconData? icon;
  final VoidCallback? onTap;

  const Theme3CategoryChip({
    super.key,
    required this.label,
    this.isSelected = false,
    this.isDisabled = false,
    this.icon,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    Color getBackgroundColor() {
      if (isDisabled) {
        return isDark ? AppColors.borderDark : AppColors.borderLight;
      }
      if (isSelected) {
        return isDark ? AppColors.primaryDark : AppColors.primary;
      }
      return isDark ? AppColors.surfaceElevatedDark : AppColors.backgroundLight;
    }

    Color getTextColor() {
      if (isDisabled) {
        return isDark ? AppColors.textHintDark : AppColors.textHintLight;
      }
      if (isSelected) {
        return Colors.white;
      }
      return isDark ? AppColors.textPrimaryDark : AppColors.textPrimaryLight;
    }

    Color getBorderColor() {
      if (isDisabled) {
        return isDark ? AppColors.borderDark : AppColors.borderLight;
      }
      if (isSelected) {
        return isDark ? AppColors.primaryDark : AppColors.primary;
      }
      return isDark ? AppColors.borderDark : AppColors.borderLight;
    }

    return InkWell(
      onTap: isDisabled ? null : onTap,
      borderRadius: AppRadius.smRadius,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: BoxDecoration(
          color: getBackgroundColor(),
          borderRadius: AppRadius.smRadius,
          border: Border.all(color: getBorderColor(), width: 1),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (icon != null) ...[
              Icon(icon, size: 16, color: getTextColor()),
              const SizedBox(width: 6),
            ],
            Text(
              label,
              style: AppTextStyles.labelMedium(getTextColor()).copyWith(
                fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

