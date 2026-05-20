import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../models/request_item.dart';
import 'request_item_card.dart';
import 'category_selector.dart';

class ShoppingListBuilder extends StatelessWidget {
  final List<RequestItem> items;
  final bool isMixedCategory;
  final String globalCategory;
  final ValueChanged<List<RequestItem>> onItemsChanged;
  final ValueChanged<bool> onModeChanged;
  final ValueChanged<String> onGlobalCategoryChanged;

  const ShoppingListBuilder({
    super.key,
    required this.items,
    required this.isMixedCategory,
    required this.globalCategory,
    required this.onItemsChanged,
    required this.onModeChanged,
    required this.onGlobalCategoryChanged,
  });

  void _addItem() {
    final newItem = RequestItem(
      id: const Uuid().v4(),
      itemName: '',
      quantity: 1,
      unit: isMixedCategory ? 'pieces' : _getCategoryDefaultUnit(globalCategory),
      category: isMixedCategory ? 'Groceries' : globalCategory,
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
        content: const Text('Are you sure you want to clear all items from your shopping list? This cannot be undone.'),
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
        // Mode Selector (Same vs Mixed)
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: isDark ? AppColors.surfaceDark : Colors.grey.shade50,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: borderColor),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Shopping List Category Mode',
                style: AppTextStyles.labelMedium(primaryText),
              ),
              const SizedBox(height: 4),
              Text(
                'Same Category is best for groceries. Mixed is best for multiple different product types.',
                style: AppTextStyles.caption(secondaryText),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: ChoiceChip(
                      label: const Center(child: Text('Same Category')),
                      selected: !isMixedCategory,
                      onSelected: (selected) {
                        if (selected) {
                          onModeChanged(false);
                          // Sync category for all items
                          final synced = items.map((i) => i.copyWith(category: globalCategory)).toList();
                          onItemsChanged(synced);
                        }
                      },
                      selectedColor: AppColors.customerColor.withOpacity(0.15),
                      checkmarkColor: AppColors.customerColor,
                      labelStyle: AppTextStyles.bodySmall(
                        !isMixedCategory ? AppColors.customerColor : secondaryText,
                      ).copyWith(fontWeight: !isMixedCategory ? FontWeight.bold : FontWeight.normal),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: ChoiceChip(
                      label: const Center(child: Text('Mixed Categories')),
                      selected: isMixedCategory,
                      onSelected: (selected) {
                        if (selected) {
                          onModeChanged(true);
                        }
                      },
                      selectedColor: AppColors.customerColor.withOpacity(0.15),
                      checkmarkColor: AppColors.customerColor,
                      labelStyle: AppTextStyles.bodySmall(
                        isMixedCategory ? AppColors.customerColor : secondaryText,
                      ).copyWith(fontWeight: isMixedCategory ? FontWeight.bold : FontWeight.normal),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),

        // Global Category Selector if Same Category Mode (Mode A) is selected
        if (!isMixedCategory) ...[
          Text('Select Shopping List Category', style: AppTextStyles.subtitle(primaryText)),
          const SizedBox(height: 4),
          Text('All items in this list will be created under this category.', style: AppTextStyles.caption(secondaryText)),
          const SizedBox(height: 10),
          CategorySelector(
            selectedCategory: globalCategory,
            compact: true,
            onSelected: (cat) {
              onGlobalCategoryChanged(cat);
              // Sync category for all existing items in the list
              final synced = items.map((i) => i.copyWith(category: cat)).toList();
              onItemsChanged(synced);
            },
          ),
          const SizedBox(height: 20),
        ],

        // Items Header Row
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Shopping List Builder',
              style: AppTextStyles.h2(primaryText),
            ),
            if (items.isNotEmpty)
              TextButton.icon(
                icon: const Icon(Icons.clear_all_rounded, size: 18, color: AppColors.error),
                label: Text('Clear All', style: AppTextStyles.bodySmall(AppColors.error).copyWith(fontWeight: FontWeight.bold)),
                onPressed: () => _clearAll(context),
              ),
          ],
        ),
        const SizedBox(height: 12),

        // Empty State or Item Cards
        if (items.isEmpty)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 40, horizontal: 20),
            decoration: BoxDecoration(
              color: isDark ? Colors.black12 : Colors.grey.shade50,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: borderColor, style: BorderStyle.solid),
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
                  'Tap "Add Item" to write down your first request.',
                  textAlign: TextAlign.center,
                  style: AppTextStyles.caption(secondaryText),
                ),
                const SizedBox(height: 20),
                ElevatedButton.icon(
                  onPressed: _addItem,
                  icon: const Icon(Icons.add_rounded, color: Colors.white),
                  label: const Text('Add First Item'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.customerColor,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                  ),
                ),
              ],
            ),
          )
        else ...[
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
                isMixedCategory: isMixedCategory,
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
          // Add Another Item Button
          SizedBox(
            width: double.infinity,
            height: 52,
            child: OutlinedButton.icon(
              onPressed: _addItem,
              icon: const Icon(Icons.add_rounded, color: AppColors.customerColor),
              label: Text('Add Another Item', style: AppTextStyles.button(AppColors.customerColor)),
              style: OutlinedButton.styleFrom(
                side: const BorderSide(color: AppColors.customerColor, width: 1.5),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              ),
            ),
          ),
        ],
      ],
    );
  }
}
