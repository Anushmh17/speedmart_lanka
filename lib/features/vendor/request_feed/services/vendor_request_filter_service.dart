import '../../../customer/delivery_address/utils/vendor_delivery_privacy.dart';
import '../../../proposals/models/proposal.dart';
import '../../../requests/models/shopping_request.dart';
import '../../../../shared/models/location_model.dart';
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

  bool vendorIsApproved({required bool? vendorApproved}) {
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
    List<String> vendorCategories = const [],
  }) {
    if (request.latitude == 0 && request.longitude == 0) {
      return true;
    }
    final distance = LocationModel.calculateDistance(
      lat1: request.latitude,
      lon1: request.longitude,
      lat2: vendorLat,
      lon2: vendorLon,
    );
    final maxRadius = maxRadiusForRequest(
      request,
      vendorCategories: vendorCategories,
    );
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
    required bool vendorApproved,
    String? categoryFilter,
  }) {
    if (!vendorIsApproved(vendorApproved: vendorApproved)) {
      return [];
    }

    final active =
        allRequests.where((r) => isActiveMarketplaceRequest(r.status));

    final matched = active.where((request) {
      if (!matchesVendorCategories(request, vendorCategories)) return false;
      if (!isWithinRadius(
        request: request,
        vendorLat: vendorLatitude,
        vendorLon: vendorLongitude,
        vendorCategories: vendorCategories,
      )) {
        return false;
      }
      if (categoryFilter != null && categoryFilter.isNotEmpty) {
        final filter = categoryFilter.toLowerCase();
        final cats = _requestCategories(request);
        if (!cats.any((c) => c.toLowerCase() == filter)) return false;
      }
      return true;
    });

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
        maxRadiusKm: maxRadiusForRequest(
          request,
          vendorCategories: vendorCategories,
        ),
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
