import '../../payments/models/payment.dart';
import '../../proposals/models/proposal.dart';

enum OrderStatus {
  submitted,
  accepted,
  preparing,
  readyForDelivery,
  outForDelivery,
  delivered,
  completed,
  cancelled,
}

extension OrderStatusExtension on OrderStatus {
  String get displayName {
    switch (this) {
      case OrderStatus.submitted:
        return 'Order Submitted';
      case OrderStatus.accepted:
        return 'Accepted by Shop Owner';
      case OrderStatus.preparing:
        return 'Preparing Order';
      case OrderStatus.readyForDelivery:
        return 'Ready for Delivery';
      case OrderStatus.outForDelivery:
        return 'Out for Delivery';
      case OrderStatus.delivered:
        return 'Delivered';
      case OrderStatus.completed:
        return 'Completed';
      case OrderStatus.cancelled:
        return 'Cancelled';
    }
  }

  String get statusIcon {
    switch (this) {
      case OrderStatus.submitted:
        return '📝';
      case OrderStatus.accepted:
        return '✅';
      case OrderStatus.preparing:
        return '📦';
      case OrderStatus.readyForDelivery:
        return '🚀';
      case OrderStatus.outForDelivery:
        return '🛵';
      case OrderStatus.delivered:
        return '📍';
      case OrderStatus.completed:
        return '🎉';
      case OrderStatus.cancelled:
        return '❌';
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
  final String? paymentId;
  final PaymentMethod paymentMethod;
  final PaymentStatus paymentStatus;
  final bool isAddressReleased;
  final DateTime? addressReleasedAt;
  final OrderStatus status;
  final DateTime createdAt;
  final DateTime? updatedAt;
  final double vendorLatitude;
  final double vendorLongitude;
  final double customerLatitude;
  final double customerLongitude;
  final double? accuracy;
  final DateTime? detectedAt;

  /// Snapshotted at order creation from the vendor's admin-set commission rate.
  final double commissionRate;

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
    this.paymentId,
    required this.paymentMethod,
    this.paymentStatus = PaymentStatus.pending,
    this.isAddressReleased = false,
    this.addressReleasedAt,
    this.status = OrderStatus.submitted,
    required this.createdAt,
    this.updatedAt,
    this.vendorLatitude = 0.0,
    this.vendorLongitude = 0.0,
    this.customerLatitude = 0.0,
    this.customerLongitude = 0.0,
    this.accuracy,
    this.detectedAt,
    this.commissionRate = 0.0,
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
    String? paymentId,
    PaymentMethod? paymentMethod,
    PaymentStatus? paymentStatus,
    bool? isAddressReleased,
    DateTime? addressReleasedAt,
    OrderStatus? status,
    DateTime? createdAt,
    DateTime? updatedAt,
    double? vendorLatitude,
    double? vendorLongitude,
    double? customerLatitude,
    double? customerLongitude,
    double? accuracy,
    DateTime? detectedAt,
    double? commissionRate,
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
      paymentId: paymentId ?? this.paymentId,
      paymentMethod: paymentMethod ?? this.paymentMethod,
      paymentStatus: paymentStatus ?? this.paymentStatus,
      isAddressReleased: isAddressReleased ?? this.isAddressReleased,
      addressReleasedAt: addressReleasedAt ?? this.addressReleasedAt,
      status: status ?? this.status,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      vendorLatitude: vendorLatitude ?? this.vendorLatitude,
      vendorLongitude: vendorLongitude ?? this.vendorLongitude,
      customerLatitude: customerLatitude ?? this.customerLatitude,
      customerLongitude: customerLongitude ?? this.customerLongitude,
      accuracy: accuracy ?? this.accuracy,
      detectedAt: detectedAt ?? this.detectedAt,
      commissionRate: commissionRate ?? this.commissionRate,
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
      'paymentId': paymentId,
      'paymentMethod': paymentMethod.name,
      'paymentStatus': paymentStatus.name,
      'isAddressReleased': isAddressReleased,
      'addressReleasedAt': addressReleasedAt?.toIso8601String(),
      'status': status.name,
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt?.toIso8601String(),
      'vendorLatitude': vendorLatitude,
      'vendorLongitude': vendorLongitude,
      'customerLatitude': customerLatitude,
      'customerLongitude': customerLongitude,
      'accuracy': accuracy,
      'detectedAt': detectedAt?.toIso8601String(),
      'commissionRate': commissionRate,
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
      paymentId: json['paymentId'] as String?,
      paymentMethod: PaymentMethod.values.firstWhere(
        (m) => m.name == json['paymentMethod'],
        orElse: () => PaymentMethod.cashOnDelivery,
      ),
      paymentStatus: PaymentStatus.values.firstWhere(
        (s) => s.name == json['paymentStatus'],
        orElse: () => PaymentStatus.pending,
      ),
      isAddressReleased: json['isAddressReleased'] as bool? ?? false,
      addressReleasedAt: json['addressReleasedAt'] != null
          ? DateTime.tryParse(json['addressReleasedAt'] as String)
          : null,
      status: OrderStatus.values.firstWhere(
        (s) => s.name == json['status'],
        orElse: () => OrderStatus.submitted,
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
      accuracy: (json['accuracy'] as num?)?.toDouble(),
      detectedAt: json['detectedAt'] != null ? DateTime.tryParse(json['detectedAt'] as String) : null,
      commissionRate: (json['commissionRate'] as num?)?.toDouble() ?? 0.0,
    );
  }
}

