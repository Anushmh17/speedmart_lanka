import * as admin from "firebase-admin";
import {onDocumentCreated, onDocumentUpdated, onDocumentWritten} from "firebase-functions/v2/firestore";
import {onCall, HttpsError} from "firebase-functions/v2/https";
import {onSchedule} from "firebase-functions/v2/scheduler";

admin.initializeApp();

const db = admin.firestore();
const messaging = admin.messaging();

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
    console.error(`[FCM] Failed to send to ${userId}:`, e);
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

// ── 1. Vendor Approved ────────────────────────────────────────────────────────
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

    // Vendor suspended
    if (before.vendorStatus !== "suspended" && after.vendorStatus === "suspended") {
      const name = after.businessName ?? after.fullName ?? "Shop Owner";

      await Promise.all([
        createNotification(
          vendorId,
          "vendorSuspended",
          "Account Suspended",
          "Your shop owner account has been suspended. Please contact support for assistance.",
          vendorId
        ),
        sendPushNotification(
          vendorId,
          "Account Suspended",
          "Your account has been suspended. Contact support for help.",
          {route: "/vendor/status", type: "vendorSuspended"}
        ),
        logActivity("suspend", "users/vendors/profiles", vendorId, "admin", `Vendor ${name} suspended`),
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
// Notify nearby vendors when a customer submits a new request

export const onNewRequest = onDocumentCreated(
  "requests/{requestId}",
  async (event) => {
    const request = event.data?.data();
    if (!request) return;

    const requestId = event.params.requestId;
    const customerArea = request.customerArea ?? "your area";

    // Get all approved active vendors
    const vendorsSnap = await db
      .collection("users/vendors/profiles")
      .where("vendorStatus", "==", "approved")
      .where("isActive", "==", true)
      .get();

    const notifyPromises: Promise<void>[] = [];

    for (const vendorDoc of vendorsSnap.docs) {
      const vendor = vendorDoc.data();
      const vendorId = vendorDoc.id;

      // Basic radius check using Haversine if vendor has coordinates
      if (vendor.shopLatitude && vendor.shopLongitude &&
          request.latitude && request.longitude) {
        const dist = haversineKm(
          vendor.shopLatitude, vendor.shopLongitude,
          request.latitude, request.longitude
        );
        const radius = vendor.assignedRadiusKm ?? 5;
        if (dist > radius) continue;
      }

      notifyPromises.push(
        createNotification(
          vendorId,
          "newNearbyRequest",
          "New Shopping Request Nearby 📍",
          `A customer in ${customerArea} needs items delivered. Submit your proposal now!`,
          requestId,
          {requestId}
        ),
        sendPushNotification(
          vendorId,
          "New Request Nearby 📍",
          `Customer in ${customerArea} needs delivery. Tap to view.`,
          {route: `/vendor/requests/${requestId}`, type: "newNearbyRequest", requestId}
        )
      );
    }

    await Promise.all(notifyPromises);
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
    const customerId: string = proposal.customerId;
    const vendorId: string = proposal.vendorId;

    // Get vendor name
    const vendorDoc = await db.doc(`users/vendors/profiles/${vendorId}`).get();
    const vendorName = vendorDoc.data()?.businessName ?? vendorDoc.data()?.fullName ?? "A shop owner";

    await Promise.all([
      createNotification(
        customerId,
        "newProposal",
        "New Proposal Received 💬",
        `${vendorName} has submitted a proposal for your shopping request.`,
        proposalId,
        {proposalId, requestId: proposal.requestId}
      ),
      sendPushNotification(
        customerId,
        "New Proposal 💬",
        `${vendorName} submitted a proposal. Tap to review.`,
        {route: `/customer/requests/${proposal.requestId}`, type: "newProposal", proposalId}
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

export const cleanupStaleFcmTokens = onSchedule("every sunday 00:00", async () => {
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

// ── 8. Send Notification (Callable) ──────────────────────────────────────────
// Admin can trigger a manual push notification from the admin web panel

export const sendAdminNotification = onCall(async (request) => {
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

// ── Haversine distance helper ─────────────────────────────────────────────────

function haversineKm(lat1: number, lon1: number, lat2: number, lon2: number): number {
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
