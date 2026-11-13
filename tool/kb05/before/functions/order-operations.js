const {requireContingency, auditContingency} =
    require("./operational-contingency");
const {prepareCourierDispatch} = require("./courier-dispatch-contract");
const {createHash} = require("node:crypto");
const {onCall, HttpsError} = require("firebase-functions/v2/https");
const {Timestamp, FieldValue} = require("firebase-admin/firestore");
const {authorize, readyForDispatch} = require("./courier-assignment");
const {courierUid, isAssignableCourier,
  planCourierDelivery, writeCourierDelivery} =
    require("./courier-deliveries");

const reject = (message) => {
  throw new HttpsError("failed-precondition", message);
};
const validId = (id) => typeof id === "string" && id.length > 0 &&
  !id.includes("/") && ![".", ".."].includes(id) &&
  Buffer.byteLength(id) <= 1500;
const digest = (value) => createHash("sha256").update(value).digest("hex");

/** Validates a bounded, strictly allowlisted request.
 * @param {Object} request Callable request.
 * @param {string[]} fields Allowed fields.
 * @return {Object} Payload.
 */
function payload(request, fields) {
  const data = request.data;
  if (!data || typeof data !== "object" || Array.isArray(data) ||
      Object.keys(data).some((key) => !fields.includes(key)) ||
      typeof data.requestId !== "string" ||
      !/^[A-Za-z0-9_-]{16,100}$/.test(data.requestId)) {
    throw new HttpsError("invalid-argument", "Solicitação inválida.");
  }
  return data;
}

/** Explicit finance and operational cashier permissions.
 * @param {Object} request Verified callable request.
 * @return {string} Actor UID.
 */
function authorizeSettlement(request) {
  return authorize(request, ["finance", "operations_admin", "superadmin"]);
}

/** Moves one order; all projection and stock effects commit with the status.
 * @param {Object} db Admin Firestore.
 * @param {Object} request Verified request.
 * @param {string} operation separate or complete.
 * @param {Function} resolveReservation Shared existing stock algorithm.
 * @param {Function} checkFinancial Existing item/quantity consistency check.
 * @return {Promise<Object>} Receipt.
 */
