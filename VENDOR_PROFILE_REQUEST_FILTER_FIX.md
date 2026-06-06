# Vendor Profile Request Categories Filter Fix

**Status**: ✅ COMPLETE  
**Date**: 2025-01-XX

---

## Issue Fixed

**Problem**: 
In vendor profile edit mode, Request Categories selector showed ALL master categories, including already-approved categories.

**Example (WRONG)**:
```
Approved Categories:
Clothing, Electronics, Hardware, Home Appliances, Vehicle Parts

Request Categories selector shows:
Groceries, Electronics, Hardware, Furniture, Pharmacy, Clothing, Vehicle Parts, Home Appliances
```

This is logically wrong because vendor should not request categories that are already approved.

---

## Required Behavior

**Request Categories selector should show ONLY categories that are NOT already approved.**

**Example (CORRECT)**:
```
Approved Categories:
Clothing, Electronics, Hardware, Home Appliances, Vehicle Parts

Request Categories selector shows ONLY:
Groceries, Furniture, Pharmacy
```

---

## Solution Implemented

### 1. Calculate Requestable Categories

In vendor profile edit mode, dynamically calculate which categories can be requested:

```dart
final approved = VendorCategories.normalizeList(user.allowedCategories ?? []);
final all = VendorCategories.normalizedList;
final requestableCategories = all
    .where((cat) => !approved.contains(cat))
    .toList();
```

### 2. Filter Initialization

When initializing `_requestedCategories` from pending request, filter out any already-approved categories:

```dart
_requestedCategories = VendorCategories.normalizeList(user.requestedCategories)
    .where((cat) => requestableCategories.contains(cat))
    .toList();
```

### 3. Build Request Chips from Requestable Only

Request category chips are built from `requestableCategories` only, not all master categories.

### 4. Handle All Approved Case

If no requestable categories exist (all are approved), show:
```
"All categories are already approved."
```

---

## Code Changes

### File: lib/features/shared/presentation/screens/profile_screen.dart

#### Change 1: Removed Unused Variable
```dart
// REMOVED:
final List<String> _availableCategories = VendorCategories.displayNames;
```

#### Change 2: Enhanced Initialization Logic
```dart
// BEFORE:
_requestedCategories = VendorCategories.normalizeList(user.requestedCategories);

// AFTER:
final approved = VendorCategories.normalizeList(user.allowedCategories ?? []);
final all = VendorCategories.normalizedList;
final requestableCategories = all.where((cat) => !approved.contains(cat)).toList();

_requestedCategories = VendorCategories.normalizeList(user.requestedCategories)
    .where((cat) => requestableCategories.contains(cat))
    .toList();
```

#### Change 3: Dynamic Requestable Categories in UI
```dart
// Calculate on each build in edit mode
Builder(
  builder: (context) {
    final approved = VendorCategories.normalizeList(user.allowedCategories ?? []);
    final all = VendorCategories.normalizedList;
    final requestableCategories = all.where((cat) => !approved.contains(cat)).toList();
    final requestableDisplay = VendorCategories.displayList(requestableCategories);
    
    if (requestableCategories.isEmpty) {
      return Text('All categories are already approved.');
    }
    
    // Build chips from requestableDisplay only
  }
)
```

---

## Logs Added

```dart
[CategoryLogic] Approved categories: <list>
[CategoryLogic] Requestable categories: <list>
[CategoryLogic] Filtered requested categories: <list>
```

---

## Test Cases

### Test A: Vendor with Some Approved Categories ✅

**Given**:
```dart
allowedCategories = [clothing, electronics, hardware, home appliances, vehicle parts]
requestedCategories = []
hasPendingCategoryRequest = false
```

**Vendor Profile Edit Mode**:
- Approved Categories (read-only): Clothing, Electronics, Hardware, Home Appliances, Vehicle Parts
- Request Categories selector shows ONLY: **Groceries, Furniture, Pharmacy**
- Does NOT show: Clothing, Electronics, Hardware, Home Appliances, Vehicle Parts

---

### Test B: Vendor Selects New Category ✅

**Action**: Vendor selects "Furniture" from Request Categories and saves

**Result**:
```dart
requestedCategories = [furniture]
hasPendingCategoryRequest = true
```

**View Mode Shows**:
- Approved: Clothing, Electronics, Hardware, Home Appliances, Vehicle Parts
- Pending Request: **Furniture** (only)

---

### Test C: Vendor with All Categories Approved ✅

**Given**:
```dart
allowedCategories = [clothing, electronics, groceries, furniture, hardware, home appliances, pharmacy, vehicle parts]
```

**Vendor Profile Edit Mode**:
- Approved Categories: All 8 categories
- Request Categories section shows: **"All categories are already approved."**
- No chips available to select

---

### Test D: Filter Legacy Requested Categories ✅

**Given** (edge case - requested category was approved since request was made):
```dart
allowedCategories = [clothing, electronics, hardware, home appliances, vehicle parts, furniture]
requestedCategories = [furniture, pharmacy]  // furniture now approved
hasPendingCategoryRequest = true
```

**Vendor Profile Edit Mode**:
- Initialization automatically filters out "furniture" (already approved)
- `_requestedCategories` becomes: `[pharmacy]` only
- Request Categories selector shows: Groceries, Pharmacy
- "Pharmacy" is pre-selected

---

## Business Logic

✅ **Approved Categories** = read-only, always shown  
✅ **Requestable Categories** = Master list MINUS approved categories  
✅ **Request Categories** = vendor selects from requestable only  
✅ Vendor cannot request already-approved categories  
✅ Automatic filtering prevents stale requests  
✅ Clear message when all categories approved  

---

## No Changes Made To

✅ Admin assign store screen  
✅ Vendor feed logic  
✅ Category constants  
✅ Customer requests  
✅ Approved categories display  
✅ Save logic  

---

## Files Modified

1. ✅ `lib/features/shared/presentation/screens/profile_screen.dart`
   - Removed unused `_availableCategories` variable
   - Added requestable categories calculation in `_initData()`
   - Added requestable categories calculation in edit mode UI
   - Added filtering for initialization
   - Added "all approved" message

---

## Summary

**Root Cause**: Request Categories selector used all master categories instead of filtering out approved ones

**Fix**: 
- Calculate `requestableCategories = all - approved`
- Build chips from requestable categories only
- Filter initialization to remove already-approved categories
- Show message when no requestable categories exist

**Result**: 
- Vendor only sees categories they don't already have
- Cleaner, more intuitive UI
- Prevents redundant requests
- Handles edge cases (all approved, stale requests)
