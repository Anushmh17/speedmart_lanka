import 'package:flutter/foundation.dart';

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
    this.accuracy,
    this.detectedAt,
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
  final double? accuracy;
  final DateTime? detectedAt;
  final DateTime updatedAt;

  bool get isComplete =>
      province.trim().isNotEmpty &&
      district.trim().isNotEmpty &&
      _areaLabel.trim().isNotEmpty &&
      streetAddress.trim().isNotEmpty &&
      hasValidCoordinates;

  bool get hasValidCoordinates =>
      latitude != null &&
      longitude != null &&
      latitude != 0.0 &&
      longitude != 0.0;

  String get _areaLabel =>
      approximateArea.isNotEmpty ? approximateArea : suburb;

  DeliveryLocation toDeliveryLocation() {
    debugPrint('[ApproxAreaAudit] ===== toDeliveryLocation START =====');
    debugPrint('[ApproxAreaAudit] this.approximateArea: "$approximateArea"');
    debugPrint('[ApproxAreaAudit] this.suburb: "$suburb"');
    
    final areaText = approximateArea.isNotEmpty ? approximateArea : suburb;
    debugPrint('[ApproxAreaAudit] Result approximateAreaText: "$areaText"');
    
    final result = DeliveryLocation(
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
      approximateAreaText: areaText,
      source: isGpsDetected ? 'gps' : (isManualOverride ? 'manual' : ''),
      accuracy: accuracy,
      detectedAt: detectedAt,
    );
    
    debugPrint('[ApproxAreaAudit] ===== toDeliveryLocation COMPLETE =====');
    return result;
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
    debugPrint('[ApproxAreaAudit] ===== fromDeliveryLocation START =====');
    debugPrint('[ApproxAreaAudit] Input location.approximateAreaText: "${location.approximateAreaText}"');
    debugPrint('[ApproxAreaAudit] Input location.suburb: "${location.suburb}"');
    
    final approximateArea = location.approximateAreaText.isNotEmpty
        ? location.approximateAreaText
        : location.suburb;
    
    debugPrint('[ApproxAreaAudit] Result approximateArea: "$approximateArea"');
    debugPrint('[ApproxAreaAudit] ===== fromDeliveryLocation COMPLETE =====');
    
    return CustomerDeliveryAddress(
      customerId: customerId,
      province: location.province,
      district: location.district,
      city: location.city,
      suburb: location.suburb,
      approximateArea: approximateArea,
      streetAddress: location.streetAddress.isNotEmpty
          ? location.streetAddress
          : location.preciseAddress,
      formattedAddress: location.formattedAddress,
      deliveryNote: deliveryNote ?? location.deliveryNote,
      latitude: location.latitude,
      longitude: location.longitude,
      isGpsDetected: location.isGpsDetected,
      isManualOverride: location.isManualOverride,
      accuracy: location.accuracy,
      detectedAt: location.detectedAt,
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
    double? accuracy,
    DateTime? detectedAt,
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
      accuracy: accuracy,
      detectedAt: detectedAt,
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
      accuracy: (json['accuracy'] as num?)?.toDouble(),
      detectedAt: json['detectedAt'] != null ? DateTime.parse(json['detectedAt'] as String) : null,
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
        'accuracy': accuracy,
        'detectedAt': detectedAt?.toIso8601String(),
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
    double? accuracy,
    DateTime? detectedAt,
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
      accuracy: accuracy ?? this.accuracy,
      detectedAt: detectedAt ?? this.detectedAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
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

