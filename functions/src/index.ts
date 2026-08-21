import * as admin from "firebase-admin";
import {onDocumentCreated, onDocumentUpdated, onDocumentWritten} from "firebase-functions/v2/firestore";
import {onCall, HttpsError} from "firebase-functions/v2/https";
import {onSchedule} from "firebase-functions/v2/scheduler";

admin.initializeApp();

const db = admin.firestore();
const messaging = admin.messaging();

// Strips newlines (log injection) and HTML special chars (XSS) from user data
const sanitize = (s: unknown): string =>
  String(s ?? "").replace(/[\r\n]/g, " ").replace(/[<>"'&]/g, "");

// ── Helpers ───────────────────────────────────────────────────────────────────

async function getFcmToken(userId: string): Promise<string | null> {
  // Check all user subcollections for the FCM token
  const collections = ["customers", "vendors", "admins"];
  for (const col of collections) {
    const doc = await db.doc(`users/${col}/profiles/${userId}`).get();
    if (doc.exists) {
      return doc.data()?.fcmToken ?? null;
    }
  }
  return null;
}

async function sendPushNotification(
  userId: string,
  title: string,
  body: string,
  data: Record<string, string> = {}
): Promise<void> {
  const token = await getFcmToken(userId);
  if (!token) return;
  try {
    await messaging.send({
      token,
      notification: {title, body},
      data,
      android: {priority: "high"},
      apns: {payload: {aps: {sound: "default"}}},
    });
  } catch (e) {
    console.error(`[FCM] Failed to send to ${sanitize(userId)}:`, e);
  }
}

async function createNotification(
  userId: string,
  type: string,
  title: string,
  body: string,
  relatedId?: string,
  data?: Record<string, unknown>
): Promise<void> {
  await db.collection("notifications").add({
    userId,
    type,
    title,
    body,
    relatedId: relatedId ?? null,
    createdAt: new Date().toISOString(),
    isRead: false,
    data: data ?? null,
  });
}

async function logActivity(
  action: string,
  collection: string,
  docId: string,
  performedBy: string,
  details?: string
): Promise<void> {
  await db.collection("activity_logs").add({
    action,
    collection,
    docId,
    performedBy,
    timestamp: new Date().toISOString(),
    details: details ?? null,
  });
}

// Triggered when admin approves a vendor (vendorApproved: false → true)

export const onVendorApproved = onDocumentUpdated(
  "users/vendors/profiles/{vendorId}",
  async (event) => {
    const before = event.data?.before.data();
    const after = event.data?.after.data();
    if (!before || !after) return;

    const vendorId = event.params.vendorId;

    if (before.vendorApproved === false && after.vendorApproved === true) {
      const name = after.businessName ?? after.fullName ?? "Shop Owner";

      await Promise.all([
        createNotification(
          vendorId,
          "vendorApproved",
          "Account Approved! 🎉",
          `Congratulations ${name}! Your shop owner account has been approved. You can now start receiving orders.`,
          vendorId
        ),
        sendPushNotification(
          vendorId,
          "Account Approved! 🎉",
          "Your shop owner account has been approved. Start receiving orders now.",
          {route: "/vendor/dashboard", type: "vendorApproved"}
        ),
        logActivity("approve", "users/vendors/profiles", vendorId, "admin", `Vendor ${name} approved`),
      ]);
    }

    // Vendor rejected
    if (before.vendorStatus !== "rejected" && after.vendorStatus === "rejected") {
      const name = after.businessName ?? after.fullName ?? "Shop Owner";

      await Promise.all([
        createNotification(
          vendorId,
          "vendorRejected",
          "Registration Rejected",
          "Your shop owner registration was not approved. Please contact support for more information.",
          vendorId
        ),
        sendPushNotification(
          vendorId,
          "Registration Rejected",
          "Your shop owner registration was not approved.",
          {route: "/vendor/status", type: "vendorRejected"}
        ),
        logActivity("reject", "users/vendors/profiles", vendorId, "admin", `Vendor ${name} rejected`),
      ]);
    }
  }
);

// ── 2. New Shopping Request ───────────────────────────────────────────────────
// Notify nearby vendors via district-based FCM topic (avoids fan-out reads/writes)

export const onNewRequest = onDocumentCreated(
  "requests/{requestId}",
  async (event) => {
    const request = event.data?.data();
    if (!request) return;

    const requestId = event.params.requestId;
    const customerArea = request.customerArea ?? "your area";

    // Determine which district topic to use.
    // Vendors subscribe to "vendor_requests_<district>" on app startup.
    // Fall back to the global "vendor_requests_all" topic if district is missing.
    const rawDistrict: string = (
      request.district ||
      request.deliveryDistrict ||
      request.customerDistrict ||
      ""
    ).toString().toLowerCase().replace(/[^a-z0-9]/g, "_");

    const districtTopic = rawDistrict ? `vendor_requests_${rawDistrict}` : "vendor_requests_all";

    // Cost: ONE FCM multicast to a topic (replaces N individual reads + N writes)
    try {
      await messaging.send({
        topic: districtTopic,
        notification: {
          title: "New Request Nearby 📍",
          body: `Customer in ${sanitize(customerArea)} needs delivery. Tap to view.`,
        },
        data: {
          route: `/vendor/requests/${requestId}`,
          type: "newNearbyRequest",
          requestId,
        },
        android: {priority: "high"},
        apns: {payload: {aps: {sound: "default"}}},
      });
    } catch (e) {
      console.error(`[FCM] Topic send to ${sanitize(districtTopic)} failed:`, e);
    }

    // Also broadcast to the global fallback topic so vendors without a district still receive it
    if (rawDistrict) {
      try {
        await messaging.send({
          topic: "vendor_requests_all",
          notification: {
            title: "New Request Nearby 📍",
            body: `Customer in ${sanitize(customerArea)} needs delivery. Tap to view.`,
          },
          data: {
            route: `/vendor/requests/${requestId}`,
            type: "newNearbyRequest",
            requestId,
          },
          android: {priority: "high"},
          apns: {payload: {aps: {sound: "default"}}},
        });
      } catch (e) {
        console.error(`[FCM] Topic send to vendor_requests_all failed:`, e);
      }
    }

    await logActivity("create", "requests", requestId, request.customerId ?? "customer");
  }
);

// ── 3. New Proposal Received ──────────────────────────────────────────────────
// Notify customer when a vendor submits a proposal on their request

export const onNewProposal = onDocumentCreated(
  "proposals/{proposalId}",
  async (event) => {
    const proposal = event.data?.data();
    if (!proposal) return;

    const proposalId = event.params.proposalId;
    const customerId = typeof proposal.customerId === "string" ? proposal.customerId : "";
    const requestId = typeof proposal.requestId === "string" ? proposal.requestId : "";

    if (!customerId) {
      console.error(`[Proposal] ${sanitize(proposalId)} has no customerId; notification skipped.`);
      return;
    }

    // Keep the request summary in sync for customer dashboards. Use the
    // current proposal collection rather than incrementing so retried events
    // cannot inflate the count.
    if (requestId) {
      const [requestDoc, proposalDocs] = await Promise.all([
        db.doc(`requests/${requestId}`).get(),
        db.collection("proposals").where("requestId", "==", requestId).get(),
      ]);
      if (requestDoc.exists) {
        const openProposalCount = proposalDocs.docs.filter((doc) => {
          const status = doc.data().status;
          return status === "submitted" || status === "updated";
        }).length;
        const currentStatus = requestDoc.data()?.status;
        const update: Record<string, unknown> = {
          proposalCount: openProposalCount,
          updatedAt: new Date().toISOString(),
        };
        if (currentStatus === "submitted" ||
            currentStatus === "waitingForVendor" ||
            currentStatus === "proposalSubmitted") {
          update.status = "proposalSubmitted";
        }
        await requestDoc.ref.update(update);
      }
    }

    await Promise.all([
      createNotification(
        customerId,
        "newProposal",
        "New Proposal Received 💬",
        "A verified partner has submitted a proposal for your shopping request.",
        proposalId,
        {proposalId, requestId}
      ),
      sendPushNotification(
        customerId,
        "New Proposal 💬",
        "A verified partner submitted a proposal. Tap to review.",
        {route: `/customer/requests/${requestId}`, type: "newProposal", proposalId}
      ),
    ]);
  }
);

// ── 4. Proposal Status Changed ────────────────────────────────────────────────
// Notify vendor when customer accepts or rejects their proposal

export const onProposalStatusChanged = onDocumentUpdated(
  "proposals/{proposalId}",
  async (event) => {
    const before = event.data?.before.data();
    const after = event.data?.after.data();
    if (!before || !after) return;

    if (before.status === after.status) return;

    const proposalId = event.params.proposalId;
    const vendorId: string = after.vendorId;
    const customerId: string = after.customerId;

    if (after.status === "accepted") {
      await Promise.all([
        createNotification(
          vendorId,
          "proposalAccepted",
          "Proposal Accepted ✅",
          "Your proposal has been accepted! Prepare the order for delivery.",
          proposalId,
          {proposalId, requestId: after.requestId}
        ),
        sendPushNotification(
          vendorId,
          "Proposal Accepted ✅",
          "Your proposal was accepted. Prepare the order now.",
          {route: `/vendor/orders`, type: "proposalAccepted", proposalId}
        ),
      ]);
    }

    if (after.status === "rejected") {
      await Promise.all([
        createNotification(
          vendorId,
          "proposalRejected",
          "Proposal Rejected ❌",
          "Your proposal was not selected for this request.",
          proposalId
        ),
        sendPushNotification(
          vendorId,
          "Proposal Not Selected",
          "Your proposal was not selected. Keep submitting!",
          {route: `/vendor/requests`, type: "proposalRejected"}
        ),
      ]);
    }

    // Notify customer when vendor withdraws
    if (after.status === "withdrawn") {
      await createNotification(
        customerId,
        "proposalWithdrawn",
        "Proposal Withdrawn",
        "A vendor has withdrawn their proposal from your request.",
        proposalId
      );
    }
  }
);

// ── 5. Order Status Updated ───────────────────────────────────────────────────
// Notify customer and vendor on every order status change

export const onOrderStatusChanged = onDocumentUpdated(
  "orders/{orderId}",
  async (event) => {
    const before = event.data?.before.data();
    const after = event.data?.after.data();
    if (!before || !after) return;

    if (before.status === after.status) return;

    const orderId = event.params.orderId;
    const customerId: string = after.customerId;
    const vendorId: string = after.vendorId;
    const status: string = after.status;

    const statusMessages: Record<string, {title: string; body: string; vendorBody?: string}> = {
      accepted: {
        title: "Order Accepted ✅",
        body: "Your order has been accepted by the shop owner and is being prepared.",
        vendorBody: "You accepted the order. Start preparing it now.",
      },
      preparing: {
        title: "Order Being Prepared 📦",
        body: "Your order is being prepared by the shop owner.",
      },
      readyForDelivery: {
        title: "Order Ready 🚀",
        body: "Your order is ready and waiting for pickup by the delivery rider.",
      },
      outForDelivery: {
        title: "Out for Delivery 🛵",
        body: "Your order is on its way! The rider is heading to your location.",
      },
      delivered: {
        title: "Order Delivered 📍",
        body: "Your order has been delivered. Please confirm receipt.",
      },
      completed: {
        title: "Order Completed 🎉",
        body: "Your order is complete. Thank you for using Speedmart Lanka!",
        vendorBody: "Order completed. Payment will be processed shortly.",
      },
      cancelled: {
        title: "Order Cancelled ❌",
        body: "Your order has been cancelled.",
        vendorBody: "The order has been cancelled.",
      },
    };

    const msg = statusMessages[status];
    if (!msg) return;

    const promises: Promise<void>[] = [
      createNotification(
        customerId,
        "orderStatusUpdated",
        msg.title,
        msg.body,
        orderId,
        {orderId, status}
      ),
      sendPushNotification(
        customerId,
        msg.title,
        msg.body,
        {route: `/customer/orders/${orderId}`, type: "orderStatusUpdated", orderId, status}
      ),
    ];

    if (msg.vendorBody) {
      promises.push(
        createNotification(
          vendorId,
          "orderStatusUpdated",
          msg.title,
          msg.vendorBody,
          orderId,
          {orderId, status}
        ),
        sendPushNotification(
          vendorId,
          msg.title,
          msg.vendorBody,
          {route: `/vendor/orders/${orderId}`, type: "orderStatusUpdated", orderId, status}
        )
      );
    }

    await Promise.all(promises);
    await logActivity("update", "orders", orderId, vendorId, `Order status → ${status}`);
  }
);

// ── 5b. Bank Transfer Payment Events ─────────────────────────────────────────
// Two triggers on the `payments` collection:
//
//  A) Customer submits receipt (status: pending → pendingBankTransfer)
//     → Push the VENDOR so they know to open the order and verify,
//       even if their app is completely closed.
//
//  B) Vendor confirms payment received (status: pendingBankTransfer → paid)
//     → Push the CUSTOMER so they know their order is now being prepared,
//       even if their app is completely closed.
//
// Previously both of these only wrote a Firestore notification doc — meaning
// the recipient had to open the app and check manually. These triggers ensure
// a real device-level push is delivered.

export const onBankTransferReceiptSubmitted = onDocumentUpdated(
  "payments/{paymentId}",
  async (event) => {
    const before = event.data?.before.data();
    const after  = event.data?.after.data();
    if (!before || !after) return;

    const beforeStatus: string = before.paymentStatus ?? "";
    const afterStatus:  string = after.paymentStatus  ?? "";

    // ── A) Customer submitted receipt ────────────────────────────────────────
    if (
      beforeStatus !== "pendingBankTransfer" &&
      afterStatus  === "pendingBankTransfer"
    ) {
      const vendorId:   string = after.vendorId   ?? "";
      const customerId: string = after.customerId ?? "";
      const orderId:    string = after.orderId    ?? "";
      const amount:     number = after.amount     ?? 0;

      if (!vendorId) return;

      const hasReceipt = !!(after.receiptImageUrl ?? "");
      const receiptNote = hasReceipt
        ? " They uploaded a receipt — tap to verify."
        : " Please check your banking app and verify the transfer.";

      await Promise.all([
        // Firestore notification doc (in-app notification center)
        createNotification(
          vendorId,
          "bankTransferReceiptSubmitted",
          "Bank Transfer Submitted 🏦",
          `Customer confirmed a bank transfer of Rs. ${amount.toFixed(2)} for order ${orderId}.${receiptNote}`,
          orderId,
          { orderId, customerId, hasReceipt: String(hasReceipt) }
        ),
        // Real FCM push (works when app is closed/backgrounded)
        sendPushNotification(
          vendorId,
          "Bank Transfer Submitted 🏦",
          `Customer confirmed Rs. ${amount.toFixed(2)} transfer for order ${orderId}.${receiptNote}`,
          {
            route:    `/vendor/orders/${orderId}`,
            type:     "bankTransferReceiptSubmitted",
            orderId,
          }
        ),
      ]);

      console.log(`[BankTransfer] Receipt submitted for order ${sanitize(orderId)} — vendor ${sanitize(vendorId)} notified.`);
    }

    // ── B) Vendor confirmed payment ──────────────────────────────────────────
    if (
      beforeStatus !== "paid" &&
      afterStatus  === "paid" &&
      (before.paymentMethod === "bankTransfer" || after.paymentMethod === "bankTransfer")
    ) {
      const customerId: string = after.customerId ?? "";
      const orderId:    string = after.orderId    ?? "";
      const amount:     number = after.amount     ?? 0;

      if (!customerId) return;

      await Promise.all([
        // Firestore notification doc (in-app notification center)
        createNotification(
          customerId,
          "bankTransferConfirmed",
          "Payment Verified ✅",
          `Your bank transfer of Rs. ${amount.toFixed(2)} for order ${orderId} has been verified. The vendor will now start preparing your order.`,
          orderId,
          { orderId }
        ),
        // Real FCM push (works when app is closed/backgrounded)
        sendPushNotification(
          customerId,
          "Payment Verified ✅",
          `Your bank transfer for order ${orderId} is confirmed. Preparing your order now!`,
          {
            route:  `/customer/orders/${orderId}`,
            type:   "bankTransferConfirmed",
            orderId,
          }
        ),
      ]);

      console.log(`[BankTransfer] Payment confirmed for order ${sanitize(orderId)} — customer ${sanitize(customerId)} notified.`);
    }
  }
);

// ── 6. Activity Log — Admin Actions ──────────────────────────────────────────
// Log all writes to sensitive admin-managed collections

export const logCategoryChanges = onDocumentWritten(
  "categories/{categoryId}",
  async (event) => {
    const categoryId = event.params.categoryId;
    const after = event.data?.after;
    const before = event.data?.before;

    let action = "update";
    if (!before?.exists) action = "create";
    else if (!after?.exists) action = "delete";

    const name = after?.data()?.name ?? before?.data()?.name ?? categoryId;
    await logActivity(action, "categories", categoryId, "admin", `Category: ${name}`);
  }
);

export const logDeliveryAreaChanges = onDocumentWritten(
  "delivery_areas/{areaId}",
  async (event) => {
    const areaId = event.params.areaId;
    const after = event.data?.after;
    const before = event.data?.before;

    let action = "update";
    if (!before?.exists) action = "create";
    else if (!after?.exists) action = "delete";

    const name = after?.data()?.name ?? before?.data()?.name ?? areaId;
    await logActivity(action, "delivery_areas", areaId, "admin", `Delivery area: ${name}`);
  }
);

// ── 7. Cleanup Stale FCM Tokens (Scheduled) ───────────────────────────────────
// Runs every Sunday at midnight to remove invalid FCM tokens

export const cleanupStaleFcmTokens = onSchedule(
  "every sunday 00:00",
  async () => {
  const collections = ["customers", "vendors", "admins"];

  for (const col of collections) {
    const snap = await db.collection(`users/${col}/profiles`).get();
    const batch = db.batch();
    let count = 0;

    for (const doc of snap.docs) {
      const token = doc.data().fcmToken;
      if (!token) continue;

      try {
        // Dry-run send to validate token
        await messaging.send({token, condition: "false"}, true);
      } catch (e: unknown) {
        const code = (e as {code?: string}).code;
        if (
          code === "messaging/invalid-registration-token" ||
          code === "messaging/registration-token-not-registered"
        ) {
          batch.update(doc.ref, {fcmToken: admin.firestore.FieldValue.delete()});
          count++;
        }
      }
    }

    if (count > 0) {
      await batch.commit();
      console.log(`[Cleanup] Removed ${count} stale FCM tokens from ${col}`);
    }
  }
});

// ── 7b. Cleanup Old Notifications (Scheduled) ────────────────────────────────
// Runs every night at 2 AM — deletes notification docs older than 30 days.
// Prevents the /notifications collection from bloating and running up
// Firestore read/write costs indefinitely.

export const cleanupOldNotifications = onSchedule(
  "every day 02:00",
  async () => {
    const cutoff = new Date();
    cutoff.setDate(cutoff.getDate() - 30);
    const cutoffIso = cutoff.toISOString();

    const snap = await db
      .collection("notifications")
      .where("createdAt", "<", cutoffIso)
      .limit(400) // process in chunks to stay within batch limit
      .get();

    if (snap.empty) {
      console.log("[Cleanup] No old notifications to purge.");
      return;
    }

    const batch = db.batch();
    snap.docs.forEach((doc) => batch.delete(doc.ref));
    await batch.commit();
    console.log(`[Cleanup] Deleted ${snap.size} notifications older than 30 days.`);
  }
);

// ── 8. Send Notification (Callable) ──────────────────────────────────────────
// Admin can trigger a manual push notification from the admin web panel

export const sendAdminNotification = onCall({memory: '128MiB', timeoutSeconds: 60}, async (request) => {
  // Only allow authenticated admins
  if (!request.auth) throw new HttpsError("unauthenticated", "Must be signed in.");

  const callerDoc = await db.doc(`users/admins/profiles/${request.auth.uid}`).get();
  if (!callerDoc.exists) throw new HttpsError("permission-denied", "Admin only.");

  const {userId, title, body, type, relatedId} = request.data as {
    userId: string;
    title: string;
    body: string;
    type: string;
    relatedId?: string;
  };

  if (!userId || !title || !body) {
    throw new HttpsError("invalid-argument", "userId, title and body are required.");
  }

  await Promise.all([
    createNotification(userId, type ?? "adminMessage", title, body, relatedId),
    sendPushNotification(userId, title, body, {type: type ?? "adminMessage"}),
    logActivity("notify", "notifications", userId, request.auth.uid, `Manual: ${title}`),
  ]);

  return {success: true};
});

// ── Haversine distance helper (exported for use in other modules) ─────────────

export function haversineKm(lat1: number, lon1: number, lat2: number, lon2: number): number {
  const R = 6371;
  const dLat = toRad(lat2 - lat1);
  const dLon = toRad(lon2 - lon1);
  const a =
    Math.sin(dLat / 2) ** 2 +
    Math.cos(toRad(lat1)) * Math.cos(toRad(lat2)) * Math.sin(dLon / 2) ** 2;
  return R * 2 * Math.atan2(Math.sqrt(a), Math.sqrt(1 - a));
}

function toRad(deg: number): number {
  return (deg * Math.PI) / 180;
}

// ── Commission Payment Triggers ───────────────────────────────────────────────

/**
 * Fires when a vendor submits (or resubmits) a bank transfer receipt.
 * Notifies all admin users to review the receipt.
 */
export const onCommissionReceiptSubmitted = onDocumentUpdated(
  "vendor_commission_payments/{paymentId}",
  async (event) => {
    const before = event.data?.before.data();
    const after = event.data?.after.data();
    if (!before || !after) return;

    // Only fire when status transitions to receiptSubmitted
    const wasSubmitted = before.status === "receiptSubmitted";
    const isNowSubmitted = after.status === "receiptSubmitted";
    if (wasSubmitted || !isNowSubmitted) return;

    const vendorName: string = after.vendor_name ?? "A vendor";
    const amountOwed: number = after.amount_owed ?? 0;
    const paymentId: string = event.params.paymentId;

    // Notify all admins
    const adminSnap = await db.collection("users/admins/profiles").get();
    const notifyTasks = adminSnap.docs.map((adminDoc) => {
      const adminId = adminDoc.id;
      const title = "💰 Commission Receipt Submitted";
      const body = `${vendorName} submitted a payment receipt for Rs. ${amountOwed.toFixed(2)}. Please review.`;
      return Promise.all([
        sendPushNotification(adminId, title, body, {
          type: "commissionReceiptSubmitted",
          paymentId,
          vendorId: after.vendor_id ?? "",
        }),
        createNotification(
          adminId,
          "commissionReceiptSubmitted",
          title,
          body,
          paymentId,
          {vendorId: after.vendor_id, amountOwed}
        ),
      ]);
    });

    await Promise.allSettled(notifyTasks);
    console.log(`[Commission] Receipt submitted notification sent for ${sanitize(paymentId)}`);
  }
);

/**
 * Fires when an admin reviews a commission receipt (status → accepted or partial).
 * Notifies the vendor of the outcome and updated balance.
 */
export const onCommissionReceiptReviewed = onDocumentUpdated(
  "vendor_commission_payments/{paymentId}",
  async (event) => {
    const before = event.data?.before.data();
    const after = event.data?.after.data();
    if (!before || !after) return;

    const reviewStatuses = ["accepted", "partial"];
    const wasReviewed = reviewStatuses.includes(before.status);
    const isNowReviewed = reviewStatuses.includes(after.status);

    // Only fire on transition into a reviewed state
    if (wasReviewed || !isNowReviewed) return;

    const vendorId: string = after.vendor_id ?? "";
    if (!vendorId) return;

    const paymentId: string = event.params.paymentId;
    const amountOwed: number = after.amount_owed ?? 0;
    const amountPaid: number = after.amount_paid ?? 0;
    const isFullyPaid = amountOwed <= 0;

    const title = isFullyPaid
      ? "✅ Commission Receipt Accepted"
      : "📋 Partial Payment Recorded";

    const body = isFullyPaid
      ? `Your commission payment of Rs. ${amountPaid.toFixed(2)} has been verified. Your balance is now cleared.`
      : `Rs. ${amountPaid.toFixed(2)} confirmed. You still owe Rs. ${amountOwed.toFixed(2)}. Please complete the remaining balance.`;

    await Promise.all([
      sendPushNotification(vendorId, title, body, {
        type: "commissionReceiptReviewed",
        paymentId,
        amountOwed: amountOwed.toString(),
      }),
      createNotification(
        vendorId,
        "commissionReceiptReviewed",
        title,
        body,
        paymentId,
        {amountPaid, amountOwed, isFullyPaid}
      ),
    ]);

    console.log(`[Commission] Review notification sent to vendor ${sanitize(vendorId)} for ${sanitize(paymentId)}`);
  }
);
