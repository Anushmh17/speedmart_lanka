import 'package:flutter/foundation.dart';

enum PaymentMethod {
  cashOnDelivery,
  mockOnline,
  bankTransfer,
  cardPlaceholder,
}

extension PaymentMethodExtension on PaymentMethod {
  String get displayName {
    switch (this) {
      case PaymentMethod.cashOnDelivery:
        return 'Cash on Delivery';
      case PaymentMethod.mockOnline:
        return 'Mock Online Payment';
      case PaymentMethod.bankTransfer:
        return 'Bank Transfer (Placeholder)';
      case PaymentMethod.cardPlaceholder:
        return 'Card Payment (Placeholder)';
    }
  }
}

enum PaymentStatus {
  pending,
  pendingOnDelivery, // COD payment pending until delivery
  paid,
  failed,
  refunded,
  cancelled,
}

extension PaymentStatusExtension on PaymentStatus {
  String get displayName {
    switch (this) {
      case PaymentStatus.pending:
        return 'Pending';
      case PaymentStatus.pendingOnDelivery:
        return 'Pending on Delivery';
      case PaymentStatus.paid:
        return 'Paid';
      case PaymentStatus.failed:
        return 'Failed';
      case PaymentStatus.refunded:
        return 'Refunded';
      case PaymentStatus.cancelled:
        return 'Cancelled';
    }
  }
}

class PaymentModel {
  final String id;
  final String orderId;
  final String customerId;
  final String vendorId;
  final String vendorBusinessName;
  final String proposalId;
  final double amount; // Customer pays: subtotal + delivery
  final double subtotal; // Items total
  final double deliveryFee; // Delivery cost
  final double serviceFee; // DEPRECATED: kept for compatibility, use platformCommission
  final double platformCommission; // Commission earned by platform (typically 20%)
  final double vendorNetAmount; // Amount vendor receives: subtotal + delivery - commission
  final PaymentMethod paymentMethod;
  final PaymentStatus paymentStatus;
  final DateTime? paidAt;
  final DateTime createdAt;
  final String transactionReference;
  final String receiptNumber;

  const PaymentModel({
    required this.id,
    required this.orderId,
    required this.customerId,
    required this.vendorId,
    required this.vendorBusinessName,
    required this.proposalId,
    required this.amount,
    required this.subtotal,
    required this.deliveryFee,
    required this.serviceFee,
    this.platformCommission = 0.0,
    this.vendorNetAmount = 0.0,
    required this.paymentMethod,
    this.paymentStatus = PaymentStatus.pending,
    this.paidAt,
    required this.createdAt,
    this.transactionReference = '',
    required this.receiptNumber,
  });

  PaymentModel copyWith({
    String? id,
    String? orderId,
    String? customerId,
    String? vendorId,
    String? vendorBusinessName,
    String? proposalId,
    double? amount,
    double? subtotal,
    double? deliveryFee,
    double? serviceFee,
    double? platformCommission,
    double? vendorNetAmount,
    PaymentMethod? paymentMethod,
    PaymentStatus? paymentStatus,
    DateTime? paidAt,
    DateTime? createdAt,
    String? transactionReference,
    String? receiptNumber,
  }) {
    return PaymentModel(
      id: id ?? this.id,
      orderId: orderId ?? this.orderId,
      customerId: customerId ?? this.customerId,
      vendorId: vendorId ?? this.vendorId,
      vendorBusinessName: vendorBusinessName ?? this.vendorBusinessName,
      proposalId: proposalId ?? this.proposalId,
      amount: amount ?? this.amount,
      subtotal: subtotal ?? this.subtotal,
      deliveryFee: deliveryFee ?? this.deliveryFee,
      serviceFee: serviceFee ?? this.serviceFee,
      platformCommission: platformCommission ?? this.platformCommission,
      vendorNetAmount: vendorNetAmount ?? this.vendorNetAmount,
      paymentMethod: paymentMethod ?? this.paymentMethod,
      paymentStatus: paymentStatus ?? this.paymentStatus,
      paidAt: paidAt ?? this.paidAt,
      createdAt: createdAt ?? this.createdAt,
      transactionReference: transactionReference ?? this.transactionReference,
      receiptNumber: receiptNumber ?? this.receiptNumber,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'orderId': orderId,
      'customerId': customerId,
      'vendorId': vendorId,
      'vendorBusinessName': vendorBusinessName,
      'proposalId': proposalId,
      'amount': amount,
      'subtotal': subtotal,
      'deliveryFee': deliveryFee,
      'serviceFee': serviceFee,
      'platformCommission': platformCommission,
      'vendorNetAmount': vendorNetAmount,
      'paymentMethod': paymentMethod.name,
      'paymentStatus': paymentStatus.name,
      'paidAt': paidAt?.toIso8601String(),
      'createdAt': createdAt.toIso8601String(),
      'transactionReference': transactionReference,
      'receiptNumber': receiptNumber,
    };
  }

  factory PaymentModel.fromJson(Map<String, dynamic> json) {
    return PaymentModel(
      id: json['id'] as String? ?? '',
      orderId: json['orderId'] as String? ?? '',
      customerId: json['customerId'] as String? ?? '',
      vendorId: json['vendorId'] as String? ?? '',
      proposalId: json['proposalId'] as String? ?? '',
      amount: (json['amount'] as num?)?.toDouble() ?? 0.0,
      subtotal: (json['subtotal'] as num?)?.toDouble() ?? 0.0,
      deliveryFee: (json['deliveryFee'] as num?)?.toDouble() ?? 0.0,
      serviceFee: (json['serviceFee'] as num?)?.toDouble() ?? 0.0,
      platformCommission: (json['platformCommission'] as num?)?.toDouble() ?? 0.0,
      vendorNetAmount: (json['vendorNetAmount'] as num?)?.toDouble() ?? 0.0,
      paymentMethod: PaymentMethod.values.firstWhere(
        (m) => m.name == json['paymentMethod'],
        orElse: () => PaymentMethod.cashOnDelivery,
      ),
      paymentStatus: PaymentStatus.values.firstWhere(
        (s) => s.name == json['paymentStatus'],
        orElse: () => PaymentStatus.pending,
      ),
      vendorBusinessName: json['vendorBusinessName'] as String? ?? '',
      paidAt: json['paidAt'] != null
          ? DateTime.tryParse(json['paidAt'] as String)
          : null,
      createdAt: DateTime.tryParse(json['createdAt'] as String? ?? '') ?? DateTime.now(),
      transactionReference: json['transactionReference'] as String? ?? '',
      receiptNumber: json['receiptNumber'] as String? ?? '',
    );
  }
}

