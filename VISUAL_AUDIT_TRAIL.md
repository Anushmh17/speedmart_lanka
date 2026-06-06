# Category Persistence Flow - Visual Audit Trail

## Complete Data Flow: Admin Save → Storage → Vendor Login → Feed

```
┌─────────────────────────────────────────────────────────────────────┐
│                         ADMIN SAVES CATEGORIES                       │
└─────────────────────────────────────────────────────────────────────┘
                                  │
                                  │ [electronics]
                                  ▼
┌─────────────────────────────────────────────────────────────────────┐
│ ✓ CHECKPOINT 1: Admin UI Selection                                  │
│   File: admin_vendor_assignment_screen.dart                         │
│   Method: _saveAssignment()                                         │
│                                                                       │
│   Log: [CategoryAudit] Categories selected in UI: [electronics]    │
│   Log: [CategoryAudit] Vendor current: [groceries]                 │
│                                                                       │
│   VERIFY: UI selection is [electronics] ONLY                        │
└─────────────────────────────────────────────────────────────────────┘
                                  │
                                  │ allowedCategories: [electronics]
                                  ▼
┌─────────────────────────────────────────────────────────────────────┐
│ ✓ CHECKPOINT 2: Auth Provider Input                                 │
│   File: auth_provider.dart                                          │
│   Method: updateVendorShopAssignment()                              │
│                                                                       │
│   Log: [CategoryAudit] allowedCategories input: [electronics]      │
│                                                                       │
│   VERIFY: Parameter received is [electronics]                       │
└─────────────────────────────────────────────────────────────────────┘
                                  │
                                  │ Get vendor from repository
                                  ▼
┌─────────────────────────────────────────────────────────────────────┐
│ ⚠️  CHECKPOINT 3: copyWith() Operation  ⚠️                           │
│   File: auth_provider.dart + user_model.dart                        │
│   Method: vendor.copyWith()                                         │
│                                                                       │
│   Log: [CategoryAudit] Before copyWith: [groceries]                │
│   Log: [CategoryAudit] After copyWith: ???                         │
│                                                                       │
│   CRITICAL CHECK:                                                    │
│   ✅ PASS: After = [electronics]          (REPLACE)                 │
│   ❌ FAIL: After = [groceries, electronics] (APPEND - BUG!)         │
└─────────────────────────────────────────────────────────────────────┘
                                  │
                                  │ updatedVendor object
                                  ▼
┌─────────────────────────────────────────────────────────────────────┐
│ ✓ CHECKPOINT 4: Repository Update                                   │
│   File: mock_auth_repository.dart                                   │
│   Method: updateUser()                                              │
│                                                                       │
│   Log: [CategoryAudit] user.allowedCategories: [electronics]       │
│   Log: [CategoryAudit] BEFORE in _sessionUsers: [groceries]        │
│   Log: [CategoryAudit] AFTER in _sessionUsers: ???                 │
│                                                                       │
│   VERIFY: In-memory data updated correctly                          │
└─────────────────────────────────────────────────────────────────────┘
                                  │
                                  │ user.toJson()
                                  ▼
┌─────────────────────────────────────────────────────────────────────┐
│ ✓ CHECKPOINT 5: Storage Serialization                               │
│   File: storage_service.dart                                        │
│   Method: saveUser()                                                │
│                                                                       │
│   Log: [CategoryAudit] allowed_categories: [electronics]           │
│                                                                       │
│   VERIFY: JSON serialization preserves category list                │
└─────────────────────────────────────────────────────────────────────┘
                                  │
                                  │ jsonEncode() → Secure Storage
                                  │
                       ┌──────────┴──────────┐
                       │  SECURE STORAGE     │
                       │  Flutter Keychain   │
                       └──────────┬──────────┘
                                  │
                                  │ (Time passes)
                                  │ (Vendor logs in)
                                  │
┌─────────────────────────────────────────────────────────────────────┐
│                      VENDOR LOGS IN                                  │
└─────────────────────────────────────────────────────────────────────┘
                                  │
                                  │ Load from storage
                                  ▼
┌─────────────────────────────────────────────────────────────────────┐
│ ✓ CHECKPOINT 6: Session Restore                                     │
│   File: auth_provider.dart                                          │
│   Method: _restoreSession()                                         │
│                                                                       │
│   Log: [CategoryAudit] userJson allowed_categories: ???            │
│   Log: [CategoryAudit] user.allowedCategories: ???                 │
│                                                                       │
│   VERIFY: Loaded data matches what was saved                        │
└─────────────────────────────────────────────────────────────────────┘
                                  │
                                  │ UserModel.fromJson()
                                  │
                       ┌──────────┴──────────┐
                       │  AUTHENTICATED USER │
                       │  State Updated      │
                       └──────────┬──────────┘
                                  │
                                  │ Vendor opens feed
                                  ▼
┌─────────────────────────────────────────────────────────────────────┐
│ ⚠️  CHECKPOINT 7: Feed Matching  ⚠️                                  │
│   File: vendor_request_feed_provider.dart                           │
│   Method: loadFeed()                                                │
│                                                                       │
│   Log: [CategoryAudit] vendor.allowedCategories: ???               │
│   Log: [CategoryAudit] vendor.vendorCategories: ???                │
│   Log: [CategoryAudit] FINAL CATEGORIES USED: ???                  │
│                                                                       │
│   CRITICAL CHECK:                                                    │
│   ✅ PASS: Uses allowedCategories [electronics]                     │
│   ❌ FAIL: Uses vendorCategories [groceries]                        │
│                                                                       │
│   RESULT: Only electronics requests visible in feed                 │
└─────────────────────────────────────────────────────────────────────┘
                                  │
                                  │ Filtered requests
                                  ▼
                         ┌────────────────┐
                         │  VENDOR FEED   │
                         │  UI Display    │
                         └────────────────┘
```

