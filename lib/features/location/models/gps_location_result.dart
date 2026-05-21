/// The raw result returned by the GPS + reverse-geocoding pipeline.
///
/// [address] may be null when reverse geocoding fails — in that case the
/// caller must ask the user to type their area manually.
class GpsLocationResult {
  final double latitude;
  final double longitude;

  /// Human-readable address from reverse geocoding.
  /// Null when reverse geocoding was unsuccessful.
  final String? address;

  /// Province name extracted from geocoding result, if matched.
  final String? province;

  /// District name extracted from geocoding result, if matched.
  final String? district;

  /// Approximate city/area name from geocoding.
  final String? city;

  /// When the position was captured.
  final DateTime timestamp;

  /// Whether reverse geocoding succeeded.
  final bool geocodingSucceeded;

  const GpsLocationResult({
    required this.latitude,
    required this.longitude,
    required this.timestamp,
    this.address,
    this.province,
    this.district,
    this.city,
    this.geocodingSucceeded = false,
  });

  /// Convenience: true when coordinates are valid.
  bool get hasCoordinates => true; // always true — we only create this when coords exist

  /// Convenience: true when we have at least some address info.
  bool get hasAddress => address != null && address!.isNotEmpty;

  @override
  String toString() =>
      'GpsLocationResult(lat=$latitude, lng=$longitude, geocoded=$geocodingSucceeded)';
}
