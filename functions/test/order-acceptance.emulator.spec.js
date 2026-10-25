const {before, after, beforeEach, test, mock} = require("node:test");
const assert = require("node:assert/strict");
const {EventEmitter} = require("node:events");
const {initializeApp, deleteApp} = require("firebase-admin/app");
const {getFirestore, Timestamp, GeoPoint} = require("firebase-admin/firestore");
const {initializeTestEnvironment, assertFails, assertSucceeds} = require("@firebase/rules-unit-testing");
const {doc, getDoc, setDoc, serverTimestamp} = require("firebase/firestore");
const {loadBackend} = require("./backend-fixture");
const {deliveryFixture} = require("./delivery-fixture");
const {rulesAt, useOpenClock} = require("./operational-fixture");
const {serverClock, storeIsOpen} = require("../order-acceptance");
const {customerPolicyFixture, customerProfileFixture} = require("./customer-policy-fixture");

let app; let db; let env; let backend; let endpoints; let sequence = 0;
const posts = [];
const previousToken = process.env.MERCADOPAGO_ACCESS_TOKEN;
const previousTestKey = process.env.CHAMAE_PIX_TEST_KEY;
const environment = async (instant) => initializeTestEnvironment({projectId: "demo-chamae-rules", firestore: {
  host: "127.0.0.1", port: 8187, rules: rulesAt(instant),
}});
before(async () => {
  assert.equal(process.env.FIRESTORE_EMULATOR_HOST, "127.0.0.1:8187", "local-only; never production fallback");
  env = await environment(); await env.clearFirestore();
  app = initializeApp({projectId: "demo-chamae-rules"}); db = getFirestore(app);
  const loaded = loadBackend(db); backend = loaded.functions; endpoints = loaded.endpoints;
  process.env.MERCADOPAGO_ACCESS_TOKEN = "TEST_ONLY";
  process.env.CHAMAE_PIX_TEST_KEY = "TEST_ONLY";
  const nativeFetch = global.fetch;
  mock.method(global, "fetch", async (url, options) => {
    const target = new URL(url);
    if (target.hostname === "api.mercadopago.com") {
      assert.equal(options.method, "POST"); posts.push(JSON.parse(options.body));
      return {ok: true, status: 201, text: async () => JSON.stringify({id: "TEST_ORDER", status: "action_required",
        transactions: {payments: [{id: "TEST_PAY", payment_method: {qr_code: "TEST_QR"}}]}}),
      json: async () => ({id: "TEST_ORDER", transactions: {payments: [
        {id: "TEST_PAY", payment_method: {qr_code: "TEST_QR"}},
      ]}})};
    }
    assert.ok(["127.0.0.1", "localhost"].includes(target.hostname), "unexpected external call blocked");
    return nativeFetch(url, options);
  });
  const policy = customerPolicyFixture();
  await db.doc("customerPolicies/current").set(policy);
  await db.doc("customerProfiles/buyer").set(customerProfileFixture(policy, Timestamp.now()));
  await db.doc("products/kb03").set({priceBRL: 20, stock: 10, reservedStock: 0, salesCount: 0, isActive: true});
});
beforeEach(() => {
  useOpenClock(); posts.length = 0;
});
after(async () => {
  mock.restoreAll();
  if (previousToken === undefined) delete process.env.MERCADOPAGO_ACCESS_TOKEN;
  else process.env.MERCADOPAGO_ACCESS_TOKEN = previousToken;
  if (previousTestKey === undefined) delete process.env.CHAMAE_PIX_TEST_KEY;
  else process.env.CHAMAE_PIX_TEST_KEY = previousTestKey;
  if (env) await env.cleanup();
  if (db) await db.terminate();
  if (app) await deleteApp(app);
});

async function seed(method = "PIX", country = "BR") {
  const id = `kb03-${++sequence}`;
  const fixture = deliveryFixture({quoteId: sequence.toString(16).padStart(64, "0")});
  fixture.destination.countryCode = country;
  fixture.documents.get(`deliveryQuotes/${fixture.quoteId}`).destinationVerification.countryCode = country;
  for (const [p, data] of fixture.documents) await db.doc(p).set(data);
  const order = {id: `#${id}`, customerUid: "buyer", customerFlowVersion: 2, customerName: "TEST CUSTOMER",
    deliveryAddress: fixture.destination, deliveryQuoteId: fixture.quoteId,
    paymentMethod: method, pixRequested: method === "PIX", splitPayment: false,
    itemsList: [{id: "kb03", quantity: 1, price: 0.01}], totalBRL: 1,
    status: method === "PIX" ? "Aguardando pagamento" : "Novo",
    paymentStatus: method === "PIX" ? "Aguardando confirmação" : "Pendente na entrega",
    courierPaid: false, createdAt: Timestamp.now()};
  const ref = db.doc(`orders/${id}`); await ref.set(order);
  return {id, ref, order, fixture};
}
async function invoke(item, flow) {
  if (flow === "manual") {
    let code; let body;
    const response = Object.assign(new EventEmitter(), {status: (value) => {
      code = value; return response;
    },
    json: (value) => {
      body = value;
    }, send: () => {}});
    await endpoints.chamaeCriarPix({method: "POST", headers: {}, get: () => "TEST_ONLY",
      body: {orderDocumentId: item.id, timezone: "Asia/Tokyo", storeOpen: true}}, response);
    return {code, body};
  }
  const handler = flow === "reserve" ? backend.chamaeReservarEstoquePagamentoEntrega : backend.chamaeCriarPixAutomatico;
  await handler({params: {orderId: item.id}, data: await item.ref.get()});
}

