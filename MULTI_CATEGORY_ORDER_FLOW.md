# MULTI-CATEGORY ORDER FLOW FIX

## Status: ✅ MODELS COMPLETE - UI IMPLEMENTATION NEEDED

---

## Problem Statement

Current behavior incorrectly treats multi-category requests as single orders.

### Example Broken Behavior:
```
Request: [TV (Electronics), Rice (Groceries), Hammer (Hardware)]

Customer accepts Electronics vendor proposal:
❌ WRONG: All proposals for entire request get cancelled
❌ WRONG: Groceries and Hardware proposals rejected
❌ WRONG: Request marked as fully accepted
```

### Correct Behavior Required:
```
Request: [TV (Electronics), Rice (Groceries), Hammer (Hardware)]

Customer accepts Electronics vendor proposal:
✅ Electronics category → Accepted
✅ Electronics competing proposals → Rejected
✅ Groceries category → Still Pending
✅ Hardware category → Still Pending
✅ Groceries proposals → Still Active
✅ Hardware proposals → Still Active
```

---

## Solution Implemented

### Architecture: Category-Level Fulfillment Tracking

Each category in a multi-category request has **independent lifecycle**.

---

## New Models Created

### 1. RequestCategoryStatus Enum

```dart
enum RequestCategoryStatus {
  pending,           // Waiting for vendor proposals
  proposalReceived,  // At least one proposal received
  accepted,          // Customer accepted a vendor
  paid,              // Payment completed for this category
  completed,         // Items delivered
  cancelled          // Category cancelled
}
```

**Key Methods**:
- `canReceiveProposals` - true for pending/proposalReceived
- `isActive` - not cancelled or completed
- `isInProgress` - accepted or paid

---

### 2. RequestCategoryFulfillment Model

Tracks status for ONE category within a request.

```dart
class RequestCategoryFulfillment {
  final String categoryNormalized;        // e.g., "electronics"
  final RequestCategoryStatus status;
  final String? acceptedProposalId;       // Which vendor won
  final String? acceptedVendorId;
  final DateTime? acceptedAt;
  final DateTime? paidAt;
  final DateTime? completedAt;
  final DateTime? cancelledAt;
  final String? cancellationReason;
}
```

**File**: `lib/features/requests/models/request_category_fulfillment.dart`

---

### 3. Enhanced ShoppingRequest Model

Added category-level tracking:

```dart
class ShoppingRequest {
  // ... existing fields ...
  
  // NEW: Map category → fulfillment status
  final Map<String, RequestCategoryFulfillment> categoryFulfillments;
  
  // NEW: Helper methods
  List<String> get categories;
  bool get isMultiCategory;
  int get totalCategories;
  int get pendingCategoriesCount;
  int get acceptedCategoriesCount;
  int get completedCategoriesCount;
  bool get allCategoriesCompleted;
  bool get hasAcceptedCategory;
  
  RequestCategoryStatus getCategoryStatus(String categoryNormalized);
  bool canCategoryReceiveProposals(String categoryNormalized);
}
```

**Initialization**:
```dart
// Automatically creates fulfillments from request items
Request items: [TV (Electronics), Rice (Groceries)]
↓
categoryFulfillments = {
  'electronics': RequestCategoryFulfillment(status: pending),
  'groceries': RequestCategoryFulfillment(status: pending),
}
```

---

### 4. Enhanced Proposal Model

Added category tracking:

```dart
class Proposal {
  // ... existing fields ...
  
  // NEW: Which category this proposal addresses
  final String? categoryNormalized;
}
```

**Purpose**: 
- Vendor proposals are now category-specific
- In multi-category requests, each vendor's proposal only covers their category items

---

## Business Rules Implemented

### Rule 1: Independent Category Lifecycles
```dart
Request categories: {electronics, groceries, hardware}

Electronics: accepted → paid → completed
Groceries: pending → proposalReceived → accepted → paid → completed
Hardware: pending → cancelled

Each category progresses independently.
```

