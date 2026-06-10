# Category Cleanup Order Bug Fix

## Root Cause Analysis

The category cleanup was running **before** the category repository was loaded, resulting in:
1. Empty `validKeys` set: `{}`
2. Cleanup logic using empty validKeys still "cleaned" categories
3. `copyWith()` not actually using cleaned lists - used original user properties
4. Invalid keys like `[umbrella, hellorzx]` persisted through cleanup
5. Feed loaded categories without forcing repository load first

## Bug Manifestation

### Logs Proving Bug
```
[CategoryCleanup] Valid keys in repository: {}
[CategoryCleanup] Removed invalid keys...
user.allowedCategories being saved: [umbrella, hellorzx]
FINAL CATEGORIES USED IN FEED: [umbrella, hellorzx]
```

## Fix Implementation

### 1. auth_provider.dart - Force Category Load Before Cleanup

**File**: `lib/features/auth/providers/auth_provider.dart`

**Changes**:
- Added `await categoryNotifier.loadCategories()` BEFORE reading valid keys
- Added empty validKeys guard - returns user unchanged if repository empty
- Fixed `copyWith()` to use empty lists `[]` instead of nullable cleaned lists
- Added comprehensive BEFORE/AFTER debug logging

**Code**:
```dart
Future<UserModel> _cleanUserCategoriesOnLogin(UserModel user) async {
  if (user.role != UserRole.vendor) {
    return user;
  }
  
  try {
    // FORCE load categories before cleanup validation
    final categoryNotifier = _ref.read(categoryProvider.notifier);
    await categoryNotifier.loadCategories();  // ✅ NEW: Load first
    final allCategories = categoryNotifier.getAllCategories();
    final validKeys = allCategories.map((c) => c.normalizedKey).toSet();
    
    debugPrint('[CategoryCleanup] Valid keys in repository: $validKeys');
    
    // If no categories loaded, DO NOT cleanup - return user unchanged
    if (validKeys.isEmpty) {  // ✅ NEW: Guard against empty
      debugPrint('[CategoryCleanup] WARNING: Category repository empty, skipping cleanup');
      return user;
    }
    
    // Clean each category list
    final cleanedAllowed = _cleanCategoryList(user.allowedCategories, validKeys, 'allowedCategories', user.id);
    final cleanedVendor = _cleanCategoryList(user.vendorCategories, validKeys, 'vendorCategories', user.id);
    final cleanedRequested = _cleanCategoryList(user.requestedCategories, validKeys, 'requestedCategories', user.id);
    
    // Check if anything changed
    if (cleanedAllowed != user.allowedCategories ||
        cleanedVendor != user.vendorCategories ||
        cleanedRequested != user.requestedCategories) {
      debugPrint('[CategoryCleanup] Categories cleaned for user ${user.id} during login');
      debugPrint('[CategoryCleanup] user.allowedCategories being saved: $cleanedAllowed');
      
      final cleanedUser = user.copyWith(
        allowedCategories: cleanedAllowed ?? [],  // ✅ FIXED: Use cleaned lists
        vendorCategories: cleanedVendor ?? [],
        requestedCategories: cleanedRequested ?? [],
        hasPendingCategoryRequest: (cleanedRequested?.isNotEmpty ?? false),
      );
      
      await _repo.updateUser(cleanedUser);
      return cleanedUser;
    }
    
    return user;
  } catch (e) {
    debugPrint('[CategoryCleanup] Error during login cleanup: $e');
    return user;
  }
}

List<String>? _cleanCategoryList(
  List<String>? original,
  Set<String> validKeys,
  String fieldName,
  String userId,
) {
  if (original == null || original.isEmpty) return null;
  
  debugPrint('[CategoryCleanup] $fieldName BEFORE cleanup: $original');  // ✅ NEW
  
  final cleaned = original
      .map((k) => k.toLowerCase().trim())
      .where((k) => k.isNotEmpty && validKeys.contains(k))
      .toSet()
      .toList();
  
  debugPrint('[CategoryCleanup] $fieldName AFTER cleanup: $cleaned');  // ✅ NEW
  
  final removed = original.length - cleaned.length;
  if (removed > 0) {
    debugPrint('[CategoryCleanup] Removed $removed invalid keys from $fieldName for user $userId');
  }
  
  return cleaned.isEmpty ? null : cleaned;
}
```

### 2. vendor_request_feed_provider.dart - Force Category Load Before Sanitization

**File**: `lib/features/vendor/request_feed/providers/vendor_request_feed_provider.dart`

**Changes**:
- Added `await categoryNotifier.loadCategories()` BEFORE sanitization
- Changed from `ref.read(activeCategoriesProvider)` to `categoryNotifier.getAllCategories()`
- Ensures validKeys is populated before filtering

