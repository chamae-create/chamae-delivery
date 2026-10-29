const {test} = require("node:test");
const assert = require("node:assert/strict");
const {tokenHasApple, ensureAppleRevoked} = require("../customer-provider-revocation");
const {requestClosure} = require("../customer-account");
const user = {providerData: [{providerId: "apple.com", uid: "TEST_APPLE_SUBJECT"}]};
const job = {requestId: "test-request-123456", status: "requested", requestedAt: {seconds: 1000, nanoseconds: 0}};
function fixture() {
  const documents = new Map();
  documents.set("customerAccountClosures/buyer", job);
  const db = {collection: (name) => ({doc: (uid) => ({path: `${name}/${uid}`,
    get: async () => ({exists: documents.has(`${name}/${uid}`), data: () => documents.get(`${name}/${uid}`)}),
    update: async (data) => documents.set(`${name}/${uid}`, {...documents.get(`${name}/${uid}`), ...data}),
    set: async (data) => documents.set(`${name}/${uid}`, data),
  })})};
  db.runTransaction = (fn) => fn({
    get: (ref) => ref.get(),
    update: (ref, fields) => ref.update(fields),
    set: (ref, fields) => ref.set(fields),
  });
  return {db, documents};
}
test("Apple requirement comes from verified provider/identities, including Google + Apple", () => {
  assert.equal(tokenHasApple({firebase: {sign_in_provider: "apple.com"}}), true);
  assert.equal(tokenHasApple({firebase: {sign_in_provider: "google.com",
    identities: {"apple.com": ["subject"]}}}), true);
  assert.equal(tokenHasApple({firebase: {sign_in_provider: "google.com"}}), false);
  assert.equal(tokenHasApple({}), false);
});
test("Google-only worker has no provider IO", async () => {
  await ensureAppleRevoked({collection: () => assert.fail("no provider data needed")}, "buyer", job,
      {providerData: [{providerId: "google.com", uid: "TEST_GOOGLE"}]});
});
test("legacy Apple credential absence records manual outcome without claiming revocation", async () => {
  const f = fixture();
  const result = await ensureAppleRevoked(f.db, "buyer", job, user);
  assert.equal(result.status, "manual_required");
  assert.equal(result.reason, "LEGACY_CREDENTIAL_MISSING");
  assert.equal(result.completedAt, undefined);
  assert.equal(f.documents.get("customerProviderRevocations/buyer").status, "manual_required");
});
test("provider failure and unbound/incomplete proof never persist a successful receipt or raw errors", async () => {
  for (const revokeApple of [async () => {
    throw new Error("SECRET_TOKEN_CODE_MUST_NOT_LEAK");
  },
  async () => ({revoked: true, subject: "different-subject"}), async () => ({revoked: false})]) {
    const f = fixture();
    await assert.rejects(ensureAppleRevoked(f.db, "buyer", job, user, {revokeApple}), (error) => {
      assert.ok(!JSON.stringify(error).includes("SECRET_TOKEN_CODE"));
      return /^APPLE_REVOCATION_/.test(error.details.reason);
    });
    assert.equal(f.documents.has("customerProviderRevocations/buyer"), false);
  }
});
test("server confirmation is scoped to subject/request and sequential retry does not revoke twice", async () => {
  const f = fixture(); let calls = 0;
  const services = {revokeApple: async ({subject, idempotencyKey}) => {
    calls++; assert.match(idempotencyKey, /^[a-f0-9]{64}$/); return {revoked: true, subject};
  }};
  await ensureAppleRevoked(f.db, "buyer", job, user, services);
  await ensureAppleRevoked(f.db, "buyer", job, user, services);
  assert.equal(calls, 1);
  const receipt = f.documents.get("customerProviderRevocations/buyer");
  assert.equal(receipt.status, "revoked"); assert.ok(!JSON.stringify(receipt).includes("TEST_APPLE_SUBJECT"));
  await assert.rejects(ensureAppleRevoked(f.db, "buyer", {...job, requestId: "other"}, user));
});
test("missing Apple identity cannot be fabricated; completed server proof can resume after Auth deletion", async () => {
  const f = fixture();
  await assert.rejects(ensureAppleRevoked(f.db, "buyer", {...job, requiresAppleRevocation: true}, null));
  await ensureAppleRevoked(f.db, "buyer", job, user, {revokeApple: async ({subject}) => ({revoked: true, subject})});
  const saved = f.documents.get("customerAccountClosures/buyer");
  await ensureAppleRevoked(f.db, "buyer", {...job, ...saved}, null);
});
test("client cannot provide a revocation flag, provider token, receipt or foreign identity", async () => {
  for (const extra of [{appleRevoked: true}, {authorizationCode: "TEST_ONLY"}, {accessToken: "TEST_ONLY"},
    {receipt: "forged"}, {expectedUid: "other"}]) {
    await assert.rejects(requestClosure({}, {auth: {uid: "buyer", token: {firebase: {sign_in_provider: "apple.com"}}},
      data: {confirmation: "EXCLUIR MINHA CONTA", expectedUid: "buyer", requestId: "request-123456789", ...extra}}),
    {code: "invalid-argument"});
  }
});
test("a new request timestamp requires new revocation evidence even when requestId is reused", async () => {
  const f = fixture();
  await ensureAppleRevoked(f.db, "buyer", job, user, {revokeApple: async ({subject}) => ({revoked: true, subject})});
  const next = {...job, requestedAt: {seconds: 1001, nanoseconds: 0}};
  f.documents.set("customerAccountClosures/buyer", next);
  const previous = f.documents.get("customerProviderRevocations/buyer");
  const outcome = await ensureAppleRevoked(f.db, "buyer", next, user);
  assert.equal(outcome.status, "manual_required");
  assert.notEqual(outcome.fingerprint, previous.fingerprint);
});

