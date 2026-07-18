import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_radius.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../models/vendor_feed_enums.dart';

class VendorFeedFilterBar extends StatelessWidget {
  const VendorFeedFilterBar({
    super.key,
    required this.isDark,
    required this.categoryChips,
    required this.selectedCategory,
    required this.sortMode,
    required this.onCategorySelected,
    required this.onSortChanged,
  });

  final bool isDark;
  final List<String> categoryChips;
  final String? selectedCategory;
  final VendorFeedSortMode sortMode;
  final ValueChanged<String?> onCategorySelected;
  final ValueChanged<VendorFeedSortMode> onSortChanged;

  @override
  Widget build(BuildContext context) {
    final primaryText =
        isDark ? AppColors.textPrimaryDark : AppColors.textPrimaryLight;
    final chipBg = isDark ? AppColors.cardDark : AppColors.cardLight;
    final border = isDark ? AppColors.borderDark : AppColors.borderLight;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: AppSpacing.sm),
        SizedBox(
          height: 40,
          child: ListView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
            children: [
              _CategoryChip(
                label: 'All',
                selected: selectedCategory == null,
                isDark: isDark,
                onTap: () => onCategorySelected(null),
              ),
              ...categoryChips.map(
                (cat) => Padding(
                  padding: const EdgeInsets.only(left: AppSpacing.sm),
                  child: _CategoryChip(
                    label: cat,
                    selected: selectedCategory?.toLowerCase() ==
                        cat.toLowerCase(),
                    isDark: isDark,
                    onTap: () => onCategorySelected(cat),
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: AppSpacing.md),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
          child: Row(
            children: [
              Icon(Icons.tune_rounded, size: 18, color: primaryText),
              const SizedBox(width: AppSpacing.sm),
              Text('Sort', style: AppTextStyles.caption(primaryText)),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: VendorFeedSortMode.values.map((mode) {
                      final selected = sortMode == mode;
                      return Padding(
                        padding: const EdgeInsets.only(right: AppSpacing.sm),
                        child: FilterChip(
                          label: Text(mode.label),
                          selected: selected,
                          onSelected: (_) => onSortChanged(mode),
                          selectedColor:
                              AppColors.vendorColor.withValues(alpha: 0.2),
                          checkmarkColor: AppColors.vendorColor,
                          labelStyle: AppTextStyles.caption(
                            selected
                                ? AppColors.vendorColor
                                : primaryText,
                          ).copyWith(fontWeight: FontWeight.w600),
                          backgroundColor: chipBg,
                          side: BorderSide(
                            color: selected
                                ? AppColors.vendorColor
                                : border,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(AppRadius.md),
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _CategoryChip extends StatelessWidget {
  const _CategoryChip({
    required this.label,
    required this.selected,
    required this.isDark,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final bool isDark;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return FilterChip(
      label: Text(label),
      selected: selected,
      onSelected: (_) => onTap(),
      selectedColor: AppColors.vendorColor.withValues(alpha: 0.2),
      checkmarkColor: AppColors.vendorColor,
      labelStyle: AppTextStyles.caption(
        selected ? AppColors.vendorColor : (isDark
            ? AppColors.textPrimaryDark
            : AppColors.textPrimaryLight),
      ).copyWith(fontWeight: FontWeight.w600),
      backgroundColor: isDark ? AppColors.cardDark : AppColors.cardLight,
      side: BorderSide(
        color: selected
            ? AppColors.vendorColor
            : (isDark ? AppColors.borderDark : AppColors.borderLight),
      ),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.md)),
    );
  }
}

