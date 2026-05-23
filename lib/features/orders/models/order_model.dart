import '../../proposals/models/proposal.dart';

enum PaymentMethod {
  cashOnDelivery,
  cardPayment
}

extension PaymentMethodExtension on PaymentMethod {
  String get displayName {
    switch (this) {
      case PaymentMethod.cashOnDelivery:
        return 'Cash on Delivery';
      case PaymentMethod.cardPayment:
        return 'Card Payment';
    }
  }
}

enum PaymentStatus {
  pending,
  paid,
  failed
}

enum OrderStatus {
  preparing,
  outForDelivery,
  delivered,
  cancelled
}

extension OrderStatusExtension on OrderStatus {
  String get displayName {
    switch (this) {
      case OrderStatus.preparing:
        return 'Preparing Order';
      case OrderStatus.outForDelivery:
        return 'Out for Delivery';
      case OrderStatus.delivered:
        return 'Delivered';
      case OrderStatus.cancelled:
        return 'Cancelled';
    }
  }
}

class OrderModel {
  final String id;
  final String proposalId;
  final String requestId;
  final String customerId;
  final String vendorId;
  
  // Confirmed Revealed Contact Info (Anti-bypass & Reveal logic)
  final String vendorBusinessName;
  final String vendorPhone;
  final String customerName;
  final String customerPhone;
  final String deliveryAddress;

  final List<ProposalItem> items;
  final double deliveryCharge;
  final double totalPrice;
  final PaymentMethod paymentMethod;
  final PaymentStatus paymentStatus;
  final OrderStatus status;
  final DateTime createdAt;
  final DateTime? updatedAt;
  final double vendorLatitude;
  final double vendorLongitude;
  final double customerLatitude;
  final double customerLongitude;

  OrderModel({
    required this.id,
    required this.proposalId,
    required this.requestId,
    required this.customerId,
    required this.vendorId,
    required this.vendorBusinessName,
    required this.vendorPhone,
    required this.customerName,
    required this.customerPhone,
    required this.deliveryAddress,
    required this.items,
    required this.deliveryCharge,
    required this.totalPrice,
    required this.paymentMethod,
    this.paymentStatus = PaymentStatus.pending,
    this.status = OrderStatus.preparing,
    required this.createdAt,
    this.updatedAt,
    this.vendorLatitude = 0.0,
    this.vendorLongitude = 0.0,
    this.customerLatitude = 0.0,
    this.customerLongitude = 0.0,
  });

  OrderModel copyWith({
    String? id,
    String? proposalId,
    String? requestId,
    String? customerId,
    String? vendorId,
    String? vendorBusinessName,
    String? vendorPhone,
    String? customerName,
    String? customerPhone,
    String? deliveryAddress,
    List<ProposalItem>? items,
    double? deliveryCharge,
    double? totalPrice,
    PaymentMethod? paymentMethod,
    PaymentStatus? paymentStatus,
    OrderStatus? status,
    DateTime? createdAt,
    DateTime? updatedAt,
    double? vendorLatitude,
    double? vendorLongitude,
    double? customerLatitude,
    double? customerLongitude,
  }) {
    return OrderModel(
      id: id ?? this.id,
      proposalId: proposalId ?? this.proposalId,
      requestId: requestId ?? this.requestId,
      customerId: customerId ?? this.customerId,
      vendorId: vendorId ?? this.vendorId,
      vendorBusinessName: vendorBusinessName ?? this.vendorBusinessName,
      vendorPhone: vendorPhone ?? this.vendorPhone,
      customerName: customerName ?? this.customerName,
      customerPhone: customerPhone ?? this.customerPhone,
      deliveryAddress: deliveryAddress ?? this.deliveryAddress,
      items: items ?? this.items,
      deliveryCharge: deliveryCharge ?? this.deliveryCharge,
      totalPrice: totalPrice ?? this.totalPrice,
      paymentMethod: paymentMethod ?? this.paymentMethod,
      paymentStatus: paymentStatus ?? this.paymentStatus,
      status: status ?? this.status,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      vendorLatitude: vendorLatitude ?? this.vendorLatitude,
      vendorLongitude: vendorLongitude ?? this.vendorLongitude,
      customerLatitude: customerLatitude ?? this.customerLatitude,
      customerLongitude: customerLongitude ?? this.customerLongitude,
    );
  }

  /// TODO: Replace local mock order persistence with backend API.
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'proposalId': proposalId,
      'requestId': requestId,
      'customerId': customerId,
      'vendorId': vendorId,
      'vendorBusinessName': vendorBusinessName,
      'vendorPhone': vendorPhone,
      'customerName': customerName,
      'customerPhone': customerPhone,
      'deliveryAddress': deliveryAddress,
      'items': items.map((i) => i.toJson()).toList(),
      'deliveryCharge': deliveryCharge,
      'totalPrice': totalPrice,
      'paymentMethod': paymentMethod.name,
      'paymentStatus': paymentStatus.name,
      'status': status.name,
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt?.toIso8601String(),
      'vendorLatitude': vendorLatitude,
      'vendorLongitude': vendorLongitude,
      'customerLatitude': customerLatitude,
      'customerLongitude': customerLongitude,
    };
  }

  factory OrderModel.fromJson(Map<String, dynamic> json) {
    return OrderModel(
      id: json['id'] as String? ?? '',
      proposalId: json['proposalId'] as String? ?? '',
      requestId: json['requestId'] as String? ?? '',
      customerId: json['customerId'] as String? ?? '',
      vendorId: json['vendorId'] as String? ?? '',
      vendorBusinessName: json['vendorBusinessName'] as String? ?? '',
      vendorPhone: json['vendorPhone'] as String? ?? '',
      customerName: json['customerName'] as String? ?? '',
      customerPhone: json['customerPhone'] as String? ?? '',
      deliveryAddress: json['deliveryAddress'] as String? ?? '',
      items: (json['items'] as List<dynamic>? ?? [])
          .map((e) => ProposalItem.fromJson(Map<String, dynamic>.from(e as Map)))
          .toList(),
      deliveryCharge: (json['deliveryCharge'] as num?)?.toDouble() ?? 0.0,
      totalPrice: (json['totalPrice'] as num?)?.toDouble() ?? 0.0,
      paymentMethod: PaymentMethod.values.firstWhere(
        (m) => m.name == json['paymentMethod'],
        orElse: () => PaymentMethod.cashOnDelivery,
      ),
      paymentStatus: PaymentStatus.values.firstWhere(
        (s) => s.name == json['paymentStatus'],
        orElse: () => PaymentStatus.pending,
      ),
      status: OrderStatus.values.firstWhere(
        (s) => s.name == json['status'],
        orElse: () => OrderStatus.preparing,
      ),
      createdAt: DateTime.tryParse(json['createdAt'] as String? ?? '') ??
          DateTime.now(),
      updatedAt: json['updatedAt'] != null
          ? DateTime.tryParse(json['updatedAt'] as String)
          : null,
      vendorLatitude: (json['vendorLatitude'] as num?)?.toDouble() ?? 0.0,
      vendorLongitude: (json['vendorLongitude'] as num?)?.toDouble() ?? 0.0,
      customerLatitude: (json['customerLatitude'] as num?)?.toDouble() ?? 0.0,
      customerLongitude: (json['customerLongitude'] as num?)?.toDouble() ?? 0.0,
    );
  }
}
