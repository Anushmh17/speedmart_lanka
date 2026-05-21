import 'dart:math';
import '../models/request_item.dart';
import '../models/shopping_request.dart';
import '../../location/models/delivery_location.dart';
import '../../location/services/location_service.dart';

class MockRequestRepository {
  static final MockRequestRepository instance = MockRequestRepository._();
  
  final List<ShoppingRequest> _requests = [];

  MockRequestRepository._() {
    // Start with empty list to ensure no mock locations appear in the system.
  }

  Future<List<ShoppingRequest>> getCustomerRequests(String customerId) async {
    await Future.delayed(const Duration(milliseconds: 800));
    return _requests.where((r) => r.customerId == customerId).toList();
  }

  // Get active requests within a certain radius (e.g. 20 km) for vendors
  Future<List<ShoppingRequest>> getNearbyRequests() async {
    await Future.delayed(const Duration(milliseconds: 800));
    // Filter only those that are submitted/waiting for vendor and within radius (all mock requests are configured under 20km)
    return _requests
        .where((r) => r.status == RequestStatus.submitted || r.status == RequestStatus.waitingForVendor)
        .toList();
  }

  // Get a single request by ID
  Future<ShoppingRequest?> getRequestById(String id) async {
    await Future.delayed(const Duration(milliseconds: 300));
    try {
      return _requests.firstWhere((r) => r.id == id);
    } catch (_) {
      return null;
    }
  }

  // Update request status
  Future<void> updateRequestStatus(String requestId, RequestStatus status) async {
    await Future.delayed(const Duration(milliseconds: 400));
    final index = _requests.indexWhere((r) => r.id == requestId);
    if (index != -1) {
      _requests[index] = _requests[index].copyWith(
        status: status,
        updatedAt: DateTime.now(),
      );
    }
  }

  Future<ShoppingRequest> createRequest({
    required String customerId,
    required List<RequestItem> items,
    required String customerArea,
    required String deliveryAddress,
    required double latitude,
    required double longitude,
    DeliveryLocation? deliveryLocation,
  }) async {
    await Future.delayed(const Duration(milliseconds: 1000));
    final resolvedLocation = deliveryLocation ?? LocationService.reverseGeocode(
      latitude: latitude,
      longitude: longitude,
      streetAddress: deliveryAddress,
    );
    final newRequest = ShoppingRequest(
      id: 'REQ-${Random().nextInt(90000) + 10000}',
      customerId: customerId,
      items: items,
      status: RequestStatus.submitted,
      createdAt: DateTime.now(),
      customerArea: resolvedLocation.suburb,
      deliveryAddress: resolvedLocation.streetAddress,
      customerPhone: '+94 77 999 8888',
      customerName: 'Anush Hewage',
      approximateDistance: 1.5,
      latitude: resolvedLocation.latitude ?? 0.0,
      longitude: resolvedLocation.longitude ?? 0.0,
      deliveryLocation: resolvedLocation,
    );
    _requests.insert(0, newRequest);
    return newRequest;
  }
}
