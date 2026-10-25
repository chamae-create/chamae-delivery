const {before, after, test, mock} = require("node:test");
const assert = require("node:assert/strict");
const {randomUUID} = require("node:crypto");
const {initializeApp, deleteApp} = require("firebase-admin/app");
const {getFirestore, Timestamp, GeoPoint} = require("firebase-admin/firestore");
const {initializeTestEnvironment, assertFails, assertSucceeds} = require("@firebase/rules-unit-testing");
const {doc, getDoc, setDoc, updateDoc, serverTimestamp} = require("firebase/firestore");
const {loadBackend} = require("./backend-fixture");
const {deliveryFixture} = require("./delivery-fixture");
const {rulesAt} = require("./operational-fixture");
let app; let db; let env; let backend; let count = 0;
const auth = {uid: "kb05-operator", token: {roles: ["superadmin"]}};
const req = (id, patch = {}) => ({auth, data: {orderId: id, requestId: randomUUID(),
  contingencyReason: "Ocorrência operacional conferida no ensaio", confirmation: `CONFIRMAR ${id}`, ...patch}});
const read = async (path) => (await db.doc(path).get()).data();
const order = (item) => read(`orders/${item.id}`);
const stock = (item) => read(`products/${item.id}`);
const incident = async (item, action = "attempt", patch = {}) => {
  const current = await order(item);
  return req(item.id, {action, expectedStatus: current.status,
    expectedRevision: current.deliveryIncidentRevision || 0,
    ...(action === "attempt" ? {reasonCode: "customer_not_located"} : {}),
    ...(action === "return" ? {returnCondition: "intact", returnAuthorized: true} : {}), ...patch});
};
const apply = (request) => backend.chamaeRegistrarContingenciaEntrega(request);
const complete = async (item, patch = {}) => backend.chamaeConcluirEntrega(req(item.id, {
  deliveryConfirmed: true, collectionConfirmed: true,
  expectedDeliveryRevision: (await order(item)).deliveryIncidentRevision || 0, ...patch}));
const compensate = (item, action = "cancel") => backend[action === "cancel" ? "chamaeCancelarPedido" :
  "chamaeAutorizarDevolucaoPedido"]({auth, data: {orderId: item.id, requestId: randomUUID(),
  reason: "Compensação operacional autorizada no ensaio", confirmation: `${action === "cancel" ? "CANCELAR" :
    "DEVOLVER"} ${item.id}`}});
const resolve = async (item) => backend.chamaeResolverReservaEstoque({params: {orderId: item.id},
  data: {after: await item.ref.get()}});
before(async () => {
  assert.equal(process.env.FIRESTORE_EMULATOR_HOST, "127.0.0.1:8187", "local demo emulator mandatory");
  env = await initializeTestEnvironment({projectId: "demo-chamae-rules", firestore: {
    host: "127.0.0.1", port: 8187, rules: rulesAt()}}); await env.clearFirestore();
  app = initializeApp({projectId: "demo-chamae-rules"}); db = getFirestore(app);
  backend = loadBackend(db).functions;
  const nativeFetch = global.fetch;
  mock.method(global, "fetch", (url, options) => {
    assert.ok(["127.0.0.1", "localhost"].includes(new URL(url).hostname), "external requests prohibited");
    return nativeFetch(url, options);
  });
  await db.doc("couriers/kb05-rider").set({name: "Entregador de ensaio", administrativeState: "active"});
});
after(async () => {
  mock.restoreAll(); if (env) await env.cleanup(); if (db) await db.terminate(); if (app) await deleteApp(app);
});
async function seed(stage = "route", method = "Dinheiro") {
  const id = `kb05-${++count}`;
  const delivery = deliveryFixture({quoteId: count.toString(16).padStart(64, "e")});
  for (const [path, value] of delivery.documents) await db.doc(path).set(value);
  await db.doc(`products/${id}`).set({priceBRL: 20, stock: 10, reservedStock: 0, salesCount: 0, isActive: true});
  const ref = db.doc(`orders/${id}`);
  await ref.set({id: `#${id}`, customerUid: "buyer", customerName: "Cliente ensaio",
    deliveryAddress: delivery.destination, deliveryQuoteId: delivery.quoteId,
    address: "Endereço de ensaio", deliveryLocation: new GeoPoint(-22.5, -55.7),
    itemsList: [{id, quantity: 2, price: 20}], status: "Novo", paymentMethod: method,
    paymentStatus: "Pendente na entrega", courierPaid: false, createdAt: Timestamp.now(),
    ...(method === "Pagamento dividido" ? {splitPayment: true, paymentParts: [
      {method: "Dinheiro", currency: "BRL", amountCurrency: 25},
      {method: "Dinheiro", currency: "BRL", amountCurrency: 30}]} : {})});
  await backend.chamaeReservarEstoquePagamentoEntrega({params: {orderId: id}, data: await ref.get()});
  await backend.chamaeIniciarSeparacao({auth, data: {orderId: id, requestId: randomUUID()}});
  await backend.chamaeAtribuirMotoboy(req(id, {courierUid: "kb05-rider", expectedCourierUid: ""}));
  if (stage !== "separation") await backend.chamaeDespacharPedido(req(id));
  return {id, ref};
}
async function committedPix(item) {
  // Explicit paid fixture. Actual provider signature/payment race is covered by KB-04 emulator regression.
  await item.ref.update({paymentStatus: "Pago", paymentMethod: "PIX", stockProcessingStatus: "processed",
    stockReservationStatus: "finalized", stockProcessed: true, stockProcessedBy: "mercado_pago_webhook"});
  await db.doc(`products/${item.id}`).update({stock: 8, reservedStock: 0, salesCount: 2});
}

