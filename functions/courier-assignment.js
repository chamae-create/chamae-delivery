const {createHash, randomUUID} = require("node:crypto");
const {onCall, HttpsError} = require("firebase-functions/v2/https");
const {Timestamp, FieldValue, FieldPath} = require("firebase-admin/firestore");
const {courierUid, isAssignableCourier, planCourierDelivery,
  writeCourierDelivery} = require("./courier-deliveries");

/**
 * Rejeita anônimos e roles desconhecidas antes de qualquer acesso a dados.
 * @param {Object} request CallableRequest verificada pelo Firebase.
 * @param {string[]} acceptedRoles Backend-controlled roles.
 * @return {string} UID do operador autorizado.
 */
function authorize(request, acceptedRoles = [
  "operations_admin", "superadmin",
]) {
  const auth = request.auth;
  const token = (auth && auth.token) || {};
  if (!auth || typeof auth.uid !== "string" || !auth.uid ||
      (token.firebase &&
       token.firebase.sign_in_provider === "anonymous")) {
    throw new HttpsError("unauthenticated", "Entre para continuar.");
  }
  const roles = token.roles;
  if (!Array.isArray(roles) || !roles.some((role) =>
    acceptedRoles.includes(role))) {
    throw new HttpsError("permission-denied", "Ação não autorizada.");
  }
  return auth.uid;
}

/**
 * IDs documentais não são nomes ou caminhos enviados pelo navegador.
 * @param {*} id ID a validar.
 * @return {string} ID validado.
 */
function orderId(id) {
  if (typeof id !== "string" || !id || id.includes("/") ||
      id === "." || id === ".." || Buffer.byteLength(id) > 1500) {
    throw new HttpsError("invalid-argument", "Pedido inválido.");
  }
  return id;
}

/**
 * Mesmo limite operacional das Rules existentes, sem alterar pagamentos.
 * @param {Object} order Pedido atual.
 * @return {boolean} Pedido está liberado para despacho.
 */
function readyForDispatch(order) {
  const financial = order.financialValidationStatus === "validated";
  if (!financial ||
      ["requires_review", "error", "released"].includes(
          order.stockReservationStatus) ||
      order.stockProcessingStatus === "requires_review" ||
      order.stockProcessingError != null ||
      order.stockReservationError != null) {
    return false;
  }
  const pix = (value) => typeof value === "string" && /pix/i.test(value);
  const hasPix = order.pixRequested === true || pix(order.paymentMethod) ||
    (Array.isArray(order.paymentParts) && order.paymentParts.some((part) =>
      part && [part.method, part.paymentMethod, part.type].some(pix)));
  return hasPix ? order.paymentStatus === "Pago" &&
    order.stockProcessingStatus === "processed" :
    order.stockReservationRequired !== true ||
    ["reserved", "finalized"].includes(order.stockReservationStatus);
}

/**
 * Atribuição, remoção e despacho usam uma transação e um ledger de reexecução.
 * @param {Object} db Firestore Admin SDK.
 * @param {Object} request CallableRequest.
 * @param {string} operation assign ou dispatch.
 * @return {Promise<Object>} Resultado sem dados do cliente.
 */
