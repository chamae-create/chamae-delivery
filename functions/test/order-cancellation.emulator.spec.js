const {before, after, test, mock} = require("node:test");
const assert = require("node:assert/strict");
const {createHmac} = require("node:crypto");
const {EventEmitter} = require("node:events");
const {initializeApp, deleteApp} = require("firebase-admin/app");
const {getFirestore, Timestamp} = require("firebase-admin/firestore");
const {initializeTestEnvironment, assertFails} = require("@firebase/rules-unit-testing");
const {doc, getDoc, setDoc, updateDoc} = require("firebase/firestore");
const {loadBackend} = require("./backend-fixture");
const {deliveryFixture} = require("./delivery-fixture");
const {rulesAt} = require("./operational-fixture");
const {customerPolicyFixture, customerProfileFixture} = require("./customer-policy-fixture");
const {compensate, input} = require("../order-cancellation");
const {savePixCreation, updateActiveOrder} = require("../order-cancellation-state");

let app; let db; let env; let functions; let endpoints; let count = 0;
const providers = new Map(); const posts = [];
const secretNames = ["MERCADOPAGO_ACCESS_TOKEN", "MERCADOPAGO_WEBHOOK_SECRET", "CHAMAE_PIX_TEST_KEY"];
const previousSecrets = new Map(secretNames.map((key) => [key, process.env[key]]));
const command = (id, operation = "cancel", requestId, role = "superadmin") => ({
  auth: {uid: `actor-${role}`, token: {roles: [role], firebase: {sign_in_provider: "password"}}},
  data: {orderId: id, requestId: requestId || `${operation}-${id}-request-1234567890`,
    reason: "Cancelamento/devolução autorizado no ensaio",
    confirmation: `${operation === "cancel" ? "CANCELAR" : "DEVOLVER"} ${id}`},
});
const cancel = (id, requestId, role) => functions.chamaeCancelarPedido(command(id, "cancel", requestId, role));
const restock = (id, requestId) => functions.chamaeAutorizarDevolucaoPedido(command(id, "restock", requestId));
const get = async (path) => (await db.doc(path).get()).data();
const stock = (item) => get(`products/${item.id}`);
before(async () => {
  assert.equal(process.env.FIRESTORE_EMULATOR_HOST, "127.0.0.1:8187", "local emulator only; never production");
  env = await initializeTestEnvironment({projectId: "demo-chamae-rules", firestore: {
    host: "127.0.0.1", port: 8187, rules: rulesAt(),
  }}); await env.clearFirestore();
  app = initializeApp({projectId: "demo-chamae-rules"}); db = getFirestore(app);
  const loaded = loadBackend(db); functions = loaded.functions; endpoints = loaded.endpoints;
  for (const key of secretNames) process.env[key] = "TEST_ONLY";
  const nativeFetch = global.fetch;
  mock.method(global, "fetch", async (url, options) => {
    const target = new URL(url);
    if (target.hostname === "api.mercadopago.com") {
      if (options.method === "POST") {
        const body = JSON.parse(options.body); posts.push(body);
        const id = `MP_${body.external_reference}`;
        const response = {id, external_reference: body.external_reference, total_amount: body.total_amount,
          processing_mode: "automatic", status: "action_required", status_detail: "waiting_transfer",
          transactions: {payments: [{id: `PAY_${id}`, status: "created", payment_method: {
            id: "pix", type: "bank_transfer", qr_code: "TEST_QR"}}]}};
        providers.set(id, response);
        return {ok: true, status: 201, text: async () => JSON.stringify(response), json: async () => response};
      }
      assert.equal(options.method, "GET");
      const response = providers.get(target.pathname.split("/").at(-1));
      assert.ok(response); return {ok: true, status: 200, json: async () => response};
    }
    assert.ok(["127.0.0.1", "localhost"].includes(target.hostname), "unexpected external call blocked");
    return nativeFetch(url, options);
  });
  const policy = customerPolicyFixture();
  await db.doc("customerPolicies/current").set(policy);
  await db.doc("customerProfiles/buyer").set(customerProfileFixture(policy, Timestamp.now()));
});
after(async () => {
  mock.restoreAll();
  for (const [key, value] of previousSecrets) {
    if (value === undefined) delete process.env[key]; else process.env[key] = value;
  }
  if (env) await env.cleanup(); if (db) await db.terminate(); if (app) await deleteApp(app);
});

