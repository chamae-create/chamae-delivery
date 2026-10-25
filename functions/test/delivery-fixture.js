const {countryEvidence} = require("./operational-fixture");
// TEST ONLY: synthetic coordinates, route result and price. Never imported by
// production handlers or used to provision a live configuration.
/** Builds explicit private pricing documents for isolated tests.
 * @param {Object} options Synthetic owner, quote ID and fee.
 * @return {Object} Destination, quote ID and documents to seed.
 */
function deliveryFixture({uid = "buyer", feeCents = 1000,
  quoteId = "b".repeat(64)} = {}) {
  const origin = {latitude: -20, longitude: -50};
  const destination = {latitude: -22.5, longitude: -55.7,
    countryCode: "BR", confirmed: true, street: "Rua das Flores",
    city: "Cidade", number: "123"};
  const table = {schemaVersion: 2, minimumPolicy: "replace", origin,
    maxDistanceMeters: 3000, bands: [{minExclusiveMeters: 0,
      maxInclusiveMeters: 3000, priceCents: feeCents,
      enabled: true, order: 0}]};
  return {destination, quoteId, documents: new Map([
    ["deliveryConfiguration/current", {mode: "routeBands",
      activeVersion: "test-route-v1", travelMode: "DRIVE"}],
    ["deliveryPricingVersions/test-route-v1", {version: "test-route-v1",
      status: "published", published: true, table}],
    [`deliveryQuotes/${quoteId}`, {uid, version: "test-route-v1", origin,
      destination, distanceMeters: 2300, distanceUnit: "m",
      destinationVerification: countryEvidence(destination),
      distanceSource: "route", provider: "test-route", feeCents,
      createdAtMs: Date.now(), expiresAtMs: Date.now() + 300000}],
  ])};
}
module.exports = {deliveryFixture};
