# Category Persistence Audit Report

## Overview
This audit traces category data through the entire persistence flow from Admin UI to Vendor Feed.

## Expected Behavior
When Admin changes vendor categories from `[Groceries]` to `[Electronics]`:
- **EXPECTED**: Vendor should end with `[Electronics]` (REPLACE)
- **NOT EXPECTED**: Vendor should end with `[Groceries, Electronics]` (APPEND)

---

## Audit Points with Logging

### 1. Admin Category Selection Widget
**File**: `lib/features/admin/presentation/screens/admin_vendor_assignment_screen.dart`
**Method**: `_saveAssignment()`

**Logs Added**:
```dart
debugPrint('[CategoryAudit] ===== ADMIN SAVE START =====');
debugPrint('[CategoryAudit] Categories selected in UI: $_selectedCategories');
debugPrint('[CategoryAudit] Submitted categories: ${widget.vendor.vendorCategories}');
debugPrint('[CategoryAudit] Categories before save: $_selectedCategories');
debugPrint('[CategoryAudit] Vendor current allowedCategories: ${widget.vendor.allowedCategories}');
```

**What to verify**:
- `_selectedCategories` should contain ONLY the newly selected categories
- No mixing with old categories

---

### 2. _saveAssignment() → updateVendorShopAssignment()
**File**: `lib/features/admin/presentation/screens/admin_vendor_assignment_screen.dart`
**Method**: `_saveAssignment()`

**Logs Added**:
```dart
debugPrint('[CategoryAudit] Saving allowedCategories: $_selectedCategories');
await authNotifier.updateVendorShopAssignment(
  vendorId: widget.vendor.id,
  allowedCategories: _selectedCategories, // <- Passed here
);
debugPrint('[CategoryAudit] ===== ADMIN SAVE COMPLETE =====');
debugPrint('[CategoryAudit] Saved vendor allowedCategories: $_selectedCategories');
```

**What to verify**:
- Categories passed to `updateVendorShopAssignment()` match UI selection
- No appending happening here

---

### 3. AuthProvider.updateVendorShopAssignment()
**File**: `lib/features/auth/providers/auth_provider.dart`
**Method**: `updateVendorShopAssignment()`

**Logs Added**:
```dart
debugPrint('[CategoryAudit] ===== AUTH PROVIDER UPDATE START =====');
debugPrint('[CategoryAudit] vendorId=$vendorId');
debugPrint('[CategoryAudit] allowedCategories input: $allowedCategories');

// Get the vendor from repository
final vendor = await _repo.getUserById(vendorId);
debugPrint('[CategoryAudit] Before copyWith: vendor.allowedCategories=${vendor.allowedCategories}');

final updatedVendor = vendor.copyWith(
  allowedCategories: allowedCategories, // <- CRITICAL: Does this REPLACE or APPEND?
);

debugPrint('[CategoryAudit] After copyWith: updatedVendor.allowedCategories=${updatedVendor.allowedCategories}');
await _repo.updateUser(updatedVendor);

final userJson = updatedVendor.toJson();
debugPrint('[CategoryAudit] User JSON toJson: allowed_categories=${userJson['allowed_categories']}');
await StorageService.saveUser(userJson);

debugPrint('[CategoryAudit] ===== PERSISTED TO STORAGE =====');
```

**What to verify**:
- `vendor.copyWith(allowedCategories: newList)` should REPLACE, not append
- Check `UserModel.copyWith()` implementation in `user_model.dart`

**ROOT CAUSE SUSPECTED HERE**: Check if `copyWith` correctly replaces the list

---

### 4. Repository.updateUser()
**File**: `lib/features/auth/data/mock_auth_repository.dart`
**Method**: `updateUser()`

