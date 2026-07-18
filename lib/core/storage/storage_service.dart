import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../constants/app_constants.dart';

/// Handles all local storage operations.
/// Sensitive data (tokens) → FlutterSecureStorage.
/// Non-sensitive data (theme, role) → SharedPreferences.
class StorageService {
  StorageService._();

  static const _secure = FlutterSecureStorage(
    aOptions: AndroidOptions(encryptedSharedPreferences: true),
  );

  // ── Token (secure) ────────────────────────────────────────────────────────

  static Future<void> saveToken(String token) async {
    await _secure.write(key: AppConstants.tokenKey, value: token);
  }

  static Future<String?> getToken() async {
    return _secure.read(key: AppConstants.tokenKey);
  }

  static Future<void> deleteToken() async {
    await _secure.delete(key: AppConstants.tokenKey);
  }

  // ── User JSON (secure) ────────────────────────────────────────────────────

  static Future<void> saveUser(Map<String, dynamic> userJson) async {
    debugPrint('[CategoryAudit] ===== STORAGE SERVICE SAVE START =====');
    debugPrint('[CategoryAudit] saveUser called with allowed_categories: ${userJson['allowed_categories']}');
    debugPrint('[CategoryAudit] Full userJson keys: ${userJson.keys.toList()}');
    debugPrint('[CategoryAudit] Serializing to secure storage...');
    
    await _secure.write(
      key: AppConstants.userKey,
      value: jsonEncode(userJson),
    );
    
    debugPrint('[CategoryAudit] ===== STORAGE SERVICE SAVE COMPLETE =====');
  }

  static Future<Map<String, dynamic>?> getUser() async {
    final raw = await _secure.read(key: AppConstants.userKey);
    if (raw == null) return null;
    final decoded = jsonDecode(raw) as Map<String, dynamic>;
    
    debugPrint('[CategoryAudit] ===== STORAGE SERVICE LOAD =====');
    debugPrint('[CategoryAudit] getUser loaded allowed_categories: ${decoded['allowed_categories']}');
    debugPrint('[CategoryAudit] getUser loaded vendor_categories: ${decoded['vendor_categories']}');
    
    return decoded;
  }

  static Future<void> deleteUser() async {
    await _secure.delete(key: AppConstants.userKey);
  }

  // ── Theme (non-sensitive) ─────────────────────────────────────────────────

