const assert = require("node:assert/strict");
const fs = require("node:fs");
const path = require("node:path");
const {randomUUID} = require("node:crypto");
const {before, after, test} = require("node:test");
const {initializeApp, deleteApp} = require("firebase-admin/app");
const {getFirestore, Timestamp, FieldValue} =
    require("firebase-admin/firestore");
const {initializeTestEnvironment, assertFails, assertSucceeds} =
    require("@firebase/rules-unit-testing");
const {doc, getDoc, getDocs, collection, query, where,
  setDoc, updateDoc, serverTimestamp, GeoPoint: ClientGeoPoint} =
    require("firebase/firestore");
const {loadBackend} = require("./backend-fixture");
const {changeCourier} = require("../courier-assignment");
const {customerPolicyFixture, customerProfileFixture} =
    require("./customer-policy-fixture");

let app;
let db;
let env;
let backend;
let n = 0;
const auth = (role = "operations_admin") => ({uid: `actor-${role}`,
  token: {roles: [role], firebase: {sign_in_provider: "password"}}});
const request = (data, role) => ({auth: auth(role),
  data: {requestId: randomUUID(), ...data}});
const client = (uid, role) => env.authenticatedContext(uid,
    role ? {roles: [role]} : {customerVerified: true,
      firebase: {sign_in_provider: "password"}}).firestore();
const act = (id, operation, extra = {}) => backend.functions[
  operation === "separate" ? "chamaeIniciarSeparacao" : "chamaeConcluirEntrega"
](request({orderId: id, ...(operation === "complete" ? {
  contingencyReason: "Falha do aparelho do motoboy",
  confirmation: `CONFIRMAR ${id}`} : {}),
...extra}, operation === "complete" ? "superadmin" : "operations_admin"));
const settle = (ids, extra = {}, role = "finance") =>
  backend.functions.chamaeRegistrarAcertoMotoboy(
      request({orderDocumentIds: ids, ...extra}, role));
const assign = (id, uid = "pilot-rider") => changeCourier(db,
    request({orderId: id, courierUid: uid,
      contingencyReason: "Falha do aparelho do motoboy",
      confirmation: `CONFIRMAR ${id}`}, "superadmin"));
const dispatch = (id) => changeCourier(db, request({orderId: id,
  contingencyReason: "Falha do aparelho do motoboy",
  confirmation: `CONFIRMAR ${id}`}, "superadmin"), "dispatch");
before(async () => {
  const host = process.env.FIRESTORE_EMULATOR_HOST;
  assert.ok(host, "Local emulator mandatory; no production fallback");
  const address = new URL(`http://${host}`);
  assert.ok(["localhost", "127.0.0.1", "[::1]"].includes(address.hostname));
  env = await initializeTestEnvironment({projectId: "demo-chamae-rules",
    firestore: {host: address.hostname, port: Number(address.port),
      rules: fs.readFileSync(path.join(__dirname, "../../firestore.rules"),
          "utf8")}});
  await env.clearFirestore();
  app = initializeApp({projectId: "demo-chamae-rules"});
  db = getFirestore(app);
  const policy = customerPolicyFixture();
  await db.doc("customerPolicies/current").set(policy);
  await db.doc("customerProfiles/buyer").set(
      customerProfileFixture(policy, Timestamp.fromMillis(1000)));
  backend = loadBackend(db);
  for (const uid of ["pilot-rider", "other-rider"]) {
    await db.doc(`couriers/${uid}`).set({name: `Oficial ${uid}`,
      administrativeState: "active"});
  }
});
after(async () => {
  if (env) await env.cleanup();
  if (db) await db.terminate();
  if (app) await deleteApp(app);
});

/** Creates through customer Rules and invokes the actual cash validator.
 * @return {Promise<string>} New documentary order ID.
 */
