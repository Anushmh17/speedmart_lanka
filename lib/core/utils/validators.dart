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
  ///   Old NIC — 9 digits + V or X  (e.g. 123456789V)
  ///   New NIC — exactly 12 digits  (e.g. 200012345678)
  static String? nic(String? value) {
    if (value == null || value.trim().isEmpty) {
      return AppStrings.fieldRequired;
    }
    final clean = value.trim().toUpperCase();
    if (RegExp(r'^\d{9}[VX]$').hasMatch(clean)) return null;
    if (RegExp(r'^\d{12}$').hasMatch(clean)) return null;
    return 'Enter a valid NIC (e.g. 123456789V or 200012345678)';
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

