import 'package:flutter/services.dart';
import 'package:flutter/foundation.dart';
import 'sri_lanka_phone_helper.dart';

/// Sri Lankan phone number input formatter (local format only).
/// - Automatically removes leading 0 if typed
/// - Accepts max 9 digits after removing leading 0
/// - Formats as: 7X XXX XXXX
/// - Blocks input beyond 9 digits
class SriLankaPhoneInputFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    // Extract digits only
    String digits = SriLankaPhoneHelper.digitsOnly(newValue.text);
    
    // Remove leading 0 if present
    if (digits.startsWith('0')) {
      digits = digits.substring(1);
      debugPrint('[PhoneFormat] removed leading 0');
    }
    
    // Block input beyond 9 digits
    if (digits.length > 9) {
      debugPrint('[PhoneFormat] blocked: exceeds 9 digits');
      return oldValue;
    }

    if (digits.isEmpty) {
      return const TextEditingValue(
        text: '',
        selection: TextSelection.collapsed(offset: 0),
      );
    }

    // Format: 7X XXX XXXX
    String formatted = '';
    
    if (digits.length >= 1) {
      formatted = digits.substring(0, digits.length.clamp(0, 2));
    }
    
    if (digits.length >= 3) {
      formatted += ' ${digits.substring(2, digits.length.clamp(2, 5))}';
    }
    
    if (digits.length >= 6) {
      formatted += ' ${digits.substring(5, digits.length.clamp(5, 9))}';
    }

    debugPrint('[PhoneFormat] formatted: $formatted (${digits.length} digits)');

    // Place cursor at end
    int offset = formatted.length;

    return TextEditingValue(
      text: formatted,
      selection: TextSelection.collapsed(offset: offset),
    );
  }
}

