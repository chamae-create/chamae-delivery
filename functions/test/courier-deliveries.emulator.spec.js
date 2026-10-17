const assert = require("node:assert/strict");
const fs = require("node:fs");
const path = require("node:path");
const {before, after, test} = require("node:test");
const {initializeApp, deleteApp} = require("firebase-admin/app");
const {getFirestore, GeoPoint} = require("firebase-admin/firestore");
const {initializeTestEnvironment, assertFails, assertSucceeds} =
    require("@firebase/rules-unit-testing");
const {getDoc, doc} = require("firebase/firestore");
const {syncCourierDelivery, createCourierDeliveryTrigger} =
    require("../courier-deliveries");

let app;
let db;
let environment;
let sequence = 0;
before(async () => {
  const host = process.env.FIRESTORE_EMULATOR_HOST;
  assert.ok(host, "Run only with the local Firestore emulator");
  const address = new URL(`http://${host}`);
  assert.ok(["localhost", "127.0.0.1", "[::1]"].includes(address.hostname));
  environment = await initializeTestEnvironment({
    projectId: "demo-chamae-rules",
    firestore: {
      host: address.hostname, port: Number(address.port),
      rules: fs.readFileSync(path.join(__dirname, "../../firestore.rules"),
          "utf8"),
    },
  });
  await environment.clearFirestore();
  app = initializeApp({projectId: "demo-chamae-rules"}, "courier-test");
  db = getFirestore(app);
  await db.doc("couriers/rider-a").set({
    name: "Entregador A", administrativeState: "active",
  });
  await db.doc("couriers/rider-b").set({
    name: "Entregador B", administrativeState: "active",
  });
});
after(async () => {
  if (environment) await environment.cleanup();
  if (db) await db.terminate();
  if (app) await deleteApp(app);
});

const seed = async (overrides = {}) => {
  const id = `projection-${++sequence}`;
  const ref = db.doc(`orders/${id}`);
  await ref.set({
    id: "#CH-FRIENDLY", courierUid: "rider-a", courierName: "Display only",
    customerUid: "buyer", customerName: "Maria da Silva",
    customerPhone: "67999990000", WhatsApp: "67999990000",
    email: "private@example.com", totalBRL: 70.60,
    deliveryFee: 10, customerFee: 0.60, merchantFee: 1.80,
    mercadoPagoOrderId: "PRIVATE_MP_ID", mercadoPagoPaymentId: "PRIVATE_PAY_ID",
    paymentMethod: "PIX", history: ["PRIVATE_HISTORY"],
    status: "Em Separação", address: "Rua das Flores, 123",
    deliveryLocation: new GeoPoint(-22.5, -55.7),
    deliveryAddress: {
      addressText: "Rua das Flores, 123", complement: "Casa 2",
      reference: "Portão azul", latitude: -22.5, longitude: -55.7,
      customerPhone: "67999990000", internalFinancialData: "PRIVATE_FINANCE",
    },
    ...overrides,
  });
  const delivery = db.doc(`courierDeliveries/${id}`);
  const read = async () => (await delivery.get()).data();
  const audit = async () => (await db.collection("courierDeliveryAudit")
      .where("orderId", "==", id).get()).docs.map((d) => d.data());
  return {id, ref, delivery, read, audit,
    sync: () => syncCourierDelivery(db, id)};
};

const riderDb = (uid) => environment.authenticatedContext(uid).firestore();

test("no UID or unregistered UID creates no delivery or audit", async () => {
  for (const uid of [null, "", "not-provisioned"]) {
    const f = await seed({courierUid: uid, courierName: "Entregador A"});
    await f.sync();
    assert.equal((await f.delivery.get()).exists, false);
    assert.equal((await f.audit()).length, 0);
  }
});

