const {createHash} = require("node:crypto");
const {HttpsError} = require("firebase-functions/v2/https");
const {FieldValue} = require("firebase-admin/firestore");

const digest = (value) => createHash("sha256").update(value).digest("hex");
const fail = (reason) => {
  throw new HttpsError("failed-precondition", "A revogação Apple precisa ser confirmada antes da exclusão.", {reason});
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

// Server-only integration seam. No provider token/secret is accepted from the closure payload.
// A real adapter must obtain an authorized credential bound to this subject, revoke it,
// and support retries for the supplied key. No real Apple adapter/configuration exists yet.
async function ensureAppleRevoked(db, uid, job, user, services = {}) {
  const apple = user?.providerData?.find((item) => item.providerId === "apple.com");
  if (!apple && job.requiresAppleRevocation !== true) return;
  const subject = typeof apple?.uid === "string" && apple.uid ? apple.uid : null;
  const subjectHash = subject ? digest(subject) : job.appleSubjectHash;
  if (!subjectHash) fail("APPLE_REVOCATION_IDENTITY_UNVERIFIED");
  if (!attemptTime(job)) fail("APPLE_REVOCATION_REQUEST_UNVERIFIED");
  const fingerprint = digest(JSON.stringify([uid, job.requestId, subjectHash, attemptTime(job)]));
  const jobRef = db.collection("customerAccountClosures").doc(uid);
  const receiptRef = db.collection("customerProviderRevocations").doc(uid);
  const receipt = await receiptRef.get();
  if (receipt.exists && receipt.data().status === "revoked" && receipt.data().fingerprint === fingerprint) return;
  if (!subject) fail("APPLE_REVOCATION_IDENTITY_UNVERIFIED");
  await db.runTransaction(async (tx) => {
    const current = await tx.get(jobRef);
    if (!sameClosureAttempt(job, current.data()) ||
        !["requested", "processing"].includes(current.data().status)) fail("APPLE_REVOCATION_REQUEST_CHANGED");
    tx.update(jobRef, {requiresAppleRevocation: true, appleSubjectHash: subjectHash});
  });
  if (typeof services.revokeApple !== "function") fail("APPLE_REVOCATION_NOT_CONFIGURED");
  let result;
  try {
    result = await services.revokeApple({uid, subject, idempotencyKey: fingerprint});
  } catch (_) {
    fail("APPLE_REVOCATION_FAILED");
  }
  if (result?.revoked !== true || result.subject !== subject) fail("APPLE_REVOCATION_UNCONFIRMED");
  await db.runTransaction(async (tx) => {
    const current = await tx.get(jobRef);
    const saved = await tx.get(receiptRef);
    if (!sameClosureAttempt(job, current.data()) ||
        !["requested", "processing"].includes(current.data().status)) fail("APPLE_REVOCATION_REQUEST_CHANGED");
    if (saved.exists && saved.data().status === "revoked" && saved.data().fingerprint === fingerprint) return;
    tx.set(receiptRef, {schemaVersion: 1, status: "revoked", fingerprint,
      subjectHash, requestId: job.requestId, requestedAt: job.requestedAt, completedAt: FieldValue.serverTimestamp()});
  });
}
module.exports = {tokenHasApple, ensureAppleRevoked, sameClosureAttempt};
