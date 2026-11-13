const {onCall, HttpsError} = require("firebase-functions/v2/https");
const {FieldValue} = require("firebase-admin/firestore");
const {assertCustomerAccountActive} = require("./customer-account-state");
const {requireCourierIdentity, requireApprovedCourier,
  requireCourierAdministrator} = require("./courier-authorization");

const {assertCurrentCourierAcceptance, currentCourierAcceptance} = require("./courier-policy");

const profileFields = ["name", "phone", "profilePhoto", "city", "vehicleType",
  "vehicleDescription", "vehiclePlate", "vehicleCountry", "driverLicense"];
const statuses = ["pendingApproval", "approved", "rejected", "suspended"];
function dataOnly(data, fields) {
  if (!data || typeof data !== "object" || Array.isArray(data) ||
      Object.keys(data).some((key) => !fields.includes(key))) {
    throw new HttpsError("invalid-argument", "Solicitação inválida.");
  }
  return data;
}
function text(value, maximum, minimum = 1) {
  if (typeof value !== "string" || value.trim().length < minimum ||
      value.trim().length > maximum || Array.from(value).some((character) =>
    character.codePointAt(0) < 32 || character.codePointAt(0) === 127)) {
    throw new HttpsError("invalid-argument", "Confira os dados informados.");
  }
  return value.trim();
}
function profileInput(data, partial = false) {
  dataOnly(data, profileFields);
  const result = {};
  for (const field of profileFields) {
    if (partial && !Object.hasOwn(data, field)) continue;
    const limits = {name: 120, phone: 32, profilePhoto: 240, city: 120, vehicleType: 30,
      vehicleDescription: 160, vehiclePlate: 20, vehicleCountry: 10, driverLicense: 80};
    const required = ["name", "phone", "profilePhoto"].includes(field);
    result[field] = text(data[field] == null ? "" : data[field], limits[field], required ? 1 : 0);
  }
  if (result.phone !== undefined &&
      !/^[+() .\d-]{7,32}$/.test(result.phone)) {
    throw new HttpsError("invalid-argument", "Confira o telefone.");
  }
  if (result.vehicleType !== undefined &&
      !["", "motorcycle", "bicycle", "car"].includes(result.vehicleType)) {
    throw new HttpsError("invalid-argument", "Confira o veículo.");
  }
  if (result.vehicleCountry && !["BR", "PY", "OTHER"].includes(result.vehicleCountry)) {
    throw new HttpsError("invalid-argument", "Confira o país da placa.");
  }
  if (!Object.keys(result).length) {
    throw new HttpsError("invalid-argument", "Informe os dados do perfil.");
  }
  return result;
}
function publicProfile(uid, data) {
  const result = {courierUid: uid,
    approvalStatus: statuses.includes(data.approvalStatus) ? data.approvalStatus : "pendingApproval",
    administrativeState: data.administrativeState || "pendingApproval",
    enabled: data.enabled === true,
    ...(data.accountClosureStatus ? {accountClosureStatus: data.accountClosureStatus} : {})};
  for (const field of profileFields) result[field] = data[field] || "";
  for (const field of ["createdAt", "updatedAt"]) {
    result[`${field}Ms`] = data[field] && typeof data[field].toMillis === "function" ?
      data[field].toMillis() : null;
  }
  return result;
}
async function ownProfile(db, request, operation = "get") {
  const uid = requireCourierIdentity(request);
  const roles = request.auth.token && request.auth.token.roles;
  if (operation === "register" && Array.isArray(roles) && roles.length) {
    throw new HttpsError("permission-denied", "Use uma conta de motoboy.");
  }
  const patch = operation === "get" ?
    dataOnly(request.data || {}, []) && null : profileInput(request.data, operation === "update");
  const ref = db.collection("couriers").doc(uid);
  await db.runTransaction(async (tx) => {
    await assertCustomerAccountActive(db, uid, tx);
    const snapshot = await tx.get(ref);
    if (snapshot.exists && snapshot.data().accountClosureStatus && operation !== "get") {
      throw new HttpsError("failed-precondition", "A exclusão desta conta está em andamento.");
    }
    if (patch && patch.profilePhoto) {
      const photo = await tx.get(db.doc(`courierProfilePhotos/${uid}`));
      if (!photo.exists || photo.data().verified !== true || photo.data().reference !== patch.profilePhoto) {
        throw new HttpsError("failed-precondition", "Envie sua foto de perfil antes de continuar.");
      }
    }
    if (operation === "register") {
      await assertCurrentCourierAcceptance(db, uid, tx);
      // Retrying registration never resets a rejection or suspension.
      if (!snapshot.exists) {
        tx.create(ref, {...patch, role: "courier",
          approvalStatus: "pendingApproval", administrativeState: "pendingApproval",
          enabled: false, online: false,
          createdAt: FieldValue.serverTimestamp(), updatedAt: FieldValue.serverTimestamp()});
      }
    } else {
      if (!snapshot.exists) throw new HttpsError("not-found", "Cadastro não encontrado.");
      if (operation === "update") tx.update(ref, {...patch, updatedAt: FieldValue.serverTimestamp()});
    }
  });
  return {...publicProfile(uid, (await ref.get()).data()),
    policyAcceptanceCurrent: await currentCourierAcceptance(db, uid)};
}
async function reviewCourier(db, request) {
  const actorUid = requireCourierAdministrator(request);
  const data = dataOnly(request.data, ["courierUid", "action", "expectedStatus", "reason"]);
  const uid = text(data.courierUid, 128);
  if (uid.includes("/") || [".", "..", actorUid].includes(uid)) {
    throw new HttpsError("invalid-argument", "Cadastro inválido.");
  }
  const transitions = {approve: ["pendingApproval", "suspended"],
    reject: ["pendingApproval"], suspend: ["approved"]};
  if (!Object.hasOwn(transitions, data.action) || !statuses.includes(data.expectedStatus)) {
    throw new HttpsError("invalid-argument", "Ação inválida.");
  }
  const reason = data.action === "approve" ? "" : text(data.reason, 500, 3);
  const ref = db.collection("couriers").doc(uid);
  const auditRef = db.collection("courierApprovalAudit").doc();
  return db.runTransaction(async (tx) => {
    await assertCustomerAccountActive(db, actorUid, tx);
    await assertCustomerAccountActive(db, uid, tx);
    const actor = await tx.get(db.collection("couriers").doc(actorUid));
    if (actor.exists) throw new HttpsError("permission-denied", "Use uma conta administrativa.");
    const snapshot = await tx.get(ref);
    if (!snapshot.exists) throw new HttpsError("not-found", "Cadastro não encontrado.");
    if (snapshot.data().accountClosureStatus) {
      throw new HttpsError("failed-precondition", "A conta está em encerramento.");
    }
    const previous = snapshot.data().approvalStatus;
    if (previous !== data.expectedStatus || !transitions[data.action].includes(previous)) {
      throw new HttpsError("failed-precondition", "O cadastro mudou. Atualize a lista.");
    }
    if (data.action === "approve") {
      await assertCurrentCourierAcceptance(db, uid, tx);
      const profile = snapshot.data();
      profileInput(Object.fromEntries(profileFields.filter((key) =>
        Object.hasOwn(profile, key)).map((key) => [key, profile[key]])));
    }
    const status = {approve: "approved", reject: "rejected", suspend: "suspended"}[data.action];
    const prefix = {approve: "approved", reject: "rejected", suspend: "suspended"}[data.action];
    const now = FieldValue.serverTimestamp();
    const patch = {approvalStatus: status,
      administrativeState: status === "approved" ? "active" : status,
      enabled: status === "approved", online: false, updatedAt: now,
      [`${prefix}At`]: now, [`${prefix}By`]: actorUid};
    if (data.action !== "approve") patch[data.action === "reject" ? "rejectionReason" : "suspensionReason"] = reason;
    if (previous === "suspended" && status === "approved") {
      patch.reactivatedAt = now; patch.reactivatedBy = actorUid;
    }
    tx.update(ref, patch);
    tx.create(auditRef, {courierUid: uid, actorUid, action: data.action,
      previousStatus: previous, approvalStatus: status, reason, createdAt: now});
    // Active orders and their states are intentionally untouched.
    return {courierUid: uid, approvalStatus: status};
  });
}

