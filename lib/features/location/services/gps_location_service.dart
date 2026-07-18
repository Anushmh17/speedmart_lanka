import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';
import '../models/gps_location_result.dart';

/// Low-level GPS service.
///
/// Responsibilities:
/// - Check / request location permissions.
/// - Return current device coordinates.
/// - Never returns fake / default coordinates.
///
/// This service does NOT do reverse geocoding — that is handled by
/// [ReverseGeocodingService].
class GpsLocationService {
  /// Requests permission if not already granted, then returns the current
  /// device [Position].
  ///
  /// Strategy:
  ///   1. Check / request permissions.
  ///   2. Try last-known position first (instant, no battery hit).
  ///   3. Fall back to fresh getCurrentPosition with a 30-second timeout.
  ///
  /// Throws a [LocationException] with a user-friendly message on any failure
  /// so callers can display a proper UI error without leaking raw exception text.
  Future<Position> getCurrentPosition() async {
    final serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      throw const LocationException(
        code: LocationExceptionCode.serviceDisabled,
        message:
            'Location services are turned off on this device. '
            'Please enable GPS in your device settings and try again.',
      );
    }

    LocationPermission permission = await Geolocator.checkPermission();

    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        throw const LocationException(
          code: LocationExceptionCode.permissionDenied,
          message:
              'Could not detect GPS. Please type your delivery area manually.',
        );
      }
    }

    if (permission == LocationPermission.deniedForever) {
      throw const LocationException(
        code: LocationExceptionCode.permissionPermanentlyDenied,
        message:
            'Location access is permanently blocked. '
            'Please open app settings, enable location, then try again.',
      );
    }

    // ── Strategy 1: fresh position (accurate, required for registration) ──────
    try {
      return await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
        timeLimit: const Duration(seconds: 30),
      );
    } on Exception {
      // Fall through to last-known as a fallback
    }

    // ── Strategy 2: last known position as fallback only ─────────────────────
    try {
      final last = await Geolocator.getLastKnownPosition();
      if (last != null) return last;
    } catch (_) {}

    throw const LocationException(
      code: LocationExceptionCode.positionUnavailable,
      message: 'Could not detect GPS. Please type your delivery area manually.',
    );
  }

  /// Checks the current permission status without requesting it.
  Future<LocationPermission> checkPermission() {
    return Geolocator.checkPermission();
  }

  /// Returns true if location services are enabled on the device.
  Future<bool> isServiceEnabled() {
    return Geolocator.isLocationServiceEnabled();
  }

  /// Opens the device location settings page.
  Future<bool> openLocationSettings() {
    return Geolocator.openLocationSettings();
  }

  /// Opens the app settings page (useful after permanent denial).
  Future<bool> openAppSettings() {
    return Geolocator.openAppSettings();
  }

  /// Builds a [GpsLocationResult] from a raw [Position].
  /// Geocoding is NOT performed here.
  GpsLocationResult positionToResult(Position position) {
    debugPrint('[Location] GPS accuracy: ${position.accuracy}m');
    return GpsLocationResult(
      latitude: position.latitude,
      longitude: position.longitude,
      accuracy: position.accuracy,
      detectedAt: DateTime.now(),
      timestamp: DateTime.now(),
      geocodingSucceeded: false,
    );
  }
}

// ── Exception types ────────────────────────────────────────────────────────

enum LocationExceptionCode {
  serviceDisabled,
  permissionDenied,
  permissionPermanentlyDenied,
  positionUnavailable,
  geocodingFailed,
}

class LocationException implements Exception {
  final LocationExceptionCode code;
  final String message;

  const LocationException({required this.code, required this.message});

  @override
  String toString() => 'LocationException(${code.name}): $message';

  bool get isPermissionIssue =>
      code == LocationExceptionCode.permissionDenied ||
      code == LocationExceptionCode.permissionPermanentlyDenied;

  bool get isPermanentlyDenied =>
      code == LocationExceptionCode.permissionPermanentlyDenied;

  bool get isServiceDisabled =>
      code == LocationExceptionCode.serviceDisabled;
}