async function createOrder() {
  const id = `pilot-${++n}`;
  const productId = `pilot-product-${n}`;
  await db.doc(`products/${productId}`).set({priceBRL: 20, isActive: true,
    stock: 20, reservedStock: 0, salesCount: 0});
  await assertSucceeds(setDoc(doc(client("buyer"), "orders", id), {
    id: "#PILOT", customerUid: "buyer", customerName: "Ana",
    customerFlowVersion: 2,
    customerPhone: "PRIVATE_PHONE", address: "Rua das Flores, 123",
    deliveryAddress: {latitude: -22.5, longitude: -55.7,
      street: "Rua das Flores",
      city: "Cidade", number: "123", countryCode: "BR", confirmed: true},
    deliveryLocation: new ClientGeoPoint(-22.5, -55.7),
    itemsList: [{id: productId, quantity: 3, price: 0.01}],
    totalBRL: 1, itemsTotal: 1, deliveryFee: 1,
    customerFee: 1, merchantFee: 1, merchantNet: 1, platformFee: 1,
    paymentMethod: "Maquininha", paymentStatus: "Pendente na entrega",
    status: "Novo", courierPaid: false, createdAt: serverTimestamp(),
  }));
  const ref = db.doc(`orders/${id}`);
  await backend.functions.chamaeReservarEstoquePagamentoEntrega({
    params: {orderId: id}, data: await ref.get()});
  const order = (await ref.get()).data();
  assert.equal(order.financialValidationStatus, "validated");
  assert.equal(order.stockReservationStatus, "reserved");
  assert.equal(order.totalBRL, 70.60);
  assert.equal(order.deliveryFee, 10);
  return id;
}
const completed = async () => {
  const id = await createOrder();
  await act(id, "separate");
  await assign(id);
  await dispatch(id);
  await act(id, "complete");
  return id;
};

test("pilot E2E: create, official finance, operate, privacy, stock and cashier",
    async () => {
      const id = await createOrder();
      const operator = client("operator", "operations_admin");
      await assertSucceeds(getDoc(doc(operator, "orders", id)));
      await assertFails(getDocs(collection(env.unauthenticatedContext()
          .firestore(), "orders")));
      const owned = await assertSucceeds(getDocs(query(collection(
          client("buyer"), "orders"), where("customerUid", "==", "buyer"))));
      assert.ok(owned.docs.some((row) => row.id === id));
      await assertFails(getDoc(doc(client("other-buyer"), "orders", id)));
      await act(id, "separate");
      await assign(id);
      const rider = client("pilot-rider");
      const own = await assertSucceeds(getDoc(doc(rider,
          "courierDeliveries", id)));
      const safe = own.data();
      assert.equal(safe.customerName, "Ana");
      assert.equal(safe.address, "Rua das Flores, 123");
      assert.ok(safe.deliveryLocation);
      for (const key of ["customerPhone", "WhatsApp", "whatsapp", "email",
        "customerUid", "totalBRL", "deliveryFee", "merchantFee", "history",
        "mercadoPagoOrderId", "mercadoPagoPaymentId"]) {
        assert.equal(Object.hasOwn(safe, key), false, key);
      }
      assert.equal(JSON.stringify(safe).includes("PRIVATE"), false);
      await assertFails(getDoc(doc(rider, "orders", id)));
      await assertFails(getDoc(doc(client("other-rider"),
          "courierDeliveries", id)));
      await dispatch(id);
      assert.equal((await db.doc(`courierDeliveries/${id}`).get())
          .data().status, "Saiu para Entrega");
      const nonce = randomUUID();
      await act(id, "complete", {requestId: nonce});
      const order = (await db.doc(`orders/${id}`).get()).data();
      assert.equal(order.status, "Concluído");
      assert.equal(order.paymentStatus, "Pago");
      assert.ok(order.completedAt instanceof Timestamp);
      assert.equal(order.stockReservationStatus, "finalized");
      const product = db.doc(`products/${order.itemsList[0].id}`);
      assert.deepEqual((await product.get()).data(), {priceBRL: 20,
        isActive: true, stock: 17, reservedStock: 0, salesCount: 3});
      assert.equal((await db.doc(`courierDeliveries/${id}`).get())
          .data().status, "Concluído");
      const oldTime = (await product.get()).updateTime;
      await act(id, "complete", {requestId: nonce});
      await act(id, "complete");
      // Delayed trigger rechecks the same finalized order, never double debits.
      await backend.functions.chamaeResolverReservaEstoque({
        params: {orderId: id}, data: {
          after: await db.doc(`orders/${id}`).get()}});
      assert.ok((await product.get()).updateTime.isEqual(oldTime));
      const receipt = await settle([id]);
      const saved = (await db.doc(`courierSettlements/${receipt.settlementId}`)
          .get()).data();
      assert.equal(saved.total, 10);
      assert.equal(saved.actorUid, "actor-finance");
      assert.equal(saved.courierUid, "pilot-rider");
      await assert.rejects(settle([id]),
          (error) => error.code === "failed-precondition");
      await assertSucceeds(getDoc(doc(client("buyer"), "orders", id)));
      for (const [uid, role] of [["buyer", null],
        ["operator", "operations_admin"], ["boss", "superadmin"],
        ["cashier", "finance"]]) {
        const sdk = client(uid, role);
        await assertFails(updateDoc(doc(sdk, "orders", id), {totalBRL: 0.01}));
        await assertFails(updateDoc(doc(sdk, "orders", id), {status: "Novo"}));
        await assertFails(getDoc(doc(sdk, "orderFinancials", id)));
      }
      await assertSucceeds(getDoc(doc(client("cashier", "finance"),
          "orders", id)));
      await assertSucceeds(getDoc(doc(client("cashier", "finance"),
          "courierSettlements", receipt.settlementId)));
    });

