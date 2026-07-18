import '../../location/models/delivery_location.dart';
import 'request_item.dart';
import 'request_category_fulfillment.dart';
import '../../../shared/utils/category_constants.dart';

enum RequestStatus {
  draft,
  submitted,
  waitingForVendor,
  proposalSubmitted,
  customerAccepted,
  customerRejected,
  paymentPending,
  paid,
  cashOnDeliveryConfirmed,
  preparingOrder,
  readyForDelivery,
  outForDelivery,
  delivered,
  completed,
  cancelled,
  expired,
  accepted,
}

extension RequestStatusExtension on RequestStatus {
  String get displayName {
    switch (this) {
      case RequestStatus.draft:
        return 'Draft';
      case RequestStatus.submitted:
        return 'Submitted';
      case RequestStatus.waitingForVendor:
        return 'Awaiting Proposals';
      case RequestStatus.completed:
        return 'Completed';
      case RequestStatus.proposalSubmitted:
        return 'Proposal Submitted';
      case RequestStatus.customerAccepted:
        return 'Accepted by Customer';
      case RequestStatus.customerRejected:
        return 'Rejected by Customer';
      case RequestStatus.paymentPending:
        return 'Payment Pending';
      case RequestStatus.paid:
        return 'Paid';
      case RequestStatus.cashOnDeliveryConfirmed:
        return 'COD Confirmed';
      case RequestStatus.preparingOrder:
        return 'Preparing Order';
      case RequestStatus.readyForDelivery:
        return 'Ready for Delivery';
      case RequestStatus.outForDelivery:
        return 'Out for Delivery';
      case RequestStatus.delivered:
        return 'Delivered';
      case RequestStatus.cancelled:
        return 'Cancelled';
      case RequestStatus.expired:
        return 'Expired';
      case RequestStatus.accepted:
        return 'Accepted';
    }
  }

  /// Customer may cancel before a vendor bid is accepted.
  bool get canBeCancelledByCustomer {
    switch (this) {
      case RequestStatus.submitted:
      case RequestStatus.waitingForVendor:
      case RequestStatus.proposalSubmitted:
      case RequestStatus.accepted:
        return true;
      default:
        return false;
    }
  }

  bool get isCancelled => this == RequestStatus.cancelled;

  bool get isAwaitingVendorResponse =>
      this == RequestStatus.submitted ||
      this == RequestStatus.waitingForVendor ||
      this == RequestStatus.proposalSubmitted;
}

class ShoppingRequest {
  final String id;
  final String customerId;
  final List<RequestItem> items;
  final RequestStatus status;
  final DateTime createdAt;
  final DateTime? updatedAt;
  final String customerArea;
  final String deliveryAddress;
  final String customerPhone;
  final String customerName;
  final double approximateDistance;
  final double latitude;
  final double longitude;
  final DeliveryLocation? deliveryLocation;

  // Multi-category fulfillment tracking
  final Map<String, RequestCategoryFulfillment> categoryFulfillments;

  // Proposal count (updated when vendors submit/withdraw proposals)
  final int proposalCount;

  // TODO: Persist cancellation metadata via backend API when integrated.
  final DateTime? cancelledAt;
  final String? cancelledReason;
  final String? cancelledBy;

  ShoppingRequest({
    required this.id,
    required this.customerId,
    required this.items,
    this.status = RequestStatus.draft,
    required this.createdAt,
    this.updatedAt,
    this.customerArea = '',
    this.deliveryAddress = '',
    this.customerPhone = '',
    this.customerName = '',
    this.approximateDistance = 0.0,
    this.latitude = 0.0,
    this.longitude = 0.0,
    this.deliveryLocation,
    Map<String, RequestCategoryFulfillment>? categoryFulfillments,
    this.proposalCount = 0,
    this.cancelledAt,
    this.cancelledReason,
    this.cancelledBy,
  }) : categoryFulfillments = categoryFulfillments ?? _initializeCategoryFulfillments(items);

  /// Initialize category fulfillments from request items
  static Map<String, RequestCategoryFulfillment> _initializeCategoryFulfillments(
    List<RequestItem> items,
  ) {
    final categories = <String>{};
    for (final item in items) {
      if (item.category != null && item.category!.isNotEmpty) {
        final normalized = VendorCategories.normalize(item.category!);
        categories.add(normalized);
      }
    }

    return Map.fromEntries(
      categories.map(
        (cat) => MapEntry(
          cat,
          RequestCategoryFulfillment(categoryNormalized: cat),
        ),
      ),
    );
  }

  /// Get all categories in this request (normalized)
  List<String> get categories => categoryFulfillments.keys.toList();

  /// Check if request has multiple categories
  bool get isMultiCategory => categoryFulfillments.length > 1;

  /// Get fulfillment for a specific category
  RequestCategoryFulfillment? getFulfillment(String categoryNormalized) {
    return categoryFulfillments[categoryNormalized];
  }

  /// Get status for a specific category
  RequestCategoryStatus getCategoryStatus(String categoryNormalized) {
    return categoryFulfillments[categoryNormalized]?.status ??
        RequestCategoryStatus.pending;
  }

  /// Check if category can receive proposals
  bool canCategoryReceiveProposals(String categoryNormalized) {
    return getCategoryStatus(categoryNormalized).canReceiveProposals;
  }

  /// Get count of categories by status
  int getCategoryCountByStatus(RequestCategoryStatus status) {
    return categoryFulfillments.values
        .where((f) => f.status == status)
        .length;
  }

  /// Get total category count
  int get totalCategories => categoryFulfillments.length;

  /// Get pending categories count
  int get pendingCategoriesCount =>
      getCategoryCountByStatus(RequestCategoryStatus.pending);

