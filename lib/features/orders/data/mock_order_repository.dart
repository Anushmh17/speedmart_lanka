import 'dart:math';
import '../models/order_model.dart';

class MockOrderRepository {
  static final MockOrderRepository instance = MockOrderRepository._();
  MockOrderRepository._();

  final List<OrderModel> _orders = [];

  Future<List<OrderModel>> getOrdersForCustomer(String customerId) async {
    await Future.delayed(const Duration(milliseconds: 600));
    return _orders.where((o) => o.customerId == customerId).toList();
  }

  Future<List<OrderModel>> getOrdersForVendor(String vendorId) async {
    await Future.delayed(const Duration(milliseconds: 600));
    return _orders.where((o) => o.vendorId == vendorId).toList();
  }

  Future<OrderModel?> getOrderById(String orderId) async {
    await Future.delayed(const Duration(milliseconds: 300));
    try {
      return _orders.firstWhere((o) => o.id == orderId);
    } catch (_) {
      return null;
    }
  }

  Future<OrderModel> createOrder(OrderModel order) async {
    await Future.delayed(const Duration(milliseconds: 800));
    final newOrder = order.copyWith(
      id: order.id.isEmpty ? 'ORD-${Random().nextInt(90000) + 10000}' : order.id,
      createdAt: DateTime.now(),
    );
    _orders.insert(0, newOrder);
    return newOrder;
  }

  Future<void> updateOrderStatus(String orderId, OrderStatus status) async {
    await Future.delayed(const Duration(milliseconds: 400));
    final index = _orders.indexWhere((o) => o.id == orderId);
    if (index != -1) {
      _orders[index] = _orders[index].copyWith(
        status: status,
        updatedAt: DateTime.now(),
      );
    }
  }

  Future<void> updatePaymentStatus(String orderId, PaymentStatus status) async {
    await Future.delayed(const Duration(milliseconds: 300));
    final index = _orders.indexWhere((o) => o.id == orderId);
    if (index != -1) {
      _orders[index] = _orders[index].copyWith(
        paymentStatus: status,
        updatedAt: DateTime.now(),
      );
    }
  }
}
