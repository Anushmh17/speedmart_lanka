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
  
  // Fetch active, approved vendors from Firestore directly. 
  // The local AuthRepository cache only contains the currently logged-in user.
  final firestoreVendors = <UserModel>[];
  try {
    final snapshot = await FirebaseFirestore.instance
        .collection('users/vendors/profiles')
        .where('vendor_status', isEqualTo: VendorStatus.approved.name)
        .where('is_active', isEqualTo: true)
        .get();
    for (final doc in snapshot.docs) {
      firestoreVendors.add(UserModel.fromJson({...doc.data(), 'id': doc.id}));
    }
  } catch (e) {
    // If it fails (e.g. security rules or offline), return empty list
    return [];
  }

  final activeVendors = firestoreVendors.where((u) => u.isVendorActive).toList();

  final customerLat = locationState.latitude;
  final customerLon = locationState.longitude;

  if (customerLat != null && customerLon != null) {
    return activeVendors.where((v) {
      final vLat = v.shopLatitude;
      final vLon = v.shopLongitude;
      if (vLat == null || vLon == null) return false;
      
      // Use the vendor's admin-assigned radius, or default to 5km
      final vendorRadius = v.assignedRadiusKm ?? 5.0;
      
      return _distanceCalc.isWithinRadius(
        originLat: customerLat,
        originLon: customerLon,
        targetLat: vLat,
        targetLon: vLon,
        radiusKm: vendorRadius,
      );
    }).toList();
  }

  // No location set — cannot determine proximity
  return [];
});

/// Returns the count of nearby active vendors for backwards compatibility
final nearbyActiveVendorCountProvider = FutureProvider<int>((ref) async {
  final vendors = await ref.watch(nearbyActiveVendorsProvider.future);
  return vendors.length;
});

