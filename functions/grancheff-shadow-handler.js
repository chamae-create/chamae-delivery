"use strict";
// Authenticated adapter around the ORIGINAL receiver. No export in index.js,
// no HTTP server started, and the original emulator-only guard is retained.
const {OAuth2Client} = require("google-auth-library");
const {receiveObservation} = require("./grancheff-stock-observation");

/** Verifies a Google-signed machine ID token, not a Firebase user ID token.
 * @param {string} token Private bearer token.
 * @param {string} audience Exact Cloud Run service origin.
 * @return {Promise<Object>} Verified claims.
 */
async function verifyGoogleMachine(token, audience) {
  const ticket = await new OAuth2Client().verifyIdToken({
    idToken: token,
    audience,
  });
  return ticket.getPayload();
}

/** Creates a non-exported, emulator-only authenticated observation adapter.
 * @param {Object} db Explicit local emulator Firestore.
 * @param {Object} config Approved identity/source and injected test adapters.
 * @return {Function} Handler returning sanitized status/body objects.
 */
function createAuthenticatedShadowHandler(db, config) {
  if (!config || process.env.FIRESTORE_EMULATOR_HOST !== "127.0.0.1:8341" ||
      process.env.GCLOUD_PROJECT !== "demo-chamae-maximo" ||
      db.projectId !== "demo-chamae-maximo") {
    throw Error("AUTHENTICATED_SHADOW_EMULATOR_ONLY");
  }
  const url = new URL(config.audience);
  if (url.protocol !== "https:" || !url.hostname.endsWith(".run.app") ||
      url.origin !== config.audience ||
      typeof config.machineEmail !== "string" ||
      !/^[a-z0-9_-]+@[a-z0-9-]+\.iam\.gserviceaccount\.com$/
          .test(config.machineEmail) ||
      !/^[0-9]{1,30}$/.test(config.machineSubject) ||
      !Number.isSafeInteger(config.maxReadAgeMs) || config.maxReadAgeMs < 1) {
    throw Error("EXPLICIT_MACHINE_IDENTITY_REQUIRED");
  }
  const verify = config.verifyToken || verifyGoogleMachine;
  const receive = config.receive || receiveObservation;
  const now = config.now || Date.now;
  return async (request) => {
    if (request.method !== "POST" ||
        Object.keys(request.query || {}).length !== 0 ||
        !/^application\/json(?:;|$)/i
            .test((request.headers || {})["content-type"] || "")) {
      return {status: 400, body: {code: "REQUEST_CONTRACT_REJECTED"}};
    }
    const authorization = (request.headers || {}).authorization || "";
    if (!/^Bearer [A-Za-z0-9_.-]+$/.test(authorization)) {
      return {status: 401, body: {code: "MACHINE_AUTH_REQUIRED"}};
    }
    let claims;
    try {
      claims = await verify(authorization.slice(7), config.audience);
    } catch (_) {
      return {status: 401, body: {code: "MACHINE_AUTH_REJECTED"}};
    }
    if (!claims || !["accounts.google.com", "https://accounts.google.com"]
        .includes(claims.iss) || claims.aud !== config.audience ||
        claims.email_verified !== true ||
        claims.email !== config.machineEmail ||
        claims.sub !== config.machineSubject ||
        !Number.isSafeInteger(claims.exp) || claims.exp * 1000 <= now()) {
      return {status: 403, body: {code: "MACHINE_NOT_AUTHORIZED"}};
    }
    try {
      if (!request.body || Buffer.byteLength(JSON.stringify(request.body)) >
          16384) {
        return {status: 400, body: {code: "OBSERVATION_BODY_REJECTED"}};
      }
      const ack = await receive(db, request.body, {
        sourceId: config.sourceId,
        storeId: config.storeId,
        nowMs: now(),
        maxReadAgeMs: config.maxReadAgeMs,
      });
      return {status: 200, body: ack};
    } catch (_) {
      // No token, UID, raw URL, error text or request body is logged.
      return {status: 409, body: {code: "OBSERVATION_REVIEW_REQUIRED"}};
    }
  };
}
module.exports = {createAuthenticatedShadowHandler};
