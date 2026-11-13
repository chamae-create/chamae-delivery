"use strict";
const {createHash} = require("node:crypto");
const {Timestamp, FieldValue} = require("firebase-admin/firestore");
const {HttpsError} = require("firebase-functions/v2/https");
const {requireApprovedCourier} = require("./courier-authorization");
const {assertCurrentCourierAcceptance} = require("./courier-policy");
const {assertCustomerAccountActive} = require("./customer-account-state");
const {readyForDispatch} = require("./courier-assignment");
const {planCourierDelivery, writeCourierDelivery} = require("./courier-deliveries");
const {moveOrder} = require("./order-operations");
const {revision} = require("./delivery-contingency-state");
const hash = (s) => createHash("sha256").update(s).digest("hex");
function reject(reason) { throw new HttpsError("failed-precondition", reason, {reason}); }
const live = (v) => v instanceof Timestamp && v.toMillis() > Date.now();
async function context(db, tx, request, event, replay) {
  const current = await requireApprovedCourier(db, request, tx);
  await assertCurrentCourierAcceptance(db, current.uid, tx);
  if (current.profile.online !== true) reject("SHIFT_OFF");
  const orderRef = db.doc("orders/" + event.orderId);
  const order = (await tx.get(orderRef)).data();
  const bindingRef = db.doc("courierPickupAssignments/" + event.assignmentId);
  const binding = (await tx.get(bindingRef)).data();
  const grantRef = db.doc("courierPickupGrants/" + event.orderId);
  const grant = (await tx.get(grantRef)).data();
  const supervisedCompletion = event.type === "confirmDelivery" && order?.status === "Concluído" &&
    order.completedAt instanceof Timestamp && order.deliveryConfirmedAt instanceof Timestamp &&
    order.deliveryCollectionConfirmedAt instanceof Timestamp && order.paidAt instanceof Timestamp &&
    order.paymentStatus === "Pago" && order.paymentConfirmedBy === "delivery_completion" &&
    order.stockReservationStatus === "finalized" && typeof order.completedBy === "string" && !!order.completedBy;
  if (!order || order.courierUid !== current.uid || order.courierAssignmentId !== event.assignmentId ||
      !live(order.courierAssignmentExpiresAt) || !live(grant?.expiresAt) ||
      grant?.courierUid !== current.uid || grant?.assignmentId !== event.assignmentId ||
      !/^[a-f0-9]{64}$/.test(grant?.digest || "") ||
      !/^[a-f0-9]{64}$/.test(grant?.sessionId || "") ||
      binding?.courierUid !== current.uid || binding?.orderId !== event.orderId ||
      !(binding?.status === "pickedUp" || replay && binding?.status === "delivered") ||
      order.status === "Cancelado" || order.status === "Concluído" && !replay && !supervisedCompletion) reject("ASSIGNMENT_CHANGED");
  if (typeof order.customerUid !== "string" || !order.customerUid ||
      order.customerUid.includes("/") || [".", ".."].includes(order.customerUid)) reject("CUSTOMER_UNAVAILABLE");
  await assertCustomerAccountActive(db, order.customerUid, tx);
  return {order, orderRef, bindingRef, grant, grantRef, supervisedCompletion};
}
function receipt(event, phase, grant) {
  return {receiptId: hash(event.courierUid + ":" + event.eventId), eventId: event.eventId,
    orderId: event.orderId, courierUid: event.courierUid, sequence: event.sequence,
    fingerprint: event.fingerprint, acceptedAtMs: Date.now(), authority: "backend", delivery: null,
    availabilityOn: null, deliveryAcknowledgement: {acknowledged: true,
      assignmentId: event.assignmentId, type: event.type, phase, packageDigest: grant.digest}};
}
async function submitDeliveryEvent(db, request, event, helpers) {
  if (typeof helpers?.checkFinancial !== "function" || typeof helpers?.resolveReservation !== "function") {
    reject("DELIVERY_FINALIZER_NOT_CONFIGURED");
  }
  return db.runTransaction(async (tx) => {
    const eventRef = db.doc("courierEventReceipts/" + hash(event.courierUid + ":" + event.eventId));
    const old = await tx.get(eventRef);
    if (old.exists && old.data().fingerprint !== event.fingerprint) reject("EVENT_ID_REUSED");
    const c = await context(db, tx, request, event, old.exists);
    if (old.exists) return old.data().receipt;
    const last = c.grant.lastDeliverySequence ?? 0;
    if (!Number.isSafeInteger(last) || last < 0 || event.sequence <= last) reject("EVENT_SEQUENCE_STALE");
    if (!readyForDispatch(c.order)) reject("DELIVERY_NOT_READY");
    const financial = await tx.get(db.doc("orderFinancials/" + event.orderId));
    if (!financial.exists) reject("FINANCIAL_RECORD_REQUIRED");
    helpers.checkFinancial(c.order, financial.data());
    let phase;
    const previousPhase = c.order.courierDeliveryPhase || "pickedUp";
    if (event.type === "startRoute") {
      if (c.order.status !== "Em Separação" || previousPhase !== "pickedUp") reject("DELIVERY_TRANSITION_INVALID");
      const previous = await tx.get(db.doc("courierDeliveries/" + event.orderId));
      const plan = planCourierDelivery({orderId: event.orderId, order: c.order,
        previous: previous.data() || {}, exists: previous.exists, registered: true, now: Timestamp.now(),
        binding: {courierUid: event.courierUid, status: "Saiu para Entrega"}});
      if (plan.revoked) reject("DELIVERY_PROJECTION_INVALID");
      phase = "headingToCustomer";
      tx.update(c.orderRef, {status: "Saiu para Entrega", dispatchedAt: FieldValue.serverTimestamp(),
        courierDeliveryPhase: phase});
      writeCourierDelivery(tx, {plan, deliveryRef: db.doc("courierDeliveries/" + event.orderId),
        auditRef: db.collection("courierDeliveryAudit").doc(), orderId: event.orderId,
        previous: previous.data() || {}, actorUid: event.courierUid});
    } else if (event.type === "arrived") {
      if (c.order.status !== "Saiu para Entrega" || previousPhase !== "headingToCustomer") reject("DELIVERY_TRANSITION_INVALID");
      phase = "arrived";
      tx.update(c.orderRef, {courierDeliveryPhase: phase, courierArrivedAt: FieldValue.serverTimestamp()});
    } else {
      if ((c.order.status !== "Saiu para Entrega" && !c.supervisedCompletion) || previousPhase !== "arrived") reject("DELIVERY_TRANSITION_INVALID");
      if (c.supervisedCompletion) {
        await require("./delivery-collection-contract").assertSupervisedCollection(tx, db, c.order,
            event.orderId, financial.data(), helpers.checkDeliveryPayment);
      }
      // A PIN is delivery evidence, never proof that an unpaid cash/card/mixed
      // amount was collected. Existing authoritative payment state is required.
      if (c.order.paymentStatus !== "Pago") reject("COLLECTION_CONFIRMATION_REQUIRED");
      const verifierRef = db.doc("deliveryPinVerifiers/" + event.orderId);
      const verifier = (await tx.get(verifierRef)).data();
      const secret = (await tx.get(db.doc("customerDeliverySecrets/" + c.order.customerUid))).data();
      if (!verifier || verifier.record?.reconciled !== true ||
          verifier.uid !== c.order.customerUid || verifier.customerRevision !== secret?.revision ||
          verifier.verifiedCourierUid !== event.courierUid || verifier.verifiedAssignmentId !== event.assignmentId ||
          verifier.verificationId !== event.payload.proof.verificationId ||
          !(verifier.verifiedAt instanceof Timestamp) || verifier.completionEventId) reject("PIN_CONFIRMATION_REQUIRED");
      await moveOrder(db, {auth: request.auth, data: {orderId: event.orderId, requestId: event.eventId,
        deliveryConfirmed: true, collectionConfirmed: false, expectedDeliveryRevision: revision(c.order)}},
      "complete", helpers.resolveReservation, helpers.checkFinancial,
      {transaction: tx, courierUid: event.courierUid, fingerprint: event.fingerprint});
      phase = "delivered";
      tx.update(verifierRef, {completionEventId: event.eventId, completedAt: FieldValue.serverTimestamp()});
      tx.update(c.orderRef, {courierDeliveryPhase: phase});
      tx.update(c.bindingRef, {status: "delivered", deliveredAt: FieldValue.serverTimestamp()});
    }
    const ack = receipt(event, phase, c.grant);
    tx.update(c.grantRef, {lastDeliverySequence: event.sequence, lastDeliveryEventId: event.eventId});
    tx.create(eventRef, {fingerprint: event.fingerprint, receipt: ack, createdAt: Timestamp.now()});
    return ack;
  });
}
module.exports = {submitDeliveryEvent};
