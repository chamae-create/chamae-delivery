const {policyFingerprint} = require("../customer-onboarding");
// TEST ONLY. No legal text, URL or age in this fixture is production policy.
const customerPolicyFixture = () => {
  const policy = {published: true, draft: false, revision: "TEST-ONLY-1",
    termsVersion: "TEST-ONLY-1", privacyVersion: "TEST-ONLY-1",
    alcoholVersion: "TEST-ONLY-1", termsText: "TEST FIXTURE",
    privacyText: "TEST FIXTURE", alcoholNotice: "TEST FIXTURE",
    termsUrl: "https://example.test/terms",
    privacyUrl: "https://example.test/privacy", minimumAgeByCountry: {}};
  policy.contentHash = policyFingerprint(policy); return policy;
};
const customerProfileFixture = (policy, acceptedAt) => ({
  birthDate: "2000-01-01", dateOfBirthVerified: false,
  termsVersion: policy.termsVersion, privacyVersion: policy.privacyVersion,
  alcoholVersion: policy.alcoholVersion, policyRevision: policy.revision,
  policyHash: policy.contentHash, acceptedAt,
});
module.exports = {customerPolicyFixture, customerProfileFixture};
