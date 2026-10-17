const {isDeepStrictEqual} = require("node:util");
const {GeoPoint, Timestamp, FieldValue} = require("firebase-admin/firestore");
const {onDocumentWritten} = require("firebase-functions/v2/firestore");

const STATUSES = new Set([
  "Novo", "Em Separação", "Saiu para Entrega", "Concluído", "Cancelado",
]);
const PHONE = new RegExp("(?:^|[^\\d])(?:\\+\\d{1,3}[ .-]*)?" +
    "\\(?\\d{2}\\)?[ .-]*9?\\d{4}[ .-]*\\d{4}(?:$|[^\\d])", "u");

/**
 * Impede controles/caracteres invisíveis em UIDs e textos operacionais.
 * @param {string} text Texto a validar.
 * @return {boolean} Existe algum controle.
 */
function hasControl(text) {
  return Array.from(text).some((character) => {
    const code = character.codePointAt(0);
    return code < 32 || (code >= 127 && code <= 159) ||
      (code >= 0x200b && code <= 0x200f) ||
      (code >= 0x202a && code <= 0x202e) ||
      (code >= 0x2060 && code <= 0x206f);
  });
}

/**
 * Aceita apenas um UID explícito; nunca resolve nomes de exibição.
 * @param {*} value UID informado pelo backend atribuidor.
 * @return {string} UID ou string vazia.
 */
function courierUid(value) {
  return typeof value === "string" && value.length > 0 &&
    value.length <= 128 && value.trim() === value &&
    !/[\s/]/u.test(value) && !hasControl(value) &&
    value !== "." && value !== ".." ?
    value : "";
}

/**
 * Não replica status livres, que podem conter informações indevidas.
 * Cancelamentos seguem a convenção já usada pelo resolvedor de estoque.
 * @param {*} value Status original.
 * @return {string} Status operacional conhecido ou string vazia.
 */
function operationalStatus(value) {
  if (typeof value !== "string") return "";
  const status = value.trim();
  if (/cancel/i.test(status)) return "Cancelado";
  return STATUSES.has(status) ? status : "";
}

/**
 * Texto de rota limitado; contato embutido também impede a publicação.
 * Não aplica conversão de objetos para strings nem copia mapas livres.
 * @param {*} value Campo de texto.
 * @param {number} limit Comprimento máximo.
 * @return {?string} Texto seguro, vazio quando ausente, null se inadequado.
 */
function routeText(value, limit) {
  if (value == null || value === "") return "";
  if (typeof value !== "string") return null;
  const text = value.normalize("NFKC").trim();
  if (text.length > limit || hasControl(text)) return null;
  if (
    /@|https?:\/\/|www\.|wa\.me|mailto:|tel:/iu.test(text) ||
    /whats?app|telefone|e-?mail|mercado[\s_-]*pago|customerUid/iu.test(text) ||
    PHONE.test(text) ||
    /\b\d{4,5}[-.]\d{4}\b|\b9\d{8}\b/u.test(text)
  ) return null;
  return text;
}

/**
 * Obtém somente coordenadas numéricas, sem campos aninhados do endereço.
 * @param {Object} order Pedido atual.
 * @param {Object} address Endereço estruturado atual.
 * @return {?GeoPoint} Coordenadas válidas.
 */
function location(order, address) {
  if (order.deliveryLocation instanceof GeoPoint) {
    return new GeoPoint(order.deliveryLocation.latitude,
        order.deliveryLocation.longitude);
  }
  if (typeof address.latitude !== "number" ||
      typeof address.longitude !== "number" ||
      !Number.isFinite(address.latitude) ||
      !Number.isFinite(address.longitude) ||
      Math.abs(address.latitude) > 90 || Math.abs(address.longitude) > 180) {
    return null;
  }
  return new GeoPoint(address.latitude, address.longitude);
}

