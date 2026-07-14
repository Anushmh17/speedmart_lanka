import 'dart:math';

import 'package:speedmart_lanka/core/storage/storage_service.dart';
import 'package:speedmart_lanka/features/orders/models/order_model.dart';
import 'package:speedmart_lanka/features/payments/models/payment.dart';

/// Mock order repository with local persistence.
/// TODO: Replace local mock order persistence with backend API.
class MockOrderRepository {
  MockOrderRepository._() {
    _initFuture = _initialize();
  }

  static final MockOrderRepository instance = MockOrderRepository._();

  late final Future<void> _initFuture;
  bool _isInitialized = false;

  final List<OrderModel> _orders = [];

  Future<void> ensureInitialized() => _initFuture;

  Future<void> _initialize() async {
    if (_isInitialized) return;

    final saved = await StorageService.getOrders();
    if (saved.isNotEmpty) {
      _orders
        ..clear()
        ..addAll(saved.map(OrderModel.fromJson));
    }

    _isInitialized = true;
  }

  Future<void> _persistOrders() async {
    await StorageService.saveOrders(
      _orders.map((o) => o.toJson()).toList(),
    );
  }

  Future<List<OrderModel>> getAllOrders() async {
    await ensureInitialized();
    await Future.delayed(const Duration(milliseconds: 300));
    return List<OrderModel>.from(_orders)
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
  }

  Future<List<OrderModel>> getOrdersForCustomer(String customerId) async {
    await ensureInitialized();
    await Future.delayed(const Duration(milliseconds: 300));
    return _orders.where((o) => o.customerId == customerId).toList()
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
  }

  Future<List<OrderModel>> getOrdersForVendor(String vendorId) async {
    await ensureInitialized();
    await Future.delayed(const Duration(milliseconds: 300));
    return _orders.where((o) => o.vendorId == vendorId).toList()
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
  }

  Future<OrderModel?> getOrderById(String orderId) async {
    await ensureInitialized();
    await Future.delayed(const Duration(milliseconds: 200));
    try {
      return _orders.firstWhere((o) => o.id == orderId);
    } catch (_) {
      return null;
    }
  }

  Future<OrderModel> createOrder(OrderModel order) async {
    await ensureInitialized();
    await Future.delayed(const Duration(milliseconds: 400));
    final newOrder = order.copyWith(
      id: order.id.isEmpty
          ? 'ORD-${Random().nextInt(90000) + 10000}'
          : order.id,
      createdAt: DateTime.now(),
    );
    _orders.insert(0, newOrder);
    await _persistOrders();
    return newOrder;
  }

  Future<void> updateOrderStatus(String orderId, OrderStatus status) async {
    await ensureInitialized();
    await Future.delayed(const Duration(milliseconds: 200));
    final index = _orders.indexWhere((o) => o.id == orderId);
    if (index != -1) {
      _orders[index] = _orders[index].copyWith(
        status: status,
        updatedAt: DateTime.now(),
      );
      await _persistOrders();
    }
  }

  Future<void> updatePaymentStatus(String orderId, PaymentStatus status) async {
    await ensureInitialized();
    await Future.delayed(const Duration(milliseconds: 200));
    final index = _orders.indexWhere((o) => o.id == orderId);
    if (index != -1) {
      _orders[index] = _orders[index].copyWith(
        paymentStatus: status,
        updatedAt: DateTime.now(),
      );
      await _persistOrders();
    }
  }
}
