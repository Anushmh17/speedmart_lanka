import '../utils/haversine.dart';

/// Named wrapper around [Haversine] for use across business-logic layers.
///
/// Using this service (rather than calling [Haversine] directly) means
/// callers depend on an injectable class, making future testing / mocking easier.
class DistanceCalculationService {
  const DistanceCalculationService();

  /// Returns the distance in kilometres between two coordinate pairs.
  double distanceKm({
    required double lat1,
    required double lon1,
    required double lat2,
    required double lon2,
  }) =>
      Haversine.distanceKm(lat1: lat1, lon1: lon1, lat2: lat2, lon2: lon2);

  /// Returns the distance in metres.
  double distanceMetres({
    required double lat1,
    required double lon1,
    required double lat2,
    required double lon2,
  }) =>
      Haversine.distanceMetres(lat1: lat1, lon1: lon1, lat2: lat2, lon2: lon2);

  /// Returns true when [target] falls within [radiusKm] of [origin].
  bool isWithinRadius({
    required double originLat,
    required double originLon,
    required double targetLat,
    required double targetLon,
    required double radiusKm,
  }) =>
      Haversine.isWithinRadius(
        originLat: originLat,
        originLon: originLon,
        targetLat: targetLat,
        targetLon: targetLon,
        radiusKm: radiusKm,
      );

  /// Given an origin and a list of targets (each with lat/lon), returns the
  /// closest target index and its distance in km.
  ///
  /// Returns null when [targets] is empty.
  ({int index, double distanceKm})? findNearest({
    required double originLat,
    required double originLon,
    required List<({double lat, double lon})> targets,
  }) {
    if (targets.isEmpty) return null;

    int nearestIndex = 0;
    double minDist = double.maxFinite;

    for (int i = 0; i < targets.length; i++) {
      final d = Haversine.distanceKm(
        lat1: originLat,
        lon1: originLon,
        lat2: targets[i].lat,
        lon2: targets[i].lon,
      );
      if (d < minDist) {
        minDist = d;
        nearestIndex = i;
      }
    }

    return (index: nearestIndex, distanceKm: minDist);
  }

  /// Filters [targets] to only those within [radiusKm] of the origin,
  /// sorted by distance ascending.
  List<({int index, double distanceKm})> filterWithinRadius({
    required double originLat,
    required double originLon,
    required List<({double lat, double lon})> targets,
    required double radiusKm,
  }) {
    final results = <({int index, double distanceKm})>[];

    for (int i = 0; i < targets.length; i++) {
      final d = Haversine.distanceKm(
        lat1: originLat,
        lon1: originLon,
        lat2: targets[i].lat,
        lon2: targets[i].lon,
      );
      if (d <= radiusKm) {
        results.add((index: i, distanceKm: d));
      }
    }

    results.sort((a, b) => a.distanceKm.compareTo(b.distanceKm));
    return results;
  }

  /// Human-readable distance label, e.g. "3.2 km" or "450 m".
  String formatDistance(double km) {
    if (km < 1.0) {
      return '${(km * 1000).round()} m';
    }
    return '${km.toStringAsFixed(1)} km';
  }
}

