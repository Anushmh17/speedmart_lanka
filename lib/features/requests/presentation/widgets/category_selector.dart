import 'package:flutter/material.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';

class CategorySelector extends StatelessWidget {
  final String? selectedCategory;
  final ValueChanged<String> onSelected;
  final bool compact;

  const CategorySelector({
    super.key,
    required this.selectedCategory,
    required this.onSelected,
    this.compact = false,
  });

  static const List<Map<String, dynamic>> categoriesList = [
    {'name': 'Groceries', 'icon': Icons.local_grocery_store_outlined},
    {'name': 'Vehicle parts', 'icon': Icons.settings_outlined},
    {'name': 'Electronics', 'icon': Icons.devices_other_outlined},
    {'name': 'Furniture', 'icon': Icons.weekend_outlined},
    {'name': 'Home appliances', 'icon': Icons.kitchen_outlined},
    {'name': 'Clothing', 'icon': Icons.checkroom_outlined},
    {'name': 'Hardware items', 'icon': Icons.handyman_outlined},
    {'name': 'Stationery', 'icon': Icons.edit_note_rounded},
    {'name': 'Other', 'icon': Icons.more_horiz_rounded},
  ];

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primaryText = isDark ? AppColors.textPrimaryDark : AppColors.textPrimaryLight;
    final secondaryText = isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight;
    final cardColor = isDark ? AppColors.cardDark : AppColors.cardLight;
    final borderColor = isDark ? AppColors.borderDark : AppColors.borderLight;

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
