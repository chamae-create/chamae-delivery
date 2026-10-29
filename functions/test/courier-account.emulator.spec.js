const assert = require("node:assert/strict");
const {test, before, after} = require("node:test");
const {readFileSync} = require("node:fs");
const {join} = require("node:path");
const {spawnSync} = require("node:child_process");
const {createHash} = require("node:crypto");
const {initializeApp, deleteApp} = require("firebase-admin/app");
const {getAuth} = require("firebase-admin/auth");
const {getFirestore, Timestamp} = require("firebase-admin/firestore");
const {initializeTestEnvironment, assertFails, assertSucceeds} = require("@firebase/rules-unit-testing");
const {doc, getDoc, setDoc, getDocs, collection} = require("firebase/firestore");
const {requestCourierClosure, getCourierClosure, resolveCourierClosure, processCourierClosure,
  resumeCourierClosures, listCourierClosures} = require("../courier-account");
const {courierOperation, ownProfile, reviewCourier} = require("../courier-approval");
const {requestClosure: requestCustomerClosure} = require("../customer-account");
let app; let db; let auth; let environment; let sequence = 0;
const deletedPrefixes = [];
const storage = {deleteFiles: async (options) => deletedPrefixes.push(options.prefix)};
const digest = (ids) => createHash("sha256").update(JSON.stringify(ids)).digest("hex");
before(async () => {
  for (const key of ["FIRESTORE_EMULATOR_HOST", "FIREBASE_AUTH_EMULATOR_HOST"]) {
    assert.match(process.env[key] || "", /^(127\.0\.0\.1|localhost):\d+$/,
        "Local emulators required; no production fallback");
  }
  app = initializeApp({projectId: "demo-chamae-rules"});
  db = getFirestore(app); auth = getAuth(app);
  const address = new URL(`http://${process.env.FIRESTORE_EMULATOR_HOST}`);
  environment = await initializeTestEnvironment({projectId: "demo-chamae-rules", firestore: {
    host: address.hostname, port: Number(address.port),
    rules: readFileSync(join(__dirname, "../../firestore.rules"), "utf8"),
  }});
  await environment.clearFirestore();
});
after(async () => {
  if (environment) await environment.cleanup();
  if (db) await db.terminate();
  if (app) await deleteApp(app);
});
async function fixture(status = "pendingApproval", pendingEventIds = []) {
  const uid = `f02-courier-${++sequence}`;
  await auth.createUser({uid});
  const profile = {role: "courier", approvalStatus: status,
    administrativeState: status === "approved" ? "active" : status,
    enabled: status === "approved", online: true, name: "Synthetic Courier", phone: "67000000000",
    profilePhoto: `courier-photos/${uid}/selfie.png`, vehiclePlate: "TEST0000", driverLicense: "synthetic-cnh",
    vehicleDescription: "Synthetic motorcycle", city: "Fixture City"};
  await db.doc(`couriers/${uid}`).set(profile);
  const identity = {uid, token: {auth_time: Math.floor(Date.now() / 1000),
    firebase: {sign_in_provider: "password"}}};
  const request = {auth: identity, data: {expectedUid: uid,
    confirmation: "EXCLUIR MINHA CONTA", requestId: "f02-request-id-0001", pendingEventIds}};
  const client = environment.authenticatedContext(uid, identity.token).firestore();
  return {uid, profile, identity, request, client, job: () => db.doc(`courierAccountClosures/${uid}`).get(),
    submit: () => requestCourierClosure(db, auth, request),
    process: (options) => processCourierClosure(db, auth, storage, uid, options)};
}
for (const status of ["pendingApproval", "approved", "rejected", "suspended"]) {
  test(`${status}: owner can request deletion independently of operational approval`, async () => {
    const f = await fixture(status);
    const result = await f.submit();
    assert.equal(result.status, "requested"); assert.ok(result.protocol);
    assert.equal((await f.job()).data().status, "requested");
    assert.equal((await db.doc(`couriers/${f.uid}`).get()).data().online, false);
    await f.process();
    assert.equal((await f.job()).data().status, "completed");
    await assert.rejects(auth.getUser(f.uid), {code: "auth/user-not-found"});
  });
}
test("foreign UID and missing reauthentication cannot create a closure", async () => {
  const f = await fixture();
  await assert.rejects(requestCourierClosure(db, auth, {...f.request,
    data: {...f.request.data, expectedUid: "another-uid"}}), {code: "permission-denied"});
  await assert.rejects(requestCourierClosure(db, auth, {...f.request, auth: {...f.identity,
    token: {...f.identity.token, auth_time: 1}}}), (error) => error.details.reason === "REAUTH_REQUIRED");
  assert.equal((await f.job()).exists, false);
});
test("duplicate requests and repeated worker events are idempotent", async () => {
  const f = await fixture();
  const [a, b] = await Promise.all([f.submit(), f.submit()]);
  assert.deepEqual(a, b);
  assert.deepEqual(await getCourierClosure(db, {auth: f.identity, data: {}}), a);
  const beforePrefixes = deletedPrefixes.length;
  await Promise.all([f.process(), f.process()]);
  await f.process();
  assert.equal(deletedPrefixes.length, beforePrefixes + 1);
  assert.equal((await f.job()).data().protocol, a.protocol);
});
test("temporary storage failure retains sanitized retry state and a new worker resumes", async () => {
  const f = await fixture(); await f.submit();
  const failure = {deleteFiles: async () => {
    throw new Error("secret-token-MUST-NOT-LEAK");
  }};
  await assert.rejects(processCourierClosure(db, auth, failure, f.uid), /COURIER_CLOSURE_RETRY_REQUIRED/);
  const job = (await f.job()).data();
  assert.equal(job.status, "processing"); assert.equal(job.lastFailureCode, "RETRY_REQUIRED");
  assert.equal(JSON.stringify(job).includes("secret-token"), false);
  await f.process();
  assert.equal((await f.job()).data().status, "completed");
});
test("active delivery: accepted request, immediate access revocation, escalation and safe resolution", async () => {
  const f = await fixture("approved");
  const order = {courierUid: f.uid, status: "Saiu para Entrega", customerUid: "synthetic-customer",
    totalBRL: 90, courierPaid: false, stockReservationStatus: "reserved"};
  const ref = db.doc(`orders/order-${f.uid}`); await ref.set(order);
  const result = await f.submit(); assert.equal(result.status, "awaiting_operation");
  await f.process({now: () => Date.now() + 86400001});
  assert.ok((await f.job()).data().escalatedAt);
  assert.deepEqual((await ref.get()).data(), order);
  assert.equal((await auth.getUser(f.uid)).disabled, false);
  await assert.rejects(courierOperation(db, {auth: f.identity, data: {operation: "availability", on: true}}),
      {code: "permission-denied"});
  const resolution = {auth: {uid: "f02-operations", token: {roles: ["operations_admin"],
    firebase: {sign_in_provider: "password"}}}, data: {courierUid: f.uid, protocol: result.protocol,
    resolutionReference: "handover-evidence-0001", eventIdsDigest: digest([])}};
  await assert.rejects(resolveCourierClosure(db, resolution), {code: "failed-precondition"});
  // Represents completion by the existing authoritative operational flow, not by the closure worker.
  await ref.update({status: "Concluído"});
  const finalOrder = (await ref.get()).data();
  await resolveCourierClosure(db, resolution); await f.process();
  assert.deepEqual((await ref.get()).data(), finalOrder);
  assert.equal((await f.job()).data().status, "completed");
});
test("pending offline event reconciliation never fabricates a financial or delivery ACK", async () => {
  const f = await fixture("suspended", ["pending-event-001"]);
  const result = await f.submit(); await f.process();
  assert.equal((await f.job()).data().status, "awaiting_operation");
  const request = {auth: {uid: "f02-operator", token: {roles: ["superadmin"],
    firebase: {sign_in_provider: "password"}}}, data: {courierUid: f.uid, protocol: result.protocol,
    resolutionReference: "manual-reconciliation-001", eventIdsDigest: digest(["pending-event-001"])}};
  await assert.rejects(resolveCourierClosure(db, {...request, auth: f.identity}), {code: "permission-denied"});
  const a = await resolveCourierClosure(db, request);
  const b = await resolveCourierClosure(db, request);
  assert.deepEqual(a, b);
  await f.process();
  assert.equal((await f.job()).data().reconciliation.reference, "manual-reconciliation-001");
  assert.equal((await db.collection("courierSettlements").where("courierUid", "==", f.uid).get()).size, 0);
});
test("erases eligible PII, selfie, push and packages; preserves financial/history/customer records", async () => {
  const f = await fixture();
  const retained = {courierUid: f.uid, amountMinor: 12345, currency: "BRL", settled: false};
  await db.doc(`courierSettlements/settlement-${f.uid}`).set(retained);
  await db.doc(`courierApprovalAudit/audit-${f.uid}`).set({courierUid: f.uid, action: "suspend"});
  const customerOrder = {customerUid: "different-customer", status: "Novo", totalBRL: 10};
  await db.doc(`orders/customer-order-${f.uid}`).set(customerOrder);
  for (const collection of ["courierProfilePhotos", "courierDevices", "courierPushTokens", "courierOfflinePackages"]) {
    await db.doc(`${collection}/${f.uid}/private/nested`).set({secret: "synthetic-private"});
    await db.doc(`${collection}/${f.uid}`).set({private: "synthetic-private"});
  }
  for (const collection of ["courierDeliveries", "courierPickupGrants", "courierPickupSessions",
    "courierNotificationOutbox", "courierDeviceTokens"]) {
    await db.doc(`${collection}/owned-${f.uid}`).set({courierUid: f.uid, private: "synthetic-private"});
    await db.doc(`${collection}/foreign-${f.uid}`).set({courierUid: "unrelated"});
  }
  await f.submit(); await f.process();
  assert.ok(deletedPrefixes.includes(`courier-photos/${f.uid}/`));
  const tombstone = (await db.doc(`couriers/${f.uid}`).get()).data();
  assert.equal(tombstone.name, "Motoboy removido");
  assert.equal(JSON.stringify(tombstone).includes(f.profile.name), false);
  for (const field of ["phone", "profilePhoto", "vehiclePlate", "driverLicense", "city",
    "vehicleDescription"]) {
    assert.equal(Object.hasOwn(tombstone, field), false);
  }
  assert.equal(tombstone.accountClosureStatus, "completed");
  for (const collection of ["courierProfilePhotos", "courierDevices", "courierPushTokens", "courierOfflinePackages"]) {
    assert.equal((await db.doc(`${collection}/${f.uid}`).get()).exists, false);
    assert.equal((await db.doc(`${collection}/${f.uid}/private/nested`).get()).exists, false);
  }
  for (const collection of ["courierDeliveries", "courierPickupGrants", "courierPickupSessions",
    "courierNotificationOutbox", "courierDeviceTokens"]) {
    assert.equal((await db.doc(`${collection}/owned-${f.uid}`).get()).exists, false);
    assert.equal((await db.doc(`${collection}/foreign-${f.uid}`).get()).exists, true);
  }
  assert.deepEqual((await db.doc(`courierSettlements/settlement-${f.uid}`).get()).data(), retained);
  assert.deepEqual((await db.doc(`orders/customer-order-${f.uid}`).get()).data(), customerOrder);
  assert.equal((await db.doc(`courierApprovalAudit/audit-${f.uid}`).get()).exists, true);
});
test("old token cannot operate, recreate profile, self-approve or use client closure", async () => {
  const f = await fixture("approved"); await f.submit(); await f.process();
  await assertSucceeds(getDoc(doc(f.client, "courierAccountClosures", f.uid)));
  await assertFails(getDoc(doc(f.client, "courierAccountClosures", "another-uid")));
  await assertFails(getDocs(collection(f.client, "courierAccountClosures")));
  await assertFails(setDoc(doc(f.client, "courierAccountClosures", f.uid), {status: "completed"}));
  await assertFails(getDoc(doc(f.client, "courierDeliveries", "any-delivery")));
  await assertFails(setDoc(doc(f.client, "couriers", f.uid), {approvalStatus: "approved"}));
  await assert.rejects(ownProfile(db, {auth: f.identity, data: {name: "Forged"}}, "update"),
      {code: "failed-precondition"});
  await assert.rejects(reviewCourier(db, {auth: {uid: "f02-reviewer", token: {roles: ["superadmin"]}},
    data: {courierUid: f.uid, action: "approve", expectedStatus: "suspended"}}), {code: "failed-precondition"});
  await assert.rejects(courierOperation(db, {auth: f.identity, data: {operation: "availability", on: true}}),
      {code: "permission-denied"});
  await assert.rejects(requestCustomerClosure(db, {...f.request,
    data: {expectedUid: f.uid, confirmation: "EXCLUIR MINHA CONTA", requestId: "f02-client-guard-0001"}}));
});
test("privileged Auth claims and Apple linkage never silently complete courier deletion", async () => {
  const f = await fixture();
  await auth.setCustomUserClaims(f.uid, {roles: ["superadmin"]});
  await assert.rejects(f.submit(), {code: "permission-denied"});
  await auth.setCustomUserClaims(f.uid, {}); await f.submit();
  const linkedAuth = {getUser: async () => ({customClaims: {}, providerData: [{providerId: "apple.com"}]})};
  await processCourierClosure(db, linkedAuth, storage, f.uid);
  const job = (await f.job()).data();
  assert.equal(job.status, "provider_review_required");
  assert.equal(job.reason, "COURIER_APPLE_ADAPTER_REQUIRED");
  assert.equal(job.completedAt, undefined);
  assert.equal((await auth.getUser(f.uid)).disabled, false);
});
test("process interruption resumes after lease expiry without duplicate financial effects", async () => {
  const f = await fixture(); await f.submit();
  const modulePath = require.resolve("../courier-account");
  const child = `const {initializeApp}=require('firebase-admin/app');
    const {getFirestore}=require('firebase-admin/firestore'); const {getAuth}=require('firebase-admin/auth');
    initializeApp({projectId:'demo-chamae-rules'});
    require(${JSON.stringify(modulePath)}).processCourierClosure(getFirestore(), getAuth(),
      {deleteFiles:async()=>{}}, ${JSON.stringify(f.uid)}, {beforeAuthDelete:async()=>process.exit(42)})
      .then(()=>process.exit(0)).catch(()=>process.exit(2));`;
  const first = spawnSync(process.execPath, ["-e", child], {cwd: join(__dirname, ".."), env: process.env,
    encoding: "utf8", windowsHide: true, timeout: 45000});
  assert.equal(first.status, 42, first.stderr);
  assert.equal((await f.job()).data().status, "processing");
  assert.equal((await auth.getUser(f.uid)).disabled, true);
  await resumeCourierClosures(db, auth, storage, {now: () => Date.now() + 121000});
  assert.equal((await f.job()).data().status, "completed");
  await assert.rejects(auth.getUser(f.uid), {code: "auth/user-not-found"});
});

