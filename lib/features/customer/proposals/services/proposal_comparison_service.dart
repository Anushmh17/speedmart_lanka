import '../../../../shared/models/location_model.dart';
import '../../../proposals/models/proposal.dart';
import '../../../requests/models/shopping_request.dart';
import '../../../orders/models/order_model.dart';
import '../models/customer_item_proposal_view.dart';
import '../models/customer_proposal_view.dart';
import '../models/proposal_comparison_mode.dart';
import '../models/proposal_badge.dart';

/// Sorts and ranks vendor proposals for customer comparison.
/// TODO: Replace with backend ranking API (price, SLA, vendor score).
class ProposalComparisonService {
  const ProposalComparisonService();

  String maskedVendorName(String vendorId) {
    final code = vendorId.hashCode.abs().toString();
    return 'Partner Shop Owner #${code.length > 4 ? code.substring(0, 4) : code}';
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
    final dl = request.deliveryLocation;
    final customerLat = (dl?.latitude != null && dl!.latitude != 0) ? dl.latitude! : request.latitude;
    final customerLon = (dl?.longitude != null && dl!.longitude != 0) ? dl.longitude! : request.longitude;

    if (customerLat == 0 && customerLon == 0) return 0;
    if (proposal.vendorLatitude == 0 && proposal.vendorLongitude == 0) return 0;

    return LocationModel.calculateDistance(
      lat1: customerLat,
      lon1: customerLon,
      lat2: proposal.vendorLatitude,
      lon2: proposal.vendorLongitude,
    );
  }

  List<ProposalBadge> _identifyBadges(
    Proposal proposal,
    List<Proposal> allProposals,
    List<OrderModel> orders,
  ) {
    final badges = <ProposalBadge>[];

    if (allProposals.isEmpty) return badges;

    // Helper to get delivery fee for a proposal taking into account waived fee
    double getEffectiveDeliveryFee(Proposal p) {
      final existingOrdersForVendor = orders.where((o) =>
          o.requestId == p.requestId &&
          o.vendorId == p.vendorId &&
          o.status != OrderStatus.cancelled).toList();
      if (existingOrdersForVendor.isNotEmpty) {
        final hasDispatchedOrder = existingOrdersForVendor.any((o) =>
            o.status == OrderStatus.outForDelivery ||
            o.status == OrderStatus.delivered ||
            o.status == OrderStatus.completed);
        if (!hasDispatchedOrder) {
          return 0.0;
        }
      }
      return p.deliveryFee;
    }

    final minPrice = allProposals
        .map((p) => p.subtotal + getEffectiveDeliveryFee(p))
        .reduce((a, b) => a < b ? a : b);
    if (proposal.subtotal + getEffectiveDeliveryFee(proposal) == minPrice) {
      badges.add(ProposalBadge.bestPrice);
    }

    final minDeliveryHours = allProposals
        .map((p) => deliverySortHours(p.estimatedDeliveryTime))
        .reduce((a, b) => a < b ? a : b);
    if (deliverySortHours(proposal.estimatedDeliveryTime) == minDeliveryHours) {
      badges.add(ProposalBadge.fastestDelivery);
    }

    final maxRating = allProposals
        .map((p) => ratingPlaceholderFor(p.vendorId))
        .reduce((a, b) => a > b ? a : b);
    if (ratingPlaceholderFor(proposal.vendorId) == maxRating) {
      badges.add(ProposalBadge.highestRated);
    }

    if (ratingPlaceholderFor(proposal.vendorId) > 4.6) {
      badges.add(ProposalBadge.popularVendor);
    }

    return badges;
  }

