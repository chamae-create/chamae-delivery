"use strict";
const {HttpsError} = require("firebase-functions/v2/https");
const AGE_POLICY_VERSION = "agecheck-v1";
const FLOOR = Object.freeze({BR: 18, PY: 20});
const runtimeTrust = Object.freeze({enabled: false, providers: Object.freeze([])});
const fail = (reason) => {throw new HttpsError("failed-precondition", reason, {reason});};
function requiredAge(country, configured) {
  if (!Object.hasOwn(FLOOR, country) || !Number.isInteger(configured) || configured < FLOOR[country] || configured > 120) fail("AGE_POLICY_UNAVAILABLE");
  return configured;
}
function restrictedProduct(product) {
  // Catalog attributes, never product names. Legacy category is retained conservatively.
  const category = String(product.category || "").normalize("NFD").replace(/[\u0300-\u036f]/g, "").toLowerCase();
  return product.isAlcoholic === true || product.requiresAgeCheck === true ||
    ["cervejas", "destilados", "vinhos", "kaipi fruit"].includes(category);
}
function assertAgeEvidence(record, {uid, minimum, now = Date.now(), trust = runtimeTrust, identityRevision}) {
  if (!trust.enabled || !Array.isArray(trust.providers) || !trust.providers.length) fail("AGE_PROVIDER_UNAVAILABLE");
  if (!record || record.uid !== uid || record.identityRevision !== identityRevision || !Number.isSafeInteger(identityRevision) || identityRevision < 1 || record.schemaVersion !== 1 || record.policyVersion !== AGE_POLICY_VERSION) fail("AGE_VERIFICATION_REQUIRED");
  if (record.status === "appealPending") fail("AGE_APPEAL_PENDING");
  if (record.revoked === true || record.status !== "approved") fail("AGE_VERIFICATION_REQUIRED");
  if (!trust.providers.includes(record.provider) || record.ageVerified !== true ||
      record.identityVerified !== true || record.subjectBoundToUid !== true ||
      typeof record.evidenceDigest !== "string" || !/^[a-f0-9]{64}$/.test(record.evidenceDigest)) fail("AGE_EVIDENCE_UNTRUSTED");
  if (!Number.isSafeInteger(record.issuedAtMs) || !Number.isSafeInteger(record.expiresAtMs) ||
      record.issuedAtMs > now || record.expiresAtMs <= now || record.expiresAtMs <= record.issuedAtMs) fail("AGE_VERIFICATION_EXPIRED");
  if (!Number.isInteger(record.ageAtLeast) || record.ageAtLeast < minimum) fail("AGE_RESTRICTED");
  return {verified: true, minimumAge: minimum};
}
function assertDeliveryAge(record, {orderId, assignmentId, courierUid, minimum, now = Date.now()}) {
  if (!record || record.orderId !== orderId || record.assignmentId !== assignmentId ||
      record.courierUid !== courierUid || record.status !== "approved" ||
      record.identityMatches !== true || !Number.isInteger(record.minimumAge) ||
      record.minimumAge < minimum || !Number.isSafeInteger(record.expiresAtMs) ||
      record.expiresAtMs <= now) fail("RECIPIENT_AGE_CONFIRMATION_REQUIRED");
}
module.exports = {AGE_POLICY_VERSION, FLOOR, runtimeTrust, requiredAge, restrictedProduct, assertAgeEvidence, assertDeliveryAge};