test("operational backlog is private and does not let a courier with forged role claims resolve itself", async () => {
  const f = await fixture("approved", ["outbox-one"]); await f.submit();
  await assert.rejects(listCourierClosures(db, {auth: f.identity, data: {}}), {code: "permission-denied"});
  await assert.rejects(listCourierClosures(db, {auth: {...f.identity,
    token: {...f.identity.token, roles: ["superadmin"]}}, data: {}}), {code: "permission-denied"});
  const page = await listCourierClosures(db, {auth: {uid: "f02-backlog-operator",
    token: {roles: ["operations_admin"]}}, data: {}});
  assert.ok(page.requests.some((r) => r.courierUid === f.uid && r.status === "awaiting_operation"));
  assert.equal(JSON.stringify(page).includes("Synthetic Courier"), false);
});
test("large closed order history does not cause an indefinite active-delivery hold", async () => {
  const f = await fixture();
  const batch = db.batch();
  for (let i = 0; i < 205; i++) {
    batch.set(db.doc(`orders/history-${f.uid}-${i}`),
        {courierUid: f.uid, status: "Concluído", totalBRL: 10});
  }
  await batch.commit();
  assert.equal((await f.submit()).status, "requested");
  await f.process();
  assert.equal((await f.job()).data().status, "completed");
  assert.equal((await db.collection("orders").where("courierUid", "==", f.uid).get()).size, 205);
});