### Rule 2: Category-Specific Proposal Rejection
```dart
Customer accepts Proposal A for Electronics:

✅ Proposal A (electronics) → ACCEPTED
❌ Proposal B (electronics) → REJECTED (same category)
❌ Proposal C (electronics) → REJECTED (same category)
✅ Proposal D (groceries) → PENDING (different category)
✅ Proposal E (hardware) → PENDING (different category)
```

**Implementation**:
```dart
void acceptProposal(String proposalId) {
  final proposal = getProposal(proposalId);
  final category = proposal.categoryNormalized;
  
  // Accept this proposal
  proposal.status = ProposalStatus.accepted;
  
  // Reject OTHER proposals for SAME category
  for (final other in getProposalsForRequest(proposal.requestId)) {
    if (other.id != proposalId && 
        other.categoryNormalized == category) {
      other.status = ProposalStatus.rejected;
      other.rejectionReason = 'Customer selected another vendor for this category';
    }
  }
  
  // Update category fulfillment
  request.categoryFulfillments[category] = RequestCategoryFulfillment(
    categoryNormalized: category,
    status: RequestCategoryStatus.accepted,
    acceptedProposalId: proposalId,
    acceptedVendorId: proposal.vendorId,
    acceptedAt: DateTime.now(),
  );
}
```

### Rule 3: Vendor Sees Only Their Category Items
```dart
Request items:
- TV (Electronics)
- Phone (Electronics)
- Rice (Groceries)
- Hammer (Hardware)

Electronics vendor feed shows:
- TV ✅
- Phone ✅
- Rice ❌ (filtered out)
- Hammer ❌ (filtered out)

Already implemented via filterMatchingItems() from previous fix.
```

---

## Customer UI Requirements

### Progress Indicator

```dart
Widget buildCategoryProgress(ShoppingRequest request) {
  return Column(
    children: [
      Text('Total Categories: ${request.totalCategories}'),
      Text('Pending: ${request.pendingCategoriesCount}'),
      Text('Accepted: ${request.acceptedCategoriesCount}'),
      Text('Completed: ${request.completedCategoriesCount}'),
      
      LinearProgressIndicator(
        value: request.completedCategoriesCount / request.totalCategories,
      ),
    ],
  );
}
```

### Category Status Display

```dart
for (final category in request.categories) {
  final fulfillment = request.getFulfillment(category)!;
  final displayName = VendorCategories.display(category);
  
  ListTile(
    title: Text(displayName),
    subtitle: Text(fulfillment.status.displayName),
    trailing: _getStatusIcon(fulfillment.status),
  );
}
```

### Proposal Cards

Show category-specific status:

```dart
Widget buildProposalCard(Proposal proposal, ShoppingRequest request) {
  final category = proposal.categoryNormalized!;
  final fulfillment = request.getFulfillment(category)!;
  
  String statusText;
  if (proposal.status == ProposalStatus.accepted) {
    statusText = 'Accepted';
  } else if (proposal.status == ProposalStatus.rejected) {
    if (fulfillment.acceptedProposalId != null && 
        fulfillment.acceptedProposalId != proposal.id) {
      statusText = 'Customer selected another vendor for this category';
    } else {
      statusText = 'Rejected';
    }
  } else {
    statusText = 'Pending';
  }
  
  return Card(
    child: Column(
      children: [
        Text('Category: ${VendorCategories.display(category)}'),
        Text('Status: $statusText'),
        // ... proposal details
      ],
    ),
  );
}
```

---

## Vendor UI Requirements

### Vendor Feed (Already Implemented)

Vendor sees only items matching their approved categories via `filterMatchingItems()`.

### Proposal Status Display

