/// Category-level fulfillment status for multi-category requests.
/// Each category in a request has independent lifecycle.
enum RequestCategoryStatus {
  pending,
  proposalReceived,
  accepted,
  codConfirmed,
  outForDelivery,
  paid,
  completed,
  cancelled;

  String get displayName {
    switch (this) {
      case RequestCategoryStatus.pending:
        return 'Pending';
      case RequestCategoryStatus.proposalReceived:
        return 'Proposal Received';
      case RequestCategoryStatus.accepted:
        return 'Accepted';
      case RequestCategoryStatus.codConfirmed:
        return 'COD Confirmed';
      case RequestCategoryStatus.outForDelivery:
        return 'Out for Delivery';
      case RequestCategoryStatus.paid:
        return 'Paid';
      case RequestCategoryStatus.completed:
        return 'Completed';
      case RequestCategoryStatus.cancelled:
        return 'Cancelled';
    }
  }

  bool get isActive {
    return this != RequestCategoryStatus.cancelled &&
        this != RequestCategoryStatus.completed;
  }

  bool get canReceiveProposals {
    return this == RequestCategoryStatus.pending ||
        this == RequestCategoryStatus.proposalReceived;
  }

  bool get isInProgress {
    return this == RequestCategoryStatus.accepted ||
        this == RequestCategoryStatus.codConfirmed ||
        this == RequestCategoryStatus.outForDelivery ||
        this == RequestCategoryStatus.paid;
  }

  bool get isAwaitingPayment {
    return this == RequestCategoryStatus.codConfirmed ||
        this == RequestCategoryStatus.outForDelivery;
  }
}

/// Tracks fulfillment status for a specific category within a request
class RequestCategoryFulfillment {
  final String categoryNormalized; // e.g., "electronics", "groceries"
  final RequestCategoryStatus status;
  final String? acceptedProposalId; // Vendor selected for this category
  final String? acceptedVendorId;
  final DateTime? acceptedAt;
  final DateTime? codConfirmedAt; // When customer confirmed COD
  final DateTime? paidAt; // When vendor confirmed cash collected (for COD) or card payment succeeded
  final DateTime? completedAt;
  final DateTime? cancelledAt;
  final String? cancellationReason;

  RequestCategoryFulfillment({
    required this.categoryNormalized,
    this.status = RequestCategoryStatus.pending,
    this.acceptedProposalId,
    this.acceptedVendorId,
    this.acceptedAt,
    this.codConfirmedAt,
    this.paidAt,
    this.completedAt,
    this.cancelledAt,
    this.cancellationReason,
  });

  RequestCategoryFulfillment copyWith({
    String? categoryNormalized,
    RequestCategoryStatus? status,
    String? acceptedProposalId,
    String? acceptedVendorId,
    DateTime? acceptedAt,
    DateTime? codConfirmedAt,
    DateTime? paidAt,
    DateTime? completedAt,
    DateTime? cancelledAt,
    String? cancellationReason,
    bool clearAcceptedProposal = false,
    bool clearAcceptedVendor = false,
  }) {
    return RequestCategoryFulfillment(
      categoryNormalized: categoryNormalized ?? this.categoryNormalized,
      status: status ?? this.status,
      acceptedProposalId: clearAcceptedProposal
          ? null
          : (acceptedProposalId ?? this.acceptedProposalId),
      acceptedVendorId: clearAcceptedVendor
          ? null
          : (acceptedVendorId ?? this.acceptedVendorId),
      acceptedAt: acceptedAt ?? this.acceptedAt,
      codConfirmedAt: codConfirmedAt ?? this.codConfirmedAt,
      paidAt: paidAt ?? this.paidAt,
      completedAt: completedAt ?? this.completedAt,
      cancelledAt: cancelledAt ?? this.cancelledAt,
      cancellationReason: cancellationReason ?? this.cancellationReason,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'categoryNormalized': categoryNormalized,
      'status': status.name,
      'acceptedProposalId': acceptedProposalId,
      'acceptedVendorId': acceptedVendorId,
      'acceptedAt': acceptedAt?.toIso8601String(),
      'codConfirmedAt': codConfirmedAt?.toIso8601String(),
      'paidAt': paidAt?.toIso8601String(),
      'completedAt': completedAt?.toIso8601String(),
      'cancelledAt': cancelledAt?.toIso8601String(),
      'cancellationReason': cancellationReason,
    };
  }

  factory RequestCategoryFulfillment.fromJson(Map<String, dynamic> json) {
    return RequestCategoryFulfillment(
      categoryNormalized: json['categoryNormalized'] as String,
      status: RequestCategoryStatus.values.firstWhere(
        (s) => s.name == json['status'],
        orElse: () => RequestCategoryStatus.pending,
      ),
      acceptedProposalId: json['acceptedProposalId'] as String?,
      acceptedVendorId: json['acceptedVendorId'] as String?,
      acceptedAt: json['acceptedAt'] != null
          ? DateTime.tryParse(json['acceptedAt'] as String)
          : null,
      codConfirmedAt: json['codConfirmedAt'] != null
          ? DateTime.tryParse(json['codConfirmedAt'] as String)
          : null,
      paidAt: json['paidAt'] != null
          ? DateTime.tryParse(json['paidAt'] as String)
          : null,
      completedAt: json['completedAt'] != null
          ? DateTime.tryParse(json['completedAt'] as String)
          : null,
      cancelledAt: json['cancelledAt'] != null
          ? DateTime.tryParse(json['cancelledAt'] as String)
          : null,
      cancellationReason: json['cancellationReason'] as String?,
    );
  }
}

