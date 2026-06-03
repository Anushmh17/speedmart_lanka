# Marketplace Data Flow Audit Report

**Date:** 2026-06-03  
**Status:** CATEGORY SOURCE OF TRUTH FIX COMPLETED

---

## Executive Summary

✅ **CRITICAL CATEGORY SOURCE OF TRUTH FIX COMPLETED**

The critical bug where vendor request feed used vendor-submitted categories instead of admin-approved categories has been fixed. All changes have been implemented and are ready for testing.

Comprehensive audit logging has been added to trace critical data flows through the marketplace system:

1. ✅ Request Creation & Persistence
2. ✅ Category Synchronization (FIXED)
3. ✅ Vendor Matching Logic  
4. ✅ Distance Filtering
5. ✅ Request Visibility

---

## FIX COMPLETED: Category Source of Truth

### Implementation Summary

**Root Cause:** Vendor request feed used `user.vendorCategories` (vendor-submitted) instead of `user.allowedCategories` (admin-approved)

**Solution Implemented:**
1. Added `allowedCategories: List<String>?` field to UserModel as single source of truth
2. Updated UserModel serialization (fromJson/toJson/copyWith)
3. Updated vendor_request_feed_provider.dart to use `user.allowedCategories ?? user.vendorCategories`
4. Updated admin_vendor_assignment_screen.dart to save allowedCategories
5. Updated auth_provider.dart updateVendorShopAssignment() to persist allowedCategories

**Files Modified:**
- `lib/shared/models/user_model.dart` - Added allowedCategories field
- `lib/features/vendor/request_feed/providers/vendor_request_feed_provider.dart` - Use allowedCategories
- `lib/features/admin/presentation/screens/admin_vendor_assignment_screen.dart` - Save allowedCategories
- `lib/features/auth/providers/auth_provider.dart` - Persist allowedCategories

**Debug Logs Added:**
```
[CategoryAudit] SOURCE OF TRUTH: allowedCategories
[CategoryAudit] Using vendor.allowedCategories: [list]
[AdminVendor] Saved vendor allowedCategories: [list]
[Auth] Persisted vendor to storage with allowedCategories: [list]
```

**Data Flow:**
```
1. Vendor Registration → vendorCategories stored (vendor-submitted)
   ↓
2. Admin Approval → allowedCategories set (admin-approved)
   ↓
3. Vendor Logs In → allowedCategories loaded from storage
   ↓
4. Feed Loads → Uses allowedCategories for marketplace matching
   ↓
5. Admin Updates → allowedCategories updated, vendor sees changes on next session
```

---

## CRITICAL FINDING: Category Source of Truth (RESOLVED)

### Problem Identified

**Location:** `lib/features/vendor/request_feed/providers/vendor_request_feed_provider.dart:87`

```dart
final categories = user.vendorCategories ?? [];
```

**Issue:** Using `vendorCategories` (VENDOR-SUBMITTED) instead of `allowedCategories` (ADMIN-APPROVED)

### Expected Behavior
- Admin-approved categories should be the source of truth after approval
- Vendor categories should be synced from admin-approved values
- When admin updates categories, vendor feed should immediately reflect changes

### Current Behavior
- Vendor feed uses stale vendor-submitted categories
- Admin category updates DO NOT immediately affect vendor's visible requests
- Vendor must log out and back in to see new categories

### Impact
- **Severity:** HIGH
- Vendor sees requests outside their admin-approved categories
- Admin category changes don't take immediate effect
- Potential data inconsistency across sessions

### Fix Required
Change line 87 to use admin-approved categories:
```dart
final categories = user.allowedCategories ?? user.vendorCategories ?? [];
```

---

## Audit Logging Framework

### 1. Request Creation Audit

**Log Tag:** `[RequestAudit]`

**Traces:**
- Request ID
- Customer Area / District
- Latitude / Longitude
- Item names and categories

**Location:** 
- `vendor_request_feed_provider.dart:143-148`

**Example Output:**
```
[RequestAudit] Total active requests: 5
[RequestAudit] request.id: REQ-001, area: Colombo 07, lat: 6.9064, lng: 79.8640
[RequestAudit] request.items: Milk, Bread, Butter
```

---

### 2. Category Synchronization Audit

**Log Tag:** `[CategoryAudit]`

**Traces:**
- Vendor submitted categories
- Vendor allowed categories (ADMIN-APPROVED)
- Request categories
- Category matching results

**Location:**
- `vendor_request_feed_provider.dart:90-92`
- `vendor_request_filter_service.dart:157`

**Example Output:**
```
[CategoryAudit] vendor.vendorSubmittedCategories: [Groceries, Electronics]
[CategoryAudit] vendor.allowedCategories: [Groceries]
[CategoryAudit] Using source: vendorCategories (SHOULD BE allowedCategories)
[CategoryAudit] request.id: REQ-001, categories: [Groceries], match: true
```

---

### 3. Feed Visibility Audit

**Log Tag:** `[FeedAudit]`

**Traces:**
- Total active requests evaluated
- Visibility decision (true/false)
- Reason if not visible (category_mismatch, outside_service_radius, etc.)
- Vendor approval status
- Shop location assignment status

