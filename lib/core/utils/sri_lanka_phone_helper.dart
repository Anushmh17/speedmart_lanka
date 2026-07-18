import 'package:flutter/foundation.dart';

/// Central helper for Sri Lankan phone number handling
class SriLankaPhoneHelper {
  static const String countryCode = '+94';
  static const int localDigitCount = 9; // After removing leading 0
  
  /// Extract digits only from input
  static String digitsOnly(String input) {
    return input.replaceAll(RegExp(r'[^\d]'), '');
  }
  
  /// Normalize Sri Lankan phone for E.164 storage format
  /// Input: "072 499 9660" or "72 499 9660" or "0724999660" or "724999660"
  /// Output: "+94724999660"
  static String normalizeSriLankaPhoneForStorage(String input) {
    String digits = digitsOnly(input);
    
    // Remove leading 0 if present
    if (digits.startsWith('0')) {
      digits = digits.substring(1);
    }
    
    // Remove +94 prefix if already present
    if (digits.startsWith('94')) {
      digits = digits.substring(2);
    }
    
    debugPrint('[SriLankaPhone] normalize input: $input -> digits: $digits -> output: $countryCode$digits');
    return '$countryCode$digits';
  }
  
  /// Format Sri Lankan local number for UI display (without country code prefix)
  /// Input: "+94724999660" or "0724999660" or "724999660"
  /// Output: "72 499 9660"
  static String formatSriLankaLocalForUi(String input) {
    String digits = digitsOnly(input);
    
    // Remove +94 prefix if present
    if (digits.startsWith('94')) {
      digits = digits.substring(2);
    }
    
    // Remove leading 0 if present
    if (digits.startsWith('0')) {
      digits = digits.substring(1);
    }
    
    if (digits.length >= 9) {
      // Format as: XX XXX XXXX (e.g., 72 499 9660)
      return '${digits.substring(0, 2)} ${digits.substring(2, 5)} ${digits.substring(5, 9)}';
    } else if (digits.length >= 5) {
      // Partial format: XX XXX X...
      return '${digits.substring(0, 2)} ${digits.substring(2, 5)} ${digits.substring(5)}';
    } else if (digits.length >= 2) {
      // Partial format: XX X...
      return '${digits.substring(0, 2)} ${digits.substring(2)}';
    }
    
    return digits;
  }
  
  /// Validate Sri Lankan mobile number
  /// Must be exactly 9 digits after removing leading 0 and must start with 7
  static String? validateSriLankaMobile(String? input) {
    if (input == null || input.trim().isEmpty) {
      return 'Phone number is required';
    }
    
    String digits = digitsOnly(input);
    
    // Remove leading 0 if present
    if (digits.startsWith('0')) {
      digits = digits.substring(1);
    }
    
    // Remove +94 prefix if present
    if (digits.startsWith('94')) {
      digits = digits.substring(2);
    }
    
    if (digits.length != localDigitCount) {
      debugPrint('[SriLankaPhone] validation failed: length ${digits.length} != $localDigitCount');
      return 'Phone number must be $localDigitCount digits after +94';
    }
    
    if (!digits.startsWith('7')) {
      debugPrint('[SriLankaPhone] validation failed: does not start with 7');
      return 'Mobile number must start with 7 (e.g., 71, 72, 77)';
    }
    
    debugPrint('[SriLankaPhone] validation passed: $digits');
    return null;
  }
  
  /// Get display format with country code prefix
  /// Input: "+94724999660" or "724999660"
  /// Output: "+94 72 499 9660"
  static String formatWithCountryCode(String input) {
    final local = formatSriLankaLocalForUi(input);
    return '$countryCode $local';
  }
}

