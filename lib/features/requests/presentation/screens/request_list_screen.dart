import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_radius.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../core/widgets/theme3/theme3_app_card.dart';
import '../../../../core/widgets/theme3/theme3_empty_state.dart';
import '../../../../core/widgets/theme3/theme3_status_chip.dart';
import '../../../../core/widgets/theme3/request_image_carousel.dart';
import '../../../../shared/utils/category_constants.dart';
import '../../models/shopping_request.dart';
import '../../providers/request_provider.dart';
import 'request_details_screen.dart';

enum RequestFilterType {
  all,
  submitted,
  proposalReceived,
  accepted,
  cancelled,
}

class RequestListScreen extends ConsumerStatefulWidget {
  const RequestListScreen({super.key});

  @override
  ConsumerState<RequestListScreen> createState() => _RequestListScreenState();
}

class _RequestListScreenState extends ConsumerState<RequestListScreen> {
  RequestFilterType _selectedFilter = RequestFilterType.all;

  /// Collect all non-empty images across all items in a request.
  List<String> _getRequestImages(ShoppingRequest request) {
    final images = <String>[];
    for (final item in request.items) {
      for (final url in item.imageUrls) {
        final t = url.trim();
        if (t.isNotEmpty) images.add(t);
      }
    }
    return images;
  }

