import 'dart:math';

/// Pure Haversine distance calculation utility.
///
/// No dependencies — can be used anywhere in the app.
/// All methods are static; this class is never instantiated.
class Haversine {
  Haversine._();

  static const double _earthRadiusKm = 6371.0;

  /// Returns the great-circle distance in **kilometres** between two points.
  ///
  /// [lat1], [lon1] – origin coordinates (decimal degrees)
  /// [lat2], [lon2] – destination coordinates (decimal degrees)
  static double distanceKm({
    required double lat1,
    required double lon1,
    required double lat2,
    required double lon2,
  }) {
    final dLat = _toRad(lat2 - lat1);
    final dLon = _toRad(lon2 - lon1);

    final a = sin(dLat / 2) * sin(dLat / 2) +
        cos(_toRad(lat1)) * cos(_toRad(lat2)) * sin(dLon / 2) * sin(dLon / 2);

    final c = 2 * atan2(sqrt(a), sqrt(1 - a));
    return _earthRadiusKm * c;
  }

  /// Returns the distance in **metres**.
  static double distanceMetres({
    required double lat1,
    required double lon1,
    required double lat2,
    required double lon2,
  }) =>
      distanceKm(lat1: lat1, lon1: lon1, lat2: lat2, lon2: lon2) * 1000;

  /// Returns true if the destination point is within [radiusKm] of the origin.
  static bool isWithinRadius({
    required double originLat,
    required double originLon,
    required double targetLat,
    required double targetLon,
    required double radiusKm,
  }) =>
      distanceKm(
        lat1: originLat,
        lon1: originLon,
        lat2: targetLat,
        lon2: targetLon,
      ) <=
      radiusKm;

  static double _toRad(double degrees) => degrees * pi / 180;
}

