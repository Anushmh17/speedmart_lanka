import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../auth/providers/auth_provider.dart';
import '../../../proposals/data/mock_proposal_repository.dart';
import '../../../requests/data/mock_request_repository.dart';
import '../../../../shared/models/vendor_status.dart';
import '../models/vendor_feed_enums.dart';
import '../models/vendor_feed_request.dart';
import '../services/vendor_request_filter_service.dart';
import '../../../admin/providers/category_provider.dart';

class VendorRequestFeedState {
  const VendorRequestFeedState({
    this.isLoading = false,
    this.error,
    this.items = const [],
    this.sortMode = VendorFeedSortMode.newest,
    this.categoryFilter,
    this.categoryChips = const [],
    this.vendorApproved = false,
    this.pendingApprovalMessage,
  });

  final bool isLoading;
  final String? error;
  final List<VendorFeedRequest> items;
  final VendorFeedSortMode sortMode;
  final String? categoryFilter;
  final List<String> categoryChips;
  final bool vendorApproved;
  final String? pendingApprovalMessage;

  VendorRequestFeedState copyWith({
    bool? isLoading,
    String? error,
    List<VendorFeedRequest>? items,
    VendorFeedSortMode? sortMode,
    String? categoryFilter,
    List<String>? categoryChips,
    bool? vendorApproved,
    String? pendingApprovalMessage,
    bool clearError = false,
    bool clearCategoryFilter = false,
  }) {
    return VendorRequestFeedState(
      isLoading: isLoading ?? this.isLoading,
      error: clearError ? null : (error ?? this.error),
      items: items ?? this.items,
      sortMode: sortMode ?? this.sortMode,
      categoryFilter:
          clearCategoryFilter ? null : (categoryFilter ?? this.categoryFilter),
      categoryChips: categoryChips ?? this.categoryChips,
      vendorApproved: vendorApproved ?? this.vendorApproved,
      pendingApprovalMessage:
          pendingApprovalMessage ?? this.pendingApprovalMessage,
    );
  }
}

final vendorRequestFilterServiceProvider =
    Provider<VendorRequestFilterService>((ref) {
  return const VendorRequestFilterService();
});

final vendorRequestFeedProvider =
    StateNotifierProvider<VendorRequestFeedNotifier, VendorRequestFeedState>(
  (ref) => VendorRequestFeedNotifier(ref),
);

class VendorRequestFeedNotifier extends StateNotifier<VendorRequestFeedState> {
  VendorRequestFeedNotifier(this.ref) : super(const VendorRequestFeedState());

  final Ref ref;

  /// True after the first successful feed load — prevents resetting the user's
  /// chosen sort mode when they pull-to-refresh.
  bool _hasLoaded = false;