test("multi-order settlement replay preserves one receipt",
    async () => {
      const ids = [await completed(), await completed()];
      const requestId = randomUUID();
      const result = await settle(ids, {requestId});
      const receipt = (await db.doc(`courierSettlements/${result.settlementId}`)
          .get()).data();
      assert.equal(receipt.total, 20);
      assert.equal(receipt.orderCount, 2);
      assert.equal((await settle(ids.slice().reverse(), {requestId}))
          .replayed, true);
      await assert.rejects(settle([ids[0]], {requestId}),
          (error) => error.code === "already-exists");
      for (const id of ids) {
        assert.equal((await db.doc(`orders/${id}`).get()).data()
            .courierSettlementId, result.settlementId);
      }
    });

test("overlapping concurrent cashiers cannot pay the same delivery twice",
    async () => {
      const ids = [await completed(), await completed()];
      const result = await Promise.allSettled([
        settle(ids), settle([ids[0]], {}, "superadmin")]);
      assert.equal(result.filter((row) => row.status === "fulfilled")
          .length, 1);
      assert.equal(result.filter((row) => row.status === "rejected")
          .length, 1);
    });

for (const patch of [{courierPaid: true},
  {financialValidationStatus: "pending"},
  {deliveryFee: 99}, {status: "Saiu para Entrega"}, {courierUid: ""},
  {courierUid: "other-rider"}, {stockReservationStatus: "released"},
  {stockProcessingStatus: "requires_review"}]) {
  test(`invalid member rolls back entire settlement ${JSON.stringify(patch)}`,
      async () => {
        const ids = [await completed(), await completed()];
        await db.doc(`orders/${ids[1]}`).update(patch);
        await assert.rejects(settle(ids),
            (error) => error.code === "failed-precondition");
        assert.equal((await db.doc(`orders/${ids[0]}`).get()).data()
            .courierPaid, false);
      });
}
for (const patch of [{courierUid: ""}, {financialValidationStatus: "pending"},
  {status: "Em Separação"}, {stockReservationStatus: "released"},
  {status: "Concluído", completedAt: null},
  {stockProcessingStatus: "processed"}]) {
  test(`completion fails closed ${JSON.stringify(patch)}`, async () => {
    const id = await createOrder();
    await act(id, "separate");
    await assign(id);
    await dispatch(id);
    const ref = db.doc(`orders/${id}`);
    await ref.update(patch);
    const before = await ref.get();
    await assert.rejects(act(id, "complete"),
        (error) => error.code === "failed-precondition");
    assert.ok((await ref.get()).updateTime.isEqual(before.updateTime));
  });
}
test("inconsistent reserved inventory rolls back completion and projection",
    async () => {
      const id = await createOrder();
      await act(id, "separate");
      await assign(id);
      await dispatch(id);
      const order = (await db.doc(`orders/${id}`).get()).data();
      await db.doc(`products/${order.itemsList[0].id}`).update({
        reservedStock: 0});
      await assert.rejects(act(id, "complete"),
          (error) => error.code === "failed-precondition");
      assert.equal((await db.doc(`orders/${id}`).get()).data().status,
          "Saiu para Entrega");
      assert.equal((await db.doc(`courierDeliveries/${id}`).get())
          .data().status,
      "Saiu para Entrega");
    });
