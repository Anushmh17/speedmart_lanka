import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../../core/services/firestore_service.dart';
import '../../../core/storage/storage_service.dart';
import '../../location/models/delivery_location.dart';
import '../../location/services/location_service.dart';
import '../models/request_item.dart';
import '../models/shopping_request.dart';

/// Shopping request repository — Firestore-backed.
class RequestRepository {
  RequestRepository._();

  static final RequestRepository instance = RequestRepository._();

  static const String _requestsCollectionPath = 'requests';

  Future<void>? _initFuture;
  bool _isInitialized = false;

  final List<ShoppingRequest> _requests = [];

  Future<void> ensureInitialized() {
    if (!_isInitialized) {
      _initFuture = _initialize();
    }
    return _initFuture!;
  }

  CollectionReference<Map<String, dynamic>> get _requestsCollection =>
      FirestoreService.collection(_requestsCollectionPath);

  Future<List<Map<String, dynamic>>> _fetchRequestsFromFirestore() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return [];
    try {
      // Customers: scope to their own requests (rules enforce customerId filter).
      // Vendors: fetch open marketplace statuses (rules require status filter).
      // Admins are handled the same as vendors from the client side; the
      // server-side admin check permits broader access.
      final isCustomer = await _isCustomerSession();
      if (isCustomer) {
        final snap = await _requestsCollection
            .where('customerId', isEqualTo: user.uid)
            .limit(500)
            .get(const GetOptions(source: Source.server));
        return snap.docs
            .map((doc) => {...doc.data(), 'id': doc.id})
            .toList();
      }
      // Vendor / admin: fetch the three open statuses for the marketplace feed.
      final statuses = [
        'submitted',
        'waitingForVendor',
        'proposalSubmitted',
      ];
      final seen = <String>{};
      final results = <Map<String, dynamic>>[];
      for (final status in statuses) {
        final snap = await _requestsCollection
            .where('status', isEqualTo: status)
            .limit(200)
            .get(const GetOptions(source: Source.server));
        for (final doc in snap.docs) {
          if (seen.add(doc.id)) {
            results.add({...doc.data(), 'id': doc.id});
          }
        }
      }
      return results;
    } catch (e) {
      debugPrint('[Request] Failed to load requests from Firestore: $e');
      return [];
    }
  }

  /// Returns true when the current Firebase user has a customer profile.
  Future<bool> _isCustomerSession() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return false;
    try {
      final profile = await FirestoreService.collection('users/customers/profiles')
          .doc(uid)
          .get(const GetOptions(source: Source.server));
      return profile.exists;
    } catch (_) {
      return false;
    }
  }

  Future<void> _syncRequestToFirestore(ShoppingRequest request) async {
    try {
      await _requestsCollection.doc(request.id).set(request.toJson());
    } catch (e) {
      debugPrint('[Request] Failed to sync request ${request.id} to Firestore: $e');
    }
  }

  Future<void> _syncRequestsToFirestore(List<ShoppingRequest> requests) async {
    for (final request in requests) {
      await _syncRequestToFirestore(request);
    }
  }

  Future<void> _initialize() async {
    if (_isInitialized) return;

    // Skip Firestore fetch if no user is authenticated — avoids
    // PERMISSION_DENIED errors on the login screen.
    final firebaseUser = FirebaseAuth.instance.currentUser;
    if (firebaseUser != null) {
      final firestoreRequests = await _fetchRequestsFromFirestore();
      if (firestoreRequests.isNotEmpty) {
        _requests
          ..clear()
          ..addAll(firestoreRequests.map(ShoppingRequest.fromJson));
      } else {
        final saved = await StorageService.getShoppingRequests();
        _requests.addAll(saved.map(ShoppingRequest.fromJson));
      }
      _isInitialized = true;
    }
    // If unauthenticated, do NOT mark initialized so the next
    // ensureInitialized() call after login will re-run properly.
  }

  /// Refreshes the in-memory request cache after a cross-user change, such as
  /// a vendor submitting a proposal. Keep the existing cache on a read error
  /// so a transient Firestore failure does not erase visible requests.
  Future<void> refreshFromFirestore() async {
    if (FirebaseAuth.instance.currentUser == null) return;
    try {
      // Delegate to the same scoped fetch used during initialisation so the
      // correct per-role query (customer vs vendor) is always used.
      final refreshed = await _fetchRequestsFromFirestore();
      _requests
        ..clear()
        ..addAll(refreshed.map(ShoppingRequest.fromJson));
    } catch (e) {
      debugPrint('[Request] Failed to refresh requests from Firestore: $e');
    }
  }

  Future<void> _persistRequests() async {
    await _syncRequestsToFirestore(_requests);
  }

  Future<List<ShoppingRequest>> getCustomerRequests(String customerId) async {
    await ensureInitialized();
    await Future.delayed(const Duration(milliseconds: 300));
    return _requests.where((r) => r.customerId == customerId).toList()
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
  }

  Future<List<ShoppingRequest>> getNearbyRequests() async {
    return getMarketplaceActiveRequests();
  }

  /// Active customer requests visible on the vendor marketplace feed.
  Future<List<ShoppingRequest>> getMarketplaceActiveRequests() async {
    await ensureInitialized();
    await Future.delayed(const Duration(milliseconds: 300));
    final active = _requests
        .where((r) =>
            r.status == RequestStatus.submitted ||
            r.status == RequestStatus.waitingForVendor ||
            r.status == RequestStatus.proposalSubmitted)
        .toList();
    debugPrint('[RequestAudit] Active requests loaded: ${active.length}');
    for (final req in active) {
      debugPrint('[RequestAudit] Request: ${req.id}, area: ${req.customerArea}, lat: ${req.latitude}, lng: ${req.longitude}');
      // [ImageAudit] Repository load
      for (final item in req.items) {
        debugPrint('[ImageAudit] Loaded request: ${req.id}');
        debugPrint('[ImageAudit] Item: ${item.itemName}');
        debugPrint('[ImageAudit] Images: ${item.imageUrls}');
        debugPrint('[ImageAudit] Image count: ${item.imageUrls.length}');
      }
    }
    return active;
  }

  Future<List<ShoppingRequest>> getAllRequests() async {
    await ensureInitialized();
    return List<ShoppingRequest>.unmodifiable(_requests);
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
    bool hasAcceptedProposal = false,
  }) async {
    await ensureInitialized();
    await Future.delayed(const Duration(milliseconds: 300));
    final index = _requests.indexWhere((r) => r.id == requestId);
    if (index == -1) {
      throw Exception('Request not found');
    }

    final current = _requests[index];
    if (!current.canBeCancelledByCustomer(hasAcceptedProposal: hasAcceptedProposal)) {
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

  Future<void> updateRequest(ShoppingRequest request) async {
    await ensureInitialized();
    await Future.delayed(const Duration(milliseconds: 200));
    final index = _requests.indexWhere((r) => r.id == request.id);
    if (index != -1) {
      _requests[index] = request;
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

    debugPrint('[RequestCreate] ===== REQUEST CREATION START =====');
    debugPrint('[RequestCreate] customerId: $customerId');
    debugPrint('[RequestCreate] customerArea: $customerArea');
    debugPrint('[RequestCreate] deliveryAddress: $deliveryAddress');
    debugPrint('[RequestCreate] latitude: $latitude, longitude: $longitude');
    debugPrint('[RequestCreate] deliveryLocation.province: ${deliveryLocation?.province}');
    debugPrint('[RequestCreate] deliveryLocation.district: ${deliveryLocation?.district}');
    debugPrint('[RequestCreate] deliveryLocation.approximateAreaText: ${deliveryLocation?.approximateAreaText}');

    if (latitude == 0.0 ||
        longitude == 0.0 ||
        deliveryLocation?.latitude == null ||
        deliveryLocation?.longitude == null ||
        deliveryLocation?.latitude == 0.0 ||
        deliveryLocation?.longitude == 0.0) {
      debugPrint('[RequestCreate] ===== REJECTION: Missing saved pin coordinates =====');
      throw Exception('Please select a valid delivery location.');
    }

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
      latitude: resolvedLocation.latitude!,
      longitude: resolvedLocation.longitude!,
      deliveryLocation: resolvedLocation,
    );

    debugPrint('[RequestAudit] Request saved: ${newRequest.id}');
    debugPrint('[RequestAudit] Request lat: ${newRequest.latitude}, lng: ${newRequest.longitude}');
    debugPrint('[RequestAudit] Request deliveryLocation: ${newRequest.deliveryLocation?.province}/${newRequest.deliveryLocation?.district}');
    
    // [ImageAudit] Customer uploaded images - Repository save
    for (final item in newRequest.items) {
      debugPrint('[ImageAudit] Saving request: ${newRequest.id}');
      debugPrint('[ImageAudit] Item: ${item.itemName}');
      debugPrint('[ImageAudit] Images: ${item.imageUrls}');
      debugPrint('[ImageAudit] Image count: ${item.imageUrls.length}');
    }

    _requests.insert(0, newRequest);
    await _persistRequests();

    debugPrint('[RequestAudit] Total stored requests: ${_requests.length}');

    return newRequest;
  }
}
