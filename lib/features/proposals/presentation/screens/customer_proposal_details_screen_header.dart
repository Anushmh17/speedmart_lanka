import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_text_styles.dart';

Widget buildProposalDetailsHeader(
  BuildContext context,
  bool isDark,
  Color primaryText,
  Color secondaryText,
  String vendorName,
) {
  return Container(
    padding: EdgeInsets.fromLTRB(
      AppSpacing.md,
      MediaQuery.of(context).padding.top + AppSpacing.sm,
      AppSpacing.md,
      AppSpacing.md,
    ),
    decoration: BoxDecoration(
      color: isDark ? AppColors.surfaceDark : AppColors.surfaceLight,
      border: Border(
        bottom: BorderSide(
          color: isDark ? AppColors.borderDark : AppColors.borderLight,
          width: 1,
        ),
      ),
    ),
    child: Row(
      children: [
        IconButton(
          onPressed: () => context.pop(),
          icon: Icon(
            Icons.arrow_back_ios_new_rounded,
            color: primaryText,
          ),
          style: IconButton.styleFrom(
            backgroundColor: isDark ? AppColors.surfaceElevatedDark : AppColors.borderLight,
          ),
        ),
        SizedBox(width: AppSpacing.sm),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                vendorName,
                style: AppTextStyles.h2(primaryText),
              ),
              SizedBox(height: AppSpacing.xs),
              Text(
                'Review proposal details',
                style: AppTextStyles.bodySmall(secondaryText),
              ),
            ],
          ),
        ),
      ],
    ),
  );
}

