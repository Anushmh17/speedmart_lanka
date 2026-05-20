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
  String toString() => 'UserModel(id: $id, name: $fullName, role: ${role.name})';
}
