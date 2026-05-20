class DeliveryLocation {
  final String province;
  final String district;
  final String city;
  final String suburb;
  final String formattedAddress;
  final String streetAddress;
  final String deliveryNote;
  final double? latitude;
  final double? longitude;
  final bool isGpsDetected;
  final bool isManualOverride;

  /// The raw text the customer typed or was auto-filled into the approximate area field.
  /// This is the display value — it may or may not match a known suburb.
  final String approximateAreaText;

  /// How the location was determined: 'gps', 'suggestion', 'manual', or '' (unknown).
  final String source;

  const DeliveryLocation({
    required this.province,
    required this.district,
    required this.city,
    required this.suburb,
    required this.formattedAddress,
    required this.streetAddress,
    this.deliveryNote = '',
    this.latitude,
    this.longitude,
    this.isGpsDetected = false,
    this.isManualOverride = false,
    this.approximateAreaText = '',
    this.source = '',
  });

  factory DeliveryLocation.fromJson(Map<String, dynamic> json) {
    return DeliveryLocation(
      province: json['province'] as String? ?? '',
      district: json['district'] as String? ?? '',
      city: json['city'] as String? ?? '',
      suburb: json['suburb'] as String? ?? '',
      formattedAddress: json['formattedAddress'] as String? ?? '',
      streetAddress: json['streetAddress'] as String? ?? '',
      deliveryNote: json['deliveryNote'] as String? ?? '',
      latitude: (json['latitude'] as num?)?.toDouble(),
      longitude: (json['longitude'] as num?)?.toDouble(),
      isGpsDetected: json['isGpsDetected'] as bool? ?? false,
      isManualOverride: json['isManualOverride'] as bool? ?? false,
      approximateAreaText: json['approximateAreaText'] as String? ?? '',
      source: json['source'] as String? ?? '',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'province': province,
      'district': district,
      'city': city,
      'suburb': suburb,
      'formattedAddress': formattedAddress,
      'streetAddress': streetAddress,
      'deliveryNote': deliveryNote,
      'latitude': latitude,
      'longitude': longitude,
      'isGpsDetected': isGpsDetected,
      'isManualOverride': isManualOverride,
      'approximateAreaText': approximateAreaText,
      'source': source,
    };
  }

  DeliveryLocation copyWith({
    String? province,
    String? district,
    String? city,
    String? suburb,
    String? formattedAddress,
    String? streetAddress,
    String? deliveryNote,
    double? latitude,
    double? longitude,
    bool? isGpsDetected,
    bool? isManualOverride,
    String? approximateAreaText,
    String? source,
    bool clearLatLng = false,
  }) {
    return DeliveryLocation(
      province: province ?? this.province,
      district: district ?? this.district,
      city: city ?? this.city,
      suburb: suburb ?? this.suburb,
      formattedAddress: formattedAddress ?? this.formattedAddress,
      streetAddress: streetAddress ?? this.streetAddress,
      deliveryNote: deliveryNote ?? this.deliveryNote,
      latitude: clearLatLng ? null : (latitude ?? this.latitude),
      longitude: clearLatLng ? null : (longitude ?? this.longitude),
      isGpsDetected: isGpsDetected ?? this.isGpsDetected,
      isManualOverride: isManualOverride ?? this.isManualOverride,
      approximateAreaText: approximateAreaText ?? this.approximateAreaText,
      source: source ?? this.source,
    );
  }

  /// Whether this location has valid GPS coordinates (not null).
  bool get hasCoordinates => latitude != null && longitude != null;

  /// The display label for the approximate area (prefers suburb/city, falls back to manual text).
  String get displayArea {
    if (suburb.isNotEmpty && city.isNotEmpty) return '$suburb, $city';
    if (suburb.isNotEmpty) return suburb;
    if (approximateAreaText.isNotEmpty) return approximateAreaText;
    return '';
  }
}
