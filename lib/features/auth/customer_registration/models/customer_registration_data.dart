import 'package:speedmart_lanka/features/location/models/sri_lanka_district.dart';
import 'package:speedmart_lanka/features/location/models/sri_lanka_province.dart';

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
    this.deliveryLatitude,
    this.deliveryLongitude,
    this.deliveryAccuracy,
    this.deliveryDetectedAt,
    this.isLkUser = true,
  });

  final String fullName;
  final String nic;
  final String phone;
  final String email;
  final String country;
  final SriLankaProvince? province;
  final SriLankaDistrict? district;
  final String approxArea;
  final String preciseAddress;
  final String deliveryNote;
  final double? deliveryLatitude;
  final double? deliveryLongitude;
  final double? deliveryAccuracy;
  final DateTime? deliveryDetectedAt;
  final bool isLkUser;

  factory CustomerRegistrationData.empty() => const CustomerRegistrationData();

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
    double? deliveryLatitude,
    double? deliveryLongitude,
    double? deliveryAccuracy,
    DateTime? deliveryDetectedAt,
    bool? isLkUser,
    bool clearProvince = false,
    bool clearDistrict = false,
    bool clearDeliveryCoordinates = false,
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
      deliveryLatitude: clearDeliveryCoordinates ? null : (deliveryLatitude ?? this.deliveryLatitude),
      deliveryLongitude: clearDeliveryCoordinates ? null : (deliveryLongitude ?? this.deliveryLongitude),
      deliveryAccuracy: clearDeliveryCoordinates ? null : (deliveryAccuracy ?? this.deliveryAccuracy),
      deliveryDetectedAt: clearDeliveryCoordinates ? null : (deliveryDetectedAt ?? this.deliveryDetectedAt),
      isLkUser: isLkUser ?? this.isLkUser,
    );
  }

  String get primaryContact => isLkUser ? phone : email;
}
