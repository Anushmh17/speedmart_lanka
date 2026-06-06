# Approximate Area Keyboard Closing Fix

## Problem Statement
Keyboard closes after every letter typed in the Approximate Area field. User must tap the field again to type the next character.

## Root Cause
The SearchableLocationField was using a **dynamic key** based on the controller text:

```dart
key: ValueKey('area-field-${_areaCtrl.text}')
```

This caused Flutter to dispose and recreate the widget on every character change, losing keyboard focus.

## Solution Implemented

### 1. Changed to Stable Key
```dart
// Before (BAD - causes keyboard to close)
key: ValueKey('area-field-${_areaCtrl.text}')

// After (GOOD - preserves keyboard focus)
key: const ValueKey('area-field')
```

### 2. Implemented didUpdateWidget in SearchableLocationField
Added proper widget lifecycle management to sync external value changes without disrupting user typing:

```dart
@override
void didUpdateWidget(covariant SearchableLocationField oldWidget) {
  super.didUpdateWidget(oldWidget);
  
  debugPrint('[ApproxAreaUI] Searchable didUpdateWidget oldInitial: "${oldWidget.initialValue}"');
  debugPrint('[ApproxAreaUI] Searchable didUpdateWidget newInitial: "${widget.initialValue}"');
  debugPrint('[ApproxAreaUI] Searchable focused: ${_focusNode.hasFocus}');
  debugPrint('[ApproxAreaUI] Searchable controller.text before: "${_controller.text}"');

  // Only sync external initialValue when field is not focused (user not typing)
  if (widget.initialValue != oldWidget.initialValue &&
      widget.initialValue != _controller.text &&
      !_focusNode.hasFocus) {
    _controller.text = widget.initialValue ?? '';
    debugPrint('[ApproxAreaUI] Searchable controller synced to: "${_controller.text}"');
  }
}
```

### Key Logic
- **Check 1:** `widget.initialValue != oldWidget.initialValue` - Has the prop changed?
- **Check 2:** `widget.initialValue != _controller.text` - Is it different from current value?
- **Check 3:** `!_focusNode.hasFocus` - Is the user NOT actively typing?

Only when all three conditions are true does the internal controller get updated.

## How This Works

### User Typing Scenario
1. User taps field → focus gained
2. User types "J" → controller updates to "J"
3. Parent's onChanged callback fires
4. Parent updates `_areaCtrl.text = "J"`
5. Parent passes `initialValue: "J"` to SearchableLocationField
6. `didUpdateWidget` runs:
   - `oldWidget.initialValue` = "" 
   - `widget.initialValue` = "J" ✓ (changed)
   - `_controller.text` = "J" ✗ (already matches)
   - `_focusNode.hasFocus` = true ✗ (user typing)
7. **No controller update** → field remains focused → keyboard stays open ✅

### Loading Saved Value Scenario
1. App restarts with saved value "Jaffna"
2. Form loads and sets `_areaCtrl.text = "Jaffna"`
3. SearchableLocationField builds with `initialValue: "Jaffna"`
4. User has NOT tapped the field → not focused
5. `didUpdateWidget` runs:
   - `oldWidget.initialValue` = ""
   - `widget.initialValue` = "Jaffna" ✓ (changed)
   - `_controller.text` = "" ✓ (different)
   - `_focusNode.hasFocus` = false ✓ (not typing)
6. **Controller updated to "Jaffna"** → UI displays "Jaffna" ✅

## Test Verification

### Test Scenario 1: Typing
1. Open delivery address screen
2. Tap Approximate Area field
3. Type "Jaffna Town" (13 characters)
4. **Expected:** Keyboard stays open for all 13 characters ✅
5. **Expected:** No focus loss ✅

### Test Scenario 2: Save/Load
1. Type "Jaffna Town" in Approximate Area
2. Save address
3. Restart app
4. Open delivery address screen
5. **Expected:** Field displays "Jaffna Town" ✅

### Test Scenario 3: GPS Update
1. User is typing in field (focused)
2. Background GPS update changes provider value
3. **Expected:** Field NOT overwritten while user is typing ✅
4. User unfocuses field
5. GPS triggers another update
6. **Expected:** Field updates to GPS value ✅

## Debug Logs Added

### In DeliveryAddressForm (Parent)
```
[ApproxAreaUI] ===== BUILD SearchableLocationField =====
[ApproxAreaUI] _areaCtrl.text = "..."
[ApproxAreaUI] locationState.approximateAreaText = "..."
[ApproxAreaUI] _userEditedApproxArea = true/false
```

### In SearchableLocationField (Child)
```
[ApproxAreaUI] Searchable didUpdateWidget oldInitial: "..."
[ApproxAreaUI] Searchable didUpdateWidget newInitial: "..."
[ApproxAreaUI] Searchable focused: true/false
[ApproxAreaUI] Searchable controller.text before: "..."
[ApproxAreaUI] Searchable controller synced to: "..." (only if updated)
```

## Files Modified
- `lib/features/customer/delivery_address/presentation/widgets/delivery_address_form.dart`
  - Changed dynamic key to stable key
- `lib/features/location/widgets/searchable_location_field.dart`
  - Added `didUpdateWidget` lifecycle method with focus-aware syncing
  - Added debug logs

## Compilation Status
✅ Project compiles successfully (239 pre-existing non-blocking issues)

## Key Insights

1. **Widget keys must be stable during user interaction**: Dynamic keys based on mutable state cause widget disposal and loss of focus
2. **didUpdateWidget is the proper way to sync props**: It allows widgets to respond to parent changes without full rebuild
3. **Focus state is critical**: Never update a TextField's controller while the user is actively typing
4. **Widget lifecycle matters**: Understanding initState vs didUpdateWidget is essential for stateful widgets
5. **Trade-offs**: The dynamic key solution worked for loading but broke typing. The didUpdateWidget solution handles both cases correctly.

## Why Dynamic Key Was Wrong

Dynamic keys tell Flutter "this is a completely different widget" on every rebuild. Flutter's optimization strategy is:
- Same key + same type → update existing widget
- Different key → dispose old widget, create new widget

When the key changed from `area-field-` to `area-field-J` to `area-field-Ja`, Flutter treated each as a different widget, disposing and recreating the TextField and its focus state each time.

## Why didUpdateWidget Is Right

`didUpdateWidget` is specifically designed for this scenario: when a parent passes new props to an existing widget. The widget can inspect the changes and decide how to respond without full disposal/recreation.
