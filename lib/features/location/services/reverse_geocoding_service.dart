import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';

import '../data/sri_lanka_data.dart';
import '../models/gps_location_result.dart';
import '../utils/haversine.dart';

/// Reverse geocoding service.
///
/// Converts GPS coordinates into a structured [GpsLocationResult] by:
/// 1. Matching the nearest known Sri Lanka suburb (from [LocationService] dataset).
/// 2. Deriving province and district from that match.
///
/// This service does NOT use the `geocoding` package because:
/// - It requires native platform setup that may not be configured.
/// - Our local suburb dataset already gives us accurate province/district data.
/// - Using the local dataset avoids external API latency and errors.
///
/// If coordinates cannot be matched within a reasonable threshold, the result
/// will have [geocodingSucceeded] = false and null address fields.
/// The caller MUST ask the user to type their area manually in that case.
/// No fallback Colombo/Kandy values are ever used.
class ReverseGeocodingService {
  static const double _maxMatchDistanceKm = 25.0;

  final Dio _dio;

  ReverseGeocodingService({Dio? dio})
      : _dio = dio ??
            Dio(BaseOptions(
              connectTimeout: const Duration(seconds: 6),
              receiveTimeout: const Duration(seconds: 6),
              headers: {'User-Agent': 'SpeedmartLanka/1.0 (contact@speedmart.lk)'},
            ));

  Future<GpsLocationResult> reverseGeocode({
    required double latitude,
    required double longitude,
  }) async {
    // 1. Try Nominatim first for street-level accuracy
    try {
      final result = await _nominatimReverseGeocode(
        latitude: latitude,
        longitude: longitude,
      );
      if (result != null) return result;
    } catch (e) {
      debugPrint('[ReverseGeocoding] Nominatim failed: $e — falling back to local dataset');
    }

    // 2. Fall back to local dataset
    return _localReverseGeocode(latitude: latitude, longitude: longitude);
  }

  Future<GpsLocationResult?> _nominatimReverseGeocode({
    required double latitude,
    required double longitude,
  }) async {
    final response = await _dio.get<dynamic>(
      'https://nominatim.openstreetmap.org/reverse',
      queryParameters: {
        'lat': latitude,
        'lon': longitude,
        'format': 'json',
        'addressdetails': 1,
        'zoom': 16,
      },
    );

    final raw = response.data;
    if (raw == null) return null;
    final data = Map<String, dynamic>.from(raw as Map);

    final rawAddr = data['address'];
    if (rawAddr == null) return null;
    final addr = Map<String, dynamic>.from(rawAddr as Map);

    String _s(String key) => addr[key] as String? ?? '';

    // Most specific place name first
    final suburb = _s('suburb').isNotEmpty
        ? _s('suburb')
        : _s('neighbourhood').isNotEmpty
            ? _s('neighbourhood')
            : _s('quarter').isNotEmpty
                ? _s('quarter')
                : _s('village').isNotEmpty
                    ? _s('village')
                    : _s('town').isNotEmpty
                        ? _s('town')
                        : _s('city_district');

    final city = _s('city').isNotEmpty
        ? _s('city')
        : _s('town').isNotEmpty
            ? _s('town')
            : _s('municipality').isNotEmpty
                ? _s('municipality')
                : suburb;

    final rawProvince = _s('state');
    final rawDistrict =
        _s('state_district').isNotEmpty ? _s('state_district') : _s('county');

    // Nominatim appends " Province" / " District" — strip them before lookup
    final cleanProvince = rawProvince
        .replaceAll(RegExp(r'\s+Province$', caseSensitive: false), '')
        .replaceAll('-', ' ')
        .trim();
    final cleanDistrict = rawDistrict
        .replaceAll(RegExp(r'\s+District$', caseSensitive: false), '')
        .replaceAll('-', ' ')
        .trim();

    final province = SriLankaData.provinceByName(cleanProvince);
    final district = SriLankaData.districtByName(cleanDistrict);
    final districtName = district?.name ?? cleanDistrict;
    final provinceName = province?.name ?? cleanProvince;

    final parts = <String>[];
    if (suburb.isNotEmpty) parts.add(suburb);
    if (city.isNotEmpty && city != suburb) parts.add(city);
    if (districtName.isNotEmpty) parts.add('$districtName District');
    if (provinceName.isNotEmpty) parts.add('$provinceName Province');
    parts.add('Sri Lanka');

    debugPrint('[ReverseGeocoding] Nominatim: suburb=$suburb city=$city district=$districtName province=$provinceName');

    return GpsLocationResult(
      latitude: latitude,
      longitude: longitude,
      timestamp: DateTime.now(),
      address: parts.join(', '),
      province: provinceName,
      district: districtName,
      city: suburb.isNotEmpty ? suburb : city,
      geocodingSucceeded: true,
    );
  }

