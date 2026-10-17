const assert = require("node:assert/strict");
const fs = require("node:fs");
const path = require("node:path");
const {randomUUID} = require("node:crypto");
const {before, after, test} = require("node:test");
const {initializeApp, deleteApp} = require("firebase-admin/app");
const {getFirestore, GeoPoint, Timestamp} = require("firebase-admin/firestore");
const {initializeTestEnvironment, assertFails, assertSucceeds} =
    require("@firebase/rules-unit-testing");
const {getDoc, doc} = require("firebase/firestore");
const {changeCourier, listCouriers} = require("../courier-assignment");
const {syncCourierDelivery} = require("../courier-deliveries");

let app;
let db;
let environment;
let sequence = 0;
const auth = (role = "operations_admin") => ({
  uid: "operator", token: {roles: [role]},
});
before(async () => {
  const host = process.env.FIRESTORE_EMULATOR_HOST;
  assert.ok(host, "Local emulator required; no production fallback");
  const address = new URL(`http://${host}`);
  assert.ok(["localhost", "127.0.0.1", "[::1]"].includes(address.hostname));
  environment = await initializeTestEnvironment({
    projectId: "demo-chamae-rules", firestore: {
      host: address.hostname, port: Number(address.port),
      rules: fs.readFileSync(path.join(__dirname, "../../firestore.rules"),
          "utf8"),
    },
  });
  await environment.clearFirestore();
  app = initializeApp({projectId: "demo-chamae-rules"}, "assignment-test");
  db = getFirestore(app);
  for (const uid of ["rider-a", "rider-b"]) {
    await db.doc(`couriers/${uid}`).set({name: `Oficial ${uid}`,
      administrativeState: "active", phone: "PRIVATE_DRIVER_PHONE"});
  }
  for (const state of ["suspended", "blocked", "missing"]) {
    await db.doc(`couriers/${state}`).set({name: "Inativo",
      ...(state === "missing" ? {} : {administrativeState: state})});
  }
});
after(async () => {
  if (environment) await environment.cleanup();
  if (db) await db.terminate();
  if (app) await deleteApp(app);
});
const seed = async (overrides = {}) => {
  const id = `assignment-${++sequence}`;
  const ref = db.doc(`orders/${id}`);
  await ref.set({
    id: "#CH-FRIENDLY", courierUid: "", courierName: "NOME LEGADO",
    customerUid: "buyer", customerName: "Maria", customerPhone: "PRIVATE_PHONE",
    WhatsApp: "PRIVATE_WHATSAPP", email: "PRIVATE_EMAIL", history: ["PRIVATE"],
    status: "Em Separação", financialValidationStatus: "validated",
    paymentMethod: "PIX", paymentStatus: "Pago",
    stockProcessingStatus: "processed",
    totalBRL: 70.60, deliveryFee: 10, customerFee: 0.60, merchantFee: 1.80,
    itemsTotal: 60, merchantNet: 58.20, platformFee: 2.40,
    mercadoPagoOrderId: "PRIVATE_MP_ID", courierPaid: false,
    address: "Rua das Flores, 123",
    deliveryLocation: new GeoPoint(-22.5, -55.7),
    ...overrides,
  });
  await db.doc(`orderFinancials/${id}`).set({
    totalBRL: 70.60, deliveryFee: 10, customerFee: 0.60, merchantFee: 1.80,
    itemsTotal: 60, merchantNet: 58.20, platformFee: 2.40,
  });
  const delivery = db.doc(`courierDeliveries/${id}`);
  const call = (uid, extra = {}, role) => changeCourier(db, {
    auth: auth(role), data: {orderId: id, courierUid: uid,
      requestId: randomUUID(), ...extra},
  });
  const dispatch = (extra = {}) => changeCourier(db, {
    auth: auth(), data: {orderId: id, requestId: randomUUID(), ...extra},
  }, "dispatch");
  return {id, ref, delivery, call, dispatch,
    read: async () => (await ref.get()).data(),
    projection: async () => (await delivery.get()).data()};
};
const rider = (uid) => environment.authenticatedContext(uid).firestore();
const owns = (uid, id) => getDoc(doc(rider(uid), "courierDeliveries", id));
const forbidden = ["customerPhone", "WhatsApp", "email", "customerUid",
  "history", "totalBRL", "customerFee", "deliveryFee", "mercadoPagoOrderId"];

