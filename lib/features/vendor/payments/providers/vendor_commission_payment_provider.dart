import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/vendor_commission_payment.dart';
import '../data/vendor_commission_payment_repository.dart';
import '../../../auth/providers/auth_provider.dart';

// ── Vendor-side stream provider ────────────────────────────────────────────

/// Streams all commission payment records for the currently logged-in vendor.
final vendorCommissionPaymentsProvider =
    StreamProvider<List<VendorCommissionPayment>>((ref) {
  final user = ref.watch(currentUserProvider);
  if (user == null) return const Stream.empty();
  return VendorCommissionPaymentRepository.instance.streamForVendor(user.id);
});

/// Convenience: returns the latest (most recently updated) payment record,
/// or null if none exists.
final latestCommissionPaymentProvider =
    Provider<VendorCommissionPayment?>((ref) {
  final payments = ref.watch(vendorCommissionPaymentsProvider).valueOrNull;
  if (payments == null || payments.isEmpty) return null;
  return payments.first;
});

/// Total balance still owed by this vendor across all records.
final totalCommissionOwedProvider = Provider<double>((ref) {
  final payments = ref.watch(vendorCommissionPaymentsProvider).valueOrNull;
  if (payments == null) return 0.0;
  return payments.fold(0.0, (sum, p) => sum + p.amountOwed);
});

// ── Admin-side stream providers (used by admin web & Flutter admin) ────────

/// Streams ALL vendor commission payment records (admin view).
final allVendorCommissionPaymentsProvider =
    StreamProvider<List<VendorCommissionPayment>>((ref) {
  return VendorCommissionPaymentRepository.instance.streamAll();
});

/// Streams only records awaiting admin review.
final commissionPaymentsAwaitingReviewProvider =
    StreamProvider<List<VendorCommissionPayment>>((ref) {
  return VendorCommissionPaymentRepository.instance.streamAwaitingReview();
});
