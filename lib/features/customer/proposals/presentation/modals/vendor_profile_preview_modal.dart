import 'package:flutter/material.dart';
import '../../../../../core/theme/app_colors.dart';
import '../../../../../core/theme/app_text_styles.dart';
import '../../../../proposals/models/proposal.dart';

class VendorProfilePreviewModal extends StatelessWidget {
  const VendorProfilePreviewModal({
    super.key,
    required this.proposal,
    required this.requestId,
  });

  final Proposal proposal;
  final String requestId;

  static void show(
    BuildContext context, {
    required Proposal proposal,
    required String requestId,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor:
          isDark ? AppColors.surfaceDark : AppColors.surfaceLight,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.only(
          topLeft: Radius.circular(24),
          topRight: Radius.circular(24),
        ),
      ),
      builder: (context) {
        return DraggableScrollableSheet(
          expand: false,
          initialChildSize: 0.7,
          minChildSize: 0.5,
          maxChildSize: 0.95,
          builder: (context, scrollController) {
            return VendorProfilePreviewModal(
              proposal: proposal,
              requestId: requestId,
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primaryText =
        isDark ? AppColors.textPrimaryDark : AppColors.textPrimaryLight;
    final secondaryText = isDark
        ? AppColors.textSecondaryDark
        : AppColors.textSecondaryLight;
    final cardColor = isDark ? AppColors.cardDark : AppColors.cardLight;
    final borderColor = isDark ? AppColors.borderDark : AppColors.borderLight;

    // Calculate mock rating
    final ratingHash = proposal.vendorId.hashCode.abs() % 10;
    final rating = 4.0 + (ratingHash / 10);

    // Mock data
    final completedOrders = (proposal.vendorId.hashCode.abs() % 500) + 50;
    return SingleChildScrollView(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                CircleAvatar(
                  radius: 32,
                  backgroundColor:
                      AppColors.customerColor.withValues(alpha: 0.12),
                  child: const Icon(
                    Icons.storefront_rounded,
                    color: AppColors.customerColor,
                    size: 32,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Verified Partner',
                        style: AppTextStyles.h2(primaryText),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      Row(
                        children: [
                          Icon(
                            Icons.star_rounded,
                            size: 16,
                            color: Colors.amber.shade700,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            rating.toStringAsFixed(1),
                            style: AppTextStyles.bodySmall(secondaryText),
                          ),
                          Text(
                            ' · $completedOrders orders',
                            style: AppTextStyles.caption(secondaryText),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),

            // Divider
            Divider(color: borderColor, height: 1),
            const SizedBox(height: 20),

            // Partner info is intentionally anonymous until the platform's
            // privacy policy allows disclosure.
            Text(
              'Partner Information',
              style: AppTextStyles.subtitle(primaryText),
            ),
            const SizedBox(height: 12),

            // Verified Badge
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: AppColors.success.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: AppColors.success.withValues(alpha: 0.3),
                ),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.verified_rounded,
                    size: 16,
                    color: AppColors.success,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'Verified Partner Shop',
                    style: AppTextStyles.bodySmall(AppColors.success),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),

            // Service Area
            _InfoRow(
              icon: Icons.location_on_outlined,
              label: 'Delivery coverage',
              value: 'Available for your request',
              primaryText: primaryText,
              secondaryText: secondaryText,
            ),
            const SizedBox(height: 12),

            // Categories
            _InfoRow(
              icon: Icons.category_outlined,
              label: 'Order fulfillment',
              value: 'Available',
              primaryText: primaryText,
              secondaryText: secondaryText,
            ),
            const SizedBox(height: 12),

            // Completed Orders
            _InfoRow(
              icon: Icons.shopping_bag_outlined,
              label: 'Completed Orders',
              value: '$completedOrders',
              primaryText: primaryText,
              secondaryText: secondaryText,
            ),
            const SizedBox(height: 20),

            // Divider
            Divider(color: borderColor, height: 1),
            const SizedBox(height: 20),

          ],
        ),
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  const _InfoRow({
    required this.icon,
    required this.label,
    required this.value,
    required this.primaryText,
    required this.secondaryText,
  });

  final IconData icon;
  final String label;
  final String value;
  final Color primaryText;
  final Color secondaryText;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 20, color: AppColors.customerColor),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: AppTextStyles.caption(secondaryText),
              ),
              Text(
                value,
                style: AppTextStyles.bodySmall(primaryText),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

