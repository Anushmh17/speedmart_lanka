import '../models/category_model.dart';
import '../models/user_model.dart';

/// Centralized category synchronization helper
/// Replaces hardcoded VendorCategories validation with dynamic repository lookups
class CategorySyncHelper {
  /// Normalizes a single category key: trim, lowercase, replace spaces with underscores
  static String normalizeCategoryKey(String value) {
    return value.trim().toLowerCase().replaceAll(' ', '_');
  }

  /// Sanitizes a list of category keys: normalize, remove duplicates, remove empty
  static List<String> sanitizeCategoryKeys(List<dynamic>? input) {
    if (input == null || input.isEmpty) return [];
    return input
        .cast<dynamic>()
        .map<String>((e) => normalizeCategoryKey(e.toString()))
        .where((e) => e.isNotEmpty)
        .toSet()
        .toList();
  }

  /// Resolves a normalized key to display name using active categories provider
  /// Returns "Unknown category" if not found
  static String resolveCategoryDisplayName(
    String normalizedKey,
    List<CategoryModel> allCategories,
  ) {
    try {
      final category = allCategories.firstWhere(
        (c) => c.normalizedKey == normalizedKey.toLowerCase(),
      );
      return category.name;
    } catch (_) {
      return 'Unknown category';
    }
  }

  /// Syncs vendor categories with category repository
  /// - Updates vendor.allowedCategories to only include active categories
  /// - Removes deleted categories
  /// - Updates display context (but keys stay same)
  static UserModel syncVendorCategoriesWithRepository(
    UserModel vendor,
    List<CategoryModel> allCategories,
  ) {
    final activeKeys = allCategories
        .where((c) => c.isActive)
        .map((c) => c.normalizedKey)
        .toSet();

    final sanitized = sanitizeCategoryKeys(vendor.allowedCategories);
    final synced = sanitized.where((key) => activeKeys.contains(key)).toList();

    if (sanitized.length != synced.length) {
      // Removed categories detected but not used - log if needed
    }

    return vendor.copyWith(allowedCategories: synced);
  }

  /// Get display names for a list of normalized keys
  static List<String> getDisplayNames(
    List<String> normalizedKeys,
    List<CategoryModel> allCategories,
  ) {
    return normalizedKeys
        .map((key) => resolveCategoryDisplayName(key, allCategories))
        .toList();
  }

  /// Filter categories for UI display
  /// - Excludes disabled categories from new selectors
  /// - Can show disabled as read-only with badge
  static List<CategoryModel> filterForSelector(
    List<CategoryModel> categories, {
    bool showDisabled = false,
  }) {
    if (showDisabled) return categories;
    return categories.where((c) => c.isActive).toList();
  }

  /// Check if normalized key exists in active categories
  static bool isKeyActive(
    String normalizedKey,
    List<CategoryModel> allCategories,
  ) {
    return allCategories.any(
      (c) => c.normalizedKey == normalizedKey && c.isActive,
    );
  }

  /// Get CategoryModel by normalized key
  static CategoryModel? getCategoryByKey(
    String normalizedKey,
    List<CategoryModel> allCategories,
  ) {
    try {
      return allCategories.firstWhere(
        (c) => c.normalizedKey == normalizedKey,
      );
    } catch (_) {
      return null;
    }
  }
}


