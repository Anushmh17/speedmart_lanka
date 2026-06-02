import 'user_role.dart';

/// Core user model shared across all roles.
/// Role-specific data (vendor profile, etc.) is stored in separate models.
class UserModel {
  final String id;
  final String fullName;
  final String email;
  final String phone;
  final UserRole role;
  final bool isActive;
  final bool isVerified;
  final String? profileImageUrl;
  final DateTime createdAt;

  /// Vendor-specific fields (nullable for customer/admin)
  final String? businessName;
  final bool? vendorApproved;
  final List<String>? vendorCategories;

  /// Admin-assigned vendor shop location (not user-editable)
  final String? shopName;
  final String? shopAddress;
  final double? shopLatitude;
  final double? shopLongitude;
  final double? assignedRadiusKm;
  final bool? isShopLocationAssigned;

  /// Country override and risk fields for anti-abuse audit
  final String? detectedCountry;
  final String? selectedCountry;
  final bool? countryOverride;
  final String? detectionSource;
  final String? riskFlag;
  final bool? verifiedPhone;
  final bool? verifiedEmail;

  /// Sri Lanka NIC (old or new format).
  final String? nic;

  /// Default delivery profile captured at registration.
  final String? deliveryCountry;
  final String? deliveryProvince;
  final String? deliveryDistrict;
  final String? deliveryApproxArea;
  final String? deliveryPreciseAddress;
  final String? deliveryNote;

  const UserModel({
    required this.id,
    required this.fullName,
    required this.email,
    required this.phone,
    required this.role,
    required this.isActive,
    required this.isVerified,
    required this.createdAt,
    this.profileImageUrl,
    this.businessName,
    this.vendorApproved,
    this.vendorCategories,
    this.detectedCountry,
    this.selectedCountry,
    this.countryOverride,
    this.detectionSource,
    this.riskFlag,
    this.verifiedPhone,
    this.verifiedEmail,
    this.nic,
    this.deliveryCountry,
    this.deliveryProvince,
    this.deliveryDistrict,
    this.deliveryApproxArea,
    this.deliveryPreciseAddress,
    this.deliveryNote,
    this.shopName,
    this.shopAddress,
    this.shopLatitude,
    this.shopLongitude,
    this.assignedRadiusKm,
    this.isShopLocationAssigned,
  });

  /// Create from JSON (API response)
  factory UserModel.fromJson(Map<String, dynamic> json) {
    return UserModel(
      id: json['id'] as String,
      fullName: json['full_name'] as String,
      email: json['email'] as String,
      phone: json['phone'] as String,
      role: UserRole.fromString(json['role'] as String),
      isActive: json['is_active'] as bool? ?? true,
      isVerified: json['is_verified'] as bool? ?? false,
      createdAt: DateTime.parse(json['created_at'] as String),
      profileImageUrl: json['profile_image_url'] as String?,
      businessName: json['business_name'] as String?,
      vendorApproved: json['vendor_approved'] as bool?,
      vendorCategories: (json['vendor_categories'] as List<dynamic>?)
          ?.map((e) => e as String)
          .toList(),
      detectedCountry: json['detected_country'] as String?,
      selectedCountry: json['selected_country'] as String?,
      countryOverride: json['country_override'] as bool?,
      detectionSource: json['detection_source'] as String?,
      riskFlag: json['risk_flag'] as String?,
      verifiedPhone: json['verified_phone'] as bool?,
      verifiedEmail: json['verified_email'] as bool?,
      nic: json['nic'] as String?,
      deliveryCountry: json['delivery_country'] as String?,
      deliveryProvince: json['delivery_province'] as String?,
      deliveryDistrict: json['delivery_district'] as String?,
      deliveryApproxArea: json['delivery_approx_area'] as String?,
      deliveryPreciseAddress: json['delivery_precise_address'] as String?,
      deliveryNote: json['delivery_note'] as String?,
      shopName: json['shop_name'] as String?,
      shopAddress: json['shop_address'] as String?,
      shopLatitude: (json['shop_latitude'] as num?)?.toDouble(),
      shopLongitude: (json['shop_longitude'] as num?)?.toDouble(),
      assignedRadiusKm: (json['assigned_radius_km'] as num?)?.toDouble(),
      isShopLocationAssigned: json['is_shop_location_assigned'] as bool?,
    );
  }

