import * as admin from "firebase-admin";

if (admin.apps.length === 0) {
  // Local scripts are not running in Cloud Functions, so the project ID must
  // be supplied explicitly. Credentials still come from ADC or the service
  // account referenced by GOOGLE_APPLICATION_CREDENTIALS.
  admin.initializeApp({
    projectId: process.env.GCLOUD_PROJECT ??
        process.env.FIREBASE_PROJECT_ID ??
        "speedmart-lanka",
  });
}

const db = admin.firestore();

type JsonRecord = Record<string, unknown>;

function isRecord(value: unknown): value is JsonRecord {
  return value !== null && typeof value === "object" && !Array.isArray(value);
}

function pick(source: JsonRecord, keys: string[]): JsonRecord {
  const result: JsonRecord = {};
  for (const key of keys) {
    if (source[key] !== undefined) result[key] = source[key];
  }
  return result;
}

function customerProposalProjection(proposalId: string, proposal: JsonRecord): JsonRecord {
  const rawItems = Array.isArray(proposal.items) ? proposal.items : [];
  const customerItemDecisions: JsonRecord = isRecord(proposal.customerItemDecisions)
    ? {...proposal.customerItemDecisions}
    : {};

  const items = rawItems.map((rawItem) => {
    const item = isRecord(rawItem) ? rawItem : {};
    if (typeof item.requestItemId === "string" &&
        typeof item.customerDecision === "string" &&
        customerItemDecisions[item.requestItemId] === undefined) {
      customerItemDecisions[item.requestItemId] = item.customerDecision;
    }
    return pick(item, [
      "id", "requestItemId", "requestItemName", "itemName", "quantity",
      "status", "price", "offeredBrandModel", "availableStock", "description",
      "alternativeName", "alternativeBrand", "alternativeReason", "imageUrl",
    ]);
  });

  return {
    ...pick(proposal, [
      "requestId", "customerId", "vendorId", "missingItemIds", "deliveryCharge",
      "estimatedDeliveryTime", "totalPrice", "status", "createdAt", "updatedAt",
      "rejectedAt", "rejectionReason", "categoriesNormalized", "commissionRate",
    ]),
    id: proposalId,
    items,
    customerItemDecisions,
  };
}

function bankTransferInstruction(
  proposalId: string,
  proposal: JsonRecord,
  vendor: JsonRecord,
): JsonRecord {
  const accountName = typeof vendor.bank_account_name === "string"
    ? vendor.bank_account_name
    : null;
  const accountNumber = typeof vendor.bank_account_number === "string"
    ? vendor.bank_account_number
    : null;
  const acceptsBankTransfer = vendor.accepts_bank_transfer !== false;

  return {
    proposalId,
    customerId: proposal.customerId ?? "",
    vendorId: proposal.vendorId ?? "",
    isAvailable: acceptsBankTransfer &&
      accountName !== null && accountName.trim().length > 0 &&
      accountNumber !== null && accountNumber.trim().length > 0,
    bankName: typeof vendor.bank_name === "string" ? vendor.bank_name : null,
    bankBranch: typeof vendor.bank_branch === "string" ? vendor.bank_branch : null,
    accountName,
    accountNumber,
    updatedAt: new Date().toISOString(),
  };
}

async function backfill(): Promise<void> {
  const proposals = await db.collection("proposals").get();
  const vendorProfiles = new Map<string, JsonRecord>();
  let batch = db.batch();
  let pendingWrites = 0;
  let total = 0;

  for (const proposalDoc of proposals.docs) {
    const safeProposal = customerProposalProjection(
      proposalDoc.id,
      proposalDoc.data() as JsonRecord,
    );
    const proposal = proposalDoc.data() as JsonRecord;
    const vendorId = typeof proposal.vendorId === "string" ? proposal.vendorId : "";
    let vendor = vendorProfiles.get(vendorId);
    if (vendor === undefined && vendorId) {
      const vendorDoc = await db.doc(
        "users/vendors/profiles/" + vendorId,
      ).get();
      vendor = vendorDoc.exists ? vendorDoc.data() as JsonRecord : {};
      vendorProfiles.set(vendorId, vendor);
    }
    batch.set(db.collection("customer_proposals").doc(proposalDoc.id), safeProposal);
    batch.set(
      db.collection("bank_transfer_instructions").doc(proposalDoc.id),
      bankTransferInstruction(proposalDoc.id, proposal, vendor ?? {}),
    );
    pendingWrites += 2;
    total++;

    if (pendingWrites >= 400) {
      await batch.commit();
      batch = db.batch();
      pendingWrites = 0;
    }
  }

  if (pendingWrites > 0) await batch.commit();
  console.log(`Backfilled ${total} customer proposal projections.`);

  // Orders and payments are currently customer-readable for lifecycle
  // tracking. New checkout records already leave these fields blank; scrub
  // historic records so they cannot retain a vendor's identity or location.
  const [orders, payments] = await Promise.all([
    db.collection("orders").get(),
    db.collection("payments").get(),
  ]);
  batch = db.batch();
  pendingWrites = 0;
  let scrubbed = 0;

  for (const orderDoc of orders.docs) {
    const order = orderDoc.data() as JsonRecord;
    const update: JsonRecord = {};
    if (order.vendorBusinessName !== undefined && order.vendorBusinessName !== "") {
      update.vendorBusinessName = "";
    }
    if (order.vendorPhone !== undefined && order.vendorPhone !== "") {
      update.vendorPhone = "";
    }
    if (order.vendorLatitude !== undefined && order.vendorLatitude !== 0) {
      update.vendorLatitude = 0;
    }
    if (order.vendorLongitude !== undefined && order.vendorLongitude !== 0) {
      update.vendorLongitude = 0;
    }
    if (Object.keys(update).length > 0) {
      batch.update(orderDoc.ref, update);
      pendingWrites++;
      scrubbed++;
    }
    if (pendingWrites === 400) {
      await batch.commit();
      batch = db.batch();
      pendingWrites = 0;
    }
  }

  for (const paymentDoc of payments.docs) {
    const payment = paymentDoc.data() as JsonRecord;
    if (payment.vendorBusinessName === undefined || payment.vendorBusinessName === "") {
      continue;
    }
    batch.update(paymentDoc.ref, {vendorBusinessName: ""});
    pendingWrites++;
    scrubbed++;
    if (pendingWrites === 400) {
      await batch.commit();
      batch = db.batch();
      pendingWrites = 0;
    }
  }

  if (pendingWrites > 0) await batch.commit();
  console.log(`Scrubbed vendor identity/location fields from ${scrubbed} historic records.`);
}

backfill().catch((error: unknown) => {
  console.error("Customer proposal backfill failed:", error);
  process.exitCode = 1;
});