test("large offline outbox can initiate deletion with a bounded manifest and cannot skip reconciliation", async () => {
  const ids = Array.from({length: 350}, (_, i) => `event-${i}`);
  const f = await fixture("rejected", ids.slice(0, 200));
  f.request.data.pendingEventManifest = {count: ids.length, digest: digest(ids)};
  const result = await f.submit();
  assert.equal(result.status, "awaiting_operation");
  assert.equal(result.pendingEventCount, 350);
  await f.process();
  assert.equal((await f.job()).data().status, "awaiting_operation");
  const request = {auth: {uid: "f02-large-outbox-operator", token: {roles: ["superadmin"]}},
    data: {courierUid: f.uid, protocol: result.protocol, resolutionReference: "reconciled-350-events",
      eventIdsDigest: digest(ids.slice(0, 200))}};
  await assert.rejects(resolveCourierClosure(db, request), {code: "failed-precondition"});
  request.data.eventIdsDigest = digest(ids);
  await resolveCourierClosure(db, request); await f.process();
  assert.equal((await f.job()).data().status, "completed");
});

test("existing financial handler can settle a closed courier once without restoring personal name", async () => {
  const f = await fixture("approved");
  const id = `unpaid-${f.uid}`;
  const amounts = {itemsTotal: 20, deliveryFee: 10, customerFee: 0.6, merchantFee: 0,
    merchantNet: 20, platformFee: 0.6, totalBRL: 30.6};
  const financial = {...amounts, items: [{id: "synthetic-item", quantity: 1, price: 20}],
    totalCentavos: 3060, version: 1};
  const order = {...amounts, id, courierUid: f.uid, status: "Concluído",
    completedAt: Timestamp.now(), paymentStatus: "Pago", financialValidationStatus: "validated",
    stockReservationStatus: "finalized", courierPaid: false,
    itemsList: [{id: "synthetic-item", quantity: 1, price: 20}]};
  await db.doc(`orders/${id}`).set(order);
  await db.doc(`orderFinancials/${id}`).set(financial);
  await f.submit(); await f.process();
  const backend = require("./backend-fixture").loadBackend(db);
  const request = {auth: {uid: "f02-finance-operator", token: {roles: ["finance"]}},
    data: {orderDocumentIds: [id], requestId: "f02-settlement-after-closure"}};
  const settle = backend.functions.chamaeRegistrarAcertoMotoboy;
  const first = await settle(request);
  const retry = await settle(request);
  assert.equal(first.replayed, false); assert.equal(retry.replayed, true);
  assert.equal(first.settlementId, retry.settlementId);
  await assert.rejects(settle({...request, data: {...request.data, requestId: "f02-new-settlement-key"}}),
      {code: "failed-precondition"});
  const receipt = (await db.doc(`courierSettlements/${first.settlementId}`).get()).data();
  assert.equal(receipt.total, 10);
  assert.equal(receipt.courierUid, f.uid);
  assert.equal(receipt.courierName, "Motoboy removido");
  assert.equal((await db.doc(`orders/${id}`).get()).data().courierPaid, true);
  assert.deepEqual((await db.doc(`orderFinancials/${id}`).get()).data(), financial);
  assert.equal((await db.doc(`couriers/${f.uid}`).get()).data().administrativeState, "closed");
});
