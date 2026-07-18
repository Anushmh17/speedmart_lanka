import '../../payments/models/payment.dart';
import '../models/order_model.dart';

class VendorDeliveryAccessService {
  VendorDeliveryAccessService._();

  static bool canViewFullAddress(OrderModel order) {
    return order.isAddressReleased || order.paymentStatus == PaymentStatus.paid;
  }

  static bool canViewCustomerPhone(OrderModel order) {
    return canViewFullAddress(order);
  }

  static bool canViewLocationAccuracy(OrderModel order) {
    return canViewFullAddress(order);
  }
}

