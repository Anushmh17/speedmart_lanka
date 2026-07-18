import '../../../proposals/models/proposal.dart';
import 'proposal_badge.dart';

/// Customer-facing enriched proposal for comparison cards.
class CustomerProposalView {
  const CustomerProposalView({
    required this.proposal,
    this.proposalItemId,
    required this.maskedVendorName,
    required this.distanceKm,
    required this.ratingPlaceholder,
    required this.deliverySortHours,
    required this.isBestForMode,
    this.badges = const [],
    this.waveDeliveryFee = false,
  });

  /// The full proposal object.
  final Proposal proposal;

  /// Unique item ID within the proposal.
  final String? proposalItemId;

  final String maskedVendorName;
  final double distanceKm;
  final double ratingPlaceholder;
  final int deliverySortHours;
  final bool isBestForMode;
  final List<ProposalBadge> badges;
  final bool waveDeliveryFee;

  /// Proposal ID.
  String get proposalId => proposal.id;

  /// Unique identifier for a proposal line item.
  /// Example: proposal_123_item_1
  String get proposalLineId =>
      proposalItemId == null || proposalItemId!.isEmpty
          ? proposal.id
          : '${proposal.id}_$proposalItemId';

  /// Computed total = items subtotal (excluding unavailable) + delivery.
  /// Matches the calculation used in the payment screen to avoid discrepancies.
  double get totalPrice => proposal.subtotal + deliveryFee;

  double get subtotal => proposal.subtotal;

  double get deliveryFee => waveDeliveryFee ? 0.0 : proposal.deliveryFee;

  String get estimatedDelivery => proposal.estimatedDeliveryTime;

  bool get canAcceptOrReject =>
      proposal.status == ProposalStatus.submitted ||
      proposal.status == ProposalStatus.updated;

  bool get isAccepted => proposal.status == ProposalStatus.accepted;

  bool get isInactive =>
      proposal.status == ProposalStatus.withdrawn ||
      proposal.status == ProposalStatus.rejected ||
      proposal.status == ProposalStatus.expired;

  CustomerProposalView copyWith({
    Proposal? proposal,
    String? proposalItemId,
    String? maskedVendorName,
    double? distanceKm,
    double? ratingPlaceholder,
    int? deliverySortHours,
    bool? isBestForMode,
    List<ProposalBadge>? badges,
    bool? waveDeliveryFee,
  }) {
    return CustomerProposalView(
      proposal: proposal ?? this.proposal,
      proposalItemId: proposalItemId ?? this.proposalItemId,
      maskedVendorName: maskedVendorName ?? this.maskedVendorName,
      distanceKm: distanceKm ?? this.distanceKm,
      ratingPlaceholder: ratingPlaceholder ?? this.ratingPlaceholder,
      deliverySortHours: deliverySortHours ?? this.deliverySortHours,
      isBestForMode: isBestForMode ?? this.isBestForMode,
      badges: badges ?? this.badges,
      waveDeliveryFee: waveDeliveryFee ?? this.waveDeliveryFee,
    );
  }
}
