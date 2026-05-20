import 'package:flutter/material.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';

enum RequestType { single, multiple }

class RequestTypeToggle extends StatelessWidget {
  final RequestType selectedType;
  final ValueChanged<RequestType> onChanged;

  const RequestTypeToggle({
    super.key,
    required this.selectedType,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final backgroundColor = isDark ? Colors.black26 : Colors.grey.shade100;
    final cardColor = isDark ? AppColors.cardDark : Colors.white;
    final primaryText = isDark ? AppColors.textPrimaryDark : AppColors.textPrimaryLight;
    final secondaryText = isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight;

    return Container(
      height: 52,
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          Expanded(
            child: _ToggleOption(
              label: 'Single Item',
              icon: Icons.shopping_bag_outlined,
              isSelected: selectedType == RequestType.single,
              onTap: () => onChanged(RequestType.single),
              cardColor: cardColor,
              primaryText: primaryText,
              secondaryText: secondaryText,
            ),
          ),
          Expanded(
            child: _ToggleOption(
              label: 'Multiple Items',
              icon: Icons.format_list_bulleted_rounded,
              isSelected: selectedType == RequestType.multiple,
              onTap: () => onChanged(RequestType.multiple),
              cardColor: cardColor,
              primaryText: primaryText,
              secondaryText: secondaryText,
            ),
          ),
        ],
      ),
    );
  }
}

class _ToggleOption extends StatelessWidget {
  final String label;
  final IconData icon;
  final bool isSelected;
  final VoidCallback onTap;
  final Color cardColor;
  final Color primaryText;
  final Color secondaryText;

  const _ToggleOption({
    required this.label,
    required this.icon,
    required this.isSelected,
    required this.onTap,
    required this.cardColor,
    required this.primaryText,
    required this.secondaryText,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.customerColor : Colors.transparent,
          borderRadius: BorderRadius.circular(12),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: AppColors.customerColor.withOpacity(0.2),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  )
                ]
              : [],
        ),
        alignment: Alignment.center,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              icon,
              size: 20,
              color: isSelected ? Colors.white : secondaryText,
            ),
            const SizedBox(width: 8),
            Text(
              label,
              style: AppTextStyles.bodyMedium(
                isSelected ? Colors.white : primaryText,
              ).copyWith(
                fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