test("registered courier receives only sanitized fields; source untouched",
    async () => {
      const f = await seed();
      const beforeOrder = await f.ref.get();
      const beforeCourier = await db.doc("couriers/rider-a").get();
      await f.sync();
      const data = await f.read();
      assert.deepEqual(Object.keys(data).sort(), [
        "orderId", "courierUid", "customerName", "address", "deliveryLocation",
        "complement", "reference", "status", "createdAt", "assignedAt",
        "updatedAt",
      ].sort());
      assert.equal(data.orderId, f.id);
      assert.equal(data.customerName, "Maria da Silva");
      assert.equal(data.address, "Rua das Flores, 123");
      assert.equal(data.courierUid, "rider-a");
      assert.equal(JSON.stringify(data).includes("PRIVATE_"), false);
      assert.ok((await f.ref.get()).updateTime.isEqual(beforeOrder.updateTime));
      assert.ok((await db.doc("couriers/rider-a").get()).updateTime.isEqual(
          beforeCourier.updateTime));
      await assertSucceeds(getDoc(doc(riderDb("rider-a"),
          "courierDeliveries", f.id)));
      await assertFails(getDoc(doc(riderDb("rider-b"),
          "courierDeliveries", f.id)));
      const audits = await db.collection("courierDeliveryAudit")
          .where("orderId", "==", f.id).get();
      assert.equal(audits.size, 1);
      const audit = audits.docs[0];
      assert.deepEqual(Object.keys(audit.data()).sort(), [
        "orderId", "previousCourierUid", "courierUid", "previousStatus",
        "status", "reason", "changedAt",
      ].sort());
      await assertFails(getDoc(doc(riderDb("rider-a"), audit.ref.path)));
    });

test("duplicates and financial-only writes leave projection unchanged",
    async () => {
      const f = await seed();
      await f.sync();
      const previous = await f.delivery.get();
      await f.ref.update({totalBRL: 100, mercadoPagoOrderId: "NEW_PRIVATE_MP"});
      await f.sync();
      await f.sync();
      const next = await f.delivery.get();
      assert.ok(next.updateTime.isEqual(previous.updateTime));
      assert.deepEqual(await f.read(), previous.data());
      assert.equal((await f.audit()).length, 1);
    });

test("operational delivery lifecycle stays consistent", async () => {
  const f = await seed({status: "Novo"});
  for (const status of ["Novo", "Em Separação", "Saiu para Entrega",
    "Concluído"]) {
    await f.ref.update({status});
    await f.sync();
    assert.equal((await f.read()).status, status);
  }
  const completed = await f.read();
  assert.ok(completed.pickedUpAt);
  assert.ok(completed.completedAt);
  await f.sync();
  assert.deepEqual(await f.read(), completed);
  await f.ref.update({status: "Cancelado: motivo privado"});
  await f.sync();
  assert.equal((await f.read()).status, "Cancelado");
  assert.equal((await f.read()).courierUid, "rider-a");
  assert.equal((await f.audit()).length, 5);
});

test("reassignment replaces binding; old courier can no longer get document",
    async () => {
      const f = await seed();
      await f.sync();
      const first = await f.read();
      await f.ref.update({courierUid: "rider-b"});
      await f.sync();
      const next = await f.read();
      assert.equal(next.courierUid, "rider-b");
      assert.ok(next.createdAt.isEqual(first.createdAt));
      await assertFails(getDoc(doc(riderDb("rider-a"),
          "courierDeliveries", f.id)));
      await assertSucceeds(getDoc(doc(riderDb("rider-b"),
          "courierDeliveries", f.id)));
      const audit = (await f.audit()).find((entry) =>
        entry.previousCourierUid === "rider-a");
      assert.equal(audit.courierUid, "rider-b");
    });

test("unassignment revokes access, removes PII, retains operational audit",
    async () => {
      const f = await seed({status: "Concluído"});
      await f.sync();
      const previous = await f.read();
      await f.ref.update({courierUid: ""});
      await f.sync();
      const tombstone = await f.read();
      assert.equal(tombstone.courierUid, "");
      assert.equal(tombstone.status, "Concluído");
      assert.ok(tombstone.completedAt.isEqual(previous.completedAt));
      for (const key of ["customerName", "address", "deliveryLocation",
        "complement", "reference"]) {
        assert.equal(Object.hasOwn(tombstone, key), false);
      }
      await assertFails(getDoc(doc(riderDb("rider-a"),
          "courierDeliveries", f.id)));
      assert.equal((await f.audit()).length, 2);
      await f.sync();
      assert.equal((await f.audit()).length, 2);
    });

