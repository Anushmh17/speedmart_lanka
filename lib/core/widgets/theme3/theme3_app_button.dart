import 'package:flutter/material.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_text_styles.dart';
import '../../theme/app_radius.dart';

enum Theme3ButtonType { primary, secondary, ghost, danger }

class Theme3AppButton extends StatelessWidget {
  final String label;
  final VoidCallback? onPressed;
  final Theme3ButtonType type;
  final bool isLoading;
  final IconData? icon;
  final double? width;
  final double height;

  const Theme3AppButton({
    super.key,
    required this.label,
    this.onPressed,
    this.type = Theme3ButtonType.primary,
    this.isLoading = false,
    this.icon,
    this.width,
    this.height = 52,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final isDisabled = onPressed == null || isLoading;

    Color getBackgroundColor() {
      if (isDisabled) {
        return isDark ? AppColors.borderDark : AppColors.borderLight;
      }
      
      switch (type) {
        case Theme3ButtonType.primary:
          return isDark ? AppColors.primaryDark : AppColors.primary;
        case Theme3ButtonType.secondary:
          return Colors.transparent;
        case Theme3ButtonType.ghost:
          return Colors.transparent;
        case Theme3ButtonType.danger:
          return AppColors.error;
      }
    }

    Color getForegroundColor() {
      if (isDisabled) {
        return isDark ? AppColors.textHintDark : AppColors.textHintLight;
      }
      
      switch (type) {
        case Theme3ButtonType.primary:
          return Colors.white;
        case Theme3ButtonType.secondary:
          return isDark ? AppColors.primaryDark : AppColors.primary;
        case Theme3ButtonType.ghost:
          return isDark ? AppColors.textPrimaryDark : AppColors.textPrimaryLight;
        case Theme3ButtonType.danger:
          return Colors.white;
      }
    }

    BorderSide? getBorder() {
      if (type == Theme3ButtonType.secondary) {
        final color = isDisabled
            ? (isDark ? AppColors.borderDark : AppColors.borderLight)
            : (isDark ? AppColors.primaryDark : AppColors.primary);
        return BorderSide(color: color, width: 1.5);
      }
      return null;
    }

    return SizedBox(
      width: width ?? double.infinity,
      height: height,
      child: ElevatedButton(
        onPressed: isDisabled ? null : onPressed,
        style: ElevatedButton.styleFrom(
          backgroundColor: getBackgroundColor(),
          foregroundColor: getForegroundColor(),
          elevation: 0,
          disabledBackgroundColor: getBackgroundColor(),
          disabledForegroundColor: getForegroundColor(),
          shape: RoundedRectangleBorder(
            borderRadius: AppRadius.mdRadius,
            side: getBorder() ?? BorderSide.none,
          ),
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
        ),
        child: isLoading
            ? SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  valueColor: AlwaysStoppedAnimation<Color>(getForegroundColor()),
                ),
              )
            : Row(
                mainAxisAlignment: MainAxisAlignment.center,
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (icon != null) ...[
                    Icon(icon, size: 20),
                    const SizedBox(width: 8),
                  ],
                  Flexible(
                    child: Text(
                      label,
                      style: AppTextStyles.button(getForegroundColor()),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      textAlign: TextAlign.center,
                    ),
                  ),
                ],
              ),
      ),
    );
  }
}

