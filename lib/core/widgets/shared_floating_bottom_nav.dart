import 'package:flutter/material.dart';
import '../theme/app_colors.dart';
import '../theme/app_text_styles.dart';

class SharedFloatingBottomNavItem {
  final IconData unselectedIcon;
  final IconData selectedIcon;
  final String label;

  const SharedFloatingBottomNavItem({
    required this.unselectedIcon,
    required this.selectedIcon,
    required this.label,
  });
}

class SharedFloatingBottomNav extends StatelessWidget {
  const SharedFloatingBottomNav({
    super.key,
    required this.currentIndex,
    required this.onTap,
    required this.items,
    required this.activeColor,
  });

  final int currentIndex;
  final ValueChanged<int> onTap;
  final List<SharedFloatingBottomNavItem> items;
  final Color activeColor;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 20),
      decoration: BoxDecoration(
        color: isDark ? AppColors.surfaceDark.withOpacity(0.92) : Colors.white.withOpacity(0.95),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: isDark ? AppColors.borderDark.withOpacity(0.5) : AppColors.borderLight.withOpacity(0.5),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(isDark ? 0.4 : 0.08),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(24),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 8),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: List.generate(items.length, (index) {
              final item = items[index];
              final isSelected = currentIndex == index;
              final color = isSelected ? activeColor : (isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight);

              return InkWell(
                onTap: () => onTap(index),
                borderRadius: BorderRadius.circular(16),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 250),
                  padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
                  decoration: BoxDecoration(
                    color: isSelected
                        ? activeColor.withOpacity(isDark ? 0.15 : 0.08)
                        : Colors.transparent,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        isSelected ? item.selectedIcon : item.unselectedIcon,
                        color: color,
                        size: 20,
                      ),
                      if (isSelected) ...[
                        const SizedBox(width: 8),
                        Text(
                          item.label,
                          style: AppTextStyles.labelMedium(activeColor).copyWith(
                            fontWeight: FontWeight.bold,
                            letterSpacing: 0.1,
                          ),
                        ),
                      ]
                    ],
                  ),
                ),
              );
            }),
          ),
        ),
      ),
    );
  }
}
