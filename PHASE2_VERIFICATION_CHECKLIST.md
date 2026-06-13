# PHASE 2 MANUAL VERIFICATION CHECKLIST

## IMPORTANT: Visual Verification Required

Since automated screenshot capture is not available, please manually verify each item below by running the app.

---

## 1. PROFILE SCREEN VERIFICATION

### Navigation Test:
1. ✅ Launch app as customer
2. ✅ Navigate to Profile tab
3. ✅ Press back button
4. ✅ **VERIFY**: Returns to Home screen (NOT app exit)

### Layout Verification:
**Header Section:**
- [ ] Profile avatar displays
- [ ] User name displays
- [ ] User email displays  
- [ ] Verified/Pending badge (if vendor)

**Quick Stats Section:**
- [ ] Section title: "Quick Stats"
- [ ] 3 columns displayed horizontally:
  - Requests | Active | Completed
- [ ] Each stat card has: icon, number value, label
- [ ] Cards use Theme3AppCard styling

**Account Section:**
- [ ] Section title: "Account"
- [ ] Menu items in single card:
  - [ ] "Personal Information" → Opens edit mode
  - [ ] "Delivery Address" → Navigates to delivery address screen
  - [ ] "Notifications" (placeholder)
  - [ ] "Payment Methods" (placeholder)
- [ ] Each item has: icon (left), label (center), chevron (right)
- [ ] Items have dividers between them

**Support Section:**
- [ ] Section title: "Support"
- [ ] Menu items in single card:
  - [ ] "Help Center"
  - [ ] "Contact Support"
  - [ ] "About App"
- [ ] Chevron icons on right side

**Danger Zone:**
- [ ] Only "Logout" button visible
- [ ] Red danger styling
- [ ] Logout icon present

### CRITICAL VERIFICATION - Location Controls REMOVED:
- [ ] ❌ NO "Edit Location" button on profile
- [ ] ❌ NO "Detect Again" button on profile
- [ ] ❌ NO "View Saved Location" button on profile
- [ ] ✅ ONLY "Delivery Address" menu item that navigates away

**Result**: Profile is clean, organized, with location controls moved to dedicated screen

---

## 2. DELIVERY ADDRESS SCREEN VERIFICATION

### Navigation Test:
1. ✅ From Profile → Tap "Delivery Address"
2. ✅ **VERIFY**: Navigates to new screen (not inline edit)
3. ✅ Screen title: "Delivery Address"

### Layout Verification:
**Header:**
- [ ] Title: "Manage Delivery Address"
- [ ] Subtitle: "Vendors see only your approximate area until order confirmation"

**Current Address Card:**
- [ ] Elevated card style (visible shadow)
- [ ] Location icon (orange) + "Current Address" title
- [ ] Form fields inside card:
  - Province dropdown
  - District dropdown
  - Approximate Area text
  - Street Address (optional)
- [ ] Card has golden/light border (Theme3 style)

**GPS Status Card (if coordinates exist):**
- [ ] Green success icon (gps_fixed_rounded)
- [ ] Text: "GPS Detected"
- [ ] Subtitle: "Location verified successfully"
- [ ] Green background tint

**Map Picker Card:**
- [ ] Card with "Pin Location on Map" title
- [ ] Map widget inside card
- [ ] Can drag/pin location

**Save Button:**
- [ ] Theme3AppButton styling
- [ ] Label: "Save Changes"
- [ ] Check icon present
- [ ] Orange primary color
- [ ] Full width

**Visual Quality:**
- [ ] Cards have visible shadows (not flat)
- [ ] Golden borders visible on cards
- [ ] Good spacing between sections
- [ ] Premium/polished appearance

---

## 3. ORDERS SCREEN VERIFICATION

### Navigation Test:
1. ✅ Navigate to Orders tab
2. ✅ Press back button
3. ✅ **VERIFY**: Returns to Home screen (NOT app exit)

### Layout Verification:
**Header:**
- [ ] Title: "My Orders" (not "My Active Orders")

**Order Cards (if orders exist):**
Each card should have marketplace-style layout:

**LEFT SIDE (Thumbnail):**
- [ ] 56x56 icon container
- [ ] Background color matches order status:
  - Accepted: Blue
  - Preparing: Purple  
  - Out for Delivery: Green
  - Delivered: Dark Green
  - Cancelled: Red
- [ ] Shopping bag icon inside
- [ ] Rounded corners (12px radius)

**CENTER COLUMN:**
- [ ] Order number: "Order #12345678"
- [ ] Vendor name below number
- [ ] Status chip (inline, not separate component):
  - Same color as thumbnail background
  - Text displays status
  - Pill shape

**RIGHT COLUMN:**
- [ ] Total price (Rs. XX.XX) in orange
- [ ] Payment method below price (COD/CARD)

**Overall Card:**
- [ ] White background (or dark in dark mode)
- [ ] Visible shadow
- [ ] Good spacing between elements
- [ ] Tap opens order tracking

**Empty State:**
- [ ] Icon: shopping_bag_outlined
- [ ] Title: "No Orders Yet"
- [ ] Subtitle: "Your orders will appear here."