/**
 * Constrói a allowlist campo a campo. Não inclui valores a cobrar.
 * @param {string} orderId ID documental, nunca o identificador amigável.
 * @param {Object} order Pedido atual.
 * @param {Object} previous Projeção anterior, apenas para timestamps.
 * @param {Timestamp} now Instante de observação operacional.
 * @param {Object} binding Vínculo/status autoritativo da transação, se houver.
 * @return {?Object} Projeção utilizável ou null.
 */
function buildCourierDelivery(orderId, order, previous, now, binding = {}) {
  const uid = courierUid(binding.courierUid === undefined ?
    order.courierUid : binding.courierUid);
  const status = operationalStatus(binding.status || order.status);
  const address = order.deliveryAddress &&
    typeof order.deliveryAddress === "object" &&
    !Array.isArray(order.deliveryAddress) ? order.deliveryAddress : {};
  const customerName = routeText(order.customerName, 120);
  const route = routeText(address.addressText == null ?
    order.address : address.addressText, 500);
  const complement = routeText(address.complement == null ?
    order.complement : address.complement, 250);
  const reference = routeText(address.reference == null ?
    order.reference : address.reference, 250);
  const point = location(order, address);
  if (!uid || !status || !customerName || !route || !point ||
      complement === null || reference === null) return null;

  const sameCourier = previous.courierUid === uid;
  const delivery = {
    orderId,
    courierUid: uid,
    customerName,
    address: route,
    deliveryLocation: point,
    status,
    createdAt: previous.createdAt instanceof Timestamp ?
      previous.createdAt : now,
    assignedAt: sameCourier && previous.assignedAt instanceof Timestamp ?
      previous.assignedAt : now,
  };
  if (complement) delivery.complement = complement;
  if (reference) delivery.reference = reference;
  if (status === "Saiu para Entrega" || status === "Concluído") {
    if (sameCourier && previous.pickedUpAt instanceof Timestamp) {
      delivery.pickedUpAt = previous.pickedUpAt;
    } else if (status === "Saiu para Entrega") {
      delivery.pickedUpAt = now;
    }
  }
  if (status === "Concluído") {
    delivery.completedAt = previous.completedAt instanceof Timestamp ?
      previous.completedAt : now;
  }
  return delivery;
}

/**
 * Revoga o acesso sem apagar o registro operacional. Sem nome ou rota.
 * @param {string} orderId ID documental.
 * @param {?Object} order Pedido atual, se existir.
 * @param {Object} previous Projeção anterior.
 * @param {Timestamp} now Instante de observação.
 * @return {Object} Marcador inacessível para qualquer UID autenticado.
 */
function revokedDelivery(orderId, order, previous, now) {
  const delivery = {
    orderId,
    courierUid: "",
    createdAt: previous.createdAt instanceof Timestamp ?
      previous.createdAt : now,
  };
  const status = operationalStatus(order && order.status) ||
    operationalStatus(previous.status);
  if (status) delivery.status = status;
  for (const key of ["assignedAt", "pickedUpAt", "completedAt"]) {
    if (previous[key] instanceof Timestamp) delivery[key] = previous[key];
  }
  return delivery;
}

/**
 * Compara a allowlist inteira, inclusive removendo campos legados indevidos.
 * @param {Object} previous Documento salvo.
 * @param {Object} next Allowlist desejada, sem updatedAt.
 * @return {boolean} Documento já é a projeção exata e tem timestamp válido.
 */
function unchanged(previous, next) {
  return previous.updatedAt instanceof Timestamp &&
    Object.keys(previous).length === Object.keys(next).length + 1 &&
    Object.keys(next).every((key) =>
      isDeepStrictEqual(previous[key], next[key]));
}

/**
 * Habilitação explícita, sem presumir atividade de cadastro legado.
 * @param {?Object} data Cadastro oficial.
 * @return {boolean} Cadastro pode receber atribuição.
 */
function isAssignableCourier(data) {
  return !!data && data.administrativeState === "active" &&
    data.enabled !== false && data.isActive !== false &&
    data.active !== false &&
    typeof data.name === "string" && data.name.trim().length > 0 &&
    data.name.trim().length <= 120;
}

