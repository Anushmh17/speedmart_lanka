# Approximate Area Persistence Audit

## Problem

`approximateAreaText` (e.g., "Nugegoda", "Kandy Town") does not persist after app restart.
Other address fields (province, district, streetAddress) persist correctly.

## Audit Trace Points

### 1. Form Input Capture
**File**: `delivery_address_form.dart`
**Method**: `validateAndSync()`

```dart
[ApproxAreaAudit] ===== FORM validateAndSync =====
[ApproxAreaAudit] _areaCtrl.text: "Nugegoda"
[ApproxAreaAudit] Created loc.approximateAreaText: "Nugegoda"
[ApproxAreaAudit] Created loc.suburb: "Nugegoda"
```

**Verify**: The controller value is correctly captured.

---

### 2. Location Provider Update
**File**: `location_provider.dart`
**Method**: `setLocation()`

```dart
[ApproxAreaAudit] ===== LOCATION PROVIDER setLocation =====
[ApproxAreaAudit] Input location.approximateAreaText: "Nugegoda"
[ApproxAreaAudit] Input location.suburb: "Nugegoda"
[ApproxAreaAudit] State updated: state.approximateAreaText: "Nugegoda"
[ApproxAreaAudit] State updated: state.currentLocation.approximateAreaText: "Nugegoda"
```

**Verify**: Provider state is updated correctly.

---

### 3. Save Button Click
**File**: `customer_delivery_address_screen.dart`
**Method**: `_save()`

```dart
[ApproxAreaAudit] ===== SAVE BUTTON CLICKED =====
[ApproxAreaAudit] deliveryLocationProvider.currentLocation.approximateAreaText: "Nugegoda"
[ApproxAreaAudit] deliveryLocationProvider.approximateAreaText: "Nugegoda"
```

**Verify**: Location data is available before conversion.

---

### 4. Model Conversion (DeliveryLocation → CustomerDeliveryAddress)
**File**: `customer_delivery_address.dart`
**Method**: `fromDeliveryLocation()`

```dart
[ApproxAreaAudit] ===== fromDeliveryLocation START =====
[ApproxAreaAudit] Input location.approximateAreaText: "Nugegoda"
[ApproxAreaAudit] Input location.suburb: "Nugegoda"
[ApproxAreaAudit] Result approximateArea: "Nugegoda"
[ApproxAreaAudit] ===== fromDeliveryLocation COMPLETE =====
```

**Verify**: 
- Does `approximateAreaText` or `suburb` have the value?
- Is the ternary logic correct?

---

### 5. Provider Save
**File**: `customer_delivery_address_provider.dart`
**Method**: `saveDefaultAddress()`

```dart
[ApproxAreaAudit] ===== SAVE DEFAULT ADDRESS START =====
[ApproxAreaAudit] Input address.approximateArea: "Nugegoda"
[ApproxAreaAudit] Saved address.approximateArea: "Nugegoda"
[ApproxAreaAudit] ===== SAVE DEFAULT ADDRESS COMPLETE =====
```

**Verify**: Address model has correct value before repository save.

---

### 6. Repository Serialization
**File**: `customer_delivery_address_repository.dart`
**Method**: `save()`

```dart
[ApproxAreaAudit] ===== REPOSITORY SAVE START =====
[ApproxAreaAudit] Input address.approximateArea: "Nugegoda"
[ApproxAreaAudit] Storage key: customer_delivery_address_cust-001
[ApproxAreaAudit] Serialized JSON approximateArea: "Nugegoda"
[ApproxAreaAudit] ===== REPOSITORY SAVE COMPLETE =====
```

**Verify**: JSON serialization preserves the value.

---

### 7. Repository Deserialization (App Restart)
**File**: `customer_delivery_address_repository.dart`
**Method**: `load()`

```dart
[ApproxAreaAudit] ===== REPOSITORY LOAD =====
[ApproxAreaAudit] Loaded from storage key: customer_delivery_address_cust-001
[ApproxAreaAudit] Raw JSON approximateArea: "Nugegoda"
[ApproxAreaAudit] Deserialized address.approximateArea: "Nugegoda"
[ApproxAreaAudit] ===== LOAD COMPLETE =====
```

**Verify**: 
- Does the JSON have the value?
- Does deserialization work correctly?

---

### 8. Model Conversion (CustomerDeliveryAddress → DeliveryLocation)
**File**: `customer_delivery_address.dart`
**Method**: `toDeliveryLocation()`

```dart
[ApproxAreaAudit] ===== toDeliveryLocation START =====
[ApproxAreaAudit] this.approximateArea: "Nugegoda"
[ApproxAreaAudit] this.suburb: "Nugegoda"
[ApproxAreaAudit] Result approximateAreaText: "Nugegoda"
[ApproxAreaAudit] ===== toDeliveryLocation COMPLETE =====
```

**Verify**: Conversion back to DeliveryLocation preserves approximateAreaText.

---

### 9. Apply to Provider (After Load)
**File**: `customer_delivery_address_provider.dart`
**Method**: `applyActiveLocationToProvider()`

```dart
[ApproxAreaAudit] ===== applyActiveLocationToProvider =====
[ApproxAreaAudit] activeLocation: exists
[ApproxAreaAudit] activeLocation.approximateAreaText: "Nugegoda"
```

**Verify**: The loaded location is applied to the location provider.

---

### 10. Location Provider Receives Restored Data
**File**: `location_provider.dart`
**Method**: `setLocation()`

