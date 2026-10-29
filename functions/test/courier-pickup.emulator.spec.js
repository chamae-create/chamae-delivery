const assert = require("node:assert/strict");
const fs = require("node:fs"); const path = require("node:path");
const {generateKeyPairSync} = require("node:crypto");
const {before, after, test} = require("node:test");
const {initializeApp, deleteApp} = require("firebase-admin/app");
const {getFirestore, Timestamp} = require("firebase-admin/firestore");
const {initializeTestEnvironment, assertFails, assertSucceeds} = require("@firebase/rules-unit-testing");
const {getDoc, doc, setDoc} = require("firebase/firestore");
const {beginPickup, confirmPickup, signTicket, listAssignments, issueTicket} = require("../courier-pickup");
const {enqueueNotice, deliverNotice} = require("../courier-notifications");
const {ownProfile, reviewCourier} = require("../courier-approval");
let app; let db; let environment; let n = 0;
const keys = generateKeyPairSync("ed25519");
const auth = (uid = "rider") => ({uid, token: {firebase: {sign_in_provider: "password"}}});
const admin = {uid: "reviewer", token: {roles: ["superadmin"]}};
const denied = (e) => ["permission-denied", "failed-precondition", "invalid-argument"].includes(e.code);
before(async () => {
  const host = process.env.FIRESTORE_EMULATOR_HOST; assert.ok(host);
  const address = new URL(`http://${host}`);
  assert.ok(["127.0.0.1", "localhost", "[::1]"].includes(address.hostname));
  environment = await initializeTestEnvironment({projectId: "demo-chamae-rules", firestore: {
    host: address.hostname, port: Number(address.port),
    rules: fs.readFileSync(path.join(__dirname, "../../firestore.rules"), "utf8")}});
  await environment.clearFirestore();
  app = initializeApp({projectId: "demo-chamae-rules"}, "pickup-v2"); db = getFirestore(app);
});
after(async () => {
  if (environment) await environment.cleanup(); if (db) await db.terminate(); if (app) await deleteApp(app);
});
async function fixture(status = "approved") {
  const id = `pickup-${++n}`; const assignmentId = `assignment-${n}`; const uid = `rider-${n}`;
  const expiry = Date.now() + 3600000;
  const profile = {name: "Pessoa Exemplo", role: "courier", approvalStatus: status,
    administrativeState: "active", enabled: true, online: true};
  await db.doc(`couriers/${uid}`).set(profile);
  const order = {courierUid: uid, courierAssignmentId: assignmentId, acceptedAt: Timestamp.now(),
    courierAssignmentExpiresAt: Timestamp.fromMillis(expiry), status: "Em Separação",
    financialValidationStatus: "validated", paymentMethod: "Dinheiro"};
  await db.doc(`orders/${id}`).set(order);
  await db.doc(`courierDeliveries/${id}`).set({orderId: id, courierUid: uid, customerName: "Nome mínimo",
    status: "Em Separação", address: "Rua de exemplo"});
  const ticketData = {keyId: "test-key", orderId: id, assignmentId, courierUid: uid,
    packageVersion: 1, expiresAtMs: expiry, nonce: `nonce-${n}`};
  const ticket = signTicket(ticketData, keys.privateKey);
  const bundle = {schemaVersion: 2, assignment: {orderId: id, assignmentId, courierUid: uid,
    packageVersion: 1, expiresAtMs: expiry}, delivery: {orderId: id, courierUid: uid,
    address: "Rua necessária", coordinates: {latitude: -22, longitude: -55},
    payment: {state: "paid", amountMinor: 0, currency: "BRL"},
    pinVerifier: {orderId: id, verificationVersion: 1, expiresAtMs: expiry, maxAttempts: 3,
      verificationMaterial: `opaque-order-verifier-${id}`}},
  map: {geometry: [{latitude: -22.1, longitude: -55.1}, {latitude: -22, longitude: -55}], asset: "fixture-map"}};
  bundle.map.navigation = {schemaVersion: 1, engine: "fixture-graph-v1", datasetVersion: "synthetic-1",
    destination: bundle.delivery.coordinates, coverage: {marginMeters: 200, corridors: [bundle.map.geometry]},
    nodes: [{id: "A", point: bundle.map.geometry[0]}, {id: "D", point: bundle.delivery.coordinates}],
    edges: [{from: "A", to: "D"}], alternatives: []};
  let downloads = 0;
  const ports = {publicKey: async () => keys.publicKey, package: async () => {
    downloads++; return Buffer.from(JSON.stringify(bundle));
  }};
  const begin = (identity = auth(uid), value = ticket) => beginPickup(db, {auth: identity, data: {ticket: value}},
      ports);
  const confirm = (download) => confirmPickup(db, {auth: auth(uid), data: {sessionId: download.sessionId,
    digest: download.digest,
    activationProof: JSON.parse(Buffer.from(download.package, "base64").toString("utf8")).activationProof}});
  const client = environment.authenticatedContext(uid, auth(uid).token).firestore();
  return {id, assignmentId, uid, expiry, profile, ticket, ticketData, bundle, ports, begin, confirm, client,
    downloads: () => downloads, order};
}
test("approved has only safe assignment indication before physical pickup", async () => {
  const f = await fixture();
  const result = await listAssignments(db, {auth: auth(f.uid)});
  assert.equal(result.assignments.length, 1);
  for (const field of ["address", "customerName", "payment", "pin"]) {
    assert.equal(Object.hasOwn(result.assignments[0],
        field), false);
  }
  await assertFails(getDoc(doc(f.client, "courierDeliveries", f.id)));
});
for (const status of ["pendingApproval", "rejected", "suspended"]) {
  test(`${status} cannot list/scan/download even with a genuine signed ticket`, async () => {
    const f = await fixture(status);
    await assert.rejects(f.begin(), denied);
    await assert.rejects(listAssignments(db, {auth: auth(f.uid)}), denied);
    assert.equal(f.downloads(), 0);
  });
}
test("valid physical ticket prepares but grants no read until durable-package acknowledgement", async () => {
  const f = await fixture(); const prepared = await f.begin();
  assert.equal(f.downloads(), 1); assert.ok(prepared.digest);
  await assertFails(getDoc(doc(f.client, "courierDeliveries", f.id)));
  assert.equal((await db.doc(`orders/${f.id}`).get()).data().courierPickupState, undefined);
  const confirmed = await f.confirm(prepared); assert.equal(confirmed.acknowledged, true);
  await assertSucceeds(getDoc(doc(f.client, "courierDeliveries", f.id)));
  assert.equal((await db.doc(`orders/${f.id}`).get()).data().courierPickupState, "headingToCustomer");
  const before = (await db.doc(`courierPickupGrants/${f.id}`).get()).updateTime;
  assert.equal((await f.confirm(prepared)).replayed, true);
  assert.ok(before.isEqual((await db.doc(`courierPickupGrants/${f.id}`).get()).updateTime));
});
test("foreign courier and tampering never reach download provider", async () => {
  const f = await fixture(); await db.doc("couriers/other").set(f.profile);
  await assert.rejects(f.begin(auth("other")), denied);
  await assert.rejects(f.begin(auth(f.uid), JSON.stringify({...JSON.parse(f.ticket), orderId: "forged"})), denied);
  assert.equal(f.downloads(), 0);
});
test("partial, wrong-version or incomplete provider response never creates a session/grant", async () => {
  for (const patch of [{schemaVersion: 99}, {map: {}}, {delivery: {pin: "PRIVATE_PIN"}}]) {
    const f = await fixture(); Object.assign(f.bundle, patch);
    await assert.rejects(f.begin(), denied);
    assert.equal((await db.doc(`courierPickupGrants/${f.id}`).get()).exists, false);
  }
});
test("reassignment and suspension after download reject commit and revoke old access", async () => {
  const f = await fixture(); const prepared = await f.begin();
  await db.doc(`orders/${f.id}`).update({courierAssignmentId: "replacement"});
  await assert.rejects(f.confirm(prepared), denied);
  const g = await fixture(); const second = await g.begin();
  await db.doc(`couriers/${g.uid}`).update({approvalStatus: "suspended"});
  await assert.rejects(g.confirm(second), denied);
  await assertFails(getDoc(doc(g.client, "courierDeliveries", g.id)));
});
test("forged grant/session via SDK and forged ready/digest are refused", async () => {
  const f = await fixture(); const prepared = await f.begin();
  await assertFails(setDoc(doc(f.client, "courierPickupGrants", f.id), {courierUid: f.uid,
    assignmentId: f.assignmentId}));
  await assertFails(setDoc(doc(f.client, "courierPickupSessions", prepared.sessionId), {digest: prepared.digest}));
  await assert.rejects(f.confirm({...prepared, digest: "0".repeat(64)}), denied);
  await assert.rejects(confirmPickup(db, {auth: auth(f.uid), data: {sessionId: prepared.sessionId,
    digest: prepared.digest, ready: true}}), denied);
});
test("second ticket cannot replay a completed physical pickup", async () => {
  const f = await fixture(); const prepared = await f.begin(); await f.confirm(prepared);
  const second = await f.begin(auth(f.uid), signTicket({...f.ticketData, nonce: "second-ticket"}, keys.privateKey));
  await assert.rejects(f.confirm(second), (e) => e.code === "already-exists");
});
test("only approved and available assignment enqueues notification, adapter revalidates stale notices", async () => {
  const f = await fixture();
  await db.runTransaction(async (tx) => enqueueNotice(tx, db, f.id, f.assignmentId, f.uid, f.profile));
  const sent = []; const transport = {send: async (...args) => sent.push(args)};
  assert.equal(await deliverNotice(db, f.assignmentId, transport), true);
  assert.equal(await deliverNotice(db, f.assignmentId, transport), false);
  assert.equal(sent.length, 1); assert.equal(sent[0][1].body, "Você recebeu uma nova entrega da Pit Stop V8.");
  const g = await fixture();
  await db.runTransaction(async (tx) => enqueueNotice(tx, db, g.id, g.assignmentId, g.uid, g.profile));
  await db.doc(`couriers/${g.uid}`).update({approvalStatus: "suspended"});
  assert.equal(await deliverNotice(db, g.assignmentId, transport), false);
  const h = await fixture();
  await db.runTransaction(async (tx) => enqueueNotice(tx, db, h.id, h.assignmentId, h.uid, {...h.profile,
    online: false}));
  assert.equal((await db.doc(`courierNotificationOutbox/${h.assignmentId}`).get()).exists, false);
});
test("photo receipt required, plate/license optional, administrator approval succeeds without documents", async () => {
  const uid = `applicant-${++n}`;
  const fields = {name: "Pessoa Exemplo", phone: "67900000000", profilePhoto: "verified-photo-reference"};
  await assert.rejects(ownProfile(db, {auth: auth(uid), data: fields}, "register"), denied);
  await db.doc(`courierProfilePhotos/${uid}`).set({verified: true, reference: fields.profilePhoto});
  await ownProfile(db, {auth: auth(uid), data: fields}, "register");
  await reviewCourier(db, {auth: admin, data: {courierUid: uid, action: "approve", expectedStatus: "pendingApproval"}});
  const profile = (await db.doc(`couriers/${uid}`).get()).data();
  assert.equal(profile.approvalStatus, "approved"); assert.equal(profile.vehiclePlate,
      ""); assert.equal(profile.driverLicense, "");
});

