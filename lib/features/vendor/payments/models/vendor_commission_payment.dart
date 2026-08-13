/// Represents a single commission payment record from a vendor to Speedmart.
/// Stored in Firestore at: vendor_commission_payments/{paymentId}
class VendorCommissionPayment {
  final String id;
  final String vendorId;
  final String vendorName;

  /// Total outstanding amount the vendor owes (in LKR).
  /// Admin can update this after reviewing a partial payment.
  final double amountOwed;

  /// Amount confirmed as paid (set by admin after accepting).
  final double amountPaid;

  /// Firebase Storage URL for the uploaded bank receipt.
  final String? receiptUrl;

  /// Optional note from the vendor when submitting their receipt.
  final String? receiptNote;

  /// Optional note from the admin when reviewing.
  final String? adminNote;

  final VendorCommissionPaymentStatus status;

  final DateTime createdAt;
  final DateTime? submittedAt;
  final DateTime? reviewedAt;
  final DateTime updatedAt;

  const VendorCommissionPayment({
    required this.id,
    required this.vendorId,
    required this.vendorName,
    required this.amountOwed,
    required this.amountPaid,
    required this.status,
    required this.createdAt,
    required this.updatedAt,
    this.receiptUrl,
    this.receiptNote,
    this.adminNote,
    this.submittedAt,
    this.reviewedAt,
  });

  factory VendorCommissionPayment.fromJson(Map<String, dynamic> json) {
    return VendorCommissionPayment(
      id: json['id'] as String,
      vendorId: json['vendor_id'] as String,
      vendorName: json['vendor_name'] as String? ?? '',
      amountOwed: (json['amount_owed'] as num?)?.toDouble() ?? 0.0,
      amountPaid: (json['amount_paid'] as num?)?.toDouble() ?? 0.0,
      receiptUrl: json['receipt_url'] as String?,
      receiptNote: json['receipt_note'] as String?,
      adminNote: json['admin_note'] as String?,
      status: VendorCommissionPaymentStatus.fromString(
          json['status'] as String? ?? 'pending'),
      createdAt: _parseDateTime(json['created_at']),
      updatedAt: _parseDateTime(json['updated_at']),
      submittedAt: json['submitted_at'] != null
          ? _parseDateTime(json['submitted_at'])
          : null,
      reviewedAt: json['reviewed_at'] != null
          ? _parseDateTime(json['reviewed_at'])
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'vendor_id': vendorId,
      'vendor_name': vendorName,
      'amount_owed': amountOwed,
      'amount_paid': amountPaid,
      'receipt_url': receiptUrl,
      'receipt_note': receiptNote,
      'admin_note': adminNote,
      'status': status.name,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
      'submitted_at': submittedAt?.toIso8601String(),
      'reviewed_at': reviewedAt?.toIso8601String(),
    };
  }

  VendorCommissionPayment copyWith({
    String? id,
    String? vendorId,
    String? vendorName,
    double? amountOwed,
    double? amountPaid,
    String? receiptUrl,
    String? receiptNote,
    String? adminNote,
    VendorCommissionPaymentStatus? status,
    DateTime? createdAt,
    DateTime? updatedAt,
    DateTime? submittedAt,
    DateTime? reviewedAt,
  }) {
    return VendorCommissionPayment(
      id: id ?? this.id,
      vendorId: vendorId ?? this.vendorId,
      vendorName: vendorName ?? this.vendorName,
      amountOwed: amountOwed ?? this.amountOwed,
      amountPaid: amountPaid ?? this.amountPaid,
      receiptUrl: receiptUrl ?? this.receiptUrl,
      receiptNote: receiptNote ?? this.receiptNote,
      adminNote: adminNote ?? this.adminNote,
      status: status ?? this.status,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      submittedAt: submittedAt ?? this.submittedAt,
      reviewedAt: reviewedAt ?? this.reviewedAt,
    );
  }

  /// True if the vendor has submitted a receipt but admin hasn't reviewed yet.
  bool get awaitingReview =>
      status == VendorCommissionPaymentStatus.receiptSubmitted;

  /// True if the commission balance is fully cleared.
  bool get isCleared => amountOwed <= 0;

  static DateTime _parseDateTime(dynamic value) {
    if (value == null) return DateTime.now();
    if (value is String) return DateTime.parse(value);
    return DateTime.now();
  }
}

enum VendorCommissionPaymentStatus {
  /// Admin created the record — vendor hasn't submitted receipt yet.
  pending,

  /// Vendor uploaded their bank transfer receipt.
  receiptSubmitted,

  /// Admin accepted — full or partial.
  accepted,

  /// Admin noted a partial payment — amountOwed was updated to remaining.
  partial,
  ;

  static VendorCommissionPaymentStatus fromString(String raw) {
    return VendorCommissionPaymentStatus.values.firstWhere(
      (e) => e.name == raw,
      orElse: () => VendorCommissionPaymentStatus.pending,
    );
  }

  String get displayLabel {
    switch (this) {
      case pending:
        return 'Payment Due';
      case receiptSubmitted:
        return 'Receipt Submitted';
      case accepted:
        return 'Accepted';
      case partial:
        return 'Partial — Balance Remaining';
    }
  }
}
