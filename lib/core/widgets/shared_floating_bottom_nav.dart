import 'package:flutter/material.dart';
import '../theme/app_colors.dart';
import '../theme/app_text_styles.dart';

class SharedFloatingBottomNavItem {
  final IconData unselectedIcon;
  final IconData selectedIcon;
  final String label;
  final int? badgeCount;

  const SharedFloatingBottomNavItem({
    required this.unselectedIcon,
    required this.selectedIcon,
    required this.label,
    this.badgeCount,
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
    final safeBottom = MediaQuery.of(context).padding.bottom;

    return Padding(
      padding: EdgeInsets.fromLTRB(20, 0, 20, safeBottom + 14),
      child: Container(
        height: 72,
        decoration: BoxDecoration(
          color: isDark
              ? AppColors.surfaceElevatedDark
              : Colors.white,
          borderRadius: BorderRadius.circular(32),
          border: Border.all(
            color: isDark
                ? Colors.white.withValues(alpha: 0.22)
                : AppColors.borderLight.withValues(alpha: 0.8),
            width: 1,
          ),
          boxShadow: [
            BoxShadow(
              color: activeColor.withValues(alpha: isDark ? 0.18 : 0.12),
              blurRadius: 24,
              spreadRadius: 0,
              offset: const Offset(0, 6),
            ),
            BoxShadow(
              color: Colors.black.withValues(alpha: isDark ? 0.35 : 0.07),
              blurRadius: 16,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: List.generate(items.length, (index) {
              final item = items[index];
              final isSelected = currentIndex == index;
              final color = isSelected
                  ? activeColor
                  : (isDark
                      ? AppColors.textSecondaryDark
                      : AppColors.textSecondaryLight);

              return Expanded(
                child: GestureDetector(
                  onTap: () => onTap(index),
                  behavior: HitTestBehavior.opaque,
                  child: Center(
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 260),
                      curve: Curves.easeInOut,
                      padding: const EdgeInsets.symmetric(
                          vertical: 7, horizontal: 14),
                      decoration: BoxDecoration(
                        color: isSelected
                            ? activeColor.withValues(
                                alpha: isDark ? 0.18 : 0.11)
                            : Colors.transparent,
                        borderRadius: BorderRadius.circular(22),
                      ),
                      child: Stack(
                        clipBehavior: Clip.none,
                        children: [
                          Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                isSelected
                                    ? item.selectedIcon
                                    : item.unselectedIcon,
                                color: color,
                                size: 22,
                              ),
                              const SizedBox(height: 3),
                              Text(
                                item.label,
                                style: AppTextStyles.labelSmall(color).copyWith(
                                  fontWeight: isSelected
                                      ? FontWeight.w700
                                      : FontWeight.w500,
                                  fontSize: 10,
                                ),
                              ),
                            ],
                          ),
                          if (item.badgeCount != null && item.badgeCount! > 0)
                            Positioned(
                              top: -4,
                              right: -8,
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                decoration: BoxDecoration(
                                  color: AppColors.error,
                                  borderRadius: BorderRadius.circular(999),
                                ),
                                constraints: const BoxConstraints(minWidth: 18, minHeight: 18),
                                child: Text(
                                  item.badgeCount! > 99 ? '99+' : item.badgeCount!.toString(),
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 10,
                                    fontWeight: FontWeight.w700,
                                  ),
                                  textAlign: TextAlign.center,
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
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

