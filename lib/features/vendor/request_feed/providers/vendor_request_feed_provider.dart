import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../auth/providers/auth_provider.dart';
import '../../../proposals/data/mock_proposal_repository.dart';
import '../../../requests/data/mock_request_repository.dart';
import '../models/vendor_feed_enums.dart';
import '../models/vendor_feed_request.dart';
import '../services/vendor_request_filter_service.dart';

class VendorRequestFeedState {
  const VendorRequestFeedState({
    this.isLoading = false,
    this.error,
    this.items = const [],
    this.sortMode = VendorFeedSortMode.nearest,
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

  Future<void> loadFeed() async {
    final user = ref.read(currentUserProvider);
    final filterService = ref.read(vendorRequestFilterServiceProvider);

    if (user == null) {
      state = state.copyWith(
        isLoading: false,
        items: [],
        vendorApproved: false,
      );
      return;
    }

    final categories = user.vendorCategories ?? [];
    final approved = user.vendorApproved == true;

    state = state.copyWith(
      isLoading: true,
      clearError: true,
      vendorApproved: approved,
      categoryChips: filterService
          .availableCategoryFilters(categories)
          .toList()
        ..sort(),
      pendingApprovalMessage: approved
          ? null
          : 'Your vendor account is pending approval. You will see nearby requests once approved.',
    );

    if (!approved) {
      state = state.copyWith(isLoading: false, items: []);
      return;
    }

    // Check if shop location is assigned by admin
    final shopLocationAssigned = user.isShopLocationAssigned == true;
    if (!shopLocationAssigned) {
      state = state.copyWith(isLoading: false, items: []);
      return;
    }

    // Use admin-assigned shop location (not user-editable)
    final vendorLat = user.shopLatitude ?? 0.0;
    final vendorLon = user.shopLongitude ?? 0.0;
    final assignedRadius = user.assignedRadiusKm;

    try {
      await MockRequestRepository.instance.ensureInitialized();
      await MockProposalRepository.instance.ensureInitialized();

      final requests =
          await MockRequestRepository.instance.getMarketplaceActiveRequests();
      final proposals =
          await MockProposalRepository.instance.getAllProposals();

      final built = filterService.buildFeed(
        allRequests: requests,
        allProposals: proposals,
        vendorCategories: categories,
        vendorLatitude: vendorLat,
        vendorLongitude: vendorLon,
        vendorApproved: approved,
        categoryFilter: state.categoryFilter,
        assignedRadiusKm: assignedRadius,
      );

      final sorted = filterService.applySort(built, state.sortMode);

      state = state.copyWith(isLoading: false, items: sorted);
    } catch (e) {
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