const {createAppleCredentialStore, createAppleRevocationServices, AppleRevocationError} =
  require("../apple-revocation-adapter");
const config = {clientSecrets: JSON.stringify({"test.client": "SYNTHETIC_CLIENT_SECRET"}),
  encryptionKey: "12".repeat(32)};
async function adapterFixture(response = {status: 200}) {
  const f = fixture(); const calls = [];
  f.documents.delete("customerAccountClosures/buyer");
  const store = createAppleCredentialStore(f.db, () => config);
  await store.saveVerified("buyer", user.providerData[0].uid,
      {clientId: "test.client", tokenType: "refresh_token", token: "SYNTHETIC_APPLE_TOKEN"});
  f.documents.set("customerAccountClosures/buyer", job);
  const services = createAppleRevocationServices(f.db, {store, getConfig: () => config,
    fetch: async (url, options) => {
      calls.push({url, options}); return response;
    }});
  return {...f, store, calls, services};
}

test("official adapter posts a bound credential to Apple's fixed revoke endpoint and persists no secret", async () => {
  const f = await adapterFixture();
  const result = await ensureAppleRevoked(f.db, "buyer", job, user, f.services);
  assert.equal(result.status, "revoked"); assert.equal(result.evidence, "apple_http_200");
  assert.equal(f.calls.length, 1);
  assert.equal(f.calls[0].url, "https://appleid.apple.com/auth/revoke");
  const request = f.calls[0].options;
  assert.equal(request.redirect, "error"); assert.equal(request.method, "POST");
  const body = new URLSearchParams(request.body);
  assert.equal(body.get("client_id"), "test.client");
  assert.equal(body.get("token_type_hint"), "refresh_token");
  assert.equal(body.get("token"), "SYNTHETIC_APPLE_TOKEN");
  const persisted = JSON.stringify([...f.documents.values()]);
  assert.ok(!persisted.includes("SYNTHETIC_APPLE_TOKEN"));
  assert.ok(!persisted.includes("SYNTHETIC_CLIENT_SECRET"));
  await ensureAppleRevoked(f.db, "buyer", job, user, f.services);
  assert.equal(f.calls.length, 1);
});

test("previously invalidated Apple token: documented HTTP 200 remains an idempotent confirmation", async () => {
  const f = await adapterFixture();
  const recreated = createAppleRevocationServices(f.db, {getConfig: () => config,
    fetch: async () => ({status: 200})});
  assert.equal((await ensureAppleRevoked(f.db, "buyer", job, user, recreated)).status, "revoked");
});

