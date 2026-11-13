const {createHash} = require("node:crypto");
const {HttpsError, onCall} = require("firebase-functions/v2/https");
const {Timestamp} = require("firebase-admin/firestore");
const {requireApprovedCourier} = require("./courier-authorization");
const {assertCurrentCourierAcceptance} = require("./courier-policy");
const {pickupAction} = require("./courier-pickup-lifecycle");
const {matchAssignment} = require("./courier-pickup");
const hash = (value) => createHash("sha256").update(value).digest("hex");
const actions = ["accept", "headingToPickup", "pickupApproaching", "arrivedAtStore", "onWay", "decline"];
function reject(reason, message = "Atualize sua sessão e a atribuição antes de continuar.") {
  throw new HttpsError("failed-precondition", message, {reason});
}
function parseEvent(data, uid) {
  const fields = ["eventId", "orderId", "courierUid", "type", "localTimestampMs", "sequence", "payload",
    "assignmentId", "protocolVersion", "fingerprint"];
  if (!data || typeof data !== "object" || Array.isArray(data) || Object.keys(data).some((k) => !fields.includes(k)) ||
      data.courierUid !== uid || typeof data.eventId !== "string" || !/^[A-Za-z0-9_-]{16,100}$/.test(data.eventId) ||
      typeof data.orderId !== "string" || !/^[A-Za-z0-9_-]{1,128}$/.test(data.orderId) ||
      !Number.isSafeInteger(data.sequence) || data.sequence < 1 ||
      !Number.isSafeInteger(data.localTimestampMs) || data.localTimestampMs < 0 ||
      !data.payload || typeof data.payload !== "object" || Array.isArray(data.payload)) {
    throw new HttpsError("invalid-argument", "Evento ou UID inválido.");
  }
  if (!["availability", "pickupAction", "startRoute", "arrived", "confirmDelivery"].includes(data.type)) {
    reject("OPERATION_NOT_ENABLED", "QR, PIN e entrega dependem dos provedores da próxima fase.");
  }
  if (data.protocolVersion !== 2) throw new HttpsError("invalid-argument", "Protocolo de evento inválido.");
  let payload;
  if (data.type === "availability") {
    if (data.orderId !== "shift" || data.assignmentId !== undefined ||
        Object.keys(data.payload).some((k) => k !== "on") || typeof data.payload.on !== "boolean") {
      throw new HttpsError("invalid-argument", "Disponibilidade inválida.");
    }
    payload = {on: data.payload.on};
  } else if (["startRoute", "arrived", "confirmDelivery"].includes(data.type)) {
    if (typeof data.assignmentId !== "string" || !/^[A-Za-z0-9_-]{1,128}$/.test(data.assignmentId)) {
      throw new HttpsError("invalid-argument", "ASSIGNMENT_INVALID");
    }
    if (data.type === "confirmDelivery") {
      const proof = data.payload.proof;
      if (Object.keys(data.payload).some((k) => k !== "proof") || !proof || typeof proof !== "object" ||
          Object.keys(proof).some((k) => !["method", "verificationId"].includes(k)) ||
          proof.method !== "pin" || !/^[a-f0-9]{64}$/.test(proof.verificationId || "")) {
        throw new HttpsError("invalid-argument", "PROOF_INVALID");
      }
      payload = {proof: {method: "pin", verificationId: proof.verificationId}};
    } else {
      if (Object.keys(data.payload).length) throw new HttpsError("invalid-argument", "TRANSITION_INVALID");
      payload = {};
    }
  } else {
    if (typeof data.assignmentId !== "string" || !/^[A-Za-z0-9_-]{1,128}$/.test(data.assignmentId) ||
        !actions.includes(data.payload.action) ||
        Object.keys(data.payload).some((k) => !["action", "reason"].includes(k)) ||
        data.payload.reason !== undefined &&
        (typeof data.payload.reason !== "string" || data.payload.reason.length > 240)) {
      throw new HttpsError("invalid-argument", "Ação de retirada inválida.");
    }
    payload = {action: data.payload.action,
      ...(data.payload.reason === undefined ? {} : {reason: data.payload.reason})};
  }
  const canonical = {...(data.assignmentId === undefined ? {} : {assignmentId: data.assignmentId}),
    protocolVersion: 2, eventId: data.eventId, orderId: data.orderId, courierUid: uid, type: data.type,
    localTimestampMs: data.localTimestampMs, sequence: data.sequence, payload};
  const fingerprint = hash(JSON.stringify(canonical));
  if (data.fingerprint !== fingerprint) throw new HttpsError("invalid-argument", "Integridade do evento inválida.");
  return {...canonical, fingerprint};
}
async function assertBinding(tx, db, event) {
  const order = (await tx.get(db.doc(`orders/${event.orderId}`))).data();
  const binding = await tx.get(db.doc(`courierPickupAssignments/${event.assignmentId}`));
  if (!matchAssignment(order, event.courierUid, event.assignmentId, Date.now()) ||
      !binding.exists || binding.data().status !== "active" ||
      binding.data().courierUid !== event.courierUid || binding.data().orderId !== event.orderId) {
    reject("ASSIGNMENT_CHANGED");
  }
}
function receiptFor(event, now, pickupResult) {
  return {receiptId: hash(`${event.courierUid}:${event.eventId}`), eventId: event.eventId,
    orderId: event.orderId, courierUid: event.courierUid, sequence: event.sequence,
    fingerprint: event.fingerprint, acceptedAtMs: now, authority: "backend", delivery: null,
    availabilityOn: event.type === "availability" ? event.payload.on : null,
    ...(event.type === "pickupAction" ? {pickupAcknowledgement: {acknowledged: true,
      assignmentId: event.assignmentId, action: event.payload.action, ...pickupResult}} : {})};
}
async function submitCourierEvent(db, request, options = {}) {
  // The guard always runs, including retries: an old receipt cannot restore access.
  const courier = await requireApprovedCourier(db, request);
  const event = parseEvent(request.data, courier.uid);
  if (["startRoute", "arrived", "confirmDelivery"].includes(event.type)) {
    return require("./courier-delivery-events").submitDeliveryEvent(db, request, event, options);
  }
  const ref = db.doc(`courierEventReceipts/${hash(`${courier.uid}:${event.eventId}`)}`);
  if (event.type === "availability") {
    return db.runTransaction(async (tx) => {
      const current = await requireApprovedCourier(db, request, tx);
      const old = await tx.get(ref);
      if (event.payload.on) await assertCurrentCourierAcceptance(db, current.uid, tx);
      if (old.exists) {
        if (old.data().fingerprint !== event.fingerprint) reject("EVENT_ID_REUSED");
        return old.data().receipt;
      }
      const receipt = receiptFor(event, Date.now());
      tx.update(current.ref, {online: event.payload.on});
      tx.create(ref, {fingerprint: event.fingerprint, receipt, createdAt: Timestamp.now()});
      return receipt;
    });
  }
  const prior = await db.runTransaction(async (tx) => {
    const current = await requireApprovedCourier(db, request, tx);
    const old = await tx.get(ref);
    if (old.exists && old.data().fingerprint !== event.fingerprint) reject("EVENT_ID_REUSED");
    if (!current.profile.online) reject("SHIFT_OFF", "Fique ON antes de continuar.");
    const lifecycle = event.payload.action === "decline" ?
      await tx.get(db.doc(`courierPickupActionRequests/${hash(`${courier.uid}:${event.eventId}`)}`)) : null;
    const ownDecline = lifecycle && lifecycle.exists && lifecycle.data().fingerprint === hash(JSON.stringify([
      "decline", event.orderId, event.assignmentId, event.payload.reason || ""]));
    if (!(event.payload.action === "decline" && (old.exists || ownDecline))) await assertBinding(tx, db, event);
    return old.exists ? old.data().receipt : null;
  });
  if (prior) return prior;
  // Reuse the authoritative lifecycle and its durable requestId ledger.
  const result = await pickupAction(db, {auth: request.auth, data: {orderId: event.orderId,
    assignmentId: event.assignmentId, requestId: event.eventId,
    ...(event.payload.reason === undefined ? {} : {reason: event.payload.reason})}}, event.payload.action);
  if (options.afterLifecycle) await options.afterLifecycle();
  return db.runTransaction(async (tx) => {
    await requireApprovedCourier(db, request, tx);
    const old = await tx.get(ref);
    if (old.exists) {
      if (old.data().fingerprint !== event.fingerprint) reject("EVENT_ID_REUSED");
      return old.data().receipt;
    }
    if (event.payload.action !== "decline") await assertBinding(tx, db, event);
    const receipt = receiptFor(event, Date.now(), result);
    tx.create(ref, {fingerprint: event.fingerprint, receipt, createdAt: Timestamp.now()});
    return receipt;
  });
}
async function courierState(db, request) {
  const courier = await requireApprovedCourier(db, request);
  if (request.data && Object.keys(request.data).length) throw new HttpsError("invalid-argument", "Entrada inválida.");
  let cursor; let completed = 0; let pending = 0;
  for (;;) {
    let query = db.collection("orders").where("courierUid", "==", courier.uid).orderBy("__name__").limit(100);
    if (cursor) query = query.startAfter(cursor);
    const page = await query.get();
    for (const doc of page.docs) {
      if (doc.data().status === "Concluído") completed++;
      else if (doc.data().status !== "Cancelado") pending++;
    }
    if (page.size < 100) break;
    cursor = page.docs[page.docs.length - 1];
  }
  return {courierUid: courier.uid, online: courier.profile.online === true, completed, pending,
    mode: courier.profile.settlementMode === "perDelivery" ? "perDelivery" : "shift", amountVisible: false};
}
function createCourierEventFunctions(db, helpers = {}) {
  const options = {region: "southamerica-east1", maxInstances: 10};
  return {chamaeSincronizarEventoMotoboy: onCall(options, (r) => submitCourierEvent(db, r, helpers)),
    chamaeEstadoOperacionalMotoboy: onCall(options, (r) => courierState(db, r))};
}
module.exports = {parseEvent, receiptFor, submitCourierEvent, courierState, createCourierEventFunctions};
