import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../models/request_item.dart';
import 'request_item_card.dart';
import 'category_selector.dart';

class ShoppingListBuilder extends StatelessWidget {
  final List<RequestItem> items;
  final bool? isMixedCategory;
  final String? globalCategory;
  final String? preselectedCategory;
  final ValueChanged<List<RequestItem>> onItemsChanged;
  final ValueChanged<bool> onModeChanged;
  final ValueChanged<String> onGlobalCategoryChanged;

  const ShoppingListBuilder({
    super.key,
    required this.items,
    required this.isMixedCategory,
    required this.globalCategory,
    this.preselectedCategory,
    required this.onItemsChanged,
    required this.onModeChanged,
    required this.onGlobalCategoryChanged,
  });

  void _addItem() {
    final newItem = RequestItem(
      id: const Uuid().v4(),
      itemName: '',
      quantity: 1,
      unit: (isMixedCategory ?? false) ? 'pieces' : _getCategoryDefaultUnit(globalCategory ?? ''),
      category: (isMixedCategory ?? false) ? null : globalCategory,
    );
    onItemsChanged([...items, newItem]);
  }

  void _duplicateItem(int index) {
    final original = items[index];
    final duplicate = original.copyWith(
      id: const Uuid().v4(),
      itemName: original.itemName.isNotEmpty ? '${original.itemName} (Copy)' : '',
    );
    final newList = List<RequestItem>.from(items);
    newList.insert(index + 1, duplicate);
    onItemsChanged(newList);
  }

  void _removeItem(int index) {
    final newList = List<RequestItem>.from(items)..removeAt(index);
    onItemsChanged(newList);
  }

