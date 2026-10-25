const {before, after, test} = require("node:test");
const assert = require("node:assert/strict");
const {readFileSync} = require("node:fs");
const {join} = require("node:path");
const {initializeApp, deleteApp} = require("firebase-admin/app");
const {getFirestore} = require("firebase-admin/firestore");
const {getAuth} = require("firebase-admin/auth");
const {initializeTestEnvironment, assertFails, assertSucceeds} = require("@firebase/rules-unit-testing");
const {doc, getDoc, setDoc} = require("firebase/firestore");
const {requestClosure, processClosure} = require("../customer-account");
const {acceptDocuments} = require("../customer-onboarding");
let app; let db; let auth; let env;
const request = (uid, provider = "google.com", patch = {}) => ({auth: {uid, token: {
  firebase: {sign_in_provider: provider}, auth_time: Date.now() / 1000,
}}, data: {confirmation: "EXCLUIR MINHA CONTA", expectedUid: uid, requestId: `request-${uid}-123456789`, ...patch}});
const read = async (path) => (await db.doc(path).get()).data();
const job = (uid) => read(`customerAccountClosures/${uid}`);
const account = (uid) => ({getUser: async () => ({...await auth.getUser(uid),
  providerData: [{providerId: "google.com", uid: "TEST_GOOGLE_SUBJECT"},
    {providerId: "apple.com", uid: `TEST_APPLE_${uid}`}]}), deleteUser: (id) => auth.deleteUser(id)});
