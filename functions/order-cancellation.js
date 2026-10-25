const {createHash} = require("node:crypto");
const {onCall, HttpsError} = require("firebase-functions/v2/https");
const {FieldValue} = require("firebase-admin/firestore");
const {authorize} = require("./courier-assignment");
const {isCancelled, fail, financialCompensation} = require("./order-cancellation-state");
const {needsReturnProof, assertReturnProof} = require("./delivery-contingency-state");
const hash = (value) => createHash("sha256").update(value).digest("hex");
const state = (order) => ({status: order.status, paymentStatus: order.paymentStatus,
  reservation: order.stockReservationStatus || "pending", processed: order.stockProcessingStatus || "pending"});

function input(request, operation) {
  const actorUid = authorize(request, operation === "restock" ? ["superadmin"] : ["operations_admin", "superadmin"]);
  const data = request.data;
  if (!data || typeof data !== "object" || Array.isArray(data) ||
      Object.keys(data).some((key) => !["orderId", "requestId", "reason", "confirmation"].includes(key)) ||
      typeof data.orderId !== "string" || !/^[A-Za-z0-9_-]{1,128}$/.test(data.orderId) ||
      typeof data.requestId !== "string" || !/^[A-Za-z0-9_-]{16,100}$/.test(data.requestId) ||
      typeof data.reason !== "string" || data.reason.trim().length < 10 || data.reason.trim().length > 500 ||
      data.confirmation !== `${operation === "restock" ? "DEVOLVER" : "CANCELAR"} ${data.orderId}`) {
    throw new HttpsError("invalid-argument", "Informe motivo e confirme o pedido.");
  }
  return {actorUid, orderId: data.orderId, requestId: data.requestId, reason: data.reason.trim(),
    privileged: request.auth.token.roles.includes("superadmin")};
}

function itemsFor(order, financial) {
  const list = financial?.items || order.itemsList;
  if (!Array.isArray(list) || !list.length || list.length > 100) fail("CANCELLATION_ITEMS_REVIEW_REQUIRED");
  const items = new Map();
  for (const item of list) {
    if (!item || typeof item.id !== "string" || !item.id || item.id.includes("/") ||
        !Number.isSafeInteger(item.quantity) || item.quantity <= 0) fail("CANCELLATION_ITEMS_REVIEW_REQUIRED");
    const q = (items.get(item.id) || 0) + item.quantity;
    if (!Number.isSafeInteger(q)) fail("CANCELLATION_ITEMS_REVIEW_REQUIRED");
    items.set(item.id, q);
  }
  return [...items].map(([id, quantity]) => ({id, quantity}));
}
function inventoryState(order) {
  if (order.stockReservationStatus === "reserved" && order.stockProcessed === true) fail("STOCK_STATE_REVIEW_REQUIRED");
  if (order.stockReservationStatus === "reserved") {
    if (order.stockReservedBy !== "firestore_order_trigger") fail("STOCK_MODEL_UNVERIFIED");
    return "reserved";
  }
  if (order.stockReservationStatus === "finalized" || order.stockProcessingStatus === "processed") {
    if (order.stockProcessed !== true || !["stock_reservation_finalizer", "mercado_pago_webhook"]
        .includes(order.stockProcessedBy)) fail("STOCK_MODEL_UNVERIFIED");
    return "committed";
  }
  if ([undefined, null, "released"].includes(order.stockReservationStatus) &&
      [undefined, null].includes(order.stockProcessingStatus) && order.stockProcessed !== true) {
    return order.stockReservationStatus === "released" ? "released" : "pending";
  }
  fail("STOCK_STATE_REVIEW_REQUIRED");
}

