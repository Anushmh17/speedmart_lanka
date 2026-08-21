/// The accepted order assignment for one requested item.
///
/// Order documents remain authoritative for live delivery stages. This map
/// records which vendor/order owns each item, which is required when items in
/// one category are fulfilled by different vendors.
enum RequestItemFulfillmentStatus {
  pending,
  accepted,
  preparing,
  readyForDelivery,
  outForDelivery,
  delivered,
  completed,
  cancelled,
}

class RequestItemFulfillment {
  const RequestItemFulfillment({
    required this.requestItemId,
    this.status = RequestItemFulfillmentStatus.pending,
    this.proposalId,
    this.vendorId,
    this.orderId,
    this.paymentId,
    this.acceptedAt,
    this.updatedAt,
  });

  final String requestItemId;
  final RequestItemFulfillmentStatus status;
  final String? proposalId;
  final String? vendorId;
  final String? orderId;
  final String? paymentId;
  final DateTime? acceptedAt;
  final DateTime? updatedAt;

  factory RequestItemFulfillment.fromJson(Map<String, dynamic> json) {
    return RequestItemFulfillment(
      requestItemId: json['requestItemId'] as String? ?? '',
      status: RequestItemFulfillmentStatus.values.firstWhere(
        (status) => status.name == json['status'],
        orElse: () => RequestItemFulfillmentStatus.pending,
      ),
      proposalId: json['proposalId'] as String?,
      vendorId: json['vendorId'] as String?,
      orderId: json['orderId'] as String?,
      paymentId: json['paymentId'] as String?,
      acceptedAt: json['acceptedAt'] == null
          ? null
          : DateTime.tryParse(json['acceptedAt'] as String),
      updatedAt: json['updatedAt'] == null
          ? null
          : DateTime.tryParse(json['updatedAt'] as String),
    );
  }

  Map<String, dynamic> toJson() => {
        'requestItemId': requestItemId,
        'status': status.name,
        'proposalId': proposalId,
        'vendorId': vendorId,
        'orderId': orderId,
        'paymentId': paymentId,
        'acceptedAt': acceptedAt?.toIso8601String(),
        'updatedAt': updatedAt?.toIso8601String(),
      };
}
