import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_radius.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../core/widgets/theme3/theme3_empty_state.dart';
import '../../../../shared/utils/category_constants.dart';
import '../../../auth/providers/auth_provider.dart';
import '../models/vendor_feed_enums.dart';
import '../providers/vendor_request_feed_provider.dart';
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
            // Filter bar — category pills + sort pills combined
            if (feedState.vendorApproved) ...[
              const SizedBox(height: AppSpacing.sm),
              _buildFilterBar(context, feedState, isDark, primaryText, secondaryText),
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
  // ── Premium pill-tab filter bar ─────────────────────────────────────────────
  Widget _buildFilterBar(
    BuildContext context,
    VendorRequestFeedState feedState,
    bool isDark,
    Color primaryText,
    Color secondaryText,
  ) {
    final trackColor = isDark ? AppColors.surfaceElevatedDark : const Color(0xFFF3F4F6);
    final surfaceBg = isDark ? AppColors.surfaceDark : AppColors.surfaceLight;
    final borderCol = isDark ? AppColors.borderDark : AppColors.borderLight;

    // Sort pills metadata
    const sortMeta = [
      (mode: VendorFeedSortMode.newest,       label: 'Newest',          icon: Icons.schedule_rounded,         color: Color(0xFF6366F1)),
      (mode: VendorFeedSortMode.nearest,      label: 'Nearest',         icon: Icons.near_me_rounded,          color: Color(0xFF0EA5E9)),
      (mode: VendorFeedSortMode.lowCompetition, label: 'Low Competition', icon: Icons.emoji_events_rounded,    color: Color(0xFF22C55E)),
    ];

    return Container(
      decoration: BoxDecoration(
        color: surfaceBg,
        border: Border(
          bottom: BorderSide(color: borderCol, width: 1),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Sort row ─────────────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.fromLTRB(AppSpacing.lg, AppSpacing.sm, AppSpacing.lg, 0),
            child: Container(
              height: 52,
              decoration: BoxDecoration(
                color: trackColor,
                borderRadius: BorderRadius.circular(26),
              ),
              child: ListView(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 5),
                children: sortMeta.map((meta) {
                  final isSelected = feedState.sortMode == meta.mode;
                  final unselectedText = isDark
                      ? AppColors.textSecondaryDark
                      : AppColors.textSecondaryLight;
                  return GestureDetector(
                    onTap: () => ref
                        .read(vendorRequestFeedProvider.notifier)
                        .setSortMode(meta.mode),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 220),
                      curve: Curves.easeOutCubic,
                      margin: const EdgeInsets.symmetric(vertical: 5, horizontal: 3),
                      padding: const EdgeInsets.symmetric(horizontal: 18),
                      decoration: BoxDecoration(
                        gradient: isSelected
                            ? LinearGradient(
                                colors: [meta.color, meta.color.withValues(alpha: 0.78)],
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                              )
                            : null,
                        color: isSelected ? null : Colors.transparent,
                        borderRadius: BorderRadius.circular(21),
                        boxShadow: isSelected
                            ? [
                                BoxShadow(
                                  color: meta.color.withValues(alpha: 0.35),
                                  blurRadius: 8,
                                  offset: const Offset(0, 2),
                                )
                              ]
                            : null,
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            meta.icon,
                            size: 18,
                            color: isSelected
                                ? Colors.white
                                : meta.color.withValues(alpha: 0.85),
                          ),
                          const SizedBox(width: 6),
                          AnimatedDefaultTextStyle(
                            duration: const Duration(milliseconds: 180),
                            style: AppTextStyles.labelMedium(
                              isSelected ? Colors.white : unselectedText,
                            ).copyWith(
                              fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                            ),
                            child: Text(meta.label),
                          ),
                        ],
                      ),
                    ),
                  );
                }).toList(),
              ),
            ),
          ),
          // ── Category chips ────────────────────────────────────────────
          if (feedState.categoryChips.isNotEmpty) ...[  
            const SizedBox(height: AppSpacing.sm),
            SizedBox(
              height: 38,
              child: ListView(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
                children: [
                  _buildCategoryChip('All', feedState.categoryFilter == null, isDark, primaryText, null),
                  ...feedState.categoryChips.map((cat) => Padding(
                    padding: const EdgeInsets.only(left: 8),
                    child: _buildCategoryChip(
                      cat,
                      feedState.categoryFilter != null &&
                          VendorCategories.normalize(feedState.categoryFilter!) ==
                              VendorCategories.normalize(cat),
                      isDark,
                      primaryText,
                      cat,
                    ),
                  )),
                ],
              ),
            ),
          ],
          const SizedBox(height: AppSpacing.sm),
        ],
      ),
    );
  }

  Widget _buildCategoryChip(String label, bool selected, bool isDark, Color primaryText, String? categoryValue) {
    const accent = AppColors.vendorColor;
    return GestureDetector(
      onTap: () => ref
          .read(vendorRequestFeedProvider.notifier)
          .setCategoryFilter(categoryValue),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeOutCubic,
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: selected
              ? accent.withValues(alpha: 0.15)
              : (isDark ? AppColors.cardDark : AppColors.cardLight),
          borderRadius: BorderRadius.circular(AppRadius.full),
          border: Border.all(
            color: selected ? accent : (isDark ? AppColors.borderDark : AppColors.borderLight),
            width: selected ? 1.5 : 1,
          ),
        ),
        child: Text(
          label,
          style: AppTextStyles.caption(
            selected ? accent : primaryText,
          ).copyWith(fontWeight: FontWeight.w600),
        ),
      ),
    );
  }
}

