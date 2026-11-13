const {createHash} = require("node:crypto");
const {HttpsError} = require("firebase-functions/v2/https");
function documentFingerprint(policy, fields) {
  return createHash("sha256").update(JSON.stringify(fields.map((key) => {
    let value = policy[key] ?? null;
    if (key === "minimumAgeByCountry" && value && typeof value === "object" && !Array.isArray(value)) {
      value = Object.fromEntries(Object.keys(value).sort().map((country) => [country, value[country]]));
    }
    return [key, value];
  }))).digest("hex");
}
function validPublishedPolicy(policy, fields, textFields, versions) {
  if (!policy || policy.published !== true || policy.draft !== false ||
      textFields.some((key) => typeof policy[key] !== "string" || !policy[key].trim()) ||
      versions.some((key) => /draft/i.test(policy[key])) ||
      [policy.termsUrl, policy.privacyUrl].some((value) => {
        try {
          return typeof value !== "string" || new URL(value).protocol !== "https:";
        } catch (_) {
          return true;
        }
      }) || policy.contentHash !== documentFingerprint(policy, fields)) {
    throw new HttpsError("failed-precondition", "Os documentos oficiais ainda não estão disponíveis.",
        {reason: "POLICY_UNAVAILABLE"});
  }
  return policy;
}
module.exports = {documentFingerprint, validPublishedPolicy};
