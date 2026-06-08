# Category Provider Fix - Admin-Created Categories Not Displaying

## Problem Summary
When admin creates 15 categories (10 defaults + 5 custom), but vendor profile's Request Categories selector only shows 2 categories (stationery, other) instead of all 15 active categories.

## Root Cause Identified
The issue was in `lib/shared/models/user_model.dart` - the `fromJson()` factory method was using `VendorCategories.normalizeList()` to normalize category lists loaded from storage:

```dart
// BEFORE (BROKEN):
allowedCategories: VendorCategories.normalizeList(json['allowed_categories']),
requestedCategories: VendorCategories.normalizeList(json['requested_categories']),
vendorCategories: VendorCategories.normalizeList(json['vendor_categories']),
```

The problem: `VendorCategories.normalizeList()` calls methods that reference hardcoded category lists:
- `VendorCategories.normalizedList` (only 10 hardcoded categories)
- `VendorCategories.normalizationMap` (only 10 hardcoded categories)

When 5 admin-created categories (e.g., "Books", "Sports", "Toys", "Beauty", "Pet Supplies") were stored with normalized keys like `books`, `sports`, `toys`, `beauty`, `pet_supplies`, the `normalizeList()` method would:
1. Convert to lowercase ✓ (correct)
2. But these custom categories are NOT in the hardcoded `normalizedList`, so they were NOT being preserved correctly

Additionally, when comparing `approvedNormalized.contains(cat.normalizedKey)` in the profile screen:
- Provider returns admin categories with `normalizedKey` from database (e.g., "books", "sports")
- User's `allowedCategories` was processed through hardcoded lists
- **Mismatch!** Admin categories don't match because they're not in the hardcoded mapping

## Data Flow Problem

```
Admin creates 15 categories (10 default + 5 custom)
    ↓
Stored in admin_categories collection with normalizedKey
    ↓
Admin assigns categories to vendor: ["groceries", "home_appliances", "books", "sports", "toys"]
    ↓
Vendor data stored to user collection in storage
    ↓
User data loaded via UserModel.fromJson()
    ↓
VendorCategories.normalizeList() applied (FILTERS through hardcoded lists)
    ↓
Custom categories lost! Only ["groceries", "home_appliances"] remain
    ↓
Profile screen compares with provider (which has all 15)
    ↓
NO MATCH for custom categories → they appear in requestable list even though they're approved
```

## Solution Applied
Removed the call to `VendorCategories.normalizeList()` and replaced with direct normalization:

```dart
// AFTER (FIXED):
vendorCategories: (json['vendor_categories'] as List<dynamic>?)
    ?.cast<String>()
    .map((c) => c.toLowerCase().trim())
    .where((c) => c.isNotEmpty)
    .toList(),
allowedCategories: (json['allowed_categories'] as List<dynamic>?)
    ?.cast<String>()
    .map((c) => c.toLowerCase().trim())
    .where((c) => c.isNotEmpty)
    .toList(),
requestedCategories: (json['requested_categories'] as List<dynamic>?)
    ?.cast<String>()
    .map((c) => c.toLowerCase().trim())
    .where((c) => c.isNotEmpty)
    .toList(),
```

This approach:
- ✓ Converts any category to lowercase (matches admin normalized keys)
- ✓ Trims whitespace
- ✓ Removes empty entries
- ✓ Does NOT filter through hardcoded lists
- ✓ Preserves ALL admin-created custom categories

## Files Modified
- `lib/shared/models/user_model.dart` - UserModel.fromJson() - removed VendorCategories.normalizeList() calls

## Debug Logs Added to Profile Screen
Added comprehensive logs to `lib/shared/presentation/screens/profile_screen.dart` Consumer widget:

```
[ProfileCategoryFix] ===== REQUEST CATEGORIES BUILD START =====
[ProfileCategoryFix] provider count: 15
[ProfileCategoryFix] provider categories: [list of display names]
[ProfileCategoryFix] provider normalized keys: [normalized_key list]
[ProfileCategoryFix] approved normalized: [user.allowedCategories set]
[ProfileCategoryFix] Filter check: category(normalized) -> included=true/false
[ProfileCategoryFix] requestable categories: [final list]
[ProfileCategoryFix] rendered chip count: X
[ProfileCategoryFix] ===== REQUEST CATEGORIES BUILD END =====
```

## Verification
1. Admin creates 5 new categories: Books, Sports, Toys, Beauty, Pet Supplies
2. Admin approves 3 of them for vendor (Books, Sports, Beauty)
3. Vendor opens profile → Request Categories should show: Toys, Pet Supplies (not approved yet)
4. Profile screen logs should show:
   - provider count: 15 (10 default + 5 custom)
   - requestable categories: 12 (15 total - 3 approved)

## Related Files (No Changes Needed)
- `lib/features/admin/providers/category_provider.dart` - Already correct
- `lib/features/admin/data/mock_category_repository.dart` - Already correct
- `lib/shared/presentation/screens/profile_screen.dart` - Now correctly receives all admin categories
- All consumer widgets using `activeCategoriesProvider` - Already correct
