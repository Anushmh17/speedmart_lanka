import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../../../../core/constants/app_constants.dart';
import '../models/customer_delivery_address.dart';

/// Local persistence for per-customer default delivery addresses.
/// TODO: Replace with backend customer address API.
class CustomerDeliveryAddressRepository {
  CustomerDeliveryAddressRepository._();
  static final CustomerDeliveryAddressRepository instance =
      CustomerDeliveryAddressRepository._();

  static String storageKey(String customerId) =>
      '${AppConstants.customerDeliveryAddressPrefix}$customerId';

  Future<CustomerDeliveryAddress?> load(String customerId) async {
    if (customerId.isEmpty) return null;
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(storageKey(customerId));
    if (raw == null || raw.isEmpty) return null;
    try {
      return CustomerDeliveryAddress.fromJson(
        jsonDecode(raw) as Map<String, dynamic>,
      );
    } catch (_) {
      return null;
    }
  }

  Future<void> save(CustomerDeliveryAddress address) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      storageKey(address.customerId),
      jsonEncode(address.toJson()),
    );
  }

  Future<void> delete(String customerId) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(storageKey(customerId));
  }
}