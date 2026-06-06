import 'package:flutter/foundation.dart';

/// Single source of truth for all vendor categories.
/// Categories are stored in normalized lowercase format internally.
/// Display format uses proper title case capitalization.
class VendorCategories {
  /// Master list of all valid vendor categories (display format)
  static const List<String> displayNames = [
    'Groceries',
    'Electronics',
    'Hardware',
    'Furniture',
    'Pharmacy',
    'Clothing',
    'Vehicle Parts',
    'Home Appliances',
  ];

  /// Normalized list (lowercase) - used for storage and comparison
  static const List<String> normalizedList = [
    'groceries',
    'electronics',
    'hardware',
    'furniture',
    'pharmacy',
    'clothing',
    'vehicle parts',
    'home appliances',
  ];

  /// Mapping from normalized to display format for easy lookup
  static const Map<String, String> normalizationMap = {
    'groceries': 'Groceries',
    'electronics': 'Electronics',
    'hardware': 'Hardware',
    'furniture': 'Furniture',
    'pharmacy': 'Pharmacy',
    'clothing': 'Clothing',
    'vehicle parts': 'Vehicle Parts',
    'home appliances': 'Home Appliances',
  };

  /// Convert display format to normalized format
  /// Example: 'Home Appliances' -> 'home appliances'
  static String normalize(String displayValue) {
    final normalized = displayValue.trim().toLowerCase();
    if (!normalizedList.contains(normalized)) {
      debugPrint(
          '[CategoryNormalize] WARNING: "$displayValue" is not a valid category');
    }
    return normalized;
  }

  /// Convert normalized format to display format
  /// Example: 'home appliances' -> 'Home Appliances'
  static String display(String normalizedValue) {
    final displayValue = normalizationMap[normalizedValue.trim().toLowerCase()];
    if (displayValue == null) {
      debugPrint(
          '[CategoryNormalize] WARNING: "$normalizedValue" not found in normalization map');
      // Fallback: title case if not in map
      return normalizedValue
          .split(' ')
          .map((word) => word[0].toUpperCase() + word.substring(1))
          .join(' ');
    }
    return displayValue;
  }

  /// Normalize a list of categories (any format) and remove duplicates
  /// Returns sorted list in normalized format
  static List<String> normalizeList(List<dynamic>? categories) {
    if (categories == null || categories.isEmpty) {
      return [];
    }

    debugPrint('[CategoryNormalize] Before: $categories');

    final normalized = categories
        .cast<dynamic>()
        .map<String>((e) => e.toString().trim().toLowerCase())
        .where((e) => e.isNotEmpty)
        .toSet() // Remove duplicates
        .toList()
      ..sort(); // Sort for consistency

    debugPrint('[CategoryNormalize] After: $normalized');
    return normalized;
  }

  /// Convert a list of normalized categories to display format
  static List<String> displayList(List<String> normalizedCategories) {
    return normalizedCategories.map((cat) => display(cat)).toList();
  }

  /// Validate if a category is in the master list
  static bool isValid(String normalizedCategory) {
    return normalizedList.contains(normalizedCategory.trim().toLowerCase());
  }

  /// Get all invalid categories from a list
  static List<String> getInvalidCategories(List<String> categories) {
    return categories.where((cat) => !isValid(cat)).toList();
  }
}
