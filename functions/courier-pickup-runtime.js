"use strict";
const {defineBoolean, defineString, defineSecret} = require("firebase-functions/params");
const {HttpsError} = require("firebase-functions/v2/https");
const {createSecretPickupPorts} = require("./courier-pickup-ports");
const {createStoredRoutePackageProvider} = require("./courier-route-package-provider");
// Metadata declarations only. No .value() is evaluated while discovering exports.
// No secret is created/provisioned by this source file.
const enabled = defineBoolean("CHAMAE_PICKUP_ENABLED", {default: false});
const producerId = defineString("CHAMAE_PICKUP_PRODUCER_ID", {default: ""});
const keyId = defineString("CHAMAE_PICKUP_KEY_ID", {default: "pickup-v2"});
const signingSecret = defineSecret("CHAMAE_PICKUP_SIGNING_KEY");
const routeSourceId = defineString("CHAMAE_PICKUP_ROUTE_SOURCE_ID", {default: ""});
const routeEngine = defineString("CHAMAE_PICKUP_ROUTE_ENGINE", {default: ""});
function createPickupRuntime(db, helpers, config = {enabled, producerId, keyId, signingSecret, routeSourceId, routeEngine}) {
  function ports() {
    if (config.enabled.value() !== true) {
      throw new HttpsError("failed-precondition", "PICKUP_RUNTIME_DISABLED", {reason: "PICKUP_RUNTIME_DISABLED"});
    }
    const producer = config.producerId.value(), alias = config.keyId.value();
    if (typeof producer !== "string" || !/^[A-Za-z0-9_-]{1,80}$/.test(producer) ||
        typeof alias !== "string" || !/^[A-Za-z0-9_:-]{1,128}$/.test(alias)) {
      throw new HttpsError("failed-precondition", "PICKUP_RUNTIME_NOT_CONFIGURED");
    }
    return createSecretPickupPorts({keySecret: config.signingSecret, keyId: alias,
      packageProvider: createStoredRoutePackageProvider(db, {producerId: producer, ...helpers})});
  }
  return Object.freeze({
    secrets: [config.signingSecret],
    async preparePackage(request) {
      const signing = ports();
      await signing.publicKey(signing.keyId); // Fail before producing if the legitimate signer is absent.
      const navigation = require("./courier-navigation-source").createStoredNavigationProvider(db, {
        sourceId: config.routeSourceId?.value(), engine: config.routeEngine?.value()});
      return require("./courier-route-package-producer").createRoutePackageProducer(db, {
        producerId: config.producerId.value(), routeProvider: navigation, ...helpers})(request);
    },
    checkFinancial: helpers.checkFinancial,
    get keyId() { return ports().keyId; },
    sign: (ticket) => ports().sign(ticket),
    publicKey: (alias) => ports().publicKey(alias),
    package: (ticket, order, tx) => ports().package(ticket, order, tx),
    attest: (manifest) => ports().attest(manifest),
  });
}
module.exports = {createPickupRuntime};