test("suspension immediately revokes reads before trigger",
    async () => {
      const id = await createOrder();
      await assign(id);
      const rider = client("pilot-rider");
      await assertSucceeds(getDoc(doc(rider, "courierDeliveries", id)));
      for (const flag of ["enabled", "isActive", "active"]) {
        await db.doc("couriers/pilot-rider").update({[flag]: false});
        await assertFails(getDoc(doc(rider, "courierDeliveries", id)));
        await db.doc("couriers/pilot-rider").update({[flag]: true});
      }
      await db.doc("couriers/pilot-rider").update({
        administrativeState: "blocked"});
      await assertFails(getDoc(doc(rider, "courierDeliveries", id)));
      await db.doc("couriers/pilot-rider").update({
        administrativeState: "active"});
    });
for (const role of ["operations_admin", "superadmin", "finance"]) {
  test(`${role} critical SDK writes are denied`,
      async () => {
        const id = await createOrder();
        const sdk = client(`direct-${role}`, role);
        const ref = doc(sdk, "orders", id);
        for (const status of ["Em Separação", "Saiu para Entrega",
          "Concluído"]) {
          await assertFails(updateDoc(ref, {status,
            completedAt: serverTimestamp()}));
        }
        for (const fields of [{courierUid: "pilot-rider"},
          {courierName: "Fake"}, {courierAssignedAt: serverTimestamp()},
          {courierPaid: true}, {paymentStatus: "Pago"}]) {
          await assertFails(updateDoc(ref, fields));
        }
        await assertFails(setDoc(doc(sdk, "courierSettlements", randomUUID()),
            {status: "paid", total: 0}));
      });
}
test("legacy without financial approval remains readable but cannot operate",
    async () => {
      const id = await createOrder();
      await db.doc(`orders/${id}`).update({
        financialValidationStatus: "legacy"});
      await assertSucceeds(getDoc(doc(client("operator", "operations_admin"),
          "orders", id)));
      await assert.rejects(act(id, "separate"),
          (error) => error.code === "failed-precondition");
    });
test("legacy manual PIX is IAM-private, automatic PIX remains registered",
    () => {
      assert.ok([].concat(backend.endpoints.chamaeCriarPix
          .__endpoint.httpsTrigger.invoker).includes("private"));
      assert.equal(typeof
      backend.functions.chamaeCriarPixAutomatico, "function");
    });
test("processed PIX completion never debits inventory again", async () => {
  const id = await createOrder();
  await act(id, "separate");
  await assign(id);
  await dispatch(id);
  const ref = db.doc(`orders/${id}`);
  await ref.update({paymentMethod: "PIX", paymentStatus: "Pago",
    stockProcessingStatus: "processed", stockReservationStatus: "finalized"});
  const order = (await ref.get()).data();
  const product = db.doc(`products/${order.itemsList[0].id}`);
  const oldTime = (await product.get()).updateTime;
  await act(id, "complete");
  assert.ok((await product.get()).updateTime.isEqual(oldTime));
});

