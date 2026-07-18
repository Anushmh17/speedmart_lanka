/// A suggestion item shown in the searchable location field autocomplete list.
///
/// Can represent a province, district, or a typed area name.
/// Coordinates are optional — only present when the suggestion maps to a
/// known geographic point.
class LocationSuggestion {
  /// Human-readable display text shown in the dropdown.
  final String display;

  /// Province id this suggestion belongs to, if known.
  final int? provinceId;

  /// District id this suggestion belongs to, if known.
  final int? districtId;

  /// Province name, if resolved.
  final String? provinceName;

  /// District name, if resolved.
  final String? districtName;

  /// Optional coordinates when a known suburb/town is matched.
  final double? latitude;
  final double? longitude;

  /// Where this suggestion came from: 'recent', 'search', 'gps'
  final String source;

  const LocationSuggestion({
    required this.display,
    this.provinceId,
    this.districtId,
    this.provinceName,
    this.districtName,
    this.latitude,
    this.longitude,
    this.source = 'search',
  });

  bool get hasCoordinates => latitude != null && longitude != null;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is LocationSuggestion && other.display == display;

  @override
  int get hashCode => display.hashCode;

  Map<String, dynamic> toJson() => {
        'display': display,
        'provinceId': provinceId,
        'districtId': districtId,
        'provinceName': provinceName,
        'districtName': districtName,
        'latitude': latitude,
        'longitude': longitude,
        'source': source,
      };

  factory LocationSuggestion.fromJson(Map<String, dynamic> json) {
    return LocationSuggestion(
      display: json['display'] as String? ?? '',
      provinceId: json['provinceId'] as int?,
      districtId: json['districtId'] as int?,
      provinceName: json['provinceName'] as String?,
      districtName: json['districtName'] as String?,
      latitude: (json['latitude'] as num?)?.toDouble(),
      longitude: (json['longitude'] as num?)?.toDouble(),
      source: json['source'] as String? ?? 'search',
    );
  }
}

