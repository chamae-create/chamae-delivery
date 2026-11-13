"use strict";
const {HttpsError} = require("firebase-functions/v2/https");
const {signTicket, validatePackage} = require("./courier-pickup");

// Providers are injected by the trusted server composition. No key file,
// generated route, demo package or credential fallback is ever selected here.
function createPickupPorts({privateKey, publicKey, packageProvider, secrets = [], keyId = "pickup-v2"}) {
  if (![privateKey, publicKey, packageProvider].every((p) => typeof p === "function")) {
    throw new TypeError("PICKUP_PROVIDERS_REQUIRED");
  }
  if (!/^[A-Za-z0-9_:-]{1,128}$/.test(keyId)) throw new TypeError("PICKUP_KEY_ID_INVALID");
  return Object.freeze({
    keyId, secrets,
    async sign(ticket) {
      const key = await privateKey(ticket.keyId);
      return signTicket(ticket, key);
    },
    async attest(data) {
      return require("./courier-package-attestation").signPackage(data, await privateKey(data.keyId));
    },
    async publicKey(keyId) {
      const key = await publicKey(keyId);
      if (key?.asymmetricKeyType !== "ed25519") {
        throw new HttpsError("failed-precondition", "PICKUP_PUBLIC_KEY_UNAVAILABLE");
      }
      return key;
    },
    async package(ticket, order, tx) {
      const bytes = await packageProvider(ticket, order, tx);
      if (!Buffer.isBuffer(bytes) || bytes.length < 1 || bytes.length > 2 * 1024 * 1024) {
        throw new HttpsError("failed-precondition", "PICKUP_PACKAGE_UNAVAILABLE");
      }
      validatePackage(bytes, ticket);
      return bytes;
    },
  });
}

// Secret values are resolved only inside a callable provider invocation.
// The package provider remains explicit: no synthetic route or package fallback.
function createSecretPickupPorts({keySecret, packageProvider, keyId = "pickup-v2"}) {
  if (!keySecret || typeof keySecret.value !== "function" || typeof packageProvider !== "function") {
    throw new TypeError("PICKUP_PROVIDERS_REQUIRED");
  }
  const {createPrivateKey, createPublicKey} = require("node:crypto");
  function signingKey(requestedKeyId) {
    if (requestedKeyId !== keyId) throw new HttpsError("failed-precondition", "PICKUP_KEY_ID_UNAVAILABLE");
    try {
      const key = createPrivateKey(keySecret.value());
      if (key.asymmetricKeyType !== "ed25519") throw Error();
      return key;
    } catch (_) {
      throw new HttpsError("failed-precondition", "PICKUP_SIGNER_UNAVAILABLE");
    }
  }
  return createPickupPorts({secrets: [keySecret], packageProvider, keyId,
    privateKey: async (id) => signingKey(id),
    publicKey: async (id) => createPublicKey(signingKey(id))});
}
module.exports = {createPickupPorts, createSecretPickupPorts};

