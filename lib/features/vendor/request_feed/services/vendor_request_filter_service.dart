import 'package:flutter/foundation.dart';
import '../../../customer/delivery_address/utils/vendor_delivery_privacy.dart';
import '../../../proposals/models/proposal.dart';
import '../../../requests/models/shopping_request.dart';
import '../../../requests/models/request_item.dart';
import '../../../../shared/models/location_model.dart';
import '../../../../shared/models/vendor_status.dart';
import '../../../../shared/utils/category_constants.dart';
import '../models/vendor_feed_enums.dart';
import '../models/vendor_feed_request.dart';

/// Filters and enriches customer requests for the vendor marketplace feed.
/// TODO: Replace with backend geo + category matching API.
class VendorRequestFilterService {
  const VendorRequestFilterService();

  static const Map<String, double> categoryRadiusKm = {
    'groceries': 5,
    'electronics': 5,
    'hardware': 5,
    'furniture': 5,
    'pharmacy': 5,
    'clothing': 5,
    'vehicle parts': 5,
    'home appliances': 5,
    'stationery': 5,
    'other': 5,
  };

  static const double defaultRadiusKm = 5;

  static bool isActiveMarketplaceRequest(RequestStatus status) {
    return status == RequestStatus.submitted ||
        status == RequestStatus.waitingForVendor ||
        status == RequestStatus.proposalSubmitted;
  }

  double radiusKmForCategory(String category) {
    final key = category.trim().toLowerCase();
    if (key.isEmpty) return defaultRadiusKm;
    return categoryRadiusKm[key] ?? defaultRadiusKm;
  }

  double maxRadiusForRequest(
    ShoppingRequest request, {
    List<String>? vendorCategories,
  }) {
    final cats = _requestCategories(request);
    if (cats.isEmpty) {
      if (vendorCategories != null && vendorCategories.isNotEmpty) {
        return vendorCategories
            .map(radiusKmForCategory)
            .reduce((a, b) => a > b ? a : b);
      }
      return defaultRadiusKm;
    }
    return cats.map(radiusKmForCategory).reduce((a, b) => a > b ? a : b);
  }

  bool vendorIsApproved({VendorStatus? vendorStatus, bool? vendorApproved}) {
    if (vendorStatus != null) {
      return vendorStatus == VendorStatus.approved;
    }
    return vendorApproved == true;
  }

  /// Filter items in a request to only those matching vendor categories.
  /// Returns items that match vendor's approved categories.
  /// Uses VendorCategories.normalize() to handle aliases like "Hardware items" -> "hardware"
  List<RequestItem> filterMatchingItems(
    ShoppingRequest request,
    List<String> vendorCategories,
  ) {
    if (vendorCategories.isEmpty) return request.items;

    // Normalize vendor categories using VendorCategories.normalize()
    final vendorNormalized = vendorCategories
        .map((c) => VendorCategories.normalize(c))
        .where((c) => c.isNotEmpty)
        .toSet();

    debugPrint('[FeedCategoryFix] Vendor normalized categories: $vendorNormalized');

    final matchingItems = request.items.where((item) {
      // Items with no category are visible to all vendors.
      if (item.category == null || item.category!.isEmpty) {
        debugPrint('[FeedCategoryFix] Item "${item.itemName}" has no category, including for all vendors');
        return true;
      }

      final originalCategory = item.category!;
      final itemCategoryNormalized = VendorCategories.normalize(originalCategory);
      final matches = vendorNormalized.contains(itemCategoryNormalized);

      debugPrint('[FeedCategoryFix] Item "${item.itemName}": $originalCategory -> $itemCategoryNormalized, match: $matches');
      return matches;
    }).toList();

    return matchingItems;
  }

  /// Resolves the customer's delivery coordinates from a request.
  /// Prefers deliveryLocation (GPS/picker) over top-level lat/lon fields.
  static ({double lat, double lon}) resolveCustomerCoords(ShoppingRequest request) {
    final dl = request.deliveryLocation;
    if (dl != null && (dl.latitude ?? 0) != 0 && (dl.longitude ?? 0) != 0) {
      return (lat: dl.latitude!, lon: dl.longitude!);
    }
    return (lat: request.latitude, lon: request.longitude);
  }

  bool isWithinRadius({
    required ShoppingRequest request,
    required double vendorLat,
    required double vendorLon,
    double? assignedRadiusKm,
    List<String> vendorCategories = const [],
  }) {
    final coords = resolveCustomerCoords(request);
    if (coords.lat == 0 && coords.lon == 0) {
      debugPrint('[DistanceAudit] Invalid customer coordinates (0,0), rejecting');
      return false;
    }
    final distance = LocationModel.calculateDistance(
      lat1: coords.lat,
      lon1: coords.lon,
      lat2: vendorLat,
      lon2: vendorLon,
    );
    final maxRadius = assignedRadiusKm ?? 5.0;
    return distance <= maxRadius;
  }

