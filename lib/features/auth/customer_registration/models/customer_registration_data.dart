import 'package:speedmart_lanka/features/location/models/sri_lanka_district.dart';
import 'package:speedmart_lanka/features/location/models/sri_lanka_province.dart';
import 'country_override_info.dart';

/// Immutable snapshot of all customer registration form fields.
///
/// Use [copyWith] to produce updated instances during form editing.
/// The [isLkUser] flag controls which fields are required (phone+NIC vs email).
class CustomerRegistrationData {
  const CustomerRegistrationData({
    this.fullName = '',
    this.nic = '',
    this.phone = '',
    this.email = '',
    this.country = 'Sri Lanka',
    this.province,
    this.district,
    this.approxArea = '',
    this.preciseAddress = '',
    this.deliveryNote = '',
    this.isLkUser = true,
    this.overrideInfo = const CountryOverrideInfo(),
  });

  final String fullName;

  /// National Identity Card — required for Sri Lankan users only.
  /// Old format: 9 digits + V/X  (e.g. 123456789V)
  /// New format: 12 digits       (e.g. 200012345678)
  final String nic;

  /// Required for Sri Lankan users (07XXXXXXXX or +94XXXXXXXXX).
  final String phone;

  /// Required for non-Sri Lankan users.
  final String email;

  /// Required/used for non-Sri Lankan users.
  final String country;

  final SriLankaProvince? province;
  final SriLankaDistrict? district;

  /// Approximate delivery area (neighbourhood / town name).
  final String approxArea;

  /// Full precise delivery address.
  final String preciseAddress;

  /// Optional special delivery instructions.
  final String deliveryNote;

  /// True  → show phone + NIC fields, Sri Lanka address flow.
  /// False → show email field, no NIC requirement.
  final bool isLkUser;

  /// Anti-abuse tracking for country overrides.
  final CountryOverrideInfo overrideInfo;

  /// Creates a blank registration form defaulting to Sri Lankan user.
  factory CustomerRegistrationData.empty() =>
      const CustomerRegistrationData();

  CustomerRegistrationData copyWith({
    String? fullName,
    String? nic,
    String? phone,
    String? email,
    String? country,
    SriLankaProvince? province,
    SriLankaDistrict? district,
    String? approxArea,
    String? preciseAddress,
    String? deliveryNote,
    bool? isLkUser,
    CountryOverrideInfo? overrideInfo,
    // Allows nulling province/district explicitly
    bool clearProvince = false,
    bool clearDistrict = false,
  }) {
    return CustomerRegistrationData(
      fullName: fullName ?? this.fullName,
      nic: nic ?? this.nic,
      phone: phone ?? this.phone,
      email: email ?? this.email,
      country: country ?? this.country,
      province: clearProvince ? null : (province ?? this.province),
      district: clearDistrict ? null : (district ?? this.district),
      approxArea: approxArea ?? this.approxArea,
      preciseAddress: preciseAddress ?? this.preciseAddress,
      deliveryNote: deliveryNote ?? this.deliveryNote,
      isLkUser: isLkUser ?? this.isLkUser,
      overrideInfo: overrideInfo ?? this.overrideInfo,
    );
  }

  /// The primary contact identifier for OTP dispatch.
  /// Returns phone for LK users, email for international users.
  String get primaryContact => isLkUser ? phone : email;

  @override
  String toString() => 'CustomerRegistrationData('
      'name: $fullName, isLk: $isLkUser, '
      'district: ${district?.name}, province: ${province?.name}, '
      'overrideInfo: $overrideInfo)';
}

