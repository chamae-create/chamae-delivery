const {before, after, test} = require("node:test");
const assert = require("node:assert/strict");
const fs = require("node:fs");
const path = require("node:path");
const {initializeApp, deleteApp} = require("firebase-admin/app");
const {getFirestore} = require("firebase-admin/firestore");
const {getAuth} = require("firebase-admin/auth");
const {initializeTestEnvironment, assertFails, assertSucceeds} = require("@firebase/rules-unit-testing");
const {doc, getDoc, getDocs, collection, setDoc, serverTimestamp} = require("firebase/firestore");
const {requestClosure, processClosure} = require("../customer-account");
const {assertCustomerAccountActive} = require("../customer-account-state");
const {quoteDelivery, discardProposal} = require("../delivery-service");
const {ownPin} = require("../customer-security");
const {chatOperation} = require("../order-chat");

let app; let db; let auth; let env;
const request = (uid, token = {}, data = {}) => ({auth: {uid, token: {
  firebase: {sign_in_provider: "google.com"}, auth_time: Date.now() / 1000, ...token,
}}, data: {confirmation: "EXCLUIR MINHA CONTA", expectedUid: uid, requestId: "test-request-0001", ...data}});
const client = (uid) => env.authenticatedContext(uid, {
  firebase: {sign_in_provider: "google.com"},
}).firestore();
const status = async (uid) => (await db.doc(`customerAccountClosures/${uid}`).get()).data();
const done = (uid, countryCode = "BR") => ({customerUid: uid, customerName: "Synthetic Customer",
  customerPhone: "TEST-ONLY", address: "TEST-ONLY", deliveryAddress: {countryCode},
  status: "Concluído", paymentStatus: "Pago", financialValidationStatus: "validated",
  stockReservationStatus: "finalized", stockProcessingStatus: "completed", totalBRL: 23.45,
  deliveryFee: 2.45, itemsList: [{id: "synthetic", quantity: 1}],
  deliverySnapshot: {destination: {latitude: -20, longitude: -50}, distanceMeters: 1200,
    unit: "m", version: "TEST-ONLY", appliedBand: {id: "TEST-ONLY", priceCents: 245}}});

before(async () => {
  for (const name of ["FIRESTORE_EMULATOR_HOST", "FIREBASE_AUTH_EMULATOR_HOST"]) {
    assert.ok(process.env[name], `${name} mandatory; no production fallback`);
    assert.ok(["127.0.0.1", "localhost", "[::1]"].includes(new URL(`http://${process.env[name]}`).hostname));
  }
  env = await initializeTestEnvironment({projectId: "demo-chamae-rules", firestore: {
    host: "127.0.0.1", port: 8187,
    rules: fs.readFileSync(path.join(__dirname, "../../firestore.rules"), "utf8"),
  }});
  await env.clearFirestore();
  app = initializeApp({projectId: "demo-chamae-rules"}); db = getFirestore(app); auth = getAuth(app);
});
after(async () => {
  if (env) await env.cleanup();
  if (db) await db.terminate();
  if (app) await deleteApp(app);
});

test("recent identity, future token, administrative and courier accounts fail safely", async () => {
  const now = Date.now();
  for (const authTime of [undefined, now / 1000 - 301, now / 1000 + 61]) {
    await assert.rejects(requestClosure(db, request("stale", {auth_time: authTime}), now), {code: "unauthenticated"});
  }
  await db.doc("couriers/rider").set({administrativeState: "inactive"});
  await assert.rejects(requestClosure(db, request("rider")), {code: "permission-denied"});
  assert.equal(await status("stale"), undefined);
});

test("active order blocks request; unknown/unsafe terminal order blocks worker before any erasure", async () => {
  await db.doc("orders/active").set({...done("active"), status: "Novo"});
  await db.doc("customerProfiles/active").set({birthDate: "2000-01-01"});
  await assert.rejects(requestClosure(db, request("active")), {code: "failed-precondition"});
  assert.equal(await status("active"), undefined);
  for (const [uid, extra] of [["unknown", {status: "UNRECOGNIZED"}],
    ["review", {stockProcessingStatus: "requires_review"}],
    ["pix", {status: "Cancelado", mercadoPagoOrderId: "pending-payment"}]]) {
    await db.doc(`orders/${uid}`).set({...done(uid), ...extra});
    await db.doc(`customerProfiles/${uid}`).set({birthDate: "2000-01-01"});
    await requestClosure(db, request(uid));
    await processClosure(db, auth, uid);
    assert.equal((await status(uid)).status, "blocked");
    assert.equal((await db.doc(`customerProfiles/${uid}`).get()).exists, true);
    await assertCustomerAccountActive(db, uid);
    await assertSucceeds(getDoc(doc(client(uid), `customerProfiles/${uid}`)));
    await db.doc(`orders/${uid}`).set(done(uid));
    await requestClosure(db, request(uid));
    await processClosure(db, auth, uid);
    assert.equal((await status(uid)).status, "completed");
  }
});