---

## Data Integrity Verification

At each stage, the category list should be:

```
Stage 1 (Admin UI):          [electronics]
Stage 2 (Auth Provider):     [electronics]
Stage 3 (copyWith):          [electronics]  ← MOST LIKELY BUG POINT
Stage 4 (Repository):        [electronics]
Stage 5 (Storage Write):     [electronics]
Stage 6 (Storage Read):      [electronics]
Stage 7 (Feed Logic):        [electronics]
```

---

## Replace vs Append Behavior

### ✅ CORRECT: Replace Behavior
```
Before: vendor.allowedCategories = [groceries, home appliances]
Admin selects: [electronics]
After:  vendor.allowedCategories = [electronics]
```

### ❌ INCORRECT: Append Behavior (Bug)
```
Before: vendor.allowedCategories = [groceries, home appliances]
Admin selects: [electronics]
After:  vendor.allowedCategories = [groceries, home appliances, electronics]
```

---

## Source of Truth

### Two Category Fields in UserModel:

```
┌─────────────────────────────────────────────────────────────────┐
│ vendorCategories                                                 │
│ - Vendor-submitted during registration                          │
│ - Never updated after approval                                  │
│ - Example: [groceries, home appliances]                         │
│ - USE: Display only, not for matching                           │
└─────────────────────────────────────────────────────────────────┘

┌─────────────────────────────────────────────────────────────────┐
│ allowedCategories  ← SOURCE OF TRUTH                             │
│ - Admin-approved categories                                      │
│ - Updated by admin via assignment screen                         │
│ - Example: [electronics]                                         │
│ - USE: Feed matching, proposal filtering                         │
└─────────────────────────────────────────────────────────────────┘
```

### Feed Logic:
```dart
final allowedCategories = user.allowedCategories ?? user.vendorCategories ?? [];
```

**Correct**: Uses `allowedCategories` first (admin-approved)
**Fallback**: Uses `vendorCategories` if allowedCategories is null

---

## Common Bug Patterns

### Pattern 1: UI State Preservation
```dart
// WRONG: Preserves old categories
_selectedCategories = widget.vendor.vendorCategories;

// CORRECT: Uses admin-approved categories
_selectedCategories = List<String>.from(widget.vendor.allowedCategories ?? []);
```

### Pattern 2: List Mutation
```dart
// WRONG: Mutates existing list
_selectedCategories.addAll(newCategories);

// CORRECT: Replaces list
_selectedCategories = List<String>.from(newCategories);
```

### Pattern 3: Empty List Handling
```dart
// POTENTIAL BUG: Empty list treated as null?
allowedCategories: [] ?? this.allowedCategories  // Returns []

// CORRECT: Should replace with empty list
allowedCategories: [] // Vendor has no allowed categories
```

---

## Test Execution Flowchart

```
START
  │
  ├─→ Login as Admin
  │
  ├─→ Navigate to Vendor (Kamal Silva)
  │
  ├─→ Current: [groceries, home appliances]
  │
  ├─→ Change to: [electronics]
  │
  ├─→ Save
  │
  ├─→ Collect Checkpoints 1-5 logs
  │
  ├─→ Logout Admin
  │
  ├─→ Login as Vendor
  │
  ├─→ Collect Checkpoint 6 logs
  │
  ├─→ Open Request Feed
  │
  ├─→ Collect Checkpoint 7 logs
  │
  ├─→ Verify visible requests
  │
  ├─→ PASS: Only electronics
  │   FAIL: Groceries still visible
  │
END
```

---

## Debugging Decision Tree

```
Is Checkpoint 1 wrong?
│
├─→ YES: Bug in admin_vendor_assignment_screen.dart
│         Check: _selectedCategories initialization
│
└─→ NO: Is Checkpoint 3 wrong?
        │
        ├─→ YES: Bug in UserModel.copyWith()
        │         Check: How allowedCategories parameter is handled
        │
        └─→ NO: Is Checkpoint 6 wrong?
                │
                ├─→ YES: Bug in storage serialization
                │         Check: toJson() / fromJson()
                │
                └─→ NO: Is Checkpoint 7 using wrong field?
                        │
                        ├─→ YES: Bug in vendor_request_feed_provider.dart
                        │         Check: Which field is being used
                        │
                        └─→ NO: Bug is elsewhere or no bug exists
```

---

## Summary

- 7 checkpoints instrumented
- Full trace from Admin → Storage → Vendor → Feed
- Replace vs Append verification at each stage
- Source of truth verification in feed
- Visual flow shows exact data path
- Decision tree for root cause identification

Execute test and collect logs to complete the audit.