async function seed(method = "Dinheiro", country = "BR", start = true) {
  const id = `kb04-${++count}`;
  const delivery = deliveryFixture({quoteId: count.toString(16).padStart(64, "d")});
  delivery.destination.countryCode = country;
  delivery.documents.get(`deliveryQuotes/${delivery.quoteId}`).destinationVerification.countryCode = country;
  for (const [path, value] of delivery.documents) await db.doc(path).set(value);
  await db.doc(`products/${id}`).set({priceBRL: 20, stock: 10, reservedStock: 0, salesCount: 0, isActive: true});
  const ref = db.doc(`orders/${id}`);
  await ref.set({id: `#${id}`, customerUid: "buyer", customerName: "TEST CUSTOMER", customerFlowVersion: 2,
    deliveryAddress: delivery.destination, deliveryQuoteId: delivery.quoteId,
    itemsList: [{id, quantity: 2, price: 0.01}], totalBRL: 1, paymentMethod: method,
    pixRequested: method === "PIX", status: method === "PIX" ? "Aguardando pagamento" : "Novo",
    paymentStatus: method === "PIX" ? "Aguardando confirmação" : "Pendente na entrega", courierPaid: false,
    ...(method === "Pagamento dividido" ? {splitPayment: true, paymentParts: [
      {method: "Dinheiro", currency: "BRL", amountCurrency: 30},
      {method: "Dinheiro", currency: "BRL", amountCurrency: 30}]} : {}), createdAt: Timestamp.now()});
  const original = await ref.get();
  if (start) {
    await functions[method === "PIX" ? "chamaeCriarPixAutomatico" : "chamaeReservarEstoquePagamentoEntrega"]({
      params: {orderId: id}, data: original,
    });
  }
  return {id, ref, original};
}
async function resolve(item) {
  await functions.chamaeResolverReservaEstoque({params: {orderId: item.id}, data: {after: await item.ref.get()}});
}
async function proveReturn(item) {
  const order = (await item.ref.get()).data();
  await functions.chamaeRegistrarContingenciaEntrega({auth: command(item.id).auth, data: {
    orderId: item.id, requestId: `proof-${item.id}-1234567890`, action: "return",
    contingencyReason: "Mercadoria recebida e conferida integralmente intacta",
    confirmation: `CONFIRMAR ${item.id}`, expectedRevision: order.deliveryIncidentRevision || 0,
    expectedStatus: order.status, returnCondition: "intact", returnAuthorized: true,
  }});
}
async function webhook(item, paid = true, terminal = "canceled") {
  const order = await get(`orders/${item.id}`); const mpId = order.mercadoPagoOrderId;
  const body = providers.get(mpId); assert.ok(body);
  body.status = paid ? "processed" : terminal; body.status_detail = paid ? "accredited" : "expired";
  body.transactions.payments[0].status = paid ? "processed" : "canceled";
  const ts = String(Math.floor(Date.now() / 1000)); const requestId = "test-hook-request";
  const signature = createHmac("sha256", "TEST_ONLY")
      .update(`id:${mpId};request-id:${requestId};ts:${ts};`).digest("hex");
  let code;
  const response = Object.assign(new EventEmitter(), {status: (value) => {
    code = value; return response;
  },
  json: () => {}, send: () => {}});
  await endpoints.chamaeMercadoPagoWebhook({method: "POST", headers: {}, query: {"data.id": mpId},
    body: {type: "order", live_mode: false},
    get: (name) => name === "x-signature" ? `ts=${ts},v1=${signature}` : requestId},
  response);
  assert.equal(code, 200);
}

