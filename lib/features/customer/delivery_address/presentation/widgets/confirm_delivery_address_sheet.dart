import 'package:flutter/material.dart';
import '../../../../../core/theme/app_colors.dart';
import '../../../../../core/theme/app_text_styles.dart';
import '../../../../../core/widgets/app_button.dart';
import '../../../../location/models/delivery_location.dart';

class ConfirmDeliveryAddressSheet extends StatelessWidget {
  const ConfirmDeliveryAddressSheet({
    super.key,
    required this.location,
    required this.onConfirm,
    required this.onChangeAddress,
    this.isLoading = false,
  });

  final DeliveryLocation location;
  final VoidCallback onConfirm;
  final VoidCallback onChangeAddress;
  final bool isLoading;

  static Future<void> show(
    BuildContext context, {
    required DeliveryLocation location,
    required VoidCallback onConfirm,
    required VoidCallback onChangeAddress,
    bool isLoading = false,
  }) {
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => ConfirmDeliveryAddressSheet(
        location: location,
        onConfirm: onConfirm,
        onChangeAddress: onChangeAddress,
        isLoading: isLoading,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primaryText = isDark ? AppColors.textPrimaryDark : AppColors.textPrimaryLight;
    final secondaryText = isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight;
    final cardColor = isDark ? AppColors.surfaceDark : AppColors.surfaceLight;

    final area = location.approximateAreaText.isNotEmpty
        ? location.approximateAreaText
        : location.displayArea;

    return Container(
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
      ),
      padding: EdgeInsets.fromLTRB(20, 16, 20, 20 + MediaQuery.paddingOf(context).bottom),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
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
          Text('Confirm delivery address', style: AppTextStyles.h2(primaryText), textAlign: TextAlign.center),
          const SizedBox(height: 8),
          Text(
            'Shop owners see only your approximate area until you confirm an order.',
            style: AppTextStyles.caption(secondaryText),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 20),
          _row('Approximate Area', area, primaryText, secondaryText),
          _row('District', location.district, primaryText, secondaryText),
          _row('Province', location.province, primaryText, secondaryText),
          _row('Street Address', location.streetAddress, primaryText, secondaryText),
          if (location.deliveryNote.isNotEmpty)
            _row('Delivery Note', location.deliveryNote, primaryText, secondaryText),
          const SizedBox(height: 24),
          AppButton(
            label: 'Confirm & Submit Request',
            isLoading: isLoading,
            onPressed: isLoading ? null : onConfirm,
          ),
          const SizedBox(height: 10),
          OutlinedButton(
            onPressed: isLoading ? null : onChangeAddress,
            child: const Text('Change Address'),
          ),
        ],
      ),
    );
  }

  Widget _row(String label, String value, Color primary, Color secondary) {
    if (value.trim().isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: AppTextStyles.caption(secondary)),
          const SizedBox(height: 4),
          Text(value, style: AppTextStyles.bodyMedium(primary)),
        ],
      ),
    );
  }
}
