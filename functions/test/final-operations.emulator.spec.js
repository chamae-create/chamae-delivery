const assert = require("node:assert/strict");
const {test, before, after} = require("node:test");
const {randomUUID} = require("node:crypto");
const {initializeApp, deleteApp} = require("firebase-admin/app");
const {getFirestore, Timestamp, GeoPoint} = require("firebase-admin/firestore");
const {loadBackend} = require("./backend-fixture");
const {deliveryFixture} = require("./delivery-fixture");
let app; let db; let backend; let n = 0;
const actor = (role = "operations_admin") => ({uid: `actor-${role}`,
  token: {roles: [role]}});
const request = (id, role, extra = {}) => ({auth: actor(role), data: {
  orderId: id, requestId: randomUUID(), ...extra}});
const exceptional = (id, extra = {}) => request(id, "superadmin", {
  contingencyReason: "Aparelho do motoboy com falha física",
  confirmation: `CONFIRMAR ${id}`, ...extra});
before(async () => {
  assert.equal(process.env.FIRESTORE_EMULATOR_HOST, "127.0.0.1:8187");
  app = initializeApp({projectId: "demo-chamae-rules"}); db = getFirestore(app);
  backend = loadBackend(db).functions;
  await db.doc("couriers/final-rider").set({name: "Motoboy teste",
    administrativeState: "active"});
});
after(async () => {
  if (db) await db.terminate(); if (app) await deleteApp(app);
});
/** Creates a validated fixture.
 * @return {Promise<Object>} Order reference and ID.
 */
async function seed() {
  const id = `final-${++n}`;
  const delivery = deliveryFixture({quoteId: n.toString(16).padStart(64, "c")});
  for (const [documentPath, data] of delivery.documents) {
    await db.doc(documentPath).set(data);
  }
  await db.doc(`products/${id}`).set({priceBRL: 20, stock: 20,
    reservedStock: 0, isActive: true});
  const ref = db.doc(`orders/${id}`);
  await ref.set({id: `#FINAL-${n}`, customerUid: "buyer",
    deliveryAddress: delivery.destination, deliveryQuoteId: delivery.quoteId,
    customerName: "Cliente teste",
    address: "Rua de teste", deliveryLocation: new GeoPoint(-22.5, -55.7),
    itemsList: [{id, quantity: 1, price: 20}], totalBRL: 30.2,
    status: "Novo", paymentMethod: "Maquininha",
    paymentStatus: "Pendente na entrega",
    createdAt: Timestamp.now(), courierPaid: false});
  await backend.chamaeReservarEstoquePagamentoEntrega({
    params: {orderId: id}, data: await ref.get()});
  return {id, ref};
}
test("normal roles cannot mutate courier delivery", async () => {
  const {id, ref} = await seed();
  for (const role of ["operations_admin", "superadmin", "finance",
    "catalog_admin", "courier"]) {
    for (const fn of ["chamaeAtribuirMotoboy", "chamaeDespacharPedido",
      "chamaeConcluirEntrega"]) {
      await assert.rejects(backend[fn](request(id, role,
          {courierUid: "final-rider"})),
      (e) => ["permission-denied", "failed-precondition"].includes(e.code));
    }
  }
  assert.equal((await ref.get()).data().status, "Novo");
});
test("separation prepares an idempotent dispatch contract", async () => {
  const {id, ref} = await seed();
  const req = request(id);
  await backend.chamaeIniciarSeparacao(req);
  const dispatch = db.doc(`courierDispatchRequests/${id}`);
  const first = (await dispatch.get()).data();
  assert.equal((await ref.get()).data().status, "Em Separação");
  assert.equal((await ref.get()).data().courierDispatchState,
      "awaiting_integration");
  assert.equal(first.offerSeconds, 15);
  assert.equal(first.firstWave, "longest_idle_first");
  assert.equal(first.secondWave, "all_available");
  assert.equal(first.acceptance, "atomic_first_valid_accept");
  assert.equal(first.pickup, "validated_app_qr_event");
  assert.equal(first.completion, "validated_app_delivery_event");
  await backend.chamaeIniciarSeparacao(req);
  await backend.chamaeIniciarSeparacao(request(id));
  assert.ok((await dispatch.get()).data().requestedAt
      .isEqual(first.requestedAt));
  assert.equal((await ref.get()).data().courierUid || "", "");
});
test("contingency is explicit, atomic and audited", async () => {
  const {id, ref} = await seed();
  await backend.chamaeIniciarSeparacao(request(id));
  for (const extra of [{contingencyReason: ""},
    {confirmation: "CONFIRMAR outro"}]) {
    await assert.rejects(backend.chamaeAtribuirMotoboy(exceptional(id, {
      courierUid: "final-rider", ...extra})),
    (e) => e.code === "failed-precondition");
  }
  const req = exceptional(id, {courierUid: "final-rider",
    expectedCourierUid: ""});
  await backend.chamaeAtribuirMotoboy(req);
  await backend.chamaeAtribuirMotoboy(req);
  let order = (await ref.get()).data();
  // Assignment never starts the route.
  assert.equal(order.status, "Em Separação");
  assert.equal(order.courierUid, "final-rider");
  const audit = await db.collection("operationalContingencyAudit")
      .where("orderId", "==", id).get();
  assert.equal(audit.size, 1);
  const row = audit.docs[0].data();
  assert.equal(row.actorUid, "actor-superadmin");
  assert.equal(row.reason, req.data.contingencyReason);
  assert.equal(row.previous.courierUid, "");
  assert.equal(row.next.courierUid, "final-rider");
  assert.ok(row.createdAt instanceof Timestamp);
  // An unsigned route string or caller-supplied event cannot grant departure.
  await assert.rejects(backend.chamaeDespacharPedido(request(id,
      "operations_admin", {
        qr: "https://maps.example/route", event: "pickup"})),
  (e) => e.code === "permission-denied");
  await backend.chamaeDespacharPedido(exceptional(id));
  await assert.rejects(backend.chamaeConcluirEntrega(request(id,
      "operations_admin", {
        event: "delivered"})), (e) => e.code === "permission-denied");
  await backend.chamaeConcluirEntrega(exceptional(id, {deliveryConfirmed: true,
    collectionConfirmed: true, expectedDeliveryRevision: 0}));
  order = (await ref.get()).data();
  assert.equal(order.status, "Concluído");
  const trail = await db.collection("operationalContingencyAudit")
      .where("orderId", "==", id).get();
  assert.equal(trail.size, 3);
  for (const action of ["dispatch", "complete"]) {
    assert.ok(trail.docs.some((d) => d.data().operation === action));
  }
  const completedAt = order.completedAt;
  await backend.chamaeConcluirEntrega(exceptional(id, {deliveryConfirmed: true,
    collectionConfirmed: true, expectedDeliveryRevision: 0}));
  const all = await db.collection("operationalContingencyAudit")
      .where("orderId", "==", id).get();
  assert.equal(all.size, 4, "confirmed no-op also leaves an audit trail");
  assert.ok((await ref.get()).data().completedAt.isEqual(completedAt));
});