test("before PIX/reservation: authoritative cancellation blocks stale triggers and new direct PIX", async () => {
  for (const method of ["PIX", "Dinheiro"]) {
    const item = await seed(method, "BR", false); const postCount = posts.length;
    await cancel(item.id);
    await functions[method === "PIX" ? "chamaeCriarPixAutomatico" : "chamaeReservarEstoquePagamentoEntrega"]({
      params: {orderId: item.id}, data: item.original,
    });
    assert.equal((await item.ref.get()).data().status, "Cancelado");
    assert.equal((await db.doc(`orderFinancials/${item.id}`).get()).exists, false);
    assert.equal((await stock(item)).reservedStock, 0); assert.equal(posts.length, postCount);
  }
});
for (const [method, country] of [["Dinheiro", "BR"], ["Maquininha", "BR"], ["Dinheiro", "PY"],
  ["Pagamento dividido", "PY"]]) {
  test(`${method}/${country}: RELEASE once, financial/3% preserved and no commission in closing`, async () => {
    const item = await seed(method, country);
    const financial = await get(`orderFinancials/${item.id}`);
    assert.equal((await stock(item)).reservedStock, 2);
    await Promise.all([cancel(item.id), cancel(item.id)]);
    await cancel(item.id, `${item.id}-other-request-123456`); await resolve(item);
    assert.equal((await stock(item)).stock, 10); assert.equal((await stock(item)).reservedStock, 0);
    assert.equal((await item.ref.get()).data().stockReservationStatus, "released");
    assert.deepEqual(await get(`orderFinancials/${item.id}`), financial);
    assert.equal((await get(`orderCompensations/${item.id}`)).commissionAdjustmentStatus, "excluded_from_closing");
    assert.equal((await get(`orderCompensations/${item.id}`)).originalMerchantFee, financial.merchantFee);
    assert.equal((await item.ref.get()).data().paymentStatus, "Pendente na entrega");
  });
}
test("PIX pending: no invented void/refund and no new charge; late paid webhook never debits or reopens", async () => {
  const item = await seed("PIX"); const financial = await get(`orderFinancials/${item.id}`);
  const postCount = posts.length; await cancel(item.id);
  assert.equal((await get(`orderCompensations/${item.id}`)).refundStatus, "verification_required");
  await functions.chamaeCriarPixAutomatico({params: {orderId: item.id}, data: item.original});
  assert.equal(posts.length, postCount);
  await webhook(item); await webhook(item);
  const order = (await item.ref.get()).data();
  assert.equal(order.status, "Cancelado"); assert.equal(order.paymentStatus, "Pago");
  assert.equal((await stock(item)).stock, 10);
  assert.equal((await get(`orderCompensations/${item.id}`)).refundStatus, "required");
  assert.deepEqual(await get(`orderFinancials/${item.id}`), financial);
});
for (const terminal of ["canceled", "failed"]) {
  test(`official PIX ${terminal}/expired: idempotent cancel and late-payment compensation`, async () => {
    const item = await seed("PIX"); await webhook(item, false, terminal); await webhook(item, false, terminal);
    assert.equal((await item.ref.get()).data().status, "Cancelado");
    assert.equal((await get(`orderCompensations/${item.id}`)).providerCancellationStatus, "confirmed");
    await webhook(item); assert.equal((await stock(item)).stock, 10);
    assert.equal((await item.ref.get()).data().paymentStatus, "Pago");
  });
}
test("paid PIX: separate cancellation, refund need and authorized RESTOCK", async () => {
  const item = await seed("PIX"); await webhook(item);
  const financial = await get(`orderFinancials/${item.id}`);
  await assert.rejects(cancel(item.id, undefined, "operations_admin"), {code: "permission-denied"});
  await cancel(item.id); assert.equal((await stock(item)).stock, 8);
  assert.equal((await item.ref.get()).data().paymentStatus, "Pago");
  assert.equal((await get(`orderCompensations/${item.id}`)).refundStatus, "required");
  await proveReturn(item);
  await Promise.all([restock(item.id), restock(item.id)]); await restock(item.id, "return-again-123456");
  await webhook(item);
  assert.equal((await stock(item)).stock, 10);
  assert.equal((await item.ref.get()).data().status, "Cancelado");
  assert.deepEqual(await get(`orderFinancials/${item.id}`), financial);
});
test("completed order: separate return preserves completion, payment, snapshot and sale count", async () => {
  const item = await seed(); await item.ref.update({status: "Concluído",
    deliveryConfirmedAt: Timestamp.now(), deliveryCollectionConfirmedAt: Timestamp.now()}); await resolve(item);
  const financial = await get(`orderFinancials/${item.id}`);
  assert.equal((await stock(item)).stock, 8);
  await assert.rejects(cancel(item.id), (e) => e.details.reason === "COMPLETED_ORDER_REQUIRES_RETURN");
  await proveReturn(item);
  await restock(item.id); await resolve(item);
  assert.equal((await stock(item)).stock, 10); assert.equal((await stock(item)).salesCount, 2);
  assert.equal((await item.ref.get()).data().status, "Concluído");
  assert.equal((await item.ref.get()).data().paymentStatus, "Pago");
  assert.deepEqual(await get(`orderFinancials/${item.id}`), financial);
});
test("no RESTOCK without commit, authorization, matching official items or known local stock model", async () => {
  const pending = await seed(); await assert.rejects(restock(pending.id));
  await assert.rejects(functions.chamaeAutorizarDevolucaoPedido(
      command(pending.id, "restock", undefined, "operations_admin")));
  const mapped = await seed(); await db.doc(`products/${mapped.id}`).update({PRO_CODIGO: 123});
  await assert.rejects(cancel(mapped.id), (e) => e.details.reason === "INTEGRATED_STOCK_COMPENSATION_UNAVAILABLE");
  assert.equal((await stock(mapped)).reservedStock, 2);
  const changed = await seed(); await changed.ref.update({itemsList: [{id: changed.id, quantity: 3}]});
  await assert.rejects(cancel(changed.id)); assert.equal((await stock(changed)).reservedStock, 2);
});
test("cancellation/webhook race: explicit refunds and no duplicate stock movement", async () => {
  for (let i = 0; i < 3; i++) {
    const item = await seed("PIX");
    await Promise.all([cancel(item.id), webhook(item)]); await webhook(item); await cancel(item.id);
    const order = (await item.ref.get()).data(); const product = await stock(item);
    assert.equal(order.status, "Cancelado"); assert.equal(order.paymentStatus, "Pago");
    assert.ok([8, 10].includes(product.stock));
    const compensation = await get(`orderCompensations/${item.id}`);
    assert.equal(compensation.refundStatus, "required");
    if (product.stock === 8) {
      assert.equal(compensation.inventoryState, "committed"); await restock(item.id);
    }
    assert.equal((await stock(item)).stock, 10);
  }
});
test("late POST response and error cannot reopen cancelled/paid state", async () => {
  const item = await seed("PIX"); await cancel(item.id);
  await savePixCreation(db, item.ref, {status: "Aguardando pagamento", paymentStatus: "Aguardando confirmação",
    mercadoPagoOrderId: (await item.ref.get()).data().mercadoPagoOrderId, mercadoPagoStatus: "action_required"});
  await updateActiveOrder(db, item.ref, {status: "Revisão de estoque"});
  assert.equal((await item.ref.get()).data().status, "Cancelado");
  await webhook(item);
  await savePixCreation(db, item.ref, {paymentStatus: "Aguardando confirmação", mercadoPagoStatus: "action_required"});
  assert.equal((await item.ref.get()).data().paymentStatus, "Pago");
  assert.equal((await item.ref.get()).data().mercadoPagoStatus, "processed");
});
test("RELEASE rollback and durable replay after lost ACK/restart", async () => {
  const item = await seed(); const req = command(item.id); const cmd = input(req, "cancel");
  const transaction = db.runTransaction.bind(db);
  const broken = mock.method(db, "runTransaction", (fn) => transaction((tx) => fn(new Proxy(tx, {
    get(target, key) {
      if (key === "set") {
        return (ref, ...args) => {
          if (ref.path === `orderCancellations/${item.id}`) throw new Error("AFTER_RELEASE_BEFORE_COMMIT");
          return target.set(ref, ...args);
        };
      }
      const value = target[key]; return typeof value === "function" ? value.bind(target) : value;
    },
  }))));
  try {
    await assert.rejects(cancel(item.id), /AFTER_RELEASE_BEFORE_COMMIT/);
  } finally {
    broken.mock.restore();
  }
  assert.equal((await stock(item)).reservedStock, 2);
  assert.equal((await item.ref.get()).data().status, "Novo");
  assert.equal((await db.doc(`orderCancellations/${item.id}`).get()).exists, false);
  const lost = mock.method(db, "runTransaction", async (fn) => {
    await transaction(fn); throw new Error("ACK_LOST_AFTER_COMMIT");
  });
  try {
    await assert.rejects(cancel(item.id), /ACK_LOST_AFTER_COMMIT/);
  } finally {
    lost.mock.restore();
  }
  await cancel(item.id);
  const original = await stock(item);
  const restarted = await compensate(db, cmd, "cancel", {release: () => assert.fail("replay cannot release")});
  assert.equal(restarted.replayed, true); assert.deepEqual(await stock(item), original);
  const other = await seed(); const reused = command(other.id, "cancel", req.data.requestId);
  await assert.rejects(functions.chamaeCancelarPedido(reused), {code: "already-exists"});
});
test("SDK cannot cancel, confirm refund, mutate commission/stock or read private reasons/receipts", async () => {
  const item = await seed(); await cancel(item.id);
  const client = env.authenticatedContext("buyer", {firebase: {sign_in_provider: "google.com"}}).firestore();
  for (const patch of [{status: "Cancelado"}, {refundStatus: "confirmed"}, {compensationStatus: "completed"},
    {paymentStatus: "Pago"}, {commissionStatus: "paid"}]) {
    await assertFails(updateDoc(doc(client, `orders/${item.id}`), patch));
  }
  for (const col of ["orderCancellations", "orderReturns", "orderCompensations", "orderCompensationAudit",
    "orderCompensationRequests"]) {
    await assertFails(getDoc(doc(client, `${col}/${item.id}`)));
    await assertFails(setDoc(doc(client, `${col}/${item.id}`), {refundStatus: "confirmed"}));
  }
});

