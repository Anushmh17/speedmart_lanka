import 'package:speedmart_lanka/features/location/models/delivery_location.dart';
import 'package:speedmart_lanka/features/location/data/sri_lanka_data.dart';

/// Utility to determine whether a [DeliveryLocation] is likely in Sri Lanka.
///
/// Used by the request submission gatekeeping to decide whether an
/// international customer needs phone verification before submitting.
class SriLankaDeliveryDetector {
  SriLankaDeliveryDetector._();

  // Sri Lanka geographic bounding box
  static const double _lkLatMin = 5.80;
  static const double _lkLatMax = 10.00;
  static const double _lkLonMin = 79.30;
  static const double _lkLonMax = 82.10;

  /// Returns `true` if the delivery location is likely in Sri Lanka.
  ///
  /// Checks in order:
  /// 1. Province/district match against known Sri Lanka data
  /// 2. GPS coordinates inside Sri Lanka bounds
  /// 3. Address text containing Sri Lankan location names
  static bool isSriLankanDelivery(DeliveryLocation? location) {
    if (location == null) return false;

    // Check 1: Province or district from Sri Lanka data
    if (_hasKnownSriLankanArea(location)) return true;

    // Check 2: GPS coordinates inside Sri Lanka bounds
    if (_isInsideSriLankaBounds(location)) return true;

    // Check 3: Text-based heuristic on address fields
    if (_addressContainsSriLankanNames(location)) return true;

    return false;
  }

  static bool _hasKnownSriLankanArea(DeliveryLocation location) {
    if (location.province.isEmpty && location.district.isEmpty) return false;

    // Check against known province names
    if (location.province.isNotEmpty) {
      final match = SriLankaData.provinceByName(location.province);
      if (match != null) return true;
    }

    // Check against known district names
    if (location.district.isNotEmpty) {
      final match = SriLankaData.districtByName(location.district);
      if (match != null) return true;
    }

    return false;
  }

  static bool _isInsideSriLankaBounds(DeliveryLocation location) {
    if (!location.hasCoordinates) return false;
    final lat = location.latitude!;
    final lon = location.longitude!;
    return lat >= _lkLatMin &&
        lat <= _lkLatMax &&
        lon >= _lkLonMin &&
        lon <= _lkLonMax;
  }

  static bool _addressContainsSriLankanNames(DeliveryLocation location) {
    // Combine all text fields for searching
    final searchText = [
      location.formattedAddress,
      location.approximateAreaText,
      location.suburb,
      location.city,
      location.preciseAddress,
      location.streetAddress,
    ].join(' ').toLowerCase();

    if (searchText.trim().isEmpty) return false;

    // Check for "sri lanka" in any address field
    if (searchText.contains('sri lanka')) return true;

    // Check against all known province names
    for (final p in SriLankaData.provinces) {
      if (searchText.contains(p.name.toLowerCase())) return true;
    }

    // Check against all known district names
    for (final d in SriLankaData.districts) {
      if (searchText.contains(d.name.toLowerCase())) return true;
    }

    // Check well-known Sri Lankan city names
    const knownCities = [
      'colombo', 'kandy', 'galle', 'jaffna', 'negombo', 'batticaloa',
      'trincomalee', 'anuradhapura', 'ratnapura', 'badulla', 'matara',
      'kurunegala', 'nuwara eliya', 'hambantota', 'puttalam', 'kilinochchi',
      'mannar', 'mullaitivu', 'vavuniya', 'polonnaruwa', 'monaragala',
      'kegalle', 'ampara', 'kalutara', 'gampaha', 'matale',
      'nugegoda', 'dehiwala', 'moratuwa', 'kotte', 'kaduwela',
      'maharagama', 'piliyandala', 'homagama', 'panadura', 'beruwala',
      'bentota', 'hikkaduwa', 'unawatuna', 'mirissa', 'ella', 'sigiriya',
      'dambulla', 'habarana', 'tangalle', 'weligama', 'ambalangoda',
    ];

    for (final city in knownCities) {
      if (searchText.contains(city)) return true;
    }

    return false;
  }
}