  /// Get categories that have received at least one proposal but not yet accepted
  int get proposalReceivedCategoriesCount =>
      getCategoryCountByStatus(RequestCategoryStatus.proposalReceived);

  /// Get accepted categories count
  int get acceptedCategoriesCount =>
      getCategoryCountByStatus(RequestCategoryStatus.accepted) +
      getCategoryCountByStatus(RequestCategoryStatus.paid);

  /// Get completed categories count
  int get completedCategoriesCount =>
      getCategoryCountByStatus(RequestCategoryStatus.completed);

  /// Check if all categories are completed
  bool get allCategoriesCompleted =>
      completedCategoriesCount == totalCategories;

  /// Check if any category is accepted
  bool get hasAcceptedCategory => acceptedCategoriesCount > 0;

  bool canBeCancelledByCustomer({required bool hasAcceptedProposal}) {
    if (hasAcceptedProposal) return false;
    return status.canBeCancelledByCustomer;
  }

  ShoppingRequest copyWith({
    String? id,
    String? customerId,
    List<RequestItem>? items,
    RequestStatus? status,
    DateTime? createdAt,
    DateTime? updatedAt,
    String? customerArea,
    String? deliveryAddress,
    String? customerPhone,
    String? customerName,
    double? approximateDistance,
    double? latitude,
    double? longitude,
    DeliveryLocation? deliveryLocation,
    Map<String, RequestCategoryFulfillment>? categoryFulfillments,
    int? proposalCount,
    DateTime? cancelledAt,
    String? cancelledReason,
    String? cancelledBy,
  }) {
    return ShoppingRequest(
      id: id ?? this.id,
      customerId: customerId ?? this.customerId,
      items: items ?? this.items,
      status: status ?? this.status,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      customerArea: customerArea ?? this.customerArea,
      deliveryAddress: deliveryAddress ?? this.deliveryAddress,
      customerPhone: customerPhone ?? this.customerPhone,
      customerName: customerName ?? this.customerName,
      approximateDistance: approximateDistance ?? this.approximateDistance,
      latitude: latitude ?? this.latitude,
      longitude: longitude ?? this.longitude,
      deliveryLocation: deliveryLocation ?? this.deliveryLocation,
      categoryFulfillments: categoryFulfillments ?? this.categoryFulfillments,
      proposalCount: proposalCount ?? this.proposalCount,
      cancelledAt: cancelledAt ?? this.cancelledAt,
      cancelledReason: cancelledReason ?? this.cancelledReason,
      cancelledBy: cancelledBy ?? this.cancelledBy,
    );
  }

  /// Serializes for local persistence (image paths only, not binary).
  /// TODO: Replace local mock request persistence with backend API.
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'customerId': customerId,
      'status': status.name,
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt?.toIso8601String(),
      'customerArea': customerArea,
      'deliveryAddress': deliveryAddress,
      'customerPhone': customerPhone,
      'customerName': customerName,
      'approximateDistance': approximateDistance,
      'latitude': latitude,
      'longitude': longitude,
      'deliveryLocation': deliveryLocation?.toJson(),
      'categoryFulfillments': categoryFulfillments.map(
        (key, value) => MapEntry(key, value.toJson()),
      ),
      'proposalCount': proposalCount,
      'cancelledAt': cancelledAt?.toIso8601String(),
      'cancelledReason': cancelledReason,
      'cancelledBy': cancelledBy,
      'items': items.map((i) => i.toJson()).toList(),
    };
  }

  factory ShoppingRequest.fromJson(Map<String, dynamic> json) {
    // Parse category fulfillments
    Map<String, RequestCategoryFulfillment> fulfillments = {};
    if (json['categoryFulfillments'] != null) {
      final fulfillmentsJson =
          json['categoryFulfillments'] as Map<String, dynamic>;
      fulfillments = fulfillmentsJson.map(
        (key, value) => MapEntry(
          key,
          RequestCategoryFulfillment.fromJson(
            Map<String, dynamic>.from(value as Map),
          ),
        ),
      );
    }

    return ShoppingRequest(
      id: json['id'] as String? ?? '',
      customerId: json['customerId'] as String? ?? '',
      items: (json['items'] as List<dynamic>? ?? [])
          .map((e) => RequestItem.fromJson(Map<String, dynamic>.from(e as Map)))
          .toList(),
      status: RequestStatus.values.firstWhere(
        (s) => s.name == json['status'],
        orElse: () => RequestStatus.submitted,
      ),
      createdAt: DateTime.tryParse(json['createdAt'] as String? ?? '') ??
          DateTime.now(),
      updatedAt: json['updatedAt'] != null
          ? DateTime.tryParse(json['updatedAt'] as String)
          : null,
      customerArea: json['customerArea'] as String? ?? '',
      deliveryAddress: json['deliveryAddress'] as String? ?? '',
      customerPhone: json['customerPhone'] as String? ?? '',
      customerName: json['customerName'] as String? ?? '',
      approximateDistance:
          (json['approximateDistance'] as num?)?.toDouble() ?? 0.0,
      latitude: (json['latitude'] as num?)?.toDouble() ?? 0.0,
      longitude: (json['longitude'] as num?)?.toDouble() ?? 0.0,
      deliveryLocation: json['deliveryLocation'] != null
          ? DeliveryLocation.fromJson(
              Map<String, dynamic>.from(json['deliveryLocation'] as Map),
            )
          : null,
      categoryFulfillments: fulfillments,
      proposalCount: json['proposalCount'] as int? ?? 0,
      cancelledAt: json['cancelledAt'] != null
          ? DateTime.tryParse(json['cancelledAt'] as String)
          : null,
      cancelledReason: json['cancelledReason'] as String?,
      cancelledBy: json['cancelledBy'] as String?,
    );
  }
}

