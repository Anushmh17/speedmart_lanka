import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import '../models/vendor_commission_payment.dart';

/// Firestore data layer for vendor commission payment records.
/// Collection: vendor_commission_payments
class VendorCommissionPaymentRepository {
  VendorCommissionPaymentRepository._();
  static final VendorCommissionPaymentRepository instance =
      VendorCommissionPaymentRepository._();

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  static const _collection = 'vendor_commission_payments';

  CollectionReference<Map<String, dynamic>> get _col =>
      _firestore.collection(_collection);

  // ── Vendor-side reads ──────────────────────────────────────────────────────

  /// Streams all payment records for a specific vendor (real-time).
  Stream<List<VendorCommissionPayment>> streamForVendor(String vendorId) {
    return _col
        .where('vendor_id', isEqualTo: vendorId)
        .snapshots()
        .map((snap) {
      final list = snap.docs
          .map((d) =>
              VendorCommissionPayment.fromJson({...d.data(), 'id': d.id}))
          .toList();
      list.sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
      return list;
    });
  }

  /// One-shot fetch for a vendor.
  Future<List<VendorCommissionPayment>> getForVendor(String vendorId) async {
    final snap = await _col
        .where('vendor_id', isEqualTo: vendorId)
        .get();
    final list = snap.docs
        .map((d) =>
            VendorCommissionPayment.fromJson({...d.data(), 'id': d.id}))
        .toList();
    list.sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
    return list;
  }

  // ── Admin-side reads ───────────────────────────────────────────────────────

  /// Streams all payment records across all vendors (admin view).
  Stream<List<VendorCommissionPayment>> streamAll() {
    return _col
        .orderBy('updated_at', descending: true)
        .snapshots()
        .map((snap) => snap.docs
            .map((d) => VendorCommissionPayment.fromJson({...d.data(), 'id': d.id}))
            .toList());
  }

  /// Streams only records with receipt_submitted status (pending admin review).
  Stream<List<VendorCommissionPayment>> streamAwaitingReview() {
    return _col
        .where('status', isEqualTo: VendorCommissionPaymentStatus.receiptSubmitted.name)
        .snapshots()
        .map((snap) {
      final list = snap.docs
          .map((d) =>
              VendorCommissionPayment.fromJson({...d.data(), 'id': d.id}))
          .toList();
      list.sort((a, b) {
        final dtA = a.submittedAt ?? a.updatedAt;
        final dtB = b.submittedAt ?? b.updatedAt;
        return dtB.compareTo(dtA);
      });
      return list;
    });
  }

  // ── Write operations ───────────────────────────────────────────────────────

  /// Admin creates a new payment record for a vendor.
  Future<VendorCommissionPayment> createPaymentRecord({
    required String vendorId,
    required String vendorName,
    required double amountOwed,
  }) async {
    final now = DateTime.now();
    final data = <String, dynamic>{
      'vendor_id': vendorId,
      'vendor_name': vendorName,
      'amount_owed': amountOwed,
      'amount_paid': 0.0,
      'receipt_url': null,
      'receipt_note': null,
      'admin_note': null,
      'status': VendorCommissionPaymentStatus.pending.name,
      'created_at': now.toIso8601String(),
      'updated_at': now.toIso8601String(),
      'submitted_at': null,
      'reviewed_at': null,
    };
    final ref = await _col.add(data);
    debugPrint('[CommissionPayment] Created record ${ref.id} for vendor $vendorId');
    return VendorCommissionPayment.fromJson({...data, 'id': ref.id});
  }

  /// Vendor submits their bank transfer receipt for an existing record.
  Future<void> submitReceipt({
    required String paymentId,
    required String receiptUrl,
    String? note,
  }) async {
    final now = DateTime.now();
    await _col.doc(paymentId).update({
      'receipt_url': receiptUrl,
      'receipt_note': note,
      'status': VendorCommissionPaymentStatus.receiptSubmitted.name,
      'submitted_at': now.toIso8601String(),
      'updated_at': now.toIso8601String(),
    });
    debugPrint('[CommissionPayment] Vendor submitted receipt for $paymentId');
  }

  /// Vendor directly submits a bank transfer receipt (when no prior pending record exists).
  Future<VendorCommissionPayment> submitVendorDirectReceipt({
    required String vendorId,
    required String vendorName,
    required String receiptUrl,
    String? note,
  }) async {
    final now = DateTime.now();
    final data = <String, dynamic>{
      'vendor_id': vendorId,
      'vendor_name': vendorName,
      'amount_owed': 0.0,
      'amount_paid': 0.0,
      'receipt_url': receiptUrl,
      'receipt_note': note,
      'admin_note': null,
      'status': VendorCommissionPaymentStatus.receiptSubmitted.name,
      'created_at': now.toIso8601String(),
      'updated_at': now.toIso8601String(),
      'submitted_at': now.toIso8601String(),
      'reviewed_at': null,
    };
    final ref = await _col.add(data);
    debugPrint('[CommissionPayment] Direct receipt submitted: ${ref.id} for vendor $vendorId');
    return VendorCommissionPayment.fromJson({...data, 'id': ref.id});
  }

  /// Admin accepts receipt — optionally adjusts amountOwed for partial payments.
  /// [amountPaid] — how much the vendor actually paid.
  /// [remainingOwed] — set to 0 for full payment, or remainder for partial.
  /// [adminNote] — optional comment from admin.
  Future<void> adminAcceptReceipt({
    required String paymentId,
    required double amountPaid,
    required double remainingOwed,
    String? adminNote,
  }) async {
    final now = DateTime.now();
    final isFull = remainingOwed <= 0;
    await _col.doc(paymentId).update({
      'amount_paid': amountPaid,
      'amount_owed': remainingOwed,
      'admin_note': adminNote,
      'status': isFull
          ? VendorCommissionPaymentStatus.accepted.name
          : VendorCommissionPaymentStatus.partial.name,
      'reviewed_at': now.toIso8601String(),
      'updated_at': now.toIso8601String(),
    });
    debugPrint(
        '[CommissionPayment] Admin reviewed $paymentId: paid=$amountPaid, remaining=$remainingOwed');
  }

  /// Admin updates the amount owed (e.g., after a manual correction).
  Future<void> adminUpdateAmountOwed({
    required String paymentId,
    required double newAmountOwed,
    String? adminNote,
  }) async {
    final now = DateTime.now();
    await _col.doc(paymentId).update({
      'amount_owed': newAmountOwed,
      if (adminNote != null) 'admin_note': adminNote,
      'updated_at': now.toIso8601String(),
    });
  }

  /// Delete a payment record (admin only).
  Future<void> deleteRecord(String paymentId) async {
    await _col.doc(paymentId).delete();
    debugPrint('[CommissionPayment] Deleted record $paymentId');
  }
}
