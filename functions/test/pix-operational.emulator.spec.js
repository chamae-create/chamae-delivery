const {test, before, after} = require("node:test");
const assert = require("node:assert/strict");
const {createHash, generateKeyPairSync} = require("node:crypto");
const {initializeApp, deleteApp} = require("firebase-admin/app");
const {getAuth} = require("firebase-admin/auth");
const {getFirestore, Timestamp} = require("firebase-admin/firestore");
const {createPaidPixOrder} = require("./pix-operational-fixture");
const {seedCourierPolicy} = require("./courier-policy-fixture");
const {ownProfile} = require("../courier-approval");
const {loadBackend} = require("./backend-fixture");
const {createCourierPickupFunctions, issueTicket, signTicket, verifyTicket, beginPickup} = require("../courier-pickup");
const {createPickupLifecycleFunctions, pickupAction} = require("../courier-pickup-lifecycle");
const {createCourierApprovalFunctions} = require("../courier-approval");
const {createDeliveryContingency} = require("../delivery-contingency");
const {changeCourier} = require("../courier-assignment");
const {submitCourierEvent} = require("../courier-events");
let app; let db; let auth;
const prefix = "pix-sprint-" + Date.now();
const customerUid = prefix + "-customer"; const courierUid = prefix + "-courier";
const operatorUid = prefix + "-admin"; const orderId = prefix + "-order";
const identity = {uid: courierUid, token: {email_verified: true, firebase: {sign_in_provider: "password"}}};
const admin = {uid: operatorUid, token: {roles: ["superadmin"]}};
before(async () => {
  assert.match(process.env.FIRESTORE_EMULATOR_HOST || "", /^(127\.0\.0\.1|localhost):[0-9]+$/);
  assert.match(process.env.FIREBASE_AUTH_EMULATOR_HOST || "", /^(127\.0\.0\.1|localhost):[0-9]+$/);
  app = initializeApp({projectId: "demo-chamae-rules"}); db = getFirestore(app); auth = getAuth(app);
  await auth.createUser({uid: customerUid, email: customerUid + "@pix.invalid", password: "Pix-Test-Only-928!",
    emailVerified: true});
  await auth.setCustomUserClaims(customerUid, {customerVerified: true});
  await db.doc("couriers/" + courierUid).set({role: "courier", approvalStatus: "approved",
    administrativeState: "active", enabled: true, online: true, name: "TEST COURIER", phone: "67000000000"});
  await seedCourierPolicy(db, courierUid, Timestamp.now());
});
after(async () => {
  if (db) await db.terminate(); if (app) await deleteApp(app);
});
function event(action = "accept") {
  return db.doc("orders/" + orderId).get().then((snapshot) => {
    const payload = {assignmentId: snapshot.data().courierAssignmentId, protocolVersion: 2,
      eventId: prefix + "-event-" + action, orderId, courierUid, type: "pickupAction", localTimestampMs: Date.now(),
      sequence: 1, payload: {action}};
    return {...payload, fingerprint: createHash("sha256").update(JSON.stringify(payload)).digest("hex")};
  });
}
test("PIX SDK customer -> real validator/HMAC/payment -> assignment -> Moto backend ACK is integrated", async () => {
  const proof = await createPaidPixOrder({db, customerUid, courierUid, operatorUid, orderId,
    customerEmail: customerUid + "@pix.invalid", customerPassword: "Pix-Test-Only-928!"});
  assert.equal(proof.blockedAssignmentBeforePayment, true); assert.equal(proof.providerSandbox, false);
  assert.equal(proof.provider, "MOCK_IN_TEST_ONLY"); assert.equal(proof.amounts.totalBRL, 70.60);
  await changeCourier(db, {auth: admin, data: {orderId, courierUid, requestId: prefix + "-assignment-paid",
    contingencyReason: "TEST ONLY PAID ORDER ASSIGNMENT", confirmation: "CONFIRMAR " + orderId}});
  const data = await event(); const before = (await db.doc("orderFinancials/" + orderId).get()).data();
  const first = await submitCourierEvent(db, {auth: identity, data});
  assert.deepEqual(await submitCourierEvent(db, {auth: identity, data}), first);
  assert.equal(first.authority, "backend"); assert.equal(first.pickupAcknowledgement.acknowledged, true);
  const current = (await db.doc("orders/" + orderId).get()).data();
  assert.equal(current.courierPickupState, "accepted"); assert.equal(current.paymentStatus, "Pago");
  assert.deepEqual((await db.doc("orderFinancials/" + orderId).get()).data(), before);
  console.log("PIX_INTEGRATED_PROOF " + JSON.stringify({...proof, courierAck: true, duplicateAckIdempotent: true}));
});
test("the five PWA callable exports use the expected region and enforce Auth at their real boundary", async () => {
  const exports = {...createCourierPickupFunctions(db), ...createPickupLifecycleFunctions(db),
    ...createCourierApprovalFunctions(db), ...createDeliveryContingency(db)};
  const requests = {chamaeEmitirTicketRetirada: {orderId}, chamaeDarMaisTempoRetirada: {orderId},
    chamaeRevogarRetirada: {orderId}, chamaeRevisarCadastroMotoboy: {courierUid},
    chamaeRegistrarContingenciaEntrega: {orderId}};
  for (const [name, data] of Object.entries(requests)) {
    assert.deepEqual(exports[name].__endpoint.region, ["southamerica-east1"]);
    await assert.rejects(exports[name].run({auth: null, data}),
        (error) => ["unauthenticated", "permission-denied"].includes(error.code), name);
  }
});
test("ticket signs with real Ed25519 only through an injected signer; default callable fails closed", async () => {
  const keys = generateKeyPairSync("ed25519");
  const issued = await issueTicket(db, {auth: admin, data: {orderId}}, {
    sign: async (value) => signTicket(value, keys.privateKey)});
  const ticket = verifyTicket(issued.ticket, keys.publicKey);
  assert.equal(ticket.orderId, orderId); assert.equal(ticket.courierUid, courierUid);
  const bindingRef = db.doc("courierPickupAssignments/" + ticket.assignmentId);
  const originalBinding = (await bindingRef.get()).data();
  await bindingRef.delete();
  try {
    await assert.rejects(beginPickup(db, {auth: identity, data: {ticket: issued.ticket}}, {
      publicKey: async () => keys.publicKey,
      package: async () => assert.fail("Missing authoritative binding must block before any package download"),
    }), {code: "failed-precondition"});
  } finally {
    await bindingRef.set(originalBinding);
  }

  await assert.rejects(createCourierPickupFunctions(db).chamaeEmitirTicketRetirada.run({auth: admin,
    data: {orderId}}), (error) => error.code === "failed-precondition");
});
test("extend/revoke are idempotent and a missing/mismatched binding cannot be accepted or extended", async () => {
  const ref = db.doc("orders/" + orderId); const current = (await ref.get()).data();
  const call = (action, requestId, reason) => pickupAction(db, {auth: admin,
    data: {orderId, assignmentId: current.courierAssignmentId, requestId, ...(reason ? {reason} : {})}}, action, true);
  const binding = db.doc("courierPickupAssignments/" + current.courierAssignmentId);
  const original = (await binding.get()).data(); await binding.delete();
  await assert.rejects(call("extend", prefix + "-missing-binding"));
  await assert.rejects(pickupAction(db, {auth: identity, data: {orderId,
    assignmentId: current.courierAssignmentId, requestId: prefix + "-missing-accept"}}, "accept"));
  await binding.set({...original, courierUid: "foreign-courier"});
  await assert.rejects(call("extend", prefix + "-foreign-binding"));
  await binding.set(original);
  const extended = await call("extend", prefix + "-extension-valid");
  assert.equal((await call("extend", prefix + "-extension-valid")).replayed, true);
  assert.ok(extended.expectedPickupByMs > current.expectedPickupBy.toMillis());
  await call("revoke", prefix + "-revocation-valid", "TEST ONLY REVOKE");
  assert.equal((await call("revoke", prefix + "-revocation-valid", "TEST ONLY REVOKE")).replayed, true);
  assert.equal((await binding.get()).data().status, "revoked");
  assert.equal((await ref.get()).data().courierUid, "");
});


