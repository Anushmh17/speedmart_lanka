import 'dart:math';

class LocationModel {
  final String name;
  final double latitude;
  final double longitude;

  const LocationModel({
    required this.name,
    required this.latitude,
    required this.longitude,
  });

  /// Popular Sri Lankan cities and suburbs mapped to precise coordinates
  static const List<LocationModel> sriLankanLocations = [
    LocationModel(name: 'Colombo 01 (Fort)', latitude: 6.9344, longitude: 79.8428),
    LocationModel(name: 'Colombo 03 (Colpetty)', latitude: 6.9145, longitude: 79.8510),
    LocationModel(name: 'Colombo 05 (Havelock Town)', latitude: 6.8920, longitude: 79.8660),
    LocationModel(name: 'Dehiwala', latitude: 6.8388, longitude: 79.8767),
    LocationModel(name: 'Nugegoda', latitude: 6.8745, longitude: 79.8890),
    LocationModel(name: 'Rajagiriya', latitude: 6.9100, longitude: 79.8860),
    LocationModel(name: 'Battaramulla', latitude: 6.8989, longitude: 79.9223),
    LocationModel(name: 'Mount Lavinia', latitude: 6.8340, longitude: 79.8670),
    LocationModel(name: 'Negombo (Out-of-bound >20km)', latitude: 7.2089, longitude: 79.8353),
    LocationModel(name: 'Kandy (Out-of-bound >100km)', latitude: 7.2906, longitude: 80.6337),
    LocationModel(name: 'Galle (Out-of-bound >110km)', latitude: 6.0535, longitude: 80.2210),
  ];

  /// Computes distance in kilometers between two sets of coordinates using the Haversine Formula
  static double calculateDistance({
    required double lat1,
    required double lon1,
    required double lat2,
    required double lon2,
  }) {
    const double earthRadiusKm = 6371.0;

    double dLat = _degreesToRadians(lat2 - lat1);
    double dLon = _degreesToRadians(lon2 - lon1);

    double a = sin(dLat / 2) * sin(dLat / 2) +
        cos(_degreesToRadians(lat1)) *
            cos(_degreesToRadians(lat2)) *
            sin(dLon / 2) *
            sin(dLon / 2);

    double c = 2 * atan2(sqrt(a), sqrt(1 - a));
    return earthRadiusKm * c;
  }

  static double _degreesToRadians(double degrees) {
    return degrees * pi / 180;
  }

  /// Finds the nearest predefined Sri Lankan location for a given pair of coordinates
  static LocationModel findNearest(double latitude, double longitude) {
    LocationModel nearest = sriLankanLocations.first;
    double minDistance = double.maxFinite;

    for (final loc in sriLankanLocations) {
      final dist = calculateDistance(
        lat1: latitude,
        lon1: longitude,
        lat2: loc.latitude,
        lon2: loc.longitude,
      );
      if (dist < minDistance) {
        minDistance = dist;
        nearest = loc;
      }
    }
    return nearest;
  }
}