  static Future<void> saveThemeMode(String mode) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(AppConstants.themeKey, mode);
  }

  static Future<String?> getThemeMode() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(AppConstants.themeKey);
  }

  // ── Role (non-sensitive) ──────────────────────────────────────────────────

  static Future<void> saveRole(String role) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(AppConstants.roleKey, role);
  }

  static Future<String?> getRole() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(AppConstants.roleKey);
  }

  // ── Request Drafts (non-sensitive) ────────────────────────────────────────

  static Future<void> saveDraftRequest(Map<String, dynamic> draftJson) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('draft_request', jsonEncode(draftJson));
  }

  static Future<Map<String, dynamic>?> getDraftRequest() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString('draft_request');
    if (raw == null) return null;
    return jsonDecode(raw) as Map<String, dynamic>;
  }

  static Future<void> clearDraftRequest() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('draft_request');
  }

  // ── Mock registered users (SharedPreferences, until backend is ready) ───

  /// Persists the local mock user registry.
  /// TODO: Replace with backend user sync when API is available.
  static Future<void> saveRegisteredUsers(
    List<Map<String, dynamic>> users,
  ) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      AppConstants.registeredUsersKey,
      jsonEncode(users),
    );
  }

  static Future<void> _saveJsonList(
    String key,
    List<Map<String, dynamic>> items,
  ) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(key, jsonEncode(items));
  }

  static Future<List<Map<String, dynamic>>> _loadJsonList(String key) async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(key);
    if (raw == null || raw.isEmpty) return [];
    try {
      final decoded = jsonDecode(raw) as List<dynamic>;
      return decoded
          .map((e) => Map<String, dynamic>.from(e as Map))
          .toList();
    } catch (_) {
      return [];
    }
  }

  /// TODO: Replace with backend request API.
  static Future<void> saveShoppingRequests(
    List<Map<String, dynamic>> requests,
  ) async {
    await _saveJsonList(AppConstants.shoppingRequestsKey, requests);
  }

  static Future<List<Map<String, dynamic>>> getShoppingRequests() async {
    return _loadJsonList(AppConstants.shoppingRequestsKey);
  }

  /// TODO: Replace with backend proposal API.
  static Future<void> saveVendorProposals(
    List<Map<String, dynamic>> proposals,
  ) async {
    await _saveJsonList(AppConstants.vendorProposalsKey, proposals);
  }

  static Future<List<Map<String, dynamic>>> getVendorProposals() async {
    return _loadJsonList(AppConstants.vendorProposalsKey);
  }

  /// TODO: Replace with backend order API.
  static Future<void> saveOrders(List<Map<String, dynamic>> orders) async {
    await _saveJsonList(AppConstants.ordersKey, orders);
  }

  static Future<List<Map<String, dynamic>>> getOrders() async {
    return _loadJsonList(AppConstants.ordersKey);
  }

  /// TODO: Replace with backend payment API.
  static Future<void> savePayments(List<Map<String, dynamic>> payments) async {
    await _saveJsonList(AppConstants.paymentsKey, payments);
  }

  static Future<List<Map<String, dynamic>>> getPayments() async {
    return _loadJsonList(AppConstants.paymentsKey);
  }

  static Future<void> saveSavedProposals(List<String> proposalIds) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList('saved_proposals', proposalIds);
  }

  static Future<List<String>?> getSavedProposals() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getStringList('saved_proposals');
  }

  /// TODO: Replace with backend notification API / Firebase Cloud Messaging.
  static Future<void> saveNotifications(
    List<Map<String, dynamic>> notifications,
  ) async {
    await _saveJsonList(AppConstants.notificationsKey, notifications);
  }

  static Future<List<Map<String, dynamic>>> getNotifications() async {
    return _loadJsonList(AppConstants.notificationsKey);
  }

  static Future<List<Map<String, dynamic>>> getRegisteredUsers() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(AppConstants.registeredUsersKey);
    if (raw == null || raw.isEmpty) return [];
    try {
      final decoded = jsonDecode(raw) as List<dynamic>;
      return decoded
          .map((e) => Map<String, dynamic>.from(e as Map))
          .toList();
    } catch (_) {
      return [];
    }
  }

  // ── Passwords (mock auth, non-sensitive during dev) ────────────────────────

  /// Persists password store for mock authentication.
  /// TODO: Replace with backend authentication when API is ready.
  static Future<void> savePasswords(Map<String, String> passwords) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final jsonMap = <String, dynamic>{};
      passwords.forEach((key, value) {
        jsonMap[key] = value;
      });
      final encoded = jsonEncode(jsonMap);
      await prefs.setString('auth_passwords', encoded);
      debugPrint('[Storage] Saved ${passwords.length} passwords: ${passwords.keys.toList()}');
    } catch (e) {
      debugPrint('[Storage] ERROR saving passwords: $e');
      rethrow;
    }
  }

  /// Loads password store from storage.
  static Future<Map<String, String>> getPasswords() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString('auth_passwords');
      if (raw == null || raw.isEmpty) {
        debugPrint('[Storage] No passwords in storage (key is empty/null)');
        return {};
      }
      final decoded = jsonDecode(raw) as Map<String, dynamic>;
      final result = Map<String, String>.from(
        decoded.map((k, v) => MapEntry(k, v.toString())),
      );
      debugPrint('[Storage] Loaded ${result.length} passwords: ${result.keys.toList()}');
      return result;
    } catch (e) {
      debugPrint('[Storage] ERROR loading passwords: $e');
      return {};
    }
  }

  // ── Customer Remember Me ─────────────────────────────────────────────────

  static Future<void> saveCustomerRememberMe(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('customer_remember_me', value);
  }

  static Future<bool> getCustomerRememberMe() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool('customer_remember_me') ?? false;
  }

  static Future<void> clearCustomerRememberMe() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('customer_remember_me');
  }

  // ── Vendor Remember Me ──────────────────────────────────────────────────

  static Future<void> saveVendorRememberMe(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('vendor_remember_me', value);
  }

  static Future<bool> getVendorRememberMe() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool('vendor_remember_me') ?? false;
  }

  static Future<void> clearVendorRememberMe() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('vendor_remember_me');
  }

  // ── Platform Settings (admin-configured defaults) ────────────────────────

  static Future<void> savePlatformSettings({
    required double standardCommissionPct,
    required int standardRadiusKm,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setDouble('platform_commission_pct', standardCommissionPct);
    await prefs.setInt('platform_radius_km', standardRadiusKm);
  }

  static Future<({double commissionPct, int radiusKm})> getPlatformSettings() async {
    final prefs = await SharedPreferences.getInstance();
    return (
      commissionPct: prefs.getDouble('platform_commission_pct') ?? 10.0,
      radiusKm: prefs.getInt('platform_radius_km') ?? 5,
    );
  }

  // ── Clear session / all ───────────────────────────────────────────────────

  /// Clears logged-in session only. Keeps registered users, app preferences, and last role.
  static Future<void> clearSession() async {
    await deleteToken();
    await deleteUser();
  }

  /// Full wipe (e.g. uninstall simulation). Preserves registered users + theme.
  static Future<void> clearAll() async {
    final users = await getRegisteredUsers();
    final theme = await getThemeMode();
    final draft = await getDraftRequest();
    final requests = await getShoppingRequests();
    final proposals = await getVendorProposals();
    final orders = await getOrders();

    await _secure.deleteAll();
    final prefs = await SharedPreferences.getInstance();
    await prefs.clear();

    if (theme != null) await saveThemeMode(theme);
    if (users.isNotEmpty) await saveRegisteredUsers(users);
    if (draft != null) await saveDraftRequest(draft);
    if (requests.isNotEmpty) await saveShoppingRequests(requests);
    if (proposals.isNotEmpty) await saveVendorProposals(proposals);
    if (orders.isNotEmpty) await saveOrders(orders);
  }
}


