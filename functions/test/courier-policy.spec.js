const {test} = require("node:test");
const assert = require("node:assert/strict");
const {createHash} = require("node:crypto");
const {courierPolicyFixture} = require("./courier-policy-fixture");
const {acceptDocuments, validPolicy, policyFingerprint, assertCurrentCourierAcceptance,
  createCourierPolicyFunctions} = require("../courier-policy");
const {ownProfile, reviewCourier, courierOperation} = require("../courier-approval");
const {requireApprovedCourier} = require("../courier-authorization");
function memory() {
  const docs = new Map([["courierPolicies/current", courierPolicyFixture()]]);
  const snap = (path) => ({exists: docs.has(path), data: () => docs.get(path)});
  const ref = (path) => ({path, get: async () => snap(path)});
  const db = {collection: (name) => ({doc: (id = "generated-audit") => ref(name + "/" + id)}), doc: ref,
    runTransaction: async (fn) => {
      const writes = [];
      const result = await fn({get: async (r) => {
        assert.equal(writes.length, 0, "all transaction reads must precede writes"); return snap(r.path);
      }, set: (r, data) => writes.push([r.path, data]), create: (r, data) => {
        assert.equal(docs.has(r.path), false); writes.push([r.path, data]);
      }, update: (r, data) => writes.push([r.path, {...docs.get(r.path), ...data}])});
      for (const [path, data] of writes) docs.set(path, data);
      return result;
    }};
  return {db, docs};
}
const identity = (verified = true) => ({uid: "rider", token: {email_verified: verified,
  firebase: {sign_in_provider: "password"}}});
const request = (policy = courierPolicyFixture(), auth = identity()) => ({auth, data: {
  policyRevision: policy.revision, policyHash: policy.contentHash, termsVersion: policy.termsVersion,
  privacyVersion: policy.privacyVersion, acceptTerms: true, acknowledgePrivacy: true}});
