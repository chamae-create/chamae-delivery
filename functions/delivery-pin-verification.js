"use strict";
const {createHash, createHmac} = require("node:crypto");
const {HttpsError, onCall} = require("firebase-functions/v2/https");
const {defineSecret} = require("firebase-functions/params");
const {Timestamp} = require("firebase-admin/firestore");
const {requireApprovedCourier} = require("./courier-authorization");
const {assertCustomerAccountActive} = require("./customer-account-state");
const {assertCurrentCourierAcceptance} = require("./courier-policy");
const {decryptPin, newOrderVerifier, checkAttempt} = require("./delivery-pin");
const pinKey = defineSecret("CHAMAE_DELIVERY_PIN_KEY");
const hash = (s) => createHash("sha256").update(s).digest("hex");
const id = (s) => typeof s === "string" && /^[A-Za-z0-9_-]{1,128}$/.test(s);
const deny = (reason) => { throw new HttpsError("failed-precondition", reason, {reason}); };

// Online reconciliation only. The server HMAC/digest, encrypted fixed customer
// PIN and typed attempt never appear in the response or courier offline package.
async function verifyOrderPin(db, request, key) {
  const data = request.data;
  if (!data || Object.keys(data).some((k) => !["orderId", "assignmentId", "requestId", "pin"].includes(k)) ||
      !id(data.orderId) || !id(data.assignmentId) || !id(data.requestId) || data.requestId.length < 16 ||
      typeof data.pin !== "string" || !/^\d{4}$/.test(data.pin)) {
    throw new HttpsError("invalid-argument", "PIN_REQUEST_INVALID");
  }
  if (!/^[a-fA-F0-9]{64}$/.test(key || "")) deny("PIN_KEY_NOT_CONFIGURED");
  return db.runTransaction(async (tx) => {
    const courier = await requireApprovedCourier(db, request, tx);
    await assertCurrentCourierAcceptance(db, courier.uid, tx);
    const order = (await tx.get(db.doc(`orders/${data.orderId}`))).data();
    const binding = (await tx.get(db.doc(`courierPickupAssignments/${data.assignmentId}`))).data();
    const grant = (await tx.get(db.doc(`courierPickupGrants/${data.orderId}`))).data();
    const now = Date.now();
    if (courier.profile.online !== true || !order || order.status !== "Saiu para Entrega" ||
        order.courierDeliveryPhase !== "arrived" ||
        order.financialValidationStatus !== "validated" || order.courierUid !== courier.uid ||
        order.courierAssignmentId !== data.assignmentId ||
        !(order.courierAssignmentExpiresAt instanceof Timestamp) || order.courierAssignmentExpiresAt.toMillis() <= now ||
        !binding || binding.status !== "pickedUp" || binding.courierUid !== courier.uid || binding.orderId !== data.orderId ||
        !grant || grant.assignmentId !== data.assignmentId || grant.courierUid !== courier.uid ||
        !(grant.expiresAt instanceof Timestamp) || grant.expiresAt.toMillis() <= now) deny("PIN_ASSIGNMENT_INVALID");
    if (typeof order.customerUid !== "string" || !order.customerUid || order.customerUid.length > 128 ||
        order.customerUid.includes("/") || [".", ".."].includes(order.customerUid)) deny("PIN_CUSTOMER_UNAVAILABLE");
    await assertCustomerAccountActive(db, order.customerUid, tx);
    await require("./age-delivery-policy").assertOrderRecipient(tx, db, order, {orderId: data.orderId, assignmentId: data.assignmentId, courierUid: courier.uid});
    const ref = db.doc(`deliveryPinVerifiers/${data.orderId}`);
    const snapshot = await tx.get(ref);
    const secret = await tx.get(db.doc(`customerDeliverySecrets/${order.customerUid}`));
    if (!secret.exists || !Number.isSafeInteger(secret.data().revision) || secret.data().revision < 1) {
      deny("PIN_CUSTOMER_UNAVAILABLE");
    }
    const fingerprint = createHmac("sha256", Buffer.from(key, "hex"))
        .update(JSON.stringify([courier.uid, data.orderId, data.assignmentId, data.requestId, data.pin])).digest("hex");
    const requestKey = hash(`${courier.uid}:${data.requestId}`);
    const old = snapshot.exists ? snapshot.data() : null;
    if (old && (old.uid !== order.customerUid || old.customerRevision !== secret.data().revision)) {
      deny("PIN_REVISION_CHANGED");
    }
    if (old && (!old.record || !old.requests || typeof old.requests !== "object" ||
        Array.isArray(old.requests) || Object.keys(old.requests).length > 5)) deny("PIN_RECORD_INVALID");
    const previous = old?.requests?.[requestKey];
    if (previous) {
      if (previous.fingerprint !== fingerprint) deny("PIN_REQUEST_ID_REUSED");
      return {...previous.result, replayed: true};
    }
    // Only the same authoritative order consumes the global attempt budget.
    // Assignment transfers cannot reset that budget or reuse another UID's ACK.
    const record = old?.record || newOrderVerifier(decryptPin(secret.data().encrypted,
        order.customerUid, key), order.customerUid, data.orderId, key);
    const checked = checkAttempt(record, data.pin, order.customerUid, data.orderId, key);
    if (!checked.allowed) return {orderId: data.orderId, verified: false,
      remainingAttempts: 0, reason: "PIN_LOCKED_OR_RECONCILED", replayed: false};
    const result = {orderId: data.orderId, assignmentId: data.assignmentId,
      verified: checked.matched, remainingAttempts: checked.record.maxAttempts - checked.record.attempts,
      ...(checked.matched ? {verificationId: requestKey} : {}), replayed: false};
    const stamp = Timestamp.now();
    tx.set(ref, {uid: order.customerUid, customerRevision: secret.data().revision, record: checked.record,
      requests: {...old?.requests, [requestKey]: {fingerprint, result}}, updatedAt: stamp,
      ...(checked.matched ? {verifiedCourierUid: courier.uid, verifiedAssignmentId: data.assignmentId,
        verificationId: requestKey, verifiedAt: stamp} : {})});
    // Existing deletion worker already removes deliveryPinVerifiers/{orderId}
    // and deliveryPinAudit rows by uid. No new unmanaged personal collection.
    tx.create(db.doc(`deliveryPinAudit/${requestKey}`), {uid: order.customerUid,
      orderId: data.orderId, operation: "order_attempt", matched: checked.matched, at: stamp});
    return result;
  });
}
function createDeliveryPinVerification(db) {
  return {chamaeVerificarPinPedido: onCall({region: "southamerica-east1", maxInstances: 1,
    secrets: [pinKey]}, (r) => verifyOrderPin(db, r, pinKey.value()))};
}
module.exports = {verifyOrderPin, createDeliveryPinVerification};
