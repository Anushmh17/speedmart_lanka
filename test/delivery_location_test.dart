import 'package:flutter_test/flutter_test.dart';
import 'package:speedmart_lanka/features/location/models/delivery_location.dart';
import 'package:speedmart_lanka/features/location/services/location_service.dart';
import 'package:speedmart_lanka/features/requests/providers/draft_provider.dart';

void main() {
  group('DeliveryLocation and LocationService Tests', () {
    test('LocationService.reverseGeocode resolves Sri Lankan coordinates', () {
      // Colombo 03 / Colpetty coords
      final location = LocationService.reverseGeocode(
        latitude: 6.9145,
        longitude: 79.8510,
        streetAddress: '45 Galle Rd',
      );

      expect(location.suburb, equals('Colpetty'));
      expect(location.city, equals('Colombo 03'));
      expect(location.district, equals('Colombo'));
      expect(location.province, equals('Western'));
      expect(location.latitude, equals(6.9145));
      expect(location.longitude, equals(79.8510));
    });

    test('LocationService.reverseGeocode resolves Jaffna coordinates', () {
      // Jaffna Town coords
      final location = LocationService.reverseGeocode(
        latitude: 9.6615,
        longitude: 80.0255,
      );

      expect(location.district, equals('Jaffna'));
      expect(location.province, equals('Northern'));
    });

    test('LocationService.calculateDistance calculates correct Haversine distance', () {
      // Distance between Colombo 03 (6.9145, 79.8510) and Galle Face (6.9271, 79.8485)
      final distance = LocationService.calculateDistance(
        lat1: 6.9145,
        lon1: 79.8510,
        lat2: 6.9271,
        lon2: 79.8485,
      );
      expect(distance, closeTo(1.42, 0.1)); // ~1.4 km
    });

    test('LocationService.searchSuburbs searches properly', () {
      final colpettySearch = LocationService.searchSuburbs('Colp');
      expect(colpettySearch.any((s) => s.name == 'Colpetty'), isTrue);

      final negomboSearch = LocationService.searchSuburbs('Negombo');
      expect(negomboSearch.any((s) => s.city == 'Negombo'), isTrue);
    });

    test('DeliveryLocation JSON serialization/deserialization', () {
      final original = const DeliveryLocation(
        province: 'Western',
        district: 'Colombo',
        city: 'Colombo 03',
        suburb: 'Colpetty',
        formattedAddress: 'Colpetty, Colombo 03',
        streetAddress: '123 Galle Rd',
        latitude: 6.9145,
        longitude: 79.8510,
      );

      final json = original.toJson();
      final decoded = DeliveryLocation.fromJson(json);

      expect(decoded.province, equals(original.province));
      expect(decoded.district, equals(original.district));
      expect(decoded.city, equals(original.city));
      expect(decoded.suburb, equals(original.suburb));
      expect(decoded.formattedAddress, equals(original.formattedAddress));
      expect(decoded.streetAddress, equals(original.streetAddress));
      expect(decoded.latitude, equals(original.latitude));
      expect(decoded.longitude, equals(original.longitude));
    });

    test('DeliveryLocation with nullable coordinates', () {
      final manualLocation = const DeliveryLocation(
        province: '',
        district: '',
        city: '',
        suburb: '',
        formattedAddress: '',
        streetAddress: '45 Custom Road',
        approximateAreaText: 'My Custom Area',
        source: 'manual',
        isManualOverride: true,
      );

      expect(manualLocation.latitude, isNull);
      expect(manualLocation.longitude, isNull);
      expect(manualLocation.hasCoordinates, isFalse);
      expect(manualLocation.approximateAreaText, equals('My Custom Area'));
      expect(manualLocation.source, equals('manual'));
    });

    test('DeliveryLocation.hasCoordinates and displayArea', () {
      final withCoords = const DeliveryLocation(
        province: 'Western',
        district: 'Colombo',
        city: 'Colombo 03',
        suburb: 'Colpetty',
        formattedAddress: 'Colpetty, Colombo 03',
        streetAddress: '',
        latitude: 6.9145,
        longitude: 79.8510,
        source: 'gps',
      );

      expect(withCoords.hasCoordinates, isTrue);
      expect(withCoords.displayArea, equals('Colpetty, Colombo 03'));

      final manualOnly = const DeliveryLocation(
        province: '',
        district: '',
        city: '',
        suburb: '',
        formattedAddress: '',
        streetAddress: '',
        approximateAreaText: 'Near Kandy Lake',
        source: 'manual',
      );

      expect(manualOnly.hasCoordinates, isFalse);
      expect(manualOnly.displayArea, equals('Near Kandy Lake'));
    });

    test('DeliveryLocation JSON round-trip with null coordinates', () {
      final original = const DeliveryLocation(
        province: 'Central',
        district: 'Kandy',
        city: 'Kandy',
        suburb: '',
        formattedAddress: '',
        streetAddress: '10 Temple St',
        approximateAreaText: 'Near Temple of Tooth',
        source: 'manual',
        isManualOverride: true,
      );

      final json = original.toJson();
      expect(json['latitude'], isNull);
      expect(json['longitude'], isNull);
      expect(json['approximateAreaText'], equals('Near Temple of Tooth'));
      expect(json['source'], equals('manual'));

      final decoded = DeliveryLocation.fromJson(json);
      expect(decoded.latitude, isNull);
      expect(decoded.longitude, isNull);
      expect(decoded.hasCoordinates, isFalse);
      expect(decoded.approximateAreaText, equals('Near Temple of Tooth'));
      expect(decoded.source, equals('manual'));
    });

    test('DraftService.hasValidDraft validation rules', () {
      // Empty draft
      expect(DraftService.hasValidDraft(null), isFalse);
      expect(DraftService.hasValidDraft({}), isFalse);

      // Draft with only default/mock properties
      expect(DraftService.hasValidDraft({
        'requestType': 'single',
        'singleQty': 1,
        'singleUnit': 'kg',
      }), isFalse);

      // Draft with meaningful location
      expect(DraftService.hasValidDraft({
        'deliveryLocation': {
          'province': 'Western',
          'district': 'Colombo',
          'city': 'Colombo 03',
          'suburb': 'Colpetty',
          'formattedAddress': 'Colpetty, Colombo 03',
          'streetAddress': '',
        }
      }), isTrue);

      // Draft with street address
      expect(DraftService.hasValidDraft({
        'deliveryAddress': '123 Flower Rd'
      }), isTrue);

      // Draft with item name
      expect(DraftService.hasValidDraft({
        'singleName': 'Banana'
      }), isTrue);

      // Draft with category
      expect(DraftService.hasValidDraft({
        'singleCategory': 'Fruits'
      }), isTrue);

      // Draft with quantity != 1
      expect(DraftService.hasValidDraft({
        'singleQty': 5
      }), isTrue);

      // Draft with multiple items
      expect(DraftService.hasValidDraft({
        'multipleItems': [{'itemName': 'Apples', 'quantity': 1}]
      }), isTrue);
    });

    test('DraftService.isFormDirty validation rules', () {
      // Clean/default state
      expect(DraftService.isFormDirty(
        deliveryLocation: null,
        suburbText: '',
        addressText: '',
        requestTypeName: 'single',
        singleCategory: null,
        singleName: '',
        singleQuantity: 1,
        singleBrand: '',
        singleDesc: '',
        singleImageUrls: [],
        multipleItems: [],
      ), isFalse);

      // Dirty with suburb search text
      expect(DraftService.isFormDirty(
        deliveryLocation: null,
        suburbText: 'Negombo',
        addressText: '',
        requestTypeName: 'single',
        singleCategory: null,
        singleName: '',
        singleQuantity: 1,
        singleBrand: '',
        singleDesc: '',
        singleImageUrls: [],
        multipleItems: [],
      ), isTrue);

      // Dirty with singleName
      expect(DraftService.isFormDirty(
        deliveryLocation: null,
        suburbText: '',
        addressText: '',
        requestTypeName: 'single',
        singleCategory: null,
        singleName: 'Rice',
        singleQuantity: 1,
        singleBrand: '',
        singleDesc: '',
        singleImageUrls: [],
        multipleItems: [],
      ), isTrue);

      // Dirty with multiple items list
      expect(DraftService.isFormDirty(
        deliveryLocation: null,
        suburbText: '',
        addressText: '',
        requestTypeName: 'multiple',
        singleCategory: null,
        singleName: '',
        singleQuantity: 1,
        singleBrand: '',
        singleDesc: '',
        singleImageUrls: [],
        multipleItems: ['some_item'],
      ), isTrue);
    });
  });
}
