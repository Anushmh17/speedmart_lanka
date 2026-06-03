# Vendor Location Fix - Test & Verification Plan

## Fix Applied
**Replaced hardcoded vendor GPS mock with real location service**

- Before: `register_screen._getGpsPosition()` always returned Colombo (6.9271, 79.8612)
- After: Now uses `SriLankaLocationService.detectCurrentLocation()` - same as customer delivery
- Result: Vendor shop location uses ACTUAL device GPS, not mock

---

## Test Scenario: Vendor in Jaffna

### Step 1: Register Vendor in Jaffna (Real Device Location)

1. **Device Setup:**
   - Android Emulator or Physical Device with Location enabled
   - Set emulator location to Jaffna: ~9.66°N, 80.01°E
   - Or enable GPS on physical device in Jaffna

2. **Register as Vendor:**
   - Role: Vendor
   - Full Name: "Jaffna Vendor Test"
   - Email: `jaffna-vendor@test.com`
   - Phone: `0777777777`
   - Business Name: "Jaffna Test Store"
   - Categories: Select "Groceries"
   - Shop Address: "123 Main St, Jaffna"

3. **GPS Detection:**
   - Click "Use Current Location" button
   - **Expected:** Device detects ACTUAL Jaffna coordinates (~9.66, 80.01)
   - **NOT:** Hardcoded Colombo (6.9271, 79.8612)

4. **Verify Registration Logs:**
   ```
   [VendorLocationAudit] GPS detected: lat=9.66XXX, lng=80.01XXX, accuracy=XX.Xm
   [VendorLocationAudit] Registration coordinates: lat=9.66XXX, lng=80.01XXX
   [VendorLocationAudit] Stored vendor coordinates: lat=9.66XXX, lng=80.01XXX
   ```

5. **Create Password:**
   - Password: `jaffna123`
   - Confirm: `jaffna123`

6. **Submit Registration**
   - Wait for auth to complete
   - Should navigate to Vendor Home

---

### Step 2: Admin Approves Vendor

1. **Login as Admin:**
   - Email: `admin@speedmart.lk`
   - Password: `admin123` (or whatever you used during admin registration)

2. **Go to Admin Dashboard → Vendor Management**

3. **Find "Jaffna Vendor Test" vendor**

4. **Click Edit/Assign**

5. **Verify Prefilled Coordinates:**
   - Latitude: Should show ~9.66XXX (NOT 6.9271)
   - Longitude: Should show ~80.01XXX (NOT 79.8612)
   - **These should be the actual Jaffna coordinates registered**

6. **Approve Vendor:**
   - Toggle "Approve Vendor" to ON
   - Click "Save Assignment"

7. **Verify Admin Logs:**
   ```
   [AdminVendor] Saved vendor allowedCategories: [groceries]
   ```

---

### Step 3: Create Customer Request in Jaffna

1. **Login as Customer:**
   - Email: `customer@test.com`
   - Password: (use existing customer account password)

2. **Go to Create Request**

3. **GPS Detection for Request:**
   - Same location (Jaffna ~9.66, 80.01)
   - Confirm location detection succeeds

4. **Create Request:**
   - Items: "Milk, Bread" (or any groceries)
   - Categories: "Groceries"
   - Complete and Submit

5. **Verify Request Created:**
   - Should see confirmation screen
   - Note request ID and location

---

### Step 4: Verify Vendor Sees Request (CRITICAL)

1. **Logout Customer, Login as Jaffna Vendor:**
   - Email: `jaffna-vendor@test.com`
   - Password: `jaffna123`

2. **Go to Vendor Request Feed**

3. **Watch Console Logs:**
   ```
   [FeedAudit] ===== VENDOR FEED LOAD START =====
   [VendorLocationAudit] Loaded vendor coordinates: lat=9.66XXX, lng=80.01XXX
   [FeedAudit] vendor.shopLatitude: 9.66XXX
   [FeedAudit] vendor.shopLongitude: 80.01XXX
   [FeedAudit] vendor.assignedRadiusKm: 20.0
   
   [RequestAudit] Total active requests: 1
   [RequestAudit] request.id: req-XXX, area: Jaffna, lat: 9.66XXX, lng: 80.01XXX
   [RequestAudit] request.items: Milk, Bread
   
   [DistanceAudit] request: req-XXX, distance: 0.0km (or very small), radius: 20.0, visible: true
   [FeedAudit] ===== VENDOR FEED LOAD COMPLETE: 1 requests shown =====
   ```

