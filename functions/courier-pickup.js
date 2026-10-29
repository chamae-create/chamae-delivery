const {createHash, verify, sign, randomUUID, randomBytes, timingSafeEqual} = require("node:crypto");
const {Timestamp, FieldValue} = require("firebase-admin/firestore");
const {HttpsError, onCall} = require("firebase-functions/v2/https");
const {validNavigation} = require("./courier-navigation-package");
const {requireApprovedCourier} = require("./courier-authorization");
const {authorize, readyForDispatch} = require("./courier-assignment");
const fields = ["version", "algorithm", "keyId", "orderId", "assignmentId", "courierUid",
  "packageVersion", "expiresAtMs", "nonce", "signature"];
function body(t) {
  return Buffer.from(JSON.stringify(fields.slice(0, -1).map((key) => t[key])));
}
function parseTicket(encoded) {
  let t;
  try {
    if (typeof encoded !== "string" || encoded.length > 4096) throw Error(); t = JSON.parse(encoded);
  } catch (_) {
    throw new HttpsError("invalid-argument", "Ticket inválido.");
  }
  if (!t || typeof t !== "object" || Array.isArray(t) ||
      Object.keys(t).length !== fields.length || Object.keys(t).some((k) => !fields.includes(k)) ||
      t.version !== 2 || t.algorithm !== "Ed25519" || t.packageVersion !== 1 ||
      !Number.isSafeInteger(t.expiresAtMs) ||
      ["keyId", "orderId", "assignmentId", "courierUid", "nonce"].some((k) =>
        typeof t[k] !== "string" || !/^[A-Za-z0-9_:-]{1,128}$/.test(t[k])) ||
      typeof t.signature !== "string" || !/^[A-Za-z0-9+/]{86}==$/.test(t.signature)) {
    throw new HttpsError("invalid-argument", "Ticket inválido.");
  }
  return t;
}
function verifyTicket(encoded, publicKey, now = Date.now()) {
  const ticket = parseTicket(encoded);
  if (ticket.expiresAtMs <= now || !publicKey || publicKey.asymmetricKeyType !== "ed25519" ||
      !verify(null, body(ticket), publicKey, Buffer.from(ticket.signature, "base64"))) {
    throw new HttpsError("permission-denied", "Ticket inválido ou expirado.");
  }
  return ticket;
}
function signTicket(data, privateKey) {
  if (!privateKey || privateKey.asymmetricKeyType !== "ed25519") throw new Error("SIGNER_NOT_CONFIGURED");
  const ticket = {...data, version: 2, algorithm: "Ed25519"};
  ticket.signature = sign(null, body(ticket), privateKey).toString("base64");
  return JSON.stringify(parseTicket(JSON.stringify(ticket)));
}
// Inspect field names only; never log package values or key/PIN material.
function hasForbiddenPackageData(value) {
  const forbidden = new Set(["pin", "plainpin", "plaintextpin", "privatekey",
    "private_key", "secretkey", "signingkey", "serviceaccount"]);
  const pending = [value]; let visited = 0;
  while (pending.length) {
    if (++visited > 100000) return true;
    const next = pending.pop();
    if (Array.isArray(next)) {
      for (const item of next) pending.push(item);
    } else if (next && typeof next === "object") {
      if (Object.keys(next).some((key) => forbidden.has(key.toLowerCase()))) return true;
      for (const item of Object.values(next)) pending.push(item);
    }
  }
  return false;
}
function validatePackage(bytes, ticket) {
  let data;
  try {
    data = JSON.parse(bytes.toString("utf8"));
  } catch (_) {
    throw new HttpsError("failed-precondition", "Pacote offline inválido.");
  }
  const a = data.assignment || {}; const d = data.delivery || {}; const m = data.map || {};
  const pin = d.pinVerifier || {};
  if (hasForbiddenPackageData(data) || data.schemaVersion !== 2 || Object.keys(data).some((k) =>
    !["schemaVersion", "assignment", "delivery", "map", "contingency"].includes(k)) ||
    a.assignmentId !== ticket.assignmentId || a.orderId !== ticket.orderId ||
    a.courierUid !== ticket.courierUid || a.packageVersion !== ticket.packageVersion ||
    !Number.isSafeInteger(a.expiresAtMs) || a.expiresAtMs > ticket.expiresAtMs || a.expiresAtMs <= Date.now() ||
    d.orderId !== ticket.orderId || d.courierUid !== ticket.courierUid ||
    typeof d.address !== "string" || !d.address || !d.coordinates || !d.payment ||
    typeof d.coordinates.latitude !== "number" || !Number.isFinite(d.coordinates.latitude) ||
    typeof d.coordinates.longitude !== "number" || !Number.isFinite(d.coordinates.longitude) ||
    Math.abs(d.coordinates.latitude) > 90 || Math.abs(d.coordinates.longitude) > 180 ||
    !["paid", "collect"].includes(d.payment.state) || !Number.isSafeInteger(d.payment.amountMinor) ||
    d.payment.amountMinor < 0 || d.payment.state === "paid" && d.payment.amountMinor !== 0 ||
    !["BRL", "PYG", "USD"].includes(d.payment.currency) ||
    pin.orderId !== ticket.orderId ||
    !pin.verificationMaterial || pin.verificationVersion !== 1 ||
    !Number.isSafeInteger(pin.expiresAtMs) || pin.expiresAtMs <= Date.now() ||
    !Number.isInteger(pin.maxAttempts) || pin.maxAttempts < 1 || pin.maxAttempts > 5 ||
    ["pin", "plainPin", "customerPhone", "merchantNet", "orderFinancials"].some((k) => Object.hasOwn(d, k)) ||
    !Array.isArray(m.geometry) || m.geometry.length < 2 || typeof m.asset !== "string" || !m.asset ||
    !validNavigation(m.navigation, d.coordinates, m.geometry)) {
    throw new HttpsError("failed-precondition", "Pacote offline incompleto.");
  }
  return data;
}
const unconfigured = {
  async publicKey() {
    throw new HttpsError("failed-precondition", "Verificação de ticket ainda não configurada.");
  },
  async sign() {
    throw new HttpsError("failed-precondition", "Assinatura de ticket ainda não configurada.");
  },
  async package() {
    throw new HttpsError("failed-precondition", "Pacote offline ainda não configurado.");
  },
};
function matchAssignment(order, uid, assignmentId, now) {
  return order && typeof assignmentId === "string" && assignmentId.length > 0 && order.courierUid === uid &&
      order.courierAssignmentId === assignmentId &&
    order.courierAssignmentExpiresAt instanceof Timestamp && order.courierAssignmentExpiresAt.toMillis() > now &&
    !["Concluído", "Cancelado"].includes(order.status);
}
async function issueTicket(db, request, ports = unconfigured) {
  authorize(request);
  const id = request.data && request.data.orderId;
  if (typeof id !== "string" || !/^[A-Za-z0-9_-]{1,128}$/.test(id)) {
    throw new HttpsError("invalid-argument",
        "Pedido inválido.");
  }
  return db.runTransaction(async (tx) => {
    const actor = await tx.get(db.doc(`couriers/${request.auth.uid}`));
    if (actor.exists) throw new HttpsError("permission-denied", "Use uma conta administrativa.");
    const snapshot = await tx.get(db.doc(`orders/${id}`));
    const order = snapshot.data();
    if (!snapshot.exists || !matchAssignment(order, order.courierUid, order.courierAssignmentId, Date.now())) {
      throw new HttpsError("failed-precondition", "Atribua um motoboy antes de emitir o ticket.");
    }
    const profile = await tx.get(db.doc(`couriers/${order.courierUid}`));
    const {isApprovedCourierProfile} = require("./courier-authorization");
    if (!profile.exists || !isApprovedCourierProfile(profile.data())) {
      throw new HttpsError("permission-denied",
          "Motoboy não liberado.");
    }
    return {ticket: await ports.sign({version: 2, algorithm: "Ed25519", keyId: "pickup-v2",
      orderId: id, assignmentId: order.courierAssignmentId, courierUid: order.courierUid,
      packageVersion: 1, expiresAtMs: order.courierAssignmentExpiresAt.toMillis(), nonce: randomUUID()})};
  });
}
async function beginPickup(db, request, ports = unconfigured) {
  return db.runTransaction(async (tx) => {
    const courier = await requireApprovedCourier(db, request, tx);
    const parsed = parseTicket(request.data && request.data.ticket);
    const ticket = verifyTicket(request.data.ticket, await ports.publicKey(parsed.keyId));
    if (ticket.courierUid !== courier.uid) {
      throw new HttpsError("permission-denied",
          "Esta entrega não está atribuída a você.");
    }
    const order = (await tx.get(db.doc(`orders/${ticket.orderId}`))).data();
    if (!matchAssignment(order, courier.uid, ticket.assignmentId, Date.now()) || courier.profile.online !== true) {
      throw new HttpsError("permission-denied", "Esta entrega não está mais atribuída a você.");
    }
    if (request.data.expectedOrderId && request.data.expectedOrderId !== ticket.orderId) {
      throw new HttpsError("failed-precondition", "Pedido incorreto.");
    }
    const binding = await tx.get(db.doc(`courierPickupAssignments/${ticket.assignmentId}`));
    if (! (order.acceptedAt instanceof Timestamp) || binding.exists && binding.data().status !== "active") {
      throw new HttpsError("failed-precondition", "Aceite a entrega antes de retirar.");
    }
    let bytes = await ports.package(ticket, order);
    if (!Buffer.isBuffer(bytes) || !bytes.length || bytes.length > 2 * 1024 * 1024) {
      throw new HttpsError("failed-precondition", "Pacote offline incompleto.");
    }
    validatePackage(bytes, ticket);
    if (order.displayOrderId && JSON.parse(bytes.toString("utf8")).delivery.number !== order.displayOrderId) {
      throw new HttpsError("failed-precondition", "Identificador operacional divergente no pacote.");
    }
    const sessionId = createHash("sha256").update(`${courier.uid}:${ticket.nonce}`).digest("hex");
    const ref = db.doc(`courierPickupSessions/${sessionId}`);
    const previous = await tx.get(ref);
    const activationProof = previous.exists ? previous.data().activationProof : randomBytes(32).toString("base64url");
    const complete = JSON.parse(bytes.toString("utf8"));
    complete.activationProof = activationProof;
    bytes = Buffer.from(JSON.stringify(complete));
    if (bytes.length > 2 * 1024 * 1024) throw new HttpsError("failed-precondition", "Pacote excede o limite.");
    const digest = createHash("sha256").update(bytes).digest("hex");
    if (previous.exists && previous.data().digest !== digest) {
      throw new HttpsError("aborted",
          "O pacote mudou. Leia um novo ticket.");
    }
    if (!previous.exists) {
      tx.create(ref, {courierUid: courier.uid, orderId: ticket.orderId,
        assignmentId: ticket.assignmentId, packageVersion: ticket.packageVersion,
        expiresAt: Timestamp.fromMillis(Math.min(ticket.expiresAtMs, order.courierAssignmentExpiresAt.toMillis())),
        digest, activationProof, createdAt: FieldValue.serverTimestamp()});
    }
    return {sessionId, digest, length: bytes.length, package: bytes.toString("base64")};
  }).catch(async (error) => {
    if (request.auth && error.code === "permission-denied") {
      try {
        await db.collection("courierPickupAudit").add({actorUid: request.auth.uid,
          code: "pickup_denied",
          at: FieldValue.serverTimestamp()});
      } catch (_) {/* Never turn an audit failure into permission. */}
    }
    throw error;
  });
}
async function confirmPickup(db, request) {
  const data = request.data || {};
  if (!/^[a-f0-9]{64}$/.test(data.sessionId || "") || !/^[a-f0-9]{64}$/.test(data.digest || "") ||
      Object.keys(data).some((k) => !["sessionId", "digest", "activationProof"].includes(k))) {
    throw new HttpsError("invalid-argument",
        "Preparação inválida.");
  }
  return db.runTransaction(async (tx) => {
    const courier = await requireApprovedCourier(db, request, tx);
    const sessionRef = db.doc(`courierPickupSessions/${data.sessionId}`);
    const session = await tx.get(sessionRef);
    if (!session.exists || session.data().courierUid !== courier.uid || session.data().digest !== data.digest ||
        session.data().expiresAt.toMillis() <= Date.now()) {
      throw new HttpsError("permission-denied",
          "Preparação inválida.");
    }
    const prepared = session.data();
    if (typeof data.activationProof !== "string" || data.activationProof.length > 128 ||
        !timingSafeEqual(createHash("sha256").update(data.activationProof).digest(),
            createHash("sha256").update(prepared.activationProof).digest())) {
      throw new HttpsError("permission-denied", "Recebimento do pacote não confirmado.");
    }
    const orderRef = db.doc(`orders/${prepared.orderId}`);
    const order = (await tx.get(orderRef)).data();
    if (!matchAssignment(order, courier.uid, prepared.assignmentId, Date.now()) || courier.profile.online !== true ||
        !readyForDispatch(order)) throw new HttpsError("failed-precondition", "A entrega mudou. Atualize com a loja.");
    const grantRef = db.doc(`courierPickupGrants/${prepared.orderId}`);
    const previous = await tx.get(grantRef);
    if (previous.exists && previous.data().sessionId === data.sessionId) return {acknowledged: true, replayed: true};
    if (previous.exists && previous.data().assignmentId === prepared.assignmentId) {
      throw new HttpsError("already-exists", "Retirada já confirmada por outro ticket.");
    }
    const bindingRef = db.doc(`courierPickupAssignments/${prepared.assignmentId}`);
    const binding = await tx.get(bindingRef);
    if (! (order.acceptedAt instanceof Timestamp) || binding.exists && binding.data().status !== "active") {
      throw new HttpsError("failed-precondition", "Esta entrega não está mais atribuída a você.");
    }
    if (binding.exists) tx.update(bindingRef, {status: "pickedUp", pickedUpAt: FieldValue.serverTimestamp()});
    if (order.expectedPickupBy instanceof Timestamp && Date.now() <= order.expectedPickupBy.toMillis()) {
      tx.set(db.doc(`courierReliabilityEvents/${prepared.assignmentId}-ontime`), {type: "pickupOnTime",
        orderId: prepared.orderId, assignmentId: prepared.assignmentId, courierUid: courier.uid,
        at: FieldValue.serverTimestamp()});
    }
    tx.set(grantRef, {...prepared, sessionId: data.sessionId, confirmedAt: FieldValue.serverTimestamp()});
    tx.update(orderRef, {courierPickupState: "headingToCustomer", courierPickedUpAt: FieldValue.serverTimestamp()});
    return {acknowledged: true, replayed: false};
  });
}
async function listAssignments(db, request) {
  return db.runTransaction(async (tx) => {
    const courier = await requireApprovedCourier(db, request, tx);
    const snapshot = await tx.get(db.collection("orders").where("courierUid", "==", courier.uid).limit(50));
    const assignments = [];
    for (const doc of snapshot.docs) {
      const order = doc.data();
      if (!matchAssignment(order, courier.uid, order.courierAssignmentId, Date.now())) continue;
      const grant = await tx.get(db.doc(`courierPickupGrants/${doc.id}`));
      assignments.push({orderId: doc.id, assignmentId: order.courierAssignmentId,
        courierUid: courier.uid, expiresAtMs: order.courierAssignmentExpiresAt.toMillis(), packageVersion: 1,
        ...(order.displayOrderId ? {displayOrderId: order.displayOrderId} : {}),
        pickupState: order.courierPickupState || "assigned",
        acceptedAtMs: order.acceptedAt instanceof Timestamp ? order.acceptedAt.toMillis() : null,
        expectedPickupByMs: order.expectedPickupBy instanceof Timestamp ? order.expectedPickupBy.toMillis() : null,
        reminderAtMs: order.pickupReminderAt instanceof Timestamp ? order.pickupReminderAt.toMillis() : null,
        confirmationRequestedAtMs: order.pickupConfirmationRequestedAt instanceof Timestamp ?
    order.pickupConfirmationRequestedAt.toMillis() : null,
        extensionCount: order.pickupExtensionCount || 0,
        pickedUp: grant.exists && grant.data().courierUid === courier.uid &&
          grant.data().expiresAt instanceof Timestamp && grant.data().expiresAt.toMillis() > Date.now() &&
          grant.data().assignmentId === order.courierAssignmentId});
    }
    return {assignments};
  });
}
function createCourierPickupFunctions(db) {
  const options = {region: "southamerica-east1", maxInstances: 10};
  return {chamaeMinhasAtribuicoes: onCall(options, (r) => listAssignments(db, r)),
    chamaeEmitirTicketRetirada: onCall(options, (r) => issueTicket(db, r)),
    chamaePrepararRetirada: onCall(options, (r) => beginPickup(db, r)),
    chamaeConfirmarPacoteRetirada: onCall(options, (r) => confirmPickup(db, r))};
}
module.exports = {matchAssignment, validatePackage, listAssignments, parseTicket, verifyTicket, signTicket,
  issueTicket, beginPickup,
  confirmPickup,
  createCourierPickupFunctions};
