# Category Audit - Quick Reference Guide

## How to Read the Logs

### Log Pattern to Look For

The audit logs follow a consistent pattern across 7 critical checkpoints:

```
[CategoryAudit] ===== CHECKPOINT NAME =====
[CategoryAudit] <specific data being traced>
[CategoryAudit] ===== CHECKPOINT COMPLETE =====
```

---

## The 7 Checkpoints

### ✅ Checkpoint 1: Admin UI Selection
```
[CategoryAudit] ===== ADMIN SAVE START =====
[CategoryAudit] Categories selected in UI: [electronics]
```
**What to verify**: Are the selected categories what you clicked in the UI?

---

### ✅ Checkpoint 2: Before Save
```
[CategoryAudit] Vendor current allowedCategories: [groceries]
[CategoryAudit] Categories before save: [electronics]
```
**What to verify**: Old vs New categories are clearly different

---

### ✅ Checkpoint 3: Auth Provider Receives Data
```
[CategoryAudit] ===== AUTH PROVIDER UPDATE START =====
[CategoryAudit] allowedCategories input: [electronics]
[CategoryAudit] Before copyWith: vendor.allowedCategories=[groceries]
[CategoryAudit] After copyWith: updatedVendor.allowedCategories=[electronics]
```
**⚠️ CRITICAL CHECK**: After copyWith should show ONLY new categories, not merged!

---

### ✅ Checkpoint 4: Repository Update
```
[CategoryAudit] ===== REPOSITORY UPDATE START =====
[CategoryAudit] user.allowedCategories being saved: [electronics]
[CategoryAudit] BEFORE update in _sessionUsers: [groceries]
[CategoryAudit] AFTER update in _sessionUsers: [electronics]
```
**What to verify**: In-memory data correctly replaced

---

### ✅ Checkpoint 5: Storage Serialization
```
[CategoryAudit] ===== STORAGE SERVICE SAVE START =====
[CategoryAudit] saveUser called with allowed_categories: [electronics]
```
**What to verify**: JSON has correct categories before write to disk

---

### ✅ Checkpoint 6: Vendor Login/Session Restore
```
[CategoryAudit] ===== VENDOR LOGIN RESTORE =====
[CategoryAudit] userJson allowed_categories: [electronics]
[CategoryAudit] user.allowedCategories: [electronics]
```
**What to verify**: Data loaded from storage matches what was saved

---

### ✅ Checkpoint 7: Feed Matching
```
[CategoryAudit] ===== CATEGORY AUDIT =====
[CategoryAudit] vendor.allowedCategories (admin-approved): [electronics]
[CategoryAudit] FINAL CATEGORIES USED IN FEED: [electronics]
```
**What to verify**: Feed uses correct source of truth (allowedCategories, not vendorCategories)

---

## Quick Diagnosis

### ✅ PASS: Categories Replaced Correctly
Every checkpoint shows `[electronics]` after the change:
```
Checkpoint 1: [electronics] ✓
Checkpoint 3: [electronics] ✓
Checkpoint 4: [electronics] ✓
Checkpoint 5: [electronics] ✓
Checkpoint 6: [electronics] ✓
Checkpoint 7: [electronics] ✓
```

### ❌ FAIL: Categories Appended (Bug)
Any checkpoint shows `[groceries, electronics]`:
```
Checkpoint 3: [groceries, electronics] ✗ ← ROOT CAUSE: copyWith merging lists
```

### ❌ FAIL: Wrong Source of Truth
Feed uses vendorCategories instead of allowedCategories:
```
Checkpoint 7: FINAL CATEGORIES USED: vendorCategories ✗ ← BUG: Wrong field
```

---

## Common Issues and Their Signatures

### Issue 1: UI State Mutation
```
Checkpoint 1: [groceries, electronics]  ← Bug is HERE
Checkpoint 2: [groceries, electronics]
```
**Diagnosis**: `_selectedCategories` is being mutated with old values
**Fix**: Ensure `_selectedCategories` is initialized as a fresh list

---

### Issue 2: copyWith Merging
```
Checkpoint 3: Before copyWith: [groceries]
Checkpoint 3: After copyWith: [groceries, electronics]  ← Bug is HERE
```
**Diagnosis**: `UserModel.copyWith()` is appending instead of replacing
**Fix**: Check copyWith implementation or how allowedCategories is passed

---

### Issue 3: Storage Corruption
```
Checkpoint 5: [electronics]  ← Correct here
Checkpoint 6: [groceries, electronics]  ← Bug is HERE
```
**Diagnosis**: Serialization or deserialization merging data
**Fix**: Check `toJson()` and `fromJson()` in UserModel

---

### Issue 4: Wrong Field Used in Feed
```
Checkpoint 6: user.allowedCategories: [electronics]
Checkpoint 7: FINAL CATEGORIES USED: [groceries]  ← Bug is HERE
```
**Diagnosis**: Feed is reading `vendorCategories` instead of `allowedCategories`
**Fix**: Update feed provider to use correct field

---

## Testing Checklist

- [ ] Start with vendor having `[groceries]`
- [ ] Admin changes to `[electronics]`
- [ ] Checkpoint 1: UI shows `[electronics]` only
- [ ] Checkpoint 3: copyWith produces `[electronics]` only
- [ ] Checkpoint 5: Storage gets `[electronics]` only
- [ ] Checkpoint 6: Restore loads `[electronics]` only
- [ ] Checkpoint 7: Feed uses `[electronics]` only
- [ ] Vendor sees only electronics requests (not groceries)

---

## Expected Full Trace (Success)

```
[CategoryAudit] ===== ADMIN SAVE START =====
[CategoryAudit] Categories selected in UI: [electronics]
[CategoryAudit] Vendor current allowedCategories: [groceries]

[CategoryAudit] ===== AUTH PROVIDER UPDATE START =====
[CategoryAudit] allowedCategories input: [electronics]
[CategoryAudit] Before copyWith: vendor.allowedCategories=[groceries]
[CategoryAudit] After copyWith: updatedVendor.allowedCategories=[electronics]
[CategoryAudit] User JSON toJson: allowed_categories=[electronics]

[CategoryAudit] ===== REPOSITORY UPDATE START =====
[CategoryAudit] user.allowedCategories being saved: [electronics]
[CategoryAudit] BEFORE update: [groceries]
[CategoryAudit] AFTER update: [electronics]
[CategoryAudit] ===== REPOSITORY UPDATE COMPLETE =====

[CategoryAudit] ===== STORAGE SERVICE SAVE START =====
[CategoryAudit] saveUser called with allowed_categories: [electronics]
[CategoryAudit] ===== STORAGE SERVICE SAVE COMPLETE =====

[CategoryAudit] ===== VENDOR LOGIN RESTORE =====
[CategoryAudit] userJson allowed_categories: [electronics]
[CategoryAudit] user.allowedCategories: [electronics]
[CategoryAudit] ===== SESSION RESTORED =====

[CategoryAudit] ===== CATEGORY AUDIT =====
[CategoryAudit] vendor.allowedCategories (admin-approved): [electronics]
[CategoryAudit] FINAL CATEGORIES USED IN FEED: [electronics]
```

---

## Next Steps

1. Run the app
2. Follow testing instructions in CATEGORY_PERSISTENCE_AUDIT.md
3. Collect the logs from Debug Console
4. Compare against expected trace above
5. Identify which checkpoint shows incorrect behavior
6. Report finding BEFORE making any fixes