for (const role of ["operations_admin", "superadmin"]) {
  test(`${role}: official name and sanitized projection`,
      async () => {
        const f = await seed();
        const beforeOrder = await f.read();
        await f.call("rider-a", {}, role);
        const order = await f.read();
        assert.equal(order.courierUid, "rider-a");
        assert.equal(order.courierName, "Oficial rider-a");
        assert.ok(order.courierAssignedAt instanceof Timestamp);
        const projection = await f.projection();
        assert.equal(projection.courierUid, "rider-a");
        assert.equal(projection.customerName, "Maria");
        for (const field of forbidden) {
          assert.equal(Object.hasOwn(projection, field), false, field);
        }
        assert.equal(JSON.stringify(projection).includes("PRIVATE"), false);
        for (const field of ["paymentMethod", "paymentStatus", "totalBRL",
          "deliveryFee", "customerFee", "merchantFee", "mercadoPagoOrderId",
          "stockProcessingStatus"]) {
          assert.deepEqual(order[field], beforeOrder[field], field);
        }
        await assertSucceeds(owns("rider-a", f.id));
      });
}

for (const uid of ["not-found", "suspended", "blocked", "missing"]) {
  test(`reject non-existent or unenabled courier ${uid} without partial writes`,
      async () => {
        const f = await seed();
        const beforeOrder = await f.ref.get();
        await assert.rejects(f.call(uid), (error) =>
          ["not-found", "failed-precondition"].includes(error.code));
        assert.ok((await f.ref.get()).updateTime
            .isEqual(beforeOrder.updateTime));
        assert.equal((await f.delivery.get()).exists, false);
      });
}

test("caller cannot send a courier name or arbitrary fields", async () => {
  const f = await seed();
  await assert.rejects(f.call("rider-a", {courierName: "FORGED"}),
      (error) => error.code === "invalid-argument");
  assert.equal((await f.read()).courierName, "NOME LEGADO");
});

test("missing order is rejected", async () => {
  const f = await seed();
  await f.ref.delete();
  await assert.rejects(f.call("rider-a"),
      (error) => error.code === "not-found");
});

test("exchange and removal revoke the old reader before any trigger runs",
    async () => {
      const f = await seed();
      await f.call("rider-a");
      await f.call("rider-b", {expectedCourierUid: "rider-a"});
      assert.equal((await f.read()).courierUid, "rider-b");
      await assertFails(owns("rider-a", f.id));
      await assertSucceeds(owns("rider-b", f.id));
      await f.call("", {expectedCourierUid: "rider-b"});
      const unassigned = await f.read();
      assert.equal(unassigned.courierUid, "");
      assert.equal(unassigned.courierName, "");
      assert.ok(unassigned.courierUnassignedAt instanceof Timestamp);
      await assertFails(owns("rider-b", f.id));
      assert.equal(Object.hasOwn(await f.projection(), "address"), false);
      await syncCourierDelivery(db, f.id);
      await assertFails(owns("rider-b", f.id));
    });

test("duplicate request after another assignment never restores old courier",
    async () => {
      const f = await seed();
      const requestId = randomUUID();
      await f.call("rider-a", {requestId});
      await f.call("rider-b");
      const beforeOrder = await f.ref.get();
      const projection = await f.delivery.get();
      const result = await f.call("rider-a", {requestId});
      assert.equal(result.replayed, true);
      assert.ok((await f.ref.get()).updateTime
          .isEqual(beforeOrder.updateTime));
      assert.ok((await f.delivery.get()).updateTime
          .isEqual(projection.updateTime));
      assert.equal((await f.read()).courierUid, "rider-b");
    });

