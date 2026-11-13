"use strict";
const {sign} = require("node:crypto");
const {HttpsError} = require("firebase-functions/v2/https");
const fields = ["version", "algorithm", "keyId", "orderId", "assignmentId", "courierUid",
  "packageVersion", "expiresAtMs", "sessionId", "digest", "length"];
function body(value) {
  return Buffer.from(JSON.stringify(["CHAMAE_PICKUP_PACKAGE_V1", ...fields.map((k) => value[k])]));
}
function signPackage(data, key) {
  if (key?.asymmetricKeyType !== "ed25519") throw new HttpsError("failed-precondition", "PICKUP_SIGNER_UNAVAILABLE");
  const value = {version: 1, algorithm: "Ed25519", ...data};
  return JSON.stringify({...value, signature: sign(null, body(value), key).toString("base64")});
}
module.exports = {body, signPackage};