for (const country of ["BR", "PY"]) {
  test(`${country}: erase personal data; preserve money, distance, stock and other UID`, async () => {
    const uid = `customer-${country}`; const id = `closed-${country}`;
    await auth.createUser({uid, email: `${uid}@example.test`});
    const order = done(uid, country);
    await db.doc(`orders/${id}`).set(order);
    const financial = {totalBRL: 23.45, deliveryFee: 2.45, totalCentavos: 2345,
      deliverySnapshot: order.deliverySnapshot, items: order.itemsList};
    await db.doc(`orderFinancials/${id}`).set(financial);
    await db.doc(`orderChats/${id}/messages/private`).set({text: "TEST PERSONAL DATA"});
    await db.doc(`courierDeliveries/${id}`).set({customerName: order.customerName});
    await db.doc(`deliveryPinVerifiers/${id}`).set({hash: "TEST PIN"});
    for (const col of ["customerProfiles", "customerWorkspaces", "customerDeliverySecrets",
      "customerConsentEvents", "customerOrderCancellations"]) {
      await db.doc(`${col}/${uid}`).set({private: true});
      await db.doc(`${col}/${uid}/events/nested`).set({birthDate: "2000-01-01"});
    }
    for (const [col, field] of [["deliveryQuotes", "uid"], ["deliveryPinAudit", "uid"],
      ["reviews", "customerUid"]]) await db.doc(`${col}/${uid}`).set({[field]: uid, private: true});
    await db.doc("products/account-stock").set({stock: 99, reservedStock: 0});
    await db.doc("customerProfiles/untouched").set({birthDate: "1990-01-01"});
    assert.deepEqual(await requestClosure(db, request(uid)), {status: "requested"});
    const first = await status(uid);
    assert.deepEqual(await requestClosure(db, request(uid, {auth_time: 0})), {status: "requested"});
    assert.equal((await status(uid)).requestedAt.toMillis(), first.requestedAt.toMillis());
    await processClosure(db, auth, uid);
    const completed = await status(uid);
    assert.equal(completed.status, "completed");
    await assert.rejects(auth.getUser(uid), {code: "auth/user-not-found"});
    const redacted = (await db.doc(`orders/${id}`).get()).data();
    assert.match(redacted.customerUid, /^deleted_[a-f0-9]{64}$/);
    assert.equal(redacted.customerPhone, undefined); assert.equal(redacted.address, undefined);
    assert.equal(redacted.deliveryAddress, undefined); assert.equal(redacted.deliverySnapshot.destination, undefined);
    assert.equal(redacted.totalBRL, order.totalBRL); assert.deepEqual(redacted.itemsList, order.itemsList);
    const retainedRoute = {...order.deliverySnapshot}; delete retainedRoute.destination;
    assert.deepEqual((await db.doc(`orderFinancials/${id}`).get()).data(),
        {...financial, deliverySnapshot: retainedRoute});
    for (const ref of [`orderChats/${id}/messages/private`, `courierDeliveries/${id}`,
      `deliveryPinVerifiers/${id}`, `customerProfiles/${uid}`, `customerWorkspaces/${uid}`,
      `customerConsentEvents/${uid}/events/nested`, `customerDeliverySecrets/${uid}`,
      `deliveryQuotes/${uid}`, `deliveryPinAudit/${uid}`, `reviews/${uid}`]) {
      assert.equal((await db.doc(ref).get()).exists, false, ref);
    }
    assert.deepEqual((await db.doc("products/account-stock").get()).data(), {stock: 99, reservedStock: 0});
    assert.deepEqual((await db.doc("customerProfiles/untouched").get()).data(), {birthDate: "1990-01-01"});
    await processClosure(db, auth, uid);
    assert.equal((await status(uid)).completedAt.toMillis(), completed.completedAt.toMillis());
  });
}

