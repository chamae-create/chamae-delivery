const {before, after, test} = require("node:test");
const assert = require("node:assert/strict");
const {spawnSync} = require("node:child_process");
const {join} = require("node:path");
const {initializeApp, deleteApp} = require("firebase-admin/app");
const {getFirestore} = require("firebase-admin/firestore");
const {getAuth} = require("firebase-admin/auth");
const {requestClosure} = require("../customer-account");
const {createAppleCredentialStore} = require("../apple-revocation-adapter");
let app; let db; let auth;
before(() => {
  assert.equal(process.env.FIRESTORE_EMULATOR_HOST, "127.0.0.1:8187");
  assert.equal(process.env.FIREBASE_AUTH_EMULATOR_HOST, "127.0.0.1:9099");
  app = initializeApp({projectId: "demo-chamae-rules"}); db = getFirestore(app); auth = getAuth(app);
});
after(async () => {
  if (db) await db.terminate(); if (app) await deleteApp(app);
});
const childSource = String.raw`
const {initializeApp, deleteApp} = require("firebase-admin/app");
const {getFirestore} = require("firebase-admin/firestore");
const {getAuth} = require("firebase-admin/auth");
const {processClosure} = require("./customer-account");
const {createAppleRevocationServices} = require("./apple-revocation-adapter");
const uid = process.argv[1], phase = process.argv[2];
if (process.env.FIRESTORE_EMULATOR_HOST !== "127.0.0.1:8187" ||
    process.env.FIREBASE_AUTH_EMULATOR_HOST !== "127.0.0.1:9099") process.exit(90);
const app = initializeApp({projectId: "demo-chamae-rules"});
const db = getFirestore(app), auth = getAuth(app);
const account = {getUser: async (id) => ({...await auth.getUser(id),
  providerData: [{providerId: "apple.com", uid: "SYNTHETIC_RESTART_SUBJECT"}]}),
  deleteUser: async (id) => { if (phase === "interrupt") process.exit(42); await auth.deleteUser(id); }};
const services = phase === "interrupt" ? createAppleRevocationServices(db, {
  getConfig: () => ({clientSecrets: JSON.stringify({"test.client": "SYNTHETIC_CLIENT_SECRET"}),
    encryptionKey: "cd".repeat(32)}), fetch: async () => ({status: 200})}) :
  {revokeApple: () => { throw new Error("RECEIPT_MUST_SURVIVE_PROCESS_RESTART"); }};
processClosure(db, account, uid, services).then(async () => {
  await db.terminate(); await deleteApp(app); process.exit(0);
}).catch(() => { console.error("F01_CHILD_FAILED"); process.exit(1); });
`;
test("F01 OS process restart resumes durable Apple receipt without credentials or repeated revocation", async () => {
  const uid = "f01-os-restart";
  await auth.createUser({uid, email: `${uid}@example.test`});
  await db.doc(`customerProfiles/${uid}`).set({personal: "SYNTHETIC_PII"});
  await db.doc(`orders/${uid}`).set({customerUid: uid, customerName: "Synthetic", address: "SYNTHETIC_ADDRESS",
    status: "Concluído", paymentStatus: "Pago", totalBRL: 12.34});
  await db.doc(`orderFinancials/${uid}`).set({totalCentavos: 1234, commissionCentavos: 100});
  await createAppleCredentialStore(db, () => ({encryptionKey: "cd".repeat(32)}))
      .saveVerified(uid, "SYNTHETIC_RESTART_SUBJECT", {clientId: "test.client",
        tokenType: "refresh_token", token: "SYNTHETIC_RESTART_TOKEN"});
  await requestClosure(db, {auth: {uid, token: {firebase: {sign_in_provider: "apple.com"},
    auth_time: Date.now() / 1000}}, data: {expectedUid: uid, confirmation: "EXCLUIR MINHA CONTA",
    requestId: "request-os-restart-123456789"}});
  const run = (phase) => spawnSync(process.execPath, ["-e", childSource, uid, phase], {
    cwd: join(__dirname, ".."), env: process.env, windowsHide: true, encoding: "utf8", timeout: 30000,
  });
  const interrupted = run("interrupt");
  assert.equal(interrupted.status, 42, interrupted.stderr);
  assert.equal((await db.doc(`customerAccountClosures/${uid}`).get()).data().status, "processing");
  assert.ok(await auth.getUser(uid));
  assert.equal((await db.doc(`customerAppleCredentials/${uid}`).get()).exists, false);
  const receipt = (await db.doc(`customerProviderRevocations/${uid}`).get()).data();
  assert.equal(receipt.status, "revoked");
  const resumed = run("resume");
  assert.equal(resumed.status, 0, resumed.stderr);
  assert.equal((await db.doc(`customerAccountClosures/${uid}`).get()).data().status, "completed");
  await assert.rejects(auth.getUser(uid));
  assert.deepEqual((await db.doc(`customerProviderRevocations/${uid}`).get()).data(), receipt);
  assert.equal((await db.doc(`orders/${uid}`).get()).data().address, undefined);
  assert.deepEqual((await db.doc(`orderFinancials/${uid}`).get()).data(),
      {totalCentavos: 1234, commissionCentavos: 100});
  assert.ok(!(interrupted.stdout + interrupted.stderr + resumed.stdout + resumed.stderr)
      .includes("SYNTHETIC_RESTART_TOKEN"));
});
