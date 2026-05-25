import '../../../proposals/models/proposal.dart';

/// Customer-facing enriched proposal for comparison cards.
class CustomerProposalView {
  const CustomerProposalView({
    required this.proposal,
    required this.maskedVendorName,
    required this.distanceKm,
    required this.ratingPlaceholder,
    required this.deliverySortHours,
    required this.isBestForMode,
  });

  final Proposal proposal;
  final String maskedVendorName;
  final double distanceKm;
  final double ratingPlaceholder;
  final int deliverySortHours;
  final bool isBestForMode;

  String get proposalId => proposal.id;

  double get totalPrice => proposal.totalPrice;

  double get subtotal => proposal.subtotal;

  double get deliveryFee => proposal.deliveryFee;

  String get estimatedDelivery => proposal.estimatedDeliveryTime;

  bool get canAcceptOrReject =>
      proposal.status == ProposalStatus.submitted ||
      proposal.status == ProposalStatus.updated;

  bool get isAccepted => proposal.status == ProposalStatus.accepted;

  bool get isInactive =>
      proposal.status == ProposalStatus.withdrawn ||
      proposal.status == ProposalStatus.rejected ||
      proposal.status == ProposalStatus.expired;
}
