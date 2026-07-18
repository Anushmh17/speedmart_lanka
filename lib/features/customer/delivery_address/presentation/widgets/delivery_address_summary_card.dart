import 'package:flutter/material.dart';
import '../../../../../core/theme/app_colors.dart';
import '../../../../../core/theme/app_text_styles.dart';
import '../../../../location/models/delivery_location.dart';

class DeliveryAddressSummaryCard extends StatelessWidget {
  const DeliveryAddressSummaryCard({
    super.key,
    required this.location,
    required this.onChange,
    this.isRequestOnly = false,
  });

  final DeliveryLocation location;
  final VoidCallback onChange;
  final bool isRequestOnly;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primaryText =
        isDark ? AppColors.textPrimaryDark : AppColors.textPrimaryLight;
    final secondaryText =
        isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight;
    final cardColor = isDark ? AppColors.cardDark : AppColors.cardLight;
    final borderColor = isDark ? AppColors.borderDark : AppColors.borderLight;

    final area = location.approximateAreaText.isNotEmpty
        ? location.approximateAreaText
        : location.displayArea;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: borderColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.location_on_rounded,
                  color: AppColors.customerColor, size: 20),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  isRequestOnly ? 'Delivery (this request)' : 'Default Delivery Address',
                  style: AppTextStyles.subtitle(primaryText),
                ),
              ),
              TextButton(onPressed: onChange, child: const Text('Change')),
            ],
          ),
          const SizedBox(height: 8),
          Text(area, style: AppTextStyles.bodyMedium(primaryText)),
          if (location.district.isNotEmpty)
            Text(
              '${location.district}, ${location.province}',
              style: AppTextStyles.bodySmall(secondaryText),
            ),
          const SizedBox(height: 4),
          Text(
            location.streetAddress,
            style: AppTextStyles.bodySmall(secondaryText),
          ),
          if (location.deliveryNote.isNotEmpty) ...[
            const SizedBox(height: 6),
            Text(
              'Note: ${location.deliveryNote}',
              style: AppTextStyles.caption(secondaryText),
            ),
          ],
        ],
      ),
    );
  }
}
