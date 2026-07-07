import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../admin/providers/category_provider.dart';

// ── Category color & icon config ──────────────────────────────────────────────

class _CategoryMeta {
  final IconData icon;
  final Color color;
  final Color lightBg;
  final Color darkBg;

  const _CategoryMeta({
    required this.icon,
    required this.color,
    required this.lightBg,
    required this.darkBg,
  });
}

const Map<String, _CategoryMeta> _categoryMeta = {
  'groceries': _CategoryMeta(
    icon: Icons.local_grocery_store_rounded,
    color: Color(0xFF16A34A),
    lightBg: Color(0xFFDCFCE7),
    darkBg: Color(0xFF052E16),
  ),
  'electronics': _CategoryMeta(
    icon: Icons.devices_rounded,
    color: Color(0xFF2563EB),
    lightBg: Color(0xFFDBEAFE),
    darkBg: Color(0xFF0D1A33),
  ),
  'hardware': _CategoryMeta(
    icon: Icons.handyman_rounded,
    color: Color(0xFFEA580C),
    lightBg: Color(0xFFFFEDD5),
    darkBg: Color(0xFF2C0F00),
  ),
  'furniture': _CategoryMeta(
    icon: Icons.weekend_rounded,
    color: Color(0xFF7C3AED),
    lightBg: Color(0xFFEDE9FE),
    darkBg: Color(0xFF1A0D33),
  ),
  'pharmacy': _CategoryMeta(
    icon: Icons.local_pharmacy_rounded,
    color: Color(0xFFDC2626),
    lightBg: Color(0xFFFEE2E2),
    darkBg: Color(0xFF2D0A0A),
  ),
  'clothing': _CategoryMeta(
    icon: Icons.checkroom_rounded,
    color: Color(0xFFDB2777),
    lightBg: Color(0xFFFCE7F3),
    darkBg: Color(0xFF2D0D1A),
  ),
  'vehicle_parts': _CategoryMeta(
    icon: Icons.directions_car_rounded,
    color: Color(0xFF4338CA),
    lightBg: Color(0xFFE0E7FF),
    darkBg: Color(0xFF0E0D2E),
  ),
  'home_appliances': _CategoryMeta(
    icon: Icons.kitchen_rounded,
    color: Color(0xFF0891B2),
    lightBg: Color(0xFFCFFAFE),
    darkBg: Color(0xFF042633),
  ),
  'stationery': _CategoryMeta(
    icon: Icons.edit_note_rounded,
    color: Color(0xFFD97706),
    lightBg: Color(0xFFFEF3C7),
    darkBg: Color(0xFF2C1800),
  ),
  'sports_&_outdoors': _CategoryMeta(
    icon: Icons.sports_soccer_rounded,
    color: Color(0xFF059669),
    lightBg: Color(0xFFD1FAE5),
    darkBg: Color(0xFF062E1A),
  ),
  'books_&_stationery': _CategoryMeta(
    icon: Icons.menu_book_rounded,
    color: Color(0xFFD97706),
    lightBg: Color(0xFFFEF3C7),
    darkBg: Color(0xFF2C1800),
  ),
  'baby_&_kids': _CategoryMeta(
    icon: Icons.child_care_rounded,
    color: Color(0xFFDB2777),
    lightBg: Color(0xFFFCE7F3),
    darkBg: Color(0xFF2D0D1A),
  ),
  'toys_&_games': _CategoryMeta(
    icon: Icons.sports_esports_rounded,
    color: Color(0xFF7C3AED),
    lightBg: Color(0xFFEDE9FE),
    darkBg: Color(0xFF1A0D33),
  ),
  'pet_supplies': _CategoryMeta(
    icon: Icons.pets_rounded,
    color: Color(0xFFEA580C),
    lightBg: Color(0xFFFFEDD5),
    darkBg: Color(0xFF2C0F00),
  ),
  'office_supplies': _CategoryMeta(
    icon: Icons.business_center_rounded,
    color: Color(0xFF2563EB),
    lightBg: Color(0xFFDBEAFE),
    darkBg: Color(0xFF0D1A33),
  ),
  'building_materials': _CategoryMeta(
    icon: Icons.foundation_rounded,
    color: Color(0xFF92400E),
    lightBg: Color(0xFFFEF3C7),
    darkBg: Color(0xFF1C0E00),
  ),
  'automotive': _CategoryMeta(
    icon: Icons.car_repair_rounded,
    color: Color(0xFF4338CA),
    lightBg: Color(0xFFE0E7FF),
    darkBg: Color(0xFF0E0D2E),
  ),
  'agriculture': _CategoryMeta(
    icon: Icons.grass_rounded,
    color: Color(0xFF16A34A),
    lightBg: Color(0xFFDCFCE7),
    darkBg: Color(0xFF052E16),
  ),
  'tools_&_equipment': _CategoryMeta(
    icon: Icons.build_rounded,
    color: Color(0xFFEA580C),
    lightBg: Color(0xFFFFEDD5),
    darkBg: Color(0xFF2C0F00),
  ),
  'jewelry_&_watches': _CategoryMeta(
    icon: Icons.watch_rounded,
    color: Color(0xFFD97706),
    lightBg: Color(0xFFFEF3C7),
    darkBg: Color(0xFF2C1800),
  ),
  'other': _CategoryMeta(
    icon: Icons.category_rounded,
    color: Color(0xFF6B7280),
    lightBg: Color(0xFFF3F4F6),
    darkBg: Color(0xFF1A1A1A),
  ),
};

