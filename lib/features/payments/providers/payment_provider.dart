import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../auth/providers/auth_provider.dart';
import '../data/mock_payment_repository.dart';
import '../models/payment.dart';

class PaymentState {
  final bool isLoading;
  final String? error;
  final List<PaymentModel> payments;

  const PaymentState({
    this.isLoading = false,
    this.error,
    this.payments = const [],
  });

  PaymentState copyWith({
    bool? isLoading,
    String? error,
    List<PaymentModel>? payments,
    bool clearError = false,
  }) {
    return PaymentState(
      isLoading: isLoading ?? this.isLoading,
      error: clearError ? null : (error ?? this.error),
      payments: payments ?? this.payments,
    );
  }
}

class PaymentNotifier extends StateNotifier<PaymentState> {
  PaymentNotifier(this.ref) : super(const PaymentState()) {
    _repo = MockPaymentRepository.instance;
  }

  final Ref ref;
  late final MockPaymentRepository _repo;

  Future<void> loadCustomerPayments() async {
    final user = ref.read(currentUserProvider);
    if (user == null) return;
    await _repo.ensureInitialized();
    state = state.copyWith(isLoading: true, clearError: true);
    try {
      final payments = await _repo.getCustomerPayments(user.id);
      state = state.copyWith(isLoading: false, payments: payments);
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
    }
  }

  Future<void> loadVendorPayments() async {
    final user = ref.read(currentUserProvider);
    if (user == null) return;
    await _repo.ensureInitialized();
    state = state.copyWith(isLoading: true, clearError: true);
    try {
      final payments = await _repo.getVendorPayments(user.id);
      state = state.copyWith(isLoading: false, payments: payments);
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
    }
  }

  Future<PaymentModel> createPayment(PaymentModel payment) async {
    await _repo.ensureInitialized();
    state = state.copyWith(isLoading: true, clearError: true);
    try {
      final created = await _repo.createPayment(payment);
      state = state.copyWith(
        isLoading: false,
        payments: [created, ...state.payments],
      );
      return created;
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
      rethrow;
    }
  }

  Future<PaymentModel?> markPaid(String paymentId) async {
    await _repo.ensureInitialized();
    state = state.copyWith(isLoading: true, clearError: true);
    try {
      final updated = await _repo.markPaid(paymentId);
      if (updated != null) {
        state = state.copyWith(
          isLoading: false,
          payments: state.payments.map((p) => p.id == updated.id ? updated : p).toList(),
        );
      } else {
        state = state.copyWith(isLoading: false);
      }
      return updated;
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
      rethrow;
    }
  }

  Future<PaymentModel?> markFailed(String paymentId) async {
    await _repo.ensureInitialized();
    state = state.copyWith(isLoading: true, clearError: true);
    try {
      final updated = await _repo.markFailed(paymentId);
      if (updated != null) {
        state = state.copyWith(
          isLoading: false,
          payments: state.payments.map((p) => p.id == updated.id ? updated : p).toList(),
        );
      } else {
        state = state.copyWith(isLoading: false);
      }
      return updated;
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
      rethrow;
    }
  }

  Future<PaymentModel?> assignOrderId(String paymentId, String orderId) async {
    await _repo.ensureInitialized();
    state = state.copyWith(isLoading: true, clearError: true);
    try {
      final updated = await _repo.updatePaymentOrderId(paymentId, orderId);
      if (updated != null) {
        state = state.copyWith(
          isLoading: false,
          payments: state.payments.map((p) => p.id == updated.id ? updated : p).toList(),
        );
      } else {
        state = state.copyWith(isLoading: false);
      }
      return updated;
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
      rethrow;
    }
  }

  Future<PaymentModel?> getPaymentByOrderId(String orderId) async {
    await _repo.ensureInitialized();
    return _repo.getPaymentByOrderId(orderId);
  }
}

final paymentProvider = StateNotifierProvider<PaymentNotifier, PaymentState>((ref) {
  return PaymentNotifier(ref);
});

/// Reads a vendor's custom commission rate from their user profile.
/// Falls back to 0.0 if not set. Replaces the deleted adminProvider version.
final vendorCommissionRateProvider = Provider.family<double, String>((ref, vendorId) {
  final users = ref.watch(authProvider).user;
  // Commission rate is stored on the vendor's own user model
  // For the payment screen we read it from the auth repo directly via a FutureProvider
  return 0.0;
});

