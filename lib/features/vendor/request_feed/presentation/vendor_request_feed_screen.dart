import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_radius.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../core/widgets/theme3/theme3_app_card.dart';
import '../../../../core/widgets/theme3/theme3_empty_state.dart';
import '../../../auth/providers/auth_provider.dart';
import '../providers/vendor_request_feed_provider.dart';
import '../widgets/vendor_feed_filter_bar.dart';
import '../widgets/vendor_request_card.dart';

/// Vendor marketplace feed: nearby active requests matching categories & radius.
class VendorRequestFeedScreen extends ConsumerStatefulWidget {
  const VendorRequestFeedScreen({super.key, required this.isDark});

  final bool isDark;

  @override
  ConsumerState<VendorRequestFeedScreen> createState() =>
      _VendorRequestFeedScreenState();
}

class _VendorRequestFeedScreenState
    extends ConsumerState<VendorRequestFeedScreen> {
  bool _initialLoadScheduled = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_initialLoadScheduled) return;
      _initialLoadScheduled = true;
      Future.microtask(() {
        ref.read(vendorRequestFeedProvider.notifier).loadFeed();
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    final isDark = widget.isDark;
    final primaryText =
        isDark ? AppColors.textPrimaryDark : AppColors.textPrimaryLight;
    final secondaryText = isDark
        ? AppColors.textSecondaryDark
        : AppColors.textSecondaryLight;
    final user = ref.watch(currentUserProvider);
    final feedState = ref.watch(vendorRequestFeedProvider);

    // Show error if vendor is approved but has no shop location assigned
    if (user?.vendorApproved == true && user?.isShopLocationAssigned != true) {
      return Scaffold(
        backgroundColor: Colors.transparent,
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.storefront_outlined,
                    size: 64, color: Colors.orange.withValues(alpha: 0.6)),
                const SizedBox(height: 16),
                Text(
                  'Shop location not assigned',
                  textAlign: TextAlign.center,
                  style: AppTextStyles.h3(primaryText),
                ),
                const SizedBox(height: 8),
                Text(
                  'Your shop location and service radius are assigned by the administrator. '
                  'Please contact support to complete your store setup.',
                  textAlign: TextAlign.center,
                  style: AppTextStyles.bodyMedium(secondaryText),
                ),
              ],
            ),
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: RefreshIndicator(
        color: AppColors.vendorColor,
        onRefresh: () async {
          await ref.read(vendorRequestFeedProvider.notifier).refresh();
        },
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Premium Header
            Padding(
              padding: const EdgeInsets.fromLTRB(AppSpacing.lg, AppSpacing.lg, AppSpacing.lg, AppSpacing.xs),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Request Feed',
                          style: AppTextStyles.h2(primaryText),
                        ),
                        const SizedBox(height: AppSpacing.xs),
                        Text(
                          'Nearby customer requests',
                          style: AppTextStyles.caption(secondaryText),
                        ),
                      ],
                    ),
                  ),
                  if ((user?.assignedRadiusKm ?? 0) > 0)
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: AppSpacing.md,
                        vertical: AppSpacing.sm,
                      ),
                      decoration: BoxDecoration(
                        color: AppColors.vendorColor.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(AppRadius.full),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(
                            Icons.radar,
                            color: AppColors.vendorColor,
                            size: 16,
                          ),
                          const SizedBox(width: AppSpacing.xs),
                          Text(
                            '${user!.assignedRadiusKm!.toStringAsFixed(0)}km',
                            style: AppTextStyles.caption(AppColors.vendorColor)
                                .copyWith(fontWeight: FontWeight.bold),
                          ),
                        ],
                      ),
                    ),
                ],
              ),
            ),
            // Shop Location Card
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
              child: Theme3AppCard(
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(AppSpacing.sm),
                      decoration: BoxDecoration(
                        color: AppColors.vendorColor.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(AppRadius.md),
                      ),
                      child: const Icon(
                        Icons.storefront_rounded,
                        color: AppColors.vendorColor,
                        size: 20,
                      ),
                    ),
                    const SizedBox(width: AppSpacing.md),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            user?.shopName ?? 'Shop Location',
                            style: AppTextStyles.bodyMedium(primaryText)
                                .copyWith(fontWeight: FontWeight.w600),
                          ),
                          const SizedBox(height: AppSpacing.xs),
                          Text(
                            'Admin-assigned base',
                            style: AppTextStyles.caption(secondaryText),
                          ),
                        ],
                      ),
                    ),
                    Icon(
                      Icons.lock_rounded,
                      color: AppColors.vendorColor.withValues(alpha: 0.4),
                      size: 18,
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: AppSpacing.md),
            if (!feedState.vendorApproved &&
                feedState.pendingApprovalMessage != null)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(AppSpacing.md),
                  decoration: BoxDecoration(
                    color: AppColors.warning.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(AppRadius.md),
                    border: Border.all(
                      color: AppColors.warning.withValues(alpha: 0.4),
                    ),
                  ),
                  child: Row(
                    children: [
                      const Icon(
                        Icons.hourglass_top_rounded,
                        color: AppColors.warning,
                        size: 20,
                      ),
                      const SizedBox(width: AppSpacing.sm),
                      Expanded(
                        child: Text(
                          feedState.pendingApprovalMessage!,
                          style: AppTextStyles.bodySmall(AppColors.warning),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            if (!feedState.vendorApproved &&
                feedState.pendingApprovalMessage != null)
              const SizedBox(height: AppSpacing.md),
            if (feedState.vendorApproved) ...[
              VendorFeedFilterBar(
                isDark: isDark,
                categoryChips: feedState.categoryChips,
                selectedCategory: feedState.categoryFilter,
                sortMode: feedState.sortMode,
                onCategorySelected: (cat) {
                  ref
                      .read(vendorRequestFeedProvider.notifier)
                      .setCategoryFilter(cat);
                },
                onSortChanged: (mode) {
                  ref.read(vendorRequestFeedProvider.notifier).setSortMode(mode);
                },
              ),
              const SizedBox(height: AppSpacing.sm),
            ],
            Expanded(
              child: feedState.isLoading
                  ? const Center(
                      child: CircularProgressIndicator(
                        color: AppColors.vendorColor,
                      ),
                    )
                  : !feedState.vendorApproved
                      ? const Theme3EmptyState(
                          icon: Icons.verified_user_outlined,
                          title: 'Approval required',
                          subtitle:
                              'Complete vendor verification to access the marketplace feed.',
                        )
                      : feedState.items.isEmpty
                          ? const Theme3EmptyState(
                              icon: Icons.location_searching_rounded,
                              title: 'No nearby requests',
                              subtitle:
                                  'New customer requests in your approved categories will appear here.',
                            )
                          : ListView.builder(
                              padding: const EdgeInsets.fromLTRB(
                                AppSpacing.lg,
                                0,
                                AppSpacing.lg,
                                100,
                              ),
                              itemCount: feedState.items.length,
                              itemBuilder: (context, index) {
                                return VendorRequestCard(
                                  feedRequest: feedState.items[index],
                                  isDark: isDark,
                                  animationDelay:
                                      Duration(milliseconds: 40 * index),
                                );
                              },
                            ),
            ),
          ],
        ),
      ),
    );
  }
}
