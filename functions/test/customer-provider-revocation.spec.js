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
test("unconfigured Apple fails closed without claiming revocation", async () => {
  const f = fixture();
  await assert.rejects(ensureAppleRevoked(f.db, "buyer", job, user),
      (error) => error.details.reason === "APPLE_REVOCATION_NOT_CONFIGURED");
  assert.equal(f.documents.has("customerProviderRevocations/buyer"), false);
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
  await assert.rejects(ensureAppleRevoked(f.db, "buyer", next, user),
      (error) => error.details.reason === "APPLE_REVOCATION_NOT_CONFIGURED");
});
