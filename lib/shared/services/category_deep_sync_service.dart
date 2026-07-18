import 'package:flutter/foundation.dart';
import '../models/category_model.dart';
import '../models/user_model.dart';

/// Deep category synchronization service
/// Ensures all vendor category references are valid and up-to-date with repository
class CategoryDeepSyncService {
  /// Syncs a single user's categories with repository
  /// Returns updated user if changes were made, null otherwise
  static UserModel? syncUserCategoriesWithRepository(
    UserModel user,
    List<CategoryModel> allCategories,
  ) {
    if (user.role.name != 'vendor') {
      return null;
    }

    final validKeys = allCategories.map((c) => c.normalizedKey).toSet();
    final activeKeys = allCategories
        .where((c) => c.isActive)
        .map((c) => c.normalizedKey)
        .toSet();

    bool hasChanges = false;
    List<String>? syncedAllowed;
    List<String>? syncedVendor;
    List<String>? syncedRequested;
    bool? syncedHasPending;

    if (user.allowedCategories != null) {
      final sanitized = _sanitizeAndNormalize(user.allowedCategories!);
      final filtered = sanitized.where((key) => validKeys.contains(key)).toList();
      if (filtered.length != (user.allowedCategories?.length ?? 0) ||
          _listsDiffer(filtered, user.allowedCategories)) {
        syncedAllowed = filtered;
        hasChanges = true;
      }
    }

    if (user.vendorCategories != null) {
      final sanitized = _sanitizeAndNormalize(user.vendorCategories!);
      final filtered = sanitized.where((key) => validKeys.contains(key)).toList();
      if (filtered.length != (user.vendorCategories?.length ?? 0) ||
          _listsDiffer(filtered, user.vendorCategories)) {
        syncedVendor = filtered;
        hasChanges = true;
      }
    }

    if (user.requestedCategories != null) {
      final sanitized = _sanitizeAndNormalize(user.requestedCategories!);
      final filtered = sanitized.where((key) => activeKeys.contains(key)).toList();
      if (filtered.length != (user.requestedCategories?.length ?? 0) ||
          _listsDiffer(filtered, user.requestedCategories)) {
        syncedRequested = filtered;
        hasChanges = true;

        if (syncedRequested != null) {
          final newHasPending = syncedRequested.isNotEmpty;
          if (newHasPending != (user.hasPendingCategoryRequest ?? false)) {
            syncedHasPending = newHasPending;
            hasChanges = true;
          }
        }
      }
    }

    if (!hasChanges) {
      return null;
    }

    return user.copyWith(
      allowedCategories: syncedAllowed ?? user.allowedCategories,
      vendorCategories: syncedVendor ?? user.vendorCategories,
      requestedCategories: syncedRequested ?? user.requestedCategories,
      hasPendingCategoryRequest: syncedHasPending ?? user.hasPendingCategoryRequest,
    );
  }

  static List<String> _sanitizeAndNormalize(List<dynamic>? input) {
    if (input == null || input.isEmpty) return [];
    return input
        .cast<dynamic>()
        .map<String>((e) {
          final str = e.toString().trim().toLowerCase().replaceAll(' ', '_');
          return str;
        })
        .where((e) => e.isNotEmpty)
        .toSet()
        .toList();
  }

  static bool _listsDiffer(List<String>? list1, List<String>? list2) {
    if (list1 == null || list2 == null) return list1 != list2;
    if (list1.length != list2.length) return true;
    final set1 = list1.toSet();
    final set2 = list2.toSet();
    return set1.containsAll(list2) == false || set2.containsAll(list1) == false;
  }

  static List<String> getValidDisplayNames(
    List<String>? normalizedKeys,
    List<CategoryModel> allCategories,
  ) {
    if (normalizedKeys == null || normalizedKeys.isEmpty) return [];
    
    return normalizedKeys
        .where((key) => allCategories.any((c) => c.normalizedKey == key))
        .map((key) {
          try {
            final cat =
                allCategories.firstWhere((c) => c.normalizedKey == key);
            return cat.name;
          } catch (_) {
            return null;
          }
        })
        .whereType<String>()
        .toList();
  }

  static List<String> filterToActiveKeys(
    List<String>? normalizedKeys,
    List<CategoryModel> allCategories,
  ) {
    if (normalizedKeys == null || normalizedKeys.isEmpty) return [];
    
    final activeKeys =
        allCategories.where((c) => c.isActive).map((c) => c.normalizedKey).toSet();
    return normalizedKeys.where((key) => activeKeys.contains(key)).toList();
  }

  static bool isKeyValidAndActive(
    String normalizedKey,
    List<CategoryModel> allCategories,
  ) {
    return allCategories.any(
      (c) => c.normalizedKey == normalizedKey && c.isActive,
    );
  }
}


