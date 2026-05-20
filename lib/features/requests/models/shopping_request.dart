import '../../location/models/delivery_location.dart';
import 'request_item.dart';

enum RequestStatus {
  draft,
  submitted,
  waitingForVendor,
  vendorAccepted,
  proposalSubmitted,
  customerAccepted,
  customerRejected,
  paymentPending,
  paid,
  cashOnDeliveryConfirmed,
  preparingOrder,
  outForDelivery,
  delivered,
  cancelled,
  expired
}

extension RequestStatusExtension on RequestStatus {
  String get displayName {
    switch (this) {
      case RequestStatus.draft:
        return 'Draft';
      case RequestStatus.submitted:
        return 'Submitted';
      case RequestStatus.waitingForVendor:
        return 'Waiting for Vendor';
      case RequestStatus.vendorAccepted:
        return 'Vendor Accepted';
      case RequestStatus.proposalSubmitted:
        return 'Proposal Submitted';
      case RequestStatus.customerAccepted:
        return 'Accepted by Customer';
      case RequestStatus.customerRejected:
        return 'Rejected by Customer';
      case RequestStatus.paymentPending:
        return 'Payment Pending';
      case RequestStatus.paid:
        return 'Paid';
      case RequestStatus.cashOnDeliveryConfirmed:
        return 'COD Confirmed';
      case RequestStatus.preparingOrder:
        return 'Preparing Order';
      case RequestStatus.outForDelivery:
        return 'Out for Delivery';
      case RequestStatus.delivered:
        return 'Delivered';
      case RequestStatus.cancelled:
        return 'Cancelled';
      case RequestStatus.expired:
        return 'Expired';
    }
  }
}

class ShoppingRequest {
  final String id;
  final String customerId;
  final List<RequestItem> items;
  final RequestStatus status;
  final DateTime createdAt;
  final DateTime? updatedAt;
  final String customerArea;
  final String deliveryAddress;
  final String customerPhone;
  final String customerName;
  final double approximateDistance;
  final double latitude;
  final double longitude;
  final DeliveryLocation? deliveryLocation;

  ShoppingRequest({
    required this.id,
    required this.customerId,
    required this.items,
    this.status = RequestStatus.draft,
    required this.createdAt,
    this.updatedAt,
    this.customerArea = '',
    this.deliveryAddress = '',
    this.customerPhone = '',
    this.customerName = '',
    this.approximateDistance = 0.0,
    this.latitude = 0.0,
    this.longitude = 0.0,
    this.deliveryLocation,
  });

  ShoppingRequest copyWith({
    String? id,
    String? customerId,
    List<RequestItem>? items,
    RequestStatus? status,
    DateTime? createdAt,
    DateTime? updatedAt,
    String? customerArea,
    String? deliveryAddress,
    String? customerPhone,
    String? customerName,
    double? approximateDistance,
    double? latitude,
    double? longitude,
    DeliveryLocation? deliveryLocation,
  }) {
    return ShoppingRequest(
      id: id ?? this.id,
      customerId: customerId ?? this.customerId,
      items: items ?? this.items,
      status: status ?? this.status,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      customerArea: customerArea ?? this.customerArea,
      deliveryAddress: deliveryAddress ?? this.deliveryAddress,
      customerPhone: customerPhone ?? this.customerPhone,
      customerName: customerName ?? this.customerName,
      approximateDistance: approximateDistance ?? this.approximateDistance,
      latitude: latitude ?? this.latitude,
      longitude: longitude ?? this.longitude,
      deliveryLocation: deliveryLocation ?? this.deliveryLocation,
    );
  }
}
