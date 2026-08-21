import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../shared/models/location_model.dart';
import '../../auth/providers/auth_provider.dart';
import 'package:speedmart_lanka/features/auth/data/auth_repository.dart';
import 'package:speedmart_lanka/features/notifications/providers/notification_provider.dart' as notification_feature;
import 'package:speedmart_lanka/features/notifications/models/notification_type.dart';
import 'package:speedmart_lanka/shared/utils/category_constants.dart';
import '../data/request_repository.dart';
import '../../proposals/data/proposal_repository.dart';
import '../../proposals/models/proposal.dart';
import '../../orders/data/order_repository.dart';
import '../../orders/models/order_model.dart';
import '../models/request_item.dart';
import '../models/shopping_request.dart';
import '../../location/models/delivery_location.dart';
import 'package:speedmart_lanka/core/utils/error_translator.dart';

class RequestState {
  final bool isLoading;
  final String? error;
  final List<ShoppingRequest> requests;
  final List<ShoppingRequest> nearbyRequests;
  final double vendorLatitude;
  final double vendorLongitude;
  final String vendorArea;

  const RequestState({
    this.isLoading = false,
    this.error,
    this.requests = const [],
    this.nearbyRequests = const [],
    this.vendorLatitude = 6.9145, // Colombo 03 default
    this.vendorLongitude = 79.8510,
    this.vendorArea = 'Colombo 03 (Colpetty)',
  });

  RequestState copyWith({
    bool? isLoading,
    String? error,
    List<ShoppingRequest>? requests,
    List<ShoppingRequest>? nearbyRequests,
    double? vendorLatitude,
    double? vendorLongitude,
    String? vendorArea,
    bool clearError = false,
  }) {
    return RequestState(
      isLoading: isLoading ?? this.isLoading,
      error: clearError ? null : (error ?? this.error),
      requests: requests ?? this.requests,
      nearbyRequests: nearbyRequests ?? this.nearbyRequests,
      vendorLatitude: vendorLatitude ?? this.vendorLatitude,
      vendorLongitude: vendorLongitude ?? this.vendorLongitude,
      vendorArea: vendorArea ?? this.vendorArea,
    );
  }
}

class RequestNotifier extends StateNotifier<RequestState> {
  RequestNotifier(this.ref) : super(const RequestState()) {
    _repo = RequestRepository.instance;
    _bootstrap();
  }

  final Ref ref;
  late final RequestRepository _repo;
  StreamSubscription<QuerySnapshot<Map<String, dynamic>>>?
      _customerProposalSubscription;
  String? _watchedCustomerId;
  Future<void> _customerRequestLoadQueue = Future.value();

  Future<void> _bootstrap() async {
    await _repo.ensureInitialized();
    await ProposalRepository.instance.ensureInitialized();
    await OrderRepository.instance.ensureInitialized();
    final user = ref.read(currentUserProvider);
    if (user == null) return;
    if (user.role.name == 'customer') {
      await loadMyRequests();
    } else if (user.role.name == 'vendor') {
      await loadNearbyRequests();
    }
  }

  /// Customer startup triggers this from the provider, dashboard, and the
  /// proposal listener. These reads share repository caches, so serializing
  /// them prevents an older response from overwriting a newer proposal count.
  Future<void> loadMyRequests() {
    final Future<void> nextLoad = _customerRequestLoadQueue.then<void>(
      (_) => _loadMyRequests(),
      onError: (_) => _loadMyRequests(),
    );
    _customerRequestLoadQueue = nextLoad;
    return nextLoad;
  }

  Future<void> _loadMyRequests() async {
    final user = ref.read(currentUserProvider);
    if (user == null) return;

    _watchCustomerProposals(user.id);

    await _repo.ensureInitialized();
    await ProposalRepository.instance.ensureInitialized();
    await OrderRepository.instance.ensureInitialized();
    state = state.copyWith(isLoading: true, clearError: true);
    try {
      await Future.wait([
        _repo.refreshFromFirestore(),
        ProposalRepository.instance.refreshFromFirestore(),
        OrderRepository.instance.refreshFromFirestore(),
      ]);
      final requests = await _repo.getCustomerRequests(user.id);
      final proposals = await ProposalRepository.instance.getAllProposals();
      final orders = await OrderRepository.instance.getOrdersForCustomer(user.id);

      // Vendor apps cannot write customer requests directly. Derive the
      // customer-facing count and status from the authoritative proposals so
      // dashboard and list cards update even before a server refresh arrives.
      final hydratedRequests = requests.map((request) {
        final hasOpenCategory = request.categoryFulfillments.isNotEmpty &&
            request.categoryFulfillments.values
                .any((fulfillment) => fulfillment.status.canReceiveProposals);
        final hasConfirmedOrder = orders.any(
          (order) =>
              order.requestId == request.id &&
              order.status != OrderStatus.cancelled,
        );
        // An order closes a single-category request. For a multi-category
        // request, preserve the remaining category offers until all categories
        // have been resolved.
        final isOrderCompleteForRequest = hasConfirmedOrder &&
            (!request.isMultiCategory || !hasOpenCategory);
        final requestOrders = orders
            .where((order) =>
                order.requestId == request.id &&
                order.status != OrderStatus.cancelled)
            .toList();
        final derivedOrderStatus = _requestStatusFromOrders(requestOrders);
        final openProposalCount = proposals
            .where((proposal) =>
                proposal.requestId == request.id &&
                (proposal.status == ProposalStatus.submitted ||
                    proposal.status == ProposalStatus.updated))
            .length;
        final hasNewProposal = openProposalCount > 0;
        final shouldShowProposalStatus = hasNewProposal &&
            (request.status == RequestStatus.submitted ||
                request.status == RequestStatus.waitingForVendor ||
                request.status == RequestStatus.proposalSubmitted);

        return request.copyWith(
          proposalCount:
              isOrderCompleteForRequest ? 0 : openProposalCount,
          status: isOrderCompleteForRequest
              ? (derivedOrderStatus ?? RequestStatus.customerAccepted)
              : shouldShowProposalStatus
                  ? RequestStatus.proposalSubmitted
                  : request.status,
        );
      }).toList();

      state = state.copyWith(isLoading: false, requests: hydratedRequests);
    } catch (e) {
      state = state.copyWith(isLoading: false, error: ErrorTranslator.friendly(e));
    }
  }

