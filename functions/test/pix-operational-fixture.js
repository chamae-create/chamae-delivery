// TEST ONLY: real Auth/Firestore emulators and production handlers; only Mercado Pago HTTP is mocked.
const assert = require("node:assert/strict");
const {createHash, createHmac} = require("node:crypto");
const {EventEmitter} = require("node:events");
const {getAuth: adminAuth} = require("firebase-admin/auth");
const {initializeApp, deleteApp} = require("firebase/app");
const {getAuth, connectAuthEmulator, signInWithEmailAndPassword} = require("firebase/auth");
const {getFirestore, connectFirestoreEmulator, doc, setDoc, serverTimestamp, terminate} = require("firebase/firestore");
const {loadBackend} = require("./backend-fixture");
const {deliveryFixture} = require("./delivery-fixture");
const {customerPolicyFixture} = require("./customer-policy-fixture");
const {acceptDocuments} = require("../customer-onboarding");
const {changeCourier} = require("../courier-assignment");
function emulatorAddress(key) {
  const value = process.env[key] || "";
  assert.match(value, /^(127\.0\.0\.1|localhost):[0-9]+$/, "Emulator required; no production fallback: " + key);
  const [host, port] = value.split(":"); return {value, host, port: Number(port)};
}
function response() {
  const res = new EventEmitter(); res.code = 200;
  res.status = (code) => {
    res.code = code; return res;
  };
  res.send = (body) => {
    res.body = body; return res;
  };
  res.json = res.send; return res;
}
async function createPaidPixOrder({db, customerUid, courierUid, operatorUid = "pix-ack-admin",
  orderId, customerEmail, customerPassword}) {
  const firestore = emulatorAddress("FIRESTORE_EMULATOR_HOST");
  const authAddress = emulatorAddress("FIREBASE_AUTH_EMULATOR_HOST");
  assert.equal(db.projectId, "demo-chamae-rules");
  assert.match(orderId, /^[a-zA-Z0-9_-]+$/);
  const app = initializeApp({projectId: "demo-chamae-rules", apiKey: "emulator-only-key",
    appId: "1:000000000:web:pix-test-only"}, "pix-sdk-" + orderId);
  const auth = getAuth(app); connectAuthEmulator(auth, "http://" + authAddress.value, {disableWarnings: true});
  const sdk = getFirestore(app); connectFirestoreEmulator(sdk, firestore.host, firestore.port);
  const nativeFetch = global.fetch;
  const previous = Object.fromEntries(["MERCADOPAGO_ACCESS_TOKEN", "MERCADOPAGO_WEBHOOK_SECRET"]
      .map((key) => [key, process.env[key]]));
  const secret = "TEST-ONLY-PIX-HMAC-NOT-A-REAL-CREDENTIAL";
  process.env.MERCADOPAGO_ACCESS_TOKEN = "TEST-ONLY-FAKE-PROVIDER-TOKEN";
  process.env.MERCADOPAGO_WEBHOOK_SECRET = secret;
  const providerId = "MOCK_" + orderId; const providerCalls = [];
  let providerAmount; let providerReference = orderId;
  try {
    const login = await signInWithEmailAndPassword(auth, customerEmail, customerPassword);
    assert.equal(login.user.uid, customerUid);
    const token = await adminAuth().verifyIdToken(await login.user.getIdToken(true));
    const policy = customerPolicyFixture(); await db.doc("customerPolicies/current").set(policy);
    await acceptDocuments(db, {auth: {uid: customerUid, token}, data: {birthDate: "2000-01-01",
      termsVersion: policy.termsVersion, privacyVersion: policy.privacyVersion, alcoholVersion: policy.alcoholVersion,
      policyRevision: policy.revision, policyHash: policy.contentHash, acceptTerms: true,
      acknowledgePrivacy: true, acknowledgeAlcohol: true}});
    const quote = deliveryFixture({uid: customerUid, quoteId: createHash("sha256").update(orderId).digest("hex")});
    for (const [path, value] of quote.documents) await db.doc(path).set(value);
    const productId = orderId + "-product";
    await db.doc("products/" + productId).set({name: "TEST FIXTURE", category: "Gelo", priceBRL: 20,
      isActive: true, stock: 20, reservedStock: 0, salesCount: 0});
    // False only suppresses automatic delivery of the onCreate event in the separate Functions test process.
    // The real auto-PIX handler is invoked below after the test scheduler activates the request.
    await setDoc(doc(sdk, "orders", orderId), {id: "#" + orderId, customerUid, customerName: "Cliente Ficticio PIX",
      customerFlowVersion: 2, deliveryQuoteId: quote.quoteId, deliveryAddress: quote.destination,
      address: "Rua Ficticia 123", itemsList: [{id: productId, quantity: 3, price: 0.01}],
      totalBRL: 1, paymentMethod: "PIX", paymentStatus: "Aguardando confirmação", pixRequested: false,
      status: "Aguardando pagamento", courierPaid: false, createdAt: serverTimestamp()});
    const ref = db.doc("orders/" + orderId); await ref.update({pixRequested: true});
    const backend = loadBackend(db);
    global.fetch = async (url, init = {}) => {
      const target = new URL(url);
      if (target.hostname !== "api.mercadopago.com") {
        assert.ok(["127.0.0.1", "localhost", "[::1]"].includes(target.hostname), "Unexpected external request blocked");
        return nativeFetch(url, init);
      }
      assert.ok(init.method === "POST" && target.pathname === "/v1/orders" ||
        init.method === "GET" && target.pathname === "/v1/orders/" + encodeURIComponent(providerId));
      providerCalls.push({method: init.method, path: target.pathname});
      if (init.method === "POST") providerAmount = JSON.parse(init.body).total_amount;
      const body = {id: providerId, external_reference: providerReference, processing_mode: "automatic",
        total_amount: providerAmount, status: init.method === "POST" ? "action_required" : "processed",
        status_detail: init.method === "POST" ? "waiting_payment" : "accredited", transactions: {payments: [{
          id: "MOCK_PAYMENT_" + orderId, status: "processed", status_detail: "accredited",
          payment_method: {id: "pix", type: "bank_transfer", qr_code: "MOCK_IN_TEST_ONLY_" + orderId}}]}};
      return {ok: true, status: 200, json: async () => body, text: async () => JSON.stringify(body)};
    };
    await backend.functions.chamaeCriarPixAutomatico({params: {orderId}, data: await ref.get()});
    const issued = (await ref.get()).data(); const amounts = (await db.doc("orderFinancials/" + orderId).get()).data();
    assert.equal(issued.mercadoPagoOrderId, providerId);
    assert.equal(issued.totalBRL, 70.60); assert.equal(amounts.totalBRL, 70.60);
    assert.equal(issued.paymentStatus, "Aguardando confirmação");
    const assign = () => changeCourier(db, {auth: {uid: operatorUid, token: {roles: ["superadmin"]}},
      data: {orderId, courierUid, requestId: orderId + "-before-payment-assignment",
        contingencyReason: "TEST ONLY ASSIGNMENT BEFORE PROVIDER CONFIRMATION", confirmation: "CONFIRMAR " + orderId}});
    await assert.rejects(assign(), {code: "failed-precondition"});
    const notify = async (valid = true) => {
      const id = "mock-request-" + orderId; const timestamp = String(Date.now());
      const hash = createHmac("sha256", secret).update("id:" + providerId.toLowerCase() + ";request-id:" + id +
        ";ts:" + timestamp + ";").digest("hex");
      const signature = "ts=" + timestamp + ",v1=" + (valid ? hash : "0".repeat(64));
      const res = response(); await backend.endpoints.chamaeMercadoPagoWebhook({method: "POST",
        query: {"data.id": providerId}, body: {type: "order", live_mode: false, action: "order.updated"},
        get: (key) => key === "x-signature" ? signature : key === "x-request-id" ? id : undefined}, res);
      return res;
    };
    const beforeBad = providerCalls.length;
    assert.equal((await notify(false)).code, 401);
    assert.equal(providerCalls.length, beforeBad, "Invalid webhook must not query provider");
    const correctAmount = providerAmount;
    providerAmount = "0.01"; await notify();
    assert.equal((await ref.get()).data().paymentStatus, "Aguardando confirmação");
    providerAmount = correctAmount; providerReference = "foreign-test-order"; await notify();
    assert.equal((await ref.get()).data().paymentStatus, "Aguardando confirmação");
    providerReference = orderId;
    assert.equal((await notify()).code, 200);
    const paid = (await ref.get()).data(); const stock = (await db.doc("products/" + productId).get()).data();
    assert.equal(paid.paymentStatus, "Pago"); assert.equal(paid.status, "Novo");
    assert.equal(paid.stockProcessingStatus, "processed");
    assert.equal(stock.stock, 17); assert.equal(stock.salesCount, 3);
    await notify();
    assert.deepEqual((await db.doc("products/" + productId).get()).data(), stock,
        "Duplicate webhook cannot debit stock");
    assert.deepEqual((await db.doc("orderFinancials/" + orderId).get()).data(), amounts,
        "Official financial ledger must remain unchanged");
    return {orderId, customerUid, courierUid, provider: "MOCK_IN_TEST_ONLY", providerSandbox: false,
      realExternalPayment: false, customerAuthSdk: true, customerFirestoreSdk: true,
      blockedAssignmentBeforePayment: true, invalidSignatureRejected: true, underpaymentRejected: true,
      foreignReferenceRejected: true, duplicatePaymentIdempotent: true, paymentStatus: paid.paymentStatus,
      amounts: Object.fromEntries(["itemsTotal", "deliveryFee", "customerFee", "merchantFee", "merchantNet",
        "platformFee", "totalBRL"].map((key) => [key, amounts[key]])), providerCalls};
  } finally {
    global.fetch = nativeFetch;
    for (const [key, value] of Object.entries(previous)) {
      if (value === undefined) delete process.env[key]; else process.env[key] = value;
    }
    await auth.signOut(); await terminate(sdk); await deleteApp(app);
  }
}
module.exports = {createPaidPixOrder};
