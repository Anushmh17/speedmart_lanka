import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../../core/services/firestore_service.dart';
import '../../../core/storage/storage_service.dart';
import '../models/payment.dart';

/// Local payment repository with persisted data.
/// TODO: Replace local payment persistence with backend payment API integration.
class PaymentRepository {
  PaymentRepository._() {
    _initFuture = _initialize();
  }

  static final PaymentRepository instance = PaymentRepository._();

  static const String _paymentsCollectionPath = 'payments';

  late final Future<void> _initFuture;
  bool _isInitialized = false;

  final List<PaymentModel> _payments = [];

  CollectionReference<Map<String, dynamic>> get _paymentsCollection =>
      FirestoreService.collection(_paymentsCollectionPath);

  Future<List<Map<String, dynamic>>> _fetchPaymentsFromFirestore() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return [];
    try {
      // Rules require a customerId or vendorId filter equal to uid().
      final customerSnap = await _paymentsCollection
          .where('customerId', isEqualTo: uid)
          .limit(500)
          .get();
      final vendorSnap = await _paymentsCollection
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
      debugPrint('[Payment] Failed to load payments from Firestore: $e');
      return [];
    }
  }

  Future<void> _syncPaymentToFirestore(PaymentModel payment) async {
    try {
      await _paymentsCollection.doc(payment.id).set(payment.toJson());
    } catch (e) {
      debugPrint(
          '[Payment] Failed to sync payment ${payment.id} to Firestore: $e');
    }
  }

  Future<void> _syncPaymentsToFirestore(List<PaymentModel> payments) async {
    for (final payment in payments) {
      await _syncPaymentToFirestore(payment);
    }
  }

  Future<void> ensureInitialized() => _initFuture;

  Future<void> _initialize() async {
    if (_isInitialized) return;

    final firestorePayments = await _fetchPaymentsFromFirestore();
    if (firestorePayments.isNotEmpty) {
      _payments
        ..clear()
        ..addAll(firestorePayments.map(PaymentModel.fromJson));
    }

    final saved = await StorageService.getPayments();
    if (saved.isNotEmpty) {
      for (final json in saved) {
        final payment = PaymentModel.fromJson(json);
        final index = _payments.indexWhere((p) => p.id == payment.id);
        if (index != -1) {
          _payments[index] = payment;
        } else {
          _payments.add(payment);
        }
      }
    }

    _isInitialized = true;
  }

  Future<void> _persistPayments() async {
    await StorageService.savePayments(
      _payments.map((p) => p.toJson()).toList(),
    );
    await _syncPaymentsToFirestore(_payments);
  }

  Future<void> refreshFromFirestore() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;
    try {
      final customerSnap = await _paymentsCollection
          .where('customerId', isEqualTo: uid)
          .limit(500)
          .get(const GetOptions(source: Source.server));
      final vendorSnap = await _paymentsCollection
          .where('vendorId', isEqualTo: uid)
          .limit(500)
          .get(const GetOptions(source: Source.server));
      final seen = <String>{};
      final merged = <PaymentModel>[];
      for (final doc in [...customerSnap.docs, ...vendorSnap.docs]) {
        if (seen.add(doc.id)) {
          merged.add(PaymentModel.fromJson({...doc.data(), 'id': doc.id}));
        }
      }
      _payments
        ..clear()
        ..addAll(merged);
    } catch (e) {
      debugPrint('[Payment] Failed to refresh payments from Firestore: $e');
    }
  }

  Future<PaymentModel> createPayment(PaymentModel payment) async {
    await ensureInitialized();
    await Future.delayed(const Duration(milliseconds: 300));
    final newPayment = payment.copyWith(
      id: payment.id.isEmpty
          ? 'PAY-${Random().nextInt(90000) + 10000}'
          : payment.id,
    );
    _payments.insert(0, newPayment);
    await _persistPayments();
    return newPayment;
  }

  Future<PaymentModel?> getPaymentByOrderId(String orderId) async {
    await ensureInitialized();
    await Future.delayed(const Duration(milliseconds: 200));
    try {
      return _payments.firstWhere((p) => p.orderId == orderId);
    } catch (_) {
      return null;
    }
  }

  Future<List<PaymentModel>> getCustomerPayments(String customerId) async {
    await ensureInitialized();
    await Future.delayed(const Duration(milliseconds: 250));
    return _payments.where((p) => p.customerId == customerId).toList()
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
  }

  Future<List<PaymentModel>> getVendorPayments(String vendorId) async {
    await ensureInitialized();
    await Future.delayed(const Duration(milliseconds: 250));
    return _payments.where((p) => p.vendorId == vendorId).toList()
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
  }

  Future<PaymentModel?> markPaid(String paymentId) async {
    await ensureInitialized();
    await Future.delayed(const Duration(milliseconds: 200));
    final index = _payments.indexWhere((p) => p.id == paymentId);
    if (index == -1) return null;
    _payments[index] = _payments[index].copyWith(
      paymentStatus: PaymentStatus.paid,
      paidAt: DateTime.now(),
    );
    await _persistPayments();
    return _payments[index];
  }

  Future<PaymentModel?> markBankTransferReceiptSubmitted(
    String paymentId, {
    String? receiptImageUrl,
  }) async {
    await ensureInitialized();
    await Future.delayed(const Duration(milliseconds: 200));
    final index = _payments.indexWhere((p) => p.id == paymentId);
    if (index == -1) return null;
    _payments[index] = _payments[index].copyWith(
      paymentStatus: PaymentStatus.pendingBankTransfer,
      receiptImageUrl: receiptImageUrl,
    );
    await _persistPayments();
    return _payments[index];
  }

  Future<PaymentModel?> markFailed(String paymentId) async {
    await ensureInitialized();
    await Future.delayed(const Duration(milliseconds: 200));
    final index = _payments.indexWhere((p) => p.id == paymentId);
    if (index == -1) return null;
    _payments[index] = _payments[index].copyWith(
      paymentStatus: PaymentStatus.failed,
      paidAt: DateTime.now(),
    );
    await _persistPayments();
    return _payments[index];
  }

  Future<PaymentModel?> updatePaymentOrderId(
      String paymentId, String orderId) async {
    await ensureInitialized();
    await Future.delayed(const Duration(milliseconds: 200));
    final index = _payments.indexWhere((p) => p.id == paymentId);
    if (index == -1) return null;
    _payments[index] = _payments[index].copyWith(orderId: orderId);
    await _persistPayments();
    return _payments[index];
  }

  Future<void> updatePaymentStatus(
      String paymentId, PaymentStatus status) async {
    await ensureInitialized();
    await Future.delayed(const Duration(milliseconds: 200));
    final index = _payments.indexWhere((p) => p.id == paymentId);
    if (index != -1) {
      _payments[index] = _payments[index].copyWith(
        paymentStatus: status,
        paidAt: status == PaymentStatus.paid
            ? DateTime.now()
            : _payments[index].paidAt,
      );
      await _persistPayments();
    }
  }
}
