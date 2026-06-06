# Category System - Quick Reference Guide

## Single Source of Truth

All categories defined in one place:
```dart
import 'package:speedmart_lanka/shared/utils/category_constants.dart';

VendorCategories.displayList     // ['Groceries', 'Electronics', ...]
VendorCategories.normalizedList  // ['groceries', 'electronics', ...]
VendorCategories.normalizationMap // Map lookup
```

---

## Common Operations

### Normalize Single Category
```dart
// Display → Normalized
VendorCategories.normalize('Home Appliances')    // 'home appliances'
VendorCategories.normalize('ELECTRONICS')        // 'electronics'
```

### Convert to Display Format
```dart
// Normalized → Display
VendorCategories.display('home appliances')      // 'Home Appliances'
VendorCategories.display('electronics')          // 'Electronics'
```

### Normalize List (Remove Duplicates)
```dart
// List with duplicates → Clean list
VendorCategories.normalizeList([
  'Home Appliances',
  'home appliances',
  'Electronics'
])
// Returns: ['electronics', 'home appliances'] (deduplicated, sorted)
```

### Convert List to Display Format
```dart
VendorCategories.displayList(['electronics', 'home appliances'])
// Returns: ['Electronics', 'Home Appliances']
```

### Show Category Options in UI
```dart
// Use displayList for chip options
VendorCategories.displayList.map((displayCat) {
  final normalized = VendorCategories.normalize(displayCat);
  return FilterChip(
    label: Text(displayCat),  // Display format
    selected: _selectedCategories.contains(normalized),  // Check normalized
    onSelected: (selected) {
      setState(() {
        if (selected) {
          _selectedCategories.add(normalized);
        } else {
          _selectedCategories.remove(normalized);
        }
      });
    },
  );
})
```

### Validate Categories
```dart
// Check if valid
if (VendorCategories.isValid('home appliances')) {
  // Valid
}

// Get invalid categories
List<String> invalid = VendorCategories.getInvalidCategories(categories);
```

---

## Screen-Specific Usage

### Admin Assignment Screen
```dart
// Initialize
_selectedCategories = VendorCategories.normalizeList(vendor.allowedCategories);

// Display options
VendorCategories.displayList

// Save (already normalized)
allowedCategories: List<String>.from(_selectedCategories),
```

### Vendor Profile Screen
```dart
// Initialize requested
_requestedCategories = VendorCategories.normalizeList(user.requestedCategories);

// Display approved
VendorCategories.displayList(VendorCategories.normalizeList(user.allowedCategories))

// Save (already normalized)
requestedCategories: _requestedCategories
```

### Display in Cards/Lists
```dart
// Show categories in card
VendorCategories.displayList(VendorCategories.normalizeList(vendor.allowedCategories))
    .take(3)
    .map((displayCat) => Chip(label: Text(displayCat)))
    .toList()
```

---

## Data Flow

### Load Data
```
Raw JSON: {allowed_categories: ['Home Appliances', 'home appliances']}
    ↓
UserModel.fromJson(json)
    ↓
VendorCategories.normalizeList()
    ↓
Result: ['electronics', 'home appliances'] (deduplicated)
```

### Display in UI
```
Stored: ['electronics', 'home appliances']
    ↓
VendorCategories.displayList()
    ↓
UI: ['Electronics', 'Home Appliances']
```

### Save User Selection
```
User selects: [✓ Electronics, ✓ Home Appliances]
    ↓
VendorCategories.normalize() each
    ↓
Stored: ['electronics', 'home appliances']
```

---

## Logging

### Enable Category Logs
```bash
# Console/logcat filter
adb logcat | grep "\[Category"

# Shows:
# [CategoryNormalize] Before/After
# [CategoryFix] Operations
```

### What Gets Logged

```
[CategoryNormalize] Before: [Home Appliances, home appliances, Electronics]
[CategoryNormalize] After: [electronics, home appliances]

[CategoryFix] INITIALIZED categories from fresh vendor: [...]
[CategoryFix] CHIP SELECTED: Home Appliances (home appliances), list now: [...]
[CategoryFix] EXACT categories to save: [...]
```

---

## 8 Valid Categories

Only these are recognized:
1. Groceries → groceries
2. Electronics → electronics
3. Hardware → hardware
4. Furniture → furniture
5. Pharmacy → pharmacy
6. Clothing → clothing
7. Vehicle Parts → vehicle parts
8. Home Appliances → home appliances

Anything else will be logged as invalid.

---

## Key Rules

✅ **Always use VendorCategories**
- Don't hardcode categories
- Don't create duplicate lists
- Don't normalize manually

✅ **Storage is Always Lowercase**
- Save: ['electronics', 'home appliances']
- Never: ['Electronics', 'Home Appliances']

✅ **Display is Always Title Case**
- Show: 'Electronics', 'Home Appliances'
- Never: 'electronics', 'home appliances'

✅ **Deduplication Automatic**
- Call normalizeList()
- Duplicates removed automatically
- No manual dedup needed

✅ **Case Insensitive**
- "HOME APPLIANCES" = "home appliances" = "Home Appliances"
- All normalize to same value

---

## Common Mistakes & Fixes

### ❌ WRONG: Hardcoded List
```dart
final categories = ['Groceries', 'Electronics'];
chips.addAll(categories.map(...));
```

### ✅ CORRECT: Use VendorCategories
```dart
final categories = VendorCategories.displayList;
chips.addAll(categories.map(...));
```

---

### ❌ WRONG: Manual Normalization
```dart
final normalized = category.toLowerCase().trim();
```

### ✅ CORRECT: Use VendorCategories
```dart
final normalized = VendorCategories.normalize(category);
```

---

### ❌ WRONG: Display Normalized
```dart
Text(_selectedCategories[0])  // Shows: 'home appliances'
```

### ✅ CORRECT: Use Display Helper
```dart
Text(VendorCategories.display(_selectedCategories[0]))  // Shows: 'Home Appliances'
```

---

### ❌ WRONG: Manual Dedup
```dart
categories = categories.toSet().toList();
```

### ✅ CORRECT: Use normalizeList
```dart
categories = VendorCategories.normalizeList(categories);
```

---

## Quick Checklist

Before saving categories:
- [ ] Using VendorCategories? (not hardcoded list)
- [ ] Calling normalizeList()? (for dedup)
- [ ] Storing lowercase? (normalized format)
- [ ] Displaying title case? (using .display())
- [ ] Logging operations? ([CategoryFix] prefix)

Before displaying categories:
- [ ] Using VendorCategories.displayList?
- [ ] Calling VendorCategories.display() for each?
- [ ] Will show as title case? (Home Appliances)
- [ ] No duplicates possible? (normalizeList used)

---

## Support

**Questions about categories?**
1. Check VendorCategories in category_constants.dart
2. Look for [CategoryNormalize] or [CategoryFix] in logs
3. Verify using VendorCategories helpers
4. Ensure normalizeList() called

**Debugging**:
```bash
# Show all category operations
adb logcat | grep "\[Category"

# Show normalization details
adb logcat | grep "\[CategoryNormalize\]"

# Show fix operations
adb logcat | grep "\[CategoryFix\]"
```

---

## Summary

**Single Source of Truth**: VendorCategories
**Automatic Dedup**: normalizeList()
**Always Normalized**: Lowercase storage
**Always Displayed**: Title case UI
**Zero Duplicates**: Guaranteed
