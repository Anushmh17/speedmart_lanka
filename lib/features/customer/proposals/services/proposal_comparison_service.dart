import '../../../../shared/models/location_model.dart';
import '../../../proposals/models/proposal.dart';
import '../../../requests/models/shopping_request.dart';
import '../models/customer_proposal_view.dart';
import '../models/proposal_comparison_mode.dart';

/// Sorts and ranks vendor proposals for customer comparison.
/// TODO: Replace with backend ranking API (price, SLA, vendor score).
class ProposalComparisonService {
  const ProposalComparisonService();

  String maskedVendorName(String vendorId) {
    final code = vendorId.hashCode.abs().toString();
    return 'Partner Merchant #${code.length > 4 ? code.substring(0, 4) : code}';
  }

  /// Stable mock rating until real vendor reviews exist.
  double ratingPlaceholderFor(String vendorId) {
    final seed = vendorId.hashCode.abs() % 10;
    return 4.0 + (seed / 10);
  }

  int deliverySortHours(String estimatedDeliveryTime) {
    final lower = estimatedDeliveryTime.toLowerCase();
    final match = RegExp(r'(\d+)').firstMatch(lower);
    if (match != null) {
      final n = int.tryParse(match.group(1)!) ?? 24;
      if (lower.contains('minute') || lower.contains('min')) {
        return (n / 60).ceil().clamp(1, 24);
      }
      if (lower.contains('day')) return n * 24;
      return n;
    }
    if (lower.contains('same day')) return 8;
    if (lower.contains('immediate') || lower.contains('asap')) return 1;
    return 24;
  }

  double distanceKmFor({
    required Proposal proposal,
    required ShoppingRequest request,
  }) {
    if (request.latitude == 0 && request.longitude == 0) return 0;
    if (proposal.vendorLatitude == 0 && proposal.vendorLongitude == 0) {
      return 0;
    }
    return LocationModel.calculateDistance(
      lat1: request.latitude,
      lon1: request.longitude,
      lat2: proposal.vendorLatitude,
      lon2: proposal.vendorLongitude,
    );
  }

  List<CustomerProposalView> buildViews({
    required List<Proposal> proposals,
    required ShoppingRequest request,
    required ProposalComparisonMode mode,
  }) {
    final comparable = proposals
        .where((p) => p.status.isVisibleToCustomer || p.status == ProposalStatus.accepted)
        .toList();

    if (comparable.isEmpty) return [];

    final views = comparable.map((p) {
      return CustomerProposalView(
        proposal: p,
        maskedVendorName: maskedVendorName(p.vendorId),
        distanceKm: distanceKmFor(proposal: p, request: request),
        ratingPlaceholder: ratingPlaceholderFor(p.vendorId),
        deliverySortHours: deliverySortHours(p.estimatedDeliveryTime),
        isBestForMode: false,
      );
    }).toList();

    final sorted = _sort(views, mode);
    if (sorted.isEmpty) return sorted;

    final bestId = _bestId(sorted, mode);
    return sorted
        .map(
          (v) => CustomerProposalView(
            proposal: v.proposal,
            maskedVendorName: v.maskedVendorName,
            distanceKm: v.distanceKm,
            ratingPlaceholder: v.ratingPlaceholder,
            deliverySortHours: v.deliverySortHours,
            isBestForMode: v.proposal.id == bestId && v.canAcceptOrReject,
          ),
        )
        .toList();
  }

  List<CustomerProposalView> _sort(
    List<CustomerProposalView> views,
    ProposalComparisonMode mode,
  ) {
    final list = List<CustomerProposalView>.from(views);
    switch (mode) {
      case ProposalComparisonMode.lowestPrice:
        list.sort((a, b) => a.totalPrice.compareTo(b.totalPrice));
        break;
      case ProposalComparisonMode.fastestDelivery:
        list.sort(
          (a, b) => a.deliverySortHours.compareTo(b.deliverySortHours),
        );
        break;
      case ProposalComparisonMode.nearestVendor:
        list.sort((a, b) {
          if (a.distanceKm == 0 && b.distanceKm == 0) {
            return a.totalPrice.compareTo(b.totalPrice);
          }
          return a.distanceKm.compareTo(b.distanceKm);
        });
        break;
    }
    return list;
  }

  String? _bestId(List<CustomerProposalView> sorted, ProposalComparisonMode mode) {
    final active = sorted.where((v) => v.canAcceptOrReject).toList();
    if (active.isEmpty) return null;
    return active.first.proposal.id;
  }
}
