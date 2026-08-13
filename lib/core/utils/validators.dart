import '../constants/app_strings.dart';

/// Centralised form validation functions.
/// Return null for valid, or an error string for invalid.
class Validators {
  Validators._();

  /// Required field
  static String? required(String? value, {String? fieldName}) {
    if (value == null || value.trim().isEmpty) {
      return fieldName != null
          ? '$fieldName is required'
          : AppStrings.fieldRequired;
    }
    return null;
  }

  /// Email address
  static String? email(String? value) {
    if (value == null || value.trim().isEmpty) {
      return AppStrings.fieldRequired;
    }
    final emailRegex = RegExp(r'^[\w\-.]+@([\w\-]+\.)+[\w\-]{2,4}$');
    if (!emailRegex.hasMatch(value.trim())) {
      return AppStrings.invalidEmail;
    }
    return null;
  }

  /// Password (min 8 chars)
  static String? password(String? value) {
    if (value == null || value.isEmpty) {
      return AppStrings.fieldRequired;
    }
    if (value.length < 8) {
      return AppStrings.passwordTooShort;
    }
    return null;
  }

  /// Confirm password match
  static String? confirmPassword(String? value, String original) {
    final basic = password(value);
    if (basic != null) return basic;
    if (value != original) {
      return AppStrings.passwordsDoNotMatch;
    }
    return null;
  }

  /// Full name (min 2 chars)
  static String? fullName(String? value) {
    if (value == null || value.trim().isEmpty) {
      return AppStrings.fieldRequired;
    }
    if (value.trim().length < 2) {
      return AppStrings.nameTooShort;
    }
    return null;
  }

  /// Sri Lankan phone number
  static String? phone(String? value) {
    if (value == null || value.trim().isEmpty) {
      return AppStrings.fieldRequired;
    }
    // Accepts: 07XXXXXXXX or +947XXXXXXXX or 947XXXXXXXX
    final phoneRegex = RegExp(r'^(?:\+94|94|0)?[1-9]\d{8}$');
    final cleaned = value.replaceAll(RegExp(r'[\s\-()]'), '');
    if (!phoneRegex.hasMatch(cleaned)) {
      return AppStrings.invalidPhone;
    }
    return null;
  }

  /// Business / shop name
  static String? businessName(String? value) {
    if (value == null || value.trim().isEmpty) {
      return AppStrings.fieldRequired;
    }
    if (value.trim().length < 2) {
      return 'Business name must be at least 2 characters';
    }
    return null;
  }

  /// Sri Lanka National Identity Card (NIC).
  ///
  /// Accepts:
  ///   Old NIC — 9 digits + V  (e.g. 123456789V)
  ///   New NIC — exactly 12 digits  (e.g. 200012345678)
  static String? nic(String? value) {
    if (value == null || value.trim().isEmpty) {
      return AppStrings.fieldRequired;
    }
    final clean = value.trim().toUpperCase();
    // Accept only old format with 'V' and new 12-digit format
    if (RegExp(r'^\d{9}V$').hasMatch(clean)) {
      if (_nicEncodesValidDob(clean)) return null;
      return 'Enter a valid NIC (date information looks invalid)';
    }
    if (RegExp(r'^\d{12}$').hasMatch(clean)) {
      if (_nicEncodesValidDob(clean)) return null;
      return 'Enter a valid NIC (date information looks invalid)';
    }
    return 'Enter a valid NIC (e.g. 123456789V or 200012345678)';
  }

  static bool _nicEncodesValidDob(String nic) {
    final cleaned = nic.replaceAll(RegExp(r'[^A-Za-z0-9]'), '').toUpperCase();
    final now = DateTime.now().year;

    // Old format: YYDDDxxxxxV -> first 2 digits year, next 3 digits day-of-year
    if (RegExp(r'^\d{9}V$').hasMatch(cleaned)) {
      final yy = int.tryParse(cleaned.substring(0, 2));
      final ddd = int.tryParse(cleaned.substring(2, 5));
      if (yy == null || ddd == null) return false;
      int year = 1900 + yy;
      int age = now - year;
      if (age < 10) year = 2000 + yy;
      if (year > now || now - year > 120) return false;
      int dayOfYear = ddd;
      if (dayOfYear > 500) dayOfYear -= 500; // female offset
      if (dayOfYear < 1) return false;
      final isLeap = (year % 4 == 0 && (year % 100 != 0 || year % 400 == 0));
      final maxDay = isLeap ? 366 : 365;
      if (dayOfYear > maxDay) return false;
      return true;
    }

    // New format: YYYYDDDxxxxxx -> first 4 digits year, next 3 digits day-of-year
    if (RegExp(r'^\d{12}$').hasMatch(cleaned)) {
      final year = int.tryParse(cleaned.substring(0, 4));
      final ddd = int.tryParse(cleaned.substring(4, 7));
      if (year == null || ddd == null) return false;
      if (year > now || now - year > 120) return false;
      int dayOfYear = ddd;
      if (dayOfYear > 500) dayOfYear -= 500;
      if (dayOfYear < 1) return false;
      final isLeap = (year % 4 == 0 && (year % 100 != 0 || year % 400 == 0));
      final maxDay = isLeap ? 366 : 365;
      if (dayOfYear > maxDay) return false;
      return true;
    }

    return false;
  }

  /// Generic min length
  static String? minLength(String? value, int min, {String? fieldName}) {
    if (value == null || value.trim().isEmpty) {
      return AppStrings.fieldRequired;
    }
    if (value.trim().length < min) {
      return '${fieldName ?? 'Field'} must be at least $min characters';
    }
    return null;
  }
}

