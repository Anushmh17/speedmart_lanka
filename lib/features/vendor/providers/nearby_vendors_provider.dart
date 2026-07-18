import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:speedmart_lanka/features/auth/data/mock_auth_repository.dart';
import 'package:speedmart_lanka/features/location/providers/location_provider.dart';
import 'package:speedmart_lanka/features/location/services/distance_calculation_service.dart';
import 'package:speedmart_lanka/shared/models/user_role.dart';
import 'package:speedmart_lanka/shared/models/vendor_status.dart';

const _distanceCalc = DistanceCalculationService();

/// Returns the count of active vendors within 5 km of the customer's
/// current delivery location. Returns 0 when no location is set.
final nearbyActiveVendorCountProvider = FutureProvider<int>((ref) async {
  final locationState = ref.watch(locationProvider);
  final allUsers = await MockAuthRepository.instance.getAllUsers();

  final activeVendors = allUsers.where((u) =>
      u.role == UserRole.vendor &&
      u.vendorStatus == VendorStatus.approved &&
      u.isActive &&
      u.isVendorActive);

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