  List<CustomerProposalView> buildViews({
    required List<Proposal> proposals,
    required ShoppingRequest request,
    required ProposalComparisonMode mode,
    List<OrderModel> orders = const [],
  }) {
    final comparable = proposals
        .where((p) => p.status.isVisibleToCustomer || p.status == ProposalStatus.accepted)
        .toList();

    if (comparable.isEmpty) return [];

    final views = comparable.map((p) {
      final existingOrdersForVendor = orders.where((o) =>
          o.requestId == request.id &&
          o.vendorId == p.vendorId &&
          o.status != OrderStatus.cancelled).toList();

      bool waveDeliveryCharge = false;
      if (existingOrdersForVendor.isNotEmpty) {
        final hasDispatchedOrder = existingOrdersForVendor.any((o) =>
            o.status == OrderStatus.outForDelivery ||
            o.status == OrderStatus.delivered ||
            o.status == OrderStatus.completed);
        if (!hasDispatchedOrder) {
          waveDeliveryCharge = true;
        }
      }

      return CustomerProposalView(
        proposal: p,
        maskedVendorName: maskedVendorName(p.vendorId),
        distanceKm: distanceKmFor(proposal: p, request: request),
        ratingPlaceholder: ratingPlaceholderFor(p.vendorId),
        deliverySortHours: deliverySortHours(p.estimatedDeliveryTime),
        isBestForMode: false,
        badges: _identifyBadges(p, comparable, orders),
        waveDeliveryFee: waveDeliveryCharge,
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
            badges: v.badges,
            waveDeliveryFee: v.waveDeliveryFee,
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
      case ProposalComparisonMode.lowestDeliveryFee:
        list.sort((a, b) => a.deliveryFee.compareTo(b.deliveryFee));
        break;
      case ProposalComparisonMode.mostComplete:
        list.sort((a, b) {
          final aAvailable = a.proposal.items
              .where((item) => item.status != ProposalItemStatus.unavailable)
              .length;
          final bAvailable = b.proposal.items
              .where((item) => item.status != ProposalItemStatus.unavailable)
              .length;
          if (aAvailable != bAvailable) {
            return bAvailable.compareTo(aAvailable);
          }
          return a.totalPrice.compareTo(b.totalPrice);
        });
        break;
      case ProposalComparisonMode.recommended:
        list.sort((a, b) {
          final aScore = _recommendationScore(a, list);
          final bScore = _recommendationScore(b, list);
          return bScore.compareTo(aScore);
        });
        break;
    }
    return list;
  }

  double _recommendationScore(
    CustomerProposalView view,
    List<CustomerProposalView> allViews,
  ) {
    if (allViews.length <= 1) return 0;

    final prices = allViews.map((v) => v.totalPrice).toList();
    final minPrice = prices.reduce((a, b) => a < b ? a : b);
    final maxPrice = prices.reduce((a, b) => a > b ? a : b);

    final times = allViews
        .map((v) => v.deliverySortHours.toDouble())
        .toList();
    final minTime = times.reduce((a, b) => a < b ? a : b);
    final maxTime = times.reduce((a, b) => a > b ? a : b);

    final priceRange = maxPrice - minPrice;
    final timeRange = maxTime - minTime;

    final priceNorm = priceRange > 0
        ? 1 - ((view.totalPrice - minPrice) / priceRange)
        : 0.5;
    final timeNorm = timeRange > 0
        ? 1 - ((view.deliverySortHours - minTime) / timeRange)
        : 0.5;
    final ratingNorm = view.ratingPlaceholder / 5.0;

    return (priceNorm * 0.4) + (timeNorm * 0.3) + (ratingNorm * 0.3);
  }

  String? _bestId(List<CustomerProposalView> sorted, ProposalComparisonMode mode) {
    final active = sorted.where((v) => v.canAcceptOrReject).toList();
    if (active.isEmpty) return null;
    return active.first.proposal.id;
  }

  /// Builds item-level views grouped by requested item.
  /// Each [CustomerItemProposalView] holds all vendor offers for ONE item.
  /// Filters out [ProposalItemStatus.unavailable] items — customer never sees them.
  /// Marks [ItemVendorOffer.isSameVendorAsAnother] when a vendor has offers
  /// for multiple items in the same request.
  List<CustomerItemProposalView> buildItemViews({
    required List<Proposal> proposals,
    required ShoppingRequest request,
  }) {
    // Only consider proposals that are visible to the customer.
    final visibleProposals = proposals
        .where((p) => p.status.isVisibleToCustomer || p.status == ProposalStatus.accepted)
        .toList();

    // Collect all vendorIds that appear more than once across items
    // so we can label "Same Vendor" correctly.
    final vendorIdAppearanceMap = <String, int>{};
    for (final proposal in visibleProposals) {
      for (final item in proposal.items) {
        if (item.status != ProposalItemStatus.unavailable) {
          vendorIdAppearanceMap[proposal.vendorId] =
              (vendorIdAppearanceMap[proposal.vendorId] ?? 0) + 1;
        }
      }
    }

    final result = <CustomerItemProposalView>[];

    for (final requestItem in request.items) {
      final offers = <ItemVendorOffer>[];

      for (final proposal in visibleProposals) {
        // Find the matching ProposalItem for this requestItem
        final matchingProposalItems = proposal.items.where(
          (pi) => pi.requestItemId == requestItem.id &&
              pi.status != ProposalItemStatus.unavailable,
        );

        for (final pi in matchingProposalItems) {
          offers.add(ItemVendorOffer(
            vendorProposal: proposal,
            proposalItem: pi,
            maskedVendorName: maskedVendorName(proposal.vendorId),
            distanceKm: distanceKmFor(proposal: proposal, request: request),
            ratingPlaceholder: ratingPlaceholderFor(proposal.vendorId),
            isSameVendorAsAnother: (vendorIdAppearanceMap[proposal.vendorId] ?? 0) > 1,
          ));
        }
      }

      // Sort: accepted first, then by price ascending
      offers.sort((a, b) {
        if (a.isAccepted && !b.isAccepted) return -1;
        if (!a.isAccepted && b.isAccepted) return 1;
        return a.itemSubtotal.compareTo(b.itemSubtotal);
      });

      // Only add the item card if there's at least one visible offer
      if (offers.isNotEmpty) {
        result.add(CustomerItemProposalView(
          requestItem: requestItem,
          vendorOffers: offers,
        ));
      }
    }

    return result;
  }
}

