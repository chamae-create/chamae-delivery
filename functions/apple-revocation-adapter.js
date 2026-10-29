const {createCipheriv, createDecipheriv, randomBytes, createHash, createPublicKey, verify} = require("node:crypto");

const endpoint = "https://appleid.apple.com/auth/revoke";
const hash = (value) => createHash("sha256").update(value).digest("hex");
class AppleRevocationError extends Error {
  constructor(reason) {
    super("Apple authorization needs a safe retry or review.");
    this.reason = reason;
  }
}
const fail = (reason) => {
  throw new AppleRevocationError(reason);
};
const configuration = () => ({
  // Bind these Secret Manager resources to the worker. Never log their values.
  clientSecrets: process.env.CHAMAE_APPLE_CLIENT_SECRETS,
  encryptionKey: process.env.CHAMAE_APPLE_CREDENTIAL_KEY,
});
function key(config) {
  if (typeof config.encryptionKey !== "string" || !/^[a-f0-9]{64}$/i.test(config.encryptionKey)) {
    fail("APPLE_REVOCATION_CONFIGURATION_REQUIRED");
  }
  return Buffer.from(config.encryptionKey, "hex");
}
function binding(uid, subject, credential) {
  return JSON.stringify([uid, hash(subject), credential.clientId, credential.tokenType]);
}
function validateBinding(credential, uid, subject) {
  if (!credential || credential.schemaVersion !== 1 || credential.uid !== uid ||
      credential.subjectHash !== hash(subject) || typeof credential.clientId !== "string" ||
      !credential.clientId || !["access_token", "refresh_token"].includes(credential.tokenType) ||
      credential.identityVerified !== true) fail("APPLE_REVOCATION_CREDENTIAL_MISMATCH");
}

