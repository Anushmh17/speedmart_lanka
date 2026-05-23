import '../../../location/models/delivery_location.dart';

/// Saved default delivery address for a customer account.
/// Coordinates are stored for internal use only — never shown in UI.
class CustomerDeliveryAddress {
  const CustomerDeliveryAddress({
    required this.customerId,
    this.province = '',
    this.district = '',
    this.city = '',
    this.suburb = '',
    this.approximateArea = '',
    this.streetAddress = '',
    this.formattedAddress = '',
    this.deliveryNote = '',
    this.latitude,
    this.longitude,
    this.isGpsDetected = false,
    this.isManualOverride = false,
    required this.updatedAt,
  });

  final String customerId;
  final String province;
  final String district;
  final String city;
  final String suburb;
  final String approximateArea;
  final String streetAddress;
  final String formattedAddress;
  final String deliveryNote;
  final double? latitude;
  final double? longitude;
  final bool isGpsDetected;
  final bool isManualOverride;
  final DateTime updatedAt;

  bool get isComplete =>
      province.trim().isNotEmpty &&
      district.trim().isNotEmpty &&
      _areaLabel.trim().isNotEmpty &&
      streetAddress.trim().isNotEmpty;

  String get _areaLabel =>
      approximateArea.isNotEmpty ? approximateArea : suburb;

  DeliveryLocation toDeliveryLocation() {
    return DeliveryLocation(
      province: province,
      district: district,
      city: city,
      suburb: suburb.isNotEmpty ? suburb : approximateArea,
      formattedAddress: formattedAddress.isNotEmpty
          ? formattedAddress
          : _buildFormattedAddress(),
      preciseAddress: streetAddress,
      streetAddress: streetAddress,
      deliveryNote: deliveryNote,
      latitude: latitude,
      longitude: longitude,
      isGpsDetected: isGpsDetected,
      isManualOverride: isManualOverride,
      approximateAreaText: approximateArea.isNotEmpty ? approximateArea : suburb,
      source: isGpsDetected ? 'gps' : (isManualOverride ? 'manual' : ''),
    );
  }

  String _buildFormattedAddress() {
    final parts = <String>[
      if (approximateArea.isNotEmpty) approximateArea else if (suburb.isNotEmpty) suburb,
      if (district.isNotEmpty) district,
      if (province.isNotEmpty) province,
    ];
    return parts.join(', ');
  }

  factory CustomerDeliveryAddress.fromDeliveryLocation({
    required String customerId,
    required DeliveryLocation location,
    String? deliveryNote,
  }) {
    return CustomerDeliveryAddress(
      customerId: customerId,
      province: location.province,
      district: location.district,
      city: location.city,
      suburb: location.suburb,
      approximateArea: location.approximateAreaText.isNotEmpty
          ? location.approximateAreaText
          : location.suburb,
      streetAddress: location.streetAddress.isNotEmpty
          ? location.streetAddress
          : location.preciseAddress,
      formattedAddress: location.formattedAddress,
      deliveryNote: deliveryNote ?? location.deliveryNote,
      latitude: location.latitude,
      longitude: location.longitude,
      isGpsDetected: location.isGpsDetected,
      isManualOverride: location.isManualOverride,
      updatedAt: DateTime.now(),
    );
  }

  factory CustomerDeliveryAddress.fromUserFields({
    required String customerId,
    String? deliveryProvince,
    String? deliveryDistrict,
    String? deliveryApproxArea,
    String? deliveryPreciseAddress,
    String? deliveryNote,
  }) {
    final area = deliveryApproxArea?.trim() ?? '';
    final street = deliveryPreciseAddress?.trim() ?? '';
    return CustomerDeliveryAddress(
      customerId: customerId,
      province: deliveryProvince?.trim() ?? '',
      district: deliveryDistrict?.trim() ?? '',
      suburb: area,
      approximateArea: area,
      streetAddress: street,
      formattedAddress: [area, deliveryDistrict, deliveryProvince]
          .where((e) => e != null && e.trim().isNotEmpty)
          .join(', '),
      deliveryNote: deliveryNote?.trim() ?? '',
      isManualOverride: true,
      updatedAt: DateTime.now(),
    );
  }

  factory CustomerDeliveryAddress.fromJson(Map<String, dynamic> json) {
    return CustomerDeliveryAddress(
      customerId: json['customerId'] as String? ?? '',
      province: json['province'] as String? ?? '',
      district: json['district'] as String? ?? '',
      city: json['city'] as String? ?? '',
      suburb: json['suburb'] as String? ?? '',
      approximateArea: json['approximateArea'] as String? ?? '',
      streetAddress: json['streetAddress'] as String? ?? '',
      formattedAddress: json['formattedAddress'] as String? ?? '',
      deliveryNote: json['deliveryNote'] as String? ?? '',
      latitude: (json['latitude'] as num?)?.toDouble(),
      longitude: (json['longitude'] as num?)?.toDouble(),
      isGpsDetected: json['isGpsDetected'] as bool? ?? false,
      isManualOverride: json['isManualOverride'] as bool? ?? false,
      updatedAt: DateTime.tryParse(json['updatedAt'] as String? ?? '') ??
          DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() => {
        'customerId': customerId,
        'province': province,
        'district': district,
        'city': city,
        'suburb': suburb,
        'approximateArea': approximateArea,
        'streetAddress': streetAddress,
        'formattedAddress': formattedAddress,
        'deliveryNote': deliveryNote,
        'latitude': latitude,
        'longitude': longitude,
        'isGpsDetected': isGpsDetected,
        'isManualOverride': isManualOverride,
        'updatedAt': updatedAt.toIso8601String(),
      };

  CustomerDeliveryAddress copyWith({
    String? province,
    String? district,
    String? city,
    String? suburb,
    String? approximateArea,
    String? streetAddress,
    String? formattedAddress,
    String? deliveryNote,
    double? latitude,
    double? longitude,
    bool? isGpsDetected,
    bool? isManualOverride,
    DateTime? updatedAt,
    bool clearLatLng = false,
  }) {
    return CustomerDeliveryAddress(
      customerId: customerId,
      province: province ?? this.province,
      district: district ?? this.district,
      city: city ?? this.city,
      suburb: suburb ?? this.suburb,
      approximateArea: approximateArea ?? this.approximateArea,
      streetAddress: streetAddress ?? this.streetAddress,
      formattedAddress: formattedAddress ?? this.formattedAddress,
      deliveryNote: deliveryNote ?? this.deliveryNote,
      latitude: clearLatLng ? null : (latitude ?? this.latitude),
      longitude: clearLatLng ? null : (longitude ?? this.longitude),
      isGpsDetected: isGpsDetected ?? this.isGpsDetected,
      isManualOverride: isManualOverride ?? this.isManualOverride,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}