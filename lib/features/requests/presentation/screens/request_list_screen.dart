import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_radius.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../core/widgets/theme3/theme3_app_card.dart';
import '../../../../core/widgets/theme3/theme3_category_chip.dart';
import '../../../../core/widgets/theme3/theme3_empty_state.dart';
import '../../../../core/widgets/theme3/theme3_status_chip.dart';
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

  /// Check if image path is a network URL
  bool _isNetworkImage(String path) {
    return path.startsWith('http://') || path.startsWith('https://');
  }

  /// Check if image path is an asset
  bool _isAssetImage(String path) {
    return path.startsWith('assets/');
  }

  /// Build image content with proper loader based on path type
  Widget _buildImageContent({
    required String imagePath,
    required double size,
    required Widget fallback,
  }) {
    if (_isNetworkImage(imagePath)) {
      return Image.network(
        imagePath,
        width: size,
        height: size,
        fit: BoxFit.cover,
        errorBuilder: (context, error, stackTrace) => fallback,
        loadingBuilder: (context, child, loadingProgress) {
          if (loadingProgress == null) return child;
          return fallback;
        },
      );
    }

    if (_isAssetImage(imagePath)) {
      return Image.asset(
        imagePath,
        width: size,
        height: size,
        fit: BoxFit.cover,
        errorBuilder: (context, error, stackTrace) => fallback,
      );
    }

    // Local file path
    return Image.file(
      File(imagePath),
      width: size,
      height: size,
      fit: BoxFit.cover,
      errorBuilder: (context, error, stackTrace) => fallback,
    );
  }

  /// Extract first available customer image from request
  String? _getRequestThumbnailImage(ShoppingRequest request) {
    if (request.items.isNotEmpty) {
      for (final item in request.items) {
        if (item.imageUrls.isNotEmpty) {
          final firstImage = item.imageUrls.first.trim();
          if (firstImage.isNotEmpty) {
            return firstImage;
          }
        }
      }
    }
    return null;
  }

  /// Build smart thumbnail that shows image if available, otherwise category icon
  Widget _buildSmartRequestThumbnail({
    required String? imagePath,
    required String category,
    required double size,
    required bool isDark,
  }) {
    final categoryIcon = _getCategoryIcon(category);
    final categoryColor = _getCategoryColor(category);
    
    // Build category icon fallback widget
    final iconFallback = Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: categoryColor.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(AppRadius.md),
        border: Border.all(
          color: categoryColor.withValues(alpha: 0.35),
          width: 1,
        ),
      ),
      child: Icon(
        categoryIcon,
        color: categoryColor,
        size: size * 0.47,
      ),
    );
    
    // If image exists, show image thumbnail
    if (imagePath != null && imagePath.trim().isNotEmpty) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(AppRadius.md),
        child: Container(
          width: size,
          height: size,
          decoration: BoxDecoration(
            color: categoryColor.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(AppRadius.md),
          ),
          child: _buildImageContent(
            imagePath: imagePath.trim(),
            size: size,
            fallback: iconFallback,
          ),
        ),
      );
    }
    
    // No image, show category icon thumbnail
    return iconFallback;
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
                      padding: EdgeInsets.all(AppSpacing.md),
                      itemCount: filteredRequests.length,
                      itemBuilder: (context, index) {
                        final request = filteredRequests[index];
                        return _buildRequestCard(context, request, isDark, primaryText, secondaryText);
                      },
                    ),
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
              IconButton(
                onPressed: () {},
                icon: Icon(
                  Icons.search_rounded,
                  color: secondaryText,
                ),
                style: IconButton.styleFrom(
                  backgroundColor: isDark ? AppColors.surfaceElevatedDark : AppColors.surfaceLight,
                ),
              ),
              SizedBox(width: AppSpacing.xs),
              IconButton(
                onPressed: () {},
                icon: Icon(
                  Icons.tune_rounded,
                  color: secondaryText,
                ),
                style: IconButton.styleFrom(
                  backgroundColor: isDark ? AppColors.surfaceElevatedDark : AppColors.surfaceLight,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildFilterChips(bool isDark) {
    return Container(
      height: 56,
      padding: EdgeInsets.symmetric(vertical: AppSpacing.xs),
      decoration: BoxDecoration(
        color: isDark ? AppColors.surfaceDark : AppColors.surfaceLight,
        border: Border(
          bottom: BorderSide(
            color: isDark ? AppColors.borderDark : AppColors.borderLight,
            width: 1,
          ),
        ),
      ),
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: EdgeInsets.symmetric(horizontal: AppSpacing.md),
        children: [
          _buildFilterChip('All', RequestFilterType.all, isDark),
          SizedBox(width: AppSpacing.xs),
          _buildFilterChip('Submitted', RequestFilterType.submitted, isDark),
          SizedBox(width: AppSpacing.xs),
          _buildFilterChip('Proposal Received', RequestFilterType.proposalReceived, isDark),
          SizedBox(width: AppSpacing.xs),
          _buildFilterChip('Accepted', RequestFilterType.accepted, isDark),
          SizedBox(width: AppSpacing.xs),
          _buildFilterChip('Cancelled', RequestFilterType.cancelled, isDark),
        ],
      ),
    );
  }

  Widget _buildFilterChip(String label, RequestFilterType type, bool isDark) {
    final isSelected = _selectedFilter == type;
    return Theme3CategoryChip(
      label: label,
      isSelected: isSelected,
      onTap: () {
        setState(() {
          _selectedFilter = type;
        });
      },
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
    final requestImagePath = _getRequestThumbnailImage(request);
    final proposalCount = request.proposalCount;
    final firstItemName = request.items.isNotEmpty ? request.items.first.name : 'Request';
    
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
            _buildSmartRequestThumbnail(
              imagePath: requestImagePath,
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
                  Text(
                    firstItemName,
                    style: AppTextStyles.labelLarge(primaryText),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
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
      case RequestStatus.vendorAccepted:
        return 'Vendor Accepted';
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
