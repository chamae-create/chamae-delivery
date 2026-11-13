const {test, before, after} = require("node:test");
const assert = require("node:assert/strict");
const {generateKeyPairSync} = require("node:crypto");
const {initializeApp, deleteApp} = require("firebase-admin/app");
const {getFirestore, Timestamp} = require("firebase-admin/firestore");
const {signTicket, beginPickup, confirmPickup} = require("../courier-pickup");
const {loadBackend} = require("./backend-fixture");
const {deliveryFixture} = require("./delivery-fixture");
const {customerPolicyFixture, customerProfileFixture} = require("./customer-policy-fixture");
const {createPickupPorts} = require("../courier-pickup-ports");
const {seedCourierPolicy} = require("./courier-policy-fixture");
let app; let db; let backend; let number = 0;
const keys = generateKeyPairSync("ed25519"); const prefix = "confirm-security-" + Date.now();
before(() => {
  assert.match(process.env.FIRESTORE_EMULATOR_HOST || "", /^(127\.0\.0\.1|localhost):[0-9]+$/);
  app = initializeApp({projectId: "demo-chamae-rules"}); db = getFirestore(app); backend = loadBackend(db);
});
after(async () => {
  if (db) await db.terminate(); if (app) await deleteApp(app);
});
async function fixture() {
  const id = prefix + "-" + (++number); const uid = id + "-courier"; const assignmentId = id + "-binding";
  const expiresAtMs = Date.now() + 3600000;
  const auth = {uid, token: {email_verified: true, firebase: {sign_in_provider: "password"}}};
  await db.doc("couriers/" + uid).set({role: "courier", approvalStatus: "approved",
    administrativeState: "active", enabled: true, online: true});
  const orderRef = db.doc("orders/" + id);
  const policy = customerPolicyFixture();
  await db.doc("customerPolicies/current").set(policy);
  await db.doc("customerProfiles/buyer").set(customerProfileFixture(policy, Timestamp.now()));
  const delivery = deliveryFixture({quoteId: number.toString(16).padStart(64, "a")});
  for (const [path, value] of delivery.documents) await db.doc(path).set(value);
  await db.doc("products/" + id).set({priceBRL: 10, stock: 10, reservedStock: 0, salesCount: 0, isActive: true});
  await orderRef.set({customerUid: "buyer", customerName: "TEST FIXTURE", customerFlowVersion: 2,
    deliveryAddress: delivery.destination, deliveryQuoteId: delivery.quoteId, address: "TEST FIXTURE",
    itemsList: [{id, quantity: 1, price: 10}], totalBRL: 1, paymentMethod: "Dinheiro",
    paymentStatus: "Pendente na entrega", status: "Novo", courierPaid: false, createdAt: Timestamp.now()});
  // Real financial/reservation handler: no no-op financial gate in this fixture.
  await backend.functions.chamaeReservarEstoquePagamentoEntrega({params: {orderId: id}, data: await orderRef.get()});
  assert.equal((await db.doc("orderFinancials/" + id).get()).exists, true);
  await orderRef.update({courierUid: uid, courierAssignmentId: assignmentId, acceptedAt: Timestamp.now(),
    courierAssignmentExpiresAt: Timestamp.fromMillis(expiresAtMs), status: "Em Separação"});
  const bindingRef = db.doc("courierPickupAssignments/" + assignmentId);
  const binding = {orderId: id, courierUid: uid, status: "active"}; await bindingRef.set(binding);
  const assignment = {orderId: id, assignmentId, courierUid: uid, packageVersion: 1, expiresAtMs};
  const start = {latitude: -22.1, longitude: -55.1}; const end = {latitude: -22, longitude: -55};
  const bundle = {schemaVersion: 2, assignment,
    delivery: {orderId: id, courierUid: uid, address: "TEST FIXTURE", expiresAtMs, coordinates: end,
      payment: {state: "collect", amountMinor: 1000, currency: "BRL"}, pinVerifier: {orderId: id,
        verificationVersion: 1, expiresAtMs, maxAttempts: 3, verificationMaterial: "server-only:v1"}},
    map: {geometry: [start, end], asset: "TEST-MAP", navigation: {schemaVersion: 1, engine: "fixture-graph-v1",
      datasetVersion: "synthetic-1", destination: end, coverage: {marginMeters: 200, corridors: [[start, end]]},
      nodes: [{id: "A", point: start}, {id: "D", point: end}], edges: [{from: "A", to: "D"}], alternatives: []}}};
  const ticket = signTicket({...assignment, keyId: "TEST-KEY", nonce: id + "-nonce"}, keys.privateKey);
  await seedCourierPolicy(db, uid, Timestamp.now());
  const prepared = await beginPickup(db, {auth, data: {ticket}}, createPickupPorts({keyId: "TEST-KEY", privateKey: async () => keys.privateKey,
    publicKey: async () => keys.publicKey, packageProvider: async () => Buffer.from(JSON.stringify(bundle))}));
  const request = {auth, data: {sessionId: prepared.sessionId, digest: prepared.digest,
    activationProof: JSON.parse(Buffer.from(prepared.package, "base64").toString("utf8")).activationProof}};
  return {id, uid, orderRef, bindingRef, binding, request, confirm: () => backend.functions.chamaeConfirmarPacoteRetirada(request)};
}
for (const change of ["missing", "foreign-courier", "foreign-order", "revoked"]) {
  test("confirm denies " + change + " binding changed after preparation, with no state/grant writes", async () => {
    const f = await fixture(); const before = (await f.orderRef.get()).data();
    if (change === "missing") await f.bindingRef.delete();
    else {
      await f.bindingRef.update(change === "foreign-courier" ? {courierUid: "unrelated-courier"} :
      change === "foreign-order" ? {orderId: "unrelated-order"} : {status: "revoked"});
    }
    await assert.rejects(f.confirm(), {code: "failed-precondition"});
    assert.equal((await db.doc("courierPickupGrants/" + f.id).get()).exists, false);
    assert.deepEqual((await f.orderRef.get()).data(), before);
    assert.equal((await f.orderRef.get()).data().courierPickedUpAt, undefined);
    // Restoring only the legitimate binding permits the original prepared package to confirm.
    await f.bindingRef.set(f.binding); const first = await f.confirm();
    assert.equal(first.acknowledged, true); assert.equal(first.replayed, false);
    const granted = await db.doc("courierPickupGrants/" + f.id).get();
    assert.equal((await f.bindingRef.get()).data().status, "pickedUp");
    assert.equal((await f.confirm()).replayed, true);
    assert.ok((await db.doc("courierPickupGrants/" + f.id).get()).updateTime.isEqual(granted.updateTime));
    assert.equal((await f.orderRef.get()).data().courierPickupState, "headingToCustomer");
  });
}