**Logs Added**:
```dart
debugPrint('[CategoryAudit] ===== REPOSITORY UPDATE START =====');
debugPrint('[CategoryAudit] updateUser called for userId: ${user.id}');
debugPrint('[CategoryAudit] user.allowedCategories being saved: ${user.allowedCategories}');
debugPrint('[CategoryAudit] user.vendorCategories: ${user.vendorCategories}');

final index = _sessionUsers.indexWhere((u) => u.id == user.id);
if (index != -1) {
  debugPrint('[CategoryAudit] BEFORE update in _sessionUsers[${index}].allowedCategories: ${_sessionUsers[index].allowedCategories}');
  _sessionUsers[index] = user;
  debugPrint('[CategoryAudit] AFTER update in _sessionUsers[${index}].allowedCategories: ${_sessionUsers[index].allowedCategories}');
}

await _persistUsers();
debugPrint('[CategoryAudit] ===== REPOSITORY UPDATE COMPLETE =====');
```

**What to verify**:
- User object in `_sessionUsers` gets fully replaced
- Categories correctly stored in memory

---

### 5. StorageService.saveUser()
**File**: `lib/core/storage/storage_service.dart`
**Method**: `saveUser()`

**Logs Added**:
```dart
debugPrint('[CategoryAudit] ===== STORAGE SERVICE SAVE START =====');
debugPrint('[CategoryAudit] saveUser called with allowed_categories: ${userJson['allowed_categories']}');
debugPrint('[CategoryAudit] Full userJson keys: ${userJson.keys.toList()}');
debugPrint('[CategoryAudit] Serializing to secure storage...');

await _secure.write(
  key: AppConstants.userKey,
  value: jsonEncode(userJson),
);

debugPrint('[CategoryAudit] ===== STORAGE SERVICE SAVE COMPLETE =====');
```

**What to verify**:
- JSON serialization preserves the category list correctly
- No mutation during serialization

---

### 6. Vendor Login Restore
**File**: `lib/features/auth/providers/auth_provider.dart`
**Method**: `_restoreSession()`

**Logs Added**:
```dart
debugPrint('[CategoryAudit] ===== VENDOR LOGIN RESTORE =====');
debugPrint('[CategoryAudit] Restoring session from storage');
debugPrint('[CategoryAudit] userJson allowed_categories: ${userJson['allowed_categories']}');
debugPrint('[CategoryAudit] userJson vendor_categories: ${userJson['vendor_categories']}');

final user = UserModel.fromJson(userJson);

debugPrint('[CategoryAudit] UserModel.fromJson result:');
debugPrint('[CategoryAudit] user.allowedCategories: ${user.allowedCategories}');
debugPrint('[CategoryAudit] user.vendorCategories: ${user.vendorCategories}');
debugPrint('[CategoryAudit] ===== SESSION RESTORED =====');
```

**What to verify**:
- Categories loaded from storage match what was saved
- No mixing of `allowedCategories` and `vendorCategories`

---

### 7. Vendor Request Feed
**File**: `lib/features/vendor/request_feed/providers/vendor_request_feed_provider.dart`
**Method**: `loadFeed()`

**Logs Already Present**:
```dart
debugPrint('[FeedAudit] ===== VENDOR FEED LOAD START =====');
debugPrint('[CategoryAudit] ===== CATEGORY AUDIT =====');
debugPrint('[CategoryAudit] vendor.allowedCategories (admin-approved): ${user.allowedCategories}');
debugPrint('[CategoryAudit] vendor.vendorCategories (vendor-submitted): ${user.vendorCategories}');
debugPrint('[CategoryAudit] FINAL CATEGORIES USED IN FEED: $allowedCategories');
debugPrint('[CategoryAudit] SOURCE OF TRUTH for feed: $allowedCategories');
```

**What to verify**:
- Feed uses `allowedCategories` (SOURCE OF TRUTH), not `vendorCategories`
- Categories match admin's last save

---

## Testing Instructions

### Step 1: Clear existing state
1. Logout all users
2. Restart the app

