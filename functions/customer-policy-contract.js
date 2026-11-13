const policyFields = ["revision", "termsVersion", "privacyVersion", "alcoholVersion",
  "termsText", "privacyText", "alcoholNotice", "termsUrl", "privacyUrl", "minimumAgeByCountry"];
const {documentFingerprint, validPublishedPolicy} = require("./published-policy");
function policyFingerprint(policy) {
  return documentFingerprint(policy, policyFields);
}
function validPolicy(policy) {
  return validPublishedPolicy(policy, policyFields,
      ["revision", "termsVersion", "privacyVersion", "alcoholVersion", "termsText", "privacyText", "alcoholNotice"],
      ["termsVersion", "privacyVersion", "alcoholVersion"]);
}
function birthDate(value, now = new Date()) {
  if (typeof value !== "string" || !/^\d{4}-\d{2}-\d{2}$/.test(value)) return null;
  const date = new Date(`${value}T00:00:00.000Z`);
  if (!Number.isFinite(date.getTime()) || date.toISOString().slice(0, 10) !== value ||
      date.getUTCFullYear() < 1900 || date > now) return null;
  return date;
}
const {validNavigationDeclaration, navigationMinimum} = require("./navigation-age");
function legacyNavigationEligible(value, policy, now = new Date()) {
  const dob = birthDate(value, now), minimum = navigationMinimum(policy, "BR");
  if (!dob || minimum === null) return false;
  let age = now.getUTCFullYear() - dob.getUTCFullYear();
  if (now.getUTCMonth() < dob.getUTCMonth() || (now.getUTCMonth() === dob.getUTCMonth() && now.getUTCDate() < dob.getUTCDate())) age--;
  return age >= minimum;
}
function profileCurrent(profile, policy) {
  return Boolean(profile && (legacyNavigationEligible(profile.birthDate, policy) || validNavigationDeclaration(profile.navigationAgeDeclaration, policy)) && profile.acceptedAt &&
    profile.termsVersion === policy.termsVersion && profile.privacyVersion === policy.privacyVersion &&
    profile.alcoholVersion === policy.alcoholVersion && profile.policyRevision === policy.revision &&
    profile.policyHash === policy.contentHash);
}
module.exports = {policyFields, policyFingerprint, validPolicy, birthDate, profileCurrent};
