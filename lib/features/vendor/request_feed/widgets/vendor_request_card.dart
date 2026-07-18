import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_radius.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../core/widgets/theme3/request_image_carousel.dart';
import '../../../../core/widgets/theme3/theme3_status_chip.dart';
import '../models/vendor_feed_enums.dart';
import '../models/vendor_feed_request.dart';

class VendorRequestCard extends StatelessWidget {
  const VendorRequestCard({
    super.key,
    required this.feedRequest,
    required this.isDark,
    this.animationDelay = Duration.zero,
  });

  final VendorFeedRequest feedRequest;
  final bool isDark;
  final Duration animationDelay;

  List<String> _getImages() {
    final images = <String>[];
    for (final item in feedRequest.request.items) {
      for (final url in item.imageUrls) {
        final t = url.trim();
        if (t.isNotEmpty) images.add(t);
      }
    }
    return images;
  }

  Widget _buildCarousel(VendorFeedRequest feedRequest) {
    const size = 56.0;
    final images = _getImages();
    final fallback = Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: AppColors.vendorColor.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(AppRadius.md),
        border: Border.all(color: AppColors.vendorColor.withValues(alpha: 0.3)),
      ),
      child: const Icon(Icons.inventory_2_outlined, color: AppColors.vendorColor, size: 26),
    );
    return RequestImageCarousel(images: images, fallback: fallback, size: size);
  }

  Color _urgencyColor(RequestUrgency urgency) {
    switch (urgency) {
      case RequestUrgency.high:
        return AppColors.error;
      case RequestUrgency.medium:
        return AppColors.warning;
      case RequestUrgency.normal:
        return AppColors.vendorColor.withValues(alpha: 0.85);
    }
  }

  @override
  Widget build(BuildContext context) {
    final primaryText =
        isDark ? AppColors.textPrimaryDark : AppColors.textPrimaryLight;
    final secondaryText = isDark
        ? AppColors.textSecondaryDark
        : AppColors.textSecondaryLight;
    final cardColor = isDark ? AppColors.cardDark : AppColors.cardLight;
    final borderColor = isDark ? AppColors.borderDark : AppColors.borderLight;

    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: const Duration(milliseconds: 320),
      curve: Curves.easeOutCubic,
      builder: (context, value, child) {
        return Opacity(
          opacity: value,
          child: Transform.translate(
            offset: Offset(0, (1 - value) * 12),
            child: child,
          ),
        );
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: AppSpacing.md),
        decoration: BoxDecoration(
          color: cardColor,
          borderRadius: BorderRadius.circular(AppRadius.lg),
          border: Border.all(color: borderColor),
          boxShadow: [
            BoxShadow(
              color: AppColors.vendorColor.withValues(alpha: isDark ? 0.06 : 0.08),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            borderRadius: BorderRadius.circular(AppRadius.lg),
            onTap: () {
              context.push(
                '/vendor/requests/detail',
                extra: feedRequest.request,
              );
            },
            child: Padding(
              padding: const EdgeInsets.all(AppSpacing.lg),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Wrap(
                          spacing: AppSpacing.xs,
                          runSpacing: AppSpacing.xs,
                          children: [
                            ...feedRequest.allCategories.take(3).map((cat) =>
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: AppSpacing.sm,
                                  vertical: AppSpacing.xs,
                                ),
                                decoration: BoxDecoration(
                                  color: AppColors.vendorColor.withValues(alpha: 0.12),
                                  borderRadius: BorderRadius.circular(AppRadius.sm),
                                ),
                                child: Text(
                                  cat,
                                  style: AppTextStyles.caption(AppColors.vendorColor)
                                      .copyWith(fontWeight: FontWeight.w700),
                                ),
                              ),
                            ),
                            if (feedRequest.allCategories.length > 3)
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: AppSpacing.sm,
                                  vertical: AppSpacing.xs,
                                ),
                                decoration: BoxDecoration(
                                  color: AppColors.vendorColor.withValues(alpha: 0.08),
                                  borderRadius: BorderRadius.circular(AppRadius.sm),
                                ),
                                child: Text(
                                  '+${feedRequest.allCategories.length - 3} more',
                                  style: AppTextStyles.caption(AppColors.vendorColor)
                                      .copyWith(fontWeight: FontWeight.w600),
                                ),
                              ),
                          ],
                        ),
                      ),
                      const SizedBox(width: AppSpacing.sm),
                      Theme3StatusChip(
                        label: feedRequest.urgency.label,
                        status: Theme3StatusType.custom,
                        customColor: _urgencyColor(feedRequest.urgency),
                      ),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.md),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Carousel thumbnail
                      _buildCarousel(feedRequest),
                      const SizedBox(width: AppSpacing.md),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              feedRequest.approximateArea,
                              style: AppTextStyles.subtitle(primaryText),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            if (feedRequest.district.isNotEmpty) ...[
                              const SizedBox(height: AppSpacing.xs),
                              Row(
                                children: [
                                  Icon(
                                    Icons.map_outlined,
                                    size: 14,
                                    color: secondaryText,
                                  ),
                                  const SizedBox(width: AppSpacing.xs),
                                  Text(
                                    feedRequest.district,
                                    style: AppTextStyles.bodySmall(secondaryText),
                                  ),
                                ],
                              ),
                            ],
                          ],
                        ),
                      ),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text(
                            feedRequest.distanceKm > 0
                                ? '${feedRequest.distanceKm} km'
                                : 'Nearby',
                            style: AppTextStyles.subtitle(AppColors.vendorColor),
                          ),
                          Text(
                            'within ${feedRequest.maxRadiusKm.toStringAsFixed(0)} km',
                            style: AppTextStyles.caption(secondaryText),
                          ),
                        ],
                      ),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.md),
                  Wrap(
                    spacing: AppSpacing.sm,
                    runSpacing: AppSpacing.sm,
                    children: [
                      _MetaChip(
                        icon: Icons.inventory_2_outlined,
                        label: '${feedRequest.itemCount} items',
                        isDark: isDark,
                      ),
                      _MetaChip(
                        icon: Icons.schedule_rounded,
                        label: feedRequest.timePostedLabel,
                        isDark: isDark,
                      ),
                      _MetaChip(
                        icon: Icons.gavel_rounded,
                        label: '${feedRequest.proposalCount} bids',
                        isDark: isDark,
                      ),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.md),
                  const Divider(height: 1),
                  const SizedBox(height: AppSpacing.md),
                  Align(
                    alignment: Alignment.centerRight,
                    child: ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.vendorColor,
                        foregroundColor: Colors.white,
                        elevation: 0,
                        minimumSize: const Size(0, 36),
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        padding: const EdgeInsets.symmetric(
                          horizontal: AppSpacing.md,
                          vertical: AppSpacing.sm,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(AppRadius.md),
                        ),
                      ),
                      onPressed: () {
                        context.push(
                          '/vendor/requests/detail',
                          extra: feedRequest.request,
                        );
                      },
                      icon: const Icon(Icons.send_rounded, size: 16),
                      label: Text(
                        'Submit bid',
                        style: AppTextStyles.button(Colors.white)
                            .copyWith(fontSize: 13),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _MetaChip extends StatelessWidget {
  const _MetaChip({
    required this.icon,
    required this.label,
    required this.isDark,
  });

  final IconData icon;
  final String label;
  final bool isDark;

  @override
  Widget build(BuildContext context) {
    final bg = isDark ? Colors.white10 : AppColors.vendorColor.withValues(alpha: 0.06);
    final text = isDark
        ? AppColors.textSecondaryDark
        : AppColors.textSecondaryLight;

    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.sm,
        vertical: AppSpacing.xs,
      ),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(AppRadius.sm),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: AppColors.vendorColor),
          const SizedBox(width: AppSpacing.xs),
          Text(label, style: AppTextStyles.caption(text)),
        ],
      ),
    );
  }
}