test("expired or unusable credential is manual, never a fabricated successful revocation", async () => {
  for (const error of ["invalid_token", "invalid_grant"]) {
    const f = await adapterFixture({status: 400, json: async () => ({error})});
    const outcome = await ensureAppleRevoked(f.db, "buyer", job, user, f.services);
    assert.equal(outcome.status, "manual_required");
    assert.equal(outcome.reason, "APPLE_CREDENTIAL_UNUSABLE"); assert.equal(outcome.completedAt, undefined);
  }
});

test("temporary Apple errors are retryable, sanitized and have no successful receipt", async () => {
  for (const response of [{status: 503}, {status: 429}]) {
    const f = await adapterFixture(response);
    await assert.rejects(ensureAppleRevoked(f.db, "buyer", job, user, f.services),
        (e) => e.code === "unavailable" && e.details.reason === "APPLE_REVOCATION_RETRYABLE");
    assert.equal(f.documents.has("customerProviderRevocations/buyer"), false);
  }
  const f = await adapterFixture();
  const services = createAppleRevocationServices(f.db, {getConfig: () => config,
    fetch: async () => {
      throw new Error("SYNTHETIC_APPLE_TOKEN SYNTHETIC_CLIENT_SECRET");
    }});
  await assert.rejects(ensureAppleRevoked(f.db, "buyer", job, user, services), (e) => {
    assert.ok(!JSON.stringify(e).includes("SYNTHETIC_"));
    return e.details.reason === "APPLE_REVOCATION_RETRYABLE";
  });
});

test("missing configuration with an existing credential requires review, not legacy fallback", async () => {
  const f = await adapterFixture();
  const services = createAppleRevocationServices(f.db, {getConfig: () => ({}),
    fetch: () => assert.fail("no network with missing encryption configuration")});
  await assert.rejects(ensureAppleRevoked(f.db, "buyer", job, user, services),
      (e) => e.details.reason === "APPLE_REVOCATION_CONFIGURATION_REQUIRED");
  assert.equal(f.documents.has("customerProviderRevocations/buyer"), false);
});

test("vault read outage cannot masquerade as a legacy account", async () => {
  const f = fixture();
  const services = createAppleRevocationServices(f.db, {store: {
    load: async () => {
      throw new Error("SYNTHETIC_SECRET_DATABASE_FAILURE");
    },
  }, fetch: () => assert.fail("unreadable vault")});
  await assert.rejects(ensureAppleRevoked(f.db, "buyer", job, user, services),
      (e) => e.details.reason === "APPLE_REVOCATION_RETRYABLE");
});

test("encrypted credential cannot be moved between UID, Apple subject or OAuth client", async () => {
  const f = await adapterFixture();
  const record = f.documents.get("customerAppleCredentials/buyer");
  f.documents.set("customerAppleCredentials/other", record);
  await assert.rejects(f.store.load("other", user.providerData[0].uid), AppleRevocationError);
  await assert.rejects(f.store.load("buyer", "OTHER_APPLE_SUBJECT"), AppleRevocationError);
  f.documents.set("customerAppleCredentials/buyer", {...record, clientId: "another.client"});
  await assert.rejects(f.store.load("buyer", user.providerData[0].uid), AppleRevocationError);
});

test("invalid Apple client configuration never becomes a revocation receipt", async () => {
  const f = await adapterFixture({status: 400, json: async () => ({error: "invalid_client",
    debug: "SYNTHETIC_SECRET"})});
  await assert.rejects(ensureAppleRevoked(f.db, "buyer", job, user, f.services), (e) => {
    assert.ok(!JSON.stringify(e).includes("SYNTHETIC_SECRET"));
    return e.details.reason === "APPLE_REVOCATION_CONFIGURATION_REQUIRED";
  });
});

