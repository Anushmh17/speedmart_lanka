# Log Collection Script

## Step-by-Step Test Execution

Copy this checklist and fill in the actual log outputs as you perform each step.

---

## Setup
- [ ] App restarted
- [ ] Debug console cleared
- [ ] Ready to collect logs

---

## Test Scenario: Change Groceries → Electronics

### STEP 1: Login as Admin
```
User: admin@speedmart.lk
Pass: admin123
```

---

### STEP 2: Navigate to Vendor Assignment
1. Go to Vendor Management
2. Select vendor: **Kamal Silva** (vendor@test.com)
3. Current categories should show: `[groceries, home appliances]`

---

### STEP 3: Change Categories
1. **UNCHECK**: Groceries
2. **UNCHECK**: Home Appliances  
3. **CHECK**: Electronics
4. Click "Save Assignment"

---

### STEP 4: Collect Admin Save Logs

Look for these logs in Debug Console:

#### Checkpoint 1: Admin UI Selection
```
PASTE LOG OUTPUT HERE:
[CategoryAudit] ===== ADMIN SAVE START =====
[CategoryAudit] Categories selected in UI: ???
[CategoryAudit] Vendor current allowedCategories: ???
```

**Analysis**: 
- Selected categories = ______________
- Previous categories = ______________
- Are they correctly different? YES / NO

---

#### Checkpoint 2: Auth Provider Update
```
PASTE LOG OUTPUT HERE:
[CategoryAudit] ===== AUTH PROVIDER UPDATE START =====
[CategoryAudit] allowedCategories input: ???
[CategoryAudit] Before copyWith: ???
[CategoryAudit] After copyWith: ???
```

**Analysis**:
- Input = ______________
- Before copyWith = ______________
- After copyWith = ______________
- ⚠️ Did categories get merged? YES / NO

---

#### Checkpoint 3: Repository Update
```
PASTE LOG OUTPUT HERE:
[CategoryAudit] ===== REPOSITORY UPDATE START =====
[CategoryAudit] user.allowedCategories being saved: ???
[CategoryAudit] BEFORE update in _sessionUsers: ???
[CategoryAudit] AFTER update in _sessionUsers: ???
```

**Analysis**:
- Categories being saved = ______________
- Before in memory = ______________
- After in memory = ______________

---

#### Checkpoint 4: Storage Save
```
PASTE LOG OUTPUT HERE:
[CategoryAudit] ===== STORAGE SERVICE SAVE START =====
[CategoryAudit] saveUser called with allowed_categories: ???
```

**Analysis**:
- Categories persisted to storage = ______________

---

### STEP 5: Logout Admin
```
PASTE LOG OUTPUT HERE:
(Any relevant logout logs)
```

---

### STEP 6: Login as Vendor
```
User: vendor@test.com
Pass: vendor123
```

---

### STEP 7: Collect Vendor Login Logs

#### Checkpoint 5: Session Restore
```
PASTE LOG OUTPUT HERE:
[CategoryAudit] ===== VENDOR LOGIN RESTORE =====
[CategoryAudit] userJson allowed_categories: ???
[CategoryAudit] user.allowedCategories: ???
```

**Analysis**:
- Loaded from storage = ______________
- Deserialized UserModel = ______________
- Do they match what was saved? YES / NO

---

### STEP 8: Navigate to Request Feed

#### Checkpoint 6: Feed Load
```
PASTE LOG OUTPUT HERE:
[CategoryAudit] ===== CATEGORY AUDIT =====
[CategoryAudit] vendor.allowedCategories (admin-approved): ???
[CategoryAudit] vendor.vendorCategories (vendor-submitted): ???
[CategoryAudit] FINAL CATEGORIES USED IN FEED: ???
```

**Analysis**:
- allowedCategories = ______________
- vendorCategories = ______________
- FINAL USED = ______________
- Which field is being used? allowedCategories / vendorCategories

---

### STEP 9: Visual Verification

Check what requests are visible in the feed:

```
Visible Requests:
1. Request ID: ______ Category: ______
2. Request ID: ______ Category: ______
3. Request ID: ______ Category: ______
```

**Expected**: Only electronics requests visible
**Actual**: ______________________

---

## Root Cause Determination

Based on the logs collected above, identify where the issue occurs:

### Option A: UI State Mutation ❌
```
Checkpoint 1 shows: [groceries, electronics]
```
→ Bug is in admin_vendor_assignment_screen.dart

### Option B: copyWith Merging ❌
```
Checkpoint 2 "Before copyWith": [groceries]
Checkpoint 2 "After copyWith": [groceries, electronics]
```
→ Bug is in UserModel.copyWith() or how it's called

### Option C: Storage Corruption ❌
```
Checkpoint 4 save: [electronics]
Checkpoint 5 load: [groceries, electronics]
```
→ Bug is in toJson() / fromJson() or storage service

### Option D: Wrong Field Used ❌
```
Checkpoint 6 allowedCategories: [electronics]
Checkpoint 6 FINAL USED: [groceries]
```
→ Bug is in vendor_request_feed_provider.dart (using wrong field)

### Option E: Everything Works ✅
```
All checkpoints show: [electronics]
Feed shows: Only electronics requests
```
→ No bug, categories correctly replaced

---

## My Diagnosis

**Root Cause Location**: _______________________

**Root Cause Description**: _______________________

**Evidence**: _______________________

---

## Next Steps

1. ✅ Logs collected
2. ✅ Root cause identified
3. ⏸️ STOP - Do not modify code yet
4. ⏸️ Report findings to team
5. ⏸️ Wait for fix approval
