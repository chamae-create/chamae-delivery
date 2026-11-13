const {policyFingerprint} = require("../courier-policy");
function courierPolicyFixture(patch = {}) {
  const policy = {published: true, draft: false, revision: "TEST-ONLY-1", termsVersion: "TEST-ONLY-1",
    privacyVersion: "TEST-ONLY-1", termsText: "TEST FIXTURE TERMS", privacyText: "TEST FIXTURE PRIVACY",
    termsUrl: "https://example.test/terms", privacyUrl: "https://example.test/privacy", ...patch};
  return {...policy, contentHash: policyFingerprint(policy)};
}
function courierAcceptanceFixture(policy, acceptedAt) {
  return {policyRevision: policy.revision, policyHash: policy.contentHash, termsVersion: policy.termsVersion,
    privacyVersion: policy.privacyVersion, acceptTerms: true, acknowledgePrivacy: true, acceptedAt};
}
async function seedCourierPolicy(db, uid, acceptedAt = new Date()) {
  const policy = courierPolicyFixture();
  await db.doc("courierPolicies/current").set(policy);
  await db.doc("courierPolicyAcceptances/" + uid).set(courierAcceptanceFixture(policy, acceptedAt));
}
module.exports = {courierPolicyFixture, courierAcceptanceFixture, seedCourierPolicy};
