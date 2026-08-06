import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../../../core/services/firestore_service.dart';
import 'package:speedmart_lanka/core/storage/storage_service.dart';
import 'package:speedmart_lanka/features/orders/models/order_model.dart';
import 'package:speedmart_lanka/features/payments/models/payment.dart';

/// Order repository — Firestore-backed.
class OrderRepository {
  OrderRepository._() {
    _initFuture = _initialize();
  }

  static final OrderRepository instance = OrderRepository._();

  static const String _ordersCollectionPath = 'orders';

  late final Future<void> _initFuture;
  bool _isInitialized = false;

  final List<OrderModel> _orders = [];

  Future<void> ensureInitialized() => _initFuture;

  CollectionReference<Map<String, dynamic>> get _ordersCollection =>
      FirestoreService.collection(_ordersCollectionPath);

  Future<List<Map<String, dynamic>>> _fetchOrdersFromFirestore() async {
    if (FirebaseAuth.instance.currentUser == null) return [];
    try {
      final query = await _ordersCollection.get();
      return query.docs.map((doc) {
        final data = doc.data();
        return {
          ...data,
          'id': doc.id,
        };
      }).toList();
    } catch (e) {
      debugPrint('[Order] Failed to load orders from Firestore: $e');
      return [];
    }
  }

  Future<void> _syncOrderToFirestore(OrderModel order) async {
    await FirestoreService.runAuthenticated(() async {
      try {
        await _ordersCollection.doc(order.id).set(order.toJson());
      } catch (e) {
        debugPrint('[Order] Failed to sync order ${order.id} to Firestore: $e');
      }
    });
  }

  Future<void> _syncOrdersToFirestore(List<OrderModel> orders) async {
    for (final order in orders) {
      await _syncOrderToFirestore(order);
    }
  }

  Future<void> _initialize() async {
    if (_isInitialized) return;

    final firestoreOrders = await _fetchOrdersFromFirestore();
    if (firestoreOrders.isNotEmpty) {
      _orders
        ..clear()
        ..addAll(firestoreOrders.map(OrderModel.fromJson));
    } else {
      // Firestore unavailable — fall back to local storage once
      final saved = await StorageService.getOrders();
      _orders.addAll(saved.map(OrderModel.fromJson));
    }

    _isInitialized = true;
  }

  Future<void> _persistOrders() async {
    await _syncOrdersToFirestore(_orders);
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