  GpsLocationResult _localReverseGeocode({
    required double latitude,
    required double longitude,
  }) {
    try {
      final match = _findNearestSuburb(latitude, longitude);
      if (match == null) {
        return GpsLocationResult(
          latitude: latitude,
          longitude: longitude,
          timestamp: DateTime.now(),
          geocodingSucceeded: false,
        );
      }

      final province = SriLankaData.provinceByName(match.province);
      final district = SriLankaData.districtByName(match.district);
      final address = '${match.name}, ${match.city}, ${match.district} District, '
          '${match.province} Province, Sri Lanka';

      debugPrint('[ReverseGeocoding] Local fallback matched: ${match.name}');

      return GpsLocationResult(
        latitude: latitude,
        longitude: longitude,
        timestamp: DateTime.now(),
        address: address,
        province: province?.name ?? match.province,
        district: district?.name ?? match.district,
        city: match.city,
        geocodingSucceeded: true,
      );
    } catch (_) {
      return GpsLocationResult(
        latitude: latitude,
        longitude: longitude,
        timestamp: DateTime.now(),
        geocodingSucceeded: false,
      );
    }
  }

  // ── Private helpers ────────────────────────────────────────────────────────

  _SuburbEntry? _findNearestSuburb(double lat, double lon) {
    _SuburbEntry? nearest;
    double minDist = double.maxFinite;

    for (final suburb in _suburbDataset) {
      final dist = Haversine.distanceKm(
        lat1: lat,
        lon1: lon,
        lat2: suburb.lat,
        lon2: suburb.lon,
      );
      if (dist < minDist) {
        minDist = dist;
        nearest = suburb;
      }
    }

    if (nearest == null || minDist > _maxMatchDistanceKm) return null;
    return nearest;
  }

  // ── Suburb dataset (province/district/city metadata only) ─────────────────
  // Coordinates taken from the existing LocationService dataset.
  // We keep this internal to this service so other services don't depend on coords.