async function moveOrder(db, request, operation, resolveReservation,
    checkFinancial) {
  const actorUid = authorize(request);
  const reason = operation === "complete" ? requireContingency(request) : null;
  const data = payload(request, operation === "complete" ?
    ["orderId", "requestId", "contingencyReason", "confirmation"] :
    ["orderId", "requestId"]);
  if (!validId(data.orderId)) {
    throw new HttpsError("invalid-argument", "Pedido inválido.");
  }
  const id = data.orderId;
  const ref = db.doc(`orders/${id}`);
  const deliveryRef = db.doc(`courierDeliveries/${id}`);
  const auditRef = db.collection("courierDeliveryAudit").doc();
  const ledgerRef = db.doc(`orderOperationRequests/${digest(
      `${actorUid}:${data.requestId}`)}`);
  const fingerprint = digest(reason ? `${operation}:${id}:${reason}` :
    `${operation}:${id}`);
  const contingencyRef = db.collection("operationalContingencyAudit").doc();
  const next = operation === "separate" ? "Em Separação" : "Concluído";
  const before = operation === "separate" ? "Novo" : "Saiu para Entrega";
  return db.runTransaction(async (tx) => {
    const receipt = await tx.get(ledgerRef);
    if (receipt.exists) {
      if (receipt.data().fingerprint !== fingerprint) {
        throw new HttpsError("already-exists", "Tentativa já utilizada.");
      }
      return {orderId: id, status: next, replayed: true};
    }
    const snapshot = await tx.get(ref);
    if (!snapshot.exists) {
      throw new HttpsError("not-found", "Pedido não encontrado.");
    }
    const order = snapshot.data();
    if (order.status !== before && order.status !== next) {
      reject("O pedido mudou. Confira a etapa atual.");
    }
    // Legacy absence never implies approval. Only backend-frozen finance.
    const financial = await tx.get(db.doc(`orderFinancials/${id}`));
    if (order.financialValidationStatus !== "validated" || !financial.exists) {
      reject("Pedido sem validação financeira oficial. Revisão necessária.");
    }
    checkFinancial(order, financial.data());
    const previous = await tx.get(deliveryRef);
    const uid = courierUid(order.courierUid);
    let registered = false;
    if (uid) {
      const profile = await tx.get(db.doc(`couriers/${uid}`));
      registered = profile.exists && isAssignableCourier(profile.data());
    }
    if (operation === "complete" && (!uid || !registered ||
        !(order.courierAssignedAt instanceof Timestamp))) {
      reject("A entrega precisa de motoboy real atribuído.");
    }
    if (operation === "complete" && order.status === next &&
        !(order.completedAt instanceof Timestamp)) {
      reject("Conclusão legada sem timestamp exige revisão administrativa.");
    }
    if (!readyForDispatch(order) ||
        order.stockProcessingStatus === "processed" &&
        order.stockReservationStatus === "reserved") {
      reject("Confira pagamento, validação e reserva de estoque.");
    }
    if (operation === "complete" &&
        order.stockReservationStatus !== "reserved" &&
        order.stockReservationStatus !== "finalized" &&
        order.stockProcessingStatus !== "processed") {
      reject("Estoque ainda não está pronto para conclusão.");
    }
    const plan = planCourierDelivery({orderId: id, order,
      previous: previous.exists ? previous.data() : {},
      exists: previous.exists, registered, now: Timestamp.now(),
      binding: {courierUid: uid, status: next}});
    if (operation === "complete" && plan.revoked) {
      reject("Rota inválida. Revise o pedido antes de concluir.");
    }
    // The shared reservation resolver performs the last reads before writes.
    if (operation === "complete" &&
        order.stockReservationStatus === "reserved") {
      await resolveReservation(tx, ref, id, true);
    }
    if (operation === "complete") {
      auditContingency(tx, contingencyRef, request, "complete", order,
          {status: next});
    }
    if (order.status !== next) {
      if (operation === "separate") {
        prepareCourierDispatch(tx, db.doc(`courierDispatchRequests/${id}`), id);
      }
      tx.update(ref, {status: next, updatedAt: FieldValue.serverTimestamp(),
        ...(operation === "complete" ? {
          completedAt: FieldValue.serverTimestamp(), completedBy: actorUid,
        } : {separationStartedAt: FieldValue.serverTimestamp(),
          courierDispatchState: "awaiting_integration"})});
    }
    writeCourierDelivery(tx, {plan, deliveryRef, auditRef, orderId: id,
      previous: previous.exists ? previous.data() : {}, actorUid});
    tx.create(ledgerRef, {orderId: id, actorUid, operation, fingerprint,
      createdAt: FieldValue.serverTimestamp()});
    return {orderId: id, status: next, replayed: false};
  });
}

/** Validates exact cents; no client totals are accepted.
 * @param {*} value Persisted official amount.
 * @return {number} Integer cents.
 */
function cents(value) {
  const amount = Math.round(value * 100);
  if (typeof value !== "number" || !Number.isFinite(value) || value < 0 ||
      !Number.isSafeInteger(amount) ||
      Math.abs(value * 100 - amount) > 0.000001) {
    reject("Valor oficial inválido. Revisão necessária.");
  }
  return amount;
}

/** Settles a complete selected set, atomically, by immutable courier identity.
 * @param {Object} db Admin Firestore.
 * @param {Object} request Callable request.
 * @param {Function} checkFinancial Existing consistency check.
 * @return {Promise<Object>} Immutable receipt ID.
 */
