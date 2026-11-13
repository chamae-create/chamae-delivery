const {HttpsError} = require("firebase-functions/v2/https");
const {FieldValue} = require("firebase-admin/firestore");

/** Validates a manual contingency.
 * @param {Object} request Verified callable request.
 * @return {string} Required reason.
 */
function requireContingency(request) {
  const roles = request.auth && request.auth.token && request.auth.token.roles;
  if (!Array.isArray(roles) || !roles.includes("superadmin")) {
    throw new HttpsError("permission-denied",
        "Somente contingência superadmin.");
  }
  const data = request.data || {};
  const reason = typeof data.contingencyReason === "string" ?
    data.contingencyReason.trim() : "";
  if (reason.length < 10 || reason.length > 500 ||
      data.confirmation !== `CONFIRMAR ${data.orderId}`) {
    throw new HttpsError("failed-precondition",
        "Informe motivo (10 a 500 caracteres) e confirme o pedido.");
  }
  return reason;
}

/** Writes an immutable trail in the intervention transaction.
 * @param {Object} tx Transaction.
 * @param {Object} ref Audit reference.
 * @param {Object} request Verified request.
 * @param {string} operation Action.
 * @param {Object} before Previous order.
 * @param {Object} patch Mutation.
 */
function auditContingency(tx, ref, request, operation, before, patch) {
  const state = (value) => ({status: value.status,
    courierUid: typeof value.courierUid === "string" ? value.courierUid : "",
    courierName: typeof value.courierName === "string" ?
      value.courierName : ""});
  tx.create(ref, {orderId: request.data.orderId, actorUid: request.auth.uid,
    reason: request.data.contingencyReason.trim(), operation,
    previous: state(before), next: state({...before, ...patch}),
    createdAt: FieldValue.serverTimestamp(), source: "superadmin_contingency"});
}

module.exports = {requireContingency, auditContingency};