test("reused request with different data and stale modal are rejected",
    async () => {
      const f = await seed();
      const requestId = randomUUID();
      await f.call("rider-a", {requestId});
      await assert.rejects(f.call("rider-b", {requestId}),
          (error) => error.code === "already-exists");
      await assert.rejects(f.call("rider-b", {expectedCourierUid: ""}),
          (error) => error.code === "aborted");
      assert.equal((await f.read()).courierUid, "rider-a");
    });

test("same binding with new requests does not renew assignment timestamps",
    async () => {
      const f = await seed();
      await f.call("rider-a");
      const beforeOrder = await f.ref.get();
      await f.call("rider-a");
      assert.ok((await f.ref.get()).updateTime
          .isEqual(beforeOrder.updateTime));
    });

test("unusable sanitized route rolls back both binding and projection",
    async () => {
      const f = await seed({address: "WhatsApp 67999990000"});
      await assert.rejects(f.call("rider-a"),
          (error) => error.code === "failed-precondition");
      assert.equal((await f.read()).courierUid, "");
      assert.equal((await f.delivery.get()).exists, false);
    });

for (const status of ["Saiu para Entrega", "Concluído", "Cancelado"]) {
  test(`historical or in-flight assignment is locked: ${status}`, async () => {
    const f = await seed({status, courierUid: "rider-a"});
    for (const uid of ["rider-b", ""]) {
      await assert.rejects(f.call(uid),
          (error) => error.code === "failed-precondition");
    }
  });
}

test("dispatch requires current active courier and operational readiness",
    async () => {
      const f = await seed();
      await assert.rejects(f.dispatch(),
          (error) => error.code === "failed-precondition");
      assert.equal((await f.read()).status, "Em Separação");
      await f.call("rider-a");
      await f.ref.update({paymentStatus: "Pendente"});
      await assert.rejects(f.dispatch(),
          (error) => error.code === "failed-precondition");
      await f.ref.update({paymentStatus: "Pago"});
      await f.dispatch();
      assert.equal((await f.read()).status, "Saiu para Entrega");
      assert.equal((await f.projection()).status, "Saiu para Entrega");
      assert.ok((await f.projection()).pickedUpAt instanceof Timestamp);
    });

test("deactivated courier cannot dispatch or be revived by synchronization",
    async () => {
      const f = await seed();
      await f.call("rider-a");
      await db.doc("couriers/rider-a").update({administrativeState: "blocked"});
      await assert.rejects(f.dispatch(),
          (error) => error.code === "failed-precondition");
      await syncCourierDelivery(db, f.id);
      await assertFails(owns("rider-a", f.id));
      await db.doc("couriers/rider-a").update({administrativeState: "active"});
    });

test("operator listing stays sanitized; operations can read couriers",
    async () => {
      const result = await listCouriers(db, {auth: auth(), data: {}});
      assert.ok(result.couriers.length > 0);
      for (const item of result.couriers) {
        assert.deepEqual(Object.keys(item).sort(), ["name", "uid"]);
        assert.ok(!["suspended", "blocked", "missing"].includes(item.uid));
      }
      const operator = environment.authenticatedContext("operator", {
        roles: ["operations_admin"],
      }).firestore();
      await assertSucceeds(getDoc(doc(operator, "couriers/rider-a")));
    });

test("active courier listing is paginated without losing eligible records",
    async () => {
      for (let i = 0; i < 54; i++) {
        await db.doc(`couriers/page-${String(i).padStart(3, "0")}`).set({
          name: "Oficial", administrativeState: "active",
        });
      }
      const first = await listCouriers(db, {auth: auth(), data: {}});
      assert.equal(first.couriers.length, 50);
      assert.ok(first.nextCursor);
      const second = await listCouriers(db, {auth: auth(),
        data: {cursor: first.nextCursor}});
      const ids = [...first.couriers, ...second.couriers].map((c) => c.uid);
      assert.equal(new Set(ids).size, 56);
      assert.equal(second.nextCursor, null);
    });
