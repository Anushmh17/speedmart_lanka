import 'package:flutter/material.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../core/widgets/app_button.dart';

class StickySubmitBar extends StatelessWidget {
  final int totalItems;
  final bool hasLocation;
  final bool hasMissingRequiredFields;
  final bool isLoading;
  final VoidCallback? onSubmit;

  const StickySubmitBar({
    super.key,
    required this.totalItems,
    required this.hasLocation,
    required this.hasMissingRequiredFields,
    required this.isLoading,
    this.onSubmit,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cardColor = isDark ? AppColors.surfaceDark : AppColors.surfaceLight;
    final borderColor = isDark ? AppColors.borderDark : AppColors.borderLight;
    final primaryText = isDark ? AppColors.textPrimaryDark : AppColors.textPrimaryLight;
    final secondaryText = isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight;

    final bool isSubmissionDisabled = !hasLocation || hasMissingRequiredFields || totalItems == 0 || onSubmit == null;

    // Build the dynamic warning text
    String? warningMsg;
    if (totalItems == 0) {
      warningMsg = 'Please add at least one item to submit.';
    } else if (!hasLocation) {
      warningMsg = 'Please select a delivery suburb and address.';
    } else if (hasMissingRequiredFields) {
      warningMsg = 'Ensure all added items have names and quantities.';
    }

    return Container(
      decoration: BoxDecoration(
        color: cardColor,
        border: Border(top: BorderSide(color: borderColor, width: 1.2)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.06),
            blurRadius: 10,
            offset: const Offset(0, -4),
          )
        ],
      ),
      padding: EdgeInsets.fromLTRB(16, 12, 16, MediaQuery.of(context).padding.bottom + 12),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Dynamic Validation Warning Box
          if (warningMsg != null) ...[
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              margin: const EdgeInsets.only(bottom: 12),
              decoration: BoxDecoration(
                color: AppColors.errorContainer.withOpacity(0.4),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: AppColors.error.withOpacity(0.3)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.warning_amber_rounded, color: AppColors.error, size: 18),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      warningMsg,
                      style: AppTextStyles.caption(isDark ? Colors.red.shade200 : AppColors.error).copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],

          // Total Items & Submission Button Layout
          Row(
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Total Items',
                    style: AppTextStyles.caption(secondaryText),
                  ),
                  Text(
                    '$totalItems ${totalItems == 1 ? "Item" : "Items"}',
                    style: AppTextStyles.h2(primaryText).copyWith(fontWeight: FontWeight.bold),
                  ),
                ],
              ),
              const SizedBox(width: 24),
              Expanded(
                child: AppButton(
                  label: isLoading ? 'Submitting...' : 'Submit Request',
                  onPressed: isSubmissionDisabled ? null : onSubmit,
                  color: AppColors.customerColor,
                  isLoading: isLoading,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

