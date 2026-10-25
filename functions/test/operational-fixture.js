const fs = require("node:fs");
const path = require("node:path");
const assert = require("node:assert/strict");
const {serverClock} = require("../order-acceptance");

// TEST ONLY. No process-wide Date override or switch in production requests.
const openTime = Date.parse("2026-10-24T16:00:00Z");
const useOpenClock = () => {
  serverClock.now = () => openTime;
};
const countryEvidence = (destination) => ({schemaVersion: 1,
  provider: "google-geocoding", countryCode: destination.countryCode,
  latitude: destination.latitude, longitude: destination.longitude,
  verifiedAtMs: Date.now()});
const countryVerifier = {verify: async (destination) => countryEvidence(destination)};

// Firestore has no injectable request.time. Replace only the argument of the
// real schedule predicate, in memory, when loading local emulator test Rules.
// The function body, authorization, payload checks and createdAt stay intact.
function rulesAt(instant = "2026-10-24T16:00:00Z") {
  const rules = fs.readFileSync(path.join(__dirname, "../../firestore.rules"), "utf8");
  if (instant === null) return rules;
  assert.equal(rules.split("storeAcceptsAt(request.time)").length, 2);
  return rules.replace("storeAcceptsAt(request.time)",
      `storeAcceptsAt(timestamp.value("${instant}"))`);
}
module.exports = {openTime, useOpenClock, countryEvidence, countryVerifier, rulesAt};
