import 'dart:math';
import '../../../core/storage/storage_service.dart';
import '../models/payment.dart';

/// Mock payment repository with local persistence.
/// TODO: Replace mock payment persistence with backend payment API integration.
class MockPaymentRepository {
  MockPaymentRepository._() {
    _initFuture = _initialize();
  }

  static final MockPaymentRepository instance = MockPaymentRepository._();

  late final Future<void> _initFuture;
  bool _isInitialized = false;

  final List<PaymentModel> _payments = [];

  Future<void> ensureInitialized() => _initFuture;

  Future<void> _initialize() async {
    if (_isInitialized) return;
    final saved = await StorageService.getPayments();
    if (saved.isNotEmpty) {
      _payments
        ..clear()
        ..addAll(saved.map(PaymentModel.fromJson));
    }
    _isInitialized = true;
  }

  Future<void> _persistPayments() async {
    await StorageService.savePayments(
      _payments.map((p) => p.toJson()).toList(),
    );
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
    return _payments
        .where((p) => p.customerId == customerId)
        .toList()
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
  }

  Future<List<PaymentModel>> getVendorPayments(String vendorId) async {
    await ensureInitialized();
    await Future.delayed(const Duration(milliseconds: 250));
    return _payments
        .where((p) => p.vendorId == vendorId)
        .toList()
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

  Future<PaymentModel?> updatePaymentOrderId(String paymentId, String orderId) async {
    await ensureInitialized();
    await Future.delayed(const Duration(milliseconds: 200));
    final index = _payments.indexWhere((p) => p.id == paymentId);
    if (index == -1) return null;
    _payments[index] = _payments[index].copyWith(orderId: orderId);
    await _persistPayments();
    return _payments[index];
  }

  Future<void> updatePaymentStatus(String paymentId, PaymentStatus status) async {
    await ensureInitialized();
    await Future.delayed(const Duration(milliseconds: 200));
    final index = _payments.indexWhere((p) => p.id == paymentId);
    if (index != -1) {
      _payments[index] = _payments[index].copyWith(
        paymentStatus: status,
        paidAt: status == PaymentStatus.paid ? DateTime.now() : _payments[index].paidAt,
      );
      await _persistPayments();
    }
  }
}

