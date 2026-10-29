const {randomUUID, createHash} = require("node:crypto");
const {onCall, HttpsError} = require("firebase-functions/v2/https");
const {onDocumentCreated} = require("firebase-functions/v2/firestore");
const {onSchedule} = require("firebase-functions/v2/scheduler");
const {Timestamp, FieldValue} = require("firebase-admin/firestore");
const {getAuth} = require("firebase-admin/auth");
const {getStorage} = require("firebase-admin/storage");
const {requireCourierIdentity} = require("./courier-authorization");

const COLLECTION = "courierAccountClosures";
const CONFIRMATION = "EXCLUIR MINHA CONTA";
const nowStamp = (now) => Timestamp.fromMillis(now);
function only(data, fields) {
  if (!data || typeof data !== "object" || Array.isArray(data) ||
      Object.keys(data).some((key) => !fields.includes(key))) {
    throw new HttpsError("invalid-argument", "Solicitação inválida.");
  }
  return data;
}
function unprivileged(claims = {}) {
  const roles = claims.roles || [];
  if (!Array.isArray(roles) || roles.some((role) => role !== "courier") ||
      claims.admin === true || claims.superadmin === true ||
      claims.role && claims.role !== "courier") {
    throw new HttpsError("permission-denied", "Use sua conta de motoboy.");
  }
}
function ownRequest(request, recent = false, now = Date.now()) {
  const uid = requireCourierIdentity(request);
  unprivileged(request.auth.token);
  if (recent) {
    const time = request.auth.token && request.auth.token.auth_time;
    if (!Number.isFinite(time) || now / 1000 - time > 300 || time > now / 1000 + 30) {
      throw new HttpsError("failed-precondition", "Confirme sua identidade para solicitar a exclusão.",
          {reason: "REAUTH_REQUIRED"});
    }
  }
  return uid;
}
function publicClosure(uid, job) {
  return {courierUid: uid, protocol: job.protocol, status: job.status,
    pendingEventIds: job.pendingEventIds || [],
    pendingEventCount: job.pendingEventManifest ? job.pendingEventManifest.count : (job.pendingEventIds || []).length,
    eventsReconciled: !!job.reconciliation || !(job.pendingEventManifest ?
      job.pendingEventManifest.count : (job.pendingEventIds || []).length),
    requestedAtMs: job.requestedAt.toMillis(), reviewDueAtMs: job.reviewDueAt.toMillis(),
    escalated: !!job.escalatedAt,
    supportRequired: ["awaiting_operation", "provider_review_required"].includes(job.status)};
}
function terminal(order) {
  return order.status === "Concluído" || order.status === "Cancelado";
}
async function activeOperation(db, tx, uid) {
  let cursor;
  for (;;) {
    let query = db.collection("orders").where("courierUid", "==", uid).orderBy("__name__").limit(100);
    if (cursor) query = query.startAfter(cursor);
    const orders = await tx.get(query);
    if (orders.empty) return false;
    if (orders.docs.some((doc) => !terminal(doc.data()))) return true;
    cursor = orders.docs[orders.docs.length - 1];
  }
}
async function requestCourierClosure(db, auth, request, now = Date.now()) {
  const uid = ownRequest(request, true, now);
  const data = only(request.data,
      ["expectedUid", "requestId", "confirmation", "pendingEventIds", "pendingEventManifest"]);
  if (data.expectedUid !== uid) throw new HttpsError("permission-denied", "Conta divergente.");
  if (data.confirmation !== CONFIRMATION || typeof data.requestId !== "string" ||
      !/^[A-Za-z0-9_-]{16,100}$/.test(data.requestId)) {
    throw new HttpsError("invalid-argument", "Confirme a solicitação de exclusão.");
  }
  const events = data.pendingEventIds || [];
  if (!Array.isArray(events) || events.length > 200 || events.some((id) =>
    typeof id !== "string" || !/^[A-Za-z0-9_-]{1,128}$/.test(id)) || new Set(events).size !== events.length) {
    throw new HttpsError("invalid-argument", "Fila pendente inválida. Preserve o aparelho e tente novamente.");
  }
  const eventDigest = createHash("sha256").update(JSON.stringify(events)).digest("hex");
  const manifest = data.pendingEventManifest || {count: events.length, digest: eventDigest};
  if (!manifest || typeof manifest !== "object" || Array.isArray(manifest) ||
      Object.keys(manifest).some((key) => !["count", "digest"].includes(key)) ||
      !Number.isSafeInteger(manifest.count) || manifest.count < events.length || manifest.count > 1000000 ||
      typeof manifest.digest !== "string" || !/^[a-f0-9]{64}$/.test(manifest.digest) ||
      manifest.count <= 200 && (manifest.count !== events.length || manifest.digest !== eventDigest) ||
      manifest.count > 200 && events.length !== 200) {
    throw new HttpsError("invalid-argument", "Manifesto da fila inválido.");
  }
  const known = await db.doc(`${COLLECTION}/${uid}`).get();
  if (known.exists) return publicClosure(uid, known.data());
  const user = await auth.getUser(uid);
  unprivileged(user.customClaims);
  if (user.disabled) throw new HttpsError("permission-denied", "Confirme sua identidade no suporte.");
  const ref = db.collection(COLLECTION).doc(uid);
  return db.runTransaction(async (tx) => {
    const previous = await tx.get(ref);
    const profile = await tx.get(db.doc(`couriers/${uid}`));
    if (!profile.exists || profile.data().role !== "courier") {
      throw new HttpsError("permission-denied", "Esta conta não possui cadastro de motoboy.");
    }
    if (previous.exists) return publicClosure(uid, previous.data());
    if (!["pendingApproval", "approved", "rejected", "suspended"].includes(profile.data().approvalStatus)) {
      throw new HttpsError("failed-precondition", "Cadastro requer revisão de identidade.");
    }
    const active = await activeOperation(db, tx, uid);
    const job = {schemaVersion: 1, protocol: randomUUID(), requestId: data.requestId,
      status: active || manifest.count ? "awaiting_operation" : "requested",
      pendingEventIds: events, pendingEventManifest: manifest,
      requestedAt: nowStamp(now), reviewDueAt: nowStamp(now + 24 * 60 * 60 * 1000),
      retentionPolicy: "courier-closure-v1", updatedAt: nowStamp(now)};
    tx.create(ref, job);
    // This field is shared with all authorization/assignment checks and SDK rules.
    // The assignment transaction reads the same profile, preventing a new binding race.
    tx.update(profile.ref, {accountClosureStatus: job.status, online: false, updatedAt: nowStamp(now)});
    return publicClosure(uid, job);
  });
}
async function getCourierClosure(db, request) {
  const uid = ownRequest(request);
  only(request.data || {}, []);
  const snapshot = await db.doc(`${COLLECTION}/${uid}`).get();
  return snapshot.exists ? publicClosure(uid, snapshot.data()) : {courierUid: uid, status: "none"};
}
// Human operational resolution records an attestation, NOT a delivery/payment ACK.
async function resolveCourierClosure(db, request, now = Date.now()) {
  const actor = requireCourierIdentity(request);
  const roles = request.auth.token && request.auth.token.roles;
  if (!Array.isArray(roles) || !roles.some((r) => ["operations_admin", "superadmin"].includes(r))) {
    throw new HttpsError("permission-denied", "Ação administrativa não autorizada.");
  }
  const data = only(request.data, ["courierUid", "protocol", "resolutionReference", "eventIdsDigest"]);
  const uid = data.courierUid;
  if (typeof uid !== "string" || !uid || uid.includes("/") || [".", "..", actor].includes(uid) ||
      typeof data.resolutionReference !== "string" || !/^[A-Za-z0-9_-]{8,128}$/.test(data.resolutionReference)) {
    throw new HttpsError("invalid-argument", "Informe uma referência de reconciliação operacional.");
  }
  return db.runTransaction(async (tx) => {
    const operator = await tx.get(db.doc(`couriers/${actor}`));
    const jobRef = db.doc(`${COLLECTION}/${uid}`);
    const snapshot = await tx.get(jobRef);
    if (operator.exists || !snapshot.exists) throw new HttpsError("permission-denied", "Ação não autorizada.");
    const job = snapshot.data();
    const digest = job.pendingEventManifest ? job.pendingEventManifest.digest :
      createHash("sha256").update(JSON.stringify(job.pendingEventIds || [])).digest("hex");
    if (job.protocol !== data.protocol || data.eventIdsDigest !== digest) {
      throw new HttpsError("failed-precondition", "A solicitação mudou. Atualize a reconciliação.");
    }
    if (job.reconciliation) return publicClosure(uid, job);
    if (job.status !== "awaiting_operation" || await activeOperation(db, tx, uid)) {
      throw new HttpsError("failed-precondition", "Conclua ou reatribua a entrega pelo fluxo operacional existente.");
    }
    tx.update(jobRef, {status: "requested",
      reconciliation: {actorUid: actor,
        reference: data.resolutionReference, eventIdsDigest: digest, recordedAt: nowStamp(now)},
      updatedAt: nowStamp(now)});
    tx.update(db.doc(`couriers/${uid}`), {accountClosureStatus: "requested"});
    return publicClosure(uid, {...job, status: "requested", reconciliation: true});
  });
}
async function listCourierClosures(db, request) {
  const actor = requireCourierIdentity(request);
  const roles = request.auth.token && request.auth.token.roles;
  if (!Array.isArray(roles) || !roles.some((role) => ["operations_admin", "superadmin"].includes(role)) ||
      (await db.doc(`couriers/${actor}`).get()).exists) {
    throw new HttpsError("permission-denied", "Ação administrativa não autorizada.");
  }
  const data = only(request.data || {}, ["cursor"]);
  if (data.cursor !== undefined && (typeof data.cursor !== "string" || !data.cursor ||
      data.cursor.includes("/") || [".", ".."].includes(data.cursor) || data.cursor.length > 128)) {
    throw new HttpsError("invalid-argument", "Cursor inválido.");
  }
  let query = db.collection(COLLECTION).where("status", "in",
      ["requested", "processing", "awaiting_operation", "provider_review_required"]).orderBy("__name__").limit(100);
  if (data.cursor) query = query.startAfter(data.cursor);
  const page = await query.get();
  return {requests: page.docs.map((doc) => publicClosure(doc.id, doc.data())),
    cursor: page.size === 100 ? page.docs[page.size - 1].id : null};
}
async function purgeWhere(db, collection, uid) {
  for (;;) {
    const page = await db.collection(collection).where("courierUid", "==", uid).limit(100).get();
    if (page.empty) return;
    for (const doc of page.docs) await db.recursiveDelete(doc.ref);
  }
}
async function processCourierClosure(db, auth, storage, uid, options = {}) {
  if (!uid || uid.includes("/") || [".", ".."].includes(uid)) throw new Error("INVALID_COURIER_UID");
  const now = options.now ? options.now() : Date.now();
  const owner = randomUUID();
  const ref = db.doc(`${COLLECTION}/${uid}`);
  const job = await db.runTransaction(async (tx) => {
    const snapshot = await tx.get(ref);
    if (!snapshot.exists) return null;
    const current = snapshot.data();
    if (current.status === "provider_review_required") {
      if (now >= current.reviewDueAt.toMillis()) tx.update(ref, {escalatedAt: nowStamp(now)});
      return null;
    }
    if (current.status === "completed" ||
        current.leaseUntil && current.leaseUntil.toMillis() > now) return null;
    const profile = await tx.get(db.doc(`couriers/${uid}`));
    if (!profile.exists || profile.data().role !== "courier" || !profile.data().accountClosureStatus) {
      throw new Error("COURIER_CLOSURE_IDENTITY_REVIEW");
    }
    const active = await activeOperation(db, tx, uid);
    const pendingCount = current.pendingEventManifest ?
      current.pendingEventManifest.count : current.pendingEventIds.length;
    const unreconciled = pendingCount && !current.reconciliation;
    if (active || unreconciled) {
      tx.update(ref, {status: "awaiting_operation", updatedAt: nowStamp(now),
        ...(now >= current.reviewDueAt.toMillis() ? {escalatedAt: nowStamp(now)} : {})});
      return null;
    }
    tx.update(ref, {status: "processing", leaseOwner: owner,
      leaseUntil: nowStamp(now + 120000), updatedAt: nowStamp(now)});
    return current;
  });
  if (!job) return;
  const finish = async (patch) => db.runTransaction(async (tx) => {
    const current = await tx.get(ref);
    if (current.data().leaseOwner !== owner) throw new Error("COURIER_CLOSURE_LEASE_LOST");
    tx.update(ref, {...patch, leaseOwner: FieldValue.delete(), leaseUntil: FieldValue.delete(),
      updatedAt: nowStamp(options.now ? options.now() : Date.now())});
  });
  try {
    let user;
    try {
      user = await auth.getUser(uid);
    } catch (error) {
      if (error.code !== "auth/user-not-found") throw error;
    }
    if (user) {
      unprivileged(user.customClaims);
      if ((user.providerData || []).some((p) => p.providerId === "apple.com")) {
        // Client F01 vault is deliberately not reused across account types.
        await finish({status: "provider_review_required", reason: "COURIER_APPLE_ADAPTER_REQUIRED"});
        return;
      }
      await auth.revokeRefreshTokens(uid);
    }
    // No token/PII/error bodies in audit logs. No financial writes in this worker.
    await storage.deleteFiles({prefix: `courier-photos/${uid}/`});
    for (const collection of ["courierProfilePhotos", "courierDevices",
      "courierPushTokens", "courierOfflinePackages"]) {
      await db.recursiveDelete(db.doc(`${collection}/${uid}`));
    }
    for (const collection of ["courierDeliveries", "courierPickupGrants", "courierPickupSessions",
      "courierNotificationOutbox", "courierDeviceTokens"]) await purgeWhere(db, collection, uid);
    // Keep a minimal tombstone: old tokens/UIDs must not become customer accounts.
    await db.doc(`couriers/${uid}`).set({role: "courier", name: "Motoboy removido",
      enabled: false, online: false,
      approvalStatus: "suspended", administrativeState: "closed", accountClosureStatus: "completed",
      closureProtocol: job.protocol, closedAt: FieldValue.serverTimestamp()});
    if (user) await auth.updateUser(uid, {disabled: true});
    if (options.beforeAuthDelete) await options.beforeAuthDelete();
    try {
      await auth.deleteUser(uid);
    } catch (error) {
      if (error.code !== "auth/user-not-found") throw error;
    }
    await finish({status: "completed", completedAt: FieldValue.serverTimestamp(),
      lastFailureCode: FieldValue.delete()});
  } catch (_) {
    await finish({status: "processing", lastFailureCode: "RETRY_REQUIRED"});
    throw new Error("COURIER_CLOSURE_RETRY_REQUIRED");
  }
}
async function resumeCourierClosures(db, auth, storage, options = {}) {
  // Bounded pages with a cursor, not an arbitrary cap that can starve old requests.
  let cursor;
  for (;;) {
    let query = db.collection(COLLECTION).where("status", "in",
        ["requested", "processing", "awaiting_operation", "provider_review_required"])
        .orderBy("__name__").limit(100);
    if (cursor) query = query.startAfter(cursor);
    const page = await query.get();
    if (page.empty) return;
    for (const doc of page.docs) {
      try {
        await processCourierClosure(db, auth, storage, doc.id, options);
      } catch (_) {/* durable retry state */}
    }
    cursor = page.docs[page.docs.length - 1];
  }
}
function createCourierAccountFunctions(db) {
  const options = {region: "southamerica-east1", maxInstances: 10};
  const run = (uid) => processCourierClosure(db, getAuth(), getStorage().bucket(), uid);
  return {
    chamaeSolicitarExclusaoMotoboy: onCall(options, (r) => requestCourierClosure(db, getAuth(), r)),
    chamaeStatusExclusaoMotoboy: onCall(options, (r) => getCourierClosure(db, r)),
    chamaeResolverExclusaoMotoboy: onCall(options, (r) => resolveCourierClosure(db, r)),
    chamaeListarExclusoesMotoboy: onCall(options, (r) => listCourierClosures(db, r)),
    chamaeProcessarExclusaoMotoboy: onDocumentCreated({...options,
      document: `${COLLECTION}/{uid}`, retry: true}, (event) => run(event.params.uid)),
    chamaeRetomarExclusoesMotoboy: onSchedule({...options, schedule: "every 5 minutes"},
        () => resumeCourierClosures(db, getAuth(), getStorage().bucket())),
  };
}
module.exports = {CONFIRMATION, terminal, ownRequest, publicClosure, activeOperation, requestCourierClosure,
  getCourierClosure, resolveCourierClosure, listCourierClosures, processCourierClosure,
  resumeCourierClosures, createCourierAccountFunctions};
