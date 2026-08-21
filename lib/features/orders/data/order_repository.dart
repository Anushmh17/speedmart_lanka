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
    final uid = FirebaseAuth.instance.currentUser!.uid;
    try {
      // Rules require a customerId or vendorId filter equal to uid().
      final customerSnap = await _ordersCollection
          .where('customerId', isEqualTo: uid)
          .limit(500)
          .get();
      final vendorSnap = await _ordersCollection
          .where('vendorId', isEqualTo: uid)
          .limit(500)
          .get();
      final seen = <String>{};
      final results = <Map<String, dynamic>>[];
      for (final doc in [...customerSnap.docs, ...vendorSnap.docs]) {
        if (seen.add(doc.id)) {
          results.add({...doc.data(), 'id': doc.id});
        }
      }
      return results;
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

  /// Reload orders created or updated on another device/session. Keep the
  /// existing cache if the server cannot be reached.
  Future<void> refreshFromFirestore() async {
    if (FirebaseAuth.instance.currentUser == null) return;
    final uid = FirebaseAuth.instance.currentUser!.uid;
    try {
      final customerSnap = await _ordersCollection
          .where('customerId', isEqualTo: uid)
          .limit(500)
          .get(const GetOptions(source: Source.server));
      final vendorSnap = await _ordersCollection
          .where('vendorId', isEqualTo: uid)
          .limit(500)
          .get(const GetOptions(source: Source.server));
      final seen = <String>{};
      final merged = <OrderModel>[];
      for (final doc in [...customerSnap.docs, ...vendorSnap.docs]) {
        if (seen.add(doc.id)) {
          merged.add(OrderModel.fromJson({...doc.data(), 'id': doc.id}));
        }
      }
      _orders
        ..clear()
        ..addAll(merged);
    } catch (e) {
      debugPrint('[Order] Failed to refresh orders from Firestore: $e');
    }
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

  /// Persist the vendor's packing checklist state for [orderId].
  /// Uses a targeted Firestore `update` so the full order is not re-written.
  Future<void> savePackedItems(
      String orderId, Map<String, bool> packedItems) async {
    try {
      await _ordersCollection.doc(orderId).update({
        'packedItems': packedItems,
      });
    } catch (e) {
      debugPrint('[Order] Failed to save packedItems for $orderId: $e');
    }
  }

  /// Load the vendor's packing checklist state for [orderId] from Firestore.
  Future<Map<String, bool>> loadPackedItems(String orderId) async {
    try {
      final doc = await _ordersCollection.doc(orderId).get();
      if (!doc.exists) return {};
      final raw = doc.data()?['packedItems'];
      if (raw == null) return {};
      return Map<String, bool>.from(
        (raw as Map<String, dynamic>).map(
          (k, v) => MapEntry(k, v == true),
        ),
      );
    } catch (e) {
      debugPrint('[Order] Failed to load packedItems for $orderId: $e');
      return {};
    }
  }
}