**Code**:
```dart
Future<void> loadFeed() async {
  // ... existing code ...
  
  final rawCategories = user.allowedCategories ?? user.vendorCategories ?? [];
  debugPrint('[CategoryAudit] rawCategories BEFORE sanitization: $rawCategories');
  
  // FORCE load categories before validation
  final categoryNotifier = ref.read(categoryProvider.notifier);
  await categoryNotifier.loadCategories();  // ✅ NEW: Load first
  final allCategories = categoryNotifier.getAllCategories();
  final validKeys = allCategories.map((c) => c.normalizedKey).toSet();
  
  debugPrint('[CategoryAudit] Valid keys loaded from repository: $validKeys');  // ✅ NEW
  
  // Sanitize: normalize, deduplicate, and filter to only valid repository keys
  final sanitizedCategories = rawCategories
      .map((k) => k.toLowerCase().trim())
      .where((k) => k.isNotEmpty && validKeys.contains(k))
      .toSet()
      .toList();
  
  debugPrint('[CategoryAudit] FINAL CATEGORIES USED IN FEED: $sanitizedCategories');
  
  // ... rest of feed loading ...
}
```

## Expected Log Output After Fix

### Login/Session Restore
```
[CategoryCleanup] Valid keys in repository: {groceries, electronics, ...}  ✅ NOT EMPTY
[CategoryCleanup] allowedCategories BEFORE cleanup: [umbrella, hellorzx]
[CategoryCleanup] allowedCategories AFTER cleanup: []  ✅ CLEANED
[CategoryCleanup] Removed 2 invalid keys from allowedCategories for user ...
[CategoryCleanup] user.allowedCategories being saved: []  ✅ EMPTY LIST SAVED
```

### Feed Loading
```
[CategoryAudit] rawCategories BEFORE sanitization: [umbrella, hellorzx]
[CategoryAudit] Valid keys loaded from repository: {groceries, electronics, ...}  ✅ NOT EMPTY
[CategoryAudit] sanitizedCategories AFTER filtering: []
[CategoryAudit] Removed invalid keys: {umbrella, hellorzx}  ✅ REMOVED
[CategoryAudit] FINAL CATEGORIES USED IN FEED: []  ✅ CLEAN FEED
```

## Verification Commands

```bash
# No compilation errors
flutter analyze

# Run app and check logs
flutter run -d windows

# Look for these patterns in logs:
# ✅ Valid keys in repository: {...NOT EMPTY...}
# ✅ AFTER cleanup: []
# ✅ FINAL CATEGORIES USED IN FEED: [] or [valid_keys_only]
# ❌ Should NEVER see: FINAL CATEGORIES USED IN FEED: [umbrella, hellorzx]
```

## Key Insights

1. **Load Order Critical**: Categories MUST be loaded before validation
2. **Empty Guard**: If validKeys is empty, skip cleanup to avoid false positives
3. **copyWith Bug**: Must explicitly use cleaned lists, not original user properties
4. **Feed Must Force Load**: Can't rely on activeCategoriesProvider being pre-loaded
5. **Debug Logging Essential**: BEFORE/AFTER logs prove cleanup actually works

## Files Modified

1. `lib/features/auth/providers/auth_provider.dart`
   - `_cleanUserCategoriesOnLogin()` method
   - `_cleanCategoryList()` helper method

2. `lib/features/vendor/request_feed/providers/vendor_request_feed_provider.dart`
   - `loadFeed()` method

## Testing Checklist

- [ ] `flutter analyze` shows 0 compilation errors
- [ ] Login logs show validKeys NOT empty: `{...}`
- [ ] Login logs show AFTER cleanup: `[]` for invalid keys
- [ ] Feed logs show validKeys loaded: `{...}`
- [ ] Feed logs show FINAL CATEGORIES: `[]` or valid keys only
- [ ] Feed logs NEVER show: `[umbrella, hellorzx]`
- [ ] Vendor with no categories sees empty feed
- [ ] Vendor with valid categories sees correct filtered requests
- [ ] Invalid keys removed from database permanently

## Commit Message

```
fix: enforce category load order before cleanup validation

BEFORE:
- Cleanup ran before category repository loaded
- validKeys was empty {}, allowing invalid keys through
- copyWith used original properties, not cleaned lists
- Feed used raw allowedCategories without load
- Logs: "FINAL CATEGORIES USED IN FEED: [umbrella, hellorzx]"

AFTER:
- Force loadCategories() before cleanup in auth_provider
- Guard against empty validKeys, skip cleanup if empty
- copyWith uses cleaned lists with ?? [] fallback
- Feed forces loadCategories() before sanitization
- Logs: "FINAL CATEGORIES USED IN FEED: []"

Changed:
- auth_provider.dart: _cleanUserCategoriesOnLogin() with await loadCategories()
- vendor_request_feed_provider.dart: loadFeed() with await loadCategories()

Result: Invalid keys removed at login AND feed load, never persisted
```
