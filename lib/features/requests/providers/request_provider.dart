import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../shared/models/location_model.dart';
import '../../auth/providers/auth_provider.dart';
import '../data/mock_request_repository.dart';
import '../models/request_item.dart';
import '../models/shopping_request.dart';

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
    final user = ref.read(currentUserProvider);
    if (user != null) {
      if (user.role.name == 'customer') {
        loadMyRequests();
      } else if (user.role.name == 'vendor') {
        loadNearbyRequests();
      }
    }
  }

  final Ref ref;
  late final MockRequestRepository _repo;

  Future<void> loadMyRequests() async {
    final user = ref.read(currentUserProvider);
    if (user == null) return;

    state = state.copyWith(isLoading: true, clearError: true);
    try {
      final requests = await _repo.getCustomerRequests(user.id);
      state = state.copyWith(isLoading: false, requests: requests);
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
    }
  }

  Future<void> loadNearbyRequests() async {
    state = state.copyWith(isLoading: true, clearError: true);
    try {
      final rawRequests = await _repo.getNearbyRequests();
      
      // Dynamic Haversine geofencing filter (radius = 20 km)
      final filteredRequests = rawRequests.where((req) {
        final distance = LocationModel.calculateDistance(
          lat1: req.latitude,
          lon1: req.longitude,
          lat2: state.vendorLatitude,
          lon2: state.vendorLongitude,
        );
        return distance <= 20.0;
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
  }) async {
    final user = ref.read(currentUserProvider);
    if (user == null) return;

    state = state.copyWith(isLoading: true, clearError: true);
    try {
      final newReq = await _repo.createRequest(
        customerId: user.id,
        items: items,
        customerArea: customerArea,
        deliveryAddress: deliveryAddress,
        latitude: latitude,
        longitude: longitude,
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
}

final requestProvider = StateNotifierProvider<RequestNotifier, RequestState>((ref) {
  return RequestNotifier(ref);
});