  static const List<_SuburbEntry> _suburbDataset = [
    // Western – Colombo
    _SuburbEntry(name: 'Fort', city: 'Colombo', district: 'Colombo', province: 'Western', lat: 6.9344, lon: 79.8428),
    _SuburbEntry(name: 'Slave Island', city: 'Colombo', district: 'Colombo', province: 'Western', lat: 6.9213, lon: 79.8493),
    _SuburbEntry(name: 'Bambalapitiya', city: 'Colombo', district: 'Colombo', province: 'Western', lat: 6.8990, lon: 79.8570),
    _SuburbEntry(name: 'Wellawatta', city: 'Colombo', district: 'Colombo', province: 'Western', lat: 6.8783, lon: 79.8620),
    _SuburbEntry(name: 'Cinnamon Gardens', city: 'Colombo', district: 'Colombo', province: 'Western', lat: 6.9064, lon: 79.8640),
    _SuburbEntry(name: 'Borella', city: 'Colombo', district: 'Colombo', province: 'Western', lat: 6.9195, lon: 79.8750),
    _SuburbEntry(name: 'Pettah', city: 'Colombo', district: 'Colombo', province: 'Western', lat: 6.9376, lon: 79.8512),
    _SuburbEntry(name: 'Nugegoda', city: 'Nugegoda', district: 'Colombo', province: 'Western', lat: 6.8745, lon: 79.8890),
    _SuburbEntry(name: 'Rajagiriya', city: 'Rajagiriya', district: 'Colombo', province: 'Western', lat: 6.9100, lon: 79.8860),
    _SuburbEntry(name: 'Battaramulla', city: 'Battaramulla', district: 'Colombo', province: 'Western', lat: 6.8989, lon: 79.9223),
    _SuburbEntry(name: 'Maharagama', city: 'Maharagama', district: 'Colombo', province: 'Western', lat: 6.8511, lon: 79.9212),
    _SuburbEntry(name: 'Moratuwa', city: 'Moratuwa', district: 'Colombo', province: 'Western', lat: 6.7733, lon: 79.8823),
    _SuburbEntry(name: 'Dehiwala', city: 'Dehiwala', district: 'Colombo', province: 'Western', lat: 6.8388, lon: 79.8767),
    _SuburbEntry(name: 'Mount Lavinia', city: 'Mount Lavinia', district: 'Colombo', province: 'Western', lat: 6.8340, lon: 79.8670),
    _SuburbEntry(name: 'Malabe', city: 'Malabe', district: 'Colombo', province: 'Western', lat: 6.9028, lon: 79.9631),
    _SuburbEntry(name: 'Kaduwela', city: 'Kaduwela', district: 'Colombo', province: 'Western', lat: 6.9365, lon: 79.9786),
    // Western – Gampaha
    _SuburbEntry(name: 'Negombo', city: 'Negombo', district: 'Gampaha', province: 'Western', lat: 7.2089, lon: 79.8353),
    _SuburbEntry(name: 'Ja-Ela', city: 'Ja-Ela', district: 'Gampaha', province: 'Western', lat: 7.0736, lon: 79.8913),
    _SuburbEntry(name: 'Wattala', city: 'Wattala', district: 'Gampaha', province: 'Western', lat: 6.9814, lon: 79.8927),
    _SuburbEntry(name: 'Kelaniya', city: 'Kelaniya', district: 'Gampaha', province: 'Western', lat: 6.9553, lon: 79.9215),
    _SuburbEntry(name: 'Katunayake', city: 'Katunayake', district: 'Gampaha', province: 'Western', lat: 7.1683, lon: 79.8866),
    // Western – Kalutara
    _SuburbEntry(name: 'Kalutara', city: 'Kalutara', district: 'Kalutara', province: 'Western', lat: 6.5854, lon: 79.9607),
    _SuburbEntry(name: 'Panadura', city: 'Panadura', district: 'Kalutara', province: 'Western', lat: 6.7119, lon: 79.9074),
    // Central – Kandy
    _SuburbEntry(name: 'Kandy', city: 'Kandy', district: 'Kandy', province: 'Central', lat: 7.2906, lon: 80.6337),
    _SuburbEntry(name: 'Peradeniya', city: 'Peradeniya', district: 'Kandy', province: 'Central', lat: 7.2681, lon: 80.5966),
    _SuburbEntry(name: 'Gampola', city: 'Gampola', district: 'Kandy', province: 'Central', lat: 7.1650, lon: 80.5742),
    // Central – Matale
    _SuburbEntry(name: 'Matale', city: 'Matale', district: 'Matale', province: 'Central', lat: 7.4675, lon: 80.6234),
    _SuburbEntry(name: 'Dambulla', city: 'Dambulla', district: 'Matale', province: 'Central', lat: 7.8608, lon: 80.6517),
    // Central – Nuwara Eliya
    _SuburbEntry(name: 'Nuwara Eliya', city: 'Nuwara Eliya', district: 'Nuwara Eliya', province: 'Central', lat: 6.9497, lon: 80.7891),
    _SuburbEntry(name: 'Hatton', city: 'Hatton', district: 'Nuwara Eliya', province: 'Central', lat: 6.8908, lon: 80.5986),
    // Southern – Galle
    _SuburbEntry(name: 'Galle', city: 'Galle', district: 'Galle', province: 'Southern', lat: 6.0367, lon: 80.2170),
    _SuburbEntry(name: 'Hikkaduwa', city: 'Hikkaduwa', district: 'Galle', province: 'Southern', lat: 6.1398, lon: 80.1060),
    // Southern – Matara
    _SuburbEntry(name: 'Matara', city: 'Matara', district: 'Matara', province: 'Southern', lat: 5.9549, lon: 80.5550),
    _SuburbEntry(name: 'Weligama', city: 'Weligama', district: 'Matara', province: 'Southern', lat: 5.9722, lon: 80.4289),
    // Southern – Hambantota
    _SuburbEntry(name: 'Hambantota', city: 'Hambantota', district: 'Hambantota', province: 'Southern', lat: 6.1248, lon: 81.1185),
    _SuburbEntry(name: 'Tangalle', city: 'Tangalle', district: 'Hambantota', province: 'Southern', lat: 6.0242, lon: 80.7937),
    // Northern – Jaffna
    _SuburbEntry(name: 'Jaffna', city: 'Jaffna', district: 'Jaffna', province: 'Northern', lat: 9.6615, lon: 80.0125),
    // Northern – Kilinochchi
    _SuburbEntry(name: 'Kilinochchi', city: 'Kilinochchi', district: 'Kilinochchi', province: 'Northern', lat: 9.3803, lon: 80.3986),
    // Northern – Mannar
    _SuburbEntry(name: 'Mannar', city: 'Mannar', district: 'Mannar', province: 'Northern', lat: 8.9810, lon: 79.9054),
    // Northern – Vavuniya
    _SuburbEntry(name: 'Vavuniya', city: 'Vavuniya', district: 'Vavuniya', province: 'Northern', lat: 8.7514, lon: 80.4971),
    // Northern – Mullaitivu
    _SuburbEntry(name: 'Mullaitivu', city: 'Mullaitivu', district: 'Mullaitivu', province: 'Northern', lat: 9.2662, lon: 80.8143),
    // Eastern – Trincomalee
    _SuburbEntry(name: 'Trincomalee', city: 'Trincomalee', district: 'Trincomalee', province: 'Eastern', lat: 8.5711, lon: 81.2335),
    // Eastern – Batticaloa
    _SuburbEntry(name: 'Batticaloa', city: 'Batticaloa', district: 'Batticaloa', province: 'Eastern', lat: 7.7170, lon: 81.7010),
    // Eastern – Ampara
    _SuburbEntry(name: 'Ampara', city: 'Ampara', district: 'Ampara', province: 'Eastern', lat: 7.2882, lon: 81.6747),
    _SuburbEntry(name: 'Kalmunai', city: 'Kalmunai', district: 'Ampara', province: 'Eastern', lat: 7.4166, lon: 81.8271),
    // North Western – Kurunegala
    _SuburbEntry(name: 'Kurunegala', city: 'Kurunegala', district: 'Kurunegala', province: 'North Western', lat: 7.4863, lon: 80.3647),
    _SuburbEntry(name: 'Kuliyapitiya', city: 'Kuliyapitiya', district: 'Kurunegala', province: 'North Western', lat: 7.4686, lon: 80.0414),
    // North Western – Puttalam
    _SuburbEntry(name: 'Puttalam', city: 'Puttalam', district: 'Puttalam', province: 'North Western', lat: 8.0330, lon: 79.8267),
    _SuburbEntry(name: 'Chilaw', city: 'Chilaw', district: 'Puttalam', province: 'North Western', lat: 7.5759, lon: 79.7952),
    // North Central – Anuradhapura
    _SuburbEntry(name: 'Anuradhapura', city: 'Anuradhapura', district: 'Anuradhapura', province: 'North Central', lat: 8.3114, lon: 80.4037),
    // North Central – Polonnaruwa
    _SuburbEntry(name: 'Polonnaruwa', city: 'Polonnaruwa', district: 'Polonnaruwa', province: 'North Central', lat: 7.9397, lon: 81.0022),
    // Uva – Badulla
    _SuburbEntry(name: 'Badulla', city: 'Badulla', district: 'Badulla', province: 'Uva', lat: 6.9934, lon: 81.0550),
    _SuburbEntry(name: 'Bandarawela', city: 'Bandarawela', district: 'Badulla', province: 'Uva', lat: 6.8259, lon: 80.9981),
    _SuburbEntry(name: 'Ella', city: 'Ella', district: 'Badulla', province: 'Uva', lat: 6.8760, lon: 81.0460),
    // Uva – Monaragala
    _SuburbEntry(name: 'Monaragala', city: 'Monaragala', district: 'Monaragala', province: 'Uva', lat: 6.8719, lon: 81.3503),
    // Sabaragamuwa – Ratnapura
    _SuburbEntry(name: 'Ratnapura', city: 'Ratnapura', district: 'Ratnapura', province: 'Sabaragamuwa', lat: 6.6828, lon: 80.3992),
    _SuburbEntry(name: 'Embilipitiya', city: 'Embilipitiya', district: 'Ratnapura', province: 'Sabaragamuwa', lat: 6.3423, lon: 80.8436),
    // Sabaragamuwa – Kegalle
    _SuburbEntry(name: 'Kegalle', city: 'Kegalle', district: 'Kegalle', province: 'Sabaragamuwa', lat: 7.2513, lon: 80.3464),
    _SuburbEntry(name: 'Mawanella', city: 'Mawanella', district: 'Kegalle', province: 'Sabaragamuwa', lat: 7.2534, lon: 80.4551),
  ];
}

// ── Internal data class ────────────────────────────────────────────────────

class _SuburbEntry {
  final String name;
  final String city;
  final String district;
  final String province;
  final double lat;
  final double lon;

  const _SuburbEntry({
    required this.name,
    required this.city,
    required this.district,
    required this.province,
    required this.lat,
    required this.lon,
  });
}