for (const [instant, allowed] of [["2026-10-24T11:59:00Z", false], ["2026-10-24T12:00:00Z", true],
  ["2026-10-24T16:00:00Z", true], ["2026-10-25T03:59:00Z", true], ["2026-10-25T04:00:00Z", false]]) {
  test(`real Firestore transaction and direct HTTP: ${instant}, allowed=${allowed}`, async () => {
    for (const flow of ["auto", "manual", "reserve"]) {
      const item = await seed(flow === "reserve" ? "Dinheiro" : "PIX");
      const initial = (await db.doc("products/kb03").get()).data();
      const postCount = posts.length;
      serverClock.now = () => Date.parse(instant);
      const response = await invoke(item, flow);
      assert.equal((await db.doc(`orderFinancials/${item.id}`).get()).exists, allowed);
      assert.equal(posts.length - postCount, allowed && flow !== "reserve" ? 1 : 0);
      if (!allowed) {
        assert.deepEqual((await db.doc("products/kb03").get()).data(), initial);
        assert.equal(response?.body?.erro || (await item.ref.get()).data().financialValidationError, "STORE_CLOSED");
        assert.equal((await db.doc(`deliveryQuotes/${item.fixture.quoteId}`).get()).data().orderId, undefined);
      }
    }
  });
}

test("verified PY permits PIX/cash; invalid method/country/attestation cause no effects", async () => {
  for (const invalid of ["card", "missing", "invalid", "forged", "oldquote", "projection", "alias", "topalias"]) {
    const item = await seed(invalid === "card" ? "Maquininha" : "Dinheiro", "PY");
    const initial = (await db.doc("products/kb03").get()).data();
    if (invalid === "missing") await item.ref.update({"deliveryAddress.countryCode": null});
    if (invalid === "invalid") await item.ref.update({"deliveryAddress.countryCode": "AR"});
    if (invalid === "forged") await item.ref.update({"deliveryAddress.countryCode": "BR"});
    if (invalid === "projection") await item.ref.update({deliveryLocation: new GeoPoint(-23, -54)});
    if (invalid === "alias") await item.ref.update({"deliveryAddress.country": "BR"});
    if (invalid === "topalias") await item.ref.update({country: "BR"});
    if (invalid === "oldquote") {
      await db.doc(`deliveryQuotes/${item.fixture.quoteId}`)
          .update({destinationVerification: null});
    }
    await invoke(item, "reserve");
    assert.equal((await db.doc(`orderFinancials/${item.id}`).get()).exists, false);
    assert.deepEqual((await db.doc("products/kb03").get()).data(), initial);
    assert.equal((await item.ref.get()).data().financialValidationError,
        invalid === "card" ? "PAYMENT_METHOD_NOT_ALLOWED_FOR_COUNTRY" : "DESTINATION_COUNTRY_UNVERIFIED");
  }
  const cash = await seed("Dinheiro", "PY"); await invoke(cash, "reserve");
  assert.equal((await cash.ref.get()).data().stockReservationStatus, "reserved");
  const pix = await seed("PIX", "PY"); await invoke(pix, "auto");
  assert.equal((await db.doc(`orderFinancials/${pix.id}`).get()).exists, true);
  assert.equal(posts.length, 1);
});

test("frozen financial does not allow a new PIX at closing; accepted cash retry leaves stock unchanged", async () => {
  const pix = await seed(); await invoke(pix, "auto");
  const financial = (await db.doc(`orderFinancials/${pix.id}`).get()).data();
  await pix.ref.update({mercadoPagoOrderId: null});
  const cash = await seed("Dinheiro"); await invoke(cash, "reserve");
  const stock = (await db.doc("products/kb03").get()).data();
  serverClock.now = () => Date.parse("2026-10-25T04:00:00Z");
  await invoke(pix, "auto"); await invoke(cash, "reserve");
  assert.equal(posts.length, 1);
  assert.deepEqual((await db.doc(`orderFinancials/${pix.id}`).get()).data(), financial);
  assert.deepEqual((await db.doc("products/kb03").get()).data(), stock);
});

test("Rules boundaries, PY card denial and forged payload clock", async () => {
  for (const [instant, allowed] of [["2026-10-24T11:59:00Z", false], ["2026-10-24T12:00:00Z", true],
    ["2026-10-24T16:00:00Z", true], ["2026-10-25T03:59:00Z", true], ["2026-10-25T04:00:00Z", false]]) {
    await env.cleanup(); env = await environment(instant);
    const client = env.authenticatedContext("buyer", {firebase: {sign_in_provider: "google.com"}}).firestore();
    const item = await seed("Dinheiro");
    const payload = {...item.order, createdAt: serverTimestamp()};
    const promise = setDoc(doc(client, `orders/rules-${++sequence}`), payload);
    if (allowed) await assertSucceeds(promise); else await assertFails(promise);
    await assertFails(setDoc(doc(client, `orders/forged-${++sequence}`),
        {...payload, timezone: "Pacific/Honolulu", storeOpen: true, hour: 12}));
    await assertFails(setDoc(doc(client, `orders/py-card-${++sequence}`), {...payload, paymentMethod: "Maquininha",
      deliveryAddress: {...payload.deliveryAddress, countryCode: "PY"}}));
    await assertSucceeds(getDoc(doc(client, "products/kb03")));
  }
});

test("unmodified Rules use actual request.time, not the test/user clock", async () => {
  await env.cleanup(); env = await environment(null);
  const client = env.authenticatedContext("buyer", {firebase: {sign_in_provider: "google.com"}}).firestore();
  const item = await seed("Dinheiro");
  const promise = setDoc(doc(client, `orders/real-clock-${++sequence}`), {...item.order, createdAt: serverTimestamp()});
  if (storeIsOpen(Date.now())) await assertSucceeds(promise); else await assertFails(promise);
});
