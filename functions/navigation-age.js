"use strict";
const {HttpsError} = require("firebase-functions/v2/https");
const floors = Object.freeze({BR: 18, PY: 20});
function navigationMinimum(policy, country) {
  const value = policy.minimumAgeByCountry?.[country];
  return Object.hasOwn(floors, country) && Number.isInteger(value) && value >= floors[country] && value <= 120 ? value : null;
}
function validNavigationDeclaration(value, policy) {
  return Boolean(value && typeof value === "object" && !Array.isArray(value) &&
    Object.keys(value).length === 3 && Object.keys(value).every(k => ["countryCode", "minimumAge", "declared"].includes(k)) &&
    value.declared === true && navigationMinimum(policy, value.countryCode) !== null &&
    value.minimumAge === navigationMinimum(policy, value.countryCode));
}
function assertNavigationDeclaration(value, policy, previous, now = new Date()) {
  if (!validNavigationDeclaration(value, policy)) throw new HttpsError("invalid-argument", "NAVIGATION_AGE_DECLARATION_REQUIRED");
  if (previous.birthDate) {
    const dob = new Date(previous.birthDate + "T00:00:00.000Z");
    let age = now.getUTCFullYear() - dob.getUTCFullYear();
    if (now.getUTCMonth() < dob.getUTCMonth() || (now.getUTCMonth() === dob.getUTCMonth() && now.getUTCDate() < dob.getUTCDate())) age--;
    if (!Number.isFinite(age) || age < value.minimumAge) throw new HttpsError("permission-denied", "AGE_RESTRICTED");
  }
  return {countryCode: value.countryCode, minimumAge: value.minimumAge, declared: true};
}
module.exports = {navigationMinimum, validNavigationDeclaration, assertNavigationDeclaration};