  Future<void> loadFeed() async {
    final user = ref.read(currentUserProvider);
    final filterService = ref.read(vendorRequestFilterServiceProvider);

    if (user == null) {
      debugPrint('[FeedAudit] No authenticated user, returning empty feed');
      state = state.copyWith(
        isLoading: false,
        items: [],
        vendorApproved: false,
      );
      return;
    }

    debugPrint('[FeedAudit] ===== VENDOR FEED LOAD START =====');
    debugPrint('[FeedAudit] vendor.id: ${user.id}');
    debugPrint('[FeedAudit] vendor.vendorStatus: ${user.vendorStatus}');
    debugPrint('[FeedAudit] vendor.vendorApproved: ${user.vendorApproved}');

    // *** SOURCE OF TRUTH: allowedCategories (admin-approved) ***
    final rawCategories = user.allowedCategories ?? user.vendorCategories ?? [];
    debugPrint('[CategoryAudit] ===== CATEGORY AUDIT (BEFORE SANITIZATION) =====');
    debugPrint('[CategoryAudit] vendor.allowedCategories (raw from DB): ${user.allowedCategories}');
    debugPrint('[CategoryAudit] vendor.vendorCategories (raw from DB): ${user.vendorCategories}');
    debugPrint('[CategoryAudit] rawCategories BEFORE sanitization: $rawCategories');
    
    // FORCE load categories before validation
    final categoryNotifier = ref.read(categoryProvider.notifier);
    await categoryNotifier.loadCategories();
    final allCategories = categoryNotifier.getAllCategories();
    final validKeys = allCategories.map((c) => c.normalizedKey).toSet();
    
    debugPrint('[CategoryAudit] Valid keys loaded from repository: $validKeys');
    
    // Sanitize: normalize, deduplicate, and filter to only valid repository keys
    final sanitizedCategories = rawCategories
        .map((k) => k.toLowerCase().trim())
        .where((k) => k.isNotEmpty && validKeys.contains(k))
        .toSet()
        .toList();
    
    debugPrint('[CategoryAudit] ===== CATEGORY AUDIT (AFTER SANITIZATION) =====');
    debugPrint('[CategoryAudit] sanitizedCategories AFTER filtering: $sanitizedCategories');
    debugPrint('[CategoryAudit] Removed invalid keys: ${rawCategories.toSet().difference(sanitizedCategories.toSet())}');
    debugPrint('[CategoryAudit] FINAL CATEGORIES USED IN FEED: $sanitizedCategories');

    final approved = user.vendorStatus == VendorStatus.approved;
    debugPrint('[FeedAudit] Vendor approval check: vendorStatus=${user.vendorStatus}, approved=$approved');

    state = state.copyWith(
      isLoading: true,
      // Only reset to newest on the very first load; preserve user's choice on refresh.
      sortMode: _hasLoaded ? null : VendorFeedSortMode.newest,
      clearError: true,
      vendorApproved: approved,
      categoryChips: filterService
          .availableCategoryFilters(sanitizedCategories)
          .toList()
        ..sort(),
      pendingApprovalMessage: approved
          ? null
          : 'Your vendor account is pending approval. You will see nearby requests once approved.',
    );
    _hasLoaded = true;

    if (!approved) {
      debugPrint('[FeedAudit] ===== REJECTION: Vendor not approved =====');
      state = state.copyWith(isLoading: false, items: []);
      return;
    }

    // Check if shop location is assigned by admin
    final shopLocationAssigned = user.isShopLocationAssigned == true;
    debugPrint('[FeedAudit] Shop location check: isShopLocationAssigned=$shopLocationAssigned');
    if (!shopLocationAssigned) {
      debugPrint('[FeedAudit] ===== REJECTION: Shop location not assigned =====');
      state = state.copyWith(isLoading: false, items: []);
      return;
    }

    // Use admin-assigned shop location (not user-editable)
    final vendorLat = user.shopLatitude ?? 0.0;
    final vendorLon = user.shopLongitude ?? 0.0;
    final assignedRadius = user.assignedRadiusKm;

    debugPrint('[FeedAudit] vendor.id: ${user.id}');
    debugPrint('[VendorLocationAudit] Loaded vendor coordinates: lat=$vendorLat, lng=$vendorLon');
    debugPrint('[FeedAudit] vendor.shopLatitude: $vendorLat');
    debugPrint('[FeedAudit] vendor.shopLongitude: $vendorLon');
    debugPrint('[FeedAudit] vendor.assignedRadiusKm: $assignedRadius');
    debugPrint('[CategoryAudit] SOURCE OF TRUTH for feed: $sanitizedCategories');

    try {
      await MockRequestRepository.instance.ensureInitialized();
      await MockProposalRepository.instance.ensureInitialized();

      final requests =
          await MockRequestRepository.instance.getMarketplaceActiveRequests();
      final proposals =
          await MockProposalRepository.instance.getAllProposals();

      debugPrint('[RequestAudit] Total active requests: ${requests.length}');
      if (requests.isEmpty) {
        debugPrint('[FeedAudit] ===== REJECTION: No active requests found in repository =====');
      }
      for (final req in requests) {
        debugPrint('[RequestAudit] request.id: ${req.id}, area: ${req.customerArea}, lat: ${req.latitude}, lng: ${req.longitude}');
        debugPrint('[RequestAudit] request.items: ${req.items.map((i) => i.itemName).join(", ")}');
      }

      final built = filterService.buildFeed(
        allRequests: requests,
        allProposals: proposals,
        vendorCategories: sanitizedCategories,
        vendorLatitude: vendorLat,
        vendorLongitude: vendorLon,
        vendorStatus: user.vendorStatus,
        categoryFilter: state.categoryFilter,
        assignedRadiusKm: assignedRadius,
        vendorId: user.id,
      );

      debugPrint('[FeedAudit] Requests visible to vendor after filtering: ${built.length}');
      if (built.isEmpty && requests.isNotEmpty) {
        debugPrint('[FeedAudit] ===== WARNING: All requests filtered out by distance/category =====');
      }
      for (final item in built) {
        debugPrint('[DistanceAudit] request: ${item.request.id}, distance: ${item.distanceKm}km, radius: $assignedRadius, visible: true');
      }

      final sorted = filterService.applySort(built, state.sortMode);

      state = state.copyWith(isLoading: false, items: sorted);
      debugPrint('[FeedAudit] ===== VENDOR FEED LOAD COMPLETE: ${sorted.length} requests shown =====');
    } catch (e) {
      debugPrint('[FeedAudit] ===== ERROR: Exception during feed load: $e =====');
      state = state.copyWith(isLoading: false, error: e.toString());
    }
  }

  Future<void> refresh() => loadFeed();

  void setSortMode(VendorFeedSortMode mode) {
    if (mode == state.sortMode) return;
    final filterService = ref.read(vendorRequestFilterServiceProvider);
    state = state.copyWith(
      sortMode: mode,
      items: filterService.applySort(state.items, mode),
    );
  }

  Future<void> setCategoryFilter(String? category) async {
    state = state.copyWith(
      categoryFilter: category,
      clearCategoryFilter: category == null,
    );
    await loadFeed();
  }
}
