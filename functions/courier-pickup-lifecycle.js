const {createHash} = require("node:crypto");
const {onCall, HttpsError} = require("firebase-functions/v2/https");
const {Timestamp, FieldValue} = require("firebase-admin/firestore");
const {requireApprovedCourier} = require("./courier-authorization");
const {authorize} = require("./courier-assignment");
const {matchAssignment} = require("./courier-pickup");
// Server configuration / clock injection only. Never accepted from a client.
const pickupPolicy = {pickupMs: 15 * 60000, reminderMs: 3 * 60000, graceMs: 5 * 60000,
  extensionMs: 5 * 60000, maxCourierExtensions: 1, maxAdminExtensions: 3, now: () => Date.now()};
const hash = (v) => createHash("sha256").update(v).digest("hex");
const millis = (v) => v instanceof Timestamp ? v.toMillis() : null;
const reject = (message = "Esta entrega não está mais atribuída a você.") => {
  throw new HttpsError("failed-precondition", message);
};
function lifecycleSummary(order) {
  return {state: order.courierPickupState || "assigned", acceptedAtMs: millis(order.acceptedAt),
    expectedPickupByMs: millis(order.expectedPickupBy), reminderAtMs: millis(order.pickupReminderAt),
    confirmationRequestedAtMs: millis(order.pickupConfirmationRequestedAt),
    overdueAtMs: millis(order.pickupOverdueAt), extensionCount: order.pickupExtensionCount || 0};
}
function reliability(tx, db, eventId, type, id, assignmentId, uid, at, extra = {}) {
  tx.create(db.doc(`courierReliabilityEvents/${eventId}`), {type, orderId: id, assignmentId,
    courierUid: uid, at, ...extra});
}
async function pickupAction(db, request, action, administrator = false) {
  const actor = administrator ? authorize(request) : request.auth && request.auth.uid;
  const d = request.data || {};
  if (Object.keys(d).some((k) => !["orderId", "assignmentId", "requestId", "reason"].includes(k)) ||
      ![d.orderId, d.assignmentId].every((v) => typeof v === "string" && /^[A-Za-z0-9_-]{1,128}$/.test(v)) ||
      typeof d.requestId !== "string" || !/^[A-Za-z0-9_-]{16,100}$/.test(d.requestId) ||
      d.reason != null && (typeof d.reason !== "string" || d.reason.length > 240)) {
    throw new HttpsError("invalid-argument", "Solicitação inválida.");
  }
  if (!["accept", "headingToPickup", "pickupApproaching", "arrivedAtStore", "onWay", "decline", "extend",
    "revoke"].includes(action) ||
      administrator !== ["extend", "revoke"].includes(action)) reject("Ação inválida.");
  return db.runTransaction(async (tx) => {
    let uid = actor;
    if (!administrator) {
      const c = await requireApprovedCourier(db, request, tx); uid = c.uid;
      if (c.profile.online !== true) reject("Fique ON para continuar.");
    } else {
      if ((await tx.get(db.doc(`couriers/${actor}`))).exists) reject("Use uma conta administrativa.");
    }
    const ledger = db.doc(`courierPickupActionRequests/${hash(`${actor}:${d.requestId}`)}`);
    const old = await tx.get(ledger); const fingerprint = hash(JSON.stringify([action, d.orderId, d.assignmentId,
      d.reason || ""]));
    if (old.exists) {
      if (old.data().fingerprint !== fingerprint) throw new HttpsError("already-exists", "Tentativa já utilizada.");
      return {...old.data().result, replayed: true};
    }
    const ref = db.doc(`orders/${d.orderId}`); const snap = await tx.get(ref); const order = snap.data();
    const nowMs = pickupPolicy.now(); const now = Timestamp.fromMillis(nowMs);
    if (!order || !matchAssignment(order, administrator ? order.courierUid : uid, d.assignmentId, nowMs)) reject();
    uid = order.courierUid;
    const bindingRef = db.doc(`courierPickupAssignments/${d.assignmentId}`); const binding = await tx.get(bindingRef);
    if (!binding.exists || binding.data().status !== "active" ||
        binding.data().orderId !== d.orderId || binding.data().courierUid !== uid) reject();
    if (order.courierPickedUpAt || ["pickedUp", "headingToCustomer"].includes(order.courierPickupState) ||
        !["Novo", "Em Separação"].includes(order.status)) reject("Retirada já confirmada ou pedido indisponível.");
    let patch = {}; let type = action;
    const state = order.courierPickupState || "assigned";
    if (action === "accept") {
      if (order.acceptedAt) return {acknowledged: true, ...lifecycleSummary(order), replayed: true};
      patch = {courierPickupState: "accepted", acceptedAt: now,
        expectedPickupBy: Timestamp.fromMillis(nowMs + pickupPolicy.pickupMs), pickupExtensionCount: 0,
        pickupAdminExtensionCount: 0};
      type = "deliveryAccepted";
    } else if (["headingToPickup", "pickupApproaching", "arrivedAtStore"].includes(action)) {
      const stages = ["accepted", "headingToPickup", "pickupApproaching", "arrivedAtStore"];
      if (!order.acceptedAt || !stages.includes(state) || stages.indexOf(action) < stages.indexOf(state)) {
        reject("Atualize o estado da retirada.");
      }
      patch.courierPickupState = action;
    } else if (action === "onWay" || action === "extend") {
      if (!order.expectedPickupBy) reject("Aceite a entrega primeiro.");
      const field = administrator ? "pickupAdminExtensionCount" : "pickupExtensionCount";
      const limit = administrator ? pickupPolicy.maxAdminExtensions : pickupPolicy.maxCourierExtensions;
      if ((order[field] || 0) >= limit) reject("Limite de tolerância atingido. Fale com a loja.");
      patch = {[field]: (order[field] || 0) + 1,
        expectedPickupBy: Timestamp.fromMillis(Math.max(nowMs, millis(order.expectedPickupBy)) +
    pickupPolicy.extensionMs),
        pickupReminderAt: FieldValue.delete(), pickupConfirmationRequestedAt: FieldValue.delete(),
        pickupOverdueAt: FieldValue.delete(), courierPickupState: "headingToPickup"};
      type = administrator ? "pickupTimeExtended" : "courierOnWay";
    } else {
      if (action === "decline" && !order.acceptedAt) reject("Aceite a entrega primeiro.");
      if (!d.reason || d.reason.trim().length < 3) reject("Informe um motivo.");
      patch = {courierUid: "", courierName: "", courierAssignmentId: FieldValue.delete(),
        courierAssignmentExpiresAt: FieldValue.delete(), courierPickupState: "awaitingRedistribution",
        courierUnassignedAt: now};
      type = administrator ? "assignmentRevoked" : "courierDeclinedAfterAccept";
      tx.set(db.doc(`courierDeliveries/${d.orderId}`), {orderId: d.orderId, courierUid: "", revoked: true, updatedAt:
    now});
      tx.set(bindingRef, {orderId: d.orderId, courierUid: uid, status: "revoked", revokedAt: now, reason:
    d.reason.trim()}, {merge: true});
      if (!administrator) {
        reliability(tx, db, `${hash(`${actor}:${d.requestId}`)}-revoked`, "assignmentRevoked",
            d.orderId, d.assignmentId, uid, now);
      }
    }
    tx.update(ref, {...patch, updatedAt: now});
    const result = {acknowledged: true, ...lifecycleSummary({...order, ...patch}), revoked: ["decline",
      "revoke"].includes(action)};
    reliability(tx, db, hash(`${actor}:${d.requestId}`), type, d.orderId, d.assignmentId, uid, now,
        {actorUid: actor, ...(d.reason ? {reason: d.reason.trim()} : {})});
    tx.create(ledger, {fingerprint, result, createdAt: now});
    return result;
  });
}
// Run by server scheduler (or explicitly in emulator), never by a Flutter timer.
async function inspectPickup(db, id) {
  return db.runTransaction(async (tx) => {
    const ref = db.doc(`orders/${id}`); const snapshot = await tx.get(ref); const o = snapshot.data();
    const nowMs = pickupPolicy.now(); const deadline = o && millis(o.expectedPickupBy);
    if (!o || !deadline || o.courierPickedUpAt || !matchAssignment(o, o.courierUid, o.courierAssignmentId, nowMs)) {
      return false;
    }
    const deadlineKey = `${o.courierAssignmentId}-${deadline}`;
    const patch = {}; let kind;
    if (nowMs >= deadline + pickupPolicy.graceMs && !o.pickupOverdueAt) {
      patch.pickupOverdueAt = Timestamp.fromMillis(nowMs); patch.courierPickupState = "pickupOverdue";
      patch.pickupDelayMs = nowMs - deadline; patch.pickupOverdueCount = (o.pickupOverdueCount || 0) + 1;
      kind = "pickupOverdue";
    } else if (nowMs >= deadline && !o.pickupConfirmationRequestedAt) {
      patch.pickupConfirmationRequestedAt = Timestamp.fromMillis(nowMs); kind = "pickup_confirmation";
    } else if (nowMs >= deadline - pickupPolicy.reminderMs && !o.pickupReminderAt) {
      patch.pickupReminderAt = Timestamp.fromMillis(nowMs); kind = "pickup_reminder";
    }
    if (!kind) return false;
    const now = Timestamp.fromMillis(nowMs);
    tx.update(ref, patch);
    tx.set(db.doc(`courierNotificationOutbox/${deadlineKey}-${kind}`), {kind, version: "2", orderId: id,
      assignmentId: o.courierAssignmentId, courierUid: o.courierUid, createdAt: now, deadlineMs: deadline,
      title: kind === "pickup_reminder" ? "Você tem uma entrega aguardando retirada." :
        `Ainda vai retirar o pedido ${o.displayOrderId || "na loja"}?`,
      body: "Abra o Chamaê para confirmar com a loja."});
    if (kind === "pickupOverdue") {
      reliability(tx, db, `${deadlineKey}-overdue`, "pickupOverdue", id, o.courierAssignmentId, o.courierUid, now);
      reliability(tx, db, `${deadlineKey}-noshow`, "courierNoShow", id, o.courierAssignmentId, o.courierUid, now);
    }
    return kind;
  });
}
async function scanPickupDeadlines(db) {
  let cursor; let count = 0;
  do {
    let query = db.collection("orders").where("expectedPickupBy", "<=",
        Timestamp.fromMillis(pickupPolicy.now() + pickupPolicy.reminderMs)).limit(200);
    if (cursor) query = query.startAfter(cursor);
    const orders = await query.get();
    for (const order of orders.docs) await inspectPickup(db, order.id);
    count += orders.size;
    cursor = orders.size === 200 ? orders.docs[199] : null;
  } while (cursor);
  return count;
}
function createPickupLifecycleFunctions(db) {
  const options = {region: "southamerica-east1", maxInstances: 10};
  const definitions = {chamaeAceitarRetirada: ["accept"], chamaeIndoRetirar: ["headingToPickup"],
    chamaeAproximandoLoja: ["pickupApproaching"], chamaeChegueiLoja: ["arrivedAtStore"],
    chamaeConfirmarCaminho: ["onWay"], chamaeDesistirRetirada: ["decline"],
    chamaeDarMaisTempoRetirada: ["extend", true], chamaeRevogarRetirada: ["revoke", true]};
  return Object.fromEntries(Object.entries(definitions).map(([name, [action, admin = false]]) =>
    [name, onCall(options, (r) => pickupAction(db, r, action, admin))]));
}
module.exports = {pickupPolicy, lifecycleSummary, pickupAction, inspectPickup, scanPickupDeadlines,
  createPickupLifecycleFunctions};
