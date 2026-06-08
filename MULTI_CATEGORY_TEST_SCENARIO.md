# Multi-Category Order Flow - Test Scenario

## Test Setup

Create a test request with 3 categories:
- **TV** → Electronics
- **Rice** → Groceries  
- **Hammer** → Hardware

Request ID: REQ-96600 (or similar)

## Vendor Proposals

Have 4 vendors submit proposals:

1. **Electronics Vendor A**
   - Submits proposal for TV
   - categoryNormalized = "electronics"
   - Price: Rs. 50,000

2. **Electronics Vendor B**
   - Submits proposal for TV
   - categoryNormalized = "electronics"
   - Price: Rs. 48,000

3. **Groceries Vendor**
   - Submits proposal for Rice
   - categoryNormalized = "groceries"
   - Price: Rs. 500

4. **Hardware Vendor**
   - Submits proposal for Hammer
   - categoryNormalized = "hardware"
   - Price: Rs. 800

## Test Scenario: Accept Electronics Vendor A

### Action
Customer accepts Electronics Vendor A's proposal (Rs. 50,000)

### Expected Behavior

#### Proposal Statuses
- ✅ Electronics Vendor A → **ACCEPTED**
- ❌ Electronics Vendor B → **REJECTED** (reason: "Customer selected another vendor for this category")
- ⏳ Groceries Vendor → **STILL SUBMITTED/PENDING** (active)
- ⏳ Hardware Vendor → **STILL SUBMITTED/PENDING** (active)

#### Category Fulfillment Status
```
request.categoryFulfillments = {
  "electronics": {
    status: RequestCategoryStatus.accepted,
    acceptedProposalId: "PROP-xxxxx" (Electronics Vendor A),
    acceptedVendorId: "vendor-a-id",
    acceptedAt: DateTime.now()
  },
  "groceries": {
    status: RequestCategoryStatus.proposalReceived,
    acceptedProposalId: null,
    acceptedVendorId: null,
    acceptedAt: null
  },
  "hardware": {
    status: RequestCategoryStatus.proposalReceived,
    acceptedProposalId: null,
    acceptedVendorId: null,
    acceptedAt: null
  }
}
```

#### Customer UI - Category Progress
```
Categories Requested: 3
Accepted: 1
Pending: 2  
Completed: 0
```

Progress bar: 33% filled (1/3 categories accepted)

#### Customer UI - Item List
```
☑️ TV — Electronics — Accepted
⏳ Rice — Groceries — Pending
⏳ Hammer — Hardware — Pending
```

#### Customer UI - Proposals Grouped by Category

**Electronics Offers**  
Status: Accepted
- ✅ Vendor A - Rs. 50,000 - ACCEPTED - [Pay Now button]
- ❌ Vendor B - Rs. 48,000 - REJECTED

**Groceries Offers**  
Status: Pending
- ⏳ Groceries Vendor - Rs. 500 - [Accept] [Reject]

**Hardware Offers**  
Status: Pending
- ⏳ Hardware Vendor - Rs. 800 - [Accept] [Reject]

#### Vendor UI - Proposal Status Messages

**Electronics Vendor A:**
- Status: "Accepted — Prepare Order"
- Action: Proceed to prepare TV for delivery

**Electronics Vendor B:**
- Status: "Rejected — Customer selected another vendor for this category"
- No action available

**Groceries Vendor:**
- Status: "Pending Customer Review"
- Proposal still active, awaiting customer decision

**Hardware Vendor:**
- Status: "Pending Customer Review"  
- Proposal still active, awaiting customer decision

#### Request Overall Status
- Request status: `RequestStatus.customerAccepted`
- Request remains ACTIVE (not completed)
- Other categories can still receive proposals
- Customer can still accept additional vendors for Groceries and Hardware

## Console Logs to Verify

```
[MultiCategoryFlow] Accept proposal: PROP-xxxxx
[MultiCategoryFlow] Accepted category: electronics
[MultiCategoryFlow] Rejected same-category competitor: PROP-yyyyy
[MultiCategoryFlow] Preserved other-category proposal: PROP-zzzzz (groceries)
[MultiCategoryFlow] Preserved other-category proposal: PROP-wwwww (hardware)
[MultiCategoryFlow] Updated category fulfillment: electronics
[MultiCategoryFlow] Request summary: 1 accepted, 2 pending, 0 completed
```

## Negative Test Cases

### ❌ WRONG Behavior (Pre-Fix)
When accepting Electronics Vendor A:
- Electronics Vendor A → accepted ✅
- Electronics Vendor B → rejected ✅
- **Groceries Vendor → rejected ❌ (WRONG!)**
- **Hardware Vendor → rejected ❌ (WRONG!)**
- Request marked as fully completed ❌
- No way to order Rice and Hammer ❌

### ✅ CORRECT Behavior (Post-Fix)
When accepting Electronics Vendor A:
- Electronics Vendor A → accepted ✅
- Electronics Vendor B → rejected (same category) ✅
- Groceries Vendor → still active ✅
- Hardware Vendor → still active ✅
- Request remains open for other categories ✅
- Customer can proceed to accept Groceries and Hardware vendors ✅

## Test Steps

1. **Setup:** Create REQ-96600 with TV, Rice, Hammer
2. **Propose:** 4 vendors submit proposals (2 electronics, 1 groceries, 1 hardware)
3. **Accept:** Customer accepts Electronics Vendor A proposal
4. **Verify:** Check all expected behaviors above
5. **Continue:** Customer can now accept Groceries and Hardware proposals independently
6. **Complete:** Only when all 3 categories accepted should request be fully complete

## Success Criteria

✅ Only same-category proposals are rejected  
✅ Other-category proposals remain active  
✅ Category fulfillment tracks per-category status  
✅ Progress UI shows correct counts  
✅ Items show correct category status badges  
✅ Proposals grouped by category with status headers  
✅ Console logs confirm multi-category logic executed  
✅ Vendors from other categories not affected  
✅ Request stays open until all categories complete  
✅ Customer can independently accept/reject each category