// Server-only vault. No callable accepts a raw token, verification flag or receipt.
// Ingestion MUST first verify Apple's identity/code response against Admin SDK providerData.
// That authorized acquisition integration is deliberately separate from account deletion.
function createAppleCredentialStore(db, getConfig = configuration) {
  const ref = (uid) => db.collection("customerAppleCredentials").doc(uid);
  return {
    async load(uid, subject) {
      const doc = await ref(uid).get();
      if (!doc.exists) return null; // Known absence, not a failed read/decryption/configuration.
      const record = doc.data();
      validateBinding(record, uid, subject);
      try {
        const decipher = createDecipheriv("aes-256-gcm", key(getConfig()), Buffer.from(record.iv, "base64"));
        decipher.setAAD(Buffer.from(binding(uid, subject, record)));
        decipher.setAuthTag(Buffer.from(record.tag, "base64"));
        const token = Buffer.concat([decipher.update(Buffer.from(record.ciphertext, "base64")),
          decipher.final()]).toString("utf8");
        if (!token || token.length > 16384) fail("APPLE_REVOCATION_CREDENTIAL_MISMATCH");
        return {token, clientId: record.clientId, tokenType: record.tokenType};
      } catch (error) {
        if (error instanceof AppleRevocationError) throw error;
        fail("APPLE_REVOCATION_CREDENTIAL_MISMATCH");
      }
    },
    async saveVerified(uid, subject, credential) {
      if (typeof uid !== "string" || !uid || uid.includes("/") || typeof subject !== "string" || !subject ||
          typeof credential.token !== "string" || !credential.token || credential.token.length > 16384) {
        fail("APPLE_REVOCATION_CREDENTIAL_MISMATCH");
      }
      const record = {schemaVersion: 1, uid, subjectHash: hash(subject), clientId: credential.clientId,
        tokenType: credential.tokenType, identityVerified: true};
      validateBinding(record, uid, subject);
      const iv = randomBytes(12);
      const cipher = createCipheriv("aes-256-gcm", key(getConfig()), iv);
      cipher.setAAD(Buffer.from(binding(uid, subject, record)));
      const ciphertext = Buffer.concat([cipher.update(credential.token, "utf8"), cipher.final()]);
      const encrypted = {...record, iv: iv.toString("base64"), tag: cipher.getAuthTag().toString("base64"),
        ciphertext: ciphertext.toString("base64")};
      await db.runTransaction(async (tx) => {
        const closure = await tx.get(db.collection("customerAccountClosures").doc(uid));
        if (closure.exists && closure.data().status !== "blocked") {
          fail("APPLE_REVOCATION_REQUEST_CHANGED");
        }
        tx.set(ref(uid), encrypted);
      });
    },
    async remove(uid) {
      await ref(uid).delete();
    },
  };
}
function clientSecret(config, clientId) {
  try {
    const secrets = JSON.parse(config.clientSecrets);
    const secret = secrets && Object.hasOwn(secrets, clientId) && secrets[clientId];
    if (typeof secret !== "string" || !secret || secret.length > 16384) {
      fail("APPLE_REVOCATION_CONFIGURATION_REQUIRED");
    }
    return secret;
  } catch (_) {
    fail("APPLE_REVOCATION_CONFIGURATION_REQUIRED");
  }
}
function createAppleRevocationAdapter({store, getConfig = configuration, fetch = global.fetch,
  timeoutMs = 10000}) {
  return async ({uid, subject}) => {
    let credential;
    try {
      credential = await store.load(uid, subject);
    } catch (error) {
      if (error instanceof AppleRevocationError) throw error;
      fail("APPLE_REVOCATION_RETRYABLE");
    }
    if (credential === null) {
      return {subject, status: "manual_required", reason: "LEGACY_CREDENTIAL_MISSING"};
    }
    const secret = clientSecret(getConfig(), credential.clientId);
    const controller = new AbortController();
    const timer = setTimeout(() => controller.abort(), timeoutMs);
    try {
      const response = await fetch(endpoint, {method: "POST", redirect: "error", signal: controller.signal,
        headers: {"content-type": "application/x-www-form-urlencoded"},
        body: new URLSearchParams({client_id: credential.clientId, client_secret: secret,
          token: credential.token, token_type_hint: credential.tokenType}).toString()});
      // Apple documents HTTP 200 for both revocation and previously invalidated tokens.
      if (response.status === 200) return {subject, revoked: true, evidence: "apple_http_200"};
      if (response.status === 429 || response.status >= 500) fail("APPLE_REVOCATION_RETRYABLE");
      let body;
      try {
        body = await response.json();
      } catch (_) {
        fail("APPLE_REVOCATION_FAILED");
      }
      if (response.status === 400 && ["invalid_token", "invalid_grant"].includes(body?.error)) {
        // Never call an error response proof of revocation. Fulfil deletion with manual guidance.
        return {subject, status: "manual_required", reason: "APPLE_CREDENTIAL_UNUSABLE"};
      }
      if (["invalid_client", "unauthorized_client"].includes(body?.error)) {
        fail("APPLE_REVOCATION_CONFIGURATION_REQUIRED");
      }
      fail("APPLE_REVOCATION_FAILED");
    } catch (error) {
      if (error instanceof AppleRevocationError) throw error;
      fail("APPLE_REVOCATION_RETRYABLE");
    } finally {
      clearTimeout(timer);
    }
  };
}
// Internal acquisition contract for an authorized Apple code callback, NOT a public callable.
// uid/nonce must come from the recent authenticated server flow, never an asserted provider receipt.
async function acquireAppleCredential(db, auth, {uid, clientId, authorizationCode, expectedNonce},
    {getConfig = configuration, fetch = global.fetch, timeoutMs = 10000} = {}) {
  if (typeof uid !== "string" || !uid || uid.includes("/") ||
      typeof authorizationCode !== "string" || !authorizationCode || authorizationCode.length > 2048 ||
      typeof expectedNonce !== "string" || expectedNonce.length < 16 || expectedNonce.length > 512) {
    fail("APPLE_REVOCATION_IDENTITY_UNVERIFIED");
  }
  const secret = clientSecret(getConfig(), clientId);
  const controller = new AbortController();
  const timer = setTimeout(() => controller.abort(), timeoutMs);
  try {
    const user = await auth.getUser(uid);
    const subject = user.providerData?.find((provider) => provider.providerId === "apple.com")?.uid;
    if (user.uid !== uid || !subject || user.customClaims?.roles?.length) {
      fail("APPLE_REVOCATION_IDENTITY_UNVERIFIED");
    }
    const response = await fetch("https://appleid.apple.com/auth/token", {
      method: "POST", redirect: "error", signal: controller.signal,
      headers: {"content-type": "application/x-www-form-urlencoded"},
      body: new URLSearchParams({client_id: clientId, client_secret: secret,
        code: authorizationCode, grant_type: "authorization_code"}).toString(),
    });
    if (response.status === 429 || response.status >= 500) fail("APPLE_REVOCATION_RETRYABLE");
    if (response.status !== 200) fail("APPLE_REVOCATION_NEW_AUTH_REQUIRED");
    const tokens = await response.json();
    if (typeof tokens.id_token !== "string" || tokens.id_token.length > 16384) {
      fail("APPLE_REVOCATION_IDENTITY_UNVERIFIED");
    }
    const parts = tokens.id_token.split(".");
    if (parts.length !== 3 || parts.some((part) => !/^[A-Za-z0-9_-]+$/.test(part))) {
      fail("APPLE_REVOCATION_IDENTITY_UNVERIFIED");
    }
    const header = JSON.parse(Buffer.from(parts[0], "base64url"));
    const claims = JSON.parse(Buffer.from(parts[1], "base64url"));
    if (header.alg !== "RS256" || typeof header.kid !== "string") fail("APPLE_REVOCATION_IDENTITY_UNVERIFIED");
    const keysResponse = await fetch("https://appleid.apple.com/auth/keys", {
      redirect: "error", signal: controller.signal,
    });
    if (keysResponse.status !== 200) fail("APPLE_REVOCATION_RETRYABLE");
    const keys = (await keysResponse.json()).keys;
    const jwk = Array.isArray(keys) && keys.find((item) => item.kid === header.kid &&
      item.kty === "RSA" && item.alg === "RS256" && item.use === "sig");
    const now = Date.now() / 1000;
    if (!jwk || !verify("RSA-SHA256", Buffer.from(`${parts[0]}.${parts[1]}`),
        createPublicKey({key: jwk, format: "jwk"}), Buffer.from(parts[2], "base64url")) ||
        claims.iss !== "https://appleid.apple.com" || claims.aud !== clientId || claims.sub !== subject ||
        claims.nonce !== expectedNonce || !Number.isFinite(claims.exp) || claims.exp <= now ||
        !Number.isFinite(claims.iat) || claims.iat > now + 60 || claims.exp <= claims.iat) {
      fail("APPLE_REVOCATION_IDENTITY_UNVERIFIED");
    }
    const tokenType = tokens.refresh_token ? "refresh_token" : "access_token";
    const token = tokens[tokenType];
    await createAppleCredentialStore(db, getConfig).saveVerified(uid, subject, {clientId, tokenType, token});
    return {stored: true}; // Never return provider tokens to the caller/client.
  } catch (error) {
    if (error instanceof AppleRevocationError) throw error;
    fail("APPLE_REVOCATION_RETRYABLE");
  } finally {
    clearTimeout(timer);
  }
}

function createAppleRevocationServices(db, options = {}) {
  const store = options.store || createAppleCredentialStore(db, options.getConfig);
  return {revokeApple: createAppleRevocationAdapter({...options, store}),
    disposeAppleCredential: (uid) => store.remove(uid)};
}
module.exports = {AppleRevocationError, acquireAppleCredential, createAppleCredentialStore,
  createAppleRevocationAdapter,
  createAppleRevocationServices};