test("review callable enforces expected status, backend policy/photo checks and private audit", async () => {
  const uid = prefix + "-applicant";
  const requestAuth = {uid, token: {firebase: {sign_in_provider: "password"}, email_verified: false}};
  await seedCourierPolicy(db, uid, Timestamp.now());
  await db.doc("courierProfilePhotos/" + uid).set({verified: true, reference: "TEST-VERIFIED-PHOTO"});
  await ownProfile(db, {auth: requestAuth, data: {name: "TEST APPLICANT", phone: "67000000001",
    profilePhoto: "TEST-VERIFIED-PHOTO"}}, "register");
  const callable = createCourierApprovalFunctions(db).chamaeRevisarCadastroMotoboy;
  const data = {courierUid: uid, action: "approve", expectedStatus: "pendingApproval"};
  await assert.rejects(callable.run({auth: requestAuth, data}), {code: "permission-denied"});
  const policyRef = db.doc("courierPolicies/current"); const policy = (await policyRef.get()).data();
  await policyRef.update({draft: true});
  await assert.rejects(callable.run({auth: admin, data}),
      (error) => error.details.reason === "COURIER_POLICY_UNAVAILABLE");
  await policyRef.set(policy); await callable.run({auth: admin, data});
  await assert.rejects(callable.run({auth: admin, data}), {code: "failed-precondition"});
  const profile = (await db.doc("couriers/" + uid).get()).data();
  assert.equal(profile.approvalStatus, "approved"); assert.equal(profile.online, false);
  const audit = await db.collection("courierApprovalAudit").where("courierUid", "==", uid).get();
  assert.equal(audit.size, 1); assert.equal(audit.docs[0].data().actorUid, operatorUid);
});
test("contingency is revisioned/idempotent; SDK Rules protect incidents and financial writes", async () => {
  const {initializeApp: sdkApp, deleteApp: closeApp} = require("firebase/app");
  const {getAuth: sdkAuth, connectAuthEmulator, signInWithEmailAndPassword} = require("firebase/auth");
  const {getFirestore: sdkDb, connectFirestoreEmulator, doc, getDoc, updateDoc, terminate} =
    require("firebase/firestore");
  const backend = loadBackend(db).functions;
  await backend.chamaeIniciarSeparacao({auth: admin, data: {orderId, requestId: prefix + "-separate"}});
  const financial = (await db.doc("orderFinancials/" + orderId).get()).data();
  const stock = (await db.doc("products/" + orderId + "-product").get()).data();
  const callable = createDeliveryContingency(db).chamaeRegistrarContingenciaEntrega;
  const data = {orderId, requestId: prefix + "-contingency", contingencyReason: "TEST ONLY NO CUSTOMER RESPONSE",
    confirmation: "CONFIRMAR " + orderId, action: "attempt", expectedStatus: "Em Separação",
    expectedRevision: 0, reasonCode: "no_answer"};
  await assert.rejects(callable.run({auth: identity, data}), {code: "permission-denied"});
  const first = await callable.run({auth: admin, data}); assert.equal(first.revision, 1);
  assert.equal((await callable.run({auth: admin, data})).replayed, true);
  await assert.rejects(callable.run({auth: admin, data: {...data, requestId: prefix + "-stale-incident"}}),
      {code: "aborted"});
  assert.equal((await db.collection("orderDeliveryIncidents/" + orderId + "/events").get()).size, 1);
  assert.deepEqual((await db.doc("orderFinancials/" + orderId).get()).data(), financial);
  assert.deepEqual((await db.doc("products/" + orderId + "-product").get()).data(), stock);
  const clientApp = sdkApp({projectId: "demo-chamae-rules", apiKey: "emulator-only-key",
    appId: "1:000000:web:private-rules-test"}, prefix + "-rules-sdk");
  const clientAuth = sdkAuth(clientApp);
  connectAuthEmulator(clientAuth, "http://" + process.env.FIREBASE_AUTH_EMULATOR_HOST, {disableWarnings: true});
  const clientDb = sdkDb(clientApp); const [host, port] = process.env.FIRESTORE_EMULATOR_HOST.split(":");
  connectFirestoreEmulator(clientDb, host, Number(port));
  try {
    await signInWithEmailAndPassword(clientAuth, customerUid + "@pix.invalid", "Pix-Test-Only-928!");
    await assert.rejects(updateDoc(doc(clientDb, "orders", orderId), {paymentStatus: "Pago"}),
        (error) => error.code === "permission-denied");
    await assert.rejects(getDoc(doc(clientDb, "orderDeliveryIncidents", orderId)),
        (error) => error.code === "permission-denied");
    await assert.rejects(getDoc(doc(clientDb, "courierApprovalAudit", "foreign-audit")),
        (error) => error.code === "permission-denied");
  } finally {
    await clientAuth.signOut(); await terminate(clientDb); await closeApp(clientApp);
  }
});
