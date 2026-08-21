import 'package:flutter/foundation.dart' show debugPrint;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:speedmart_lanka/features/auth/data/auth_repository.dart';
import 'package:speedmart_lanka/features/location/providers/location_provider.dart';
import 'package:speedmart_lanka/features/location/services/distance_calculation_service.dart';
import 'package:speedmart_lanka/shared/models/user_role.dart';
import 'package:speedmart_lanka/shared/models/vendor_status.dart';
import 'package:speedmart_lanka/shared/models/user_model.dart';

const _distanceCalc = DistanceCalculationService();

/// Returns the list of active vendors within their respective radii of the customer's
/// current delivery location. Returns empty list when no location is set.
final nearbyActiveVendorsProvider = FutureProvider<List<UserModel>>((ref) async {
  final locationState = ref.watch(locationProvider);
  
  // Fetch from vendor_discovery — a lightweight public collection containing only
  // non-sensitive proximity fields. Customers are allowed to read this.
  final firestoreVendors = <UserModel>[];
  try {
    final snapshot = await FirebaseFirestore.instance
        .collection('vendor_discovery')
        .where('vendor_status', isEqualTo: VendorStatus.approved.name)
        .where('is_active', isEqualTo: true)
        .get();
    debugPrint('[NearbyVendors] vendor_discovery returned ${snapshot.docs.length} docs');
    for (final doc in snapshot.docs) {
      // vendor_discovery only has proximity fields — build a minimal UserModel
      final data = doc.data();
      final user = UserModel(
        id: doc.id,
        fullName: '',
        email: '',
        phone: '',
        role: UserRole.vendor,
        isActive: data['is_active'] as bool? ?? false,
        isVerified: true,
        createdAt: DateTime.now(),
        vendorStatus: VendorStatus.values.asNameMap()[data['vendor_status'] as String?] ?? VendorStatus.pendingApproval,
        allowedCategories: (data['allowed_categories'] as List<dynamic>?)?.cast<String>(),
        vendorCategories: (data['vendor_categories'] as List<dynamic>?)?.cast<String>(),
        shopLatitude: (data['shop_latitude'] as num?)?.toDouble(),
        shopLongitude: (data['shop_longitude'] as num?)?.toDouble(),
        assignedRadiusKm: (data['assigned_radius_km'] as num?)?.toDouble(),
        isShopLocationAssigned: data['is_shop_location_assigned'] as bool?,
      );
      debugPrint('[NearbyVendors] Discovery doc ${doc.id}: isVendorActive=${user.isVendorActive}, shopLat=${user.shopLatitude}, shopLon=${user.shopLongitude}, assignedRadius=${user.assignedRadiusKm}, cats=${user.allowedCategories}');
      firestoreVendors.add(user);
    }
  } catch (e) {
    debugPrint('[NearbyVendors] *** ERROR reading vendor_discovery: $e');
    return [];
  }

  final activeVendors = firestoreVendors.where((u) => u.isVendorActive).toList();
  debugPrint('[NearbyVendors] After isVendorActive filter: ${activeVendors.length} vendors');

  final customerLat = locationState.latitude;
  final customerLon = locationState.longitude;
  debugPrint('[NearbyVendors] Customer location: lat=$customerLat, lon=$customerLon');

  if (customerLat != null && customerLon != null) {
    final nearby = activeVendors.where((v) {
      final vLat = v.shopLatitude;
      final vLon = v.shopLongitude;
      if (vLat == null || vLon == null) return false;
      
      // Use the vendor's admin-assigned radius, or default to 5km
      final vendorRadius = v.assignedRadiusKm ?? 5.0;
      final within = _distanceCalc.isWithinRadius(
        originLat: customerLat,
        originLon: customerLon,
        targetLat: vLat,
        targetLon: vLon,
        radiusKm: vendorRadius,
      );
      final dist = _distanceCalc.distanceKm(lat1: customerLat, lon1: customerLon, lat2: vLat, lon2: vLon);
      debugPrint('[NearbyVendors] Vendor ${v.id}: distance=${dist.toStringAsFixed(2)}km, radius=${vendorRadius}km, withinRadius=$within');
      return within;
    }).toList();
    debugPrint('[NearbyVendors] Final nearby count: ${nearby.length}');
    return nearby;
  }

  debugPrint('[NearbyVendors] No customer location set — returning empty list');
  // No location set — cannot determine proximity
  return [];
});

/// Returns the count of nearby active vendors for backwards compatibility
final nearbyActiveVendorCountProvider = FutureProvider<int>((ref) async {
  final vendors = await ref.watch(nearbyActiveVendorsProvider.future);
  return vendors.length;
});