  void _clearAll(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Clear all items?'),
        content: const Text(
            'Are you sure you want to clear all items from your shopping list? This cannot be undone.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              onItemsChanged([]);
              Navigator.pop(context);
            },
            style: TextButton.styleFrom(foregroundColor: AppColors.error),
            child: const Text('Clear All'),
          ),
        ],
      ),
    );
  }

  String _getCategoryDefaultUnit(String cat) {
    if (cat == 'Groceries') return 'kg';
    return 'pieces';
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primaryText = isDark ? AppColors.textPrimaryDark : AppColors.textPrimaryLight;
    final secondaryText = isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight;
    final borderColor = isDark ? AppColors.borderDark : AppColors.borderLight;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // ── Mode Header ─────────────────────────────────────────────────────
        Padding(
          padding: const EdgeInsets.only(bottom: 14),
          child: Text(
            'Choose how you want to create your list',
            style: AppTextStyles.subtitle(primaryText).copyWith(
              fontWeight: FontWeight.w700,
            ),
          ),
        ),

        // ── Premium Same / Mixed Category Cards ─────────────────────────────
        _CategoryModeCard(
          icon: Icons.label_rounded,
          title: 'Same Category',
          description: 'All items belong to one category',
          accentColor: const Color(0xFF16A34A),
          accentBgLight: const Color(0xFFDCFCE7),
          accentBgDark: const Color(0xFF052E16),
          isSelected: isMixedCategory == false,
          isDark: isDark,
          onTap: () {
            if (isMixedCategory == false) return;
            onModeChanged(false);
            final cat = globalCategory ?? preselectedCategory;
            if (cat != null) {
              onGlobalCategoryChanged(cat);
              final synced = items.map((i) => i.copyWith(category: cat)).toList();
              onItemsChanged(synced);
            } else {
              final synced = items.map((i) => i.copyWith(category: globalCategory)).toList();
              onItemsChanged(synced);
            }
          },
        ),
        const SizedBox(height: 14),
        _CategoryModeCard(
          icon: Icons.layers_rounded,
          title: 'Mixed Categories',
          description: 'Items can be from different categories',
          accentColor: const Color(0xFF7C3AED),
          accentBgLight: const Color(0xFFEDE9FE),
          accentBgDark: const Color(0xFF1A0D33),
          isSelected: isMixedCategory == true,
          isDark: isDark,
          onTap: () {
            if (isMixedCategory == true) return;
            onModeChanged(true);
          },
        ),

        const SizedBox(height: 28),

        // ── Global Category Selector (Same Category mode only) ─────────────
        if (isMixedCategory == false) ...[
          Text(
            'Shopping List Category',
            style: AppTextStyles.subtitle(primaryText).copyWith(
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'All items in this list will be under this category.',
            style: AppTextStyles.caption(secondaryText),
          ),
          const SizedBox(height: 12),
          CategorySelector(
            selectedCategory: globalCategory,
            compact: true,
            onSelected: (cat) {
              onGlobalCategoryChanged(cat);
              final synced = items.map((i) => i.copyWith(category: cat)).toList();
              onItemsChanged(synced);
            },
          ),
          const SizedBox(height: 28),
        ],

        // ── Items Header Row ────────────────────────────────────────────────
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Items in this list (${items.length})',
              style: AppTextStyles.h2(primaryText),
            ),
            if (items.isNotEmpty)
              TextButton.icon(
                icon: const Icon(Icons.clear_all_rounded, size: 16, color: AppColors.error),
                label: Text(
                  'Clear All',
                  style: AppTextStyles.bodySmall(AppColors.error).copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                onPressed: () => _clearAll(context),
                style: TextButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                ),
              ),
          ],
        ),
        const SizedBox(height: 12),

        // ── Empty State ─────────────────────────────────────────────────────
        if (items.isEmpty)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 36, horizontal: 20),
            decoration: BoxDecoration(
              color: isDark ? Colors.black12 : Colors.grey.shade50,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: borderColor),
            ),
            child: Column(
              children: [
                Icon(
                  Icons.receipt_long_outlined,
                  size: 48,
                  color: secondaryText.withOpacity(0.4),
                ),
                const SizedBox(height: 12),
                Text(
                  'Your Shopping List is Empty',
                  style: AppTextStyles.subtitle(primaryText),
                ),
                const SizedBox(height: 6),
                Text(
                  'Tap "+ Add item" to write down your first request.',
                  textAlign: TextAlign.center,
                  style: AppTextStyles.caption(secondaryText),
                ),
                const SizedBox(height: 20),
                SizedBox(
                  width: 180,
                  height: 44,
                  child: ElevatedButton.icon(
                    onPressed: _addItem,
                    icon: const Icon(Icons.add_rounded, color: Colors.white, size: 18),
                    label: const Text('Add First Item'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.customerColor,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12)),
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                      elevation: 0,
                    ),
                  ),
                ),
              ],
            ),
          )
        else ...[
          // ── Item Cards ──────────────────────────────────────────────────
          ListView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: items.length,
            itemBuilder: (context, index) {
              final item = items[index];
              return RequestItemCard(
                key: ValueKey(item.id),
                item: item,
                itemNumber: index + 1,
                isMixedCategory: isMixedCategory ?? false,
                onChanged: (updatedItem) {
                  final newList = List<RequestItem>.from(items);
                  newList[index] = updatedItem;
                  onItemsChanged(newList);
                },
                onRemove: () => _removeItem(index),
                onDuplicate: () => _duplicateItem(index),
              );
            },
          ),
          const SizedBox(height: 12),

          // ── Add Another Item Button (fixed overflow) ────────────────────
          SizedBox(
            width: double.infinity,
            height: 50,
            child: OutlinedButton(
              onPressed: _addItem,
              style: OutlinedButton.styleFrom(
                side: const BorderSide(color: AppColors.customerColor, width: 1.5),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14)),
                padding: const EdgeInsets.symmetric(horizontal: 12),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.add_rounded, color: AppColors.customerColor, size: 20),
                  const SizedBox(width: 8),
                  Flexible(
                    child: Text(
                      '+ Add Item',
                      style: AppTextStyles.button(AppColors.customerColor),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ],
    );
  }
}

