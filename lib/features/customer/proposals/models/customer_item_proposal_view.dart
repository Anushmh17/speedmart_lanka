import '../../../proposals/models/proposal.dart';
import '../../../requests/models/request_item.dart';

/// A single vendor's offer for one specific requested item.
class ItemVendorOffer {
  const ItemVendorOffer({
    required this.vendorProposal,
    required this.proposalItem,
    required this.maskedVendorName,
    required this.distanceKm,
    required this.ratingPlaceholder,
    this.isSameVendorAsAnother = false,
  });

  final Proposal vendorProposal;
  final ProposalItem proposalItem;
  final String maskedVendorName;
  final double distanceKm;
  final double ratingPlaceholder;

  /// True when the same vendor has offers for other items in this request.
  final bool isSameVendorAsAnother;

  bool get canAccept =>
      proposalItem.customerDecision == ProposalItemDecision.pending &&
      (vendorProposal.status == ProposalStatus.submitted ||
          vendorProposal.status == ProposalStatus.updated);

  bool get isAccepted =>
      proposalItem.customerDecision == ProposalItemDecision.accepted;

  bool get isRejected =>
      proposalItem.customerDecision == ProposalItemDecision.rejected;

  /// Display name: use alternativeName if alternative, else itemName.
  String get displayItemName {
    if (proposalItem.status == ProposalItemStatus.alternative &&
        proposalItem.alternativeName != null &&
        proposalItem.alternativeName!.isNotEmpty) {
      return proposalItem.alternativeName!;
    }
    return proposalItem.itemName;
  }

  /// Status label shown to the customer.
  String get statusLabel {
    switch (proposalItem.status) {
      case ProposalItemStatus.available:
        return 'Available';
      case ProposalItemStatus.alternative:
        return 'Alternative';
      case ProposalItemStatus.unavailable:
        return 'Unavailable';
    }
  }

  /// Customer item amount includes its proportional share of the commission
  /// that is already included in the proposal total.
  double get itemSubtotal => vendorProposal.customerItemTotal(proposalItem);
}

/// Customer-facing item-level proposal view.
/// Groups all vendor offers for ONE specific requested item.
class CustomerItemProposalView {
  const CustomerItemProposalView({
    required this.requestItem,
    required this.vendorOffers,
  });

  /// The original item from the customer's shopping list.
  final RequestItem requestItem;

  /// All vendor offers for this item (status != unavailable).
  final List<ItemVendorOffer> vendorOffers;

  String get requestItemId => requestItem.id;
  String get requestItemName => requestItem.itemName;
  String get requestItemCategory => requestItem.category ?? '';
  int get requestedQuantity => requestItem.quantity;
  String? get requestedUnit => requestItem.unit;

  bool get hasAnyOffer => vendorOffers.isNotEmpty;

  bool get isFullyResolved =>
      vendorOffers.every((o) => !o.canAccept);

  /// True when at least one offer has been accepted for this item.
  bool get isAccepted =>
      vendorOffers.any((o) => o.isAccepted);
}

