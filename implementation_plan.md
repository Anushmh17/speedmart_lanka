# Fix Customer Home Navigation State and Android Back Behavior

This implementation plan outlines the steps to address:
1. Bottom navigation bar visibility/state issues after submitting or exiting a shopping request.
2. Double-back-to-exit gesture logic on the Customer Home page.

## Proposed Changes

### Requests Feature

#### [MODIFY] [create_request_screen.dart](file:///c:/App_developments/speedmart_lanka/lib/features/requests/presentation/screens/create_request_screen.dart)

- In `_submitRequest()`, change `context.pop()` to `context.go(RouteNames.customerHome)` to ensure GoRouter's route state is correctly updated to `/customer` on submission.
- In `_confirmPop()`, change all occurrences of `context.pop()` to `context.go(RouteNames.customerHome)` to ensure correct state updates and visibility when cancel/discard is selected.

---

### Customer Feature

#### [MODIFY] [customer_home_screen.dart](file:///c:/App_developments/speedmart_lanka/lib/features/customer/presentation/screens/customer_home_screen.dart)

- Import `package:flutter/services.dart` to access `SystemNavigator.pop()`.
- Declare `DateTime? _lastBackPressTime;` in `_CustomerHomeScreenState`.
- Wrap the main `Scaffold` in a `PopScope` with `canPop: false`.
- In `onPopInvokedWithResult`:
  - If `currentIndex != 0`, navigate to `RouteNames.customerHome` (switching tabs back to Home first).
  - If `currentIndex == 0`, implement the double-press check:
    - If `_lastBackPressTime` is null or the time difference is greater than 2 seconds, show the SnackBar: `"Swipe back again to exit"`.
    - Otherwise, call `SystemNavigator.pop()`.

## Verification Plan

### Automated Tests
- Run `flutter analyze` to ensure zero static analysis or compile errors.

### Manual Verification
1. **Submit Request Flow:** Create a shopping request, submit it, and verify that the app returns to the Customer Home Screen (Home tab selected) and the bottom navigation bar is visible and correctly styled.
2. **Exit Request Flow:** Open the Create Shopping Request screen, press back (top-left or Android swipe), select save/discard, and verify that the bottom navigation bar is restored correctly.
3. **Double Back to Exit:**
   - On the Customer Home Screen, press back on a non-Home tab (e.g. Orders) and verify it switches back to the Home tab.
   - On the Home tab, swipe back once and verify the SnackBar `"Swipe back again to exit"` is shown.
   - Swipe back again within 2 seconds and verify the app exits.
   - Swipe back once, wait > 2 seconds, swipe again, and verify the SnackBar is shown again instead of exiting.
