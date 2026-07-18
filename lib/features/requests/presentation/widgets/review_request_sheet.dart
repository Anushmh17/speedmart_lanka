import 'package:flutter/material.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../core/widgets/app_button.dart';
import '../../../../core/widgets/safe_request_image.dart';
import '../../models/request_item.dart';

class ReviewRequestSheet extends StatelessWidget {
  /// Human-readable suburb / city / approximate area for vendors.
  final String suburbOrCity;
  final List<RequestItem> items;
  final VoidCallback onConfirm;
  final bool isLoading;

  const ReviewRequestSheet({
    super.key,
    required this.suburbOrCity,
    required this.items,
    required this.onConfirm,
    this.isLoading = false,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primaryText = isDark ? Colors.white : Colors.black;
    final secondaryText = isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight;
    final cardColor = isDark ? AppColors.surfaceDark : AppColors.surfaceLight;
    final borderColor = isDark ? AppColors.borderDark : AppColors.borderLight;

    return Container(
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
      ),
      padding: const EdgeInsets.all(20),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Header Drag Handle
          Center(
            child: Container(
              width: 48,
              height: 4,
              decoration: BoxDecoration(
                color: isDark ? Colors.white24 : Colors.black12,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 16),
          Text(
            'Review Request Summary',
            style: AppTextStyles.h1(primaryText),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 6),
          Text(
            'Please confirm details before dispatching to vendors',
            style: AppTextStyles.caption(secondaryText),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 16),

          // Scrollable Receipt Content
          Flexible(
            child: SingleChildScrollView(
              physics: const BouncingScrollPhysics(),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Location Block
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: isDark ? Colors.black26 : Colors.grey.shade50,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: borderColor),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            const Icon(Icons.my_location_rounded, color: AppColors.customerColor, size: 18),
                            const SizedBox(width: 8),
                            Text('Delivery Details', style: AppTextStyles.labelMedium(primaryText)),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Suburb / City: $suburbOrCity',
                          style: AppTextStyles.bodyMedium(primaryText).copyWith(fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            const Icon(Icons.lock_outline, size: 14, color: AppColors.customerColor),
                            const SizedBox(width: 4),
                            Expanded(
                              child: Text(
                                'Address: Hidden until confirmation',
                                style: AppTextStyles.bodySmall(secondaryText),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),

                  // Shopping Receipt Details Block
                  Text(
                    'Item List (${items.length} ${items.length == 1 ? "item" : "items"})',
                    style: AppTextStyles.subtitle(primaryText),
                  ),
                  const SizedBox(height: 8),

                  ListView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: items.length,
                    itemBuilder: (context, index) {
                      final item = items[index];
                      return Container(
                        margin: const EdgeInsets.only(bottom: 10),
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: isDark ? Colors.black12 : Colors.grey.shade50,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: borderColor),
                        ),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // Category Icon Indicator
                            Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: AppColors.customerColor.withOpacity(0.1),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Icon(
                                _getCategoryIcon(item.category),
                                color: AppColors.customerColor,
                                size: 18,
                              ),
                            ),
                            const SizedBox(width: 12),
                            // Item description detail block
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    item.itemName,
                                    style: AppTextStyles.bodyMedium(primaryText).copyWith(fontWeight: FontWeight.bold),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    'Category: ${item.category ?? "Groceries"} | Qty: ${item.quantity} ${item.unit ?? "pieces"}',
                                    style: AppTextStyles.caption(secondaryText),
                                  ),
                                  if (item.preferredBrand != null && item.preferredBrand!.isNotEmpty)
                                    Text(
                                      'Brand: ${item.preferredBrand}',
                                      style: AppTextStyles.caption(secondaryText),
                                    ),
                                  if (item.description != null && item.description!.isNotEmpty)
                                    Text(
                                      'Notes: ${item.description}',
                                      style: AppTextStyles.caption(secondaryText).copyWith(fontStyle: FontStyle.italic),
                                    ),
                                  if (item.imageUrls.isNotEmpty) ...[
                                    const SizedBox(height: 6),
                                    SizedBox(
                                      height: 36,
                                      child: ListView.builder(
                                        scrollDirection: Axis.horizontal,
                                        physics: const NeverScrollableScrollPhysics(),
                                        itemCount: item.imageUrls.length,
                                        itemBuilder: (context, idx) {
                                          return Padding(
                                            padding: const EdgeInsets.only(right: 6),
                                            child: SafeRequestImage(
                                              path: item.imageUrls[idx],
                                              width: 36,
                                              height: 36,
                                              fit: BoxFit.cover,
                                              borderRadius: BorderRadius.circular(6),
                                            ),
                                          );
                                        },
                                      ),
                                    )
                                  ]
                                ],
                              ),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 20),

          // Actions
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: isLoading ? null : () => Navigator.pop(context),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  ),
                  child: Text('Edit List', style: AppTextStyles.button(secondaryText)),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: AppButton(
                  label: isLoading ? 'Dispatching...' : 'Confirm & Submit',
                  onPressed: isLoading ? null : onConfirm,
                  color: AppColors.customerColor,
                  isLoading: isLoading,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  IconData _getCategoryIcon(String? cat) {
    switch (cat) {
      case 'Groceries':
        return Icons.local_grocery_store_outlined;
      case 'Vehicle parts':
        return Icons.settings_outlined;
      case 'Electronics':
        return Icons.devices_other_outlined;
      case 'Furniture':
        return Icons.weekend_outlined;
      case 'Home appliances':
        return Icons.kitchen_outlined;
      case 'Clothing':
        return Icons.checkroom_outlined;
      case 'Hardware items':
        return Icons.handyman_outlined;
      case 'Stationery':
        return Icons.edit_note_rounded;
      default:
        return Icons.more_horiz_rounded;
    }
  }
}

