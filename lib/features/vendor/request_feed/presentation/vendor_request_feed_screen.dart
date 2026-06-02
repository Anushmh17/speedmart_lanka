import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../core/widgets/app_state_widgets.dart';
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
                    size: 64, color: Colors.orange.withOpacity(0.6)),
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
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 4),
              child: Text(
                'Marketplace requests',
                style: AppTextStyles.h2(primaryText),
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Text(
                'Active requests in your categories · within your service radius',
                style: AppTextStyles.caption(secondaryText),
              ),
            ),
            // Read-only shop location display (no edit button)
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 8),
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                decoration: BoxDecoration(
                  color: isDark ? AppColors.cardDark : AppColors.cardLight,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: isDark ? AppColors.borderDark : AppColors.borderLight,
                  ),
                ),
                child: Row(
                  children: [
                    const Icon(
                      Icons.storefront_rounded,
                      color: AppColors.vendorColor,
                      size: 24,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'My shop base (admin-assigned)',
                            style: AppTextStyles.caption(secondaryText),
                          ),
                          Text(
                            user?.shopName ?? 'Shop Location',
                            style: AppTextStyles.bodyMedium(primaryText)
                                .copyWith(fontWeight: FontWeight.bold),
                          ),
                          if ((user?.assignedRadiusKm ?? 0) > 0) ...[
                            const SizedBox(height: 4),
                            Text(
                              'Service radius: ${(user!.assignedRadiusKm ?? 20).toStringAsFixed(0)}km',
                              style: AppTextStyles.caption(secondaryText),
                            ),
                          ],
                        ],
                      ),
                    ),
                    Icon(
                      Icons.lock_rounded,
                      color: AppColors.vendorColor.withOpacity(0.5),
                      size: 20,
                    ),
                  ],
                ),
              ),
            ),
            if (!feedState.vendorApproved &&
                feedState.pendingApprovalMessage != null)
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppColors.warning.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: AppColors.warning.withOpacity(0.4)),
                  ),
                  child: Row(
                    children: [
                      const Icon(
                        Icons.hourglass_top_rounded,
                        color: AppColors.warning,
                        size: 20,
                      ),
                      const SizedBox(width: 10),
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
              const SizedBox(height: 8),
            ],
            Expanded(
              child: feedState.isLoading
                  ? const Center(
                      child: CircularProgressIndicator(
                        color: AppColors.vendorColor,
                      ),
                    )
                  : !feedState.vendorApproved
                      ? const AppEmptyState(
                          icon: Icons.verified_user_outlined,
                          title: 'Approval required',
                          subtitle:
                              'Complete vendor verification to access the marketplace feed.',
                        )
                      : feedState.items.isEmpty
                          ? const AppEmptyState(
                              icon: Icons.location_searching_rounded,
                              title: 'No active requests nearby',
                              subtitle:
                                  'New customer requests in your radius and categories will appear here.',
                            )
                          : ListView.builder(
                              padding:
                                  const EdgeInsets.fromLTRB(16, 0, 16, 100),
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