async function changeCourier(db, request, operation = "assign") {
  const actorUid = authorize(request);
  const data = request.data;
  const allowed = operation === "assign" ?
    ["orderId", "courierUid", "expectedCourierUid", "requestId"] :
    ["orderId", "expectedCourierUid", "requestId"];
  if (!data || typeof data !== "object" || Array.isArray(data) ||
      Object.keys(data).some((key) => !allowed.includes(key))) {
    throw new HttpsError("invalid-argument", "Solicitação inválida.");
  }
  const id = orderId(data.orderId);
  const target = data.courierUid == null ? "" : data.courierUid;
  if (operation === "assign" && (!Object.hasOwn(data, "courierUid") ||
      (target !== "" && !courierUid(target)))) {
    throw new HttpsError("invalid-argument", "Motoboy inválido.");
  }
  const expected = data.expectedCourierUid;
  if (expected !== undefined && expected !== "" && !courierUid(expected)) {
    throw new HttpsError("invalid-argument", "Vínculo esperado inválido.");
  }
  const requestId = data.requestId === undefined ?
    randomUUID() : data.requestId;
  if (typeof requestId !== "string" ||
      !/^[A-Za-z0-9_-]{16,100}$/.test(requestId)) {
    throw new HttpsError("invalid-argument", "Identificador inválido.");
  }
  const fingerprint = createHash("sha256").update(JSON.stringify({
    operation, orderId: id, courierUid: target,
    expectedCourierUid: expected === undefined ? null : expected,
  })).digest("hex");
  const ledgerId = createHash("sha256")
      .update(`${actorUid}:${requestId}`).digest("hex");
  const ledgerRef = db.collection("courierAssignmentRequests").doc(ledgerId);
  const orderRef = db.collection("orders").doc(id);
  const deliveryRef = db.collection("courierDeliveries").doc(id);
  const auditRef = db.collection("courierDeliveryAudit").doc();
  return db.runTransaction(async (transaction) => {
    const receipt = await transaction.get(ledgerRef);
    if (receipt.exists) {
      if (receipt.data().fingerprint !== fingerprint) {
        throw new HttpsError("already-exists", "Tentativa já utilizada.");
      }
      return {orderId: id, courierUid: receipt.data().courierUid,
        changed: false, replayed: true};
    }
    const snapshot = await transaction.get(orderRef);
    if (!snapshot.exists) {
      throw new HttpsError("not-found", "Pedido não existe.");
    }
    const source = snapshot.data();
    if (source.financialValidationStatus !== "validated") {
      throw new HttpsError("failed-precondition",
          "Pedido sem validação financeira oficial. Histórico não operável.");
    }
    const oldUid = courierUid(source.courierUid);
    const uid = operation === "dispatch" ? oldUid : target;
    const projection = await transaction.get(deliveryRef);
    const previous = projection.exists ? projection.data() : {};
    if (expected !== undefined && expected !== oldUid) {
      throw new HttpsError("aborted", "A atribuição do pedido mudou.");
    }
    if (operation === "assign" &&
        (!["Novo", "Em Separação"].includes(source.status) ||
         source.courierPaid === true || source.courierSettlementId != null)) {
      throw new HttpsError("failed-precondition",
          "Atribuição só pode mudar antes da saída e do acerto.");
    }
    let courier = null;
    if (uid) {
      const profile = await transaction.get(db.collection("couriers").doc(uid));
      if (!profile.exists) {
        throw new HttpsError("not-found", "Motoboy não encontrado.");
      }
      courier = profile.data();
      if (!isAssignableCourier(courier)) {
        throw new HttpsError("failed-precondition", "Motoboy não habilitado.");
      }
    }
    if (operation === "dispatch" && (!uid ||
        !["Em Separação", "Saiu para Entrega"].includes(source.status) ||
        !readyForDispatch(source))) {
      throw new HttpsError("failed-precondition",
          "Confira a liberação do pedido e atribua um motoboy ativo.");
    }
    {
      const financial = await transaction.get(
          db.collection("orderFinancials").doc(id));
      const official = financial.exists ? financial.data() : {};
      const fields = ["itemsTotal", "deliveryFee", "customerFee",
        "merchantFee", "merchantNet", "platformFee", "totalBRL"];
      if (!financial.exists || fields.some((field) =>
        typeof official[field] !== "number" ||
        !Number.isFinite(official[field]) ||
        official[field] < 0 || source[field] !== official[field])) {
        throw new HttpsError("failed-precondition",
            "Validação financeira oficial ausente ou divergente.");
      }
    }
    const now = Timestamp.now();
    const plan = planCourierDelivery({
      orderId: id, order: source, previous, exists: projection.exists,
      registered: !!courier, now, binding: {
        courierUid: uid,
        status: operation === "dispatch" ? "Saiu para Entrega" : source.status,
      },
    });
    if (uid && plan.revoked) {
      throw new HttpsError("failed-precondition",
          "Nome ou rota inválidos. Confira os dados do pedido.");
    }
    const patch = {};
    const name = courier ? courier.name.trim() : "";
    if (source.courierUid !== uid || source.courierName !== name) {
      patch.courierUid = uid;
      patch.courierName = name;
    }
    if (operation === "assign") {
      if (uid && (uid !== oldUid ||
          !(source.courierAssignedAt instanceof Timestamp))) {
        patch.courierAssignedAt = FieldValue.serverTimestamp();
      } else if (!uid && (Object.keys(patch).length ||
          Object.hasOwn(source, "courierAssignedAt"))) {
        patch.courierAssignedAt = FieldValue.delete();
        patch.courierUnassignedAt = FieldValue.serverTimestamp();
      }
    } else if (source.status !== "Saiu para Entrega") {
      patch.status = "Saiu para Entrega";
      patch.dispatchedAt = FieldValue.serverTimestamp();
    }
    const changed = Object.keys(patch).length > 0;
    if (changed) {
      patch.updatedAt = FieldValue.serverTimestamp();
      transaction.update(orderRef, patch);
    }
    writeCourierDelivery(transaction, {
      plan, deliveryRef, auditRef, orderId: id, previous, actorUid,
    });
    transaction.create(ledgerRef, {
      actorUid, orderId: id, courierUid: uid, operation, fingerprint,
      createdAt: FieldValue.serverTimestamp(),
    });
    return {orderId: id, courierUid: uid, changed: changed || plan.changed};
  });
}

/**
 * Lista paginada mínima para operadores sem acesso livre à coleção couriers.
 * @param {Object} db Firestore Admin SDK.
 * @param {Object} request CallableRequest.
 * @return {Promise<Object>} Somente UID e nome, sem presença inventada.
 */
async function listCouriers(db, request) {
  authorize(request);
  const data = request.data || {};
  if (typeof data !== "object" || Array.isArray(data) ||
      Object.keys(data).some((key) => key !== "cursor") ||
      (data.cursor !== undefined && !courierUid(data.cursor))) {
    throw new HttpsError("invalid-argument", "Página inválida.");
  }
  let query = db.collection("couriers")
      .where("administrativeState", "==", "active")
      .orderBy(FieldPath.documentId()).limit(51);
  if (data.cursor) query = query.startAfter(data.cursor);
  const snapshot = await query.get();
  return {
    couriers: snapshot.docs.slice(0, 50)
        .filter((row) => courierUid(row.id) && isAssignableCourier(row.data()))
        .map((row) => ({uid: row.id, name: row.data().name.trim()})),
    nextCursor: snapshot.size > 50 ? snapshot.docs[49].id : null,
  };
}

/**
 * Factory sem secrets ou endpoints públicos de escrita Firestore.
 * @param {Object} db Firestore Admin SDK.
 * @return {Object} Callables registradas na mesma região do painel.
 */
function createCourierAssignmentFunctions(db) {
  const options = {region: "southamerica-east1", maxInstances: 10};
  return {
    chamaeAtribuirMotoboy: onCall(options,
        (request) => changeCourier(db, request)),
    chamaeDespacharPedido: onCall(options,
        (request) => changeCourier(db, request, "dispatch")),
    chamaeListarMotoboysAtribuiveis: onCall(options,
        (request) => listCouriers(db, request)),
  };
}

module.exports = {
  authorize, changeCourier, listCouriers, readyForDispatch,
  createCourierAssignmentFunctions,
};