test("activation nonce is required and never appears in QR or public headers", async () => {
  const f = await fixture(); const prepared = await f.begin();
  assert.equal(Object.hasOwn(JSON.parse(f.ticket), "activationProof"), false);
  assert.equal(Object.hasOwn(prepared, "activationProof"), false);
  await assert.rejects(confirmPickup(db, {auth: auth(f.uid), data: {sessionId: prepared.sessionId,
    digest: prepared.digest, activationProof: "forged-proof"}}), denied);
  await f.confirm(prepared);
});
test("only an authorized operator can issue a signed physical ticket", async () => {
  const f = await fixture();
  await assert.rejects(issueTicket(db, {auth: auth(f.uid), data: {orderId: f.id}}), denied);
  const issued = await issueTicket(db, {auth: admin, data: {orderId: f.id}},
      {sign: async (data) => signTicket(data, keys.privateKey)});
  assert.equal(JSON.parse(issued.ticket).assignmentId, f.assignmentId);
});

test("polyline alone cannot prepare a new pickup package", async () => {
  const f = await fixture(); delete f.bundle.map.navigation;
  await assert.rejects(f.begin(), denied);
  assert.equal((await db.doc(`courierPickupGrants/${f.id}`).get()).exists, false);
});
test("navigation dataset is integrity-bound and preserves the assigned destination", async () => {
  const f = await fixture(); const prepared = await f.begin();
  const received = JSON.parse(Buffer.from(prepared.package, "base64").toString("utf8"));
  assert.deepEqual(received.map.navigation.destination, f.bundle.delivery.coordinates);
  f.bundle.map.navigation.datasetVersion = "changed";
  await assert.rejects(f.begin(), (e) => e.code === "aborted");
  const g = await fixture(); g.bundle.map.navigation.destination.longitude += 1;
  await assert.rejects(g.begin(), denied);
});

test("nested private material is rejected before download/receipt grant", async () => {
  const f = await fixture(); f.bundle.delivery.metadata = {privateKey: "synthetic-not-a-real-key"};
  await assert.rejects(f.begin(), denied);
  assert.equal((await db.doc(`courierPickupGrants/${f.id}`).get()).exists, false);
  assert.equal((await db.doc(`orders/${f.id}`).get()).data().courierPickupState, undefined);
});
