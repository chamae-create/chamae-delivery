const {createHash} = require("node:crypto");
const {FieldValue} = require("firebase-admin/firestore");
const {onCall, HttpsError} = require("firebase-functions/v2/https");
const {documentFingerprint, validPublishedPolicy} = require("./published-policy");
const {requireCourierIdentity} = require("./courier-authorization");
const {assertCustomerAccountActive} = require("./customer-account-state");
const fields = ["revision", "termsVersion", "privacyVersion", "termsText", "privacyText", "termsUrl", "privacyUrl"];
const policyFingerprint = (policy) => documentFingerprint(policy, fields);
function validPolicy(policy) {
  try {
    return validPublishedPolicy(policy, fields, fields.slice(0, 5), ["termsVersion", "privacyVersion"]);
  } catch (error) {
    if (error.code === "failed-precondition") {
      throw new HttpsError("failed-precondition", error.message, {reason: "COURIER_POLICY_UNAVAILABLE"});
    }
    throw error;
  }
}
function acceptanceCurrent(record, policy) {
  return !!record && !!record.acceptedAt && record.acceptTerms === true && record.acknowledgePrivacy === true &&
    record.policyRevision === policy.revision && record.policyHash === policy.contentHash &&
    record.termsVersion === policy.termsVersion && record.privacyVersion === policy.privacyVersion;
}
async function readPolicyState(db, uid, tx) {
  const read = (ref) => tx ? tx.get(ref) : ref.get();
  const policyDoc = await read(db.collection("courierPolicies").doc("current"));
  const acceptance = await read(db.collection("courierPolicyAcceptances").doc(uid));
  return {policy: policyDoc.data(), acceptance: acceptance.data()};
}
async function assertCurrentCourierAcceptance(db, uid, tx) {
  const state = await readPolicyState(db, uid, tx);
  const policy = validPolicy(state.policy);
  if (!acceptanceCurrent(state.acceptance, policy)) {
    throw new HttpsError("failed-precondition", "Confira e aceite os documentos atualizados.",
        {reason: "COURIER_POLICY_ACCEPTANCE_REQUIRED"});
  }
  return state;
}
async function currentCourierAcceptance(db, uid) {
  const state = await readPolicyState(db, uid);
  try {
    return acceptanceCurrent(state.acceptance, validPolicy(state.policy));
  } catch (_) {
    return false;
  }
}
async function acceptDocuments(db, request) {
  const uid = requireCourierIdentity(request);
  const provider = request.auth.token?.firebase?.sign_in_provider;
  if (!provider || provider === "anonymous") throw new HttpsError("unauthenticated", "Entre para continuar.");
  const roles = request.auth.token?.roles || [];
  if (!Array.isArray(roles) || roles.some((role) => role !== "courier")) {
    throw new HttpsError("permission-denied", "Use sua conta de motoboy.");
  }
  const data = request.data || {};
  if (Object.keys(data).some((key) => !["policyRevision", "policyHash", "termsVersion", "privacyVersion",
    "acceptTerms", "acknowledgePrivacy"].includes(key)) ||
      data.acceptTerms !== true || data.acknowledgePrivacy !== true) {
    throw new HttpsError("invalid-argument", "Confira os documentos antes de continuar.");
  }
  return db.runTransaction(async (tx) => {
    await assertCustomerAccountActive(db, uid, tx);
    const profile = await tx.get(db.collection("couriers").doc(uid));
    const closure = await tx.get(db.collection("courierAccountClosures").doc(uid));
    if (profile.data()?.accountClosureStatus || closure.exists && closure.data().status !== "blocked") {
      throw new HttpsError("failed-precondition", "A exclusão desta conta está em andamento.");
    }
    const state = await readPolicyState(db, uid, tx);
    const policy = validPolicy(state.policy);
    if (data.policyRevision !== policy.revision || data.policyHash !== policy.contentHash ||
        data.termsVersion !== policy.termsVersion || data.privacyVersion !== policy.privacyVersion) {
      throw new HttpsError("failed-precondition", "Os documentos foram atualizados. Confira a nova versão.",
          {reason: "COURIER_POLICY_CHANGED"});
    }
    if (acceptanceCurrent(state.acceptance, policy)) {
      return {accepted: true, policyRevision: policy.revision,
        policyHash: policy.contentHash};
    }
    const record = {policyRevision: policy.revision, policyHash: policy.contentHash,
      termsVersion: policy.termsVersion, privacyVersion: policy.privacyVersion,
      acceptTerms: true, acknowledgePrivacy: true, acceptedAt: FieldValue.serverTimestamp(),
      updatedAt: FieldValue.serverTimestamp()};
    const auditId = createHash("sha256").update(JSON.stringify([uid, policy.contentHash])).digest("hex");
    // Read immutable audit before writing: retries/reverting a policy preserve its original acceptance time.
    const event = db.collection("courierConsentEvents/" + uid + "/events").doc(auditId);
    const existingEvent = await tx.get(event);
    tx.set(db.collection("courierPolicyAcceptances").doc(uid), {...record,
      firstAcceptedAt: state.acceptance?.firstAcceptedAt ?? FieldValue.serverTimestamp()});
    if (!existingEvent.exists) tx.create(event, record);
    return {accepted: true, policyRevision: policy.revision, policyHash: policy.contentHash};
  });
}
function createCourierPolicyFunctions(db) {
  return {chamaeAceitarDocumentosMotoboy: onCall({region: "southamerica-east1", maxInstances: 10},
      (request) => acceptDocuments(db, request))};
}
module.exports = {policyFingerprint, validPolicy, acceptanceCurrent, assertCurrentCourierAcceptance,
  currentCourierAcceptance, acceptDocuments, createCourierPolicyFunctions};
