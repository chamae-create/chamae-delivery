const {test} = require("node:test");
const assert = require("node:assert/strict");
const {verifiedCustomerToken} = require("../customer-identity");
const {policyFingerprint, validPolicy, birthDate, profileCurrent, acceptDocuments,
  prepareCustomerEligibility, checkProductEligibility, checkPurchase} = require("../customer-onboarding");
const {GoogleRoutesProvider} = require("../google-routes-provider");

// Synthetic documents, URLs, ages and coordinates belong to TESTS ONLY.
const policy = () => {
  const value = {published: true, draft: false, revision: "TEST-ONLY-1",
    termsVersion: "TEST-ONLY-1", privacyVersion: "TEST-ONLY-1", alcoholVersion: "TEST-ONLY-1",
    termsText: "TEST FIXTURE", privacyText: "TEST FIXTURE", alcoholNotice: "TEST FIXTURE",
    termsUrl: "https://example.test/terms", privacyUrl: "https://example.test/privacy",
    minimumAgeByCountry: {BR: 18, PY: 21}};
  value.contentHash = policyFingerprint(value); return value;
};
const auth = (provider = "google.com") => ({uid: "buyer", token: {firebase: {sign_in_provider: provider}}});
const request = (p = policy(), overrides = {}) => ({auth: auth(), data: {
  birthDate: "2000-01-01", termsVersion: p.termsVersion, privacyVersion: p.privacyVersion,
  alcoholVersion: p.alcoholVersion, policyRevision: p.revision, policyHash: p.contentHash,
  acceptTerms: true, acknowledgePrivacy: true, acknowledgeAlcohol: true, ...overrides,
}});
const memory = () => {
  const docs = new Map([["customerPolicies/current", policy()]]);
  const db = {collection: (name) => ({doc: (id) => ({path: `${name}/${id}`})}),
    runTransaction: async (fn) => {
      const writes = [];
      const result = await fn({get: async (ref) => {
        assert.equal(writes.length, 0, "all reads precede writes");
        return {exists: docs.has(ref.path), data: () => docs.get(ref.path)};
      }, set: (ref, value) => writes.push([ref.path, value])});
      for (const [path, value] of writes) docs.set(path, value);
      return result;
    }};
  return {db, docs};
};

test("trusted Firebase Google/Apple tokens accepted; anonymous/forged flags denied", () => {
  assert.equal(verifiedCustomerToken(auth().token), true);
  assert.equal(verifiedCustomerToken(auth("apple.com").token), true);
  assert.equal(verifiedCustomerToken({...auth("anonymous").token, customerVerified: true}), false);
  assert.equal(verifiedCustomerToken({google: true, apple: true}), false);
  assert.equal(verifiedCustomerToken({customerVerified: true}), false);
});
test("birth date checks calendar, leap year and future; date is not identity proof", () => {
  const now = new Date("2026-10-18T12:00:00Z");
  for (const value of ["2025-02-29", "2000-13-01", "2027-01-01", "18/10/2000", "1899-01-01"]) {
    assert.equal(birthDate(value, now), null);
  }
  assert.ok(birthDate("2000-02-29", now));
});
test("draft/unpublished/text mutation/HTTP URL policy cannot be accepted", () => {
  assert.equal(policyFingerprint(policy()), policyFingerprint({...policy(), minimumAgeByCountry: {PY: 21, BR: 18}}));
  for (const change of [{draft: true}, {published: false}, {termsVersion: "draft-2026-10-18"},
    {termsText: "MUTATED"}, {termsUrl: "http://example.test/terms"}]) {
    assert.throws(() => validPolicy({...policy(), ...change}));
  }
});
test("acceptance stores versions/time/audit, is idempotent and requires reacceptance", async () => {
  const {db, docs} = memory(); const req = request();
  await acceptDocuments(db, req);
  const first = docs.get("customerProfiles/buyer");
  assert.equal(first.dateOfBirthVerified, false); assert.ok(first.acceptedAt);
  assert.equal(first.termsVersion, "TEST-ONLY-1"); assert.equal(docs.size, 3);
  await acceptDocuments(db, req); assert.equal(docs.size, 3);
  const next = {...policy(), termsVersion: "TEST-ONLY-2", revision: "TEST-ONLY-2"};
  next.contentHash = policyFingerprint(next); docs.set("customerPolicies/current", next);
  assert.equal(profileCurrent(first, next), false);
  await assert.rejects(acceptDocuments(db, req));
  await acceptDocuments(db, request(next));
  assert.equal(docs.get("customerProfiles/buyer").termsVersion, "TEST-ONLY-2");
  assert.equal(docs.size, 4);
});
test("minimal bootstrap profile can accept consent without fabricating prior consent", async () => {
  const {db, docs} = memory();
  docs.set("customerProfiles/buyer", {createdAt: new Date()});
  await acceptDocuments(db, request());
  const profile = docs.get("customerProfiles/buyer");
  assert.equal(profile.birthDate, "2000-01-01");
  assert.ok(profile.firstAcceptedAt);
  assert.equal(profileCurrent(profile, policy()), true);
  await assert.rejects(acceptDocuments(db, request(policy(), {birthDate: "1999-01-01"})));
});

