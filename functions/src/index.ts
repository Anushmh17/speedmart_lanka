import * as admin from "firebase-admin";
import {onDocumentCreated, onDocumentUpdated, onDocumentWritten} from "firebase-functions/v2/firestore";
import {onCall, onRequest, HttpsError} from "firebase-functions/v2/https";
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

function normalizeSriLankaPhone(phone: string): string {
  const digits = phone.replace(/[^\d]/g, "");
  if (digits.startsWith("94") && digits.length === 11) return `+${digits}`;
  if (digits.startsWith("0") && digits.length === 10) return `+94${digits.substring(1)}`;
  if (digits.length === 9) return `+94${digits}`;
  return phone.trim();
}

function normalizeEmail(value?: string | null): string {
  return (value ?? "").trim().toLowerCase();
}

function normalizeNic(value?: string | null): string {
  return (value ?? "").trim().toUpperCase();
}

function isSriLankaNic(value?: string | null): boolean {
  if (!value) return false;
  const cleaned = (value ?? "").replace(/[^A-Za-z0-9]/g, '').toUpperCase();
  // Old format: 9 digits + V (X not accepted)
  if (/^[0-9]{9}V$/.test(cleaned)) return true;
  // New format: 12 digits
  if (/^[0-9]{12}$/.test(cleaned)) return true;
  return false;
}

function nicEncodesValidDob(value?: string | null): boolean {
  if (!value) return false;
  const cleaned = (value ?? "").replace(/[^0-9A-Za-z]/g, '').toUpperCase();
  const now = new Date().getFullYear();

  if (/^[0-9]{9}V$/.test(cleaned)) {
    const yy = parseInt(cleaned.substring(0, 2), 10);
    const ddd = parseInt(cleaned.substring(2, 5), 10);
    if (Number.isNaN(yy) || Number.isNaN(ddd)) return false;
    let year = 1900 + yy;
    let age = now - year;
    if (age < 10) year = 2000 + yy;
    if (year > now || now - year > 120) return false;
    let dayOfYear = ddd;
    if (dayOfYear > 500) dayOfYear -= 500;
    if (dayOfYear < 1) return false;
    const isLeap = (year % 4 === 0 && (year % 100 !== 0 || year % 400 === 0));
    const maxDay = isLeap ? 366 : 365;
    if (dayOfYear > maxDay) return false;
    return true;
  }

  if (/^[0-9]{12}$/.test(cleaned)) {
    const year = parseInt(cleaned.substring(0, 4), 10);
    const ddd = parseInt(cleaned.substring(4, 7), 10);
    if (Number.isNaN(year) || Number.isNaN(ddd)) return false;
    if (year > now || now - year > 120) return false;
    let dayOfYear = ddd;
    if (dayOfYear > 500) dayOfYear -= 500;
    if (dayOfYear < 1) return false;
    const isLeap = (year % 4 === 0 && (year % 100 !== 0 || year % 400 === 0));
    const maxDay = isLeap ? 366 : 365;
    if (dayOfYear > maxDay) return false;
    return true;
  }

  return false;
}

function makeLockId(kind: string, value: string): string {
  return `${kind}_${encodeURIComponent(value)}`;
}

function parseIso(value: unknown): number | null {
  if (typeof value !== "string" || value.trim().length === 0) return null;
  const millis = Date.parse(value);
  return Number.isNaN(millis) ? null : millis;
}

type CustomerRegistrationRequest = {
  fullName?: string;
  email?: string;
  phone?: string;
  nic?: string;
  detectedCountry?: string;
  detectionSource?: string;
  riskFlag?: string;
  verifiedPhone?: boolean;
  verifiedEmail?: boolean;
  deliveryCountry?: string;
  deliveryProvince?: string;
  deliveryDistrict?: string;
  deliveryApproxArea?: string;
  deliveryPreciseAddress?: string;
  deliveryNote?: string;
  deliveryLatitude?: number | null;
  deliveryLongitude?: number | null;
};

