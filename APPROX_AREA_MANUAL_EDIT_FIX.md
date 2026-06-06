# Approximate Area Manual Edit Persistence Fix

## Problem Statement
When users manually edited the Approximate Area field (e.g., changing "Jaffna" to "Jaffna Town"), the value would be overwritten back to the old/provider value before save or after reload, despite the repository correctly storing and loading the data.

## Root Cause
The form's `_applyFromLocationState()` method was being triggered by provider state changes and unconditionally overwriting the text controller value, even when the user was actively typing or had manually edited the field.

## Solution Implemented

### 1. Added User Edit Tracking Flag
```dart
bool _userEditedApproxArea = false;
```

This flag tracks whether the user has manually typed into the Approximate Area field.

### 2. Modified onChanged Handler
```dart
onChanged: (text) {
  setState(() => _userEditedApproxArea = true);
  _areaCtrl.text = text;
  debugPrint('[ApproxAreaAudit] User typed manual area: "$text"');
  ref.read(deliveryLocationProvider.notifier).setApproximateAreaText(text);
}
```

**Key Changes:**
- Sets `_userEditedApproxArea = true` immediately when user types
- Updates controller text directly
- Updates provider state with typed value
- Adds audit logging

### 3. Protected Controller from Overwrites
```dart
void _applyFromLocationState(LocationState locationState) {
  if (_userEditedApproxArea) {
    debugPrint('[ApproxAreaAudit] Skipping controller overwrite because user edited approximate area');
    debugPrint('[ApproxAreaAudit] Preserving manual value: "${_areaCtrl.text}"');
  }

  if (loc != null) {
    if (!_userEditedApproxArea) {
      final areaText = locationState.approximateAreaText.isNotEmpty
          ? locationState.approximateAreaText
          : (loc.approximateAreaText.isNotEmpty
              ? loc.approximateAreaText
              : loc.displayArea);
      _areaCtrl.text = areaText;
      debugPrint('[CustomerLocation] Restored controller value: $areaText');
    }
    // ... rest of code
  }
}
```

**Key Changes:**
- Guards controller updates when `_userEditedApproxArea == true`
- Logs when overwrites are prevented
- Preserves manual edits

### 4. Reset Flag on Save Success
```dart
if (mounted) {
  setState(() {
    _province = province;
    _district = district;
    _userEditedApproxArea = false;  // Reset after successful save
  });
  debugPrint('[ApproxAreaAudit] Save success, manual edit flag reset');
}
```

### 5. Reset Flag on GPS/Map Pin Updates
```dart
// GPS detection
Future<void> detectGps() async {
  setState(() {
    _isDetectingGps = true;
    _gpsError = null;
    _userEditedApproxArea = false;  // Reset when user requests GPS
  });
  debugPrint('[ApproxAreaAudit] GPS detection triggered - manual edit flag reset');
  // ...
}

// Map pin movement
if (pinMoved) {
  setState(() => _userEditedApproxArea = false);
  debugPrint('[ApproxAreaAudit] Map pin moved - manual edit flag reset');
  _applyFromLocationState(next);
}
```

### 6. Reset Flag on Suggestion Selection
```dart
onSuggestionSelected: (s) {
  setState(() => _userEditedApproxArea = false);  // Reset when suggestion picked
  _areaCtrl.text = s.display;
  debugPrint('[ApproxAreaAudit] Suggestion selected - manual edit flag reset');
  ref.read(deliveryLocationProvider.notifier).applySuggestion(s);
  if (mounted) syncFromProvider();
}
```

## Test Scenario

### Expected Behavior
1. Open delivery address screen with saved area: "Jaffna"
2. User manually edits field to: "Jaffna Town"
3. User clicks Save button
4. Restart app
5. Open delivery address screen
6. **Expected Result:** Approximate Area field shows "Jaffna Town"

### Edge Cases Handled
- **GPS Detection:** Flag resets when user taps "Use Current Location"
- **Map Pin Movement:** Flag resets when user drags map pin
- **Suggestion Selection:** Flag resets when user picks autocomplete suggestion
- **Save Success:** Flag resets after successful save to allow future overwrites

## Files Modified
- `lib/features/customer/delivery_address/presentation/widgets/delivery_address_form.dart`

## Key Insights
1. **User intent must override provider state**: Manual edits represent explicit user intent and should take precedence over automatic provider updates
2. **State synchronization timing**: The flag must reset only at specific moments (save success, GPS request, map interaction) to properly distinguish user edits from system updates
3. **Controller vs Provider state**: The controller holds the UI state (what user sees), while the provider holds the application state (what gets saved) - both must stay in sync
4. **Audit logging is critical**: The ApproxAreaAudit logs help trace the exact flow and verify the fix works correctly

## Business Rules Preserved
- Approximate Area is a user-friendly display label
- GPS/map pin coordinates remain the source of truth for location
- Distance calculation unchanged
- Map pin coordinates unchanged
- Vendor feed logic unchanged
