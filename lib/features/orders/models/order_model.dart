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
    this.vendorLatitude = 6.9145,
    this.vendorLongitude = 79.8510,
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
    );
  }
}