**Visual Quality:**
- [ ] Cards look like marketplace/e-commerce app
- [ ] Status colors are vibrant and clear
- [ ] NOT plain list items
- [ ] Professional appearance

---

## 4. HOME SCREEN POLISH VERIFICATION

### Theme 3 Enhancements:
**Card Visibility:**
- [ ] Cards have visible shadows (not flat/washed out)
- [ ] Golden borders visible on cards
- [ ] Good contrast between background and cards

**Recent Requests Section:**
Each request card should have:
- [ ] LEFT: 64x64 category icon thumbnail (orange tint background)
- [ ] CENTER: 
  - Item name
  - Category label (uppercase)
  - Proposal count with icon
- [ ] RIGHT:
  - Status chip
  - Time ago (e.g., "2h ago")
- [ ] Card has visible shadow

**Vendor Activity Banner:**
- [ ] Shows between hero card and quick actions
- [ ] 3 overlapping avatar circles (store, truck, bag icons)
- [ ] Text: "200+ Active Vendors Nearby"
- [ ] Subtitle: "Ready to fulfill your requests"

**Recent Orders Section:**
- [ ] Orders display with thumbnails (if Phase 1 complete)
- [ ] Cards have shadows
- [ ] Track button visible

**Visual Quality:**
- [ ] Light theme has good contrast (not washed out)
- [ ] Cards stand out from background
- [ ] Borders are visible (golden tint)
- [ ] Shadows make cards pop
- [ ] Overall premium appearance

---

## 5. NAVIGATION BEHAVIOR VERIFICATION

### Home Screen Exit:
1. ✅ Go to Home tab
2. ✅ Press back button ONCE
3. ✅ **VERIFY**: Snackbar appears: "Swipe back again to exit"
4. ✅ Wait 3 seconds (snackbar disappears)
5. ✅ Press back again within 2 seconds
6. ✅ **VERIFY**: App exits

**Expected**: Double-back with 2-second window + snackbar notification

### Orders Screen Back:
1. ✅ Go to Orders tab
2. ✅ Press back button
3. ✅ **VERIFY**: Returns to Home tab
4. ✅ **VERIFY**: App does NOT exit
5. ✅ **VERIFY**: Home tab is active

### Profile Screen Back:
1. ✅ Go to Profile tab
2. ✅ Press back button
3. ✅ **VERIFY**: Returns to Home tab
4. ✅ **VERIFY**: App does NOT exit
5. ✅ **VERIFY**: Home tab is active

### Delivery Address Back:
1. ✅ Go to Profile → Delivery Address
2. ✅ Press back button
3. ✅ **VERIFY**: Returns to Profile screen
4. ✅ **VERIFY**: Profile tab remains active

---

## 6. CODE VERIFICATION (Completed)

✅ **Flutter Analyze**: No errors (186 info warnings about deprecations - acceptable)
✅ **Modified Files**: 3 files changed
✅ **Business Logic**: ZERO changes to repos/providers
✅ **Build Status**: Compiles successfully

---

## 7. REMAINING WORK (NOT IN PHASE 2)

❌ **Save Draft UX**: Bottom sheet redesign
❌ **Single Request Screen**: Horizontal category chips
❌ **Multiple Request Screen**: Shopping list UI
❌ **Category Warnings**: Cleanup alias logging

These will be Phase 3 tasks.

---

## VERIFICATION SUMMARY

### To Mark Phase 2 Complete, Verify:

**Profile Screen:**
- [ ] Back returns to home
- [ ] Quick stats in 3-column row
- [ ] Account/Support sections organized
- [ ] Delivery Address as menu item
- [ ] NO location controls on main screen

**Delivery Address Screen:**
- [ ] Premium card layout
- [ ] GPS status indicator
- [ ] Theme3 styling with shadows/borders
- [ ] Save button with icon

**Orders Screen:**
- [ ] Back returns to home
- [ ] Marketplace-style cards
- [ ] Status-colored thumbnails
- [ ] Clean information hierarchy

**Home Screen:**
- [ ] Better shadows and contrast
- [ ] Request cards with thumbnails
- [ ] Vendor activity banner
- [ ] Premium appearance

**Navigation:**
- [ ] Home: double-back to exit
- [ ] Orders: back to home
- [ ] Profile: back to home

---

## SCREENSHOTS TO PROVIDE

Please capture and share:
1. Profile Screen - main view
2. Profile Screen - Account section showing Delivery Address menu item
3. Delivery Address Screen - full view
4. Delivery Address Screen - GPS status card (if GPS detected)
5. Orders Screen - with order cards visible
6. Home Screen - showing enhanced cards and shadows
7. Home Screen - Recent Requests with thumbnails
8. Navigation test - Orders back button behavior
9. Navigation test - Profile back button behavior

---

## MANUAL TEST EXECUTION

Run the app and go through each verification item above.
Mark [ ] as [✅] when verified.
Mark [ ] as [❌] if issue found.

Report any discrepancies between expected and actual behavior.

---

**Next Step**: Provide test results and screenshots, then we can proceed to Phase 3.
