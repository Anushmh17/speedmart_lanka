import 'dart:math';

import '../../../core/storage/storage_service.dart';
import '../../location/models/delivery_location.dart';
import '../../location/services/location_service.dart';
import '../models/request_item.dart';
import '../models/shopping_request.dart';

/// Mock shopping request repository with local persistence.
/// TODO: Replace local mock request persistence with backend API.
class MockRequestRepository {
  MockRequestRepository._() {
    _initFuture = _initialize();
  }

  static final MockRequestRepository instance = MockRequestRepository._();

  late final Future<void> _initFuture;
  bool _isInitialized = false;

  final List<ShoppingRequest> _requests = [];

  Future<void> ensureInitialized() => _initFuture;

  Future<void> _initialize() async {
    if (_isInitialized) return;

    final saved = await StorageService.getShoppingRequests();
    if (saved.isNotEmpty) {
      _requests
        ..clear()
        ..addAll(saved.map(ShoppingRequest.fromJson));
    }

    _isInitialized = true;
  }

  Future<void> _persistRequests() async {
    await StorageService.saveShoppingRequests(
      _requests.map((r) => r.toJson()).toList(),
    );
  }

  Future<List<ShoppingRequest>> getCustomerRequests(String customerId) async {
    await ensureInitialized();
    await Future.delayed(const Duration(milliseconds: 300));
    return _requests.where((r) => r.customerId == customerId).toList()
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
  }

  Future<List<ShoppingRequest>> getNearbyRequests() async {
    await ensureInitialized();
    await Future.delayed(const Duration(milliseconds: 300));
    return _requests
        .where((r) =>
            r.status == RequestStatus.submitted ||
            r.status == RequestStatus.waitingForVendor)
        .toList();
  }

  Future<ShoppingRequest?> getRequestById(String id) async {
    await ensureInitialized();
    await Future.delayed(const Duration(milliseconds: 200));
    try {
      return _requests.firstWhere((r) => r.id == id);
    } catch (_) {
      return null;
    }
  }

  Future<ShoppingRequest> cancelRequest(
    String requestId, {
    String? reason,
    String cancelledBy = 'customer',
  }) async {
    await ensureInitialized();
    await Future.delayed(const Duration(milliseconds: 300));
    final index = _requests.indexWhere((r) => r.id == requestId);
    if (index == -1) {
      throw Exception('Request not found');
    }

    final current = _requests[index];
    if (!current.status.canBeCancelledByCustomer) {
      throw Exception(
        'This request can no longer be cancelled. Contact support if you need help.',
      );
    }

    final now = DateTime.now();
    final cancelled = current.copyWith(
      status: RequestStatus.cancelled,
      updatedAt: now,
      cancelledAt: now,
      cancelledReason: reason,
      cancelledBy: cancelledBy,
    );
    _requests[index] = cancelled;
    await _persistRequests();

    return cancelled;
  }

  Future<void> updateRequestStatus(String requestId, RequestStatus status) async {
    await ensureInitialized();
    await Future.delayed(const Duration(milliseconds: 200));
    final index = _requests.indexWhere((r) => r.id == requestId);
    if (index != -1) {
      _requests[index] = _requests[index].copyWith(
        status: status,
        updatedAt: DateTime.now(),
      );
      await _persistRequests();
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
    String? customerName,
    String? customerPhone,
  }) async {
    await ensureInitialized();
    await Future.delayed(const Duration(milliseconds: 500));
    final resolvedLocation = deliveryLocation ??
        LocationService.reverseGeocode(
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
      customerArea: customerArea.isNotEmpty
          ? customerArea
          : resolvedLocation.suburb,
      deliveryAddress: resolvedLocation.streetAddress,
      customerPhone: customerPhone ?? '',
      customerName: customerName ?? '',
      approximateDistance: 0.0,
      latitude: resolvedLocation.latitude ?? latitude,
      longitude: resolvedLocation.longitude ?? longitude,
      deliveryLocation: resolvedLocation,
    );
    _requests.insert(0, newRequest);
    await _persistRequests();
    return newRequest;
  }
}
