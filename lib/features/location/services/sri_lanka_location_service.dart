import 'package:flutter/foundation.dart';
import '../models/delivery_location.dart';
import '../models/gps_location_result.dart';
import '../models/location_suggestion.dart';
import '../data/sri_lanka_data.dart';
import 'gps_location_service.dart';
import 'reverse_geocoding_service.dart';

/// High-level location orchestrator for Sri Lanka.
///
/// Combines [GpsLocationService] and [ReverseGeocodingService] to produce a
/// fully resolved [DeliveryLocation] from GPS, or assists with manual entry.
///
/// Rules enforced here:
/// - Never returns fake / default coordinates.
/// - Never overwrites a user-typed [preciseAddress] automatically.
/// - On geocoding failure, returns a [DeliveryLocation] with empty address
///   fields — the caller must prompt the user to type manually.
class SriLankaLocationService {
  final GpsLocationService _gps;
  final ReverseGeocodingService _geocoding;

  SriLankaLocationService({
    GpsLocationService? gpsService,
    ReverseGeocodingService? geocodingService,
  })  : _gps = gpsService ?? GpsLocationService(),
        _geocoding = geocodingService ?? ReverseGeocodingService();

  // ── GPS Flow ───────────────────────────────────────────────────────────────

  /// Detects the user's current GPS position and reverse geocodes it.
  ///
  /// Returns a [SriLankaLocationResult] containing both the raw GPS result
  /// and the resolved [DeliveryLocation].
  ///
  /// On any failure, throws a [LocationException] with a user-friendly message.
  /// Never fabricates location data.
  Future<SriLankaLocationResult> detectCurrentLocation() async {
    // 1. Get raw GPS position (throws LocationException on failure)
    final position = await _gps.getCurrentPosition();

    // 2. Reverse geocode
    final gpsResult = await _geocoding.reverseGeocode(
      latitude: position.latitude,
      longitude: position.longitude,
    );

    // 3. Build DeliveryLocation
    final location = _buildFromGpsResult(gpsResult);

    return SriLankaLocationResult(
      gpsResult: gpsResult,
      location: location,
      geocodingSucceeded: gpsResult.geocodingSucceeded,
    );
  }

  /// Reverse geocodes a customer-adjusted delivery pin.
  ///
  /// The coordinates remain the source of truth. Address fields are refreshed
  /// from the local Sri Lankan dataset when possible, while customer-entered
  /// precise address and delivery notes are preserved by the caller.
  Future<DeliveryLocation> resolvePinLocation({
    required double latitude,
    required double longitude,
    String existingPreciseAddress = '',
    String existingDeliveryNote = '',
  }) async {
    final gpsResult = await _geocoding.reverseGeocode(
      latitude: latitude,
      longitude: longitude,
    );

    return _buildFromGpsResult(
      GpsLocationResult(
        latitude: latitude,
        longitude: longitude,
        timestamp: DateTime.now(),
        address: gpsResult.address,
        province: gpsResult.province,
        district: gpsResult.district,
        city: gpsResult.city,
        geocodingSucceeded: gpsResult.geocodingSucceeded,
        detectedAt: DateTime.now(),
      ),
      existingPreciseAddress: existingPreciseAddress,
    ).copyWith(
      deliveryNote: existingDeliveryNote,
      source: 'map_pin',
      isGpsDetected: false,
      isManualOverride: true,
      latitude: latitude,
      longitude: longitude,
      detectedAt: DateTime.now(),
    );
  }

  /// Builds a [DeliveryLocation] from an already-resolved [GpsLocationResult].
  /// Used when you have coordinates from a previous detection.
  ///
  /// [existingPreciseAddress] – if the user has already typed a precise address,
  /// it is preserved and NOT replaced by GPS data.
  DeliveryLocation buildFromGpsResult(
    GpsLocationResult gpsResult, {
    String? existingPreciseAddress,
  }) {
    return _buildFromGpsResult(
      gpsResult,
      existingPreciseAddress: existingPreciseAddress,
    );
  }

  // ── Manual Entry Flow ──────────────────────────────────────────────────────

  /// Builds a [DeliveryLocation] from manually selected province + district.
  /// Coordinates are null (user chose area manually).
  DeliveryLocation buildFromManualSelection({
    required String provinceName,
    required String districtName,
    String approximateAreaText = '',
    String preciseAddress = '',
  }) {
    return DeliveryLocation(
      province: provinceName,
      district: districtName,
      city: '',
      suburb: '',
      approximateAreaText: approximateAreaText,
      formattedAddress: _buildFormattedAddress(
        suburb: approximateAreaText,
        district: districtName,
        province: provinceName,
      ),
      preciseAddress: preciseAddress,
      streetAddress: preciseAddress,
      source: 'manual',
      isManualOverride: true,
      isGpsDetected: false,
    );
  }

