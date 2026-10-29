const {onDocumentCreated} = require("firebase-functions/v2/firestore");
const {HttpsError} = require("firebase-functions/v2/https");
const {FieldValue} = require("firebase-admin/firestore");
const validDisplayOrderId = (value) => typeof value === "string" && /^V8-(?:[0-9]{4}|[1-9][0-9]{4,})$/.test(value) &&
    value !== "V8-0000";
function formatOrderId(sequence) {
  if (!Number.isSafeInteger(sequence) || sequence < 1) throw new Error("INVALID_ORDER_SEQUENCE");
  return `V8-${String(sequence).padStart(4, "0")}`;
}
// Read phase only, so callers can finish all other reads before writing.
async function prepareOperationalId(tx, db, orderId, order) {
  const ref = db.doc(`operationalOrderIds/${orderId}`);
  const saved = await tx.get(ref);
  if (saved.exists) {
    const data = saved.data();
    if (!validDisplayOrderId(data.displayOrderId) ||
        order.displayOrderId && order.displayOrderId !== data.displayOrderId) {
      throw new HttpsError("failed-precondition", "Identificador operacional divergente.");
    }
    return {displayOrderId: data.displayOrderId, write() {}};
  }
  // Never silently trust an imported/client-proposed public identifier.
  if (order.displayOrderId != null) throw new HttpsError("failed-precondition", "Identificador sem registro oficial.");
  const counterRef = db.doc("operationalCounters/V8");
  const counter = await tx.get(counterRef);
  const last = counter.exists ? counter.data().lastSequence : 0;
  if (!Number.isSafeInteger(last) || last < 0 || last >= Number.MAX_SAFE_INTEGER) {
    throw new
    Error("ORDER_COUNTER_INVALID");
  }
  const sequence = last + 1;
  const displayOrderId = formatOrderId(sequence);
  return {displayOrderId, write() {
    tx.set(counterRef, {lastSequence: sequence, updatedAt: FieldValue.serverTimestamp()});
    tx.create(ref, {orderId, displayOrderId, sequence, createdAt: FieldValue.serverTimestamp()});
  }};
}
async function ensureOperationalId(db, orderId) {
  return db.runTransaction(async (tx) => {
    const ref = db.doc(`orders/${orderId}`); const order = await tx.get(ref);
    if (!order.exists) throw new HttpsError("not-found", "Pedido indisponível.");
    const plan = await prepareOperationalId(tx, db, orderId, order.data());
    plan.write();
    if (order.data().displayOrderId !== plan.displayOrderId) tx.update(ref, {displayOrderId: plan.displayOrderId});
    return plan.displayOrderId;
  });
}
function createOperationalIdTrigger(db) {
  return onDocumentCreated({document: "orders/{orderId}", region: "southamerica-east1", retry: true},
      (event) => ensureOperationalId(db, event.params.orderId));
}
module.exports = {formatOrderId, validDisplayOrderId, prepareOperationalId, ensureOperationalId,
  createOperationalIdTrigger};
