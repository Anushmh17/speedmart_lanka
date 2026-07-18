enum ProposalStatus {
  draft,
  submitted,
  updated,
  withdrawn,
  accepted,
  rejected,
  expired,
}

extension ProposalStatusExtension on ProposalStatus {
  String get displayName {
    switch (this) {
      case ProposalStatus.draft:
        return 'Draft';
      case ProposalStatus.submitted:
        return 'Submitted';
      case ProposalStatus.updated:
        return 'Updated';
      case ProposalStatus.withdrawn:
        return 'Withdrawn';
      case ProposalStatus.accepted:
        return 'Accepted';
      case ProposalStatus.rejected:
        return 'Rejected';
      case ProposalStatus.expired:
        return 'Expired';
    }
  }

  bool get isEditableByVendor {
    return this == ProposalStatus.draft ||
        this == ProposalStatus.submitted ||
        this == ProposalStatus.updated;
  }

  bool get isVisibleToCustomer {
    return this == ProposalStatus.submitted ||
        this == ProposalStatus.updated ||
        this == ProposalStatus.accepted ||
        this == ProposalStatus.rejected;
  }
}

enum ProposalItemStatus {
  available,
  unavailable,
  alternative,
}

/// Customer decision on a specific ProposalItem.
enum ProposalItemDecision {
  pending,
  accepted,
  rejected,
}

class ProposalItem {
  final String id;
  final String requestItemId;
  final String requestItemName;
  final String itemName;
  final int quantity;
  final ProposalItemStatus status;
  final double price;
  final String? offeredBrandModel;
  final int? availableStock;
  final String? description;
  final String? alternativeName;
  final String? alternativeBrand;
  final String? alternativeReason;
  final String? imageUrl;
  final List<String> vendorImageUrls;
  final ProposalItemDecision customerDecision;

  ProposalItem({
    String? id,
    required this.requestItemId,
    String? requestItemName,
    String? itemName,
    required this.quantity,
    required this.status,
    this.price = 0.0,
    this.offeredBrandModel,
    this.availableStock,
    this.description,
    this.alternativeName,
    this.alternativeBrand,
    this.alternativeReason,
    this.imageUrl,
    this.vendorImageUrls = const [],
    this.customerDecision = ProposalItemDecision.pending,
  })  : id = (id != null && id.isNotEmpty) ? id : requestItemId,
        requestItemName = requestItemName ?? itemName ?? '',
        itemName = itemName ?? requestItemName ?? '';

  double get unitPrice => price;

  double get subtotal =>
      status == ProposalItemStatus.unavailable ? 0.0 : price * quantity;

