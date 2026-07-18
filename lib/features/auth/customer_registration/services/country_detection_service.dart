import 'dart:io';
import 'dart:developer' as developer;
import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';

/// How the country was determined.
enum DetectionMethod { gps, locale, preference, fallback }

/// Result of country detection.
class CountryDetectionResult {
  const CountryDetectionResult({
    required this.isLkUser,
    required this.method,
    required this.isConfident,
    this.countryCode,
  });

  /// True when the user is determined to be in / from Sri Lanka.
  final bool isLkUser;

  /// Which detection strategy succeeded.
  final DetectionMethod method;

  /// True if country is confidently detected (e.g. GPS or locale).
  final bool isConfident;

  /// ISO-3166 alpha-2 country code if known (may be null for fallback)
  final String? countryCode;

  @override
  String toString() =>
      'CountryDetectionResult(isLk: $isLkUser, method: ${method.name}, confident: $isConfident, code: $countryCode)';
}

class CountryDetectionService {
  // Sri Lanka geographic bounding box (expanded limits)
  static const double _lkLatMin = 5.80;
  static const double _lkLatMax = 10.00;
  static const double _lkLonMin = 79.30;
  static const double _lkLonMax = 82.10;

  /// Logs to both dart:developer (DevTools) and debugPrint (flutter run terminal).
  void _log(String message) {
    final full = '[CountryDetection] $message';
    debugPrint(full);
    developer.log(message, name: 'CountryDetection');
  }

  /// Detects the user's country. Returns within a few seconds.
  Future<CountryDetectionResult> detect() async {
    _log('Starting detection');

    // ── Strategy 1: GPS bounding box ──────────────────────────────────────
    try {
      final gpsResult = await _detectViaGps();
      if (gpsResult != null) {
        final code = gpsResult.countryCode ?? (gpsResult.isLkUser ? 'LK' : 'OTHER');
        _log('Final country: $code');
        _log('Source: ${gpsResult.method.name}');
        _log('Confident: ${gpsResult.isConfident}');
        return gpsResult;
      }
    } catch (e) {
      _log('GPS detection failed: $e');
    }

    // ── Strategy 2: Device locale ──────────────────────────────────────────
    final localeResult = _detectViaLocale();
    if (localeResult != null) {
      final code = localeResult.countryCode ?? (localeResult.isLkUser ? 'LK' : 'OTHER');
      _log('Final country: $code');
      _log('Source: ${localeResult.method.name}');
      _log('Confident: ${localeResult.isConfident}');
      return localeResult;
    }

    // ── All methods failed — caller must prompt manual selection ──────────
    _log('All confident detection methods failed');
    _log('Final country: UNKNOWN');
    _log('Confident: false');
    _log('Manual selection required');
    return const CountryDetectionResult(
      isLkUser: false,
      method: DetectionMethod.fallback,
      isConfident: false,
    );
  }

  // ── Private helpers ────────────────────────────────────────────────────────

  Future<CountryDetectionResult?> _detectViaGps() async {
    final serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      _log('GPS permission: service_disabled');
      return null;
    }

    final permission = await Geolocator.checkPermission();
    _log('GPS permission: ${permission.name}');

    if (permission == LocationPermission.denied ||
        permission == LocationPermission.deniedForever) {
      return null;
    }

    Position? position;
    try {
      position = await Geolocator.getLastKnownPosition();
    } catch (_) {}

    if (position == null) {
      try {
        position = await Geolocator.getCurrentPosition(
          desiredAccuracy: LocationAccuracy.low,
          timeLimit: const Duration(seconds: 5),
        );
      } catch (e) {
        _log('GPS coordinates: unavailable ($e)');
        return null;
      }
    }

    _log('GPS coordinates: ${position.latitude.toStringAsFixed(5)}, ${position.longitude.toStringAsFixed(5)}');

    final inLk = _isWithinSriLanka(position.latitude, position.longitude);
    _log('GPS inside Sri Lanka: $inLk');

    if (inLk) {
      return const CountryDetectionResult(
        isLkUser: true,
        method: DetectionMethod.gps,
        isConfident: true,
        countryCode: 'LK',
      );
    }

    // Confidently NOT in Sri Lanka
    return const CountryDetectionResult(
      isLkUser: false,
      method: DetectionMethod.gps,
      isConfident: true,
      countryCode: 'OTHER',
    );
  }

  CountryDetectionResult? _detectViaLocale() {
    try {
      final locale = Platform.localeName.toLowerCase();
      _log('Locale: $locale');

      // Matches: si, si_LK, ta_LK, lk
      final isLk = locale.contains('_lk') ||
          locale.startsWith('si') ||
          locale == 'lk';

      if (isLk) {
        _log('Locale matched Sri Lanka patterns → LK');
        return const CountryDetectionResult(
          isLkUser: true,
          method: DetectionMethod.locale,
          isConfident: true,
          countryCode: 'LK',
        );
      }

      _log('Locale did not match Sri Lanka');
      return null;
    } catch (e) {
      _log('Locale: error reading locale — $e');
      return null;
    }
  }

  bool _isWithinSriLanka(double lat, double lon) {
    return lat >= _lkLatMin &&
        lat <= _lkLatMax &&
        lon >= _lkLonMin &&
        lon <= _lkLonMax;
  }
}

