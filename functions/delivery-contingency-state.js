const {HttpsError} = require("firebase-functions/v2/https");

function fail(reason) {
  throw new HttpsError("failed-precondition", reason, {reason});
}
function revision(order) {
  const value = order.deliveryIncidentRevision;
  if (value == null) return 0;
  if (!Number.isSafeInteger(value) || value < 0) fail("DELIVERY_INCIDENT_REVIEW_REQUIRED");
  return value;
}
function assertCompletion(order, data) {
  if (!["Pago", "Pendente na entrega", "Pendente"].includes(order.paymentStatus)) {
    fail("COLLECTION_STATE_REVIEW_REQUIRED");
  }
  if (data.deliveryConfirmed !== true) fail("DELIVERY_CONFIRMATION_REQUIRED");
  if (order.paymentStatus !== "Pago" && data.collectionConfirmed !== true) fail("COLLECTION_CONFIRMATION_REQUIRED");
  if (!Number.isSafeInteger(data.expectedDeliveryRevision) || data.expectedDeliveryRevision !== revision(order)) {
    fail("DELIVERY_INCIDENT_CHANGED");
  }
  if (![undefined, null, "pending", "resolved"].includes(order.deliveryIncidentStatus)) {
    fail("DELIVERY_RETURN_OR_REDELIVERY_PENDING");
  }
}
function needsReturnProof(order) {
  return order.status === "Saiu para Entrega" || order.dispatchedAt != null ||
    order.deliveryIncidentStatus != null;
}
function assertReturnProof(order, record) {
  if (!record || record.schemaVersion !== 1 || record.revision !== revision(order) ||
      !["returned", "redelivery_pending"].includes(record.phase) ||
      record.returnCondition !== "intact" || record.returnAuthorized !== true ||
      !record.returnedAt || !record.returnedBy) fail("INTACT_AUTHORIZED_RETURN_REQUIRED");
}
module.exports = {fail, revision, assertCompletion, needsReturnProof, assertReturnProof};