  double get totalPrice => subtotal;

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'requestItemId': requestItemId,
      'requestItemName': requestItemName,
      'itemName': itemName,
      'quantity': quantity,
      'status': status.name,
      'price': price,
      'offeredBrandModel': offeredBrandModel,
      'availableStock': availableStock,
      'description': description,
      'alternativeName': alternativeName,
      'alternativeBrand': alternativeBrand,
      'alternativeReason': alternativeReason,
      'imageUrl': imageUrl,
      'vendorImageUrls': vendorImageUrls,
      'customerDecision': customerDecision.name,
    };
  }

  factory ProposalItem.fromJson(Map<String, dynamic> json) {
    final name = json['itemName'] as String? ??
        json['requestItemName'] as String? ??
        '';
    return ProposalItem(
      id: json['id'] as String? ??
          json['proposalItemId'] as String? ??
          json['requestItemId'] as String? ??
          '',
      requestItemId: json['requestItemId'] as String? ?? '',
      requestItemName: name,
      itemName: name,
      quantity: json['quantity'] as int? ?? 1,
      status: ProposalItemStatus.values.firstWhere(
        (s) => s.name == json['status'],
        orElse: () => ProposalItemStatus.available,
      ),
      price: (json['price'] as num?)?.toDouble() ?? 0.0,
      offeredBrandModel: json['offeredBrandModel'] as String? ??
          json['alternativeBrand'] as String?,
      availableStock: json['availableStock'] as int?,
      description: json['description'] as String?,
      alternativeName: json['alternativeName'] as String?,
      alternativeBrand: json['alternativeBrand'] as String?,
      alternativeReason: json['alternativeReason'] as String?,
      imageUrl: json['imageUrl'] as String?,
      vendorImageUrls: (json['vendorImageUrls'] as List<dynamic>? ?? []).map((e) => e.toString()).toList(),
      customerDecision: ProposalItemDecision.values.firstWhere(
        (d) => d.name == json['customerDecision'],
        orElse: () => ProposalItemDecision.pending,
      ),
    );
  }

  ProposalItem copyWith({
    String? id,
    String? requestItemId,
    String? requestItemName,
    String? itemName,
    int? quantity,
    ProposalItemStatus? status,
    double? price,
    String? offeredBrandModel,
    int? availableStock,
    String? description,
    String? alternativeName,
    String? alternativeBrand,
    String? alternativeReason,
    String? imageUrl,
    List<String>? vendorImageUrls,
    ProposalItemDecision? customerDecision,
  }) {
    return ProposalItem(
      id: id ?? this.id,
      requestItemId: requestItemId ?? this.requestItemId,
      requestItemName: requestItemName ?? this.requestItemName,
      itemName: itemName ?? this.itemName,
      quantity: quantity ?? this.quantity,
      status: status ?? this.status,
      price: price ?? this.price,
      offeredBrandModel: offeredBrandModel ?? this.offeredBrandModel,
      availableStock: availableStock ?? this.availableStock,
      description: description ?? this.description,
      alternativeName: alternativeName ?? this.alternativeName,
      alternativeBrand: alternativeBrand ?? this.alternativeBrand,
      alternativeReason: alternativeReason ?? this.alternativeReason,
      imageUrl: imageUrl ?? this.imageUrl,
      vendorImageUrls: vendorImageUrls ?? this.vendorImageUrls,
      customerDecision: customerDecision ?? this.customerDecision,
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
  final double totalPrice;
  final ProposalStatus status;
  final DateTime createdAt;
  final DateTime? updatedAt;
  final DateTime? rejectedAt;
  final String? notes;
  final List<String> productImageUrls;
  final String? rejectionReason;
  final String? customerResponse;
  final String? vendorResponse;
  final double vendorLatitude;
  final double vendorLongitude;
  
  // Category-specific proposal tracking (for multi-category requests)
  final String? categoryNormalized; // The specific category this proposal addresses

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
    this.updatedAt,
    this.rejectedAt,
    this.notes,
    this.productImageUrls = const [],
    this.rejectionReason,
    this.customerResponse,
    this.vendorResponse,
    this.vendorLatitude = 6.9145,
    this.vendorLongitude = 79.8510,
    this.categoryNormalized,
  });

  double get subtotal => items.fold<double>(0, (sum, i) => sum + i.subtotal);

  double get deliveryFee => deliveryCharge;

  bool get canEdit => status.isEditableByVendor;

  bool get canWithdraw => status.isEditableByVendor;

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
    DateTime? updatedAt,
    DateTime? rejectedAt,
    String? notes,
    List<String>? productImageUrls,
    String? rejectionReason,
    String? customerResponse,
    String? vendorResponse,
    double? vendorLatitude,
    double? vendorLongitude,
    String? categoryNormalized,
  }) {
    return Proposal(
      id: id ?? this.id,
      requestId: requestId ?? this.requestId,
      vendorId: vendorId ?? this.vendorId,
      vendorBusinessName: vendorBusinessName ?? this.vendorBusinessName,
      items: items ?? this.items,
      missingItemIds: missingItemIds ?? this.missingItemIds,
      deliveryCharge: deliveryCharge ?? this.deliveryCharge,
      estimatedDeliveryTime:
          estimatedDeliveryTime ?? this.estimatedDeliveryTime,
      totalPrice: totalPrice ?? this.totalPrice,
      status: status ?? this.status,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      rejectedAt: rejectedAt ?? this.rejectedAt,
      notes: notes ?? this.notes,
      productImageUrls: productImageUrls ?? this.productImageUrls,
      rejectionReason: rejectionReason ?? this.rejectionReason,
      customerResponse: customerResponse ?? this.customerResponse,
      vendorResponse: vendorResponse ?? this.vendorResponse,
      vendorLatitude: vendorLatitude ?? this.vendorLatitude,
      vendorLongitude: vendorLongitude ?? this.vendorLongitude,
      categoryNormalized: categoryNormalized ?? this.categoryNormalized,
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
      'updatedAt': updatedAt?.toIso8601String(),
      'rejectedAt': rejectedAt?.toIso8601String(),
      'notes': notes,
      'productImageUrls': productImageUrls,
      'rejectionReason': rejectionReason,
      'customerResponse': customerResponse,
      'vendorResponse': vendorResponse,
      'vendorLatitude': vendorLatitude,
      'vendorLongitude': vendorLongitude,
      'categoryNormalized': categoryNormalized,
    };
  }

  static ProposalStatus _parseStatus(String? raw) {
    switch (raw) {
      case 'pending':
        return ProposalStatus.draft;
      case 'cancelled':
        return ProposalStatus.withdrawn;
      default:
        return ProposalStatus.values.firstWhere(
          (s) => s.name == raw,
          orElse: () => ProposalStatus.submitted,
        );
    }
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
      status: _parseStatus(json['status'] as String?),
      createdAt: DateTime.tryParse(json['createdAt'] as String? ?? '') ??
          DateTime.now(),
      updatedAt: json['updatedAt'] != null
          ? DateTime.tryParse(json['updatedAt'] as String)
          : null,
      rejectedAt: json['rejectedAt'] != null
          ? DateTime.tryParse(json['rejectedAt'] as String)
          : null,
      notes: json['notes'] as String?,
      productImageUrls: (json['productImageUrls'] as List<dynamic>? ?? [])
          .map((e) => e.toString())
          .toList(),
      rejectionReason: json['rejectionReason'] as String?,
      customerResponse: json['customerResponse'] as String?,
      vendorResponse: json['vendorResponse'] as String?,
      vendorLatitude: (json['vendorLatitude'] as num?)?.toDouble() ?? 6.9145,
      vendorLongitude: (json['vendorLongitude'] as num?)?.toDouble() ?? 79.8510,
      categoryNormalized: json['categoryNormalized'] as String?,
    );
  }
}

