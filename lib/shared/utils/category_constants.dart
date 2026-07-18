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
    'Stationery',
    'Other',
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
    'stationery',
    'other',
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
    'stationery': 'Stationery',
    'other': 'Other',
  };

  /// Alias mapping for legacy/alternate category names
  /// Maps old names to normalized keys
  static const Map<String, String> aliasMap = {
    // Legacy typo mappings
    'foodss': 'groceries',  // Double-s typo variant
    'foods': 'groceries',   // Single food variant
    'food': 'groceries',    // Singular food variant
    
    // Underscore variants (match to space versions)
    'vehicle_parts': 'vehicle parts',
    'home_appliances': 'home appliances',
    
    // Hardware aliases
    'hardware items': 'hardware',
    'hardware item': 'hardware',
    
    // Vehicle parts aliases
    'vehicle part': 'vehicle parts',
    'automotive': 'vehicle parts',
    'auto parts': 'vehicle parts',
    
    // Home appliances aliases
    'home appliance': 'home appliances',
    'appliances': 'home appliances',
    'appliance': 'home appliances',
    
    // Stationery aliases (common misspelling)
    'stationary': 'stationery',
    
    // Umbrella alias
    'umbrella': 'other',
    'umbrellas': 'other',
    
    // Roof alias
    'roof': 'hardware',
    'roofing': 'hardware',
    
    // Baby products alias
    'baby products': 'other',
    'baby product': 'other',
    'babies': 'other',
    'infant': 'other',
    'infant products': 'other',
  };

  /// Convert display format to normalized format
  /// Example: 'Home Appliances' -> 'home appliances'
  /// Also handles aliases: 'Hardware items' -> 'hardware'
  static String normalize(String displayValue) {
    final trimmed = displayValue.trim();
    if (trimmed.isEmpty) {
      debugPrint('[CategoryNormalize] WARNING: Empty category value');
      return '';
    }

    final lowercase = trimmed.toLowerCase();
    
    // Check if it's already a valid normalized category
    if (normalizedList.contains(lowercase)) {
      debugPrint('[CategoryNormalize] Normalized successfully: "$lowercase"');
      return lowercase;
    }
    
    // Check alias map for legacy names
    if (aliasMap.containsKey(lowercase)) {
      final normalized = aliasMap[lowercase]!;
      debugPrint('[CategoryNormalize] Alias matched: "$displayValue" -> "$normalized"');
      debugPrint('[CategoryNormalize] Normalized successfully: "$normalized"');
      return normalized;
    }
    
    // Check if it matches a display name (title case)
    if (normalizationMap.containsValue(trimmed)) {
      // Find the key for this display value
      final normalized = normalizationMap.entries
          .firstWhere(
            (entry) => entry.value == trimmed,
            orElse: () => MapEntry(lowercase, ''),
          )
          .key;
      if (normalized.isNotEmpty) {
        debugPrint('[CategoryNormalize] Normalized successfully: "$normalized"');
        return normalized;
      }
    }
    
    // Not found in master list or aliases
    debugPrint('[CategoryNormalize] WARNING: "$displayValue" not found in normalization map');
    return lowercase; // Return lowercase as fallback
  }

  /// Convert normalized format to display format
  /// Example: 'home appliances' -> 'Home Appliances'
  static String display(String normalizedValue) {
    final trimmed = normalizedValue.trim().toLowerCase();
    final displayValue = normalizationMap[trimmed];
    if (displayValue == null) {
      // Fallback: title case if not in map
      return normalizedValue
          .split(' ')
          .map((word) => word.isEmpty ? '' : word[0].toUpperCase() + word.substring(1))
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