const confirmed = () => ({revokeApple: async ({subject}) => ({revoked: true, subject})});
async function seed(uid) {
  await auth.createUser({uid, email: `${uid}@example.test`});
  await db.doc(`customerProfiles/${uid}`).set({birthDate: "2000-01-01", personal: "TEST_PII"});
  await db.doc(`customerWorkspaces/${uid}`).set({cart: [], addresses: [{street: "TEST_PII"}]});
  await db.doc(`orders/${uid}`).set({customerUid: uid, customerName: "TEST_PERSON", address: "TEST_ADDRESS",
    status: "Concluído", paymentStatus: "Pago", totalBRL: 12.34, deliveryFee: 2,
    itemsList: [{id: "TEST_PRODUCT", quantity: 1}], stockReservationStatus: "finalized"});
}
before(async () => {
  assert.equal(process.env.FIRESTORE_EMULATOR_HOST, "127.0.0.1:8187");
  assert.equal(process.env.FIREBASE_AUTH_EMULATOR_HOST, "127.0.0.1:9099");
  env = await initializeTestEnvironment({projectId: "demo-chamae-rules", firestore: {host: "127.0.0.1", port: 8187,
    rules: readFileSync(join(__dirname, "../../firestore.rules"), "utf8")}}); await env.clearFirestore();
  app = initializeApp({projectId: "demo-chamae-rules"}); db = getFirestore(app); auth = getAuth(app);
});
after(async () => {
  if (env) await env.cleanup(); if (db) await db.terminate(); if (app) await deleteApp(app);
});
test("Google deletion: old token cannot recreate PII or read historical orders", async () => {
  const uid = "kb06-google"; await seed(uid);
  const client = env.authenticatedContext(uid, {firebase: {sign_in_provider: "google.com"}}).firestore();
  await assertSucceeds(getDoc(doc(client, `customerProfiles/${uid}`)));
  await requestClosure(db, request(uid)); await processClosure(db, auth, uid);
  assert.equal((await job(uid)).status, "completed"); await assert.rejects(auth.getUser(uid));
  await assertFails(setDoc(doc(client, `customerWorkspaces/${uid}`), {cart: [], addresses: []}));
  await assertFails(getDoc(doc(client, `orders/${uid}`)));
  assert.equal((await read(`orders/${uid}`)).totalBRL, 12.34);
  assert.equal((await read(`orders/${uid}`)).address, undefined);
  await requestClosure(db, request(uid)); await processClosure(db, auth, uid);
  assert.equal((await job(uid)).status, "completed");
});
for (const provider of ["apple.com", "google.com"]) {
  test(`${provider} + Apple linked: unconfigured revocation blocks before PII/Auth deletion`, async () => {
    const uid = `kb06-unconfigured-${provider.split(".")[0]}`; await seed(uid);
    await requestClosure(db, request(uid, provider)); await processClosure(db, account(uid), uid);
    assert.equal((await job(uid)).reason, "APPLE_REVOCATION_NOT_CONFIGURED");
    assert.equal((await job(uid)).status, "blocked"); assert.ok(await auth.getUser(uid));
    assert.equal((await read(`customerProfiles/${uid}`)).personal, "TEST_PII");
    assert.equal((await read(`orders/${uid}`)).address, "TEST_ADDRESS");
    assert.equal((await db.doc(`customerProviderRevocations/${uid}`).get()).exists, false);
  });
}
test("simulated Apple revocation precedes erase; retry reuses server receipt after delete failure", async () => {
  const uid = "kb06-apple-retry"; await seed(uid); let calls = 0;
  const services = {revokeApple: async ({subject}) => {
    calls++; assert.ok(await auth.getUser(uid));
    assert.equal((await read(`customerProfiles/${uid}`)).personal, "TEST_PII");
    return {revoked: true, subject};
  }};
  await requestClosure(db, request(uid, "apple.com"));
  const broken = {...account(uid), deleteUser: async () => {
    throw new Error("TRANSIENT_DELETE");
  }};
  await assert.rejects(processClosure(db, broken, uid, services), /TRANSIENT_DELETE/);
  assert.equal((await job(uid)).status, "processing");
  await processClosure(db, account(uid), uid, services); await processClosure(db, account(uid), uid, services);
  assert.equal(calls, 1); assert.equal((await job(uid)).status, "completed");
  const receipt = await read(`customerProviderRevocations/${uid}`);
  assert.equal(receipt.status, "revoked"); assert.ok(!JSON.stringify(receipt).includes("TEST_APPLE_"));
  assert.equal((await read(`orders/${uid}`)).paymentStatus, "Pago");
});
test("provider error is sanitized, blocks removal, and a new authorized retry can complete", async () => {
  const uid = "kb06-apple-failed"; await seed(uid);
  await requestClosure(db, request(uid, "apple.com"));
  await processClosure(db, account(uid), uid, {revokeApple: async () => {
    throw new Error("SECRET_CODE_TOKEN");
  }});
  assert.equal((await job(uid)).reason, "APPLE_REVOCATION_FAILED");
  assert.ok(!JSON.stringify(await job(uid)).includes("SECRET_CODE_TOKEN"));
  assert.equal((await read(`customerProfiles/${uid}`)).personal, "TEST_PII");
  await requestClosure(db, request(uid, "apple.com")); await processClosure(db, account(uid), uid, confirmed());
  assert.equal((await job(uid)).status, "completed");
});
test("mismatched subject cannot authorize revocation/deletion", async () => {
  const uid = "kb06-wrong-subject"; await seed(uid); await requestClosure(db, request(uid, "apple.com"));
  await processClosure(db, account(uid), uid, {revokeApple: async () => ({revoked: true, subject: "OTHER"})});
  assert.equal((await job(uid)).reason, "APPLE_REVOCATION_UNCONFIRMED");
  assert.ok(await auth.getUser(uid)); assert.equal((await read(`orders/${uid}`)).customerUid, uid);
});
test("trusted Apple token without verified subject or server receipt remains blocked", async () => {
  const uid = "kb06-missing-subject"; await seed(uid); await requestClosure(db, request(uid, "apple.com"));
  await processClosure(db, auth, uid, confirmed());
  assert.equal((await job(uid)).reason, "APPLE_REVOCATION_IDENTITY_UNVERIFIED");
  assert.ok(await auth.getUser(uid));
});
test("active order blocks before attempting provider revocation", async () => {
  const uid = "kb06-active"; await seed(uid);
  await requestClosure(db, request(uid, "apple.com")); await db.doc(`orders/${uid}`).update({status: "Novo"});
  await processClosure(db, account(uid), uid, {revokeApple: () => assert.fail("must preflight before provider")});
  assert.equal((await job(uid)).reason, "ACTIVE_ORDER"); assert.ok(await auth.getUser(uid));
});
test("foreign UID, privileged/anonymous account and forged provider flags cannot enter customer deletion", async () => {
  for (const authValue of [request("buyer").auth, {...request("buyer").auth, token: {roles: ["superadmin"],
    firebase: {sign_in_provider: "google.com"}}}, {uid: "buyer", token: {customerVerified: true,
    firebase: {sign_in_provider: "anonymous"}}}]) {
    await assert.rejects(requestClosure(db, {...request("other"), auth: authValue}));
  }
  for (const roles of [["superadmin"], ["operations_admin"], ["finance"]]) {
    const req = request("admin"); req.auth.token.roles = roles;
    await assert.rejects(requestClosure(db, req), {code: "permission-denied"});
    await assert.rejects(acceptDocuments(db, req), {code: "permission-denied"});
  }
  await assert.rejects(requestClosure(db, request("buyer", "apple.com", {appleRevoked: true})),
      {code: "invalid-argument"});
});
test("provider receipts stay private/unforgeable for owner, stranger and administrators", async () => {
  const uid = "kb06-receipt-private"; await seed(uid); await requestClosure(db, request(uid, "apple.com"));
  await processClosure(db, account(uid), uid, confirmed());
  for (const [reader, roles] of [[uid, []], ["stranger", []], ["admin", ["superadmin"]]]) {
    const client = env.authenticatedContext(reader, {roles, firebase: {sign_in_provider: "google.com"}}).firestore();
    await assertFails(getDoc(doc(client, `customerProviderRevocations/${uid}`)));
    await assertFails(setDoc(doc(client, `customerProviderRevocations/${uid}`), {status: "revoked"}));
  }
  const stranger = env.authenticatedContext("stranger").firestore();
  await assertFails(getDoc(doc(stranger, `customerAccountClosures/${uid}`)));
});
test("late revocation cannot overwrite or authorize a newer closure request", async () => {
  const uid = "kb06-late-revocation"; await seed(uid); await requestClosure(db, request(uid, "apple.com"));
  let release; let entered;
  const waiting = new Promise((resolve) => {
    release = resolve;
  });
  const started = new Promise((resolve) => {
    entered = resolve;
  });
  const old = processClosure(db, account(uid), uid, {revokeApple: async ({subject}) => {
    entered(); await waiting; return {revoked: true, subject};
  }});
  await started;
  await db.doc(`customerAccountClosures/${uid}`).update({status: "blocked", reason: "TEST_INTERRUPTION"});
  await requestClosure(db, request(uid, "apple.com")); const next = await job(uid);
  release(); await old;
  assert.equal((await job(uid)).status, "requested");
  assert.ok((await job(uid)).requestedAt.isEqual(next.requestedAt));
  assert.equal((await db.doc(`customerProviderRevocations/${uid}`).get()).exists, false);
  assert.equal((await read(`customerProfiles/${uid}`)).personal, "TEST_PII");
  await processClosure(db, account(uid), uid, confirmed()); assert.equal((await job(uid)).status, "completed");
});
test("concurrent worker retries share a key with the idempotent simulated provider and one receipt", async () => {
  const uid = "kb06-concurrent"; await seed(uid); await requestClosure(db, request(uid, "apple.com"));
  const actions = new Map(); let effects = 0;
  const services = {revokeApple: async ({subject, idempotencyKey}) => {
    if (!actions.has(idempotencyKey)) {
      effects++; actions.set(idempotencyKey, {revoked: true, subject});
    }
    return actions.get(idempotencyKey);
  }};
  await Promise.all([processClosure(db, account(uid), uid, services), processClosure(db, account(uid), uid, services)]);
  assert.equal(effects, 1); assert.equal((await job(uid)).status, "completed");
  const receipt = await read(`customerProviderRevocations/${uid}`);
  await processClosure(db, account(uid), uid, services);
  assert.deepEqual(await read(`customerProviderRevocations/${uid}`), receipt);
});
