# Vendor-Side COD Order Handling - Implementation

## Overview
Implemented vendor functionality to handle Cash on Delivery (COD) orders, allowing vendors to mark cash as collected after delivery, which updates payment status and customer UI automatically.

## Customer Flow (Already Implemented)
1. Customer accepts proposal → Status: `accepted`
2. Customer selects COD → Navigate to payment  
3. Customer confirms COD → Status: `codConfirmed`, payment status: `pending`
4. Customer sees: "COD Confirmed" button (disabled, orange)

## Vendor Flow (New Implementation)

### 1. Vendor Sees COD Order
- Order card shows: "COD Order Confirmed"
- Payment method badge: "Cash on Delivery"
- Orange indicator showing COD status
- Amount to collect displayed prominently

### 2. Vendor Prepares and Dispatches Order
- Start Preparing Order
- Mark Ready for Delivery  
- Dispatch Order (Out for Delivery)

### 3. Vendor Delivers and Collects Cash
- When order status = `outForDelivery` AND payment method = `cashOnDelivery`
- Special button appears: "Mark Cash Collected / Delivered"
- Button color: Green (AppColors.success)
- Icon: paid_rounded

### 4. When Vendor Marks Cash Collected
```dart
_handleMarkCashCollected() {
  1. Get payment record for order
  2. Update paymentStatus = paid
  3. Get request and proposal
  4. Find category from proposal
  5. Update category fulfillment:
     - status = paid
     - paidAt = DateTime.now()
     - completedAt = DateTime.now()
  6. Update order status = delivered
  7. Notify customer
  8. Reload vendor orders
}
```

## Files Modified

### vendor_order_details_screen.dart

#### Added Imports
```dart
import 'package:speedmart_lanka/features/payments/providers/payment_provider.dart';
import 'package:speedmart_lanka/features/payments/data/mock_payment_repository.dart';
import 'package:speedmart_lanka/features/proposals/providers/proposal_provider.dart';
import 'package:speedmart_lanka/features/requests/models/request_category_fulfillment.dart';
import 'package:speedmart_lanka/features/requests/providers/request_provider.dart';
import 'package:speedmart_lanka/features/requests/data/mock_request_repository.dart';
```

#### Added Handler Method
```dart
Future<void> _handleMarkCashCollected(
  BuildContext context,
  WidgetRef ref,
  OrderModel order,
) async {
  // Get payment and update to paid
  final payment = await MockPaymentRepository.instance.getPaymentByOrderId(order.id);
  await MockPaymentRepository.instance.updatePaymentStatus(payment.id, PaymentStatus.paid);
  
  // Get request and proposal  
  final request = await MockRequestRepository.instance.getRequestById(order.requestId);
  final proposal = await ref.read(proposalProvider.notifier).loadProposalById(order.proposalId);
  
  // Update category fulfillment to paid
  if (proposal?.categoryNormalized != null) {
    final category = proposal!.categoryNormalized!;
    final updatedFulfillments = {...request!.categoryFulfillments};
    
    updatedFulfillments[category] = currentFulfillment.copyWith(
      status: RequestCategoryStatus.paid,
      paidAt: DateTime.now(),
      completedAt: DateTime.now(),
    );
    
    await MockRequestRepository.instance.updateRequest(
      request.copyWith(categoryFulfillments: updatedFulfillments)
    );
  }
  
  // Update order to delivered
  await ref.read(orderProvider.notifier).updateOrderStatus(
    order.id,
    OrderStatus.delivered,
  );
  
  // Notify customer
  ref.read(notificationProvider.notifier).triggerNotification(...);
}
```

#### Added COD Indicator
After Order Summary Card:
```dart
if (activeOrder.paymentMethod == PaymentMethod.cashOnDelivery)
  Container(
    // Shows COD status, amount to collect, and collection status
    child: Column(
      children: [
        Row(
          Icon(payment status icon),
          Text('COD Payment Received' or 'Cash on Delivery Order'),
        ),
        Text('Cash collected' or 'Collect Rs. X upon delivery'),
      ],
    ),
  ),
```

#### Updated Button Section
```dart
// COD Cash Collection Button
if (activeOrder.paymentMethod == PaymentMethod.cashOnDelivery &&
    activeOrder.paymentStatus != PaymentStatus.paid &&
    activeOrder.status == OrderStatus.outForDelivery)
  Column(
    children: [
      // Orange warning banner
      Container('COD Order — Collect cash on delivery'),
      
      // Green success button
      ElevatedButton.icon(
        icon: Icons.paid_rounded,
        label: 'Mark Cash Collected / Delivered',
        onPressed: () => _handleMarkCashCollected(context, ref, activeOrder),
      ),
    ],
  )
else
  // Regular status progression button
  ElevatedButton(
    'Start Preparing' / 'Mark Ready' / 'Dispatch' / 'Delivered',
  ),
```

## Logging

### Vendor Marks Cash Collected
```
[CODFlow] vendor mark cash collected start:
[CODFlow] request id: REQ-12345
[CODFlow] proposal id: PROP-67890
[CODFlow] payment id: PAY-11111
[CODFlow] payment before: pending
[CODFlow] payment after: paid
[CODFlow] category: groceries
[CODFlow] fulfillment before: codConfirmed
[CODFlow] fulfillment after: paid
[CODFlow] customer UI should now show paid: true
```

## Data Flow

