import '../../../requests/models/shopping_request.dart';

/// Vendor-visible delivery fields depend on request/order status.
extension VendorDeliveryPrivacy on ShoppingRequest {
  bool get vendorCanSeeFullDeliveryDetails {
    switch (status) {
      case RequestStatus.paid:
      case RequestStatus.cashOnDeliveryConfirmed:
      case RequestStatus.preparingOrder:
      case RequestStatus.readyForDelivery:
      case RequestStatus.outForDelivery:
      case RequestStatus.delivered:
        return true;
      default:
        return false;
    }
  }

  String get vendorVisibleAreaLabel {
    if (customerArea.isNotEmpty) return customerArea;
    return deliveryLocation?.shortDisplay ?? 'Approximate area pending';
  }

  String? get vendorVisibleStreetAddress =>
      vendorCanSeeFullDeliveryDetails ? deliveryAddress : null;

  String? get vendorVisiblePhone =>
      vendorCanSeeFullDeliveryDetails ? customerPhone : null;
}
