const {createHash} = require("node:crypto");
const {onCall, HttpsError} = require("firebase-functions/v2/https");
const {FieldValue} = require("firebase-admin/firestore");
const {authorize} = require("./courier-assignment");
const {requireContingency} = require("./operational-contingency");
const {fail, revision} = require("./delivery-contingency-state");
const hash = (value) => createHash("sha256").update(value).digest("hex");
const reasons = ["customer_not_located", "wrong_address", "no_answer", "refused",
  "no_change", "payment_refused", "courier_problem", "vehicle_broken", "delivery_interrupted"];

function input(request) {
  const actorUid = authorize(request, ["superadmin"]);
  const reason = requireContingency(request);
  const data = request.data;
  const fields = ["orderId", "requestId", "contingencyReason", "confirmation", "action",
    "expectedStatus", "expectedRevision", "reasonCode", "returnCondition", "returnAuthorized"];
  if (Object.keys(data).some((key) => !fields.includes(key)) ||
      typeof data.orderId !== "string" || !/^[A-Za-z0-9_-]{1,128}$/.test(data.orderId) ||
      typeof data.requestId !== "string" || !/^[A-Za-z0-9_-]{16,100}$/.test(data.requestId) ||
      !["attempt", "return", "redelivery"].includes(data.action) ||
      !Number.isSafeInteger(data.expectedRevision) || data.expectedRevision < 0 ||
      typeof data.expectedStatus !== "string") throw new HttpsError("invalid-argument", "INVALID_DELIVERY_INCIDENT");
  if (data.action === "attempt" && (!reasons.includes(data.reasonCode) ||
      data.returnCondition != null || data.returnAuthorized != null) ||
      data.action === "return" && (!["intact", "partial", "nonreturnable"].includes(data.returnCondition) ||
      data.returnAuthorized !== true || data.reasonCode != null) ||
      data.action === "redelivery" && [data.reasonCode, data.returnCondition, data.returnAuthorized]
          .some((value) => value != null)) throw new HttpsError("invalid-argument", "INVALID_DELIVERY_INCIDENT");
  return {actorUid, reason, data};
}

async function register(db, request) {
  const {actorUid, reason, data} = input(request);
  const {orderId, action} = data;
  const key = hash(`${actorUid}:${data.requestId}`);
  const fingerprint = hash(JSON.stringify([orderId, action, data.expectedStatus, data.expectedRevision,
    reason, data.reasonCode || null, data.returnCondition || null, data.returnAuthorized || false]));
  const orderRef = db.doc(`orders/${orderId}`);
  const incidentRef = db.doc(`orderDeliveryIncidents/${orderId}`);
  const receiptRef = db.doc(`deliveryIncidentRequests/${key}`);
  return db.runTransaction(async (tx) => {
    const receipt = await tx.get(receiptRef);
    if (receipt.exists) {
      if (receipt.data().fingerprint !== fingerprint) throw new HttpsError("already-exists", "REQUEST_ID_REUSED");
      return {...receipt.data().result, replayed: true};
    }
    const snapshot = await tx.get(orderRef);
    const incident = await tx.get(incidentRef);
    const courier = await tx.get(db.doc(`couriers/${actorUid}`));
    if (courier.exists) throw new HttpsError("permission-denied", "Perfil sem permissão.");
    if (!snapshot.exists) throw new HttpsError("not-found", "ORDER_NOT_FOUND");
    const order = snapshot.data();
    const previous = incident.exists ? incident.data() : {};
    const current = revision(order);
    if (order.status !== data.expectedStatus || current !== data.expectedRevision) {
      throw new HttpsError("aborted", "DELIVERY_INCIDENT_CHANGED", {reason: "DELIVERY_INCIDENT_CHANGED"});
    }
    if (incident.exists && previous.revision !== current || !incident.exists && current !== 0) {
      fail("DELIVERY_INCIDENT_REVIEW_REQUIRED");
    }
    if (order.returnStatus === "restocked") fail("RETURN_ALREADY_RESTOCKED");
    if (action === "return") {
      if (!["Em Separação", "Saiu para Entrega", "Cancelado", "Concluído"].includes(order.status) ||
          ["returned", "redelivery_pending"].includes(previous.phase)) fail("RETURN_STATE_INVALID");
    } else if (!["Em Separação", "Saiu para Entrega"].includes(order.status) ||
        ["redelivery_pending", "resolved"].includes(previous.phase) ||
        action === "attempt" && previous.phase === "returned") {
      fail("DELIVERY_INCIDENT_STATE_INVALID");
    }
    if (action === "redelivery" && !["pending", "returned"].includes(previous.phase)) {
      fail("DELIVERY_ATTEMPT_REQUIRED");
    }
    const phase = {attempt: "pending", return: "returned", redelivery: "redelivery_pending"}[action];
    const stamp = FieldValue.serverTimestamp();
    const nextRevision = current + 1;
    if (!Number.isSafeInteger(nextRevision)) fail("DELIVERY_INCIDENT_REVIEW_REQUIRED");
    const result = {orderId, phase, revision: nextRevision};
    const patch = {schemaVersion: 1, orderId, phase, revision: nextRevision,
      resolutionRequired: true, refundReviewRequired: order.paymentStatus === "Pago",
      updatedAt: stamp, updatedBy: actorUid,
      ...(action === "return" ? {returnCondition: data.returnCondition, returnAuthorized: true,
        returnedAt: stamp, returnedBy: actorUid} : {}),
      ...(action === "redelivery" ? {redeliveryMode: "manual_pending", redeliveryRequestedAt: stamp} : {})};
    tx.set(incidentRef, {...previous, ...patch});
    tx.create(incidentRef.collection("events").doc(key), {schemaVersion: 1, orderId, actorUid,
      action, reason, reasonCode: data.reasonCode || null, returnCondition: data.returnCondition || null,
      previousStatus: order.status, nextStatus: order.status, previousPhase: previous.phase || null, phase,
      revision: nextRevision, createdAt: stamp, paymentStatus: order.paymentStatus || null,
      paymentMethod: order.paymentMethod || null, splitPayment: order.splitPayment === true,
      stockAction: "none", financialAction: "none", resolutionRequired: true,
      refundReviewRequired: patch.refundReviewRequired});
    tx.update(orderRef, {deliveryIncidentStatus: phase, deliveryIncidentRevision: nextRevision});
    tx.create(receiptRef, {orderId, actorUid, fingerprint, result, createdAt: stamp});
    return {...result, replayed: false};
  });
}

function createDeliveryContingency(db) {
  return {chamaeRegistrarContingenciaEntrega: onCall({region: "southamerica-east1", maxInstances: 5},
      (request) => register(db, request))};
}
module.exports = {input, register, reasons, createDeliveryContingency};
