# Category Request UI and Merge Behavior Fix

**Status**: ✅ COMPLETE  
**Date**: 2025-01-XX

---

## Issues Fixed

### Issue 1: Vendor Profile Edit Screen ✅

**Problem**: 
- Request Categories section showed all approved categories as selected
- Logical confusion between approved and requested categories

**Root Cause**: 
Initialization logic was falling back to `allowedCategories` when no pending request existed

**Solution**:
Initialize `_requestedCategories` strictly from `requestedCategories` only:

```dart
if (user.hasPendingCategoryRequest == true && 
    user.requestedCategories != null && 
    user.requestedCategories!.isNotEmpty) {
  _requestedCategories = normalizeList(user.requestedCategories);
} else {
  _requestedCategories = []; // Empty, not allowedCategories
}
```

**Result**:
- Approved Categories: Read-only display of `allowedCategories`
- Request Categories: Editable chips, only shows pending requested categories
- Clear visual and logical separation

---

### Issue 2: "Use Requested Categories" Destructive Behavior ✅

**Problem**:
"Use Requested Categories" button replaced all existing allowed categories with only requested categories

**Example**:
```
Before tap:
allowedCategories: [clothing, electronics, hardware, home appliances, vehicle parts]
requestedCategories: [furniture]

After tap (WRONG):
selector: [furniture] only
```

**Root Cause**:
```dart
// WRONG:
_selectedCategories = requestedCategories;
```

**Solution**:
Changed to merge behavior:

```dart
// Merge current selected + requested categories
final merged = VendorCategories.normalizeList([
  ..._selectedCategories,
  ..._latestVendor.requestedCategories!,
]);

_selectedCategories = merged;
```

**Result**:
```
Before tap:
allowedCategories: [clothing, electronics, hardware, home appliances, vehicle parts]
requestedCategories: [furniture]

After tap (CORRECT):
selector: [clothing, electronics, furniture, hardware, home appliances, vehicle parts]
```

**Button Label Changed**:
- Before: "Use Requested Categories"
- After: "Add Requested Categories"

**Icon Changed**:
- Before: `Icons.check_circle_outline`
- After: `Icons.add_circle_outline`

---

## Business Rules Enforced

✅ **allowedCategories** = currently approved categories  
✅ **requestedCategories** = categories vendor wants to add/change  
✅ Vendor requests do NOT automatically remove existing approved categories  
✅ Admin can still manually "Clear All" if they want to replace everything  
✅ "Add Requested Categories" means "merge requested additions into current approved set"  

---

## Logs Added

### Vendor Profile Screen:
```
[CategoryLogic] Profile approvedCategories: <categories>
[CategoryLogic] Profile requestedCategories init: <categories>
[CategoryLogic] Profile requestedCategories save: <categories>
```

### Admin Assignment Screen:
```
[CategoryLogic] Before add requested: <categories>
[CategoryLogic] Requested categories: <categories>
[CategoryLogic] After add requested merged: <categories>
```

---

## Test Cases

### Test A: Vendor with No Pending Request ✅

**Given**:
```dart
allowedCategories = [clothing, electronics, hardware, home appliances, vehicle parts]
requestedCategories = []
hasPendingCategoryRequest = false
```

**Vendor Edit Screen**:
- Approved Categories (read-only): clothing, electronics, hardware, home appliances, vehicle parts
- Request Categories: no chips selected

---

### Test B: Vendor Requests New Category ✅

**Action**: Vendor selects "furniture" in Request Categories and saves

**View Mode Shows**:
- Approved: clothing, electronics, hardware, home appliances, vehicle parts
- Pending Request: furniture

---

### Test C: Admin Adds Requested Categories ✅

**Given**:
```dart
allowedCategories = [clothing, electronics, hardware, home appliances, vehicle parts]
requestedCategories = [furniture]
```

**Admin Assign Store**:
- Current Approved: clothing, electronics, hardware, home appliances, vehicle parts
- Vendor Requested: furniture (with "Add Requested Categories" button)
- Allowed Selector Initially: clothing, electronics, hardware, home appliances, vehicle parts

**Admin taps "Add Requested Categories"**:
- Allowed Selector becomes: clothing, electronics, furniture, hardware, home appliances, vehicle parts

---

### Test D: Admin Saves ✅

**Result**:
```dart
allowedCategories = [clothing, electronics, furniture, hardware, home appliances, vehicle parts]
requestedCategories = []
hasPendingCategoryRequest = false
```

---

## Files Modified

### 1. lib/features/shared/presentation/screens/profile_screen.dart

**Changes**:
- Fixed initialization: Only use `requestedCategories` if pending request exists
- Removed fallback to `allowedCategories`
- Added proper logging

**Code**:
```dart
// BEFORE (WRONG):
_requestedCategories = user.requestedCategories ?? user.allowedCategories ?? [];

// AFTER (CORRECT):
if (user.hasPendingCategoryRequest == true && 
    user.requestedCategories != null && 
    user.requestedCategories!.isNotEmpty) {
  _requestedCategories = normalizeList(user.requestedCategories);
} else {
  _requestedCategories = [];
}
```

---

### 2. lib/features/admin/presentation/screens/admin_vendor_assignment_screen.dart

**Changes**:
- Changed "Use Requested Categories" to "Add Requested Categories"
- Changed from replace behavior to merge behavior
- Updated icon from check to add
- Added merge logging

**Code**:
```dart
// BEFORE (WRONG):
_selectedCategories = VendorCategories.normalizeList(
  _latestVendor.requestedCategories,
);

// AFTER (CORRECT):
final merged = VendorCategories.normalizeList([
  ..._selectedCategories,
  ..._latestVendor.requestedCategories!,
]);
_selectedCategories = merged;
```

---

## UI Changes

### Vendor Profile Edit Mode:
- Approved Categories section: Always read-only
- Request Categories section: Only shows pending requested categories (not approved ones)

### Admin Assignment Screen:
- Button label: "Use Requested Categories" → "Add Requested Categories"
- Button icon: check icon → add icon
- Behavior: Replace → Merge

---

## No Changes Made To

✅ Vendor feed logic  
✅ Marketplace distance logic  
✅ Customer request logic  
✅ Category normalization constants  
✅ Admin vendor management card  
✅ Category save/clear logic  

---

## Summary

**Root Issues**:
1. Vendor profile initialized request categories from approved categories
2. Admin "Use Requested" replaced instead of merging

**Fixes**:
1. Strict separation: request categories ONLY from `requestedCategories`
2. Merge behavior: ADD requested to current approved

**Result**:
- Clear logical separation between approved and requested
- Non-destructive workflow for admin
- Vendor can request additions without losing existing approvals