const approved = {role: "courier", approvalStatus: "approved", administrativeState: "active", enabled: true};
test("courier policy hash uses the exact ordered UTF-8 schema", () => {
  const policy = courierPolicyFixture();
  const keys = ["revision", "termsVersion", "privacyVersion", "termsText", "privacyText", "termsUrl", "privacyUrl"];
  assert.equal(policyFingerprint(policy), createHash("sha256").update(JSON.stringify(
      keys.map((key) => [key, policy[key]]))).digest("hex"));
  for (const patch of [{draft: true}, {published: false}, {termsText: "MUTATED"},
    {termsUrl: "http://example.test/terms"}, {termsVersion: "draft-1"}]) {
    assert.throws(() => validPolicy({...policy, ...patch}));
  }
});
test("auth-owned acceptance is private, timestamped, idempotent and audited once per material policy", async () => {
  const {db, docs} = memory();
  const firstResult = await acceptDocuments(db, request());
  assert.equal(firstResult.accepted, true); assert.equal(firstResult.policyHash, courierPolicyFixture().contentHash);
  const first = docs.get("courierPolicyAcceptances/rider");
  assert.ok(first.acceptedAt); assert.ok(first.firstAcceptedAt);
  await acceptDocuments(db, request()); assert.equal(docs.get("courierPolicyAcceptances/rider"), first);
  assert.equal([...docs.keys()].filter((path) => path.startsWith("courierConsentEvents/")).length, 1);
  const next = courierPolicyFixture({revision: "TEST-ONLY-2", termsText: "REVISED TEST FIXTURE"});
  docs.set("courierPolicies/current", next);
  await assert.rejects(db.runTransaction((tx) => assertCurrentCourierAcceptance(db, "rider", tx)),
      (error) => error.details.reason === "COURIER_POLICY_ACCEPTANCE_REQUIRED");
  await assert.rejects(acceptDocuments(db, request()));
  await acceptDocuments(db, request(next));
  assert.equal([...docs.keys()].filter((path) => path.startsWith("courierConsentEvents/")).length, 2);
  assert.equal(docs.get("courierPolicyAcceptances/rider").firstAcceptedAt, first.firstAcceptedAt);
});
test("missing, draft, stale and forged documents never grant consent", async () => {
  for (const value of [undefined, courierPolicyFixture({draft: true}), courierPolicyFixture({published: false})]) {
    const {db, docs} = memory(); if (value) docs.set("courierPolicies/current", value);
    else docs.delete("courierPolicies/current");
    await assert.rejects(acceptDocuments(db, request()));
    assert.equal(docs.has("courierPolicyAcceptances/rider"), false);
  }
  const {db} = memory();
  for (const patch of [{acceptTerms: false}, {acknowledgePrivacy: false}, {uid: "other"}, {policyHash: "forged"}]) {
    const req = request(); req.data = {...req.data, ...patch}; await assert.rejects(acceptDocuments(db, req));
  }
  for (const auth of [null, {uid: "rider", token: {}}, {uid: "rider", token: {
    firebase: {sign_in_provider: "anonymous"}}},
  {...identity(), token: {...identity().token, roles: ["superadmin"]}}]) {
    await assert.rejects(acceptDocuments(db, request(undefined, auth)));
  }
});
test("closing accounts cannot accept; unverified pending accounts can accept", async () => {
  const {db, docs} = memory();
  await acceptDocuments(db, request(undefined, identity(false)));
  docs.set("couriers/rider", {...approved, accountClosureStatus: "requested"});
  await assert.rejects(acceptDocuments(db, request()));
});
test("register/approve/ON enforce current consent; get/OFF survive policy change", async () => {
  const {db, docs} = memory(); const auth = identity();
  const fields = {name: "TEST RIDER", phone: "67000000000", profilePhoto: "fixture-photo"};
  docs.set("courierProfilePhotos/rider", {verified: true, reference: fields.profilePhoto});
  await assert.rejects(ownProfile(db, {auth, data: fields}, "register"));
  await acceptDocuments(db, request());
  assert.equal((await ownProfile(db, {auth, data: fields}, "register")).policyAcceptanceCurrent, true);
  const admin = {uid: "reviewer", token: {roles: ["superadmin"]}};
  const review = {auth: admin, data: {courierUid: "rider", action: "approve", expectedStatus: "pendingApproval"}};
  docs.set("courierPolicies/current", courierPolicyFixture({revision: "TEST-ONLY-2"}));
  await assert.rejects(reviewCourier(db, review));
  await acceptDocuments(db, request(docs.get("courierPolicies/current"))); await reviewCourier(db, review);
  await courierOperation(db, {auth, data: {operation: "availability", on: true}});
  docs.delete("courierPolicies/current");
  assert.equal((await ownProfile(db, {auth, data: {}})).policyAcceptanceCurrent, false);
  await assert.rejects(courierOperation(db, {auth, data: {operation: "availability", on: true}}));
  assert.deepEqual(await courierOperation(db, {auth, data: {operation: "availability", on: false}}), {online: false});
});
test("password operations require verified fresh token while identity-only F02 guard remains usable", async () => {
  const {db, docs} = memory(); docs.set("couriers/rider", approved);
  for (const flag of [false, undefined]) {
    const auth = identity(flag); if (flag === undefined) delete auth.token.email_verified;
    await assert.rejects(requireApprovedCourier(db, {auth}),
        (error) => error.details.reason === "EMAIL_VERIFICATION_REQUIRED");
  }
  assert.equal((await requireApprovedCourier(db, {auth: identity(true)})).uid, "rider");
  assert.equal((await ownProfile(db, {auth: identity(false), data: {}})).courierUid, "rider");
});
test("new callable stays in local region without external secrets", () => {
  const fn = createCourierPolicyFunctions({}).chamaeAceitarDocumentosMotoboy;
  assert.deepEqual(fn.__endpoint.region, ["southamerica-east1"]);
  assert.ok(fn.__endpoint.callableTrigger); assert.deepEqual(fn.__endpoint.secretEnvironmentVariables || [], []);
});


test("F03 ON and replay recheck current policy; OFF remains possible after policy change", async () => {
  const {submitCourierEvent} = require("../courier-events");
  const {db, docs} = memory(); docs.set("couriers/rider", approved);
  const make = (on) => {
    const event = {protocolVersion: 2, eventId: on ? "policy-on-event-00001" : "policy-off-event-0001",
      orderId: "shift", courierUid: "rider", type: "availability", localTimestampMs: Date.now(),
      sequence: on ? 1 : 2, payload: {on}};
    return {...event, fingerprint: createHash("sha256").update(JSON.stringify(event)).digest("hex")};
  };
  const original = make(true); const send = (data) => submitCourierEvent(db, {auth: identity(), data});
  await assert.rejects(send(original)); await acceptDocuments(db, request());
  const receipt = await send(original); assert.equal(receipt.availabilityOn, true);
  assert.deepEqual(await send(original), receipt);
  docs.set("courierPolicies/current", courierPolicyFixture({revision: "TEST-ONLY-2"}));
  await assert.rejects(send(original), (error) => error.details.reason === "COURIER_POLICY_ACCEPTANCE_REQUIRED");
  assert.equal((await send(make(false))).availabilityOn, false);
});
