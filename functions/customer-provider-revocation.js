const {createHash} = require("node:crypto");
const {HttpsError} = require("firebase-functions/v2/https");
const {FieldValue} = require("firebase-admin/firestore");
const {AppleRevocationError, createAppleRevocationServices} = require("./apple-revocation-adapter");
const digest = (value) => createHash("sha256").update(value).digest("hex");
const fail = (reason) => {
  throw new HttpsError(reason === "APPLE_REVOCATION_RETRYABLE" ? "unavailable" : "failed-precondition",
      "A autorização Apple precisa de nova tentativa ou revisão segura.", {reason});
};
function tokenHasApple(token) {
  return token?.firebase?.sign_in_provider === "apple.com" ||
    Array.isArray(token?.firebase?.identities?.["apple.com"]) &&
    token.firebase.identities["apple.com"].length > 0;
}
function attemptTime(job) {
  const value = job?.requestedAt;
  return value && Number.isSafeInteger(value.seconds) && Number.isSafeInteger(value.nanoseconds) ?
    `${value.seconds}:${value.nanoseconds}` : null;
}
function sameClosureAttempt(expected, current) {
  return current?.requestId === expected.requestId && attemptTime(expected) !== null &&
    attemptTime(expected) === attemptTime(current);
}
async function ensureAppleRevoked(db, uid, job, user, services = {}) {
  const apple = user?.providerData?.find((item) => item.providerId === "apple.com");
  if (!apple && job.requiresAppleRevocation !== true) return {status: "not_required"};
  const subject = typeof apple?.uid === "string" && apple.uid ? apple.uid : null;
  const subjectHash = subject ? digest(subject) : job.appleSubjectHash;
  if (!subjectHash) fail("APPLE_REVOCATION_IDENTITY_UNVERIFIED");
  if (!attemptTime(job)) fail("APPLE_REVOCATION_REQUEST_UNVERIFIED");
  const fingerprint = digest(JSON.stringify([uid, job.requestId, subjectHash, attemptTime(job)]));
  const jobRef = db.collection("customerAccountClosures").doc(uid);
  const receiptRef = db.collection("customerProviderRevocations").doc(uid);
  const receipt = await receiptRef.get();
  // A manual outcome permits account erasure, but NEVER asserts Apple was revoked.
  if (receipt.exists && ["revoked", "manual_required"].includes(receipt.data().status) &&
      receipt.data().fingerprint === fingerprint) return receipt.data();
  if (!subject) fail("APPLE_REVOCATION_IDENTITY_UNVERIFIED");
  await db.runTransaction(async (tx) => {
    const current = await tx.get(jobRef);
    if (!sameClosureAttempt(job, current.data()) ||
        !["requested", "processing"].includes(current.data()?.status)) fail("APPLE_REVOCATION_REQUEST_CHANGED");
    tx.update(jobRef, {requiresAppleRevocation: true, appleSubjectHash: subjectHash});
  });
  const provider = services.revokeApple ? services : createAppleRevocationServices(db);
  let result;
  try {
    result = await provider.revokeApple({uid, subject, idempotencyKey: fingerprint});
  } catch (error) {
    fail(error instanceof AppleRevocationError ? error.reason : "APPLE_REVOCATION_FAILED");
  }
  const manual = result?.status === "manual_required" &&
    ["LEGACY_CREDENTIAL_MISSING", "APPLE_CREDENTIAL_UNUSABLE"].includes(result.reason);
  if (result?.subject !== subject || result.revoked !== true && !manual) fail("APPLE_REVOCATION_UNCONFIRMED");
  return db.runTransaction(async (tx) => {
    const current = await tx.get(jobRef);
    const saved = await tx.get(receiptRef);
    if (!sameClosureAttempt(job, current.data()) ||
        !["requested", "processing"].includes(current.data()?.status)) fail("APPLE_REVOCATION_REQUEST_CHANGED");
    if (saved.exists && ["revoked", "manual_required"].includes(saved.data().status) &&
        saved.data().fingerprint === fingerprint) return saved.data();
    const record = {schemaVersion: 2, status: manual ? "manual_required" : "revoked", fingerprint,
      subjectHash, requestId: job.requestId, requestedAt: job.requestedAt,
      evidence: manual ? "no_server_revocation_confirmation" : result.evidence || "trusted_server_adapter",
      reason: manual ? result.reason : "APPLE_ACCEPTED_REVOCATION",
      recordedAt: FieldValue.serverTimestamp()};
    if (!manual) record.completedAt = FieldValue.serverTimestamp();
    tx.set(receiptRef, record);
    return record;
  });
}
module.exports = {tokenHasApple, ensureAppleRevoked, sameClosureAttempt};
