/// Represents a fully resolved delivery location.
///
/// Address fields are intentionally separated:
/// - [approximateAreaText] — free text the user typed or GPS area name
/// - [preciseAddress]      — the exact door/unit address the user manually types
/// - [formattedAddress]    — full formatted string (suburb + district + province)
///
/// Coordinates are nullable:
/// - Present when GPS was used or a suggestion with known coords was selected.
/// - Null when the user typed their area manually with no GPS involvement.
///
/// [source] tracks how the location was determined:
///   'gps'        — obtained from device GPS + reverse geocoding
///   'manual'     — user typed the area directly
///   'suggestion' — user tapped a suggestion from the search list
///   ''           — unknown / not yet set
class DeliveryLocation {
  final String province;
  final String district;
  final String city;
  final String suburb;

  /// Full formatted address string: suburb + district + province + Sri Lanka.
  final String formattedAddress;

  /// The exact street/door address the user typed.
  /// NEVER overwritten automatically by GPS detection.
  final String preciseAddress;

  /// Legacy alias kept for backwards compatibility with existing screens.
  /// New code should use [preciseAddress].
  final String streetAddress;

  final String deliveryNote;
  final double? latitude;
  final double? longitude;
  final bool isGpsDetected;
  final bool isManualOverride;

  /// The raw text the customer typed or was auto-filled into the approximate
  /// area field. This is the display value — it may or may not match a known suburb.
  final String approximateAreaText;

  /// How the location was determined: 'gps', 'suggestion', 'manual', or '' (unknown).
  final String source;

  /// GPS accuracy in meters. Null if location was not GPS-detected.
  final double? accuracy;

  /// When GPS detection occurred. Null if location was not GPS-detected.
  final DateTime? detectedAt;

  const DeliveryLocation({
    required this.province,
    required this.district,
    required this.city,
    required this.suburb,
    required this.formattedAddress,
    this.preciseAddress = '',
    this.streetAddress = '',
    this.deliveryNote = '',
    this.latitude,
    this.longitude,
    this.isGpsDetected = false,
    this.isManualOverride = false,
    this.approximateAreaText = '',
    this.source = '',
    this.accuracy,
    this.detectedAt,
  });

  factory DeliveryLocation.fromJson(Map<String, dynamic> json) {
    return DeliveryLocation(
      province: json['province'] as String? ?? '',
      district: json['district'] as String? ?? '',
      city: json['city'] as String? ?? '',
      suburb: json['suburb'] as String? ?? '',
      formattedAddress: json['formattedAddress'] as String? ?? '',
      preciseAddress: json['preciseAddress'] as String? ?? '',
      streetAddress: json['streetAddress'] as String? ?? '',
      deliveryNote: json['deliveryNote'] as String? ?? '',
      latitude: (json['latitude'] as num?)?.toDouble(),
      longitude: (json['longitude'] as num?)?.toDouble(),
      isGpsDetected: json['isGpsDetected'] as bool? ?? false,
      isManualOverride: json['isManualOverride'] as bool? ?? false,
      approximateAreaText: json['approximateAreaText'] as String? ?? '',
      source: json['source'] as String? ?? '',
      accuracy: (json['accuracy'] as num?)?.toDouble(),
      detectedAt: json['detectedAt'] != null ? DateTime.parse(json['detectedAt'] as String) : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'province': province,
      'district': district,
      'city': city,
      'suburb': suburb,
      'formattedAddress': formattedAddress,
      'preciseAddress': preciseAddress,
      'streetAddress': streetAddress,
      'deliveryNote': deliveryNote,
      'latitude': latitude,
      'longitude': longitude,
      'isGpsDetected': isGpsDetected,
      'isManualOverride': isManualOverride,
      'approximateAreaText': approximateAreaText,
      'source': source,
      'accuracy': accuracy,
      'detectedAt': detectedAt?.toIso8601String(),
    };
  }

  DeliveryLocation copyWith({
    String? province,
    String? district,
    String? city,
    String? suburb,
    String? formattedAddress,
    String? preciseAddress,
    String? streetAddress,
    String? deliveryNote,
    double? latitude,
    double? longitude,
    bool? isGpsDetected,
    bool? isManualOverride,
    String? approximateAreaText,
    String? source,
    double? accuracy,
    DateTime? detectedAt,
    bool clearLatLng = false,
  }) {
    return DeliveryLocation(
      province: province ?? this.province,
      district: district ?? this.district,
      city: city ?? this.city,
      suburb: suburb ?? this.suburb,
      formattedAddress: formattedAddress ?? this.formattedAddress,
      preciseAddress: preciseAddress ?? this.preciseAddress,
      streetAddress: streetAddress ?? this.streetAddress,
      deliveryNote: deliveryNote ?? this.deliveryNote,
      latitude: clearLatLng ? null : (latitude ?? this.latitude),
      longitude: clearLatLng ? null : (longitude ?? this.longitude),
      isGpsDetected: isGpsDetected ?? this.isGpsDetected,
      isManualOverride: isManualOverride ?? this.isManualOverride,
      approximateAreaText: approximateAreaText ?? this.approximateAreaText,
      source: source ?? this.source,
      accuracy: accuracy ?? this.accuracy,
      detectedAt: detectedAt ?? this.detectedAt,
    );
  }

  /// Whether this location has valid GPS coordinates (not null).
  bool get hasCoordinates => latitude != null && longitude != null;

  /// Whether the user has explicitly typed a precise address.
  bool get hasPreciseAddress => preciseAddress.isNotEmpty;

  /// Whether this location has at least province or district data.
  bool get hasAreaData => province.isNotEmpty || district.isNotEmpty;

  /// The display label for the approximate area
  /// (prefers suburb/city, falls back to manual text).
  String get displayArea {
    if (suburb.isNotEmpty && city.isNotEmpty) return '$suburb, $city';
    if (suburb.isNotEmpty) return suburb;
    if (approximateAreaText.isNotEmpty) return approximateAreaText;
    if (city.isNotEmpty) return city;
    if (district.isNotEmpty) return district;
    return '';
  }

  /// A short summary for display in chips / badges.
  String get shortDisplay {
    if (displayArea.isNotEmpty && district.isNotEmpty) {
      return '$displayArea, $district';
    }
    if (displayArea.isNotEmpty) return displayArea;
    if (district.isNotEmpty) return district;
    if (province.isNotEmpty) return province;
    return '';
  }

  /// GPS accuracy classification helpers.
  bool get hasHighAccuracy => accuracy != null && accuracy! <= 50;
  bool get hasMediumAccuracy => accuracy != null && accuracy! > 50 && accuracy! <= 150;
  bool get hasLowAccuracy => accuracy != null && accuracy! > 150;

  /// Formatted accuracy label for display.
  String get accuracyLabel {
    if (accuracy == null) return '';
    if (hasHighAccuracy) return 'High accuracy • ±25m';
    if (hasMediumAccuracy) return 'Medium accuracy • ±90m';
    return 'Low accuracy • ±250m';
  }
}

