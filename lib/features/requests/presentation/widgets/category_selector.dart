import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../admin/providers/category_provider.dart';

class CategorySelector extends ConsumerWidget {
  final String? selectedCategory;
  final ValueChanged<String> onSelected;
  final bool compact;

  const CategorySelector({
    super.key,
    required this.selectedCategory,
    required this.onSelected,
    this.compact = false,
  });

  static IconData _getCategoryIcon(String displayName) {
    final normalized = displayName.toLowerCase().replaceAll(' ', '_');
    switch (normalized) {
      case 'groceries': return Icons.local_grocery_store_outlined;
      case 'electronics': return Icons.devices_other_outlined;
      case 'hardware': return Icons.handyman_outlined;
      case 'furniture': return Icons.weekend_outlined;
      case 'pharmacy': return Icons.local_pharmacy_outlined;
      case 'clothing': return Icons.checkroom_outlined;
      case 'vehicle_parts': return Icons.settings_outlined;
      case 'home_appliances': return Icons.kitchen_outlined;
      case 'stationery': return Icons.edit_note_rounded;
      case 'other': return Icons.more_horiz_rounded;
      default: return Icons.category_outlined;
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primaryText = isDark ? AppColors.textPrimaryDark : AppColors.textPrimaryLight;
    final secondaryText = isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight;
    final cardColor = isDark ? AppColors.cardDark : AppColors.cardLight;
    final borderColor = isDark ? AppColors.borderDark : AppColors.borderLight;

    final activeCategories = ref.watch(activeCategoriesProvider);
    final categoriesList = activeCategories.map((cat) => {
      'name': cat.displayName,
      'icon': _getCategoryIcon(cat.displayName),
    }).toList();

    if (compact) {
      // Horizontal scrolling chips for compact mode (e.g. quick filtering or top selection)
      return SizedBox(
        height: 48,
        child: ListView.builder(
          scrollDirection: Axis.horizontal,
          physics: const BouncingScrollPhysics(),
          itemCount: categoriesList.length,
          itemBuilder: (context, index) {
            final cat = categoriesList[index];
            final name = cat['name'] as String;
            final icon = cat['icon'] as IconData;
            final isSelected = selectedCategory == name;

            return Padding(
              padding: const EdgeInsets.only(right: 8),
              child: ChoiceChip(
                avatar: Icon(
                  icon,
                  size: 16,
                  color: isSelected ? Colors.white : secondaryText,
                ),
                label: Text(name),
                selected: isSelected,
                onSelected: (selected) {
                  if (selected) onSelected(name);
                },
                selectedColor: AppColors.customerColor,
                backgroundColor: cardColor,
                labelStyle: AppTextStyles.bodySmall(
                  isSelected ? Colors.white : primaryText,
                ).copyWith(fontWeight: isSelected ? FontWeight.bold : FontWeight.normal),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                  side: BorderSide(
                    color: isSelected ? AppColors.customerColor : borderColor,
                  ),
                ),
              ),
            );
          },
        ),
      );
    }

    // Grid selector for step-by-step display
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        crossAxisSpacing: 10,
        mainAxisSpacing: 10,
        childAspectRatio: 1.0,
      ),
      itemCount: categoriesList.length,
      itemBuilder: (context, index) {
        final cat = categoriesList[index];
        final name = cat['name'] as String;
        final icon = cat['icon'] as IconData;
        final isSelected = selectedCategory == name;

        return GestureDetector(
          onTap: () => onSelected(name),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            decoration: BoxDecoration(
              color: isSelected
                  ? AppColors.customerColor.withOpacity(isDark ? 0.15 : 0.08)
                  : cardColor,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: isSelected ? AppColors.customerColor : borderColor,
                width: isSelected ? 2 : 1,
              ),
              boxShadow: isSelected
                  ? [
                      BoxShadow(
                        color: AppColors.customerColor.withOpacity(0.1),
                        blurRadius: 8,
                        spreadRadius: 1,
                      )
                    ]
                  : [],
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  icon,
                  size: 28,
                  color: isSelected ? AppColors.customerColor : secondaryText,
                ),
                const SizedBox(height: 8),
                Text(
                  name,
                  textAlign: TextAlign.center,
                  style: AppTextStyles.bodySmall(primaryText).copyWith(
                    fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
