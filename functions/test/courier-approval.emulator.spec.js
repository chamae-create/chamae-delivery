const assert = require("node:assert/strict");
const fs = require("node:fs");
const path = require("node:path");
const {before, after, test} = require("node:test");
const {initializeApp, deleteApp} = require("firebase-admin/app");
const {getFirestore, Timestamp} = require("firebase-admin/firestore");
const {initializeTestEnvironment, assertFails} = require("@firebase/rules-unit-testing");
const {doc, getDoc, getDocs, collection, setDoc, updateDoc, deleteDoc} = require("firebase/firestore");
const {ownProfile, reviewCourier, courierOperation} = require("../courier-approval");
const {isAssignableCourier} = require("../courier-deliveries");
const {changeCourier} = require("../courier-assignment");
let app; let db; let environment; let sequence = 0;
const auth = (uid, roles = []) => ({uid, token: {email_verified: true, roles,
  firebase: {sign_in_provider: "password"}}});
const operator = auth("reviewer", ["superadmin"]);
const fields = {profilePhoto: "fixture-selfie", name: "Ana Exemplo", phone: "67900000000", city: "Ponta Pora",
  vehicleType: "motorcycle"};
const {seedCourierPolicy} = require("./courier-policy-fixture");
const denied = (code) => (error) => error.code === code;
before(async () => {
  const host = process.env.FIRESTORE_EMULATOR_HOST;
  assert.ok(host, "Local emulator required. No production fallback.");
  const address = new URL(`http://${host}`);
  assert.ok(["localhost", "127.0.0.1", "[::1]"].includes(address.hostname));
  environment = await initializeTestEnvironment({projectId: "demo-chamae-rules", firestore: {
    host: address.hostname, port: Number(address.port),
    rules: fs.readFileSync(path.join(__dirname, "../../firestore.rules"), "utf8"),
  }});
  await environment.clearFirestore();
  app = initializeApp({projectId: "demo-chamae-rules"}, "approval-tests");
  db = getFirestore(app);
});
after(async () => {
  if (environment) await environment.cleanup();
  if (db) await db.terminate();
  if (app) await deleteApp(app);
});
async function applicant() {
  const uid = `applicant-${++sequence}`;
  const identity = auth(uid);
  await seedCourierPolicy(db, uid, Timestamp.now());
  await db.doc(`courierProfilePhotos/${uid}`).set({verified: true, reference: fields.profilePhoto});
  const profile = await ownProfile(db, {auth: identity, data: fields}, "register");
  const ref = db.doc(`couriers/${uid}`);
  const read = async () => (await ref.get()).data();
  const review = (action, expectedStatus, reason, actor = operator) => reviewCourier(db,
      {auth: actor, data: {courierUid: uid, action, expectedStatus, ...(reason === undefined ? {} : {reason})}});
  const operation = (operation, extra = {}) => courierOperation(db,
      {auth: identity, data: {operation, ...extra}});
  const client = environment.authenticatedContext(uid, identity.token).firestore();
  return {uid, identity, profile, ref, read, review, operation, client};
}
test("new registration is pending, timestamps official; retries and edits preserve decisions", async () => {
  const f = await applicant();
  assert.equal(f.profile.approvalStatus, "pendingApproval");
  const original = await f.read();
  assert.equal(original.enabled, false);
  assert.ok(original.createdAt instanceof Timestamp);
  assert.ok(original.updatedAt instanceof Timestamp);
  await f.review("reject", "pendingApproval", "Fora da operação");
  await ownProfile(db, {auth: f.identity, data: fields}, "register");
  await ownProfile(db, {auth: f.identity, data: {name: "Ana Atualizada"}}, "update");
  const current = await f.read();
  assert.equal(current.approvalStatus, "rejected");
  assert.equal(current.name, "Ana Atualizada");
  assert.ok(current.createdAt.isEqual(original.createdAt));
  assert.equal(current.rejectedBy, operator.uid);
  assert.ok(current.rejectedAt instanceof Timestamp);
  assert.equal(current.rejectionReason, "Fora da operação");
  const own = await ownProfile(db, {auth: f.identity, data: {}});
  assert.equal(Object.hasOwn(own, "rejectionReason"), false);
  assert.equal(Object.hasOwn(own, "rejectedBy"), false);
});
test("self approval, SDK audit/status writes and arbitrary fields are denied", async () => {
  const f = await applicant();
  await assert.rejects(f.review("approve", "pendingApproval", undefined, f.identity), denied("permission-denied"));
  for (const operation of ["register", "update"]) {
    for (const key of ["approvalStatus", "approvedBy", "approvedAt", "rejectedBy", "rejectedAt",
      "suspendedBy", "suspendedAt", "enabled", "courierUid", "rejectionReason", "suspensionReason"]) {
      await assert.rejects(ownProfile(db, {auth: f.identity, data: {...fields, [key]: "forged"}}, operation),
          denied("invalid-argument"));
      await assertFails(updateDoc(doc(f.client, "couriers", f.uid), {[key]: "forged"}));
    }
  }
  await assertFails(setDoc(doc(f.client, "couriers", "new-forged"), {...fields, role: "courier",
    approvalStatus: "approved"}));
  await assertFails(deleteDoc(doc(f.client, "couriers", f.uid)));
  await assertFails(getDoc(doc(f.client, "couriers", f.uid)));
  await assertFails(getDocs(collection(f.client, "couriers")));
  await assertFails(getDoc(doc(f.client, "couriers", "someone-else")));
});
for (const status of ["pendingApproval", "rejected", "suspended"]) {
  test(`${status}: direct protected operations and customer data denied`, async () => {
    const f = await applicant();
    if (status === "rejected") await f.review("reject", "pendingApproval", "Cadastro duplicado");
    if (status === "suspended") {
      await f.review("approve", "pendingApproval");
      await f.review("suspend", "approved", "Decisão administrativa");
    }
    for (const operation of ["availability", "deliveries", "acceptDelivery", "startRoute", "pickedUp",
      "arrived", "confirmDelivery", "validatePin", "validateQr", "startShift", "settlement"]) {
      await assert.rejects(f.operation(operation, {on: true}), denied("permission-denied"));
    }
    assert.equal(isAssignableCourier(await f.read()), false);
    const id = `protected-${f.uid}`;
    await db.doc(`courierDeliveries/${id}`).set({orderId: id, courierUid: f.uid, customerName: "Cliente",
      status: "assigned"});
    await assertFails(getDoc(doc(f.client, "courierDeliveries", id)));
    await assertFails(getDocs(collection(f.client, "courierDeliveries")));
    await assertFails(getDoc(doc(f.client, "orders", id)));
    // Existing assignment callable also checks the same authoritative profile.
    await db.doc(`orders/${id}`).set({status: "Novo", financialValidationStatus: "validated"});
    await assert.rejects(changeCourier(db, {auth: operator, data: {orderId: id, courierUid: f.uid,
      requestId: "test-approval-assignment", contingencyReason: "Falha do aparelho do motoboy",
      confirmation: `CONFIRMAR ${id}`}}), denied("failed-precondition"));
  });
}
test("audit and suspension revoke existing-token reads without changing active order", async () => {
  const f = await applicant();
  await f.review("approve", "pendingApproval");
  const profile = await f.read();
  assert.equal(profile.approvedBy, operator.uid);
  assert.ok(profile.approvedAt instanceof Timestamp);
  assert.equal(isAssignableCourier(profile), true);
  await f.operation("availability", {on: true});
  assert.equal((await f.read()).online, true);
  const orderId = `active-${f.uid}`;
  const active = {status: "Saiu para Entrega", courierUid: f.uid};
  await db.doc(`orders/${orderId}`).set(active);
  await db.doc(`courierDeliveries/${orderId}`).set({orderId, courierUid: f.uid,
    customerName: "Nome Exemplo", status: "Saiu para Entrega"});
  await assertFails(getDoc(doc(f.client, "courierDeliveries", orderId)));
  await assert.rejects(f.review("suspend", "approved", ""), denied("invalid-argument"));
  await f.review("suspend", "approved", "Suspensão administrativa");
  await assertFails(getDoc(doc(f.client, "courierDeliveries", orderId)));
  await assert.rejects(f.operation("availability", {on: true}), denied("permission-denied"));
  assert.deepEqual((await db.doc(`orders/${orderId}`).get()).data(), active);
  const suspended = await f.read();
  assert.equal(suspended.online, false);
  assert.equal(suspended.suspendedBy, operator.uid);
  assert.equal(suspended.suspensionReason, "Suspensão administrativa");
  assert.ok(suspended.suspendedAt instanceof Timestamp);
  const audits = await db.collection("courierApprovalAudit").where("courierUid", "==", f.uid).get();
  assert.equal(audits.size, 2);
  for (const row of audits.docs) {
    assert.equal(row.data().actorUid, operator.uid);
    assert.ok(row.data().createdAt instanceof Timestamp);
    await assertFails(getDoc(doc(f.client, "courierApprovalAudit", row.id)));
    await assertFails(setDoc(doc(f.client, "courierApprovalAudit", row.id), {action: "approve"}));
  }
  await f.review("approve", "suspended");
  await f.operation("availability", {on: true});
  const reactivated = await f.read();
  assert.equal(reactivated.approvalStatus, "approved");
  assert.ok(reactivated.suspendedAt instanceof Timestamp, "history retained");
  await assert.rejects(f.operation("confirmDelivery"), denied("failed-precondition"), "no invented operational ACK");
});
test("ordinary, anonymous, operations admin and dual courier/admin cannot review third parties", async () => {
  const f = await applicant();
  for (const actor of [auth("ordinary"), auth("ops", ["operations_admin"]),
    auth("finance", ["finance"]), {uid: "anonymous", token: {roles: ["superadmin"],
      firebase: {sign_in_provider: "anonymous"}}}]) {
    await assert.rejects(f.review("approve", "pendingApproval", undefined, actor),
        (e) => ["permission-denied", "unauthenticated"].includes(e.code));
  }
  const dual = await applicant();
  await assert.rejects(f.review("approve", "pendingApproval", undefined, auth(dual.uid, ["superadmin"])),
      denied("permission-denied"));
  assert.equal((await f.read()).approvalStatus, "pendingApproval");
});
test("concurrent approve/reject uses expected status and creates exactly one audit", async () => {
  const f = await applicant();
  const results = await Promise.allSettled([
    f.review("approve", "pendingApproval"), f.review("reject", "pendingApproval", "Cadastro duplicado"),
  ]);
  assert.equal(results.filter((r) => r.status === "fulfilled").length, 1);
  assert.equal(results.filter((r) => r.status === "rejected").length, 1);
  const audit = await db.collection("courierApprovalAudit").where("courierUid", "==", f.uid).get();
  assert.equal(audit.size, 1);
});
test("closed accounts cannot enroll, edit, approve or operate", async () => {
  const f = await applicant();
  await f.review("approve", "pendingApproval");
  await db.doc(`customerAccountClosures/${f.uid}`).set({status: "requested"});
  await assert.rejects(f.operation("availability", {on: true}), denied("failed-precondition"));
  for (const operation of ["get", "register", "update"]) {
    await assert.rejects(ownProfile(db, {auth: f.identity, data: operation === "get" ? {} : fields}, operation),
        denied("failed-precondition"));
  }
  await assert.rejects(f.review("suspend", "approved", "Conta encerrada"), denied("failed-precondition"));
});