_CategoryMeta _metaFor(String displayName) {
  final key = displayName.toLowerCase().replaceAll(' ', '_');
  return _categoryMeta[key] ??
      const _CategoryMeta(
        icon: Icons.category_rounded,
        color: Color(0xFF6B7280),
        lightBg: Color(0xFFF3F4F6),
        darkBg: Color(0xFF1A1A1A),
      );
}

// ── Public CategorySelector widget ───────────────────────────────────────────

class CategorySelector extends ConsumerWidget {
  final String? selectedCategory;
  final ValueChanged<String> onSelected;
  // ignore: unused_field
  final bool compact;

  const CategorySelector({
    super.key,
    required this.selectedCategory,
    required this.onSelected,
    this.compact = false,
  });

  void _showCategoryModal(BuildContext context, bool isDark) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => _CategoryPickerSheet(
        selectedCategory: selectedCategory,
        isDark: isDark,
        onSelected: (cat) {
          onSelected(cat);
          Navigator.pop(ctx);
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primaryText = isDark ? AppColors.textPrimaryDark : AppColors.textPrimaryLight;
    final secondaryText = isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight;
    final cardColor = isDark ? AppColors.cardDark : AppColors.cardLight;
    final borderColor = isDark ? AppColors.borderDark : AppColors.borderLight;

    // Always render as a compact tappable row → opens the bottom sheet modal
    final meta = selectedCategory != null ? _metaFor(selectedCategory!) : null;

    return GestureDetector(
      onTap: () => _showCategoryModal(context, isDark),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: cardColor,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: selectedCategory != null
                ? (meta?.color ?? AppColors.customerColor).withOpacity(0.4)
                : borderColor,
          ),
          boxShadow: [
            if (selectedCategory != null)
              BoxShadow(
                color: (meta?.color ?? AppColors.customerColor).withOpacity(0.08),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
          ],
        ),
        child: Row(
          children: [
            if (selectedCategory != null && meta != null) ...[
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: isDark ? meta.darkBg : meta.lightBg,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(meta.icon, color: meta.color, size: 20),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      selectedCategory!,
                      style: AppTextStyles.bodyMedium(primaryText).copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    Text(
                      'Tap to change category',
                      style: AppTextStyles.caption(secondaryText),
                    ),
                  ],
                ),
              ),
            ] else ...[
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: isDark ? Colors.white10 : Colors.grey.shade100,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(
                  Icons.category_outlined,
                  color: secondaryText,
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  'Select Category',
                  style: AppTextStyles.bodyMedium(secondaryText),
                ),
              ),
            ],
            Icon(
              Icons.chevron_right_rounded,
              color: selectedCategory != null
                  ? (meta?.color ?? AppColors.customerColor)
                  : secondaryText,
              size: 22,
            ),
          ],
        ),
      ),
    );
  }
}

// ── Category Picker Bottom Sheet ──────────────────────────────────────────────

class _CategoryPickerSheet extends ConsumerStatefulWidget {
  final String? selectedCategory;
  final bool isDark;
  final ValueChanged<String> onSelected;

  const _CategoryPickerSheet({
    required this.selectedCategory,
    required this.isDark,
    required this.onSelected,
  });

  @override
  ConsumerState<_CategoryPickerSheet> createState() => _CategoryPickerSheetState();
}

class _CategoryPickerSheetState extends ConsumerState<_CategoryPickerSheet> {
  final _searchController = TextEditingController();
  String _query = '';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = widget.isDark;
    final primaryText = isDark ? AppColors.textPrimaryDark : AppColors.textPrimaryLight;
    final secondaryText = isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight;
    final surfaceColor = isDark ? AppColors.surfaceDark : AppColors.surfaceLight;
    final searchBg = isDark ? AppColors.cardDark : const Color(0xFFF5F5F5);
    final borderColor = isDark ? AppColors.borderDark : AppColors.borderLight;

    final activeCategories = ref.watch(activeCategoriesProvider);
    final allNames = activeCategories.map((cat) => cat.displayName).toList();

    final filtered = _query.isEmpty
        ? allNames
        : allNames
            .where((n) => n.toLowerCase().contains(_query.toLowerCase()))
            .toList();