4. **Expected Result:**
   - **PASS:** Request appears in vendor feed (distance = ~0km)
   - **FAIL:** "REJECTION: All requests filtered out by distance" (vendor still has old coordinates)
   - **FAIL:** "REJECTION: Vendor not approved" (admin approval failed)

---

## Verification Checklist

| Check | Expected | Status |
|-------|----------|--------|
| Vendor GPS detects Jaffna, not Colombo | lat=9.66+, lng=80.01+ | ⏳ |
| Registration logs show Jaffna coords | [VendorLocationAudit] Stored: 9.66+, 80.01+ | ⏳ |
| Admin prefill shows Jaffna, not Colombo | Latitude: 9.66+, Longitude: 80.01+ | ⏳ |
| Vendor approved successfully | Admin logs show allowedCategories | ⏳ |
| Vendor feed loads with correct coords | [VendorLocationAudit] Loaded: 9.66+, 80.01+ | ⏳ |
| Request visible to vendor | Distance ≈ 0km, request shown in feed | ⏳ |

---

## Troubleshooting

### Issue: GPS Detection Returns Colombo (6.9271, 79.8612)

**Cause:** Emulator location not set correctly, or service still using mock

**Fix:**
1. Check emulator location settings (should be Jaffna)
2. Verify imports in register_screen.dart include `SriLankaLocationService`
3. Check that `_getGpsPosition()` calls `SriLankaLocationService().detectCurrentLocation()`

### Issue: Vendor Feed Shows "REJECTION: Shop location not assigned"

**Cause:** Admin approval didn't complete or save

**Fix:**
1. Re-run admin approval workflow
2. Check that "Approve Vendor" toggle is ON before saving
3. Verify logs show "allowedCategories" saved

### Issue: Vendor Feed Shows "REJECTION: All requests filtered out by distance"

**Cause:** Vendor still has old coordinates OR request is outside radius

**Fix:**
1. Check [VendorLocationAudit] logs show correct loaded coordinates
2. Verify request latitude/longitude are close to vendor coords
3. If distance is ~0km but still filtered, check category matching in [CategoryAudit] logs

### Issue: "WARNING: All requests filtered out by distance/category"

**Cause:** Possible mismatch between vendor categories and request

**Fix:**
1. Verify vendor `allowedCategories` includes request category
2. Check request is within assigned radius (should be 20km default)
3. Verify request coordinates are being logged correctly

---

## Success Criteria

**PASS Only If ALL Are True:**

1. ✅ Vendor registers with ACTUAL device GPS (not hardcoded Colombo)
2. ✅ Registration logs show Jaffna coordinates
3. ✅ Admin approval page prefills with Jaffna coordinates
4. ✅ Vendor feed loads vendor location as Jaffna coordinates
5. ✅ Customer request in Jaffna appears in vendor feed
6. ✅ Distance calculated correctly (≈0-10km)
7. ✅ No distance rejection ("filtered out") when vendor/customer in same location

**FAIL If:**
- Vendor coordinates show as Colombo (6.9271, 79.8612)
- Distance > 20km when both in same location
- Request filtered by distance when it should be visible
- Admin page shows Colombo instead of vendor-registered coordinates

---

## After Successful Test

Once PASS verified:
1. Commit fix with test results
2. Document in git commit what coordinates were tested
3. Ready to proceed with Order Lifecycle phase

---

## Logs to Monitor

Run app with console visible. Search for these prefixes:

```
[VendorLocationAudit]  ← Main location tracking
[FeedAudit]            ← Feed load rejection reasons
[DistanceAudit]        ← Distance calculations
[AdminVendor]          ← Admin approval & categories
[RequestAudit]         ← Request data
[AuthUI]               ← Registration UI flow
```

---

## Commands

```bash
# Run app with location-sensitive code
flutter run

# View console logs filtering for location
# Search in Android Studio Logcat or VS Code terminal for "[VendorLocationAudit]"

# If using emulator, set location to Jaffna in Extended Controls:
# Emulator menu → Extended Controls → Location
# Latitude: 9.66, Longitude: 80.01, Speed: 0
```

