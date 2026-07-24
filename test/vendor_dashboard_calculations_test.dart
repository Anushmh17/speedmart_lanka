import 'package:flutter_test/flutter_test.dart';
import 'package:speedmart_lanka/features/orders/models/order_model.dart';
import 'package:speedmart_lanka/features/payments/models/payment.dart';

void main() {
  group('Vendor dashboard earnings classification', () {
    test('COD orders pending on delivery stay in pending earnings, not paid earnings', () {
      final pendingOnDeliveryOrder = OrderModel(
        id: 'ORD-1',
        proposalId: 'PROP-1',
        requestId: 'REQ-1',
        customerId: 'CUS-1',
        vendorId: 'VEN-1',
        vendorBusinessName: 'Test Vendor',
        vendorPhone: '+94 77 000 0000',
        customerName: 'Jane Customer',
        customerPhone: '+94 71 111 1111',
        deliveryAddress: '45 Galle Rd',
        items: const [],
        deliveryCharge: 200,
        totalPrice: 1200,
        paymentMethod: PaymentMethod.cashOnDelivery,
        paymentStatus: PaymentStatus.pendingOnDelivery,
        status: OrderStatus.delivered,
        createdAt: DateTime.now(),
        commissionRate: 0.1,
      );

      expect(pendingOnDeliveryOrder.isPaidForDashboard, isFalse);
      expect(pendingOnDeliveryOrder.isPendingForDashboard, isTrue);
    });

    test('paid completed orders are counted as settled earnings', () {
      final paidOrder = OrderModel(
        id: 'ORD-2',
        proposalId: 'PROP-2',
        requestId: 'REQ-2',
        customerId: 'CUS-2',
        vendorId: 'VEN-2',
        vendorBusinessName: 'Test Vendor',
        vendorPhone: '+94 77 000 0001',
        customerName: 'John Customer',
        customerPhone: '+94 71 222 2222',
        deliveryAddress: '10 Temple St',
        items: const [],
        deliveryCharge: 200,
        totalPrice: 1200,
        paymentMethod: PaymentMethod.mockOnline,
        paymentStatus: PaymentStatus.paid,
        status: OrderStatus.completed,
        createdAt: DateTime.now(),
        commissionRate: 0.1,
      );

      expect(paidOrder.isPaidForDashboard, isTrue);
      expect(paidOrder.isPendingForDashboard, isFalse);
    });
  });
}
