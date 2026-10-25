const {createHash} = require("node:crypto");
const {onCall, HttpsError} = require("firebase-functions/v2/https");
const {onDocumentWritten} = require("firebase-functions/v2/firestore");
const {FieldValue} = require("firebase-admin/firestore");
const {getAuth} = require("firebase-admin/auth");
const {verifiedCustomerToken} = require("./customer-identity");
const {tokenHasApple, ensureAppleRevoked, sameClosureAttempt} = require("./customer-provider-revocation");

const options = {region: "southamerica-east1", maxInstances: 5};
const pageSize = 100;
const pending = () => new HttpsError("failed-precondition",
    "Há um pedido ou pagamento em andamento. Aguarde a conclusão ou fale com a loja antes de excluir a conta.",
    {reason: "ACTIVE_ORDER"});

function owner(request) {
  const auth = request.auth;
  const token = auth?.token || {};
  if (!auth || typeof auth.uid !== "string" || !auth.uid || auth.uid.includes("/") ||
      !verifiedCustomerToken(token) ||
      !Array.isArray(token.roles || []) || (token.roles || []).length) {
    throw new HttpsError("permission-denied", "Entre com sua conta de cliente para continuar.");
  }
  return auth.uid;
}

function closedOrder(order) {
  if (!["Concluído", "Cancelado"].includes(order.status)) return false;
  if (["reserved", "processing", "requires_review", "error"].includes(order.stockReservationStatus) ||
      ["processing", "requires_review", "error"].includes(order.stockProcessingStatus)) return false;
  if (order.status === "Concluído") return order.paymentStatus === "Pago";
  const issuedPix = order.mercadoPagoOrderId || order.mercadoPagoPaymentId || order.mercadoPagoQrCode;
  return order.mercadoPagoCreateStatus !== "creating" && (!issuedPix ||
    ["cancelled", "canceled", "rejected", "expired", "refunded"].includes(order.mercadoPagoStatus));
}

async function requestClosure(db, request, now = Date.now()) {
  const uid = owner(request);
  const data = request.data;
  if (!data || typeof data !== "object" || Array.isArray(data) ||
      Object.keys(data).some((k) => !["confirmation", "requestId", "expectedUid"].includes(k)) ||
      data.expectedUid !== uid ||
      data.confirmation !== "EXCLUIR MINHA CONTA" ||
      typeof data.requestId !== "string" || !/^[A-Za-z0-9_-]{16,100}$/.test(data.requestId)) {
    throw new HttpsError("invalid-argument", "Confirme a exclusão da sua conta.");
  }
  const ref = db.collection("customerAccountClosures").doc(uid);
  return db.runTransaction(async (tx) => {
    const previous = await tx.get(ref);
    const courier = await tx.get(db.collection("couriers").doc(uid));
    if (courier.exists) throw new HttpsError("permission-denied", "Acesso restrito à conta de cliente.");
    if (previous.exists && previous.data().status !== "blocked") {
      return {status: previous.data().status};
    }
    const authTime = request.auth.token.auth_time;
    if (!Number.isFinite(authTime) || now / 1000 - authTime > 300 || authTime > now / 1000 + 60) {
      throw new HttpsError("unauthenticated", "Confirme sua identidade novamente antes de excluir a conta.",
          {reason: "RECENT_AUTH_REQUIRED"});
    }
    // Existing index; a full, paginated preflight follows after the write lock.
    const active = await tx.get(db.collection("orders").where("customerUid", "==", uid)
        .where("status", "in", ["Novo", "Aguardando pagamento", "Em Separação",
          "Aguardando Retirada", "Saiu para Entrega", "Revisão financeira", "Revisão de estoque"]).limit(1));
    if (!active.empty) throw pending();
    tx.set(ref, {status: "requested", schemaVersion: 1,
      requiresAppleRevocation: tokenHasApple(request.auth.token),
      requestId: data.requestId, requestedAt: FieldValue.serverTimestamp(),
      updatedAt: FieldValue.serverTimestamp()});
    return {status: "requested"};
  });
}

async function visitOrders(db, uid, visit) {
  let last;
  for (;;) {
    let query = db.collection("orders").where("customerUid", "==", uid).limit(pageSize);
    if (last) query = query.startAfter(last);
    const page = await query.get();
    for (const doc of page.docs) await visit(doc);
    if (page.size < pageSize) return;
    last = page.docs.at(-1);
  }
}

async function eraseQuery(db, collection, field, uid) {
  for (;;) {
    const page = await db.collection(collection).where(field, "==", uid).limit(pageSize).get();
    if (page.empty) return;
    const batch = db.batch();
    for (const doc of page.docs) batch.delete(doc.ref);
    await batch.commit();
  }
}

function personalFields() {
  return Object.fromEntries(["customerPhone", "customerEmail", "customerDocument", "customerCpf",
    "customerCPF", "address", "deliveryAddress", "deliveryLocation", "complement", "reference",
    "customerSocialName", "customerBirthDate", "customerPhotoUrl"]
      .map((key) => [key, FieldValue.delete()]));
}