test("expired PIX with a proven local reservation releases once and rejects a late COMMIT", async () => {
  const item = await seed(); const financial = await get(`orderFinancials/${item.id}`);
  const mpId = `MP_${item.id}`;
  await item.ref.update({paymentMethod: "PIX", pixRequested: true, mercadoPagoOrderId: mpId});
  providers.set(mpId, {id: mpId, external_reference: item.id, total_amount: financial.totalBRL,
    processing_mode: "automatic", transactions: {payments: [{id: "TEST_PAY", payment_method: {
      id: "pix", type: "bank_transfer"}}]}});
  const before = (await item.ref.get()).data();
  await webhook(item, false); await webhook(item, false);
  assert.equal((await stock(item)).reservedStock, 0); assert.equal((await stock(item)).stock, 10);
  await functions.chamaeResolverReservaEstoque({params: {orderId: item.id}, data: {after: {
    exists: true, ref: item.ref, data: () => ({...before, status: "Concluído"}),
  }}});
  assert.equal((await item.ref.get()).data().status, "Cancelado");
  assert.equal((await stock(item)).stock, 10);
  await assert.rejects(functions.chamaeConcluirEntrega({auth: command(item.id).auth, data: {
    orderId: item.id, requestId: `complete-${item.id}-123456`,
    contingencyReason: "Tentativa tardia de conclusão de ensaio", confirmation: `CONFIRMAR ${item.id}`,
  }}));
});

