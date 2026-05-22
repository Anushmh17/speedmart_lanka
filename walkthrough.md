# STEP 3 — Customer Registration System: Walkthrough

## What Was Built

A complete, production-ready customer registration flow for Speedmart Lanka, fully country-aware, with clean architecture and a mock OTP system ready for real Notify.lk integration.

---

## File Structure Created

```
lib/features/auth/customer_registration/
├── models/
│   ├── customer_registration_data.dart   ← immutable form state, copyWith
│   └── registration_step.dart            ← enum: details | sendingOtp | verifyOtp | success
├── services/
│   ├── country_detection_service.dart    ← GPS bounding box + locale + fallback
│   ├── otp_service.dart                  ← abstract OtpService + MockOtpService
│   └── notify_lk_service.dart            ← placeholder with integration guide
├── providers/
│   └── customer_registration_provider.dart ← StateNotifier, full flow machine
├── widgets/
│   ├── registration_header.dart          ← animated gradient header + step dots
│   ├── registration_section_card.dart    ← grouped section card with accent
│   ├── nic_input_field.dart              ← NIC with old/new format detection
│   └── phone_field_lk.dart              ← +94 chip phone input
└── screens/
    ├── customer_registration_screen.dart  ← 3-section animated form
    └── otp_verification_screen.dart       ← 6-box OTP + resend timer + success overlay
```

---

## Files Modified

| File | Change |
|------|--------|
| `core/utils/validators.dart` | Added `Validators.nic()` supporting old (9V/X) and new (12-digit) NIC |
| `core/routes/route_names.dart` | Added `customerRegister` and `customerRegisterOtp` routes |
| `core/routes/app_router.dart` | Imported new screens, registered 2 routes, expanded `isOnAuthRoute` guard |
| `features/auth/presentation/screens/login_screen.dart` | Customer "Sign Up" now navigates to `customerRegister`; vendor/admin still use generic `register` |

---

## Flow Walkthrough

### Step 1 — Form (CustomerRegistrationScreen)
- On mount: `CountryDetectionService.detect()` runs silently
  - GPS bounding box check for Sri Lanka (5.9°N–9.9°N, 79.6°E–81.9°E)
  - Device locale fallback (`si`, `_LK`)
  - Defaults to Sri Lanka if undetermined
- **Sri Lankan user** sees: Phone field (+94 chip), NIC field (old/new auto-detect)
- **International user** sees: Email field, optional phone
- Both flows show: Province dropdown → District dropdown (filtered), Approx area, Precise address, Optional note
- **Auto Detect** button in the delivery section triggers GPS → reverse geocode → auto-fills province, district, area
- Form validates: name, phone/NIC or email, province, district, approx area, precise address

### Step 2 — OTP Sending
- "Continue" validates the full form, updates provider state, calls `MockOtpService.sendOtp()`
- 1.5-second artificial delay simulates network
- Provider advances to `RegistrationStep.verifyOtp`
- Router `push`es to `/auth/customer/register/otp`

### Step 3 — OTP Verification (OtpVerificationScreen)
- 6 individual text boxes with auto-focus progression
- Typing the 6th digit auto-triggers verification
- 60-second countdown timer before "Resend OTP" becomes active
- Dev mode banner shows mock code `123456`
- On success: `elasticOut` scale + fade animation → 800ms pause → `go(customerHome)`
- On failure: boxes clear, error message shown, refocus box 1

---

## Key Design Decisions

- **Standalone province/district state** — the registration screen manages its own `_selectedProvince`/`_selectedDistrict` separately from the global `locationProvider`, avoiding cross-screen state pollution.
- **`context.push` for OTP** — preserves back stack so "← Back" on OTP screen returns to registration details.
- **Mock OTP is injectable** — `otpServiceProvider` returns `MockOtpService`. Swap to `NotifyLkOtpService` without any screen changes.
- **Pre-existing generic `RegisterScreen`** — kept completely untouched for vendor/admin use. Customers get the richer dedicated flow.

---

## OTP Integration Checklist (Future)

When integrating real Notify.lk:
1. Implement `NotifyLkService.sendSms()` with your API key
2. Create `NotifyLkOtpService implements OtpService`
3. Swap `otpServiceProvider` in `customer_registration_provider.dart`
4. Add a backend endpoint for OTP storage + expiry verification
5. Remove the dev hint banner from `OtpVerificationScreen`

---

## Validation Results

```
flutter analyze lib/features/auth/customer_registration/ \
               lib/core/routes/ lib/core/utils/validators.dart

→ 1 issue found (pre-existing lint in app_router.dart:39, not introduced by this task)
→ 0 errors, 0 warnings, 0 new infos in any new files
```
