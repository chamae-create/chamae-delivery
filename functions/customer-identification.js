"use strict";
const {onCall, HttpsError} = require("firebase-functions/v2/https");
const {FieldValue} = require("firebase-admin/firestore");
const {verifiedCustomerToken} = require("./customer-identity");
const {assertCustomerAccountActive} = require("./customer-account-state");
function sanitizeIdentification(data) {
  const allowed = ["fullName", "documentType", "documentIssuer", "preferredLanguage", "phone"];
  if (!data || typeof data !== "object" || Array.isArray(data) ||
      Object.keys(data).some(k => !allowed.includes(k)) ||
      typeof data.fullName !== "string" || data.fullName.trim().length < 3 || data.fullName.trim().length > 120 ||
      /[\u0000-\u001f]/.test(data.fullName) ||
      !["pt-BR", "es-PY"].includes(data.preferredLanguage) ||
      typeof data.phone !== "string" || !/^\+[1-9][0-9]{7,14}$/.test(data.phone) ||
      !((data.documentType === "cpf" && data.documentIssuer === "BR") ||
        (data.documentType === "cedula" && data.documentIssuer === "PY") ||
        (data.documentType === "other" && /^[A-Z]{2}$/.test(data.documentIssuer)))) {
    throw new HttpsError("invalid-argument", "IDENTIFICATION_INVALID", {reason: "IDENTIFICATION_INVALID"});
  }
  // Raw number, date of birth, nationality and verification flags are never accepted.
  return {fullName: data.fullName.trim(), documentType: data.documentType,
    documentIssuer: data.documentIssuer, preferredLanguage: data.preferredLanguage, phone: data.phone,
    identificationSchemaVersion: 1, documentStatus: "not_verified"};
}
async function saveIdentification(db, request) {
  if (!request.auth || !verifiedCustomerToken(request.auth.token) || (!Array.isArray(request.auth.token.roles || []) || (request.auth.token.roles || []).length || request.auth.token.superadmin === true)) {
    throw new HttpsError("permission-denied", "CUSTOMER_REQUIRED");
  }
  const uid = request.auth.uid, fields = sanitizeIdentification(request.data);
  return db.runTransaction(async tx => {
    await assertCustomerAccountActive(db, uid, tx);
    if ((await tx.get(db.doc("couriers/" + uid))).exists) throw new HttpsError("permission-denied", "CUSTOMER_REQUIRED");
    const previous=(await tx.get(db.doc("customerProfiles/"+uid))).data() || {};
    // UI gating is insufficient: verify the current official policy in this transaction.
    const {validPolicy, profileCurrent} = require("./customer-policy-contract");
    const policy = validPolicy((await tx.get(db.doc("customerPolicies/current"))).data());
    if (!profileCurrent(previous, policy)) {
      throw new HttpsError("failed-precondition", "CUSTOMER_POLICY_ACCEPTANCE_REQUIRED",
        {reason: "CUSTOMER_POLICY_ACCEPTANCE_REQUIRED"});
    }
    // The installed IPA has no requestId. A transactionally identical retry
    // must preserve the original revision and timestamp rather than re-write.
    if (Number.isSafeInteger(previous.identityRevision) && previous.identityRevision >= 1 &&
        Object.entries(fields).every(([key, value]) => previous[key] === value)) {
      return {saved: true, documentStatus: "not_verified"};
    }
    const changed=["fullName","documentType","documentIssuer"].some(k=>previous[k]!==fields[k]);
    fields.identityRevision=(Number.isSafeInteger(previous.identityRevision)?previous.identityRevision:0)+(changed?1:0);
    // Merge: existing PIN, birthday, policy versions and addresses remain untouched.
    tx.set(db.doc("customerProfiles/" + uid), {...fields, updatedAt: FieldValue.serverTimestamp()}, {merge: true});
    return {saved: true, documentStatus: "not_verified"};
  });
}
function createCustomerIdentification(db) {
  return {chamaeAtualizarIdentificacaoCliente: onCall({region: "southamerica-east1", maxInstances: 2},
    request => saveIdentification(db, request))};
}
module.exports = {sanitizeIdentification, saveIdentification, createCustomerIdentification};