```dart
[ApproxAreaAudit] ===== LOCATION PROVIDER setLocation =====
[ApproxAreaAudit] Input location.approximateAreaText: "Nugegoda"
[ApproxAreaAudit] State updated: state.approximateAreaText: "Nugegoda"
```

**Verify**: Provider state is restored correctly.

---

### 11. Form Controller Assignment (syncFromProvider)
**File**: `delivery_address_form.dart`
**Method**: `_applyFromLocationState()`

```dart
[CustomerLocation] _applyFromLocationState called
[CustomerLocation] locationState.approximateAreaText: "Nugegoda"
[CustomerLocation] currentLocation: exists
[CustomerLocation] loc.approximateAreaText: "Nugegoda"
[CustomerLocation] loc.displayArea: "Nugegoda"
[CustomerLocation] Restored controller value: "Nugegoda"
```

**Verify**: The text controller gets the restored value.

---

## Potential Root Causes

### Hypothesis 1: Empty `approximateAreaText` in DeliveryLocation
```dart
// SUSPECT: In validateAndSync()
final loc = locationState.currentLocation.copyWith(
  suburb: area,
  approximateAreaText: area,  // ← Is this being set?
);
```

### Hypothesis 2: Wrong Field Priority in Model Conversion
```dart
// SUSPECT: In fromDeliveryLocation()
approximateArea: location.approximateAreaText.isNotEmpty
    ? location.approximateAreaText
    : location.suburb,  // ← Which has the value?
```

### Hypothesis 3: Wrong Field Priority in Reverse Conversion
```dart
// SUSPECT: In toDeliveryLocation()
approximateAreaText: approximateArea.isNotEmpty ? approximateArea : suburb,
```

### Hypothesis 4: Form Controller Not Getting Value
```dart
// SUSPECT: In _applyFromLocationState()
final areaText = locationState.approximateAreaText.isNotEmpty
    ? locationState.approximateAreaText
    : (loc.approximateAreaText.isNotEmpty
        ? loc.approximateAreaText
        : loc.displayArea);
_areaCtrl.text = areaText;  // ← Is this empty?
```

---

## Testing Steps

### Step 1: Save Address
1. Login as customer
2. Go to Delivery Address screen
3. Enter:
   - Province: Western Province
   - District: Colombo
   - Approximate Area: "Nugegoda"
   - Street: "123 Main Street"
4. Click "Confirm Delivery Location"

### Step 2: Verify Save Logs
Check console for complete trace through checkpoints 1-6.

Expected at checkpoint 6:
```
[ApproxAreaAudit] Serialized JSON approximateArea: "Nugegoda"
```

### Step 3: Restart App
Close and reopen the app completely.

### Step 4: Verify Load Logs
1. Login as customer
2. Go to Delivery Address screen
3. Check console for checkpoints 7-11

Expected at checkpoint 11:
```
[CustomerLocation] Restored controller value: "Nugegoda"
```

### Step 5: Visual Verification
- [ ] Approximate Area field shows: "Nugegoda"
- [ ] Province dropdown shows: Western Province
- [ ] District dropdown shows: Colombo
- [ ] Street field shows: 123 Main Street

---

## Checkpoint Results Template

```
SAVE FLOW (Checkpoints 1-6):
✓/✗ Checkpoint 1: Form captures "Nugegoda"
✓/✗ Checkpoint 2: Provider updates with "Nugegoda"
✓/✗ Checkpoint 3: Save button has "Nugegoda"
✓/✗ Checkpoint 4: Model conversion preserves "Nugegoda"
✓/✗ Checkpoint 5: Provider save has "Nugegoda"
✓/✗ Checkpoint 6: Repository serializes "Nugegoda"

LOAD FLOW (Checkpoints 7-11):
✓/✗ Checkpoint 7: Repository loads "Nugegoda" from JSON
✓/✗ Checkpoint 8: Model conversion preserves "Nugegoda"
✓/✗ Checkpoint 9: Active location has "Nugegoda"
✓/✗ Checkpoint 10: Provider receives "Nugegoda"
✓/✗ Checkpoint 11: Form controller assigned "Nugegoda"

ROOT CAUSE IDENTIFIED AT: _______________

EXPLANATION: _____________________________
```

---

## Expected Output (Success)

If everything works correctly, you should see an unbroken chain:

```
SAVE:
Checkpoint 1: "Nugegoda" → 
Checkpoint 2: "Nugegoda" → 
Checkpoint 3: "Nugegoda" → 
Checkpoint 4: "Nugegoda" → 
Checkpoint 5: "Nugegoda" → 
Checkpoint 6: "Nugegoda" → STORAGE

LOAD:
STORAGE → 
Checkpoint 7: "Nugegoda" → 
Checkpoint 8: "Nugegoda" → 
Checkpoint 9: "Nugegoda" → 
Checkpoint 10: "Nugegoda" → 
Checkpoint 11: "Nugegoda" → UI FIELD
```

If any checkpoint shows `""` (empty string) or `null`, that's the break point.

---

## Analysis

Once you run the test and collect logs, look for:

1. **First checkpoint with empty value** - That's where data is lost
2. **Field priority issues** - Which field has value: `approximateAreaText` or `suburb`?
3. **Ternary logic bugs** - Are fallbacks working correctly?
4. **Controller assignment** - Is the UI controller getting the value?

DO NOT IMPLEMENT FIXES until root cause is confirmed from logs.