for (const operation of ["separate", "assign", "dispatch", "complete",
  "settle", "replace", "unassign"]) {
  for (const withOfficial of [true, false]) {
    test(`legacy missing validation: ${operation}, official=${withOfficial}`,
        async () => {
          const id = await createOrder();
          if (["dispatch", "complete", "settle", "replace", "unassign"]
              .includes(operation)) {
            await act(id, "separate");
            await assign(id);
          }
          if (["complete", "settle"].includes(operation)) await dispatch(id);
          if (operation === "settle") await act(id, "complete");
          const ref = db.doc(`orders/${id}`);
          await ref.update({financialValidationStatus: FieldValue.delete()});
          if (!withOfficial) await db.doc(`orderFinancials/${id}`).delete();
          const beforeOrder = await ref.get();
          const product = db.doc(`products/${beforeOrder.data()
              .itemsList[0].id}`);
          const beforeProduct = await product.get();
          const projection = db.doc(`courierDeliveries/${id}`);
          const beforeProjection = await projection.get();
          const collections = ["orderOperationRequests",
            "courierAssignmentRequests", "courierDeliveryAudit",
            "courierSettlements"];
          const counts = await Promise.all(collections.map(async (name) =>
            (await db.collection(name).get()).size));
          await assertSucceeds(getDoc(doc(client("cashier", "finance"),
              "orders", id)));
          const action = () => {
            if (operation === "assign") return assign(id);
            if (operation === "replace") return assign(id, "other-rider");
            if (operation === "unassign") return assign(id, "");
            if (operation === "dispatch") return dispatch(id);
            if (operation === "settle") return settle([id]);
            return act(id, operation);
          };
          await assert.rejects(action(),
              (error) => error.code === "failed-precondition");
          assert.ok((await ref.get()).updateTime
              .isEqual(beforeOrder.updateTime));
          assert.ok((await product.get()).updateTime
              .isEqual(beforeProduct.updateTime));
          const afterProjection = await projection.get();
          assert.equal(afterProjection.exists, beforeProjection.exists);
          if (beforeProjection.exists) {
            assert.ok(afterProjection.updateTime
                .isEqual(beforeProjection.updateTime));
          }
          assert.deepEqual(await Promise.all(collections.map(async (name) =>
            (await db.collection(name).get()).size)), counts);
        });
  }
}

test("assignment requires official finance even with validated flag",
    async () => {
      for (const mode of ["missing", "mismatch"]) {
        const id = await createOrder();
        const financial = db.doc(`orderFinancials/${id}`);
        if (mode === "missing") await financial.delete();
        else await financial.update({totalBRL: 0.01});
        const beforeOrder = await db.doc(`orders/${id}`).get();
        await assert.rejects(assign(id),
            (error) => error.code === "failed-precondition");
        assert.ok((await db.doc(`orders/${id}`).get()).updateTime
            .isEqual(beforeOrder.updateTime));
        assert.equal((await db.doc(`courierDeliveries/${id}`).get())
            .exists, false);
      }
    });

test("mixed modern and legacy settlement rejects the whole batch",
    async () => {
      const modern = await completed();
      const legacy = await completed();
      await db.doc(`orders/${legacy}`).update({
        financialValidationStatus: FieldValue.delete()});
      const refs = [modern, legacy].map((id) => db.doc(`orders/${id}`));
      const snapshots = await Promise.all(refs.map((ref) => ref.get()));
      const receipts = (await db.collection("courierSettlements").get()).size;
      await assert.rejects(settle([modern, legacy]),
          (error) => error.code === "failed-precondition");
      for (let i = 0; i < refs.length; i++) {
        assert.ok((await refs[i].get()).updateTime
            .isEqual(snapshots[i].updateTime));
        assert.equal((await refs[i].get()).data().courierPaid, false);
      }
      assert.equal((await db.collection("courierSettlements").get()).size,
          receipts);
    });