```dart
Widget buildVendorProposalStatus(Proposal proposal) {
  String statusMessage;
  Color statusColor;
  
  switch (proposal.status) {
    case ProposalStatus.accepted:
      statusMessage = 'Accepted - Prepare Order';
      statusColor = Colors.green;
      break;
    case ProposalStatus.rejected:
      if (proposal.rejectionReason?.contains('another vendor') == true) {
        statusMessage = 'Customer selected another vendor for this category';
        statusColor = Colors.orange;
      } else {
        statusMessage = 'Rejected';
        statusColor = Colors.red;
      }
      break;
    case ProposalStatus.submitted:
    case ProposalStatus.updated:
      statusMessage = 'Pending Customer Review';
      statusColor = Colors.blue;
      break;
    default:
      statusMessage = proposal.status.displayName;
      statusColor = Colors.grey;
  }
  
  return Container(
    padding: EdgeInsets.all(8),
    decoration: BoxDecoration(
      color: statusColor.withOpacity(0.2),
      borderRadius: BorderRadius.circular(8),
    ),
    child: Text(statusMessage, style: TextStyle(color: statusColor)),
  );
}
```

---

## Implementation Status

### ✅ Completed:
1. RequestCategoryStatus enum with lifecycle methods
2. RequestCategoryFulfillment model for per-category tracking
3. Enhanced ShoppingRequest with category fulfillments map
4. Helper methods for category counts and status queries
5. Enhanced Proposal model with categoryNormalized field
6. JSON serialization/deserialization for persistence

### ⏳ TODO - Critical Implementation Needed:

#### 1. Update Proposal Acceptance Logic
**File**: `lib/features/proposals/data/mock_proposal_repository.dart` or provider

```dart
Future<void> acceptProposal(String proposalId) async {
  final proposal = getProposalById(proposalId);
  final request = getRequestById(proposal.requestId);
  final category = proposal.categoryNormalized!;
  
  // Update proposal status
  await updateProposal(proposal.copyWith(status: ProposalStatus.accepted));
  
  // Reject competing proposals for SAME category only
  final competingProposals = getProposalsForRequest(proposal.requestId)
      .where((p) => 
        p.id != proposalId && 
        p.categoryNormalized == category &&
        p.status.isVisibleToCustomer
      );
  
  for (final competing in competingProposals) {
    await updateProposal(competing.copyWith(
      status: ProposalStatus.rejected,
      rejectionReason: 'Customer selected another vendor for this category',
    ));
  }
  
  // Update category fulfillment
  final updatedFulfillments = Map<String, RequestCategoryFulfillment>.from(
    request.categoryFulfillments,
  );
  updatedFulfillments[category] = RequestCategoryFulfillment(
    categoryNormalized: category,
    status: RequestCategoryStatus.accepted,
    acceptedProposalId: proposalId,
    acceptedVendorId: proposal.vendorId,
    acceptedAt: DateTime.now(),
  );
  
  await updateRequest(request.copyWith(
    categoryFulfillments: updatedFulfillments,
  ));
}
```

#### 2. Update Proposal Creation
**File**: Vendor proposal form

```dart
// When vendor creates proposal, set categoryNormalized
final vendorCategories = vendor.allowedCategories;
final requestItems = filteredRequest.items; // Already filtered
final category = VendorCategories.normalize(requestItems.first.category!);

final proposal = Proposal(
  // ... other fields
  categoryNormalized: category,
  items: requestItems.map((item) => ProposalItem.fromRequestItem(item)).toList(),
);
```

#### 3. Customer UI - Request Detail Screen
**File**: `lib/features/customer/...`

Add:
- Category progress indicator
- Category-by-category status breakdown
- Per-category proposal list

#### 4. Customer UI - Proposal List
Group proposals by category:

```dart
Map<String, List<Proposal>> groupProposalsByCategory(
  List<Proposal> proposals,
) {
  final grouped = <String, List<Proposal>>{};
  for (final proposal in proposals) {
    final category = proposal.categoryNormalized ?? 'unknown';
    grouped.putIfAbsent(category, () => []).add(proposal);
  }
  return grouped;
}
```

#### 5. Vendor UI - Proposal Status Card
Show category-specific status message when rejected due to competitor.