test("invalid replacement or contaminated route revokes previous access",
    async () => {
      for (const overrides of [{courierUid: "not-provisioned"},
        {address: "WhatsApp 67999990000", deliveryAddress: {}},
        {status: "Revisão financeira"}]) {
        const f = await seed();
        await f.sync();
        await f.ref.update(overrides);
        await f.sync();
        assert.equal((await f.read()).courierUid, "");
        assert.equal(Object.hasOwn(await f.read(), "customerName"), false);
        await assertFails(getDoc(doc(riderDb("rider-a"),
            "courierDeliveries", f.id)));
      }
    });

test("delayed events reread latest order; deletion never resurrects data",
    async () => {
      const f = await seed();
      const trigger = createCourierDeliveryTrigger(db);
      const staleEvent = {params: {orderId: f.id}, data: {
        after: {exists: true, data: () => ({
          courierUid: "rider-a", status: "Novo",
        })},
      }};
      await f.ref.update({courierUid: "rider-b", status: "Concluído"});
      await trigger.run(staleEvent);
      const completed = await f.read();
      assert.equal(completed.courierUid, "rider-b");
      assert.equal(completed.status, "Concluído");
      await trigger.run(staleEvent);
      assert.deepEqual(await f.read(), completed);
      await f.ref.delete();
      await trigger.run(staleEvent);
      assert.equal((await f.read()).courierUid, "");
      assert.equal(Object.hasOwn(await f.read(), "address"), false);
      await trigger.run(staleEvent);
      assert.equal((await f.audit()).length, 2);
    });

test("full replacement cleans legacy secret fields on unchanged status",
    async () => {
      const f = await seed();
      await f.sync();
      await f.delivery.update({
        customerPhone: "PRIVATE_PHONE",
        deliveryAddress: {email: "PRIVATE_EMAIL"},
        mercadoPagoOrderId: "PRIVATE",
      });
      await f.sync();
      const data = await f.read();
      assert.equal(Object.hasOwn(data, "customerPhone"), false);
      assert.equal(Object.hasOwn(data, "deliveryAddress"), false);
      assert.equal(Object.hasOwn(data, "mercadoPagoOrderId"), false);
      await assertSucceeds(getDoc(doc(riderDb("rider-a"),
          "courierDeliveries", f.id)));
    });

test("concurrent duplicate executions produce exactly one projection revision",
    async () => {
      const f = await seed();
      await Promise.all(Array.from({length: 6}, () => f.sync()));
      assert.equal((await f.read()).courierUid, "rider-a");
      assert.equal((await f.audit()).length, 1);
    });

test("transaction retry after concurrent reassignment reads the new UID",
    async () => {
      const f = await seed();
      let attempts = 0;
      const retry = new Error("FORCED_TEST_RETRY");
      const racingDb = {
        collection: (name) => db.collection(name),
        runTransaction: async (callback) => {
          // Aborta uma transação real antes do commit. A alteração concorrente
          // ocorre depois da liberação dos locks, antes da nova tentativa.
          await assert.rejects(db.runTransaction(async (transaction) => {
            attempts++;
            await callback(transaction);
            throw retry;
          }, {maxAttempts: 1}), (error) => error === retry);
          await f.ref.update({courierUid: "rider-b"});
          return db.runTransaction((transaction) => {
            attempts++;
            return callback(transaction);
          });
        },
      };
      await syncCourierDelivery(racingDb, f.id);
      assert.ok(attempts > 1);
      assert.equal((await f.read()).courierUid, "rider-b");
      assert.equal((await f.audit()).length, 1);
    });
