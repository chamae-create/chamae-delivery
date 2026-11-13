const {test, before, after} = require("node:test");
const assert = require("node:assert/strict");
const {initializeApp, deleteApp} = require("firebase-admin/app");
const {getFirestore, Timestamp, GeoPoint} = require("firebase-admin/firestore");
const {initializeTestEnvironment, assertFails} = require("@firebase/rules-unit-testing");
const {doc, getDoc, setDoc, updateDoc} = require("firebase/firestore");
const fs = require("node:fs"); const path = require("node:path");
const {ensureOperationalId} = require("../operational-order-id");
const {pickupAction, pickupPolicy, inspectPickup} = require("../courier-pickup-lifecycle");
const {changeCourier} = require("../courier-assignment");
const {beginPickup, signTicket, confirmPickup} = require("../courier-pickup");
const {generateKeyPairSync} = require("node:crypto");
let app; let db; let environment; let n = 0; let clock = Date.now();
const admin = {uid: "master-admin", token: {roles: ["superadmin"]}};
const auth = (uid) => ({uid, token: {email_verified: true, firebase: {sign_in_provider: "password"}}});
before(async () => {
  const host = process.env.FIRESTORE_EMULATOR_HOST; assert.ok(host);
  const url = new URL(`http://${host}`); assert.ok(["localhost", "127.0.0.1", "[::1]"].includes(url.hostname));
  environment = await initializeTestEnvironment({projectId: "demo-chamae-rules", firestore: {
    host: url.hostname, port: Number(url.port), rules: fs.readFileSync(path.join(__dirname, "../../firestore.rules"),
        "utf8")}});
  await environment.clearFirestore(); app = initializeApp({projectId: "demo-chamae-rules"}, "master-v02");
  db = getFirestore(app); pickupPolicy.now = () => clock;
});
after(async () => {
  pickupPolicy.now = () => Date.now();
  if (environment) await environment.cleanup(); if (db) await db.terminate(); if (app) await deleteApp(app);
});
async function fixture() {
  clock = Date.now(); const id = `master-${++n}`; const uid = `courier-master-${n}`; const assignmentId =
    `binding-${n}`;
  await db.doc(`couriers/${uid}`).set({role: "courier", name: "Pessoa Exemplo", approvalStatus: "approved",
    administrativeState: "active", enabled: true, online: true});
  await db.doc(`orders/${id}`).set({status: "Em Separação", courierUid: uid, courierName: "Pessoa Exemplo",
    courierAssignmentId: assignmentId, courierAssignmentExpiresAt: Timestamp.fromMillis(clock + 8 * 3600000),
    courierPickupState: "assigned", financialValidationStatus: "validated", paymentMethod: "Dinheiro",
    customerName: "Nome mínimo", address: "Rua de exemplo", deliveryLocation: new GeoPoint(-22.5, -55.7),
    ...Object.fromEntries(["itemsTotal", "deliveryFee", "customerFee", "merchantFee", "merchantNet", "platformFee",
      "totalBRL"].map((k) => [k, 0]))});
  await db.doc(`orderFinancials/${id}`).set(Object.fromEntries(
      ["itemsTotal", "deliveryFee", "customerFee", "merchantFee", "merchantNet", "platformFee", "totalBRL"].map(
          (k) => [k, 0])));
  await db.doc(`courierPickupAssignments/${assignmentId}`).set({orderId: id, courierUid: uid, status: "active"});
  const code = await ensureOperationalId(db, id);
  let req = 0;
  const action = (type, data = {}, isAdmin = false) => pickupAction(db, {auth: isAdmin ? admin : auth(uid),
    data: {orderId: id, assignmentId, requestId: `request-master-${n}-${++req}`, ...data}}, type, isAdmin);
  return {id, uid, assignmentId, code, action, order: async () => (await db.doc(`orders/${id}`).get()).data()};
}
test("concurrent creation has unique sequential codes; retry/cancel/refund never reuse", async () => {
  await db.doc("operationalCounters/V8").set({lastSequence: 9998});
  const ids = Array.from({length: 10}, (_, i) => `concurrent-${i}`);
  for (const id of ids) await db.doc(`orders/${id}`).set({status: "Novo"});
  const codes = await Promise.all(ids.map((id) => ensureOperationalId(db, id)));
  assert.equal(new Set(codes).size, 10); assert.ok(codes.includes("V8-9999")); assert.ok(codes.includes("V8-10000"));
  const original = codes[0]; await db.doc(`orders/${ids[0]}`).update({status: "Cancelado", paymentStatus:
    "Reembolsado"});
  assert.equal(await ensureOperationalId(db, ids[0]), original);
  const f = await fixture(); assert.ok(!codes.includes(f.code));
});
test("accept creates server deadline and retry keeps original time", async () => {
  const f = await fixture(); const accepted = await f.action("accept");
  assert.equal(accepted.expectedPickupByMs, clock + pickupPolicy.pickupMs);
  clock += 60000; assert.equal((await f.action("accept")).expectedPickupByMs, accepted.expectedPickupByMs);
  assert.equal((await f.order()).courierPickupState, "accepted"); assert.equal((await f.order()).courierPickedUpAt,
      undefined);
});
test("reminder, confirmation and overdue do not blindly reassign; events deduplicate", async () => {
  const f = await fixture(); await f.action("accept"); const deadline = (await f.order()).expectedPickupBy.toMillis();
  clock = deadline - pickupPolicy.reminderMs; assert.equal(await inspectPickup(db, f.id), "pickup_reminder");
  clock = deadline; assert.equal(await inspectPickup(db, f.id), "pickup_confirmation");
  clock += pickupPolicy.graceMs; assert.equal(await inspectPickup(db, f.id), "pickupOverdue");
  assert.equal(await inspectPickup(db, f.id), false);
  assert.equal((await f.order()).courierUid, f.uid);
  const events = await db.collection("courierReliabilityEvents").where("assignmentId", "==", f.assignmentId).get();
  assert.equal(events.docs.filter((v) => v.data().type === "courierNoShow").length, 1);
});
test("onWay tolerance is finite and admin extension is separately bounded", async () => {
  const f = await fixture(); await f.action("accept");
  const first = (await f.order()).expectedPickupBy.toMillis(); await f.action("onWay");
  assert.equal((await f.order()).expectedPickupBy.toMillis(), first + pickupPolicy.extensionMs);
  await assert.rejects(f.action("onWay"));
  for (let i = 0; i < pickupPolicy.maxAdminExtensions; i++) await f.action("extend", {}, true);
  await assert.rejects(f.action("extend", {}, true));
});
for (const action of ["decline", "revoke"]) {
  test(`${action} revokes once, retries idempotently, old courier cannot download`, async () => {
    const f = await fixture(); await f.action("accept");
    const data = {reason: "Não pode realizar entrega", requestId: `revoke-stable-request-${n}`};
    await f.action(action, data, action === "revoke");
    assert.equal((await f.action(action, data, action === "revoke")).replayed, true);
    assert.equal((await f.order()).courierAssignmentId, undefined);
    assert.equal((await db.doc(`courierPickupAssignments/${f.assignmentId}`).get()).data().status, "revoked");
    const keys = generateKeyPairSync("ed25519");
    const ticket = signTicket({keyId: "test", orderId: f.id, assignmentId: f.assignmentId,
      courierUid: f.uid, packageVersion: 1, nonce: "test-nonce", expiresAtMs: Date.now() + 3600000}, keys.privateKey);
    await assert.rejects(beginPickup(db, {auth: auth(f.uid), data: {ticket}}, {publicKey: async () => keys.publicKey,
      package: async () => assert.fail("revoked download")}));
    assert.equal(await ensureOperationalId(db, f.id), f.code);
  });
}
test("reassignment atomically revokes old binding and preserves official number", async () => {
  const f = await fixture(); await f.action("accept");
  await db.doc("couriers/replacement-master").set({role: "courier", name: "Outro Exemplo", approvalStatus: "approved",
    administrativeState: "active", enabled: true, online: true});
  await changeCourier(db, {auth: admin, data: {orderId: f.id, courierUid: "replacement-master", expectedCourierUid:
    f.uid,
  requestId: "reassign-master-stable-request", contingencyReason: "Teste operacional", confirmation:
    `CONFIRMAR ${f.id}`}});
  const order = await f.order(); assert.notEqual(order.courierAssignmentId, f.assignmentId);
  assert.equal(order.displayOrderId, f.code); assert.equal(order.acceptedAt, undefined);
  assert.equal((await db.doc(`courierPickupAssignments/${f.assignmentId}`).get()).data().status, "revoked");
  assert.equal((await db.doc(`courierPickupAssignments/${order.courierAssignmentId}`).get()).data().status, "active");
  await assert.rejects(f.action("accept"));
});
test("geofence states cannot confirm pickup and pickedUp cannot be revoked/reassigned blindly", async () => {
  const f = await fixture(); await f.action("accept"); await f.action("pickupApproaching"); await
  f.action("arrivedAtStore");
  assert.equal((await f.order()).courierPickedUpAt, undefined);
  await db.doc(`orders/${f.id}`).update({courierPickedUpAt: Timestamp.now(), courierPickupState: "headingToCustomer"});
  await assert.rejects(f.action("revoke", {reason: "Teste de segurança"}, true));
});
test("pending/suspended/other courier cannot accept even knowing public code", async () => {
  const f = await fixture();
  for (const status of ["pendingApproval", "suspended"]) {
    await db.doc(`couriers/${f.uid}`).update({approvalStatus: status}); await assert.rejects(f.action("accept"));
  }
});
test("new binding requires accept; package ACK records pickup once and prevents late revoke", async () => {
  const f = await fixture(); const keys = generateKeyPairSync("ed25519");
  const expiresAtMs = Date.now() + 3600000;
  const ticket = signTicket({keyId: "test", orderId: f.id, assignmentId: f.assignmentId,
    courierUid: f.uid, packageVersion: 1, nonce: "test-accepted-flow", expiresAtMs}, keys.privateKey);
  const assignment = {orderId: f.id, assignmentId: f.assignmentId, courierUid: f.uid, packageVersion: 1, expiresAtMs};
  const start = {latitude: -22.1, longitude: -55.1}; const end = {latitude: -22, longitude: -55};
  const bundle = {schemaVersion: 2, assignment, delivery: {orderId: f.id, number: f.code, courierUid: f.uid,
    address: "Rua da fixture", coordinates: end, payment: {state: "paid", amountMinor: 0, currency: "BRL"},
    pinVerifier: {orderId: f.id, verificationVersion: 1, expiresAtMs, maxAttempts: 3,
      verificationMaterial: `opaque-verifier-${f.id}`}},
  map: {geometry: [start, end], asset: "fixture-map", navigation: {schemaVersion: 1, engine: "fixture-graph-v1",
    datasetVersion: "synthetic-1", destination: end, coverage: {marginMeters: 200, corridors: [[start, end]]},
    nodes: [{id: "A", point: start}, {id: "D", point: end}], edges: [{from: "A", to: "D"}], alternatives: []}}};
  let downloads = 0;
  const ports = {publicKey: async () => keys.publicKey, package: async () => {
    downloads++; return Buffer.from(JSON.stringify(bundle));
  }};
  const request = {auth: auth(f.uid), data: {ticket, expectedOrderId: f.id}};
  await assert.rejects(beginPickup(db, request, ports)); assert.equal(downloads, 0);
  await f.action("accept"); const prepared = await beginPickup(db, request, ports);
  assert.equal((await f.order()).courierPickedUpAt, undefined);
  const activationProof = JSON.parse(Buffer.from(prepared.package, "base64").toString()).activationProof;
  const confirmation = {auth: auth(f.uid), data: {sessionId: prepared.sessionId, digest: prepared.digest,
    activationProof}};
  assert.equal((await confirmPickup(db, confirmation)).acknowledged, true);
  assert.equal((await confirmPickup(db, confirmation)).replayed, true);
  assert.equal((await f.order()).courierPickupState, "headingToCustomer");
  assert.equal((await db.doc(`courierPickupAssignments/${f.assignmentId}`).get()).data().status, "pickedUp");
  assert.equal((await db.doc(`courierReliabilityEvents/${f.assignmentId}-ontime`).get()).data().type, "pickupOnTime");
  await assert.rejects(f.action("revoke", {reason: "Não pode revogar após retirada"}, true));
  assert.equal(await inspectPickup(db, f.id), false);
});
test("Rules deny public counter, action ledger, reliability and assignments writes", async () => {
  const f = await fixture(); const client = environment.authenticatedContext(f.uid, auth(f.uid).token).firestore();
  for (const collection of ["operationalCounters", "operationalOrderIds", "courierPickupAssignments",
    "courierPickupActionRequests", "courierReliabilityEvents"]) {
    await assertFails(setDoc(doc(client, collection, "forged"), {displayOrderId: f.code}));
    await assertFails(getDoc(doc(client, collection, "forged")));
  }
  await assertFails(updateDoc(doc(client, "orders", f.id), {displayOrderId: "V8-0001"}));
});
