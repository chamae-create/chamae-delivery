const assert = require("node:assert/strict");
const {before, after, test} = require("node:test");
const fs = require("node:fs");
const {initializeApp, deleteApp} = require("firebase-admin/app");
const {getFirestore, Timestamp} = require("firebase-admin/firestore");
const {initializeTestEnvironment, assertFails, assertSucceeds} =
    require("@firebase/rules-unit-testing");
const {doc, collection, getDoc, getDocs, setDoc, updateDoc} =
    require("firebase/firestore");
const {chatOperation} = require("../order-chat");
let app; let db; let env;
const auth = (uid, roles = [], anonymous = false) => ({uid,
  token: {roles, firebase: {sign_in_provider:
    anonymous ? "anonymous" : "password"}}});
const request = (actor, extra = {}) => ({auth: actor,
  data: {orderId: "chat-order", text: "Olá loja", requestId:
    "request_identifier_0001", ...extra}});
before(async () => {
  const host = process.env.FIRESTORE_EMULATOR_HOST;
  assert.ok(host, "Emulator mandatory");
  const address = new URL("http://" + host);
  assert.ok(["localhost", "127.0.0.1"].includes(address.hostname));
  env = await initializeTestEnvironment({projectId: "demo-chamae-rules",
    firestore: {host: address.hostname, port: Number(address.port),
      rules: fs.readFileSync("../firestore.rules", "utf8")}});
  await env.clearFirestore();
  app = initializeApp({projectId: "demo-chamae-rules"});
  db = getFirestore(app);
  await db.doc("orders/chat-order").set({customerUid: "buyer",
    financialValidationStatus: "validated", status: "Novo"});
  await db.doc("couriers/rider").set({administrativeState: "active"});
});
after(async () => {
  if (env) await env.cleanup();
  if (db) await db.terminate();
  if (app) await deleteApp(app);
});
test("idempotent send and merchant read", async () => {
  const req = request(auth("buyer", [], true));
  await chatOperation(db, req, true);
  await chatOperation(db, req, true);
  let chat = (await db.doc("orderChats/chat-order").get()).data();
  assert.equal(chat.unreadMerchant, 1);
  assert.equal((await db.collection("orderChats/chat-order/messages")
      .get()).size, 1);
  await chatOperation(db, {auth: auth("ops", ["operations_admin"]),
    data: {orderId: "chat-order"}}, false);
  chat = (await db.doc("orderChats/chat-order").get()).data();
  assert.equal(chat.unreadMerchant, 0);
});
for (const role of ["operations_admin", "superadmin"]) {
  test(role + " sends and reads chat", async () => {
    await chatOperation(db, request(auth(role, [role]),
        {requestId: "request_identifier_" + role}), true);
    const client = env.authenticatedContext(role, {roles: [role]}).firestore();
    await assertSucceeds(getDoc(doc(client, "orderChats/chat-order")));
    await assertSucceeds(getDocs(collection(client,
        "orderChats/chat-order/messages")));
  });
}
for (const actor of [auth("stranger"), auth("fin", ["finance"]),
  auth("cat", ["catalog_admin"]), auth("rider"),
  auth("rider", ["superadmin"]), auth("rider", ["operations_admin"]),
  auth("anonymous-ops", ["operations_admin"], true)]) {
  test("unauthorized actor blocked: " + JSON.stringify(actor), async () => {
    await assert.rejects(chatOperation(db, request(actor), true),
        {code: "permission-denied"});
    const client = env.authenticatedContext(actor.uid, actor.token).firestore();
    await assertFails(getDoc(doc(client, "orderChats/chat-order")));
    await assertFails(getDocs(collection(client,
        "orderChats/chat-order/messages")));
    await assertFails(getDocs(collection(client, "orderChats")));
  });
}
for (const extra of [{text: ""}, {text: " "}, {text: "a".repeat(2001)},
  {text: {}}, {text: "bad\u0000text"},
  {imageUrl: "anything"}, {unreadMerchant: 0},
  {requestId: "short"}, {senderType: "merchant"}, {createdAt: 1}]) {
  test("invalid message: " + JSON.stringify(extra).slice(0, 40),
      async () => {
        await assert.rejects(chatOperation(db,
            request(auth("buyer"), extra), true),
        {code: "invalid-argument"});
      });
}
test("owner isolation and no SDK writes", async () => {
  const buyer = env.authenticatedContext("buyer", {firebase:
    {sign_in_provider: "anonymous"}}).firestore();
  await assertSucceeds(getDoc(doc(buyer, "orderChats/chat-order")));
  await assertSucceeds(getDocs(collection(buyer,
      "orderChats/chat-order/messages")));
  await assertFails(getDocs(collection(buyer, "orderChats")));
  for (const actor of [auth("buyer"), auth("ops", ["operations_admin"]),
    auth("root", ["superadmin"])]) {
    const client = env.authenticatedContext(actor.uid, actor.token).firestore();
    await assertFails(updateDoc(doc(client, "orderChats/chat-order"),
        {unreadMerchant: 0}));
    await assertFails(setDoc(doc(client,
        "orderChats/chat-order/messages/forged"), {text: "forged"}));
  }
});
test("24-hour boundary closes writes and preserves history", async () => {
  const end = Date.now();
  await db.doc("orders/chat-order").update({status: "Concluído",
    completedAt: Timestamp.fromMillis(end - 86400000)});
  await chatOperation(db, request(auth("buyer"),
      {requestId: "before_window_boundary_001"}), true, () => end - 1);
  await assert.rejects(chatOperation(db, request(auth("buyer"),
      {requestId: "after_window_boundary_0001"}), true, () => end),
  {code: "failed-precondition"});
  const client = env.authenticatedContext("buyer").firestore();
  await assertSucceeds(getDocs(collection(client,
      "orderChats/chat-order/messages")));
  await chatOperation(db, {auth: auth("buyer"),
    data: {orderId: "chat-order"}}, false, () => end);
  assert.equal((await db.doc("orderChats/chat-order").get()).data().status,
      "closed");
});
test("legacy, unauthenticated and conflicting retry are rejected", async () => {
  await db.doc("orders/legacy-chat").set({customerUid: "buyer"});
  await assert.rejects(chatOperation(db, request(auth("buyer"),
      {orderId: "legacy-chat"}), true), {code: "failed-precondition"});
  await assert.rejects(chatOperation(db, request(null), true),
      {code: "unauthenticated"});
  await assert.rejects(chatOperation(db, request(auth("buyer"),
      {text: "different text"}), true), {code: "already-exists"});
});

const {registerPrint} = require("../order-printing");
test("print log idempotent, second copy and no order mutations", async () => {
  const original = (await db.doc("orders/chat-order").get()).data();
  const req = {auth: auth("ops", ["operations_admin"]), data: {
    orderId: "chat-order", requestId: "printing_request_00001",
    part: "both", paperMm: 80}};
  const results = await Promise.all([registerPrint(db, req),
    registerPrint(db, req)]);
  assert.deepEqual(results.map((r) => r.count), [1, 1]);
  req.data.requestId = "printing_request_00002";
  assert.equal((await registerPrint(db, req)).count, 2);
  assert.deepEqual((await db.doc("orders/chat-order").get()).data(), original);
});
for (const actor of [auth("buyer"), auth("fin", ["finance"]),
  auth("cat", ["catalog_admin"]), auth("rider", ["superadmin"])]) {
  test("print log denied: " + actor.uid, async () => {
    await assert.rejects(registerPrint(db, {auth: actor, data: {
      orderId: "chat-order", requestId: "printing_request_00001",
      part: "both", paperMm: 80}}), {code: "permission-denied"});
  });
}
