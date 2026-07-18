import 'package:flutter/material.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../core/widgets/safe_request_image.dart';
import '../../models/request_item.dart';

class RequestItemListTile extends StatelessWidget {
  const RequestItemListTile({
    super.key,
    required this.item,
    required this.onTap,
    this.enabled = true,
  });

  final RequestItem item;
  final VoidCallback? onTap;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primaryText = isDark ? AppColors.textPrimaryDark : AppColors.textPrimaryLight;
    final secondaryText = isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight;
    final cardColor = isDark ? AppColors.cardDark : AppColors.cardLight;
    final borderColor = isDark ? AppColors.borderDark : AppColors.borderLight;
    final hasImages = item.imageUrls.isNotEmpty;
    final imageCount = item.imageUrls.length;

    return Opacity(
      opacity: enabled ? 1 : 0.55,
      child: Material(
        color: cardColor,
        borderRadius: BorderRadius.circular(16),
        child: InkWell(
          onTap: enabled ? onTap : null,
          borderRadius: BorderRadius.circular(16),
          child: Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: borderColor),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Stack(
                  clipBehavior: Clip.none,
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(12),
                      child: hasImages
                          ? SafeRequestImage(
                              path: item.imageUrls.first,
                              width: 72,
                              height: 72,
                              fit: BoxFit.cover,
                            )
                          : Container(
                              width: 72,
                              height: 72,
                              color: AppColors.customerColor.withValues(alpha: 0.08),
                              child: const Icon(Icons.shopping_bag_outlined, color: AppColors.customerColor, size: 28),
                            ),
                    ),
                    if (imageCount > 1)
                      Positioned(
                        right: -4,
                        bottom: -4,
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: AppColors.customerColor,
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Text(
                            '+${imageCount - 1}',
                            style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold),
                          ),
                        ),
                      ),
                  ],
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(item.itemName, style: AppTextStyles.bodyLarge(primaryText).copyWith(fontWeight: FontWeight.w600)),
                      const SizedBox(height: 4),
                      Text(item.category ?? 'General', style: AppTextStyles.caption(secondaryText)),
                      if (item.preferredBrand != null && item.preferredBrand!.isNotEmpty)
                        Text('Brand: ${item.preferredBrand}', style: AppTextStyles.caption(secondaryText), maxLines: 1, overflow: TextOverflow.ellipsis),
                      if (item.description != null && item.description!.isNotEmpty)
                        Text(item.description!, maxLines: 2, overflow: TextOverflow.ellipsis, style: AppTextStyles.bodySmall(secondaryText)),
                    ],
                  ),
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text('x${item.quantity}', style: AppTextStyles.subtitle(primaryText).copyWith(fontWeight: FontWeight.bold)),
                    if (item.unit != null && item.unit!.isNotEmpty) Text(item.unit!, style: AppTextStyles.caption(secondaryText)),
                    const SizedBox(height: 8),
                    Icon(Icons.chevron_right_rounded, color: enabled ? AppColors.customerColor : secondaryText.withValues(alpha: 0.5), size: 22),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
