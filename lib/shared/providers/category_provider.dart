import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/category_model.dart';
import '../utils/category_constants.dart';

/// Provides the static category list for the mobile app (vendor/customer side).
/// Category management is handled by the admin web panel.
final activeCategoriesProvider = Provider<List<CategoryModel>>((ref) {
  return VendorCategories.displayNames.asMap().entries.map((entry) {
    final displayName = entry.value;
    final normalizedKey = VendorCategories.normalizedList[entry.key];
    return CategoryModel(
      id: normalizedKey,
      name: displayName,
      normalizedKey: normalizedKey,
      isActive: true,
      displayOrder: entry.key,
      createdAt: DateTime(2024),
    );
  }).toList();
});