  RequestStatus? _requestStatusFromOrders(List<OrderModel> orders) {
    if (orders.isEmpty) return null;
    if (orders.every((order) => order.status == OrderStatus.completed)) {
      return RequestStatus.completed;
    }

    // With multiple vendors, show the least advanced active order. This avoids
    // claiming the whole request is out for delivery while another vendor has
    // not yet started preparing its assigned items.
    final activeOrders = orders
        .where((order) => order.status != OrderStatus.completed)
        .toList();
    final earliest = activeOrders.reduce(
      (current, candidate) => _orderStageRank(candidate.status) <
              _orderStageRank(current.status)
          ? candidate
          : current,
    );
    switch (earliest.status) {
      case OrderStatus.submitted:
      case OrderStatus.accepted:
        return RequestStatus.customerAccepted;
      case OrderStatus.preparing:
        return RequestStatus.preparingOrder;
      case OrderStatus.readyForDelivery:
        return RequestStatus.readyForDelivery;
      case OrderStatus.outForDelivery:
        return RequestStatus.outForDelivery;
      case OrderStatus.delivered:
        return RequestStatus.delivered;
      case OrderStatus.completed:
        return RequestStatus.completed;
      case OrderStatus.cancelled:
        return null;
    }
  }

  int _orderStageRank(OrderStatus status) => switch (status) {
        OrderStatus.submitted => 0,
        OrderStatus.accepted => 1,
        OrderStatus.preparing => 2,
        OrderStatus.readyForDelivery => 3,
        OrderStatus.outForDelivery => 4,
        OrderStatus.delivered => 5,
        OrderStatus.completed => 6,
        OrderStatus.cancelled => 7,
      };

  void _watchCustomerProposals(String customerId) {
    if (_watchedCustomerId == customerId &&
        _customerProposalSubscription != null) {
      return;
    }
    _customerProposalSubscription?.cancel();
    _watchedCustomerId = customerId;
    _customerProposalSubscription = FirebaseFirestore.instance
        .collection('customer_proposals')
        .where('customerId', isEqualTo: customerId)
        .snapshots()
        .listen(
      (_) {
        // A vendor submitted, edited, or withdrew a proposal. Reload the
        // derived request count/status that customer cards display.
        unawaited(loadMyRequests());
      },
      onError: (Object error) {
        state = state.copyWith(error: error.toString());
      },
    );
  }

  @override
  void dispose() {
    _customerProposalSubscription?.cancel();
    _watchedCustomerId = null;
    super.dispose();
  }

  Future<void> loadNearbyRequests() async {
    await _repo.ensureInitialized();
    state = state.copyWith(isLoading: true, clearError: true);
    try {
      final rawRequests = await _repo.getNearbyRequests();
      
      // Dynamic Haversine geofencing filter (radius = 5 km)
      final filteredRequests = rawRequests.where((req) {
        final distance = LocationModel.calculateDistance(
          lat1: req.latitude,
          lon1: req.longitude,
          lat2: state.vendorLatitude,
          lon2: state.vendorLongitude,
        );
        return distance <= 5.0;
      }).map((req) {
        final distance = LocationModel.calculateDistance(
          lat1: req.latitude,
          lon1: req.longitude,
          lat2: state.vendorLatitude,
          lon2: state.vendorLongitude,
        );
        return req.copyWith(approximateDistance: distance);
      }).toList();

      state = state.copyWith(isLoading: false, nearbyRequests: filteredRequests);
    } catch (e) {
      state = state.copyWith(isLoading: false, error: ErrorTranslator.friendly(e));
    }
  }

  Future<void> updateVendorLocation({
    required double latitude,
    required double longitude,
    required String area,
  }) async {
    state = state.copyWith(
      vendorLatitude: latitude,
      vendorLongitude: longitude,
      vendorArea: area,
    );
    await loadNearbyRequests();
  }