test("consent cannot be used to alter DOB or let courier/anonymous/admin self-enroll", async () => {
  const {db, docs} = memory(); await acceptDocuments(db, request());
  await assert.rejects(acceptDocuments(db, request(policy(), {birthDate: "1999-01-01"})));
  await assert.rejects(acceptDocuments(db, {...request(), auth: auth("anonymous")}));
  await assert.rejects(acceptDocuments(db, {...request(),
    auth: {...auth(), token: {...auth().token, roles: ["finance"]}}}));
  docs.set("couriers/buyer", {administrativeState: "active"});
  await assert.rejects(acceptDocuments(db, request()));
});
test("country policy gates restricted products; unknown policy fails closed", () => {
  const now = new Date("2026-10-18T12:00:00Z");
  const context = {policy: policy(), profile: {birthDate: "2006-10-18"}, country: "BR"};
  checkProductEligibility(context, {category: "Cervejas"}, now);
  assert.equal(context.documentRequiredAtDelivery, true);
  context.country = "PY";
  assert.throws(() => checkProductEligibility(context, {isAlcoholic: true}, now));
  context.policy.minimumAgeByCountry = {};
  assert.throws(() => checkProductEligibility(context, {requiresAgeCheck: true}, now));
  checkProductEligibility(context, {category: "Gelo"}, now);
});
test("new purchase requires current consent; legacy orders remain compatible", async () => {
  const {db, docs} = memory();
  await db.runTransaction(async (tx) => {
    assert.equal(await prepareCustomerEligibility(tx, db, {customerUid: "buyer"}), null);
    await assert.rejects(prepareCustomerEligibility(tx, db, {customerFlowVersion: 2,
      customerUid: "buyer", deliveryAddress: {countryCode: "BR"}}));
  });
  await acceptDocuments(db, request());
  docs.set("products/p1", {category: "Gelo"});
  assert.equal((await checkPurchase(db, {auth: auth(), data: {countryCode: "PY", productIds: ["p1"]}})).eligible, true);
  await assert.rejects(checkPurchase(db, {auth: auth(), data: {countryCode: "US", productIds: ["p1"]}}));
});
test("Google Routes server adapter uses field mask and real distance; no fallback", async () => {
  const args = {origin: {latitude: -20, longitude: -50}, destination: {latitude: -20.1, longitude: -50.1}};
  let sent;
  const route = new GoogleRoutesProvider({apiKey: "TEST-NOT-A-REAL-KEY", travelMode: "DRIVE",
    fetchImpl: async (url, init) => {
      sent = {url, init}; return {ok: true, json: async () => ({routes: [{distanceMeters: 1234, duration: "234.5s"}]})};
    }});
  const result = await route.route(args);
  assert.equal(result.distanceMeters, 1234); assert.equal(result.durationSeconds, 234.5);
  assert.equal(sent.init.headers["X-Goog-Api-Key"], "TEST-NOT-A-REAL-KEY");
  assert.match(sent.init.headers["X-Goog-FieldMask"], /routes.distanceMeters/);
  assert.equal(JSON.parse(sent.init.body).origin.location.latLng.latitude, -20);
  for (const data of [{routes: []}, {routes: [{distanceMeters: 1}], fallbackInfo: {}},
    {routes: [{distanceMeters: -1}]}]) {
    route.fetchImpl = async () => ({ok: true, json: async () => data});
    await assert.rejects(route.route(args), /ROUTE_UNAVAILABLE/);
  }
  await assert.rejects(new GoogleRoutesProvider({}).route(args), /NOT_CONFIGURED/);
});
