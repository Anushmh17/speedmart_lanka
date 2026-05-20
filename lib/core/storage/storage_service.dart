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

  // ── Clear all ─────────────────────────────────────────────────────────────

  /// Call on logout — clears both secure and shared storage
  static Future<void> clearAll() async {
    await _secure.deleteAll();
    final prefs = await SharedPreferences.getInstance();
    await prefs.clear();
  }
}