export const registerCustomerAccount = onRequest(async (request, response) => {
  response.set("Access-Control-Allow-Origin", "*");
  response.set("Access-Control-Allow-Headers", "Authorization, Content-Type");
  response.set("Access-Control-Allow-Methods", "POST, OPTIONS");

  if (request.method === "OPTIONS") {
    response.status(204).send("");
    return;
  }

  if (request.method !== "POST") {
    response.status(405).json({error: "Method not allowed"});
    return;
  }

  const authHeader = request.get("authorization") ?? "";
  const token = authHeader.startsWith("Bearer ") ? authHeader.substring(7).trim() : "";
  if (!token) {
    throw new HttpsError("unauthenticated", "Missing Firebase ID token.");
  }

  const decoded = await admin.auth().verifyIdToken(token);
  // Ensure the ID token belongs to a phone-authenticated user (SMS OTP)
  const signInProvider = (decoded.firebase && (decoded.firebase as any).sign_in_provider) || (decoded.sign_in_provider as any) || '';
  const verifiedPhone = normalizeSriLankaPhone(decoded.phone_number ?? "");
  if (!verifiedPhone || signInProvider !== 'phone') {
    throw new HttpsError("failed-precondition", "Phone authentication (SMS OTP) is required.");
  }

  const body = request.body as CustomerRegistrationRequest;
  const fullName = (body.fullName ?? "").trim();
  const email = normalizeEmail(body.email);
  const bodyPhone = normalizeSriLankaPhone(body.phone ?? "");
  const nic = normalizeNic(body.nic);

  if (!fullName) {
    throw new HttpsError("invalid-argument", "fullName is required.");
  }

  if (nic && nic.length > 0) {
    if (!isSriLankaNic(nic) || !nicEncodesValidDob(nic)) {
      throw new HttpsError("invalid-argument", "NIC format is invalid or encodes an impossible date for Sri Lanka.");
    }
  }

  if (bodyPhone !== verifiedPhone) {
    throw new HttpsError("permission-denied", "Verified phone number does not match the requested phone.");
  }

  const phoneLockRef = db.doc(`registration_locks/customer_phone/${makeLockId("phone", bodyPhone)}`);
  const emailLockRef = email ? db.doc(`registration_locks/customer_email/${makeLockId("email", email)}`) : null;
  const nicLockRef = nic ? db.doc(`registration_locks/customer_nic/${makeLockId("nic", nic)}`) : null;
  const rateLimitRef = db.doc(`registration_attempts/${decoded.uid}`);
  const rateLimitSnap = await rateLimitRef.get();
  const lastAttemptMs = parseIso(rateLimitSnap.data()?.lastAttemptAt);
  if (lastAttemptMs != null && Date.now() - lastAttemptMs < 15000) {
    throw new HttpsError("resource-exhausted", "Please wait a moment before trying again.");
  }

  const profileRef = db.collection("users/customers/profiles").doc();
  const userData: Record<string, unknown> = {
    id: profileRef.id,
    full_name: fullName,
    email,
    phone: bodyPhone,
    role: "customer",
    is_active: true,
    is_verified: body.verifiedPhone ?? true,
    created_at: new Date().toISOString(),
    nic: nic || null,
    verified_phone: body.verifiedPhone ?? true,
    verified_email: body.verifiedEmail ?? false,
    detected_country: body.detectedCountry ?? "LK",
    detection_source: body.detectionSource ?? "app_default",
    risk_flag: body.riskFlag ?? null,
    delivery_country: body.deliveryCountry ?? "Sri Lanka",
    delivery_province: body.deliveryProvince ?? null,
    delivery_district: body.deliveryDistrict ?? null,
    delivery_approx_area: body.deliveryApproxArea ?? null,
    delivery_precise_address: body.deliveryPreciseAddress ?? null,
    delivery_note: body.deliveryNote ?? null,
    delivery_latitude: body.deliveryLatitude ?? null,
    delivery_longitude: body.deliveryLongitude ?? null,
  };

  await db.runTransaction(async (transaction) => {
    const [phoneSnap, emailSnap, nicSnap] = await Promise.all([
      transaction.get(phoneLockRef),
      emailLockRef ? transaction.get(emailLockRef) : Promise.resolve(null),
      nicLockRef ? transaction.get(nicLockRef) : Promise.resolve(null),
    ]);

    if (phoneSnap.exists) {
      throw new HttpsError("already-exists", "An account with this phone number already exists.");
    }
    if (emailSnap?.exists) {
      throw new HttpsError("already-exists", "An account with this email already exists.");
    }
    if (nicSnap?.exists) {
      throw new HttpsError("already-exists", "An account with this NIC number already exists.");
    }

    transaction.set(profileRef, userData);
    transaction.set(phoneLockRef, {
      kind: "phone",
      value: bodyPhone,
      userId: profileRef.id,
      authUid: decoded.uid,
      createdAt: admin.firestore.FieldValue.serverTimestamp(),
    });

    if (emailLockRef) {
      transaction.set(emailLockRef, {
        kind: "email",
        value: email,
        userId: profileRef.id,
        authUid: decoded.uid,
        createdAt: admin.firestore.FieldValue.serverTimestamp(),
      });
    }

    if (nicLockRef) {
      transaction.set(nicLockRef, {
        kind: "nic",
        value: nic,
        userId: profileRef.id,
        authUid: decoded.uid,
        createdAt: admin.firestore.FieldValue.serverTimestamp(),
      });
    }

    transaction.set(rateLimitRef, {
      lastAttemptAt: new Date().toISOString(),
      authUid: decoded.uid,
      phone: verifiedPhone,
    }, {merge: true});
  });

  response.json({
    success: true,
    token: `auth_token_${profileRef.id}_${Date.now()}`,
    user: userData,
  });
});

