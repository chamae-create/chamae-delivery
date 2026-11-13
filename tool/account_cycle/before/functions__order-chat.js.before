const {onCall, HttpsError} = require("firebase-functions/v2/https");
const {FieldValue} = require("firebase-admin/firestore");
const {createHash} = require("node:crypto");
const options = {region: "southamerica-east1", maxInstances: 10};
const fail = (code, message) => {
  throw new HttpsError(code, message);
};
const validId = (id) => typeof id === "string" &&
  /^[A-Za-z0-9_-]{1,128}$/.test(id);
/** Validate the callable contract before any read or write.
 * @param {Object} request Callable request.
 * @param {boolean} send Whether a message is being sent.
 * @return {Object} Validated input.
 */
function input(request, send) {
  if (!request.auth) fail("unauthenticated", "Entre novamente.");
  const data = request.data;
  const keys = send ? ["orderId", "text", "requestId"] : ["orderId"];
  if (!data || typeof data !== "object" || Array.isArray(data) ||
      Object.keys(data).some((key) => !keys.includes(key)) ||
      !validId(data.orderId)) fail("invalid-argument", "Pedido inválido.");
  if (send && (typeof data.text !== "string" || !data.text.trim() ||
      data.text.length > 2000 ||
      Array.from(data.text).some((c) => c.charCodeAt(0) < 32 &&
        ![9, 10, 13].includes(c.charCodeAt(0))) ||
      typeof data.requestId !== "string" ||
      !/^[A-Za-z0-9_-]{16,100}$/.test(data.requestId))) {
    fail("invalid-argument", "Envie somente texto, de 1 a 2000 caracteres.");
  }
  return data;
}
/** Authorize an owner or a named operational administrator.
 * @param {Object} tx Firestore transaction.
 * @param {Object} db Firestore.
 * @param {Object} auth Firebase auth.
 * @param {string} orderId Document ID.
 * @return {Promise<Object>} Order and actor type.
 */
async function authorize(tx, db, auth, orderId) {
  const [order, courier] = await Promise.all([
    tx.get(db.doc("orders/" + orderId)),
    tx.get(db.doc("couriers/" + auth.uid)),
  ]);
  const roles = Array.isArray(auth.token.roles) ? auth.token.roles : [];
  const named = (auth.token.firebase || {}).sign_in_provider !== "anonymous";
  const operations = named && roles.some((role) =>
    ["operations_admin", "superadmin"].includes(role));
  if (courier.exists || (!operations &&
      roles.some((role) => ["finance", "catalog_admin"].includes(role)))) {
    fail("permission-denied", "Perfil sem acesso ao chat.");
  }
  if (!order.exists || (!operations &&
      order.data().customerUid !== auth.uid)) {
    fail("permission-denied", "Pedido indisponível.");
  }
  const data = order.data();
  if (data.financialValidationStatus !== "validated") {
    fail("failed-precondition", "Pedido sem validação operacional.");
  }
  return {order: data, senderType: operations ? "merchant" : "customer"};
}
/** Transactional, idempotent text chat. No order/payment/stock mutations.
 * @param {Object} db Firestore.
 * @param {Object} request Callable request.
 * @param {boolean} send Send or mark read.
 * @param {Function} now Clock for deterministic window tests.
 * @return {Promise<Object>} Result.
 */
async function chatOperation(db, request, send, now = Date.now) {
  const data = input(request, send);
  return db.runTransaction(async (tx) => {
    const actor = await authorize(tx, db, request.auth, data.orderId);
    const ref = db.doc("orderChats/" + data.orderId);
    const chat = await tx.get(ref);
    const self = actor.senderType === "merchant" ?
      "unreadMerchant" : "unreadCustomer";
    const peer = actor.senderType === "merchant" ?
      "unreadCustomer" : "unreadMerchant";
    const completed = actor.order.completedAt &&
      actor.order.completedAt.toMillis();
    const expired = actor.order.status === "Concluído" &&
      (!Number.isFinite(completed) || now() >= completed + 86400000);
    const closed = expired || actor.order.status === "Cancelado";
    const stamp = FieldValue.serverTimestamp();
    if (!send) {
      if (chat.exists) {
        tx.update(ref, {[self]: 0,
          ...(closed ? {status: "closed", closedAt: stamp} : {})});
      }
      return {read: true, closed};
    }
    const id = createHash("sha256").update(request.auth.uid + ":" +
        data.requestId).digest("hex");
    const message = ref.collection("messages").doc(id);
    const previous = await tx.get(message);
    if (previous.exists) {
      if (previous.data().text !== data.text.trim()) {
        fail("already-exists", "Identificador já utilizado.");
      }
      return {messageId: id, replayed: true};
    }
    if (closed) fail("failed-precondition", "Conversa encerrada.");
    tx.create(message, {senderType: actor.senderType,
      senderUid: request.auth.uid, text: data.text.trim(), createdAt: stamp});
    const metadata = {orderId: data.orderId,
      customerUid: actor.order.customerUid, status: "open",
      lastMessageAt: stamp, [peer]: FieldValue.increment(1)};
    if (!chat.exists) Object.assign(metadata, {createdAt: stamp, [self]: 0});
    tx.set(ref, metadata, {merge: true});
    return {messageId: id, replayed: false};
  });
}
/** Register chat callables.
 * @param {Object} db Firestore.
 * @return {Object} Exports.
 */
function createOrderChat(db) {
  return {
    chamaeEnviarMensagemPedido: onCall(options, (request) =>
      chatOperation(db, request, true)),
    chamaeMarcarChatLido: onCall(options, (request) =>
      chatOperation(db, request, false)),
  };
}
module.exports = {createOrderChat, chatOperation, input, authorize};