  /// Builds a [DeliveryLocation] from a [LocationSuggestion] the user tapped.
  DeliveryLocation buildFromSuggestion(
    LocationSuggestion suggestion, {
    String preciseAddress = '',
  }) {
    final provinceName = suggestion.provinceName ?? '';
    final districtName = suggestion.districtName ?? '';

    return DeliveryLocation(
      province: provinceName,
      district: districtName,
      city: '',
      suburb: suggestion.display,
      approximateAreaText: suggestion.display,
      formattedAddress: _buildFormattedAddress(
        suburb: suggestion.display,
        district: districtName,
        province: provinceName,
      ),
      preciseAddress: preciseAddress,
      streetAddress: preciseAddress,
      latitude: suggestion.latitude,
      longitude: suggestion.longitude,
      isGpsDetected: false,
      isManualOverride: true,
      source: 'suggestion',
    );
  }

  // ── Search ─────────────────────────────────────────────────────────────────

  /// Returns [LocationSuggestion] list for the given query string.
  /// Searches province names, district names, and known suburb/town names.
  List<LocationSuggestion> search(String query) {
    if (query.trim().isEmpty) return [];
    final lower = query.toLowerCase().trim();
    final results = <LocationSuggestion>[];

    for (final province in SriLankaData.provinces) {
      if (province.name.toLowerCase().contains(lower)) {
        results.add(LocationSuggestion(
          display: province.name,
          provinceId: province.id,
          provinceName: province.name,
          source: 'search',
        ));
      }
      for (final district in province.districts) {
        if (district.name.toLowerCase().contains(lower)) {
          results.add(LocationSuggestion(
            display: '${district.name}, ${province.name}',
            provinceId: province.id,
            districtId: district.id,
            provinceName: province.name,
            districtName: district.name,
            source: 'search',
          ));
        }
      }
    }

    return results.take(10).toList();
  }

  // ── Private helpers ────────────────────────────────────────────────────────

  DeliveryLocation _buildFromGpsResult(
    GpsLocationResult gpsResult, {
    String? existingPreciseAddress,
  }) {
    // Log accuracy info
    final accuracyStr = gpsResult.accuracy?.toStringAsFixed(1) ?? 'N/A';
    debugPrint('[Location] GPS detected at: ${gpsResult.detectedAt}');
    debugPrint('[Location] GPS accuracy: ${accuracyStr}m');

    // Determine accuracy level
    String accuracyLevel = 'unknown';
    if (gpsResult.accuracy != null) {
      if (gpsResult.accuracy! <= 50) {
        accuracyLevel = 'high';
      } else if (gpsResult.accuracy! <= 150) {
        accuracyLevel = 'medium';
      } else {
        accuracyLevel = 'low';
      }
    }
    debugPrint('[Location] GPS accuracy level: $accuracyLevel');

    if (!gpsResult.geocodingSucceeded) {
      // Geocoding failed — return coords only, leave address fields empty
      // so the UI can ask the user to type manually.
      return DeliveryLocation(
        province: '',
        district: '',
        city: '',
        suburb: '',
        approximateAreaText: '',
        formattedAddress: '',
        preciseAddress: existingPreciseAddress ?? '',
        streetAddress: existingPreciseAddress ?? '',
        latitude: gpsResult.latitude,
        longitude: gpsResult.longitude,
        isGpsDetected: true,
        isManualOverride: false,
        source: 'gps',
        accuracy: gpsResult.accuracy,
        detectedAt: gpsResult.detectedAt,
      );
    }

    final province = gpsResult.province ?? '';
    final district = gpsResult.district ?? '';
    final city = gpsResult.city ?? '';
    final suburb = city;

    return DeliveryLocation(
      province: province,
      district: district,
      city: city,
      suburb: suburb,
      approximateAreaText: suburb.isNotEmpty ? suburb : city,
      formattedAddress: gpsResult.address ?? '',
      // IMPORTANT: never overwrite a manually typed precise address
      preciseAddress: existingPreciseAddress ?? '',
      streetAddress: existingPreciseAddress ?? '',
      latitude: gpsResult.latitude,
      longitude: gpsResult.longitude,
      isGpsDetected: true,
      isManualOverride: false,
      source: 'gps',
      accuracy: gpsResult.accuracy,
      detectedAt: gpsResult.detectedAt,
    );
  }

  String _buildFormattedAddress({
    required String suburb,
    required String district,
    required String province,
  }) {
    final parts = <String>[];
    if (suburb.isNotEmpty) parts.add(suburb);
    if (district.isNotEmpty) parts.add('$district District');
    if (province.isNotEmpty) parts.add('$province Province');
    parts.add('Sri Lanka');
    return parts.join(', ');
  }
}

// ── Result wrapper ─────────────────────────────────────────────────────────

/// Wraps the outcome of a GPS detection attempt.
class SriLankaLocationResult {
  final GpsLocationResult gpsResult;
  final DeliveryLocation location;
  final bool geocodingSucceeded;

  const SriLankaLocationResult({
    required this.gpsResult,
    required this.location,
    required this.geocodingSucceeded,
  });
}