test("wrong payment amount after cancellation cannot invent paid/refund-confirmed or change stock", async () => {
  const item = await seed("PIX"); await cancel(item.id);
  const order = (await item.ref.get()).data();
  const provider = providers.get(order.mercadoPagoOrderId);
  provider.total_amount = "0.01";
  await webhook(item);
  assert.equal((await item.ref.get()).data().paymentStatus, "Aguardando confirmação");
  assert.equal((await get(`orderCompensations/${item.id}`)).refundStatus, "verification_required");
  assert.equal((await stock(item)).stock, 10);
});

test("RESTOCK refuses removed/unsafe stock product and leaves return ledger and snapshot intact", async () => {
  const item = await seed(); await item.ref.update({status: "Concluído",
    deliveryConfirmedAt: Timestamp.now(), deliveryCollectionConfirmedAt: Timestamp.now()}); await resolve(item);
  await proveReturn(item);
  const financial = await get(`orderFinancials/${item.id}`);
  await db.doc(`products/${item.id}`).update({stock: Number.MAX_SAFE_INTEGER});
  await assert.rejects(restock(item.id), (e) => e.details.reason === "RESTOCK_PRODUCT_REVIEW_REQUIRED");
  assert.equal((await db.doc(`orderReturns/${item.id}`).get()).exists, false);
  await db.doc(`products/${item.id}`).delete();
  await assert.rejects(restock(item.id));
  assert.deepEqual(await get(`orderFinancials/${item.id}`), financial);
  assert.equal((await item.ref.get()).data().status, "Concluído");
});