  Future<void> createRequest({
    required List<RequestItem> items,
    required String customerArea,
    required String deliveryAddress,
    required double latitude,
    required double longitude,
    DeliveryLocation? deliveryLocation,
  }) async {
    final user = ref.read(currentUserProvider);
    if (user == null) return;

    await _repo.ensureInitialized();
    state = state.copyWith(isLoading: true, clearError: true);
    try {
      final newReq = await _repo.createRequest(
        customerId: user.id,
        items: items,
        customerArea: customerArea,
        deliveryAddress: deliveryAddress,
        latitude: latitude,
        longitude: longitude,
        deliveryLocation: deliveryLocation,
        customerName: user.fullName,
        customerPhone: user.phone,
      );
      state = state.copyWith(
        isLoading: false,
        requests: [newReq, ...state.requests],
      );

      // Notify nearby vendors (persisted) based on vendor locations and categories.
      try {
        final allUsers = await AuthRepository.instance.getAllUsers();
        final requestCats = newReq.categories;

        for (final u in allUsers) {
          if (u.role.name != 'vendor') continue;
          if (u.isActive == false) continue;
          // Ensure vendor has shop coordinates
          final vLat = u.shopLatitude;
          final vLng = u.shopLongitude;
          if (vLat == null || vLng == null) continue;

          final radius = u.assignedRadiusKm ?? 20.0;
          final distance = LocationModel.calculateDistance(
            lat1: newReq.latitude,
            lon1: newReq.longitude,
            lat2: vLat,
            lon2: vLng,
          );
          if (distance > radius) continue;

          // Category match: vendor allowed categories or vendorCategories
          final vendorCatsRaw = u.allowedCategories ?? u.vendorCategories ?? [];
          final vendorCats = vendorCatsRaw.map((c) => VendorCategories.normalize(c)).toSet();
          final matches = requestCats.where((c) => vendorCats.contains(c)).toList();
          if (matches.isEmpty) continue;

          final title = 'New Request Nearby';
          final body = 'A customer in ${newReq.customerArea} submitted a request matching ${matches.take(2).join(', ')}.';

          await ref.read(notification_feature.notificationProvider.notifier).createNotification(
            type: NotificationType.newNearbyRequest,
            title: title,
            body: body,
            userId: u.id,
            relatedId: newReq.id,
            data: {
              'distanceKm': distance,
              'matchedCategories': matches,
              'customerId': newReq.customerId,
            },
          );
        }
      } catch (e) {
        // non-fatal: notification creation failed
        // debugPrint omitted to keep noise low
      }
    } catch (e) {
      state = state.copyWith(isLoading: false, error: ErrorTranslator.friendly(e));
      rethrow;
    }
  }

  /// Cancels a request if still before vendor acceptance.
  Future<ShoppingRequest?> cancelRequest(
    String requestId, {
    String? reason,
  }) async {
    await _repo.ensureInitialized();
    await ProposalRepository.instance.ensureInitialized();
    state = state.copyWith(isLoading: true, clearError: true);
    try {
      final proposals =
          await ProposalRepository.instance.getProposalsForRequest(requestId);
      final hasAccepted =
          proposals.any((p) => p.status == ProposalStatus.accepted);

      final existingIndex =
          state.requests.indexWhere((r) => r.id == requestId);
      if (existingIndex != -1) {
        final existing = state.requests[existingIndex];
        if (!existing.canBeCancelledByCustomer(
            hasAcceptedProposal: hasAccepted)) {
          throw Exception(
            'This request can no longer be cancelled. Contact support if you need help.',
          );
        }
      }

      if (hasAccepted) {
        throw Exception(
          'A vendor proposal has already been accepted for this request.',
        );
      }

      final cancelled = await _repo.cancelRequest(
        requestId,
        reason: reason,
        cancelledBy: 'customer',
      );
      await ProposalRepository.instance.cancelProposalsForRequest(requestId);

      final updatedList = state.requests.map((r) {
        return r.id == requestId ? cancelled : r;
      }).toList();

      state = state.copyWith(isLoading: false, requests: updatedList);
      return cancelled;
    } catch (e) {
      state = state.copyWith(isLoading: false, error: ErrorTranslator.friendly(e));
      rethrow;
    }
  }

  /// Syncs a single updated request into state without a full reload.
  void syncRequest(ShoppingRequest request) {
    final updatedList = state.requests.map((r) {
      return r.id == request.id ? request : r;
    }).toList();
    state = state.copyWith(requests: updatedList);
  }

  /// Updates a request (e.g., for category fulfillment changes)
  Future<void> updateRequest(ShoppingRequest request) async {
    await _repo.ensureInitialized();
    try {
      await _repo.updateRequest(request);
      
      // Update in state
      final updatedList = state.requests.map((r) {
        return r.id == request.id ? request : r;
      }).toList();
      
      state = state.copyWith(requests: updatedList);
    } catch (e) {
      state = state.copyWith(error: ErrorTranslator.friendly(e));
      rethrow;
    }
  }
}

final requestProvider = StateNotifierProvider<RequestNotifier, RequestState>((ref) {
  return RequestNotifier(ref);
});