/**
 * Única lógica de projeção/revogação para trigger e callables atômicas.
 * @param {Object} options Estado lido na transação.
 * @return {Object} Plano sem operações de escrita.
 */
function planCourierDelivery(options) {
  const {orderId, order, previous, exists, registered, now, binding} = options;
  let next = registered && order ?
    buildCourierDelivery(orderId, order, previous, now, binding) : null;
  if (!next && !exists) {
    return {changed: false, revoked: true, delivery: null};
  }
  const revoked = !next;
  if (revoked) next = revokedDelivery(orderId, order, previous, now);
  return {changed: !unchanged(previous, next), revoked, delivery: next};
}

/**
 * Persiste plano e auditoria na transação do chamador, sem novos reads.
 * @param {Object} transaction Transação Admin SDK.
 * @param {Object} options Referências, plano e identidade do operador.
 */
function writeCourierDelivery(transaction, options) {
  const {plan, deliveryRef, auditRef, orderId, previous, actorUid} = options;
  if (!plan.changed) return;
  plan.delivery.updatedAt = FieldValue.serverTimestamp();
  transaction.set(deliveryRef, plan.delivery);
  const audit = {
    orderId,
    previousCourierUid: courierUid(previous.courierUid),
    courierUid: plan.delivery.courierUid,
    previousStatus: operationalStatus(previous.status),
    status: plan.delivery.status || "",
    reason: plan.revoked ? "revoked" : "synchronized",
    changedAt: FieldValue.serverTimestamp(),
  };
  if (actorUid) audit.actorUid = actorUid;
  transaction.create(auditRef, audit);
}

/**
 * Reconcilia o estado ATUAL em transação; não usa o payload possivelmente
 * atrasado do evento. Nenhuma escrita é feita em orders/couriers/financeiro.
 * @param {Object} db Firestore Admin SDK.
 * @param {string} orderId ID documental do pedido.
 * @return {Promise<Object>} Resultado sem dados pessoais do cliente.
 */
async function syncCourierDelivery(db, orderId) {
  if (typeof orderId !== "string" || !orderId || orderId.includes("/") ||
      orderId === "." || orderId === "..") throw new Error("INVALID_ORDER_ID");
  const orderRef = db.collection("orders").doc(orderId);
  const deliveryRef = db.collection("courierDeliveries").doc(orderId);
  const auditRef = db.collection("courierDeliveryAudit").doc();
  return db.runTransaction(async (transaction) => {
    const orderSnapshot = await transaction.get(orderRef);
    const deliverySnapshot = await transaction.get(deliveryRef);
    const order = orderSnapshot.exists ? orderSnapshot.data() : null;
    const previous = deliverySnapshot.exists ? deliverySnapshot.data() : {};
    const uid = order ? courierUid(order.courierUid) : "";
    let registered = false;
    if (uid) {
      const courier = await transaction.get(db.collection("couriers").doc(uid));
      registered = courier.exists && isAssignableCourier(courier.data());
    }
    const now = Timestamp.now();
    const plan = planCourierDelivery({
      orderId, order, previous, exists: deliverySnapshot.exists,
      registered, now,
    });
    writeCourierDelivery(transaction, {
      plan, deliveryRef, auditRef, orderId, previous,
    });
    return {changed: plan.changed, revoked: plan.revoked};
  });
}

/**
 * Registra somente o produtor sanitizado, sem secrets ou chamadas de pagamento.
 * @param {Object} db Firestore Admin SDK.
 * @return {Function} Trigger de criação, atualização e exclusão de orders.
 */
function createCourierDeliveryTrigger(db) {
  return onDocumentWritten({
    document: "orders/{orderId}",
    region: "southamerica-east1",
    maxInstances: 10,
    retry: true,
  }, (event) => syncCourierDelivery(db, event.params.orderId));
}

module.exports = {
  buildCourierDelivery, syncCourierDelivery, createCourierDeliveryTrigger,
  planCourierDelivery, writeCourierDelivery, isAssignableCourier, courierUid,
};