test("financial rejection before any effect can be cancelled without changing snapshots or creating PIX", async () => {
  const item = await seed("Dinheiro", "BR", false);
  await item.ref.update({status: "Revisão financeira", financialValidationStatus: "rejected"});
  await cancel(item.id);
  assert.equal((await item.ref.get()).data().status, "Cancelado");
  assert.equal((await item.ref.get()).data().financialValidationStatus, "rejected");
  assert.equal((await db.doc(`orderFinancials/${item.id}`).get()).exists, false);
  assert.equal((await stock(item)).stock, 10);
});

test("lost RESTOCK ACK is replayed without second return or deleting the original payment", async () => {
  const item = await seed(); await item.ref.update({status: "Concluído",
    deliveryConfirmedAt: Timestamp.now(), deliveryCollectionConfirmedAt: Timestamp.now()}); await resolve(item);
  await proveReturn(item);
  const transaction = db.runTransaction.bind(db);
  const lost = mock.method(db, "runTransaction", async (fn) => {
    await transaction(fn); throw new Error("RESTOCK_ACK_LOST");
  });
  try {
    await assert.rejects(restock(item.id), /RESTOCK_ACK_LOST/);
  } finally {
    lost.mock.restore();
  }
  await restock(item.id); await restock(item.id);
  assert.equal((await stock(item)).stock, 10);
  assert.equal((await item.ref.get()).data().paymentStatus, "Pago");
});

test("conflicting late PIX response preserves the original transaction ID and records both IDs privately", async () => {
  const item = await seed("PIX"); const previous = (await item.ref.get()).data();
  await savePixCreation(db, item.ref, {mercadoPagoOrderId: "DIFFERENT_PROVIDER_ID", paymentStatus: "Pago"});
  assert.equal((await item.ref.get()).data().mercadoPagoOrderId, previous.mercadoPagoOrderId);
  assert.equal((await item.ref.get()).data().paymentStatus, previous.paymentStatus);
  const audit = await db.collection("orderCompensationAudit").where("orderId", "==", item.id).get();
  assert.equal(audit.docs[0].data().observedProviderId, "DIFFERENT_PROVIDER_ID");
  assert.equal((await get(`orderCompensations/${item.id}`)).refundStatus, "verification_required");
});