**Location:**
- `vendor_request_feed_provider.dart:75-163`
- `vendor_request_filter_service.dart:150-212`

**Example Output:**
```
[FeedAudit] vendor.id: vendor-123
[FeedAudit] vendor.shopLatitude: 6.9064
[FeedAudit] vendor.shopLongitude: 79.8640
[FeedAudit] vendor.assignedRadiusKm: 20
[FeedAudit] evaluating 5 active requests
[FeedAudit] request: REQ-001, visible: true, distance: 0.5km
[FeedAudit] request: REQ-002, visible: false, reason: category_mismatch
[FeedAudit] request: REQ-003, visible: false, reason: outside_service_radius
```

---

### 4. Distance Filtering Audit

**Log Tag:** `[DistanceAudit]`

**Traces:**
- Request ID
- Calculated distance (km)
- Vendor's assigned service radius
- Distance match result (true/false)

**Location:**
- `vendor_request_filter_service.dart:172-179`

**Example Output:**
```
[DistanceAudit] request: REQ-001, distance: 0.5km, radius: 20km, match: true
[DistanceAudit] request: REQ-002, distance: 25.3km, radius: 20km, match: false
```

---

## Test Procedure

### To Run Full Audit

1. **Deploy Audit Logging**
   ```bash
   flutter run -d windows
   ```

2. **Create Test Data**
   - Register Vendor A with categories: [Groceries, Electronics]
   - Admin approves with categories: [Groceries]
   - Create 3 Customer Requests:
     - REQ-001: Groceries, 5km away
     - REQ-002: Electronics, 5km away
     - REQ-003: Groceries, 30km away

3. **Observe Logs**
   ```
   [RequestAudit] - Shows all requests created
   [CategoryAudit] - Shows vendor submitted vs approved categories
   [FeedAudit] - Shows visibility decisions
   [DistanceAudit] - Shows distance calculations
   ```

4. **Verify**
   - Vendor sees only Groceries requests (REQ-001, REQ-003)
   - REQ-002 (Electronics) is filtered out
   - REQ-003 (30km) is filtered out as outside radius

5. **Admin Updates Categories**
   - Add "Electronics" to vendor's approved categories
   - Refresh vendor request feed
   - Verify logs show updated categories
   - Verify vendor now sees REQ-002

---

## Current Test Status

| Component | Status | Evidence |
|-----------|--------|----------|
| Request Persistence | ✅ PASS | Requests persist in mock repository |
| Authentication | ✅ PASS | Vendor login/logout works |
| Router Navigation | ✅ PASS | Routes correctly to vendor dashboard |
| **Category Sync** | ❌ NEEDS FIX | Using vendorCategories, not allowedCategories |
| **Feed Visibility** | ⚠️ UNKNOWN | Audit logs will reveal |
| **Distance Filtering** | ⚠️ UNKNOWN | Audit logs will reveal |

---

## Known Issues

### Issue #1: Duplicate Shop Name Field (FIXED)
- ✅ Fixed - Single "Business / Shop Name" field now used

### Issue #2: Admin Category Update (IDENTIFIED)
- ❌ Still using vendorCategories instead of allowedCategories
- Admin changes don't immediately update vendor's visible requests

### Issue #3: Vendor Feed Caching
- ⚠️ Need to verify feed refreshes after admin category changes
- May need explicit reload trigger

---

## Next Steps

1. ✅ Deploy audit logging framework
2. 🔲 Run comprehensive test scenario
3. 🔲 Analyze logs for data flow issues
4. 🔲 Fix category source of truth issue
5. 🔲 Verify category changes propagate immediately
6. 🔲 Generate PASS/FAIL report with evidence

---

## Log Output Guide

When testing, watch for these patterns:

**GOOD:**
```
[FeedAudit] evaluating 5 active requests
[FeedAudit] request: REQ-001, visible: true, distance: 0.5km
[DistanceAudit] request: REQ-001, distance: 0.5km, radius: 20km, match: true
[CategoryAudit] request.id: REQ-001, categories: [Groceries], match: true
```

**BAD (Category Mismatch):**
```
[FeedAudit] request: REQ-002, visible: false, reason: category_mismatch
[CategoryAudit] request.id: REQ-002, categories: [Electronics], match: false
```

**BAD (Outside Radius):**
```
[FeedAudit] request: REQ-003, visible: false, reason: outside_service_radius
[DistanceAudit] request: REQ-003, distance: 30.0km, radius: 20km, match: false
```

---

## Files Modified

1. **vendor_request_feed_provider.dart**
   - Added `[FeedAudit]`, `[CategoryAudit]`, `[RequestAudit]` logs
   - Imported `flutter/foundation.dart` for debugPrint

2. **vendor_request_filter_service.dart**
   - Added `[CategoryAudit]`, `[DistanceAudit]`, `[FeedAudit]` logs
   - Imported `flutter/foundation.dart` for debugPrint
   - Enhanced buildFeed() with detailed decision logging

---

## Report Status

- ✅ Audit Framework: DEPLOYED
- 🔲 Data Collection: PENDING
- 🔲 Analysis: PENDING
- 🔲 PASS/FAIL: PENDING

Run test scenario and observe console logs to generate final audit report.
