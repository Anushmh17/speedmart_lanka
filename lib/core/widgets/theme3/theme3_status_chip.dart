import 'package:flutter/material.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_text_styles.dart';
import '../../theme/app_radius.dart';

enum Theme3StatusType {
  pending,
  approved,
  active,
  rejected,
  inProgress,
  completed,
  cancelled,
  custom,
}

class Theme3StatusChip extends StatelessWidget {
  final String label;
  final Theme3StatusType status;
  final Color? customColor;
  final IconData? icon;

  const Theme3StatusChip({
    super.key,
    required this.label,
    required this.status,
    this.customColor,
    this.icon,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    Color getStatusColor() {
      switch (status) {
        case Theme3StatusType.pending:
          return AppColors.warning;
        case Theme3StatusType.approved:
          return AppColors.success;
        case Theme3StatusType.active:
          return AppColors.info;
        case Theme3StatusType.rejected:
          return AppColors.error;
        case Theme3StatusType.inProgress:
          return isDark ? AppColors.primaryDark : AppColors.primary;
        case Theme3StatusType.completed:
          return AppColors.success;
        case Theme3StatusType.cancelled:
          return isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight;
        case Theme3StatusType.custom:
          return customColor ?? AppColors.info;
      }
    }

    Color getBackgroundColor() {
      final statusColor = getStatusColor();
      return statusColor.withValues(alpha: isDark ? 0.2 : 0.15);
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: getBackgroundColor(),
        borderRadius: AppRadius.smRadius,
        border: Border.all(
          color: getStatusColor().withValues(alpha: 0.3),
          width: 1,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 14, color: getStatusColor()),
            const SizedBox(width: 4),
          ],
          Text(
            label,
            style: AppTextStyles.labelSmall(getStatusColor()).copyWith(
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

