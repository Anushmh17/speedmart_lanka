import 'dart:math';
import '../models/request_item.dart';
import '../models/shopping_request.dart';
import '../../location/models/delivery_location.dart';
import '../../location/services/location_service.dart';

class MockRequestRepository {
  static final MockRequestRepository instance = MockRequestRepository._();
  
  final List<ShoppingRequest> _requests = [];

  MockRequestRepository._() {
    // Pre-populate with realistic Sri Lankan requests from other customers for the vendor to see
    _requests.addAll([
      ShoppingRequest(
        id: 'REQ-87421',
        customerId: 'cust-999',
        status: RequestStatus.submitted,
        createdAt: DateTime.now().subtract(const Duration(minutes: 15)),
        customerArea: 'Havelock Town',
        approximateDistance: 2.3,
        latitude: 6.8920,
        longitude: 79.8660,
        customerName: 'Chaminda Silva',
        customerPhone: '+94 77 123 4567',
        deliveryAddress: '12/A, Havelock Road, Colombo 05',
        deliveryLocation: LocationService.reverseGeocode(
          latitude: 6.8920,
          longitude: 79.8660,
          streetAddress: '12/A, Havelock Road, Colombo 05',
        ),
        items: [
          RequestItem(
            id: 'item-101',
            name: 'Keells Fresh Milk 1L',
            quantity: 2,
            category: 'Groceries',
            preferredBrand: 'Keells / Anchor',
            description: 'Please check the expiry date. Needs to be at least 1 week.',
          ),
          RequestItem(
            id: 'item-102',
            name: 'Fortune Coconut Oil 1L',
            quantity: 1,
            category: 'Groceries',
            preferredBrand: 'Fortune',
          ),
          RequestItem(
            id: 'item-103',
            name: 'Harischandra Coffee 200g',
            quantity: 1,
            category: 'Groceries',
            preferredBrand: 'Harischandra',
          ),
        ],
      ),
      ShoppingRequest(
        id: 'REQ-65108',
        customerId: 'cust-998',
        status: RequestStatus.submitted,
        createdAt: DateTime.now().subtract(const Duration(hours: 1)),
        customerArea: 'Dehiwala',
        approximateDistance: 4.8,
        latitude: 6.8388,
        longitude: 79.8767,
        customerName: 'Rukshan Perera',
        customerPhone: '+94 71 987 6543',
        deliveryAddress: '45/2, Hill Street, Dehiwala',
        deliveryLocation: LocationService.reverseGeocode(
          latitude: 6.8388,
          longitude: 79.8767,
          streetAddress: '45/2, Hill Street, Dehiwala',
        ),
        items: [
          RequestItem(
            id: 'item-201',
            name: 'Toyota Vitz 2017 Air Filter',
            quantity: 1,
            category: 'Vehicle parts',
            preferredBrand: 'Toyota Genuine / Sakura',
          ),
          RequestItem(
            id: 'item-202',
            name: 'Denso Spark Plug',
            quantity: 4,
            category: 'Vehicle parts',
            preferredBrand: 'Denso',
            description: 'Model: SC16HR11 or compatible.',
          ),
        ],
      ),
      ShoppingRequest(
        id: 'REQ-32104',
        customerId: 'cust-997',
        status: RequestStatus.submitted,
        createdAt: DateTime.now().subtract(const Duration(hours: 2)),
        customerArea: 'Nugegoda',
        approximateDistance: 6.2,
        latitude: 6.8745,
        longitude: 79.8890,
        customerName: 'Nimal Siriwardena',
        customerPhone: '+94 72 444 5555',
        deliveryAddress: '102 High Level Rd, Nugegoda',
        deliveryLocation: LocationService.reverseGeocode(
          latitude: 6.8745,
          longitude: 79.8890,
          streetAddress: '102 High Level Rd, Nugegoda',
        ),
        items: [
          RequestItem(
            id: 'item-301',
            name: 'S-lon PVC Pipe 1/2 inch (10ft)',
            quantity: 5,
            category: 'Hardware items',
            preferredBrand: 'S-lon',
          ),
          RequestItem(
            id: 'item-302',
            name: 'CIC Paint White 4L',
            quantity: 1,
            category: 'Hardware items',
            preferredBrand: 'CIC Weathercoat',
            description: 'Brilliant white, interior/exterior.',
          ),
        ],
      ),
    ]);
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