test("processing lock rejects old-token recreation and all personal-data callables; status is owner-only", async () => {
  const uid = "locked";
  await requestClosure(db, request(uid));
  const own = client(uid);
  await assertSucceeds(getDoc(doc(own, `customerAccountClosures/${uid}`)));
  await assertFails(getDoc(doc(client("intruder"), `customerAccountClosures/${uid}`)));
  await assertFails(getDocs(collection(own, "customerAccountClosures")));
  await assertFails(setDoc(doc(own, `customerAccountClosures/${uid}`), {status: "blocked"}));
  await assertFails(setDoc(doc(own, `customerProfiles/${uid}`), {createdAt: serverTimestamp()}));
  await assertFails(setDoc(doc(own, `customerWorkspaces/${uid}`), {cart: [], addresses: []}));
  await assert.rejects(assertCustomerAccountActive(db, uid), {code: "failed-precondition"});
  await assert.rejects(quoteDelivery(db, request(uid)), {code: "failed-precondition"});
  await assert.rejects(ownPin(db, request(uid), Buffer.alloc(32).toString("base64")), {code: "failed-precondition"});
  await assert.rejects(discardProposal(db, request(uid, {}, {orderDocumentId: "a".repeat(20)})),
      {code: "failed-precondition"});
  await assert.rejects(chatOperation(db, {auth: request(uid).auth, data: {orderId: "test-order"}}, false),
      {code: "failed-precondition"});
  await processClosure(db, auth, uid);
  await assertFails(setDoc(doc(own, `customerWorkspaces/${uid}`), {cart: [], addresses: []}));
});

test("pagination, partial failure, concurrent retry and already-missing Auth are idempotent", async () => {
  const uid = "paginated";
  const batch = db.batch();
  for (let i = 0; i < 105; i++) {
    batch.set(db.doc(`orders/page-${String(i).padStart(3, "0")}`), done(uid));
    batch.set(db.doc(`deliveryQuotes/page-${i}`), {uid});
  }
  await batch.commit();
  await auth.createUser({uid});
  await requestClosure(db, request(uid));
  const broken = {getUser: (id) => auth.getUser(id), deleteUser: async () => {
    throw new Error("TRANSIENT");
  }};
  await assert.rejects(processClosure(db, broken, uid), /TRANSIENT/);
  assert.equal((await status(uid)).status, "processing");
  assert.equal((await db.collection("orders").where("customerUid", "==", uid).get()).size, 0);
  assert.equal((await db.collection("deliveryQuotes").where("uid", "==", uid).get()).size, 0);
  await auth.deleteUser(uid);
  await Promise.all([processClosure(db, auth, uid), processClosure(db, auth, uid)]);
  assert.equal((await status(uid)).status, "completed");
});

test("failure between orders resumes; merchant cannot recreate closed chat", async () => {
  const uid = "mid-failure";
  for (const id of ["mid-a", "mid-b"]) {
    await db.doc(`orders/${id}`).set(done(uid));
    await db.doc(`orderChats/${id}/messages/private`).set({text: "TEST ONLY"});
  }
  await requestClosure(db, request(uid));
  let count = 0;
  const unreliable = new Proxy(db, {get(target, key) {
    if (key === "recursiveDelete") {
      return async (ref) => {
        if (++count === 2) throw new Error("MID_CLEANUP_FAILURE");
        return target.recursiveDelete(ref);
      };
    }
    const value = target[key]; return typeof value === "function" ? value.bind(target) : value;
  }});
  await assert.rejects(processClosure(unreliable, auth, uid), /MID_CLEANUP_FAILURE/);
  assert.equal((await status(uid)).status, "processing");
  assert.equal((await db.doc("orders/mid-a").get()).data().address, undefined);
  assert.equal((await db.doc("orders/mid-b").get()).data().customerUid, uid);
  await processClosure(db, auth, uid);
  assert.equal((await db.doc("orders/mid-b").get()).data().address, undefined);
  assert.equal((await db.doc("orderChats/mid-b/messages/private").get()).exists, false);
  const merchant = request("merchant", {roles: ["operations_admin"]}).auth;
  await assert.rejects(chatOperation(db, {auth: merchant, data: {
    orderId: "mid-a", text: "RECREATE", requestId: "test-request-0001",
  }}, true), {code: "failed-precondition"});
  assert.equal((await db.doc("orderChats/mid-a").get()).exists, false);
});

test("promotion to privileged account after request cannot erase it", async () => {
  const uid = "promoted";
  await auth.createUser({uid});
  await db.doc(`customerProfiles/${uid}`).set({private: "retained"});
  await requestClosure(db, request(uid));
  await auth.setCustomUserClaims(uid, {roles: ["superadmin"]});
  await assert.rejects(processClosure(db, auth, uid), /CUSTOMER_CLOSURE_ROLE_DENIED/);
  assert.equal((await db.doc(`customerProfiles/${uid}`).get()).exists, true);
  assert.equal((await status(uid)).status, "requested");
});
