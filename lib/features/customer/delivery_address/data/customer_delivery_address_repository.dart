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
      final json = jsonDecode(raw) as Map<String, dynamic>;
      final address = CustomerDeliveryAddress.fromJson(json);
      
      print('[ApproxAreaAudit] ===== REPOSITORY LOAD =====');
      print('[ApproxAreaAudit] Loaded from storage key: ${storageKey(customerId)}');
      print('[ApproxAreaAudit] Raw JSON approximateArea: "${json['approximateArea']}"');
      print('[ApproxAreaAudit] Deserialized address.approximateArea: "${address.approximateArea}"');
      print('[ApproxAreaAudit] ===== LOAD COMPLETE =====');
      
      return address;
    } catch (_) {
      return null;
    }
  }

  Future<void> save(CustomerDeliveryAddress address) async {
    print('[ApproxAreaAudit] ===== REPOSITORY SAVE START =====');
    print('[ApproxAreaAudit] Input address.approximateArea: "${address.approximateArea}"');
    print('[ApproxAreaAudit] Storage key: ${storageKey(address.customerId)}');
    
    final json = address.toJson();
    print('[ApproxAreaAudit] Serialized JSON approximateArea: "${json['approximateArea']}"');
    
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      storageKey(address.customerId),
      jsonEncode(json),
    );
    
    print('[ApproxAreaAudit] ===== REPOSITORY SAVE COMPLETE =====');
  }

  Future<void> delete(String customerId) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(storageKey(customerId));
  }
}
