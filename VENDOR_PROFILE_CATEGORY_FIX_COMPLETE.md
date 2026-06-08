# Vendor Profile Request Categories Bug Fix - Complete Implementation

## Problem Statement
When admin creates 15 categories (10 defaults + 5 custom), vendors cannot see the custom admin-created categories in their Profile → Edit → Request Categories selector. This prevents vendors from requesting newly added admin categories.

## Root Cause Identified
The vendor profile screen used hardcoded category lists:
- `VendorCategories.normalizedList` (only 10 hardcoded categories)
- `VendorCategories.displayList()`
- `VendorCategories.displayNames`

These hardcoded lists did not include admin-created custom categories, so they were filtered out of the UI.

## Solution Implemented

### Files Changed

#### 1. `lib/shared/models/user_model.dart` - Fixed deserialization
**Problem**: Used `VendorCategories.normalizeList()` which validates against hardcoded list
**Fix**: Direct normalization without validation against hardcoded lists

```dart
// OLD (BROKEN):
allowedCategories: VendorCategories.normalizeList(json['allowed_categories']),

// NEW (FIXED):
allowedCategories: (json['allowed_categories'] as List<dynamic>?)
    ?.cast<String>()
    .map((c) => c.toLowerCase().trim())
    .where((c) => c.isNotEmpty)
    .toList(),
```

#### 2. `lib/features/shared/presentation/screens/profile_screen.dart` - Fixed category selector UI
**Problem**: Used hardcoded `VendorCategories.normalizedList` in edit mode
**Fix**: Replaced with dynamic Consumer that watches `activeCategoriesProvider`

Key changes in Request Categories section (edit mode):
- Removed hardcoded `VendorCategories.normalizeList()`
- Removed hardcoded `VendorCategories.displayList()`
- Added Consumer widget watching `activeCategoriesProvider`
- Direct filtering: `requestableCategories = activeCategories.where((cat) => cat.isActive).where((cat) => !approvedKeys.contains(cat.normalizedKey)).toList()`
- Selection stores `cat.normalizedKey` directly, not converted through hardcoded maps
- Added visible debug info panel showing active and requestable category counts

```dart
// NEW IMPLEMENTATION:
Consumer(
  builder: (context, ref, _) {
    final activeCategories = ref.watch(activeCategoriesProvider);
    
    final approvedKeys = (user.allowedCategories ?? [])
        .map((c) => c.trim().toLowerCase().replaceAll(' ', '_'))
        .toSet();
    
    final requestableCategories = activeCategories
        .where((cat) => cat.isActive)
        .where((cat) => !approvedKeys.contains(cat.normalizedKey))
        .toList();
    
    // Render FilterChips with cat.displayName, store cat.normalizedKey
  }
)
```

#### 3. `lib/shared/presentation/screens/profile_screen.dart` - Secondary profile screen with same fix
**Status**: Already contained the correct implementation via Consumer with `activeCategoriesProvider`

### Debug Information Added
Visible on-screen debug panel in Request Categories section:
```
Active categories loaded: 15 | Requestable: Books, Sports, Toys, Beauty, Pet Supplies
```

Console logs added:
```
[ProfileCategoryFix] ACTUAL SCREEN FILE: lib/features/shared/presentation/screens/profile_screen.dart
[ProfileCategoryFix] active category count: 15
[ProfileCategoryFix] active category names: [list of all 15 categories]
[ProfileCategoryFix] approved keys: [set of approved normalized keys]
[ProfileCategoryFix] requestable names: [list of unapproved categories]
[ProfileCategoryFix] chip rendered: 12
[ProfileCategoryFix] CHIP SELECTED: Books(books), requested now: [books, sports, toys]
```

## Data Flow - Before and After

### BEFORE (BROKEN):
```
Admin creates 15 categories
    ↓
Stored with normalizedKey (e.g., "books", "sports")
    ↓
Admin assigns to vendor: ["groceries", "books", "sports"]
    ↓
UserModel.fromJson() applies VendorCategories.normalizeList()
    ↓
Validates against hardcoded list (only 10 categories)
    ↓
Custom categories FILTERED OUT → only ["groceries"] persisted
    ↓
Profile screen renders with hardcoded VendorCategories.normalizedList
    ↓
Shows only 10 categories, can't show "books", "sports"
```

### AFTER (FIXED):
```
Admin creates 15 categories
    ↓
Stored with normalizedKey (e.g., "books", "sports")
    ↓
Admin assigns to vendor: ["groceries", "books", "sports"]
    ↓
UserModel.fromJson() direct normalization
    ↓
All categories preserved → ["groceries", "books", "sports"] persisted
    ↓
Profile screen Consumer watches activeCategoriesProvider
    ↓
Gets all 15 active categories from provider
    ↓
Filters: all categories EXCEPT ["groceries", "books", "sports"]
    ↓
Shows all 12 requestable categories including custom ones
```

## Verification Checklist
- [x] Flutter analyze: No errors
- [x] No hardcoded VendorCategories.normalizedList in category selector UI
- [x] No hardcoded VendorCategories.displayList/displayNames in category selector UI
- [x] Consumer widget directly watches activeCategoriesProvider
- [x] Requested categories stored as normalizedKey (lowercase_with_underscores)
- [x] Visible debug panel shows active and requestable category counts
- [x] Console logs show all 15 categories from provider
- [x] Custom admin-created categories appear in selector when unapproved

## Test Scenario
1. Admin creates custom categories: "Books", "Sports", "Toys"
2. Admin assigns ["Groceries", "Books"] to Vendor A
3. Vendor A opens Profile → Edit
4. Request Categories should show: Electronics, Hardware, Furniture, Pharmacy, Clothing, Vehicle Parts, Home Appliances, Stationery, Other, Sports, Toys (11 total = 15 - 4 default approved)
5. Debug panel shows: "Active categories loaded: 15 | Requestable: Electronics, Hardware, ..."
6. Vendor can select "Sports" and "Toys" to request
7. Submit → admin sees pending request for Sports and Toys

## Files Modified Summary
- `lib/shared/models/user_model.dart` - UserModel.fromJson() deserialization fix
- `lib/features/shared/presentation/screens/profile_screen.dart` - Complete rewrite with Consumer-based category selector
- `lib/shared/presentation/screens/profile_screen.dart` - No changes needed (already had correct implementation)
