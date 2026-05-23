import 'dart:convert';
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
    await _secure.write(
      key: AppConstants.userKey,
      value: jsonEncode(userJson),
    );
  }

  static Future<Map<String, dynamic>?> getUser() async {
    final raw = await _secure.read(key: AppConstants.userKey);
    if (raw == null) return null;
    return jsonDecode(raw) as Map<String, dynamic>;
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

  // ── Clear session / all ───────────────────────────────────────────────────

  /// Clears logged-in session only. Keeps registered users and app preferences.
  static Future<void> clearSession() async {
    await deleteToken();
    await deleteUser();
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(AppConstants.roleKey);
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

