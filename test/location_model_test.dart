import 'package:flutter_test/flutter_test.dart';
import 'package:speedmart_lanka/shared/models/location_model.dart';

void main() {
  group('LocationModel Distance & Geofencing Tests', () {
    test('calculateDistance should correctly compute distance using Haversine formula', () {
      // Coordinates of Colombo Fort (6.9344, 79.8428)
      // Coordinates of Colombo Colpetty (6.9145, 79.8510)
      final distance = LocationModel.calculateDistance(
        lat1: 6.9344,
        lon1: 79.8428,
        lat2: 6.9145,
        lon2: 79.8510,
      );

      // Distance should be approximately 2.38 kilometers
      expect(distance, closeTo(2.38, 0.1));
    });

    test('calculateDistance should return 0.0 for identical coordinates', () {
      final distance = LocationModel.calculateDistance(
        lat1: 6.9145,
        lon1: 79.8510,
        lat2: 6.9145,
        lon2: 79.8510,
      );
      expect(distance, 0.0);
    });

    test('findNearest should map coordinates to the closest suburb', () {
      // A coordinate very close to Havelock Town (6.8920, 79.8660)
      final nearest = LocationModel.findNearest(6.8925, 79.8665);
      expect(nearest.name, 'Colombo 05 (Havelock Town)');

      // A coordinate very close to Mount Lavinia (6.8340, 79.8670)
      final nearestMount = LocationModel.findNearest(6.8335, 79.8675);
      expect(nearestMount.name, 'Mount Lavinia');
    });

    test('geofencing matches: distance to Negombo and Kandy should be out of 20km bounds', () {
      final distanceToNegombo = LocationModel.calculateDistance(
        lat1: 6.9145, // Colombo 03
        lon1: 79.8510,
        lat2: 7.2089, // Negombo
        lon2: 79.8353,
      );

      final distanceToKandy = LocationModel.calculateDistance(
        lat1: 6.9145, // Colombo 03
        lon1: 79.8510,
        lat2: 7.2906, // Kandy
        lon2: 80.6337,
      );

      expect(distanceToNegombo, greaterThan(20.0));
      expect(distanceToKandy, greaterThan(90.0));
    });
  });
}