async function redactOrder(db, uid, doc, requestedAt) {
  // Free text can contain any personal data. Erase closed conversations in full.
  // Do this before unlinking the order, so a retry still finds unfinished work.
  await db.recursiveDelete(db.collection("orderChats").doc(doc.id));
  const financialRef = db.collection("orderFinancials").doc(doc.id);
  const projectionRef = db.collection("courierDeliveries").doc(doc.id);
  const verifierRef = db.collection("deliveryPinVerifiers").doc(doc.id);
  await db.runTransaction(async (tx) => {
    const order = await tx.get(doc.ref);
    const financial = await tx.get(financialRef);
    const projection = await tx.get(projectionRef);
    if (!order.exists || order.data().customerUid !== uid) return;
    if (!closedOrder(order.data())) throw pending();
    const pseudonym = "deleted_" + createHash("sha256").update(uid).digest("hex");
    const patch = {...personalFields(), customerUid: pseudonym,
      customerName: "Cliente com conta excluída", personalDataRedactedAt: requestedAt};
    if (order.data().deliverySnapshot) patch["deliverySnapshot.destination"] = FieldValue.delete();
    tx.update(doc.ref, patch);
    // Monetary values, route distance/unit/version/band and stock are untouched.
    if (financial.exists && financial.data().deliverySnapshot) {
      tx.update(financialRef, {"deliverySnapshot.destination": FieldValue.delete()});
    }
    if (projection.exists) tx.delete(projectionRef);
    tx.delete(verifierRef);
  });
}

async function processClosure(db, auth, uid, services = {}) {
  const ref = db.collection("customerAccountClosures").doc(uid);
  const job = await ref.get();
  if (!job.exists || !["requested", "processing"].includes(job.data().status)) return;
  const courier = await db.collection("couriers").doc(uid).get();
  if (courier.exists) throw new Error("CUSTOMER_CLOSURE_COURIER_DENIED");
  let user;
  try {
    user = await auth.getUser(uid);
    if (user.customClaims?.roles?.length) throw new Error("CUSTOMER_CLOSURE_ROLE_DENIED");
  } catch (error) {
    if (error.code !== "auth/user-not-found") throw error;
  }
  try {
    await visitOrders(db, uid, (doc) => {
      if (!closedOrder(doc.data())) throw pending();
    });
  } catch (error) {
    if (error.details?.reason !== "ACTIVE_ORDER") throw error;
    await ref.update({status: "blocked", reason: "ACTIVE_ORDER", updatedAt: FieldValue.serverTimestamp()});
    return;
  }
  try {
    // Before processing/redaction/Auth deletion; Google-linked Apple also counts.
    await ensureAppleRevoked(db, uid, job.data(), user, services);
  } catch (error) {
    if (!/^APPLE_REVOCATION_/.test(error.details?.reason || "")) throw error;
    await db.runTransaction(async (tx) => {
      const current = await tx.get(ref);
      if (!sameClosureAttempt(job.data(), current.data()) ||
          !["requested", "processing"].includes(current.data()?.status)) return;
      tx.update(ref, {status: "blocked", reason: error.details.reason, updatedAt: FieldValue.serverTimestamp()});
    });
    return;
  }
  const execute = await db.runTransaction(async (tx) => {
    const current = await tx.get(ref);
    if (!sameClosureAttempt(job.data(), current.data()) ||
        !["requested", "processing"].includes(current.data()?.status)) return false;
    tx.update(ref, {status: "processing", updatedAt: FieldValue.serverTimestamp()});
    return true;
  });
  if (!execute) return;
  await visitOrders(db, uid, (doc) => redactOrder(db, uid, doc, job.data().requestedAt));
  for (const [collection, field] of [["deliveryQuotes", "uid"], ["deliveryPinAudit", "uid"],
    ["reviews", "customerUid"]]) await eraseQuery(db, collection, field, uid);
  for (const collection of ["customerProfiles", "customerWorkspaces", "customerDeliverySecrets",
    "customerConsentEvents", "customerOrderCancellations"]) {
    await db.recursiveDelete(db.collection(collection).doc(uid));
  }
  try {
    await auth.deleteUser(uid);
  } catch (error) {
    if (error.code !== "auth/user-not-found") throw error;
  }
  await db.runTransaction(async (tx) => {
    const current = await tx.get(ref);
    if (current.data()?.status === "completed") return;
    tx.update(ref, {status: "completed", completedAt: FieldValue.serverTimestamp(),
      updatedAt: FieldValue.serverTimestamp()});
  });
}

function createCustomerAccountFunctions(db) {
  return {
    chamaeSolicitarExclusaoConta: onCall(options, (request) => requestClosure(db, request)),
    chamaeProcessarExclusaoConta: onDocumentWritten({...options,
      document: "customerAccountClosures/{uid}", retry: true, timeoutSeconds: 540}, (event) => {
      if (event.data?.after.data()?.status !== "requested" ||
          event.data?.before.data()?.status === "requested") return;
      return processClosure(db, getAuth(), event.params.uid);
    }),
  };
}
module.exports = {requestClosure, processClosure, closedOrder, createCustomerAccountFunctions};