  RequestUrgency urgencyFor(ShoppingRequest request) {
    final hours = DateTime.now().difference(request.createdAt).inHours;
    if (hours < 2) return RequestUrgency.high;
    if (hours < 6) return RequestUrgency.medium;
    return RequestUrgency.normal;
  }

  String primaryCategoryFor(ShoppingRequest request) {
    final cats = _requestCategories(request);
    if (cats.isEmpty) return 'General';
    return cats.first;
  }

  String approximateAreaFor(ShoppingRequest request) {
    return request.vendorVisibleAreaLabel;
  }

  String districtFor(ShoppingRequest request) {
    if (request.deliveryLocation?.district.isNotEmpty == true) {
      return request.deliveryLocation!.district;
    }
    return '';
  }

  int proposalCountFor(String requestId, List<Proposal> allProposals) {
    return allProposals
        .where((p) =>
            p.requestId == requestId &&
            p.status != ProposalStatus.withdrawn &&
            p.status != ProposalStatus.rejected &&
            p.status != ProposalStatus.expired &&
            p.status != ProposalStatus.draft)
        .length;
  }

  List<VendorFeedRequest> buildFeed({
    required List<ShoppingRequest> allRequests,
    required List<Proposal> allProposals,
    required List<String> vendorCategories,
    required double vendorLatitude,
    required double vendorLongitude,
    VendorStatus? vendorStatus,
    bool? vendorApproved,
    double? assignedRadiusKm,
    String? categoryFilter,
    String? vendorId,
  }) {
    if (!vendorIsApproved(vendorStatus: vendorStatus, vendorApproved: vendorApproved)) {
      return [];
    }

    // Build a map of requestId -> set of bid categories for this vendor.
    // A request is only hidden from the feed when the vendor has bid on ALL
    // categories that match their approved categories (not just one of them).
    final Map<String, Set<String>> bidCategoriesByRequest = {};
    if (vendorId != null) {
      for (final p in allProposals) {
        if (p.vendorId != vendorId) continue;
        if (p.status == ProposalStatus.withdrawn || p.status == ProposalStatus.draft) continue;
        bidCategoriesByRequest
            .putIfAbsent(p.requestId, () => {})
            .add(p.categoryNormalized ?? '');
      }
    }

    debugPrint('[FeedAudit] Vendor bid categories by request: $bidCategoriesByRequest');

    // Normalize vendor categories using VendorCategories.normalize()
    final vendorNormalized = vendorCategories
        .map((c) => VendorCategories.normalize(c))
        .where((c) => c.isNotEmpty)
        .toSet();

    debugPrint('[FeedCategoryFix] ===== VENDOR FEED BUILD START =====');
    debugPrint('[FeedCategoryFix] vendor allowedCategories (raw): $vendorCategories');
    debugPrint('[FeedCategoryFix] vendor normalized categories: $vendorNormalized');
    debugPrint('[FeedCategoryFix] Vendor location: lat=$vendorLatitude, lng=$vendorLongitude');
    debugPrint('[FeedCategoryFix] Assigned radius: ${assignedRadiusKm ?? 5.0}km');

    final active =
        allRequests.where((r) => isActiveMarketplaceRequest(r.status));

    debugPrint('[FeedCategoryFix] evaluating ${active.length} active requests');

    final matched = active.where((request) {
      debugPrint('[FeedCategoryFix] ===== REQUEST ${request.id} =====');

      // Exclude request only if vendor has already bid on ALL matching categories.
      final matchingCatsForRequest = filterMatchingItems(request, vendorCategories)
          .map((i) => VendorCategories.normalize(i.category ?? ''))
          .where((c) => c.isNotEmpty)
          .toSet();
      final bidCats = bidCategoriesByRequest[request.id] ?? {};
      final allCatsBid = matchingCatsForRequest.isNotEmpty &&
          matchingCatsForRequest.every((c) => bidCats.contains(c));
      if (allCatsBid) {
        debugPrint('[FeedCategoryFix] hidden reason: vendor_already_bid_all_categories');
        return false;
      }

      debugPrint('[FeedCategoryFix] original items: ${request.items.map((i) => "${i.itemName} (${i.category})").join(", ")}');

      // Filter items to only those matching vendor categories
      final matchingItems = filterMatchingItems(request, vendorCategories);
      
      debugPrint('[FeedCategoryFix] matching items: ${matchingItems.map((i) => "${i.itemName} (${i.category})").join(", ")}');

      // If no items match vendor categories, hide the entire request
      if (matchingItems.isEmpty) {
        debugPrint('[FeedCategoryFix] hidden reason: no_matching_items');
        debugPrint('[FeedCategoryFix] request: ${request.id}, visible: false');
        return false;
      }

      // Check radius
      final radiusCheck = isWithinRadius(
        request: request,
        vendorLat: vendorLatitude,
        vendorLon: vendorLongitude,
        assignedRadiusKm: assignedRadiusKm,
        vendorCategories: vendorCategories,
      );

      final coords = resolveCustomerCoords(request);
      final distance = coords.lat == 0 && coords.lon == 0
          ? 0.0
          : LocationModel.calculateDistance(
              lat1: coords.lat,
              lon1: coords.lon,
              lat2: vendorLatitude,
              lon2: vendorLongitude,
            );

      final assignedRadius = assignedRadiusKm ?? 5.0;

      debugPrint('[DistanceAudit] request: ${request.id}');
      debugPrint('[DistanceAudit] Customer coords: lat=${coords.lat}, lng=${coords.lon}');
      debugPrint('[DistanceAudit] Vendor coords: lat=$vendorLatitude, lng=$vendorLongitude');
      debugPrint('[DistanceAudit] Distance: ${distance.toStringAsFixed(1)}km, Radius: ${assignedRadius}km, Inside: $radiusCheck');

      if (!radiusCheck) {
        debugPrint('[FeedCategoryFix] hidden reason: outside_service_radius');
        debugPrint('[FeedCategoryFix] request: ${request.id}, visible: false');
        return false;
      }

      // Apply category filter if active
      if (categoryFilter != null && categoryFilter.isNotEmpty) {
        final filterNormalized = VendorCategories.normalize(categoryFilter);
        final hasFilterMatch = matchingItems.any(
          (item) => VendorCategories.normalize(item.category ?? '') == filterNormalized,
        );
        if (!hasFilterMatch) {
          debugPrint('[FeedCategoryFix] hidden reason: active_filter_mismatch');
          debugPrint('[FeedCategoryFix] request: ${request.id}, visible: false');
          return false;
        }
      }

      debugPrint('[FeedCategoryFix] request: ${request.id}, visible: true, distance: ${distance.toStringAsFixed(1)}km');
      return true;
    });

    final assignedRadius = assignedRadiusKm ?? 5.0;

    final feedItems = <VendorFeedRequest>[];

    for (final request in matched) {
      final coords = resolveCustomerCoords(request);
      final distance = coords.lat == 0 && coords.lon == 0
          ? 0.0
          : LocationModel.calculateDistance(
              lat1: coords.lat,
              lon1: coords.lon,
              lat2: vendorLatitude,
              lon2: vendorLongitude,
            );

      final matchingItems = filterMatchingItems(request, vendorCategories);

      // Keep all matching items in one card so allCategories shows every category.
      final filteredRequest = request.copyWith(items: matchingItems);

      // [ImageAudit] Vendor feed
      for (final item in filteredRequest.items) {
        debugPrint('[ImageAudit] Vendor feed item: ${filteredRequest.id}');
        debugPrint('[ImageAudit] Item: ${item.itemName}');
        debugPrint('[ImageAudit] Image count: ${item.imageUrls.length}');
        debugPrint('[ImageAudit] Images: ${item.imageUrls}');
      }

      feedItems.add(
        VendorFeedRequest(
          request: filteredRequest,
          distanceKm: double.parse(distance.toStringAsFixed(1)),
          proposalCount: proposalCountFor(request.id, allProposals),
          urgency: urgencyFor(request),
          primaryCategory: primaryCategoryFor(filteredRequest),
          approximateArea: approximateAreaFor(request),
          district: districtFor(request),
          maxRadiusKm: assignedRadius,
        ),
      );

    }

    return feedItems;
  }

  List<VendorFeedRequest> applySort(
    List<VendorFeedRequest> items,
    VendorFeedSortMode sort,
  ) {
    final sorted = List<VendorFeedRequest>.from(items);
    switch (sort) {
      case VendorFeedSortMode.nearest:
        sorted.sort((a, b) => a.distanceKm.compareTo(b.distanceKm));
        break;
      case VendorFeedSortMode.newest:
        sorted.sort(
          (a, b) => b.request.createdAt.compareTo(a.request.createdAt),
        );
        break;
      case VendorFeedSortMode.lowCompetition:
        sorted.sort((a, b) {
          final cmp = a.proposalCount.compareTo(b.proposalCount);
          if (cmp != 0) return cmp;
          return a.distanceKm.compareTo(b.distanceKm);
        });
        break;
    }
    return sorted;
  }

  Set<String> availableCategoryFilters(List<String> vendorCategories) {
    if (vendorCategories.isEmpty) {
      return {'Groceries', 'Electronics', 'Hardware'};
    }
    return vendorCategories.toSet();
  }

  static Set<String> _requestCategories(ShoppingRequest request) {
    return request.items
        .map((i) => i.category?.trim() ?? '')
        .where((c) => c.isNotEmpty)
        .toSet();
  }
}

