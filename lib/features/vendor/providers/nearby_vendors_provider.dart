import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:speedmart_lanka/features/auth/data/auth_repository.dart';
import 'package:speedmart_lanka/features/location/providers/location_provider.dart';
import 'package:speedmart_lanka/features/location/services/distance_calculation_service.dart';
import 'package:speedmart_lanka/shared/models/user_role.dart';
import 'package:speedmart_lanka/shared/models/vendor_status.dart';

const _distanceCalc = DistanceCalculationService();

/// Returns the count of active vendors within 5 km of the customer's
/// current delivery location. Returns 0 when no location is set.
final nearbyActiveVendorCountProvider = FutureProvider<int>((ref) async {
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
    // If it fails (e.g. security rules or offline), return 0
    return 0;
  }

  final activeVendors = firestoreVendors.where((u) => u.isVendorActive);

  final customerLat = locationState.latitude;
  final customerLon = locationState.longitude;
  const radiusKm = 5.0;

  if (customerLat != null && customerLon != null) {
    return activeVendors.where((v) {
      final vLat = v.shopLatitude;
      final vLon = v.shopLongitude;
      if (vLat == null || vLon == null) return false;
      return _distanceCalc.isWithinRadius(
        originLat: customerLat,
        originLon: customerLon,
        targetLat: vLat,
        targetLon: vLon,
        radiusKm: radiusKm,
      );
    }).length;
  }

  // No location set — cannot determine proximity
  return 0;
});

