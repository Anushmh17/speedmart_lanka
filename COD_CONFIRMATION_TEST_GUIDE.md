# COD Confirmation Fix - Testing Guide

## Test Scenario: Single Category COD Payment

### Prerequisites
- Flutter app running
- Customer account logged in
- At least one request with accepted Groceries proposal

### Test Steps

1. **Navigate to Request Details**
   - Open customer dashboard
   - Select a request that has an accepted Groceries proposal
   - Verify button shows: "Choose Payment"

2. **Initiate Payment**
   - Click "Choose Payment" button
   - Verify navigation to payment screen

3. **Select COD**
   - On payment screen, select "Cash on Delivery (COD)" option
   - Review order summary
   - Verify delivery details are correct

4. **Confirm COD**
   - Click "Confirm Cash on Delivery" button
   - Wait for payment processing

5. **Check Logs During Processing**
   ```
   Expected logs:
   [PaymentAudit] PAYMENT CREATION runs
   [PaymentFlow] COD confirm start:
   [PaymentFlow] proposal id: PROP-XXXXX
   [PaymentFlow] request id: REQ-XXXXX
   [PaymentFlow] category: groceries
   [PaymentFlow] before fulfillment status: accepted
   [PaymentFlow] after fulfillment status: paid
   [PaymentFlow] request saved after COD: REQ-XXXXX
   [PaymentFlow] request reloaded category status: paid
   ```

6. **View Receipt**
   - Verify receipt screen appears
   - Check payment method shows "Cash on Delivery"
   - Check payment status shows correct value
   - Click "Return to Dashboard" or back button

7. **Return to Request Details**
   - Navigate back to the request details screen
   - Should automatically reload with updated status

8. **Verify Updated UI**
   - ✅ Groceries proposal card shows:
     - Button label: "Payment Complete" or "COD Confirmed"
     - Button is disabled (grayed out)
     - Cannot click to reopen payment
   - ✅ Category status badge shows: "Paid"

9. **Check Final Logs**
   ```
   Expected logs:
   [PaymentFlow] Accepted category: groceries
   [PaymentFlow] categoryStatus: paid
   [PaymentFlow] isPaid: true
   [PaymentFlow] request reloaded after payment
   [PaymentFlow] categoryStatus after reload: paid
   ```

### Expected Results Summary

| Check | Expected | Status |
|-------|----------|--------|
| Payment created | ✅ Payment record exists | |
| Order created | ✅ Order record exists | |
| Category fulfillment updated | ✅ status = paid | |
| paidAt timestamp set | ✅ Not null | |
| Request saved | ✅ Persisted to storage | |
| UI button disabled | ✅ Shows "Payment Complete" | |
| Button grayed out | ✅ Not clickable | |
| No payment screen reopen | ✅ Stays on details | |
| Logs show isPaid true | ✅ Correct value | |

## Test Scenario: Multi-Category Request

### Prerequisites
- Request with multiple categories (e.g., Groceries + Electronics)
- Both categories have accepted proposals

### Test Steps

1. **Accept and Pay for First Category (Groceries)**
   - Follow steps 1-8 from single category test
   - Verify Groceries shows "Payment Complete"

2. **Check Second Category (Electronics)**
   - Verify Electronics still shows "Choose Payment"
   - Verify Electronics button is still enabled
   - Confirm independent payment status

3. **Pay for Second Category**
   - Click "Choose Payment" for Electronics
   - Complete COD confirmation
   - Return to request details

4. **Verify Both Categories**
   - ✅ Groceries: "Payment Complete" (disabled)
   - ✅ Electronics: "Payment Complete" (disabled)
   - ✅ Both categories show "Paid" status badge

### Expected Multi-Category Results

| Category | Before Payment | After Payment | Independent |
|----------|----------------|---------------|-------------|
| Groceries | "Choose Payment" | "Payment Complete" | ✅ |
| Electronics | "Choose Payment" | "Payment Complete" | ✅ |

## Error Scenarios to Test

### 1. Double Payment Attempt
**Test:**
- Complete COD for a category
- Try clicking "Payment Complete" button

**Expected:**
- Button should be disabled
- Nothing happens on click
- No navigation to payment screen

### 2. Back Navigation During Payment
**Test:**
- Start payment process
- Press back button before confirming

**Expected:**
- Returns to request details
- Category still shows "Choose Payment"
- Can try payment again

### 3. App Restart After Payment
**Test:**
- Complete COD payment
- Close and restart app
- Navigate back to request

**Expected:**
- Category still shows "Payment Complete"
- Payment status persisted
- Button remains disabled

## Debug Commands

### View Request in Storage
```dart
// In debug console
final request = await MockRequestRepository.instance.getRequestById('REQ-XXXXX');
print('Fulfillments: ${request.categoryFulfillments}');
```

### Check Category Status
```dart
final status = request.getCategoryStatus('groceries');
print('Groceries status: ${status.name}');
print('Is paid: ${status == RequestCategoryStatus.paid}');
```

### View Payment Records
```dart
final payments = await PaymentRepository.getPaymentsForRequest('REQ-XXXXX');
print('Payment count: ${payments.length}');
payments.forEach((p) => print('Method: ${p.paymentMethod.name}, Status: ${p.paymentStatus.name}'));
```

## Troubleshooting

### Issue: Button still shows "Choose Payment"
**Check:**
1. Verify logs show "after fulfillment status: paid"
2. Check if request was saved: "request saved after COD"
3. Verify request reload happened: "request reloaded after payment"
4. Check storage persistence

**Fix:**
- Ensure `updateRequest()` is being called
- Verify repository `updateRequest()` persists data
- Check provider state is updating

### Issue: Payment created but category not updated
**Check:**
1. Verify proposal has `categoryNormalized` field set
2. Check logs for "before fulfillment status"
3. Ensure category matches request items

**Fix:**
- Ensure proposal category is set correctly
- Verify category normalization (lowercase, trimmed)
- Check fulfillment map has entry for category

### Issue: Request not reloading after payment
**Check:**
1. Verify `_handleAcceptedProposalAction()` is async
2. Check if `mounted` check is passing
3. Verify `setState()` is called with refreshed data

**Fix:**
- Ensure await on `getRequestById()`
- Check widget is still mounted
- Verify setState triggers rebuild

## Success Criteria

✅ All single category tests pass
✅ All multi-category tests pass  
✅ All error scenarios handled correctly
✅ All logs show expected values
✅ UI reflects payment status accurately
✅ Data persists across app restarts
✅ No duplicate payment attempts possible
