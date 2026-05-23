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

  Map<String, dynamic> toJson() {
    return {
      'requestItemId': requestItemId,
      'requestItemName': requestItemName,
      'quantity': quantity,
      'status': status.name,
      'price': price,
      'description': description,
      'alternativeName': alternativeName,
      'alternativeBrand': alternativeBrand,
      'alternativeReason': alternativeReason,
      'imageUrl': imageUrl,
    };
  }

  factory ProposalItem.fromJson(Map<String, dynamic> json) {
    return ProposalItem(
      requestItemId: json['requestItemId'] as String? ?? '',
      requestItemName: json['requestItemName'] as String? ?? '',
      quantity: json['quantity'] as int? ?? 1,
      status: ProposalItemStatus.values.firstWhere(
        (s) => s.name == json['status'],
        orElse: () => ProposalItemStatus.available,
      ),
      price: (json['price'] as num?)?.toDouble() ?? 0.0,
      description: json['description'] as String?,
      alternativeName: json['alternativeName'] as String?,
      alternativeBrand: json['alternativeBrand'] as String?,
      alternativeReason: json['alternativeReason'] as String?,
      imageUrl: json['imageUrl'] as String?,
    );
  }
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

  /// TODO: Replace local mock proposal persistence with backend API.
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'requestId': requestId,
      'vendorId': vendorId,
      'vendorBusinessName': vendorBusinessName,
      'items': items.map((i) => i.toJson()).toList(),
      'missingItemIds': missingItemIds,
      'deliveryCharge': deliveryCharge,
      'estimatedDeliveryTime': estimatedDeliveryTime,
      'totalPrice': totalPrice,
      'status': status.name,
      'createdAt': createdAt.toIso8601String(),
      'rejectionReason': rejectionReason,
      'customerResponse': customerResponse,
      'vendorResponse': vendorResponse,
      'vendorLatitude': vendorLatitude,
      'vendorLongitude': vendorLongitude,
    };
  }

  factory Proposal.fromJson(Map<String, dynamic> json) {
    return Proposal(
      id: json['id'] as String? ?? '',
      requestId: json['requestId'] as String? ?? '',
      vendorId: json['vendorId'] as String? ?? '',
      vendorBusinessName: json['vendorBusinessName'] as String? ?? '',
      items: (json['items'] as List<dynamic>? ?? [])
          .map((e) => ProposalItem.fromJson(Map<String, dynamic>.from(e as Map)))
          .toList(),
      missingItemIds: (json['missingItemIds'] as List<dynamic>? ?? [])
          .map((e) => e.toString())
          .toList(),
      deliveryCharge: (json['deliveryCharge'] as num?)?.toDouble() ?? 0.0,
      estimatedDeliveryTime: json['estimatedDeliveryTime'] as String? ?? '',
      totalPrice: (json['totalPrice'] as num?)?.toDouble() ?? 0.0,
      status: ProposalStatus.values.firstWhere(
        (s) => s.name == json['status'],
        orElse: () => ProposalStatus.submitted,
      ),
      createdAt: DateTime.tryParse(json['createdAt'] as String? ?? '') ??
          DateTime.now(),
      rejectionReason: json['rejectionReason'] as String?,
      customerResponse: json['customerResponse'] as String?,
      vendorResponse: json['vendorResponse'] as String?,
      vendorLatitude: (json['vendorLatitude'] as num?)?.toDouble() ?? 6.9145,
      vendorLongitude: (json['vendorLongitude'] as num?)?.toDouble() ?? 79.8510,
    );
  }
}
