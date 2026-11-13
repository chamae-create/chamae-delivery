const {createHash} = require("node:crypto");
const {onCall, HttpsError} = require("firebase-functions/v2/https");
const {FieldValue} = require("firebase-admin/firestore");
const {verifiedCustomerToken} = require("./customer-identity");

const policyFields = ["revision", "termsVersion", "privacyVersion", "alcoholVersion",
  "termsText", "privacyText", "alcoholNotice", "termsUrl", "privacyUrl", "minimumAgeByCountry"];
function policyFingerprint(policy) {
  const stableValue = (key) => {
    const value = policy[key] ?? null;
    return key === "minimumAgeByCountry" && value && typeof value === "object" && !Array.isArray(value) ?
      Object.fromEntries(Object.keys(value).sort().map((country) => [country, value[country]])) : value;
  };
  return createHash("sha256").update(JSON.stringify(
      policyFields.map((key) => [key, stableValue(key)]))).digest("hex");
}
function validPolicy(policy) {
  const text = ["revision", "termsVersion", "privacyVersion", "alcoholVersion",
    "termsText", "privacyText", "alcoholNotice"];
  const urls = [policy?.termsUrl, policy?.privacyUrl];
  if (!policy || policy.published !== true || policy.draft !== false ||
      text.some((k) => typeof policy[k] !== "string" || !policy[k].trim()) ||
      [policy.termsVersion, policy.privacyVersion, policy.alcoholVersion].some((v) => /draft/i.test(v)) ||
      urls.some((value) => {
        try {
          return new URL(value).protocol !== "https:";
        } catch (_) {
          return true;
        }
      }) ||
      policy.contentHash !== policyFingerprint(policy)) {
    throw new HttpsError("failed-precondition", "Os documentos oficiais ainda não estão disponíveis.");
  }
  return policy;
}
function birthDate(value, now = new Date()) {
  if (typeof value !== "string" || !/^\d{4}-\d{2}-\d{2}$/.test(value)) return null;
  const date = new Date(`${value}T00:00:00.000Z`);
  if (!Number.isFinite(date.getTime()) || date.toISOString().slice(0, 10) !== value ||
      date.getUTCFullYear() < 1900 || date > now) return null;
  return date;
}
function profileCurrent(profile, policy) {
  return Boolean(profile && birthDate(profile.birthDate) && profile.acceptedAt &&
    profile.termsVersion === policy.termsVersion && profile.privacyVersion === policy.privacyVersion &&
    profile.alcoholVersion === policy.alcoholVersion && profile.policyRevision === policy.revision &&
    profile.policyHash === policy.contentHash);
}
function customerUid(request) {
  if (!request.auth || !verifiedCustomerToken(request.auth.token) ||
      (request.auth.token.roles || []).length) {
    throw new HttpsError("permission-denied", "Entre com sua conta para continuar.");
  }
  return request.auth.uid;
}
async function acceptDocuments(db, request) {
  const uid = customerUid(request); const data = request.data || {};
  if (data.acceptTerms !== true || data.acknowledgePrivacy !== true || data.acknowledgeAlcohol !== true) {
    throw new HttpsError("invalid-argument", "Confira os três aceites antes de continuar.");
  }
  if (!birthDate(data.birthDate)) throw new HttpsError("invalid-argument", "Informe uma data de nascimento válida.");
  const profileRef = db.collection("customerProfiles").doc(uid);
  return db.runTransaction(async (tx) => {
    const policyDoc = await tx.get(db.collection("customerPolicies").doc("current"));
    const old = await tx.get(profileRef);
    const courier = await tx.get(db.collection("couriers").doc(uid));
    if (courier.exists) throw new HttpsError("permission-denied", "Acesso restrito.");
    const policy = validPolicy(policyDoc.data());
    if (["termsVersion", "privacyVersion", "alcoholVersion"].some((key) => data[key] !== policy[key]) ||
        data.policyRevision !== policy.revision || data.policyHash !== policy.contentHash) {
      throw new HttpsError("failed-precondition", "Os documentos foram atualizados. Confira a nova versão.");
    }
    if (old.exists && old.data().birthDate != null && old.data().birthDate !== data.birthDate) {
      throw new HttpsError("failed-precondition", "Para corrigir a data de nascimento, solicite atendimento à loja.");
    }
    if (old.exists && profileCurrent(old.data(), policy)) return {accepted: true};
    const record = {birthDate: data.birthDate, dateOfBirthVerified: false,
      acceptTerms: true, acknowledgePrivacy: true, acknowledgeAlcohol: true,
      termsVersion: policy.termsVersion, privacyVersion: policy.privacyVersion,
      alcoholVersion: policy.alcoholVersion, policyRevision: policy.revision,
      policyHash: policy.contentHash, acceptedAt: FieldValue.serverTimestamp(),
      updatedAt: FieldValue.serverTimestamp()};
    tx.set(profileRef, {...record,
      firstAcceptedAt: old.data()?.firstAcceptedAt ?? FieldValue.serverTimestamp()});
    const auditId = createHash("sha256").update(JSON.stringify([uid, policy.contentHash])).digest("hex");
    tx.set(db.collection(`customerConsentEvents/${uid}/events`).doc(auditId), record);
    return {accepted: true};
  });
}
async function prepareCustomerEligibility(tx, db, order) {
  // Old orders retain the financial/stock flow that existed when created.
  if (order.customerFlowVersion !== 2) return null;
  const policyDoc = await tx.get(db.collection("customerPolicies").doc("current"));
  const profileDoc = await tx.get(db.collection("customerProfiles").doc(order.customerUid));
  const policy = validPolicy(policyDoc.data());
  if (!profileCurrent(profileDoc.data(), policy)) {
    throw new HttpsError("failed-precondition", "Confira os documentos atualizados antes de comprar.");
  }
  if (!["BR", "PY"].includes(order.deliveryAddress?.countryCode)) {
    throw new HttpsError("failed-precondition", "Confirme o país do destino.");
  }
  return {policy, profile: profileDoc.data(), country: order.deliveryAddress.countryCode,
    documentRequiredAtDelivery: false};
}
function checkProductEligibility(context, product, now = new Date()) {
  if (!context) return;
  const category = String(product.category || "").normalize("NFD").replace(/[\u0300-\u036f]/g, "").toLowerCase();
  const restricted = product.requiresAgeCheck === true || product.isAlcoholic === true ||
    ["cervejas", "destilados", "vinhos", "kaipi fruit"].includes(category);
  if (!restricted) return;
  const minimum = context.policy.minimumAgeByCountry?.[context.country];
  if (!Number.isInteger(minimum) || minimum < 1 || minimum > 120) {
    throw new HttpsError("failed-precondition",
        "A elegibilidade deste produto para o destino ainda não está disponível.");
  }
  const dob = birthDate(context.profile.birthDate, now);
  let age = now.getUTCFullYear() - dob.getUTCFullYear();
  if (now.getUTCMonth() < dob.getUTCMonth() ||
      (now.getUTCMonth() === dob.getUTCMonth() && now.getUTCDate() < dob.getUTCDate())) age--;
  if (age < minimum) {
    throw new HttpsError("permission-denied", "Este produto não está disponível para sua faixa etária neste destino.",
        {reason: "AGE_RESTRICTED"});
  }
  context.documentRequiredAtDelivery = true;
}
async function checkPurchase(db, request) {
  const uid = customerUid(request); const data = request.data || {};
  if (!Array.isArray(data.productIds) || !data.productIds.length || data.productIds.length > 100 ||
      data.productIds.some((id) => typeof id !== "string" || !id || id.includes("/"))) {
    throw new HttpsError("invalid-argument", "Confira os produtos da sacola.");
  }
  return db.runTransaction(async (tx) => {
    const courier = await tx.get(db.collection("couriers").doc(uid));
    if (courier.exists) throw new HttpsError("permission-denied", "Acesso restrito.");
    const context = await prepareCustomerEligibility(tx, db, {customerFlowVersion: 2,
      customerUid: uid, deliveryAddress: {countryCode: data.countryCode}});
    for (const id of new Set(data.productIds)) {
      const product = await tx.get(db.collection("products").doc(id));
      if (!product.exists) throw new HttpsError("failed-precondition", "Um produto não está mais disponível.");
      checkProductEligibility(context, product.data());
    }
    return {eligible: true, documentRequiredAtDelivery: context.documentRequiredAtDelivery,
      policyRevision: context.policy.revision};
  });
}
function createCustomerOnboarding(db) {
  const options = {region: "southamerica-east1"};
  return {
    chamaeAceitarDocumentosCliente: onCall(options, (r) => acceptDocuments(db, r)),
    chamaeConferirElegibilidadeCompra: onCall(options, (r) => checkPurchase(db, r)),
  };
}
module.exports = {policyFingerprint, validPolicy, birthDate, profileCurrent,
  acceptDocuments, prepareCustomerEligibility, checkProductEligibility, checkPurchase, createCustomerOnboarding};