    return DraggableScrollableSheet(
      initialChildSize: 0.82,
      minChildSize: 0.5,
      maxChildSize: 0.95,
      expand: false,
      builder: (ctx, scrollController) {
        return Container(
          decoration: BoxDecoration(
            color: surfaceColor,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.18),
                blurRadius: 24,
                spreadRadius: 2,
              ),
            ],
          ),
          child: Column(
            children: [
              // Drag handle
              Padding(
                padding: const EdgeInsets.only(top: 12, bottom: 4),
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: isDark ? Colors.white24 : Colors.black12,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),

              // Header row
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 12, 12, 0),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Select Category',
                            style: AppTextStyles.h2(primaryText).copyWith(
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            'Choose the product category you need',
                            style: AppTextStyles.caption(secondaryText),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      onPressed: () => Navigator.pop(context),
                      icon: Icon(
                        Icons.close_rounded,
                        color: secondaryText,
                        size: 22,
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 12),

              // Search field
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Container(
                  height: 44,
                  decoration: BoxDecoration(
                    color: searchBg,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: borderColor),
                  ),
                  child: Row(
                    children: [
                      const SizedBox(width: 12),
                      Icon(Icons.search_rounded, size: 20, color: secondaryText),
                      const SizedBox(width: 8),
                      Expanded(
                        child: TextField(
                          controller: _searchController,
                          onChanged: (v) => setState(() => _query = v),
                          style: AppTextStyles.bodyMedium(primaryText),
                          decoration: InputDecoration(
                            hintText: 'Search categories...',
                            hintStyle: AppTextStyles.bodyMedium(secondaryText),
                            border: InputBorder.none,
                            isDense: true,
                            contentPadding: EdgeInsets.zero,
                          ),
                        ),
                      ),
                      if (_query.isNotEmpty)
                        GestureDetector(
                          onTap: () {
                            _searchController.clear();
                            setState(() => _query = '');
                          },
                          child: Padding(
                            padding: const EdgeInsets.only(right: 8),
                            child: Icon(Icons.cancel_rounded, size: 18, color: secondaryText),
                          ),
                        ),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 12),

              // Category grid
              Expanded(
                child: filtered.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.search_off_rounded, size: 48, color: secondaryText.withOpacity(0.4)),
                            const SizedBox(height: 12),
                            Text(
                              'No categories found',
                              style: AppTextStyles.bodyMedium(secondaryText),
                            ),
                          ],
                        ),
                      )
                    : GridView.builder(
                        controller: scrollController,
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: 3,
                          crossAxisSpacing: 10,
                          mainAxisSpacing: 10,
                          childAspectRatio: 0.88,
                        ),
                        itemCount: filtered.length,
                        itemBuilder: (context, index) {
                          final name = filtered[index];
                          final isSelected = widget.selectedCategory == name;
                          final meta = _metaFor(name);

                          return GestureDetector(
                            onTap: () => widget.onSelected(name),
                            child: AnimatedContainer(
                              duration: const Duration(milliseconds: 180),
                              decoration: BoxDecoration(
                                color: isSelected
                                    ? meta.color.withOpacity(isDark ? 0.2 : 0.12)
                                    : (isDark ? AppColors.cardDark : Colors.white),
                                borderRadius: BorderRadius.circular(14),
                                border: Border.all(
                                  color: isSelected
                                      ? meta.color
                                      : (isDark ? AppColors.borderDark : AppColors.borderLight),
                                  width: isSelected ? 1.8 : 1,
                                ),
                                boxShadow: isSelected
                                    ? [
                                        BoxShadow(
                                          color: meta.color.withOpacity(0.2),
                                          blurRadius: 8,
                                          offset: const Offset(0, 3),
                                        ),
                                      ]
                                    : [
                                        BoxShadow(
                                          color: Colors.black.withOpacity(isDark ? 0.12 : 0.04),
                                          blurRadius: 4,
                                          offset: const Offset(0, 1),
                                        ),
                                      ],
                              ),
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  // Colored icon container
                                  Container(
                                    width: 44,
                                    height: 44,
                                    decoration: BoxDecoration(
                                      color: isSelected
                                          ? meta.color.withOpacity(0.22)
                                          : (isDark ? meta.darkBg : meta.lightBg),
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    child: Icon(
                                      meta.icon,
                                      color: meta.color,
                                      size: 22,
                                    ),
                                  ),
                                  const SizedBox(height: 8),
                                  Padding(
                                    padding: const EdgeInsets.symmetric(horizontal: 4),
                                    child: Text(
                                      name,
                                      textAlign: TextAlign.center,
                                      maxLines: 2,
                                      overflow: TextOverflow.ellipsis,
                                      style: TextStyle(
                                        fontSize: 11,
                                        fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                                        color: isSelected ? meta.color : primaryText,
                                        height: 1.2,
                                      ),
                                    ),
                                  ),
                                  if (isSelected) ...[
                                    const SizedBox(height: 4),
                                    Icon(Icons.check_circle_rounded, size: 14, color: meta.color),
                                  ],
                                ],
                              ),
                            ),
                          );
                        },
                      ),
              ),

              // Bottom safe area padding
              const SizedBox(height: 16),
            ],
          ),
        );
      },
    );
  }
}
