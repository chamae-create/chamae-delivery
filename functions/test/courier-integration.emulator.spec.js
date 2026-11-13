const {test, before, after} = require("node:test");
const assert = require("node:assert/strict");
const {createHash} = require("node:crypto");
const {initializeApp, deleteApp} = require("firebase-admin/app");
const {getFirestore, Timestamp} = require("firebase-admin/firestore");
const {getStorage} = require("firebase-admin/storage");
const {getAuth} = require("firebase-admin/auth");
const {seedCourierPolicy} = require("./courier-policy-fixture");
const {submitCourierEvent} = require("../courier-events");
const {confirmCourierPhoto} = require("../courier-photo");
const {pickupAction, inspectPickup, pickupPolicy} = require("../courier-pickup-lifecycle");
const {changeCourier} = require("../courier-assignment");
const {requestCourierClosure} = require("../courier-account");
let app; let db; let auth; let storage; let counter = 0;
const operator = {uid: "f03-node-admin", token: {roles: ["superadmin"]}};
const hash = (s) => createHash("sha256").update(s).digest("hex");
before(async () => {
  for (const key of ["FIRESTORE_EMULATOR_HOST", "FIREBASE_AUTH_EMULATOR_HOST", "FIREBASE_STORAGE_EMULATOR_HOST"]) {
    assert.match(process.env[key] || "", /^(127\.0\.0\.1|localhost):\d+$/);
  }
  app = initializeApp({projectId: "demo-chamae-rules", storageBucket: "demo-chamae-rules.appspot.com"}, "f03-core");
  db = getFirestore(app); auth = getAuth(app); storage = getStorage(app).bucket();
});
after(async () => {
  pickupPolicy.now = () => Date.now(); await db.terminate(); await deleteApp(app);
});
async function fixture(status = "approved") {
  const uid = `f03-core-${++counter}`; const id = `f03-core-order-${counter}`;
  await auth.createUser({uid});
  await seedCourierPolicy(db, uid, Timestamp.now());
  await db.doc(`couriers/${uid}`).set({role: "courier", name: "Fictitious courier", phone: "67000000000",
    profilePhoto: "fixture", approvalStatus: status, administrativeState: status === "approved" ? "active" : status,
    enabled: status === "approved", online: true});
  await db.doc(`orders/${id}`).set({id: "LEGACY-FIXTURE", status: "Novo", customerName: "Fixture customer",
    paymentMethod: "HOMOLOGACAO_SEM_COBRANCA", pixRequested: false, financialValidationStatus: "validated",
    address: "Rua Ficticia 123", deliveryLocation: new (require("firebase-admin/firestore").GeoPoint)(-22.5, -55.7),
    itemsTotal: 0, deliveryFee: 0, customerFee: 0, merchantFee: 0, merchantNet: 0, platformFee: 0, totalBRL: 0,
    stockReservationStatus: "finalized", courierPaid: false});
  await db.doc(`orderFinancials/${id}`).set({itemsTotal: 0, deliveryFee: 0, customerFee: 0, merchantFee: 0,
    merchantNet: 0, platformFee: 0, totalBRL: 0});
  await changeCourier(db, {auth: operator, data: {orderId: id, courierUid: status === "approved" ? uid : "",
    requestId: `f03-initial-assignment-${counter}`, contingencyReason: "Homologação com dados inteiramente fictícios",
    confirmation: `CONFIRMAR ${id}`}});
  const read = async () => (await db.doc(`orders/${id}`).get()).data();
  const initial = await read();
  const identity = {uid, token: {email_verified: true, auth_time: Math.floor(Date.now() / 1000),
    firebase: {sign_in_provider: "password"}}};
  let sequence = 0;
  const event = (type = "pickupAction", payload = {action: "accept"}, eventId) => {
    const data = {...(type === "availability" ? {} : {assignmentId: initial.courierAssignmentId}),
      protocolVersion: 2, eventId: eventId || `f03-core-event-${counter}-${++sequence}`,
      orderId: type === "availability" ? "shift" : id, courierUid: uid, type,
      localTimestampMs: Date.now(), sequence: sequence || 1, payload};
    return {...data, fingerprint: hash(JSON.stringify(data))};
  };
  return {uid, id, identity, initial, read, event,
    send: (data, options) => submitCourierEvent(db, {auth: identity, data}, options)};
}
for (const status of ["pendingApproval", "rejected", "suspended"]) {
  test(`${status}: real database guard refuses ON and pickup`, async () => {
    const f = await fixture(status);
    await assert.rejects(f.send(f.event("availability", {on: true})), {code: "permission-denied"});
  });
}
test("acceptance uses existing lifecycle, exact public V8 code, deadline and idempotent ACK", async () => {
  const f = await fixture(); const data = f.event();
  const a = await f.send(data); const b = await f.send(data);
  assert.deepEqual(a, b); assert.equal(a.authority, "backend"); assert.equal(a.delivery, null);
  assert.equal(a.pickupAcknowledgement.assignmentId, f.initial.courierAssignmentId);
  const order = await f.read();
  assert.match(order.displayOrderId, /^V8-\d{4,}$/); assert.equal(order.displayOrderId, f.initial.displayOrderId);
  assert.equal(order.courierPickupState, "accepted");
  assert.equal(order.expectedPickupBy.toMillis() - order.acceptedAt.toMillis(), pickupPolicy.pickupMs);
  assert.equal((await db.collection("courierReliabilityEvents").where("orderId", "==", f.id)
      .where("type", "==", "deliveryAccepted").get()).size, 1);
});
test("temporary interruption after lifecycle commit resumes without a duplicate acceptance", async () => {
  const f = await fixture(); const data = f.event();
  await assert.rejects(f.send(data, {afterLifecycle: async () => {
    throw new Error("synthetic interruption");
  }}));
  const acceptedAt = (await f.read()).acceptedAt;
  const ack = await f.send(data);
  assert.equal(ack.pickupAcknowledgement.acknowledged, true);
  assert.ok((await f.read()).acceptedAt.isEqual(acceptedAt));
});
test("decline retry after interruption returns revoked ACK without reactivating the binding", async () => {
  const f = await fixture(); await f.send(f.event());
  const data = f.event("pickupAction", {action: "decline", reason: "Teste de desistência controlada"});
  await assert.rejects(f.send(data, {afterLifecycle: async () => {
    throw new Error("synthetic interruption");
  }}));
  const ack = await f.send(data);
  assert.equal(ack.pickupAcknowledgement.revoked, true);
  assert.equal((await f.read()).courierUid, "");
});
test("revoked/reassigned bindings reject stale acceptance and isolate both couriers", async () => {
  const f = await fixture(); const old = f.event(); await f.send(old);
  await pickupAction(db, {auth: operator, data: {orderId: f.id, assignmentId: f.initial.courierAssignmentId,
    requestId: "f03-admin-revoke-0001", reason: "Homologação de revogação segura"}}, "revoke", true);
  await assert.rejects(f.send(old), (e) => e.details.reason === "ASSIGNMENT_CHANGED");
  const other = await fixture();
  await changeCourier(db, {auth: operator, data: {orderId: f.id, courierUid: other.uid, expectedCourierUid: "",
    requestId: "f03-reassign-other-0001", contingencyReason: "Homologação de reatribuição segura",
    confirmation: `CONFIRMAR ${f.id}`}});
  await assert.rejects(f.send(f.event()), (e) => e.details.reason === "ASSIGNMENT_CHANGED");
  assert.equal((await f.read()).displayOrderId, f.initial.displayOrderId);
});
test("deadline scanner produces overdue/no-show once without payment, stock or automatic reassignment", async () => {
  const f = await fixture(); await f.send(f.event()); const before = await f.read();
  await db.doc(`orders/${f.id}`).update({expectedPickupBy: Timestamp.fromMillis(Date.now() - 360000)});
  assert.equal(await inspectPickup(db, f.id), "pickupOverdue"); await inspectPickup(db, f.id);
  const current = await f.read();
  assert.equal(current.courierUid, f.uid); assert.equal(current.stockReservationStatus, before.stockReservationStatus);
  assert.equal(current.courierPaid, false);
  assert.equal((await db.collection("courierReliabilityEvents").where("orderId", "==", f.id)
      .where("type", "==", "courierNoShow").get()).size, 1);
});
test("foreign UID, event reuse with changed payload and F02 closing state deny new operations", async () => {
  const f = await fixture();
  await assert.rejects(f.send({...f.event(), courierUid: "another"}), {code: "invalid-argument"});
  const original = f.event("availability", {on: true}); await f.send(original);
  const changed = {...original, payload: {on: false}}; delete changed.fingerprint;
  changed.fingerprint = hash(JSON.stringify(changed));
  await assert.rejects(f.send(changed), (e) => e.details.reason === "EVENT_ID_REUSED");
  await requestCourierClosure(db, auth, {auth: f.identity, data: {expectedUid: f.uid,
    requestId: "f03-closure-00000001", confirmation: "EXCLUIR MINHA CONTA", pendingEventIds: []}});
  await assert.rejects(f.send(f.event("availability", {on: true})), {code: "permission-denied"});
});
test("photo receipt verifies real Storage bytes/generation and cannot certify another UID", async () => {
  const f = await fixture();
  const bytes = Buffer.from("89504e470d0a1a0a0000000d49484452000000010000000108060000001f15c489", "hex");
  const reference = `courier-photos/${f.uid}/${hash(bytes)}.png`;
  await storage.file(reference).save(bytes, {metadata: {contentType: "image/png"}});
  const result = await confirmCourierPhoto(db, storage, {auth: f.identity, data: {reference}});
  assert.equal(result.verified, true);
  const receipt = (await db.doc(`courierProfilePhotos/${f.uid}`).get()).data();
  assert.equal(receipt.digest, hash(bytes)); assert.ok(receipt.generation);
  await assert.rejects(confirmCourierPhoto(db, storage, {auth: {...f.identity, uid: "another"}, data: {reference}}),
      {code: "permission-denied"});
});

test("missing or mismatched assignment ledger fails closed without acceptance", async () => {
  const f = await fixture(); const ref = db.doc(`courierPickupAssignments/${f.initial.courierAssignmentId}`);
  await ref.delete();
  await assert.rejects(f.send(f.event()), (e) => e.details.reason === "ASSIGNMENT_CHANGED");
  await ref.set({orderId: f.id, courierUid: "foreign", status: "active"});
  await assert.rejects(f.send(f.event()), (e) => e.details.reason === "ASSIGNMENT_CHANGED");
  assert.equal((await f.read()).acceptedAt, undefined);
});
