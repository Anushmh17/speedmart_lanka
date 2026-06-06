# Approximate Area Persistence Audit - Summary

## What Was Done

Comprehensive logging added to trace `approximateAreaText` through the entire save/load cycle.

## Files Modified

### 1. delivery_address_form.dart
- ✅ Added logging in `validateAndSync()` to show controller value and created DeliveryLocation

### 2. location_provider.dart
- ✅ Added logging in `setLocation()` to show incoming and stored approximateAreaText

### 3. customer_delivery_address_screen.dart
- ✅ Added logging in `_save()` to show DeliveryLocation before model conversion

### 4. customer_delivery_address.dart
- ✅ Added logging in `fromDeliveryLocation()` factory (save conversion)
- ✅ Added logging in `toDeliveryLocation()` method (load conversion)

### 5. customer_delivery_address_provider.dart
- ✅ Added logging in `saveDefaultAddress()` before repository save
- ✅ Added logging in `applyActiveLocationToProvider()` after load

### 6. customer_delivery_address_repository.dart
- ✅ Added logging in `save()` to show serialized JSON
- ✅ Added logging in `load()` to show deserialized data

## Audit Checkpoints

### Save Flow (6 checkpoints)
1. Form input capture → `_areaCtrl.text`
2. Location provider update → `state.approximateAreaText`
3. Save button data → `currentLocation.approximateAreaText`
4. Model conversion → `approximateArea` field
5. Provider save → `address.approximateArea`
6. Repository save → JSON `approximateArea` key

### Load Flow (5 checkpoints)
7. Repository load → JSON `approximateArea` key
8. Model reverse conversion → `approximateAreaText` field
9. Apply to provider → `activeLocation.approximateAreaText`
10. Provider receives data → `state.approximateAreaText`
11. Form controller assignment → `_areaCtrl.text`

## Log Pattern

All audit logs use consistent format:
```
[ApproxAreaAudit] ===== STAGE NAME =====
[ApproxAreaAudit] field_name: "value"
[ApproxAreaAudit] ===== STAGE COMPLETE =====
```

## How to Use

### Execute Test

1. Run app in debug mode
2. Login as customer
3. Navigate to Delivery Address screen
4. Enter address with approximate area: "Nugegoda"
5. Save
6. Restart app completely
7. Login and check if "Nugegoda" appears

### Collect Logs

Search debug console for: `[ApproxAreaAudit]`

You should see:
- 6 checkpoint blocks during save
- 5 checkpoint blocks during load

### Analyze Results

Compare against expected trace in `APPROX_AREA_PERSISTENCE_AUDIT.md`.

Find the first checkpoint where value becomes empty → That's the root cause location.

## Potential Issues to Look For

### Issue 1: Empty at Save Point
If checkpoint 1-6 shows empty value:
- Form controller not capturing input
- Location provider not receiving update
- Model conversion losing data

### Issue 2: Empty at Load Point  
If checkpoint 7-11 shows empty value:
- JSON serialization issue
- Deserialization issue
- Model conversion priority bug
- Form controller not being assigned

### Issue 3: Field Priority Bug
If logs show:
```
approximateAreaText: ""
suburb: "Nugegoda"
```
Then the ternary logic is picking the wrong field.

## Decision Tree

```
Is checkpoint 6 correct? (JSON has "Nugegoda")
├─ YES
│  └─ Is checkpoint 7 correct? (Load reads "Nugegoda")
│     ├─ YES
│     │  └─ Is checkpoint 11 correct? (Controller assigned)
│     │     ├─ YES → No bug, data persists
│     │     └─ NO → Bug in form restoration
│     └─ NO → Bug in deserialization
└─ NO
   └─ Is checkpoint 4 correct? (Model has "Nugegoda")
      ├─ YES → Bug in provider save
      └─ NO → Bug in model conversion
```

## Next Steps

1. ✅ Audit logging implemented
2. ✅ Documentation created
3. ⏳ Execute test and collect logs
4. ⏳ Identify exact checkpoint where data is lost
5. ⏸️ Report root cause location
6. ⏸️ Implement targeted fix (after root cause confirmed)

## Important

**DO NOT IMPLEMENT FIXES** until logs confirm the exact checkpoint where data is lost.