  /// Build a carousel thumbnail for a request.
  Widget _buildRequestCarousel({
    required List<String> images,
    required String category,
    required double size,
    required bool isDark,
  }) {
    final categoryIcon = _getCategoryIcon(category);
    final categoryColor = _getCategoryColor(category);
    final iconFallback = Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: categoryColor.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(AppRadius.md),
        border: Border.all(color: categoryColor.withValues(alpha: 0.35), width: 1),
      ),
      child: Icon(categoryIcon, color: categoryColor, size: size * 0.47),
    );
    return RequestImageCarousel(images: images, fallback: iconFallback, size: size);
  }

  Color _getCategoryColor(String category) {
    if (category.isEmpty) return const Color(0xFFF59E0B);
    final normalized = VendorCategories.normalize(category);
    switch (normalized) {
      case 'groceries':
        return const Color(0xFF059669); // green
      case 'electronics':
        return const Color(0xFF0EA5E9); // blue
      case 'hardware':
        return const Color(0xFFF59E0B); // orange
      case 'furniture':
        return const Color(0xFF8B5CF6); // purple
      case 'pharmacy':
        return const Color(0xFFDC2626); // red
      case 'vehicle_parts':
        return const Color(0xFF6366F1); // indigo
      case 'home_appliances':
        return const Color(0xFFEC4899); // pink
      case 'books':
        return const Color(0xFF06B6D4); // cyan
      case 'clothing':
        return const Color(0xFFF43F5E); // rose
      case 'stationery':
        return const Color(0xFFFBBF24); // amber
      case 'other':
        return const Color(0xFF6B7280); // gray
      default:
        return const Color(0xFFF59E0B); // orange fallback
    }
  }

  IconData _getCategoryIcon(String category) {
    if (category.isEmpty) return Icons.shopping_bag_rounded;
    final normalized = VendorCategories.normalize(category);
    switch (normalized) {
      case 'groceries':
        return Icons.shopping_basket_rounded;
      case 'pharmacy':
        return Icons.local_pharmacy_rounded;
      case 'electronics':
        return Icons.devices_rounded;
      case 'stationery':
        return Icons.drive_file_rename_outline_rounded;
      case 'hardware':
        return Icons.build_rounded;
      case 'bakery':
        return Icons.cake_rounded;
      case 'meat_&_seafood':
        return Icons.set_meal_rounded;
      case 'clothing':
        return Icons.checkroom_rounded;
      default:
        return Icons.shopping_bag_rounded;
    }
  }

  static const _orderStatuses = {
    RequestStatus.paid,
    RequestStatus.cashOnDeliveryConfirmed,
    RequestStatus.preparingOrder,
    RequestStatus.readyForDelivery,
    RequestStatus.outForDelivery,
    RequestStatus.delivered,
  };

  List<ShoppingRequest> _filterRequests(List<ShoppingRequest> requests) {
    switch (_selectedFilter) {
      case RequestFilterType.all:
        return requests.where((r) => !_orderStatuses.contains(r.status)).toList();
      case RequestFilterType.submitted:
        return requests.where((r) => 
          r.status == RequestStatus.submitted || 
          r.status == RequestStatus.waitingForVendor
        ).toList();
      case RequestFilterType.proposalReceived:
        return requests.where((r) => 
          r.status == RequestStatus.proposalSubmitted
        ).toList();
      case RequestFilterType.accepted:
        return requests.where((r) => 
          r.status == RequestStatus.customerAccepted || 
          r.status == RequestStatus.accepted
        ).toList();
      case RequestFilterType.cancelled:
        return requests.where((r) => 
          r.status == RequestStatus.cancelled || 
          r.status == RequestStatus.customerRejected
        ).toList();
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primaryText = isDark ? AppColors.textPrimaryDark : AppColors.textPrimaryLight;
    final secondaryText = isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight;
    final requestState = ref.watch(requestProvider);

    if (requestState.isLoading && requestState.requests.isEmpty) {
      return Scaffold(
        backgroundColor: isDark ? AppColors.backgroundDark : AppColors.backgroundLight,
        body: Column(
          children: [
            _buildHeader(isDark, primaryText, secondaryText),
            Expanded(
              child: ListView.builder(
                padding: EdgeInsets.all(AppSpacing.md),
                itemCount: 5,
                itemBuilder: (context, index) => Padding(
                  padding: EdgeInsets.only(bottom: AppSpacing.md),
                  child: Container(
                    height: 180,
                    decoration: BoxDecoration(
                      color: isDark ? AppColors.cardDark : AppColors.cardLight,
                      borderRadius: BorderRadius.circular(AppRadius.lg),
                    ),
                    child: const Center(
                      child: CircularProgressIndicator(),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      );
    }

    final filteredRequests = _filterRequests(requestState.requests);

    if (requestState.requests.isEmpty) {
      return Scaffold(
        backgroundColor: isDark ? AppColors.backgroundDark : AppColors.backgroundLight,
        body: Column(
          children: [
            _buildHeader(isDark, primaryText, secondaryText),
            Expanded(
              child: Theme3EmptyState(
                icon: Icons.receipt_long_outlined,
                title: 'No Requests Yet',
                subtitle: 'Create your first shopping request and get proposals from vendors',
                actionLabel: 'Create New Request',
                onActionPressed: () {
                  Navigator.of(context).pop();
                },
              ),
            ),
          ],
        ),
      );
    }

    final groupedRequests = _groupRequestsByTime(filteredRequests);
    // Build a flat list: each entry is either a String (section header) or a ShoppingRequest.
    final List<dynamic> listItems = [];
    for (final entry in groupedRequests.entries) {
      if (entry.value.isNotEmpty) {
        listItems.add(entry.key); // section header label
        listItems.addAll(entry.value);
      }
    }

    return Scaffold(
      backgroundColor: isDark ? AppColors.backgroundDark : AppColors.backgroundLight,
      body: Column(
        children: [
          _buildHeader(isDark, primaryText, secondaryText),
          _buildFilterChips(isDark),
          Expanded(
            child: filteredRequests.isEmpty
                ? Theme3EmptyState(
                    icon: Icons.filter_list_off_rounded,
                    title: 'No ${_selectedFilter.name} Requests',
                    subtitle: 'Try selecting a different filter',
                  )
                : RefreshIndicator(
                    onRefresh: () => ref.read(requestProvider.notifier).loadMyRequests(),
                    child: ListView.builder(
                      padding: EdgeInsets.fromLTRB(
                        AppSpacing.md,
                        AppSpacing.sm,
                        AppSpacing.md,
                        AppSpacing.md,
                      ),
                      itemCount: listItems.length,
                      itemBuilder: (context, index) {
                        final item = listItems[index];
                        if (item is String) {
                          return _buildSectionHeader(item, isDark, secondaryText);
                        }
                        return _buildRequestCard(
                          context,
                          item as ShoppingRequest,
                          isDark,
                          primaryText,
                          secondaryText,
                        );
                      },
                    ),
                  ),
          ),
        ],
      ),
    );
  }

  /// Groups requests into time buckets: Today, This Week, Last Week, Last Month, Older.
  /// Preserves insertion order for consistent display.
  Map<String, List<ShoppingRequest>> _groupRequestsByTime(List<ShoppingRequest> requests) {
    final now = DateTime.now();
    final todayStart = DateTime(now.year, now.month, now.day);
    final weekStart = todayStart.subtract(Duration(days: now.weekday - 1)); // Monday
    final lastWeekStart = weekStart.subtract(const Duration(days: 7));
    final lastWeekEnd = weekStart;
    final monthStart = DateTime(now.year, now.month, 1);

    // Use a LinkedHashMap to preserve insertion order
    final groups = <String, List<ShoppingRequest>>{
      'Today': [],
      'This Week': [],
      'Last Week': [],
      'Last Month': [],
      'Older': [],
    };

    for (final request in requests) {
      final created = request.createdAt;
      if (!created.isBefore(todayStart)) {
        groups['Today']!.add(request);
      } else if (!created.isBefore(weekStart)) {
        groups['This Week']!.add(request);
      } else if (!created.isBefore(lastWeekStart) && created.isBefore(lastWeekEnd)) {
        groups['Last Week']!.add(request);
      } else if (!created.isBefore(monthStart)) {
        groups['Last Month']!.add(request);
      } else {
        groups['Older']!.add(request);
      }
    }

    return groups;
  }

  Widget _buildSectionHeader(String label, bool isDark, Color secondaryText) {
    return Padding(
      padding: EdgeInsets.only(top: AppSpacing.md, bottom: AppSpacing.sm),
      child: Row(
        children: [
          Text(
            label,
            style: AppTextStyles.labelMedium(secondaryText).copyWith(
              fontWeight: FontWeight.w700,
              letterSpacing: 0.5,
            ),
          ),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Container(
              height: 1,
              color: isDark
                  ? AppColors.borderDark.withValues(alpha: 0.5)
                  : AppColors.borderLight.withValues(alpha: 0.7),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader(bool isDark, Color primaryText, Color secondaryText) {
    return Container(
      padding: EdgeInsets.fromLTRB(
        AppSpacing.md,
        MediaQuery.of(context).padding.top + AppSpacing.sm,
        AppSpacing.md,
        AppSpacing.md,
      ),
      decoration: BoxDecoration(
        color: isDark ? AppColors.surfaceDark : AppColors.surfaceLight,
        border: Border(
          bottom: BorderSide(
            color: isDark ? AppColors.borderDark : AppColors.borderLight,
            width: 1,
          ),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'My Requests',
                      style: AppTextStyles.h2(primaryText),
                    ),
                    SizedBox(height: AppSpacing.xs),
                    Text(
                      'Track vendor responses and proposals',
                      style: AppTextStyles.bodySmall(secondaryText),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ── Filter metadata ────────────────────────────────────────────────────────
  static const _filterMeta = [
    (type: RequestFilterType.all,              label: 'All',       icon: Icons.apps_rounded,            color: Color(0xFF6366F1)),
    (type: RequestFilterType.submitted,        label: 'Waiting',   icon: Icons.hourglass_top_rounded,   color: Color(0xFFF59E0B)),
    (type: RequestFilterType.proposalReceived, label: 'Proposals', icon: Icons.local_offer_rounded,     color: Color(0xFF0EA5E9)),
    (type: RequestFilterType.accepted,         label: 'Accepted',  icon: Icons.check_circle_rounded,    color: Color(0xFF22C55E)),
    (type: RequestFilterType.cancelled,        label: 'Cancelled', icon: Icons.cancel_rounded,          color: Color(0xFFEF4444)),
  ];

  Widget _buildFilterChips(bool isDark) {
    final surfaceBg  = isDark ? AppColors.surfaceDark  : AppColors.surfaceLight;
    final borderCol  = isDark ? AppColors.borderDark   : AppColors.borderLight;
    final trackColor = isDark ? AppColors.surfaceElevatedDark : const Color(0xFFF3F4F6);

    return Container(
      decoration: BoxDecoration(
        color: surfaceBg,
        border: Border(
          bottom: BorderSide(color: borderCol, width: 1),
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 12, 12, 12),
        child: Container(
          height: 52,
          decoration: BoxDecoration(
            color: trackColor,
            borderRadius: BorderRadius.circular(26),
          ),
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            physics: const BouncingScrollPhysics(),
            padding: const EdgeInsets.symmetric(horizontal: 5),
            itemCount: _filterMeta.length,
            itemBuilder: (context, index) {
              final meta = _filterMeta[index];
              return _buildFilterTab(
                label: meta.label,
                icon: meta.icon,
                accentColor: meta.color,
                type: meta.type,
                isDark: isDark,
              );
            },
          ),
        ),
      ),
    );
  }

  Widget _buildFilterTab({
    required String label,
    required IconData icon,
    required Color accentColor,
    required RequestFilterType type,
    required bool isDark,
  }) {
    final isSelected = _selectedFilter == type;
    final unselectedText = isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight;

    return GestureDetector(
      onTap: () => setState(() => _selectedFilter = type),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 220),
        curve: Curves.easeOutCubic,
        margin: const EdgeInsets.symmetric(vertical: 5, horizontal: 3),
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 0),
        decoration: BoxDecoration(
          gradient: isSelected
              ? LinearGradient(
                  colors: [accentColor, accentColor.withValues(alpha: 0.78)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                )
              : null,
          color: isSelected ? null : Colors.transparent,
          borderRadius: BorderRadius.circular(21),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: accentColor.withValues(alpha: 0.35),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ]
              : null,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            AnimatedSwitcher(
              duration: const Duration(milliseconds: 180),
              child: Icon(
                icon,
                key: ValueKey('$type-$isSelected'),
                size: 18,
                color: isSelected ? Colors.white : accentColor.withValues(alpha: 0.85),
              ),
            ),
            const SizedBox(width: 6),
            AnimatedDefaultTextStyle(
              duration: const Duration(milliseconds: 180),
              style: AppTextStyles.labelMedium(
                isSelected ? Colors.white : unselectedText,
              ).copyWith(
                fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                letterSpacing: isSelected ? 0.2 : 0,
              ),
              child: Text(label),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCategoryChips(List<String> categories, Color secondaryText) {
    const maxVisible = 2;
    final visible = categories.take(maxVisible).toList();
    final overflow = categories.length - maxVisible;
    return Wrap(
      spacing: 4,
      runSpacing: 4,
      children: [
        ...visible.map((cat) => _categoryChip(
          VendorCategories.display(cat).toUpperCase(),
          _getCategoryColor(cat),
        )),
        if (overflow > 0) _categoryChip('+$overflow more', secondaryText),
      ],
    );
  }

  Widget _categoryChip(String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xs, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(AppRadius.xs),
      ),
      child: Text(label, style: AppTextStyles.caption(color).copyWith(fontSize: 9)),
    );
  }

  Widget _buildRequestCard(
    BuildContext context,
    ShoppingRequest request,
    bool isDark,
    Color primaryText,
    Color secondaryText,
  ) {
    final categories = request.categories;
    final primaryCategory = categories.isNotEmpty ? categories.first : '';
    final requestImages = _getRequestImages(request);
    final proposalCount = request.proposalCount;
    final firstItemName = request.isMultiCategory
        ? 'Multiple Category Order'
        : (request.items.isNotEmpty ? request.items.first.name : 'Request');
    
    final statusType = switch (request.status) {
      RequestStatus.submitted || RequestStatus.waitingForVendor => Theme3StatusType.pending,
      RequestStatus.proposalSubmitted => Theme3StatusType.inProgress,
      RequestStatus.customerAccepted || RequestStatus.accepted => Theme3StatusType.completed,
      RequestStatus.cancelled || RequestStatus.customerRejected || RequestStatus.expired => Theme3StatusType.cancelled,
      _ => Theme3StatusType.inProgress,
    };

    return Padding(
      padding: EdgeInsets.only(bottom: AppSpacing.md),
      child: Theme3AppCard(
        onTap: () {
          Navigator.of(context, rootNavigator: true).push(
            MaterialPageRoute(
              builder: (context) => RequestDetailsScreen(request: request),
            ),
          );
        },
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Row(
          children: [
            // LEFT: Smart Thumbnail (64x64)
            _buildRequestCarousel(
              images: requestImages,
              category: primaryCategory,
              size: 64,
              isDark: isDark,
            ),
            const SizedBox(width: AppSpacing.md),
            // CENTER: Details
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          firstItemName,
                          style: AppTextStyles.labelLarge(primaryText).copyWith(
                            fontWeight: request.isMultiCategory ? FontWeight.bold : FontWeight.w600,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      if (request.isMultiCategory) ...[
                        const SizedBox(width: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            gradient: const LinearGradient(
                              colors: [Color(0xFF7C3AED), Color(0xFF9D4EDD)],
                            ),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: const Text(
                            'Mixed',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 9,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 4),
                  if (categories.isNotEmpty)
                    _buildCategoryChips(categories, secondaryText),
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      Icon(Icons.shopping_cart_outlined, size: 12, color: secondaryText),
                      const SizedBox(width: 4),
                      Text(
                        '${request.items.length} items',
                        style: AppTextStyles.caption(secondaryText),
                      ),
                      const SizedBox(width: AppSpacing.sm),
                      Icon(Icons.receipt_long_outlined, size: 12, color: secondaryText),
                      const SizedBox(width: 4),
                      Text(
                        '$proposalCount ${proposalCount == 1 ? 'proposal' : 'proposals'}',
                        style: AppTextStyles.caption(secondaryText),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    _formatDate(request.createdAt),
                    style: AppTextStyles.caption(secondaryText),
                  ),
                ],
              ),
            ),
            // RIGHT: Status Chip & Arrow
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Theme3StatusChip(
                  label: _formatRequestStatus(request.status),
                  status: statusType,
                ),
                const SizedBox(height: 8),
                Icon(
                  Icons.chevron_right_rounded,
                  color: secondaryText,
                  size: 20,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  String _formatRequestStatus(RequestStatus status) {
    switch (status) {
      case RequestStatus.submitted:
      case RequestStatus.waitingForVendor:
        return 'Awaiting Proposals';
      case RequestStatus.proposalSubmitted:
        return 'Proposal Received';
      case RequestStatus.customerAccepted:
      case RequestStatus.accepted:
        return 'Accepted';
      case RequestStatus.paymentPending:
        return 'Payment Pending';
      case RequestStatus.customerRejected:
        return 'Rejected';
      case RequestStatus.cancelled:
        return 'Cancelled';
      case RequestStatus.expired:
        return 'Expired';
      default:
        return status.displayName;
    }
  }

  String _formatDate(DateTime date) {
    final now = DateTime.now();
    final difference = now.difference(date);

    if (difference.inMinutes < 60) {
      return '${difference.inMinutes}m ago';
    } else if (difference.inHours < 24) {
      return '${difference.inHours}h ago';
    } else if (difference.inDays < 7) {
      return '${difference.inDays}d ago';
    } else {
      return '${date.day}/${date.month}';
    }
  }
}

