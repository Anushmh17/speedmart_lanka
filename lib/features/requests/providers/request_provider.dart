import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../shared/models/location_model.dart';
import '../../auth/providers/auth_provider.dart';
import '../data/mock_request_repository.dart';
import '../../proposals/data/mock_proposal_repository.dart';
import '../../proposals/models/proposal.dart';
import '../models/request_item.dart';
import '../models/shopping_request.dart';
import '../../location/models/delivery_location.dart';

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
    _repo = MockRequestRepository.instance;
    _bootstrap();
  }

  final Ref ref;
  late final MockRequestRepository _repo;

  Future<void> _bootstrap() async {
    await _repo.ensureInitialized();
    await MockProposalRepository.instance.ensureInitialized();
    final user = ref.read(currentUserProvider);
    if (user == null) return;
    if (user.role.name == 'customer') {
      await loadMyRequests();
    } else if (user.role.name == 'vendor') {
      await loadNearbyRequests();
    }
  }

  Future<void> loadMyRequests() async {
    final user = ref.read(currentUserProvider);
    if (user == null) return;

    await _repo.ensureInitialized();
    state = state.copyWith(isLoading: true, clearError: true);
    try {
      final requests = await _repo.getCustomerRequests(user.id);
      state = state.copyWith(isLoading: false, requests: requests);
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
    }
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
      state = state.copyWith(isLoading: false, error: e.toString());
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
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
      rethrow;
    }
  }

  /// Cancels a request if still before vendor acceptance.
  Future<ShoppingRequest?> cancelRequest(
    String requestId, {
    String? reason,
  }) async {
    await _repo.ensureInitialized();
    await MockProposalRepository.instance.ensureInitialized();
    state = state.copyWith(isLoading: true, clearError: true);
    try {
      final proposals =
          await MockProposalRepository.instance.getProposalsForRequest(requestId);
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
      await MockProposalRepository.instance.cancelProposalsForRequest(requestId);

      final updatedList = state.requests.map((r) {
        return r.id == requestId ? cancelled : r;
      }).toList();

      state = state.copyWith(isLoading: false, requests: updatedList);
      return cancelled;
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
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
      state = state.copyWith(error: e.toString());
      rethrow;
    }
  }
}

final requestProvider = StateNotifierProvider<RequestNotifier, RequestState>((ref) {
  return RequestNotifier(ref);
});