### Vendor Cash Collection Flow
```
Vendor delivers product
    ↓
Vendor collects cash from customer
    ↓
Vendor taps "Mark Cash Collected / Delivered"
    ↓
Payment updated:
  - paymentStatus = paid
  - paidAt = DateTime.now()
    ↓
Category fulfillment updated:
  - status = paid
  - paidAt = DateTime.now()
  - completedAt = DateTime.now()
    ↓
Order updated:
  - status = delivered
    ↓
Customer notified:
  - "Payment Received! 💰"
  - "Vendor confirmed cash collection"
    ↓
Customer UI automatically updates:
  - Button: "Payment Complete" (green, disabled)
  - Status badge: "Paid"
  - Category status: paid
```

## UI States

### COD Order Indicator

#### Before Cash Collection
- Background: Orange (warning color with alpha 0.1)
- Border: Orange (warning color with alpha 0.3)
- Icon: local_shipping_rounded (orange)
- Title: "Cash on Delivery Order"
- Message: "Collect cash Rs. X upon delivery"

#### After Cash Collection
- Background: Green (success color with alpha 0.1)
- Border: Green (success color with alpha 0.3)
- Icon: check_circle_rounded (green)
- Title: "COD Payment Received"
- Message: "Cash has been collected from customer"

### Button States

#### Out for Delivery + COD Unpaid
- Shows: "Mark Cash Collected / Delivered"
- Color: Green (AppColors.success)
- Icon: paid_rounded
- Enabled: true
- Banner: Orange warning "COD Order — Collect cash on delivery"

#### After Cash Collected
- Button disappears (order moved to delivered)
- Or shows regular completion flow if needed

## Test Scenarios

### Test 1: End-to-End COD Flow

#### Customer Side
1. Accept Groceries proposal
2. Choose Cash on Delivery
3. Confirm COD order
4. See "COD Confirmed" button (orange, disabled)

**Expected:**
- Category status: `codConfirmed`
- Payment status: `pending`
- Button: "COD Confirmed"

#### Vendor Side
1. Login as grocery vendor
2. Navigate to orders
3. Open COD order
4. See COD indicator: "Cash on Delivery Order"
5. See amount: "Collect Rs. X upon delivery"
6. Progress order: Preparing → Ready → Out for Delivery
7. See special button: "Mark Cash Collected / Delivered"
8. Tap button

**Expected:**
- Success message: "Cash collected and payment confirmed!"
- Order status: delivered
- Payment status: paid

#### Customer Side (After Vendor Confirmation)
1. Return to request details
2. Check Groceries category

**Expected:**
- Button: "Payment Complete" (green, disabled)
- Status badge: "Paid"
- Cannot reopen payment
- Category status: `paid`

### Test 2: Multi-Category COD

#### Setup
- Request: Groceries + Electronics
- Both accepted
- Groceries: COD confirmed
- Electronics: Not yet paid

#### Vendor Actions
1. Grocery vendor marks cash collected
2. Grocery category → paid

**Expected:**
- ✅ Groceries: "Payment Complete" (green)
- ✅ Electronics: Still "Choose Payment" (if not confirmed)
- ✅ Independent category states maintained

### Test 3: Mixed Payment Methods

#### Setup
- Request: Groceries + Electronics  
- Groceries: COD confirmed
- Electronics: Card payment (already paid)

#### Verification
- ✅ Groceries shows orange "COD Confirmed" until vendor collects
- ✅ Electronics shows green "Payment Complete" immediately
- ✅ After vendor collects for Groceries, both green

## Business Rules Enforced

✅ **Only vendor can mark COD as paid**
- Handler is in vendor screen
- Customer cannot access this functionality

✅ **Cash collected only after delivery**
- Button only appears when status = `outForDelivery`
- Ensures delivery before payment confirmation

✅ **Payment status distinguishes pending from paid**
- COD confirmed: `paymentStatus = pending`
- Cash collected: `paymentStatus = paid`

✅ **Category fulfillment properly updated**
- Vendor action updates specific category only
- Other categories unaffected

✅ **Customer UI synchronizes automatically**
- Repository updates persist
- Customer sees changes when they check
- No manual refresh needed

✅ **Order status reflects completion**
- Cash collection marks order as delivered
- Proper order lifecycle maintained

## Visual Design

### COD Badge Colors
- **Pending (Orange)**: Vendor needs to collect
- **Paid (Green)**: Cash collected

### Button Colors
- **Cash Collection Button**: Green (AppColors.success)
- **Regular Progression**: Purple (AppColors.vendorColor)

### Icons
- **COD Pending**: `local_shipping_rounded`
- **COD Paid**: `check_circle_rounded`
- **Button**: `paid_rounded`

## Error Handling

### Payment Not Found
```dart
if (payment == null) {
  ScaffoldMessenger.showSnackBar(
    SnackBar(content: Text('Payment record not found')),
  );
  return;
}
```

### Proposal Not Found
- Gracefully handled
- Logs warning
- Still updates payment status

### Request Update Fails
- Error logged
- User notified
- Payment status still updated (customer can retry)

## Next Steps

### Future Enhancements
1. Add admin override for manual cash collection marking
2. Add partial payment support for COD
3. Add photo proof of cash collection
4. Add digital signature from customer
5. Add dispute resolution for COD issues

### Backend Integration
When moving to real backend:
1. Replace MockPaymentRepository with API calls
2. Replace MockRequestRepository with API calls  
3. Add proper transaction handling
4. Add payment verification
5. Add audit trail for cash collection

## Status

✅ **Vendor Side: COMPLETE**
- COD order identification
- Visual indicators for COD status
- Cash collection button
- Payment status update
- Category fulfillment update
- Order status update
- Customer notification

✅ **Customer Side: COMPLETE** 
- COD confirmation
- Status display
- UI synchronization

✅ **Multi-Category: COMPLETE**
- Independent category handling
- Proper status tracking
- Correct UI updates

✅ **Full Flow: TESTED**
- Customer confirms COD
- Vendor sees order
- Vendor collects cash
- Customer sees paid status
