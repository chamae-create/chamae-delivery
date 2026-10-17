const {onCall, HttpsError} = require("firebase-functions/v2/https");
const {FieldValue} = require("firebase-admin/firestore");
const {createHash} = require("node:crypto");
const {authorize} = require("./order-chat");
/** Register an idempotent print request, never confirm physical output.
 * @param {Object} db Firestore.
 * @param {Object} request Callable request.
 * @return {Promise<Object>} Authoritative copy number.
 */
async function registerPrint(db, request) {
  const actor = request.auth;
  const roles = actor && actor.token.roles;
  if (!actor || !Array.isArray(roles) ||
      (actor.token.firebase || {}).sign_in_provider === "anonymous" ||
      !roles.some((role) =>
        ["operations_admin", "superadmin"].includes(role))) {
    throw new HttpsError("permission-denied", "Perfil sem acesso.");
  }
  const data = request.data || {};
  if (typeof data !== "object" || Array.isArray(data) ||
      typeof data.orderId !== "string" ||
      typeof data.requestId !== "string" ||
      Object.keys(data).some((key) =>
        !["orderId", "requestId", "part", "paperMm"].includes(key)) ||
      !/^[A-Za-z0-9_-]{1,128}$/.test(data.orderId || "") ||
      !/^[A-Za-z0-9_-]{16,100}$/.test(data.requestId || "") ||
      !["both", "separation", "delivery"].includes(data.part) ||
      ![58, 80].includes(data.paperMm)) {
    throw new HttpsError("invalid-argument", "Impressão inválida.");
  }
  return db.runTransaction(async (tx) => {
    await authorize(tx, db, actor, data.orderId);
    const id = createHash("sha256").update(actor.uid + ":" +
        data.requestId).digest("hex");
    const log = db.doc("orderPrintLogs/" + id);
    const stats = db.doc("orderPrintStats/" + data.orderId);
    const [previous, summary] = await Promise.all([tx.get(log), tx.get(stats)]);
    if (previous.exists) {
      const prior = previous.data();
      if (prior.orderId !== data.orderId || prior.part !== data.part ||
          prior.paperMm !== data.paperMm) {
        throw new HttpsError("already-exists", "Pedido de impressão repetido.");
      }
      return {count: prior.count, replayed: true};
    }
    const count = (summary.exists ? summary.data().count : 0) + 1;
    tx.create(log, {orderId: data.orderId, actorUid: actor.uid, count,
      part: data.part, paperMm: data.paperMm,
      requestedAt: FieldValue.serverTimestamp()});
    tx.set(stats, {count});
    return {count, replayed: false};
  });
}
/** Callable export.
 * @param {Object} db Firestore.
 * @return {Object} Function.
 */
function createOrderPrinting(db) {
  return {chamaeRegistrarImpressaoPedido: onCall({
    region: "southamerica-east1", maxInstances: 10,
  }, (request) => registerPrint(db, request))};
}
module.exports = {registerPrint, createOrderPrinting};