export const registerVendorAccount = onRequest(async (request, response) => {
  response.set("Access-Control-Allow-Origin", "*");
  response.set("Access-Control-Allow-Headers", "Authorization, Content-Type");
  response.set("Access-Control-Allow-Methods", "POST, OPTIONS");

  if (request.method === "OPTIONS") {
    response.status(204).send("");
    return;
  }

  if (request.method !== "POST") {
    response.status(405).json({error: "Method not allowed"});
    return;
  }

  const authHeader = request.get("authorization") ?? "";
  const token = authHeader.startsWith("Bearer ") ? authHeader.substring(7).trim() : "";
  if (!token) {
    throw new HttpsError("unauthenticated", "Missing Firebase ID token.");
  }

  const decoded = await admin.auth().verifyIdToken(token);
  const signInProvider = (decoded.firebase && (decoded.firebase as any).sign_in_provider) || (decoded.sign_in_provider as any) || '';

  // Prefer the phone number carried in the ID token (when signed-in via phone),
  // but also allow email/password authenticated tokens if the Firebase user
  // record has a linked phoneNumber that matches (i.e. phone was previously
  // linked via `linkWithCredential`). This ensures vendors can sign in with
  // email/password while still proving control of the verified phone.
  let verifiedPhone = normalizeSriLankaPhone(decoded.phone_number ?? "");
  let phoneLinked = false;

  if (signInProvider === 'phone' && verifiedPhone) {
    phoneLinked = true;
  } else {
    // Try to fetch the user record and verify a linked phone exists and
    // matches a normalized phone number.
    try {
      const userRecord = await admin.auth().getUser(decoded.uid);
      const userPhone = normalizeSriLankaPhone(userRecord.phoneNumber ?? "");
      if (userPhone) {
        verifiedPhone = userPhone;
        // Consider the phone linked if the record has a phoneNumber or a
        // provider entry for the phone provider.
        phoneLinked = !!userRecord.phoneNumber || (userRecord.providerData || []).some((p: any) => p && p.providerId === 'phone');
      }
    } catch (err) {
      throw new HttpsError('unauthenticated', 'Failed to validate Firebase user record.');
    }
  }

  if (!verifiedPhone || !phoneLinked) {
    throw new HttpsError("failed-precondition", "Phone authentication (SMS OTP) is required or the phone must be linked to the account.");
  }

  const body = request.body as any;
  const fullName = (body.fullName ?? "").trim();
  const email = normalizeEmail(body.email);
  const bodyPhone = normalizeSriLankaPhone(body.phone ?? "");
  const nic = normalizeNic(body.nic);

  if (!fullName) {
    throw new HttpsError("invalid-argument", "fullName is required.");
  }

  if (nic && nic.length > 0) {
    if (!isSriLankaNic(nic) || !nicEncodesValidDob(nic)) {
      throw new HttpsError("invalid-argument", "NIC format is invalid or encodes an impossible date for Sri Lanka.");
    }
  }

  if (bodyPhone !== verifiedPhone) {
    throw new HttpsError("permission-denied", "Verified phone number does not match the requested phone.");
  }

  const phoneLockRef = db.doc(`registration_locks/vendor_phone/${makeLockId("phone", bodyPhone)}`);
  const emailLockRef = email ? db.doc(`registration_locks/vendor_email/${makeLockId("email", email)}`) : null;
  const nicLockRef = nic ? db.doc(`registration_locks/vendor_nic/${makeLockId("nic", nic)}`) : null;
  const rateLimitRef = db.doc(`registration_attempts/${decoded.uid}`);
  const rateLimitSnap = await rateLimitRef.get();
  const lastAttemptMs = parseIso(rateLimitSnap.data()?.lastAttemptAt);
  if (lastAttemptMs != null && Date.now() - lastAttemptMs < 15000) {
    throw new HttpsError("resource-exhausted", "Please wait a moment before trying again.");
  }

  const profileRef = db.collection("users/vendors/profiles").doc();
  const userData: Record<string, unknown> = {
    id: profileRef.id,
    full_name: fullName,
    email,
    phone: bodyPhone,
    role: "vendor",
    is_active: false,
    is_verified: body.verifiedPhone ?? true,
    created_at: new Date().toISOString(),
    nic: nic || null,
    verified_phone: body.verifiedPhone ?? true,
    verified_email: body.verifiedEmail ?? false,
    detected_country: body.detectedCountry ?? "LK",
    detection_source: body.detectionSource ?? "app_default",
    risk_flag: body.riskFlag ?? null,
    business_registration_number: body.businessRegistrationNumber ?? null,
    business_name: body.businessName ?? null,
    shop_address: body.shopAddress ?? null,
    shop_province: body.shopProvince ?? null,
    shop_district: body.shopDistrict ?? null,
    shop_area: body.shopArea ?? null,
    shop_latitude: body.shopLatitude ?? null,
    shop_longitude: body.shopLongitude ?? null,
    shop_location_accuracy_meters: body.shopLocationAccuracyMeters ?? null,
    shop_location_detected_at: body.shopLocationDetectedAt ?? null,
    shop_location_source: body.shopLocationSource ?? null,
  };

  await db.runTransaction(async (transaction) => {
    const [phoneSnap, emailSnap, nicSnap] = await Promise.all([
      transaction.get(phoneLockRef),
      emailLockRef ? transaction.get(emailLockRef) : Promise.resolve(null),
      nicLockRef ? transaction.get(nicLockRef) : Promise.resolve(null),
    ]);

    if (phoneSnap.exists) {
      throw new HttpsError("already-exists", "An account with this phone number already exists.");
    }
    if (emailSnap?.exists) {
      throw new HttpsError("already-exists", "An account with this email already exists.");
    }
    if (nicSnap?.exists) {
      throw new HttpsError("already-exists", "An account with this NIC number already exists.");
    }

    transaction.set(profileRef, userData);
    transaction.set(phoneLockRef, {
      kind: "phone",
      value: bodyPhone,
      userId: profileRef.id,
      authUid: decoded.uid,
      createdAt: admin.firestore.FieldValue.serverTimestamp(),
    });

    if (emailLockRef) {
      transaction.set(emailLockRef, {
        kind: "email",
        value: email,
        userId: profileRef.id,
        authUid: decoded.uid,
        createdAt: admin.firestore.FieldValue.serverTimestamp(),
      });
    }

    if (nicLockRef) {
      transaction.set(nicLockRef, {
        kind: "nic",
        value: nic,
        userId: profileRef.id,
        authUid: decoded.uid,
        createdAt: admin.firestore.FieldValue.serverTimestamp(),
      });
    }

    transaction.set(rateLimitRef, {
      lastAttemptAt: new Date().toISOString(),
      authUid: decoded.uid,
      phone: verifiedPhone,
    }, {merge: true});
  });

  response.json({
    success: true,
    token: `auth_token_${profileRef.id}_${Date.now()}`,
    user: userData,
  });
});

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
