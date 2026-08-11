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
    if (digits.startsWith('9494')) digits = digits.substring(2);
    if (digits.startsWith('94') && digits.length == 11) digits = digits.substring(2);
    if (digits.startsWith('0') && digits.length == 10) digits = digits.substring(1);
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
  
  static const List<String> _validPrefixes = ['70','71','72','74','75','76','77','78'];

  /// Validate Sri Lankan mobile number
  /// Must be exactly 9 digits after removing leading 0 and must start with a valid prefix
  static String? validateSriLankaMobile(String? input) {
    if (input == null || input.trim().isEmpty) {
      return 'Phone number is required';
    }

    String digits = digitsOnly(input);

    if (digits.startsWith('0')) digits = digits.substring(1);
    if (digits.startsWith('94')) digits = digits.substring(2);

    if (digits.length != localDigitCount) {
      return 'Phone number must be $localDigitCount digits after +94';
    }

    final prefix = digits.substring(0, 2);
    if (!_validPrefixes.contains(prefix)) {
      return 'Enter a valid mobile number (07X where X is 0,1,2,4,5,6,7,8)';
    }

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