async function settleCourier(db, request, checkFinancial) {
  const actorUid = authorizeSettlement(request);
  const data = payload(request, ["orderDocumentIds", "requestId"]);
  const list = data.orderDocumentIds;
  if (!Array.isArray(list) || list.length < 1 || list.length > 400 ||
      list.some((id) => !validId(id)) || new Set(list).size !== list.length) {
    throw new HttpsError("invalid-argument",
        "Selecione de 1 a 400 pedidos únicos.");
  }
  const ids = list.slice().sort();
  const id = digest(`${actorUid}:${data.requestId}`);
  const ref = db.doc(`courierSettlements/${id}`);
  const fingerprint = digest(JSON.stringify(ids));
  return db.runTransaction(async (tx) => {
    const existing = await tx.get(ref);
    if (existing.exists) {
      const saved = existing.data();
      if (saved.actorUid !== actorUid || saved.fingerprint !== fingerprint) {
        throw new HttpsError("already-exists",
            "Código pertence a outro lote.");
      }
      return {settlementId: id, replayed: true};
    }
    const orders = await tx.getAll(...ids.map((key) =>
      db.doc(`orders/${key}`)));
    const finances = await tx.getAll(...ids.map((key) =>
      db.doc(`orderFinancials/${key}`)));
    let uid;
    let total = 0;
    const lines = [];
    for (let i = 0; i < ids.length; i++) {
      if (!orders[i].exists || !finances[i].exists) {
        reject("Pedido sem registro oficial. Revise o lote.");
      }
      const order = orders[i].data();
      const official = finances[i].data();
      const assigned = courierUid(order.courierUid);
      if (!assigned || order.status !== "Concluído" ||
          !(order.completedAt instanceof Timestamp) ||
          order.paymentStatus !== "Pago" ||
          order.financialValidationStatus !== "validated" ||
          order.courierPaid === true || order.courierSettlementId != null ||
          order.stockReservationStatus !== "finalized" &&
          order.stockProcessingStatus !== "processed" ||
          ["released", "requires_review", "error"].includes(
              order.stockReservationStatus) ||
          order.stockProcessingStatus === "requires_review" ||
          order.stockProcessingError != null ||
          order.stockReservationError != null) {
        reject("Lote contém pedido inelegível ou já acertado. " +
          "Atualize o caixa.");
      }
      checkFinancial(order, official);
      if (uid && uid !== assigned) {
        reject("Selecione pedidos do mesmo motoboy.");
      }
      uid = assigned;
      const fee = cents(official.deliveryFee);
      // Mirrors must agree with the immutable backend record, never historical
      // repricing or accepting submitted totals.
      for (const field of ["itemsTotal", "deliveryFee", "customerFee",
        "merchantFee", "merchantNet", "platformFee", "totalBRL"]) {
        if (cents(order[field]) !== cents(official[field])) {
          reject("Valores divergentes. Revisão financeira necessária.");
        }
      }
      total += fee;
      if (!Number.isSafeInteger(total)) reject("Lote excede limite de valor.");
      lines.push({documentId: ids[i],
        id: typeof order.id === "string" ? order.id : ids[i],
        deliveryFee: fee / 100});
    }
    const profile = await tx.get(db.doc(`couriers/${uid}`));
    if (!profile.exists || typeof profile.data().name !== "string" ||
        !profile.data().name.trim()) reject("Cadastro de motoboy inválido.");
    const name = profile.data().name.trim();
    for (const snapshot of orders) {
      tx.update(snapshot.ref, {courierPaid: true,
        courierPaidAt: FieldValue.serverTimestamp(), courierSettlementId: id});
    }
    tx.create(ref, {courierUid: uid, courierName: name, orderDocumentIds: ids,
      orders: lines, total: total / 100, orderCount: ids.length, status: "paid",
      createdAt: FieldValue.serverTimestamp(), actorUid, fingerprint,
      version: 1});
    return {settlementId: id, replayed: false};
  });
}

/** Registers authenticated operations with shared financial/stock helpers.
 * @param {Object} db Firestore.
 * @param {Object} helpers Existing, unchanged business algorithms.
 * @return {Object} Callable exports.
 */
function createOrderOperations(db, helpers) {
  const options = {region: "southamerica-east1", maxInstances: 10};
  return {
    chamaeIniciarSeparacao: onCall(options, (request) => moveOrder(db, request,
        "separate", helpers.resolveReservation, helpers.checkFinancial)),
    chamaeConcluirEntrega: onCall(options, (request) => moveOrder(db, request,
        "complete", helpers.resolveReservation, helpers.checkFinancial)),
    chamaeRegistrarAcertoMotoboy: onCall(options, (request) =>
      settleCourier(db, request, helpers.checkFinancial)),
  };
}

module.exports = {moveOrder, settleCourier, authorizeSettlement, cents,
  payload, createOrderOperations};