// Structural gateway for the future v0.1 event/receipt integration. No fabricated
// delivery confirmation, settlement, PIN validation or financial acknowledgement.
async function courierOperation(db, request) {
  return db.runTransaction(async (tx) => {
    const courier = await requireApprovedCourier(db, request, tx);
    const data = dataOnly(request.data, ["operation", "on"]);
    if (data.operation === "availability") {
      if (typeof data.on !== "boolean") throw new HttpsError("invalid-argument", "Disponibilidade inválida.");
      if (data.on) await assertCurrentCourierAcceptance(db, courier.uid, tx);
      tx.update(courier.ref, {online: data.on, updatedAt: FieldValue.serverTimestamp()});
      return {online: data.on};
    }
    throw new HttpsError("failed-precondition",
        "Esta ação ainda não está habilitada na integração operacional.");
  });
}
function createCourierApprovalFunctions(db) {
  const options = {region: "southamerica-east1", maxInstances: 10};
  return {
    chamaeCadastrarMotoboy: onCall(options, (r) => ownProfile(db, r, "register")),
    chamaeMeuCadastroMotoboy: onCall(options, (r) => ownProfile(db, r)),
    chamaeAtualizarCadastroMotoboy: onCall(options, (r) => ownProfile(db, r, "update")),
    chamaeRevisarCadastroMotoboy: onCall(options, (r) => reviewCourier(db, r)),
    chamaeOperacaoMotoboy: onCall(options, (r) => courierOperation(db, r)),
  };
}
module.exports = {profileInput, publicProfile, ownProfile, reviewCourier,
  courierOperation, createCourierApprovalFunctions};
