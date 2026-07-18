import 'package:flutter/services.dart';

/// Restricts input to a valid commission percentage: 0.0 – 100.0 (one decimal place).
class CommissionInputFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    final text = newValue.text;

    if (text.isEmpty) return newValue;

    // Only allow digits and a single dot
    if (!RegExp(r'^\d*\.?\d*$').hasMatch(text)) return oldValue;

    // Block leading zeros before a non-zero digit (e.g. 05, 007)
    if (RegExp(r'^0\d').hasMatch(text)) return oldValue;

    // Block more than one decimal place
    final parts = text.split('.');
    if (parts.length == 2 && parts[1].length > 1) return oldValue;

    // Block values above 100.0
    final value = double.tryParse(text);
    if (value != null && value > 100.0) return oldValue;

    // Block "100.x" where x > 0 (e.g. 100.1)
    if (parts.length == 2 && parts[0] == '100' && parts[1].isNotEmpty) {
      return oldValue;
    }

    return newValue;
  }
}

