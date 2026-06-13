# Category "foodss" Investigation Report

## Problem Statement
WARNING logs showing:
```
WARNING: "foodss" not found in normalization map
```

## Investigation Results

### 1. Code Analysis
- **Searched ALL .dart files**: NO occurrences of "foodss" found in codebase
- **Mock auth repository** (lib/features/auth/data/mock_auth_repository.dart):
  - Seed vendor categories: `['groceries', 'home appliances']`, `['electronics', 'stationery']`, `['pharmacy']`
  - NO "foodss" in seed data
- **Category repository** (lib/features/admin/data/mock_category_repository.dart):
  - Default categories: groceries, electronics, hardware, furniture, pharmacy, clothing, vehicle_parts, home_appliances, stationery, other
  - NO "foodss" in default categories
- **Category constants** (lib/shared/utils/category_constants.dart):
  - VendorCategories.normalizedList: 10 categories (groceries, electronics, hardware, etc.)
  - VendorCategories.aliasMap: vehicle_parts, home_appliances aliases
  - NO "foodss" alias or mapping

### 2. Root Cause Determination
**"foodss" exists ONLY in device storage (SharedPreferences), NOT in code.**

#### Source Location:
The typo is stored in one of these SharedPreferences keys:
- `registered_users` (vendor profile with vendorCategories containing "foodss")
- `admin_categories` (if manually created via admin UI with typo)

#### How it got there:
1. **Manual vendor registration** with typo in category selection (unlikely - UI uses chipset from category provider)
2. **Manual category creation** by admin with typo: "foodss" instead of "groceries"
3. **Legacy/test data** from earlier development sessions persisted in storage

### 3. Category Type Analysis

#### Is "foodss" a typo of "foods"?
- "foods" is NOT a valid category in the system
- Standard food category is **"groceries"**
- "foodss" appears to be double-typo: foods → foodss

#### Should it map to "groceries"?
- **YES**. "foodss" is clearly meant to be food-related items
- "groceries" is the correct canonical category for food products
- VendorCategories.normalizedList includes "groceries" at index 0

#### Should it be removed entirely?
- **NO**. Should be migrated to "groceries" to preserve vendor intent
- Removing would cause category mismatch for affected vendors

## Recommended Fix

### Option 1: Add Alias Mapping (RECOMMENDED)
Add alias in `lib/shared/utils/category_constants.dart`:

```dart
static const Map<String, String> aliasMap = {
  'foodss': 'groceries',  // Legacy typo mapping
  'foods': 'groceries',   // Also handle single-s variant
  // ... existing aliases
};
```

**Benefits:**
- Silences WARNING without data loss
- Auto-corrects typo for all affected vendors
- Preserves vendor category intent
- Handles both "foodss" and "foods" variants

### Option 2: Database Migration Script
Create one-time migration to replace "foodss" → "groceries" in storage:

```dart
// In StorageService or migration utility
Future<void> migrateObsoleteCategories() async {
  final users = await getRegisteredUsers();
  bool needsUpdate = false;
  
  for (final user in users) {
    if (user['vendor_categories']?.contains('foodss') ?? false) {
      user['vendor_categories'] = (user['vendor_categories'] as List)
          .map((c) => c == 'foodss' ? 'groceries' : c)
          .toList();
      needsUpdate = true;
    }
  }
  
  if (needsUpdate) await saveRegisteredUsers(users);
}
```

**Benefits:**
- Cleans storage permanently
- No ongoing alias maintenance
- One-time fix

**Drawbacks:**
- Requires app restart to take effect
- Doesn't prevent future typos

### Option 3: Clear Storage (DESTRUCTIVE)
Delete all app data from device:
- Android: Settings → Apps → Speedmart Lanka → Clear Data
- iOS: Delete and reinstall app

**NOT RECOMMENDED** - loses all test data, user accounts, requests, proposals

## Recommended Action Plan

**Implement Option 1 (Alias Mapping):**

1. **Add aliases** to category_constants.dart (lines 51-52 area)
2. **Test normalization**:
   ```dart
   VendorCategories.normalize('foodss') // Returns 'groceries'
   VendorCategories.normalize('foods')  // Returns 'groceries'
   ```
3. **Verify** WARNING disappears in logs
4. **No app restart needed** - alias takes effect immediately

## Files Involved

### To Modify:
- `lib/shared/utils/category_constants.dart` (add foodss/foods → groceries aliases)

### No Changes Needed:
- `lib/features/auth/data/mock_auth_repository.dart` (seed data is clean)
- `lib/features/admin/data/mock_category_repository.dart` (defaults are clean)
- Storage files (alias handles existing data transparently)

## Verification Steps

1. Add aliases to category_constants.dart
2. Run `flutter analyze` (should show 190 issues, 0 errors)
3. Hot restart app
4. Check logs for "foodss" WARNING (should be GONE)
5. Verify vendor with "foodss" category can:
   - View profile (categories display as "Groceries")
   - Receive filtered requests (matches grocery requests)
   - Submit proposals (category matches correctly)

## Conclusion

**Root Cause:** Typo "foodss" exists in device SharedPreferences storage, likely from manual admin category creation or corrupted test data.

**Solution:** Add alias mapping `'foodss': 'groceries'` to handle legacy typo without data loss.

**Impact:** Zero code changes to business logic, instant fix via alias, prevents future WARNING logs.