for (const reasonCode of ["customer_not_located", "wrong_address", "no_answer", "refused", "no_change",
  "payment_refused", "courier_problem", "vehicle_broken", "delivery_interrupted"]) {
  test(`${reasonCode}: records private attempt, no payment/status/stock/finance mutation`, async () => {
    const item = await seed(); const original = await order(item); const inventory = await stock(item);
    const financial = await read(`orderFinancials/${item.id}`);
    await apply(await incident(item, "attempt", {reasonCode}));
    const current = await order(item);
    assert.equal(current.status, "Saiu para Entrega"); assert.equal(current.deliveryIncidentStatus, "pending");
    assert.equal(current.paymentStatus, original.paymentStatus); assert.deepEqual(await stock(item), inventory);
    assert.deepEqual(await read(`orderFinancials/${item.id}`), financial);
    assert.equal(current.contingencyReason, undefined);
    const events = await db.collection(`orderDeliveryIncidents/${item.id}/events`).get();
    assert.equal(events.size, 1); const event = events.docs[0].data();
    assert.equal(event.reasonCode, reasonCode); assert.equal(event.actorUid, auth.uid);
    assert.ok(event.createdAt instanceof Timestamp); assert.equal(event.stockAction, "none");
  });
}
test("cash/card completion rejects missing delivery or uncollected payment before commit", async () => {
  for (const method of ["Dinheiro", "Maquininha"]) {
    const item = await seed("route", method);
    for (const patch of [{deliveryConfirmed: false}, {collectionConfirmed: false}]) {
      await assert.rejects(complete(item, patch));
      assert.equal((await stock(item)).stock, 10);
      assert.equal((await order(item)).paymentStatus, "Pendente na entrega");
    }
    await complete(item); await complete(item); await resolve(item);
    assert.equal((await stock(item)).stock, 8); assert.equal((await stock(item)).salesCount, 2);
    assert.equal((await order(item)).status, "Concluído");
  }
});
test("full successful delivery explicitly resolves a pending failed attempt and commits once", async () => {
  const item = await seed(); await apply(await incident(item));
  await complete(item); await complete(item); await resolve(item);
  assert.equal((await order(item)).deliveryIncidentStatus, "resolved");
  assert.equal((await stock(item)).stock, 8); assert.equal((await order(item)).paymentStatus, "Pago");
  assert.equal((await read(`orderDeliveryIncidents/${item.id}`)).resolutionRequired, false);
});
test("paid PIX failure keeps payment/commit; intact return alone never restocks/refunds", async () => {
  const item = await seed(); await committedPix(item);
  const financial = await read(`orderFinancials/${item.id}`);
  await apply(await incident(item, "attempt", {reasonCode: "refused"}));
  assert.equal((await read(`orderDeliveryIncidents/${item.id}`)).refundReviewRequired, true);
  await apply(await incident(item, "return")); await resolve(item);
  assert.equal((await order(item)).paymentStatus, "Pago"); assert.equal((await stock(item)).stock, 8);
  await assert.rejects(complete(item));
  await compensate(item); await Promise.all([compensate(item, "restock"), compensate(item, "restock")]);
  assert.equal((await stock(item)).stock, 10); assert.equal((await order(item)).paymentStatus, "Pago");
  assert.equal((await read(`orderCompensations/${item.id}`)).refundStatus, "required");
  assert.deepEqual(await read(`orderFinancials/${item.id}`), financial);
});
test("in-route reserved cancellation fails before RELEASE until intact authorized physical return", async () => {
  const item = await seed(); await assert.rejects(compensate(item));
  await apply(await incident(item)); await assert.rejects(compensate(item));
  assert.equal((await stock(item)).reservedStock, 2);
  await apply(await incident(item, "return"));
  await Promise.all([compensate(item), compensate(item)]); await resolve(item);
  assert.equal((await stock(item)).reservedStock, 0); assert.equal((await stock(item)).stock, 10);
  assert.equal((await order(item)).paymentStatus, "Pendente na entrega");
});
for (const returnCondition of ["partial", "nonreturnable"]) {
  test(`${returnCondition}: no full RELEASE, RESTOCK or completion; manual review`, async () => {
    for (const committed of [false, true]) {
      const item = await seed(); if (committed) await committedPix(item);
      await apply(await incident(item, "return", {returnCondition}));
      const inventory = await stock(item);
      await assert.rejects(complete(item));
      if (committed) {
        await compensate(item); await assert.rejects(compensate(item, "restock"));
      } else await assert.rejects(compensate(item));
      assert.deepEqual(await stock(item), inventory);
    }
  });
}
test("future redelivery stays manual pending, no duplicate charge/fee/stock and no completion", async () => {
  const item = await seed(); const financial = await read(`orderFinancials/${item.id}`);
  await apply(await incident(item)); await apply(await incident(item, "return"));
  const command = await incident(item, "redelivery"); await apply(command); await apply(command);
  await assert.rejects(complete(item)); await assert.rejects(backend.chamaeDespacharPedido(req(item.id)));
  assert.equal((await order(item)).status, "Saiu para Entrega");
  assert.equal((await order(item)).deliveryIncidentStatus, "redelivery_pending");
  assert.deepEqual(await read(`orderFinancials/${item.id}`), financial); assert.equal((await stock(item)).stock, 10);
});
test("separation failure blocks assignment/departure; pre-departure cancellation follows KB-04", async () => {
  const untouched = await seed("separation"); await compensate(untouched);
  assert.equal((await stock(untouched)).reservedStock, 0);
  const item = await seed("separation"); await apply(await incident(item));
  await assert.rejects(backend.chamaeDespacharPedido(req(item.id)));
  await assert.rejects(backend.chamaeAtribuirMotoboy(req(item.id, {courierUid: "kb05-rider"})));
});
test("lost ACK, process restart, duplicate and out-of-order requests preserve one event", async () => {
  const item = await seed(); const command = await incident(item);
  const transaction = db.runTransaction.bind(db);
  const lost = mock.method(db, "runTransaction", async (fn) => {
    await transaction(fn); throw new Error("CONNECTION_LOST_AFTER_COMMIT");
  });
  try {
    await assert.rejects(apply(command), /CONNECTION_LOST_AFTER_COMMIT/);
  } finally {
    lost.mock.restore();
  }
  const restarted = require("../delivery-contingency").createDeliveryContingency(db);
  assert.equal((await restarted.chamaeRegistrarContingenciaEntrega.run(command)).replayed, true);
  await apply(command);
  await assert.rejects(apply({...command, data: {...command.data, requestId: randomUUID()}}), {code: "aborted"});
  await assert.rejects(apply({...command, data: {...command.data, reasonCode: "refused"}}), {code: "already-exists"});
  assert.equal((await db.collection(`orderDeliveryIncidents/${item.id}/events`).get()).size, 1);
});
test("transaction failure leaves no event, flag or receipt", async () => {
  const item = await seed(); const command = await incident(item);
  const transaction = db.runTransaction.bind(db);
  const broken = mock.method(db, "runTransaction", (fn) => transaction((tx) => fn(new Proxy(tx, {
    get(target, key) {
      if (key === "create") {
        return () => {
          throw new Error("WRITE_FAILURE");
        };
      }
      const value = target[key]; return typeof value === "function" ? value.bind(target) : value;
    },
  }))));
  try {
    await assert.rejects(apply(command), /WRITE_FAILURE/);
  } finally {
    broken.mock.restore();
  }
  assert.equal((await order(item)).deliveryIncidentStatus, undefined);
  assert.equal((await db.doc(`orderDeliveryIncidents/${item.id}`).get()).exists, false);
  await apply(command); assert.equal((await order(item)).deliveryIncidentRevision, 1);
});
test("incident/conclusion and incident/cancellation races preserve status and commit", async () => {
  const item = await seed(); const command = await incident(item);
  await Promise.allSettled([apply(command), complete(item)]);
  const current = await order(item);
  assert.ok(current.status === "Concluído" && current.deliveryIncidentStatus !== "pending" ||
    current.status === "Saiu para Entrega" && current.deliveryIncidentStatus === "pending");
  assert.equal((await stock(item)).stock, current.status === "Concluído" ? 8 : 10);
  const cancelled = await seed(); await committedPix(cancelled);
  const old = await incident(cancelled);
  await Promise.allSettled([apply(old), compensate(cancelled)]);
  assert.equal((await order(cancelled)).status, "Cancelado");
  await assert.rejects(apply(await incident(cancelled)));
});
test("completed history cannot reopen/cancel; authorized return preserves completion and payment", async () => {
  const item = await seed(); await complete(item); const before = await order(item);
  await assert.rejects(apply(await incident(item))); await assert.rejects(compensate(item));
  await apply(await incident(item, "return")); await compensate(item, "restock");
  const after = await order(item); assert.equal(after.status, "Concluído");
  assert.ok(after.completedAt.isEqual(before.completedAt)); assert.equal(after.paymentStatus, "Pago");
  assert.equal((await stock(item)).salesCount, 2);
});
test("split failure preserves confirmed parts and all original frozen amounts", async () => {
  const item = await seed("route", "Pagamento dividido");
  const before = await order(item); const financial = await read(`orderFinancials/${item.id}`);
  await apply(await incident(item, "attempt", {reasonCode: "payment_refused"}));
  await assert.rejects(complete(item, {collectionConfirmed: false}));
  assert.deepEqual((await order(item)).paymentParts, before.paymentParts);
  assert.deepEqual(await read(`orderFinancials/${item.id}`), financial);
});
test("legacy cancellation trigger in route cannot RELEASE without physical return proof", async () => {
  const item = await seed();
  // Simulate a stale trusted integration writing terminal status, never an allowed SDK write.
  await item.ref.update({status: "Cancelado"}); await resolve(item);
  assert.equal((await stock(item)).reservedStock, 2); assert.equal((await stock(item)).stock, 10);
  assert.equal((await order(item)).stockReservationStatus, "reserved");
  await apply(await incident(item, "return")); await resolve(item); await resolve(item);
  assert.equal((await stock(item)).reservedStock, 0); assert.equal((await stock(item)).stock, 10);
});
test("valid committed cancellation still requires physical evidence before authorized RESTOCK", async () => {
  const item = await seed(); await committedPix(item); await compensate(item);
  await assert.rejects(compensate(item, "restock"), (error) =>
    error.details.reason === "INTACT_AUTHORIZED_RETURN_REQUIRED");
  assert.equal((await stock(item)).stock, 8);
  assert.equal((await db.doc(`orderReturns/${item.id}`).get()).exists, false);
});
test("stale panel completion revision cannot override a newly recorded failure", async () => {
  const item = await seed(); await apply(await incident(item));
  await assert.rejects(complete(item, {expectedDeliveryRevision: 0}));
  assert.equal((await stock(item)).stock, 10); assert.equal((await stock(item)).reservedStock, 2);
  assert.equal((await order(item)).paymentStatus, "Pendente na entrega");
});
test("paid PIX can resolve a failed attempt only after full delivery attestation, no second commit", async () => {
  const item = await seed(); await committedPix(item); await apply(await incident(item));
  const financial = await read(`orderFinancials/${item.id}`);
  await complete(item, {collectionConfirmed: false}); await complete(item, {collectionConfirmed: false});
  assert.equal((await order(item)).status, "Concluído"); assert.equal((await order(item)).paymentStatus, "Pago");
  assert.equal((await stock(item)).stock, 8); assert.equal((await stock(item)).salesCount, 2);
  assert.deepEqual(await read(`orderFinancials/${item.id}`), financial);
});
test("SDK/direct callers cannot forge incident, collection, return or read internal observations", async () => {
  const item = await seed(); await apply(await incident(item));
  for (const role of ["customer", "operations_admin", "courier", "finance"]) {
    const client = env.authenticatedContext(`reader-${role}`, {roles: [role]}).firestore();
    await assertFails(getDoc(doc(client, `orderDeliveryIncidents/${item.id}`)));
    await assertFails(getDoc(doc(client, `orderDeliveryIncidents/${item.id}/events/any`)));
    await assertFails(updateDoc(doc(client, `orders/${item.id}`), {deliveryIncidentStatus: "resolved",
      deliveryConfirmedAt: serverTimestamp(), deliveryCollectionConfirmedAt: serverTimestamp()}));
    await assertFails(setDoc(doc(client, `orderDeliveryIncidents/${item.id}`), {returnAuthorized: true}));
    await assert.rejects(apply({...await incident(item), auth: {uid: `reader-${role}`, token: {roles: [role]}}}));
  }
  const admin = env.authenticatedContext(auth.uid, {roles: ["superadmin"]}).firestore();
  await assertSucceeds(getDoc(doc(admin, `orderDeliveryIncidents/${item.id}`)));
  await db.doc(`couriers/${auth.uid}`).set({name: "Operador também entregador", administrativeState: "active"});
  await assert.rejects(apply(await incident(item)), {code: "permission-denied"});
  await assertFails(getDoc(doc(admin, `orderDeliveryIncidents/${item.id}`)));
});