#### 6. Payment Flow
Update payment to be category-specific:
```dart
// Pay for specific category, not entire request
Future<void> payForCategory(
  String requestId,
  String categoryNormalized,
) async {
  final request = getRequestById(requestId);
  final fulfillment = request.getFulfillment(categoryNormalized)!;
  
  // Process payment for this category's proposal
  final proposal = getProposalById(fulfillment.acceptedProposalId!);
  await processPayment(proposal);
  
  // Update category status
  final updatedFulfillments = Map<String, RequestCategoryFulfillment>.from(
    request.categoryFulfillments,
  );
  updatedFulfillments[categoryNormalized] = fulfillment.copyWith(
    status: RequestCategoryStatus.paid,
    paidAt: DateTime.now(),
  );
  
  await updateRequest(request.copyWith(
    categoryFulfillments: updatedFulfillments,
  ));
}
```

---

## Testing Scenarios

### Scenario 1: Multi-Category Acceptance
**Setup**:
- Request: [TV (Electronics), Rice (Groceries), Hammer (Hardware)]
- 2 Electronics vendors submit proposals
- 1 Groceries vendor submits proposal
- 1 Hardware vendor submits proposal

**Actions**:
1. Customer accepts Electronics Vendor A

**Expected Results**:
- Electronics Vendor A proposal: Accepted ✅
- Electronics Vendor B proposal: Rejected ("Customer selected another vendor for this category") ✅
- Groceries vendor proposal: Still Pending ✅
- Hardware vendor proposal: Still Pending ✅
- Request overall: Still active (not all categories fulfilled) ✅

### Scenario 2: Progressive Fulfillment
**Setup**: Same as Scenario 1, after Electronics accepted

**Actions**:
1. Customer accepts Groceries vendor
2. Customer accepts Hardware vendor

**Expected Results**:
- Electronics: Accepted → Paid → Completed
- Groceries: Accepted → Paid → Completed
- Hardware: Accepted → Paid → Completed
- Request: All categories completed ✅

### Scenario 3: Vendor Sees Only Their Items
**Setup**:
- Request: [TV, Phone (Electronics), Rice, Milk (Groceries)]
- Electronics vendor views request

**Expected**:
- Vendor sees: TV, Phone ✅
- Vendor does NOT see: Rice, Milk ✅

**Already implemented** via `filterMatchingItems()`.

---

## Migration Strategy

### Existing Requests
Old requests without `categoryFulfillments` will auto-initialize on first load:

```dart
// In ShoppingRequest constructor
categoryFulfillments = categoryFulfillments ?? 
  _initializeCategoryFulfillments(items);
```

### Existing Proposals
Old proposals without `categoryNormalized` can infer it:

```dart
String inferCategoryFromProposal(Proposal proposal) {
  if (proposal.categoryNormalized != null) {
    return proposal.categoryNormalized!;
  }
  
  // Infer from first item
  if (proposal.items.isNotEmpty) {
    final firstItemCategory = getRequestItem(proposal.items.first.requestItemId).category;
    return VendorCategories.normalize(firstItemCategory!);
  }
  
  return 'unknown';
}
```

---

## Key Files Modified

### Models:
1. ✅ `lib/features/requests/models/request_category_fulfillment.dart` - NEW
2. ✅ `lib/features/requests/models/shopping_request.dart` - Enhanced
3. ✅ `lib/features/proposals/models/proposal.dart` - Enhanced

### Pending Implementation:
4. ⏳ `lib/features/proposals/data/mock_proposal_repository.dart` - Update acceptance logic
5. ⏳ `lib/features/proposals/providers/...` - Update state management
6. ⏳ `lib/features/customer/...` - UI updates
7. ⏳ `lib/features/vendor/...` - UI updates

---

## Success Criteria

✅ Models support category-level tracking
✅ Each category has independent status
⏳ Accepting proposal only rejects same-category competitors
⏳ Other categories remain active
⏳ Customer UI shows per-category progress
⏳ Vendor UI shows category-specific status
⏳ Payment is category-specific
⏳ Delivery is category-specific

---

## Next Steps

1. Implement proposal acceptance logic with category filtering
2. Update customer request detail screen with category breakdown
3. Update customer proposal list with category grouping
4. Update vendor proposal status display
5. Update payment flow for category-specific payments
6. Update order tracking for category-specific delivery
7. Add comprehensive logging for category transitions

---

**MODELS COMPLETE - READY FOR UI IMPLEMENTATION**