// ── Premium Category Mode Card ─────────────────────────────────────────────────

class _CategoryModeCard extends StatefulWidget {
  const _CategoryModeCard({
    required this.icon,
    required this.title,
    required this.description,
    required this.accentColor,
    required this.accentBgLight,
    required this.accentBgDark,
    required this.isSelected,
    required this.isDark,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String description;
  final Color accentColor;
  final Color accentBgLight;
  final Color accentBgDark;
  final bool isSelected;
  final bool isDark;
  final VoidCallback onTap;

  @override
  State<_CategoryModeCard> createState() => _CategoryModeCardState();
}

class _CategoryModeCardState extends State<_CategoryModeCard> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    final primaryText =
        widget.isDark ? AppColors.textPrimaryDark : AppColors.textPrimaryLight;
    final secondaryText =
        widget.isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight;
    final cardBg = widget.isDark ? AppColors.cardDark : Colors.white;
    final borderColor =
        widget.isDark ? AppColors.borderDark : AppColors.borderLight;

    final selectedBg =
        widget.accentColor.withOpacity(widget.isDark ? 0.12 : 0.07);

    return GestureDetector(
      onTapDown: (_) => setState(() => _pressed = true),
      onTapUp: (_) {
        setState(() => _pressed = false);
        widget.onTap();
      },
      onTapCancel: () => setState(() => _pressed = false),
      child: AnimatedScale(
        scale: _pressed ? 0.98 : 1.0,
        duration: const Duration(milliseconds: 100),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          decoration: BoxDecoration(
            color: widget.isSelected ? selectedBg : cardBg,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color:
                  widget.isSelected ? widget.accentColor : borderColor,
              width: widget.isSelected ? 2 : 1,
            ),
            boxShadow: widget.isSelected
                ? [
                    BoxShadow(
                      color: widget.accentColor.withOpacity(0.15),
                      blurRadius: 12,
                      offset: const Offset(0, 4),
                    ),
                  ]
                : [
                    BoxShadow(
                      color: Colors.black
                          .withOpacity(widget.isDark ? 0.15 : 0.04),
                      blurRadius: 6,
                      offset: const Offset(0, 2),
                    ),
                  ],
          ),
          child: Row(
            children: [
              // Icon box
              AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: widget.isSelected
                      ? widget.accentColor
                      : (widget.isDark
                          ? widget.accentBgDark
                          : widget.accentBgLight),
                  borderRadius: BorderRadius.circular(13),
                  boxShadow: widget.isSelected
                      ? [
                          BoxShadow(
                            color: widget.accentColor.withOpacity(0.35),
                            blurRadius: 10,
                            offset: const Offset(0, 4),
                          ),
                        ]
                      : [],
                ),
                child: Icon(
                  widget.icon,
                  size: 24,
                  color: widget.isSelected ? Colors.white : widget.accentColor,
                ),
              ),
              const SizedBox(width: 14),

              // Text
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      widget.title,
                      style: AppTextStyles.bodyMedium(primaryText).copyWith(
                        fontWeight: FontWeight.w700,
                        color: widget.isSelected
                            ? widget.accentColor
                            : primaryText,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      widget.description,
                      style: AppTextStyles.caption(secondaryText),
                    ),
                  ],
                ),
              ),

              // Radio indicator
              AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                width: 22,
                height: 22,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: widget.isSelected
                      ? widget.accentColor
                      : Colors.transparent,
                  border: Border.all(
                    color: widget.isSelected
                        ? widget.accentColor
                        : (widget.isDark
                            ? AppColors.borderDark
                            : AppColors.borderLight),
                    width: 2,
                  ),
                ),
                child: widget.isSelected
                    ? const Icon(Icons.check_rounded, size: 13, color: Colors.white)
                    : null,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