const {generateKeyPairSync, sign} = require("node:crypto");
const {acquireAppleCredential} = require("../apple-revocation-adapter");
const testKeys = generateKeyPairSync("rsa", {modulusLength: 2048});
const jwk = {...testKeys.publicKey.export({format: "jwk"}), kid: "TEST_ONLY", alg: "RS256", use: "sig"};
function appleIdToken(patch = {}, otherKey = testKeys.privateKey) {
  const head = Buffer.from(JSON.stringify({alg: "RS256", kid: "TEST_ONLY"})).toString("base64url");
  const body = Buffer.from(JSON.stringify({iss: "https://appleid.apple.com", aud: "test.client",
    sub: user.providerData[0].uid, nonce: "SYNTHETIC_SERVER_NONCE", iat: Math.floor(Date.now() / 1000),
    exp: Math.floor(Date.now() / 1000) + 300, ...patch})).toString("base64url");
  return `${head}.${body}.${sign("RSA-SHA256", Buffer.from(`${head}.${body}`), otherKey).toString("base64url")}`;
}
function acquisitionOptions(idToken) {
  return {getConfig: () => config, fetch: async (url) => {
    if (url.endsWith("/auth/keys")) return {status: 200, json: async () => ({keys: [jwk]})};
    assert.equal(url, "https://appleid.apple.com/auth/token");
    return {status: 200, json: async () => ({id_token: idToken, refresh_token: "SYNTHETIC_ACQUIRED_TOKEN"})};
  }};
}
const acquisition = {uid: "buyer", clientId: "test.client", authorizationCode: "SYNTHETIC_CODE",
  expectedNonce: "SYNTHETIC_SERVER_NONCE"};
const verifiedAccount = {getUser: async () => ({uid: "buyer", ...user})};

test("code exchange verifies Apple signature, nonce, audience and Admin SDK subject", async () => {
  const f = fixture();
  f.documents.delete("customerAccountClosures/buyer");
  assert.deepEqual(await acquireAppleCredential(f.db, verifiedAccount, acquisition,
      acquisitionOptions(appleIdToken())), {stored: true});
  const loaded = await createAppleCredentialStore(f.db, () => config).load("buyer", user.providerData[0].uid);
  assert.equal(loaded.token, "SYNTHETIC_ACQUIRED_TOKEN");
  assert.ok(!JSON.stringify([...f.documents.values()]).includes("SYNTHETIC_ACQUIRED_TOKEN"));
});

test("code exchange rejects a foreign subject, wrong audience/nonce, expired token and invalid signature", async () => {
  const another = generateKeyPairSync("rsa", {modulusLength: 2048});
  for (const token of [appleIdToken({sub: "FOREIGN_SUBJECT"}), appleIdToken({aud: "wrong.client"}),
    appleIdToken({nonce: "wrong-nonce"}), appleIdToken({exp: 1}), appleIdToken({}, another.privateKey)]) {
    const f = fixture();
    await assert.rejects(acquireAppleCredential(f.db, verifiedAccount, acquisition, acquisitionOptions(token)),
        (e) => e.reason === "APPLE_REVOCATION_IDENTITY_UNVERIFIED");
    assert.equal(f.documents.has("customerAppleCredentials/buyer"), false);
  }
});

test("code acquisition never logs or persists an expired authorization code or raw provider error", async () => {
  const f = fixture();
  await assert.rejects(acquireAppleCredential(f.db, verifiedAccount, acquisition, {getConfig: () => config,
    fetch: async () => ({status: 400, json: async () => ({error: "invalid_grant", code: "SYNTHETIC_CODE"})})}),
  (e) => e.reason === "APPLE_REVOCATION_NEW_AUTH_REQUIRED" && !JSON.stringify(e).includes("SYNTHETIC_CODE"));
  assert.equal(f.documents.has("customerAppleCredentials/buyer"), false);
});

test("acquisition cannot recreate provider credentials while account erasure is running or completed", async () => {
  for (const status of ["requested", "processing", "completed"]) {
    const f = fixture(); f.documents.set("customerAccountClosures/buyer", {...job, status});
    await assert.rejects(acquireAppleCredential(f.db, verifiedAccount, acquisition,
        acquisitionOptions(appleIdToken())), (e) => e.reason === "APPLE_REVOCATION_REQUEST_CHANGED");
    assert.equal(f.documents.has("customerAppleCredentials/buyer"), false);
  }
});