### Step 2: Admin assigns initial categories
1. Login as Admin (`admin@speedmart.lk` / `admin123`)
2. Navigate to Vendor Management
3. Select a vendor (e.g., "Kamal Silva")
4. Assign categories: `[Groceries]`
5. Save

### Step 3: Verify initial state
1. Logout Admin
2. Login as Vendor (`vendor@test.com` / `vendor123`)
3. Check request feed
4. **Expected**: Only see requests matching `[Groceries]`

### Step 4: Admin changes categories
1. Logout Vendor
2. Login as Admin
3. Go back to same vendor
4. **Change** categories to: `[Electronics]` (uncheck Groceries, check Electronics)
5. Save

### Step 5: Verify category replacement
1. Logout Admin
2. Login as Vendor again
3. Check request feed
4. **Expected**: Only see requests matching `[Electronics]`
5. **NOT Expected**: See requests from both `[Groceries, Electronics]`

---

## Log Trace Example

### Expected Output (REPLACE behavior):

```
[CategoryAudit] ===== ADMIN SAVE START =====
[CategoryAudit] Categories selected in UI: [electronics]
[CategoryAudit] Vendor current allowedCategories: [groceries]

[CategoryAudit] ===== AUTH PROVIDER UPDATE START =====
[CategoryAudit] allowedCategories input: [electronics]
[CategoryAudit] Before copyWith: vendor.allowedCategories=[groceries]
[CategoryAudit] After copyWith: updatedVendor.allowedCategories=[electronics]

[CategoryAudit] ===== REPOSITORY UPDATE START =====
[CategoryAudit] user.allowedCategories being saved: [electronics]
[CategoryAudit] BEFORE update: [groceries]
[CategoryAudit] AFTER update: [electronics]

[CategoryAudit] ===== STORAGE SERVICE SAVE START =====
[CategoryAudit] allowed_categories: [electronics]

[CategoryAudit] ===== VENDOR LOGIN RESTORE =====
[CategoryAudit] userJson allowed_categories: [electronics]
[CategoryAudit] user.allowedCategories: [electronics]

[CategoryAudit] ===== CATEGORY AUDIT =====
[CategoryAudit] FINAL CATEGORIES USED IN FEED: [electronics]
```

### Problematic Output (APPEND behavior):

```
[CategoryAudit] After copyWith: updatedVendor.allowedCategories=[groceries, electronics]
```

---

## Root Cause Analysis

### Suspected Issue: UserModel.copyWith()

**File**: `lib/shared/models/user_model.dart`
**Method**: `copyWith()`

The `copyWith` method uses the null-coalescing operator (`??`):

```dart
UserModel copyWith({
  List<String>? allowedCategories,
  // ...
}) {
  return UserModel(
    allowedCategories: allowedCategories ?? this.allowedCategories,
    // ...
  );
}
```

**Analysis**:
- If `allowedCategories` is passed as a non-null value, it should REPLACE
- If `allowedCategories` is null, it keeps the old value
- **This is CORRECT** - the issue is NOT here

### Investigation Focus

1. **Check if `_selectedCategories` state is being mutated**
   - Does the UI widget maintain a reference to the old list?
   - Is `List.from()` being used correctly?

2. **Check if there's list concatenation happening**
   - Search for `..addAll()`, `+`, or spread operators

3. **Check storage persistence**
   - Verify JSON serialization/deserialization doesn't merge lists

---

## Fix Strategy (DO NOT IMPLEMENT YET)

Once root cause is identified through logs:

1. If UI state mutation: Ensure `_selectedCategories` is a new list
2. If copyWith issue: Fix UserModel.copyWith() to handle empty lists
3. If storage issue: Fix serialization logic

---

## Conclusion

All audit points are now instrumented. Run the app and follow the testing instructions to see the complete trace from Admin Save → Storage → Vendor Login → Feed Matching.

The logs will reveal where the category list is being appended instead of replaced.
