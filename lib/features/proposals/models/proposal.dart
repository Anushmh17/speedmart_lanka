enum ProposalStatus {
  pending,
  submitted,
  accepted,
  rejected,
  expired,
  cancelled
}

extension ProposalStatusExtension on ProposalStatus {
  String get displayName {
    switch (this) {
      case ProposalStatus.pending:
        return 'Pending';
      case ProposalStatus.submitted:
        return 'Submitted';
      case ProposalStatus.accepted:
        return 'Accepted';
      case ProposalStatus.rejected:
        return 'Rejected';
      case ProposalStatus.expired:
        return 'Expired';
      case ProposalStatus.cancelled:
        return 'Cancelled';
    }
  }
}

enum ProposalItemStatus {
  available,
  unavailable,
  alternative
}

class ProposalItem {
  final String requestItemId;
  final String requestItemName;
  final int quantity;
  final ProposalItemStatus status;
  final double price; // unit price
  final String? description;
  
  // Alternative product details if status is alternative
  final String? alternativeName;
  final String? alternativeBrand;
  final String? alternativeReason;
  final String? imageUrl;

  ProposalItem({
    required this.requestItemId,
    required this.requestItemName,
    required this.quantity,
    required this.status,
    this.price = 0.0,
    this.description,
    this.alternativeName,
    this.alternativeBrand,
    this.alternativeReason,
    this.imageUrl,
  });

  double get totalPrice => status == ProposalItemStatus.unavailable ? 0.0 : price * quantity;
}

class Proposal {
  final String id;
  final String requestId;
  final String vendorId;
  final String vendorBusinessName;
  final List<ProposalItem> items;
  final List<String> missingItemIds;
  final double deliveryCharge;
  final String estimatedDeliveryTime;
  final double totalPrice; // Sum of available + alternative items + delivery charge
  final ProposalStatus status;
  final DateTime createdAt;
  final String? rejectionReason;
  final String? customerResponse; // suggested response
  final String? vendorResponse; // suggested response
  final double vendorLatitude;
  final double vendorLongitude;

  Proposal({
    required this.id,
    required this.requestId,
    required this.vendorId,
    required this.vendorBusinessName,
    required this.items,
    this.missingItemIds = const [],
    required this.deliveryCharge,
    required this.estimatedDeliveryTime,
    required this.totalPrice,
    this.status = ProposalStatus.submitted,
    required this.createdAt,
    this.rejectionReason,
    this.customerResponse,
    this.vendorResponse,
    this.vendorLatitude = 6.9145,
    this.vendorLongitude = 79.8510,
  });

  Proposal copyWith({
    String? id,
    String? requestId,
    String? vendorId,
    String? vendorBusinessName,
    List<ProposalItem>? items,
    List<String>? missingItemIds,
    double? deliveryCharge,
    String? estimatedDeliveryTime,
    double? totalPrice,
    ProposalStatus? status,
    DateTime? createdAt,
    String? rejectionReason,
    String? customerResponse,
    String? vendorResponse,
    double? vendorLatitude,
    double? vendorLongitude,
  }) {
    return Proposal(
      id: id ?? this.id,
      requestId: requestId ?? this.requestId,
      vendorId: vendorId ?? this.vendorId,
      vendorBusinessName: vendorBusinessName ?? this.vendorBusinessName,
      items: items ?? this.items,
      missingItemIds: missingItemIds ?? this.missingItemIds,
      deliveryCharge: deliveryCharge ?? this.deliveryCharge,
      estimatedDeliveryTime: estimatedDeliveryTime ?? this.estimatedDeliveryTime,
      totalPrice: totalPrice ?? this.totalPrice,
      status: status ?? this.status,
      createdAt: createdAt ?? this.createdAt,
      rejectionReason: rejectionReason ?? this.rejectionReason,
      customerResponse: customerResponse ?? this.customerResponse,
      vendorResponse: vendorResponse ?? this.vendorResponse,
      vendorLatitude: vendorLatitude ?? this.vendorLatitude,
      vendorLongitude: vendorLongitude ?? this.vendorLongitude,
    );
  }
}
