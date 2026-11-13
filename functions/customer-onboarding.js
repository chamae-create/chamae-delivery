const {createHash} = require("node:crypto");
const {onCall, HttpsError} = require("firebase-functions/v2/https");
const {FieldValue} = require("firebase-admin/firestore");
const {assertAgeEvidence, requiredAge} = require("./age-eligibility");
const {assertDestinationOperation, assertSinglePayment} = require("./checkout-policy");
const {verifiedCustomerToken} = require("./customer-identity");
const {assertCustomerAccountActive} = require("./customer-account-state");

const {policyFingerprint, validPolicy, birthDate, profileCurrent} = require("./customer-policy-contract");
const {assertNavigationDeclaration} = require("./navigation-age");
function customerUid(request) {
  if (!request.auth || !verifiedCustomerToken(request.auth.token) ||
      (!Array.isArray(request.auth.token.roles || []) ||
        (request.auth.token.roles || []).length || request.auth.token.superadmin === true)) {
    throw new HttpsError("permission-denied", "Entre com sua conta para continuar.");
  }
  return request.auth.uid;
}
async function acceptDocuments(db, request) {
  const uid = customerUid(request); const data = request.data || {};
  if (data.acceptTerms !== true || data.acknowledgePrivacy !== true || data.acknowledgeAlcohol !== true) {
    throw new HttpsError("invalid-argument", "Confira os três aceites antes de continuar.");
  }
  const modern = Object.hasOwn(data, "navigationAgeDeclaration");
  if ((modern && Object.hasOwn(data, "birthDate")) || (!modern && !birthDate(data.birthDate))) throw new HttpsError("invalid-argument", "Informe uma data de nascimento válida.");
  const profileRef = db.collection("customerProfiles").doc(uid);
  return db.runTransaction(async (tx) => {
    await assertCustomerAccountActive(db, uid, tx);
    const policyDoc = await tx.get(db.collection("customerPolicies").doc("current"));
    const old = await tx.get(profileRef);
    const courier = await tx.get(db.collection("couriers").doc(uid));
    if (courier.exists) throw new HttpsError("permission-denied", "Acesso restrito.");
    const policy = validPolicy(policyDoc.data());
    if (["termsVersion", "privacyVersion", "alcoholVersion"].some((key) => data[key] !== policy[key]) ||
        data.policyRevision !== policy.revision || data.policyHash !== policy.contentHash) {
      throw new HttpsError("failed-precondition", "Os documentos foram atualizados. Confira a nova versão.");
    }
    const declaration = modern ? assertNavigationDeclaration(data.navigationAgeDeclaration, policy, old.data() || {}) : null;
    if (!modern) assertNavigationDeclaration({countryCode: "BR", minimumAge: policy.minimumAgeByCountry?.BR, declared: true}, policy, {birthDate: data.birthDate});
    if (!modern && old.exists && old.data().birthDate != null && old.data().birthDate !== data.birthDate) {
      throw new HttpsError("failed-precondition", "Para corrigir a data de nascimento, solicite atendimento à loja.");
    }
    if (old.exists && profileCurrent(old.data(), policy)) return {accepted: true};
    // Consent evidence contains no full birth date, phone or document number.
    const record = {...(declaration ? {navigationAgeDeclaration: declaration} : {}),
      acceptTerms: true, acknowledgePrivacy: true, acknowledgeAlcohol: true,
      termsVersion: policy.termsVersion, privacyVersion: policy.privacyVersion,
      alcoholVersion: policy.alcoholVersion, policyRevision: policy.revision,
      policyHash: policy.contentHash, acceptedAt: FieldValue.serverTimestamp(),
      updatedAt: FieldValue.serverTimestamp()};
    tx.set(profileRef, {...record,
      ...(!modern ? {birthDate: data.birthDate, dateOfBirthVerified: false} : {}),
      firstAcceptedAt: old.data()?.firstAcceptedAt ?? FieldValue.serverTimestamp()}, {merge: true});
    const auditId = createHash("sha256").update(JSON.stringify([uid, policy.contentHash])).digest("hex");
    tx.set(db.collection(`customerConsentEvents/${uid}/events`).doc(auditId), record);
    return {accepted: true};
  });
}
async function prepareCustomerEligibility(tx, db, order) {
  // Old orders retain the financial/stock flow that existed when created.
  if (order.customerFlowVersion !== 2) return null;
  assertSinglePayment(order);
  await assertCustomerAccountActive(db, order.customerUid, tx);
  const policyDoc = await tx.get(db.collection("customerPolicies").doc("current"));
  const profileDoc = await tx.get(db.collection("customerProfiles").doc(order.customerUid));
  const policy = validPolicy(policyDoc.data());
  if (!profileCurrent(profileDoc.data(), policy)) {
    throw new HttpsError("failed-precondition", "Confira os documentos atualizados antes de comprar.");
  }
  if (!["BR", "PY"].includes(order.deliveryAddress?.countryCode)) {
    throw new HttpsError("failed-precondition", "Confirme o país do destino.");
  }
  assertDestinationOperation(order.deliveryAddress.countryCode);
  const ageProof = await tx.get(db.collection("customerAgeVerifications").doc(order.customerUid));
  return {policy, profile: profileDoc.data(), ageProof: ageProof.data(), uid: order.customerUid, country: order.deliveryAddress.countryCode,
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
  if (!dob) throw new HttpsError("failed-precondition", "AGE_VERIFICATION_REQUIRED", {reason: "AGE_PROOF_REQUIRED"});
  let age = now.getUTCFullYear() - dob.getUTCFullYear();
  if (now.getUTCMonth() < dob.getUTCMonth() ||
      (now.getUTCMonth() === dob.getUTCMonth() && now.getUTCDate() < dob.getUTCDate())) age--;
  if (age < minimum) {
    throw new HttpsError("permission-denied", "Este produto não está disponível para sua faixa etária neste destino.",
        {reason: "AGE_RESTRICTED"});
  }
  const floor = requiredAge(context.country, minimum);
  assertAgeEvidence(context.ageProof, {uid: context.uid, minimum: floor, identityRevision: context.profile.identityRevision});
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
