import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../models/proposal_comparison_mode.dart';

class ProposalComparisonBar extends StatelessWidget {
  const ProposalComparisonBar({
    super.key,
    required this.selectedMode,
    required this.onModeChanged,
    required this.proposalCount,
  });

  final ProposalComparisonMode selectedMode;
  final ValueChanged<ProposalComparisonMode> onModeChanged;
  final int proposalCount;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primaryText =
        isDark ? AppColors.textPrimaryDark : AppColors.textPrimaryLight;
    final chipBg = isDark ? AppColors.cardDark : AppColors.cardLight;
    final border = isDark ? AppColors.borderDark : AppColors.borderLight;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(Icons.compare_arrows_rounded, size: 20, color: primaryText),
            const SizedBox(width: 8),
            Text('Compare bids', style: AppTextStyles.subtitle(primaryText)),
            const Spacer(),
            Text(
              '$proposalCount offers',
              style: AppTextStyles.caption(
                isDark
                    ? AppColors.textSecondaryDark
                    : AppColors.textSecondaryLight,
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: ProposalComparisonMode.values.map((mode) {
              final selected = mode == selectedMode;
              return Padding(
                padding: const EdgeInsets.only(right: 8),
                child: FilterChip(
                  label: Text(mode.label),
                  selected: selected,
                  onSelected: (_) => onModeChanged(mode),
                  selectedColor: AppColors.customerColor.withValues(alpha: 0.18),
                  checkmarkColor: AppColors.customerColor,
                  labelStyle: AppTextStyles.caption(
                    selected ? AppColors.customerColor : primaryText,
                  ).copyWith(fontWeight: FontWeight.w600),
                  backgroundColor: chipBg,
                  side: BorderSide(
                    color: selected ? AppColors.customerColor : border,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              );
            }).toList(),
          ),
        ),
      ],
    );
  }
}

