import 'package:flutter/foundation.dart';
import '../../../customer/delivery_address/utils/vendor_delivery_privacy.dart';
import '../../../proposals/models/proposal.dart';
import '../../../requests/models/shopping_request.dart';
import '../../../../shared/models/location_model.dart';
import '../../../../shared/models/vendor_status.dart';
import '../models/vendor_feed_enums.dart';
import '../models/vendor_feed_request.dart';

/// Filters and enriches customer requests for the vendor marketplace feed.
/// TODO: Replace with backend geo + category matching API.
class VendorRequestFilterService {
  const VendorRequestFilterService();

  static const Map<String, double> categoryRadiusKm = {
    'groceries': 5,
    'electronics': 15,
    'vehicle parts': 25,
    'automotive': 25,
    'furniture': 20,
    'hardware': 15,
    'home appliances': 15,
    'clothing': 12,
    'pharmacy': 8,
    'stationery': 12,
  };

  static const double defaultRadiusKm = 15;

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

  bool matchesVendorCategories(
    ShoppingRequest request,
    List<String> vendorCategories,
  ) {
    if (vendorCategories.isEmpty) return true;

    final requestCats = _requestCategories(request);
    if (requestCats.isEmpty) return true;

    final vendorLower =
        vendorCategories.map((c) => c.trim().toLowerCase()).toSet();

    return requestCats.any((c) => vendorLower.contains(c.toLowerCase()));
  }

  bool isWithinRadius({
    required ShoppingRequest request,
    required double vendorLat,
    required double vendorLon,
    double? assignedRadiusKm,
    List<String> vendorCategories = const [],
  }) {
    // Invalid coordinates - can't determine distance
    if ((request.latitude == 0 && request.longitude == 0) && request.deliveryLocation?.latitude == null) {
      debugPrint('[DistanceAudit] Invalid coordinates (0,0) and no deliveryLocation, rejecting');
      return false;
    }

    final distance = LocationModel.calculateDistance(
      lat1: request.latitude,
      lon1: request.longitude,
      lat2: vendorLat,
      lon2: vendorLon,
    );
    // Use admin-assigned radius, default to 20km if not set
    final maxRadius = assignedRadiusKm ?? 20.0;
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
  }) {
    if (!vendorIsApproved(vendorStatus: vendorStatus, vendorApproved: vendorApproved)) {
      return [];
    }

    debugPrint('[FeedAudit] Vendor allowedCategories: $vendorCategories');
    debugPrint('[FeedAudit] Vendor location: lat=$vendorLatitude, lng=$vendorLongitude');
    debugPrint('[FeedAudit] Assigned radius: ${assignedRadiusKm ?? 20.0}km');

    final active =
        allRequests.where((r) => isActiveMarketplaceRequest(r.status));

    debugPrint('[CategoryAudit] vendorCategories: $vendorCategories');
    debugPrint('[FeedAudit] evaluating ${active.length} active requests');

    final matched = active.where((request) {
      final requestCats = _requestCategories(request).toList();
      final categoryMatch = matchesVendorCategories(request, vendorCategories);

      debugPrint('[CategoryAudit] request.id: ${request.id}, categories: $requestCats, match: $categoryMatch');

      if (!categoryMatch) {
        debugPrint('[FeedAudit] request: ${request.id}, visible: false, reason: category_mismatch');
        return false;
      }

      final radiusCheck = isWithinRadius(
        request: request,
        vendorLat: vendorLatitude,
        vendorLon: vendorLongitude,
        assignedRadiusKm: assignedRadiusKm,
        vendorCategories: vendorCategories,
      );

      final distance = request.latitude == 0 && request.longitude == 0
          ? 0.0
          : LocationModel.calculateDistance(
              lat1: request.latitude,
              lon1: request.longitude,
              lat2: vendorLatitude,
              lon2: vendorLongitude,
            );

      final assignedRadius = assignedRadiusKm ?? 20.0;

      debugPrint('[DistanceAudit] request: ${request.id}');
      debugPrint('[DistanceAudit] Request coords: lat=${request.latitude}, lng=${request.longitude}');
      debugPrint('[DistanceAudit] Vendor coords: lat=$vendorLatitude, lng=$vendorLongitude');
      debugPrint('[DistanceAudit] Distance: ${distance.toStringAsFixed(1)}km, Radius: ${assignedRadius}km, Inside: $radiusCheck');

      if (!radiusCheck) {
        debugPrint('[FeedAudit] request: ${request.id}, visible: false, reason: outside_service_radius');
        return false;
      }

      if (categoryFilter != null && categoryFilter.isNotEmpty) {
        final filter = categoryFilter.toLowerCase();
        final cats = _requestCategories(request);
        final filterMatch = cats.any((c) => c.toLowerCase() == filter);
        if (!filterMatch) {
          debugPrint('[FeedAudit] request: ${request.id}, visible: false, reason: active_filter_mismatch');
          return false;
        }
      }

      debugPrint('[FeedAudit] request: ${request.id}, visible: true, distance: ${distance.toStringAsFixed(1)}km');
      return true;
    });

    final assignedRadius = assignedRadiusKm ?? 20.0;

    return matched.map((request) {
      final distance = request.latitude == 0 && request.longitude == 0
          ? 0.0
          : LocationModel.calculateDistance(
              lat1: request.latitude,
              lon1: request.longitude,
              lat2: vendorLatitude,
              lon2: vendorLongitude,
            );

      return VendorFeedRequest(
        request: request,
        distanceKm: double.parse(distance.toStringAsFixed(1)),
        proposalCount: proposalCountFor(request.id, allProposals),
        urgency: urgencyFor(request),
        primaryCategory: primaryCategoryFor(request),
        approximateArea: approximateAreaFor(request),
        district: districtFor(request),
        maxRadiusKm: assignedRadius,
      );
    }).toList();
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