async function compensate(db, command, operation, helpers) {
  const {orderId, actorUid, requestId, reason} = command;
  const fingerprint = hash(JSON.stringify([operation, orderId, reason]));
  const receiptRef = db.collection("orderCompensationRequests").doc(hash(`${actorUid}:${requestId}`));
  const ref = db.collection("orders").doc(orderId);
  const cancellationRef = db.collection("orderCancellations").doc(orderId);
  const returnRef = db.collection("orderReturns").doc(orderId);
  const compensationRef = db.collection("orderCompensations").doc(orderId);
  return db.runTransaction(async (tx) => {
    const receipt = await tx.get(receiptRef);
    if (receipt.exists) {
      if (receipt.data().fingerprint !== fingerprint) throw new HttpsError("already-exists", "Tentativa já utilizada.");
      return {orderId, operation, replayed: true};
    }
    const snapshot = await tx.get(ref);
    const cancellation = await tx.get(cancellationRef);
    const returned = await tx.get(returnRef);
    const physicalReturn = await tx.get(db.doc(`orderDeliveryIncidents/${orderId}`));
    const financialDoc = await tx.get(db.collection("orderFinancials").doc(orderId));
    const actorCourier = await tx.get(db.collection("couriers").doc(actorUid));
    if (actorCourier.exists) throw new HttpsError("permission-denied", "Perfil sem permissão.");
    if (!snapshot.exists) throw new HttpsError("not-found", "Pedido não encontrado.");
    const order = snapshot.data();
    const financial = financialDoc.exists ? financialDoc.data() : null;
    if (command.provider) {
      if (order.paymentMethod !== "PIX" || order.splitPayment === true ||
          order.mercadoPagoOrderId !== command.provider.orderId || !financial ||
          !Number.isFinite(command.provider.amount) ||
          Math.round(command.provider.amount * 100) !== Math.round(financial.totalBRL * 100)) {
        fail("PROVIDER_CANCELLATION_MISMATCH");
      }
      if (order.paymentStatus === "Pago" || order.status === "Concluído") return {orderId, ignored: true};
    }
    if (operation === "cancel" && cancellation.exists || operation === "restock" && returned.exists) {
      tx.set(receiptRef, {orderId, operation, fingerprint, replayed: true, createdAt: FieldValue.serverTimestamp()});
      if (command.provider) {
        tx.update(ref, {mercadoPagoStatus: command.provider.status, mercadoPagoStatusDetail: command.provider.detail});
        tx.set(compensationRef, {providerCancellationStatus: "confirmed", refundStatus: "not_required",
          financialAction: "none", updatedAt: FieldValue.serverTimestamp()}, {merge: true});
      }
      return {orderId, operation, replayed: true};
    }
    if (operation === "cancel" && order.status === "Concluído") fail("COMPLETED_ORDER_REQUIRES_RETURN");
    if (operation === "cancel" && isCancelled(order)) fail("LEGACY_CANCELLATION_REVIEW_REQUIRED");
    if (!["Pago", "Aguardando confirmação", "Pendente na entrega", "Pendente"].includes(order.paymentStatus)) {
      fail("PAYMENT_STATE_REVIEW_REQUIRED");
    }
    if (order.paymentStatus === "Pago" && !command.privileged) {
      throw new HttpsError("permission-denied", "Requer superadmin.");
    }
    if (!["Novo", "Aguardando pagamento", "Em Separação", "Aguardando Retirada", "Saiu para Entrega", "Concluído",
      "Revisão financeira", "Revisão de estoque"]
        .includes(order.status) && !(operation === "restock" && isCancelled(order))) {
      fail("ORDER_STATE_REVIEW_REQUIRED");
    }
    const inventory = inventoryState(order);
    if (operation === "restock" || operation === "cancel" &&
        inventory === "reserved" && needsReturnProof(order)) {
      assertReturnProof(order, physicalReturn.exists ? physicalReturn.data() : null);
    }
    if ((inventory === "reserved" || inventory === "committed" || order.paymentStatus === "Pago") && !financial) {
      fail("OFFICIAL_FINANCIAL_REQUIRED");
    }
    if (financial) helpers.checkFinancial(order, financial);
    if (operation === "restock" && (inventory !== "committed" ||
        !isCancelled(order) && order.status !== "Concluído")) fail("RETURN_REQUIRES_VALID_COMMIT");
    const items = itemsFor(order, financial);
    const products = [];
    for (const item of items) {
      const productRef = db.collection("products").doc(item.id);
      const doc = await tx.get(productRef);
      const product = doc.exists ? doc.data() : null;
      if (product && product.PRO_CODIGO != null ||
          order.stockModel != null && order.stockModel !== "firebase_existing") {
        fail("INTEGRATED_STOCK_COMPENSATION_UNAVAILABLE");
      }
      if (inventory === "reserved" && (!product || !Number.isSafeInteger(product.reservedStock) ||
          product.reservedStock < item.quantity)) fail("STOCK_STATE_REVIEW_REQUIRED");
      if (operation === "restock" && (!product || !Number.isSafeInteger(product.stock) || product.stock < 0 ||
          !Number.isSafeInteger(product.stock + item.quantity))) fail("RESTOCK_PRODUCT_REVIEW_REQUIRED");
      products.push({...item, ref: productRef, product});
    }
    const stamp = FieldValue.serverTimestamp();
    let stockAction = "none";
    if (operation === "cancel" && inventory === "reserved") {
      // Shared existing local RELEASE, strict and atomic with cancellation.
      await helpers.release(tx, ref, orderId, false, true);
      stockAction = "release_local_reservation";
    }
    if (operation === "restock") {
      for (const item of products) tx.update(item.ref, {stock: item.product.stock + item.quantity});
      stockAction = "restock_local_after_verified_commit";
    }
    const next = operation === "cancel" ? "Cancelado" : order.status;
    const compensation = financialCompensation(order, financial);
    if (command.provider) {
      Object.assign(compensation, {providerCancellationStatus: "confirmed",
        refundStatus: "not_required", financialAction: "none"});
    }
    tx.update(ref, {status: next, ...(operation === "cancel" ? {cancellationStatus: "cancelled", cancelledAt: stamp} :
      {returnStatus: "restocked", returnedAt: stamp}),
    compensationStatus: compensation.refundStatus === "not_required" && inventory !== "committed" ?
      "not_required" : "required",
    ...(command.provider ? {mercadoPagoStatus: command.provider.status,
      mercadoPagoStatusDetail: command.provider.detail} : {})});
    tx.set(compensationRef, {...compensation, inventoryState: operation === "restock" ? "restocked" :
      inventory === "reserved" ? "released" : inventory,
    stockAction, originalPaymentStatus: order.paymentStatus, updatedAt: stamp}, {merge: true});
    tx.set(operation === "cancel" ? cancellationRef : returnRef, {schemaVersion: 1, orderId, actorUid, reason,
      previous: state(order), nextStatus: next, stockAction, financialAction: compensation.financialAction,
      inventoryState: operation === "restock" ? "restocked" : inventory === "reserved" ? "released" : inventory,
      physicalReturnRevision: physicalReturn.exists ? physicalReturn.data().revision : null,
      createdAt: stamp});
    tx.set(receiptRef, {orderId, operation, fingerprint, createdAt: stamp});
    return {orderId, operation, replayed: false};
  });
}

function createOrderCancellation(db, helpers) {
  const options = {region: "southamerica-east1", maxInstances: 5};
  return {
    chamaeCancelarPedido: onCall(options, (request) => compensate(db, input(request, "cancel"), "cancel", helpers)),
    chamaeAutorizarDevolucaoPedido: onCall(options, (request) =>
      compensate(db, input(request, "restock"), "restock", helpers)),
  };
}
async function cancelFromProvider(db, orderId, provider, helpers) {
  if (!(provider.status === "canceled" && ["canceled", "expired"].includes(provider.detail) ||
      provider.status === "failed" && provider.detail === "expired")) fail("PROVIDER_TERMINAL_UNCONFIRMED");
  return compensate(db, {actorUid: "mercado_pago_webhook", orderId, privileged: true,
    reason: "Cancelamento/expiração confirmado pela consulta oficial do provedor.",
    requestId: hash(`${orderId}:${provider.orderId}:terminal`), provider}, "cancel", helpers);
}
module.exports = {input, itemsFor, inventoryState, compensate, createOrderCancellation, cancelFromProvider};