  /// Convert to JSON (for local storage)
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'full_name': fullName,
      'email': email,
      'phone': phone,
      'role': role.name,
      'is_active': isActive,
      'is_verified': isVerified,
      'created_at': createdAt.toIso8601String(),
      'profile_image_url': profileImageUrl,
      'business_name': businessName,
      'vendor_approved': vendorApproved,
      'vendor_categories': vendorCategories,
      'detected_country': detectedCountry,
      'selected_country': selectedCountry,
      'country_override': countryOverride,
      'detection_source': detectionSource,
      'risk_flag': riskFlag,
      'verified_phone': verifiedPhone,
      'verified_email': verifiedEmail,
      'nic': nic,
      'delivery_country': deliveryCountry,
      'delivery_province': deliveryProvince,
      'delivery_district': deliveryDistrict,
      'delivery_approx_area': deliveryApproxArea,
      'delivery_precise_address': deliveryPreciseAddress,
      'delivery_note': deliveryNote,
      'shop_name': shopName,
      'shop_address': shopAddress,
      'shop_latitude': shopLatitude,
      'shop_longitude': shopLongitude,
      'assigned_radius_km': assignedRadiusKm,
      'is_shop_location_assigned': isShopLocationAssigned,
    };
  }

  /// Copy with overrides
  UserModel copyWith({
    String? id,
    String? fullName,
    String? email,
    String? phone,
    UserRole? role,
    bool? isActive,
    bool? isVerified,
    DateTime? createdAt,
    String? profileImageUrl,
    String? businessName,
    bool? vendorApproved,
    List<String>? vendorCategories,
    String? detectedCountry,
    String? selectedCountry,
    bool? countryOverride,
    String? detectionSource,
    String? riskFlag,
    bool? verifiedPhone,
    bool? verifiedEmail,
    String? nic,
    String? deliveryCountry,
    String? deliveryProvince,
    String? deliveryDistrict,
    String? deliveryApproxArea,
    String? deliveryPreciseAddress,
    String? deliveryNote,
    String? shopName,
    String? shopAddress,
    double? shopLatitude,
    double? shopLongitude,
    double? assignedRadiusKm,
    bool? isShopLocationAssigned,
  }) {
    return UserModel(
      id: id ?? this.id,
      fullName: fullName ?? this.fullName,
      email: email ?? this.email,
      phone: phone ?? this.phone,
      role: role ?? this.role,
      isActive: isActive ?? this.isActive,
      isVerified: isVerified ?? this.isVerified,
      createdAt: createdAt ?? this.createdAt,
      profileImageUrl: profileImageUrl ?? this.profileImageUrl,
      businessName: businessName ?? this.businessName,
      vendorApproved: vendorApproved ?? this.vendorApproved,
      vendorCategories: vendorCategories ?? this.vendorCategories,
      detectedCountry: detectedCountry ?? this.detectedCountry,
      selectedCountry: selectedCountry ?? this.selectedCountry,
      countryOverride: countryOverride ?? this.countryOverride,
      detectionSource: detectionSource ?? this.detectionSource,
      riskFlag: riskFlag ?? this.riskFlag,
      verifiedPhone: verifiedPhone ?? this.verifiedPhone,
      verifiedEmail: verifiedEmail ?? this.verifiedEmail,
      nic: nic ?? this.nic,
      deliveryCountry: deliveryCountry ?? this.deliveryCountry,
      deliveryProvince: deliveryProvince ?? this.deliveryProvince,
      deliveryDistrict: deliveryDistrict ?? this.deliveryDistrict,
      deliveryApproxArea: deliveryApproxArea ?? this.deliveryApproxArea,
      deliveryPreciseAddress:
          deliveryPreciseAddress ?? this.deliveryPreciseAddress,
      deliveryNote: deliveryNote ?? this.deliveryNote,
      shopName: shopName ?? this.shopName,
      shopAddress: shopAddress ?? this.shopAddress,
      shopLatitude: shopLatitude ?? this.shopLatitude,
      shopLongitude: shopLongitude ?? this.shopLongitude,
      assignedRadiusKm: assignedRadiusKm ?? this.assignedRadiusKm,
      isShopLocationAssigned: isShopLocationAssigned ?? this.isShopLocationAssigned,
    );
  }

  /// First name from full name
  String get firstName => fullName.split(' ').first;

  /// Initials for avatar
  String get initials {
    final parts = fullName.trim().split(' ');
    if (parts.length >= 2) {
      return '${parts.first[0]}${parts.last[0]}'.toUpperCase();
    }
    return fullName.substring(0, fullName.length >= 2 ? 2 : 1).toUpperCase();
  }

  @override
  String toString() => 'UserModel(id: $id, name: $fullName, role: ${role.name}, riskFlag: $riskFlag)';
}
