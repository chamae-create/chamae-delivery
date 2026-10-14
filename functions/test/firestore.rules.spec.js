const assert = require("node:assert/strict");
const fs = require("node:fs");
const path = require("node:path");
const {before, after, test} = require("node:test");
const {
  initializeTestEnvironment, assertFails, assertSucceeds,
} = require("@firebase/rules-unit-testing");
const {
  collection, doc, getDoc, getDocs, setDoc, updateDoc, deleteDoc,
  deleteField, writeBatch,
} = require("firebase/firestore");

let environment;
const product = {
  name: "Produto", price: 20, priceBRL: 20,
  stock: 10, reservedStock: 0, salesCount: 0, isActive: true,
};
const financial = {
  items: [{id: "p1", quantity: 3, price: 20}],
  totalBRL: 70.60, totalCentavos: 7060, version: 1,
};

before(async () => {
  const emulatorHost = process.env.FIRESTORE_EMULATOR_HOST;
  assert.ok(emulatorHost,
      "Run via firebase emulators:exec --only firestore --project " +
      "demo-chamae-rules. Tests never connect to production.");
  const address = new URL(`http://${emulatorHost}`);
  assert.ok(["localhost", "127.0.0.1", "[::1]"].includes(address.hostname),
      "A local Firestore emulator is required.");
  environment = await initializeTestEnvironment({
    projectId: "demo-chamae-rules",
    firestore: {
      host: address.hostname, port: Number(address.port),
      rules: fs.readFileSync(
          path.join(__dirname, "../../firestore.rules"), "utf8",
      ),
    },
  });
  await environment.clearFirestore();
  await environment.withSecurityRulesDisabled(async (context) => {
    const db = context.firestore();
    await setDoc(doc(db, "products/p1"), product);
    await setDoc(doc(db, "orderFinancials/existing"), financial);
    await setDoc(doc(db, "orders/existing"), {
      id: "order-existing", status: "Novo",
    });
  });
});

after(async () => {
  if (environment) await environment.cleanup();
});

const clients = {
  unauthenticated: () => environment.unauthenticatedContext().firestore(),
  authenticated: () => environment.authenticatedContext("customer").firestore(),
  claimedAdmin: () => environment.authenticatedContext("customer", {
    admin: true,
  }).firestore(),
};

for (const [name, database] of Object.entries(clients)) {
  test(`${name}: cannot pre-create finance before the order`, async () => {
    const db = database();
    await assertFails(setDoc(doc(db, `orderFinancials/precreated-${name}`), {
      ...financial, totalBRL: 0.01, totalCentavos: 1,
    }));
  });

  test(`${name}: cannot alter frozen finance`, async () => {
    await assertFails(updateDoc(doc(database(), "orderFinancials/existing"), {
      totalBRL: 0.01, totalCentavos: 1,
    }));
  });

  test(`${name}: cannot replace or delete frozen finance`, async () => {
    const ref = doc(database(), "orderFinancials/existing");
    await assertFails(setDoc(ref, {totalBRL: 0.01}));
    await assertFails(deleteDoc(ref));
  });

  test(`${name}: cannot read or list private finance`, async () => {
    const db = database();
    await assertFails(getDoc(doc(db, "orderFinancials/existing")));
    await assertFails(getDocs(collection(db, "orderFinancials")));
  });

  test(`${name}: cannot bypass finance protection with a subcollection`,
      async () => {
        const ref = doc(database(), "orderFinancials/existing/details/fake");
        await assertFails(setDoc(ref, {totalBRL: 0.01}));
        await assertFails(getDoc(ref));
      });

  test(`${name}: cannot bypass finance protection in an atomic batch`,
      async () => {
        const db = database();
        const batch = writeBatch(db);
        batch.set(doc(db, `orders/batch-${name}`), {status: "Novo"});
        batch.set(doc(db, `orderFinancials/batch-${name}`), financial);
        await assertFails(batch.commit());
      });

  for (const field of ["price", "priceBRL", "stock", "reservedStock",
    "salesCount"]) {
    test(`${name}: cannot tamper with official product ${field}`, async () => {
      await assertFails(updateDoc(doc(database(), "products/p1"), {
        [field]: 0.01,
      }));
    });
  }

  test(`${name}: cannot remove priceBRL to force price fallback`, async () => {
    await assertFails(updateDoc(doc(database(), "products/p1"), {
      priceBRL: deleteField(), price: 0.01,
    }));
  });

  test(`${name}: cannot fabricate, replace or delete an official product`,
      async () => {
        const db = database();
        await assertFails(setDoc(doc(db, `products/fake-${name}`), product));
        await assertFails(setDoc(doc(db, "products/p1"), {price: 0.01}));
        await assertFails(deleteDoc(doc(db, "products/p1")));
      });

  test(`${name}: cannot write a product subcollection via the broad rule`,
      async () => {
        await assertFails(setDoc(doc(database(), "products/p1/prices/fake"), {
          priceBRL: 0.01,
        }));
      });

  test(`${name}: can read and list the catalog exactly as the app does`,
      async () => {
        const db = database();
        const item = await assertSucceeds(getDoc(doc(db, "products/p1")));
        const catalog = await assertSucceeds(
            getDocs(collection(db, "products")),
        );
        assert.equal(item.data().priceBRL, 20);
        assert.equal(catalog.size, 1);
      });
}

test("backend setup can create and update official financial sources",
    async () => {
      await environment.withSecurityRulesDisabled(async (context) => {
        const db = context.firestore();
        await assertSucceeds(setDoc(doc(db, "orderFinancials/backend"),
            financial));
        await assertSucceeds(updateDoc(doc(db, "products/p1"), {priceBRL: 20}));
        await assertSucceeds(deleteDoc(doc(db, "orderFinancials/backend")));
      });
    });

test("other paths preserve the published temporary access condition",
    async () => {
      const db = clients.unauthenticated();
      const originalExpiry = Date.UTC(2026, 10, 2);
      const expected = Date.now() < originalExpiry ?
        assertSucceeds : assertFails;
      await expected(setDoc(doc(db, "orders/compatibility"), {status: "Novo"}));
      await expected(getDocs(collection(db, "orders")));
      await expected(updateDoc(doc(db, "orders/existing"), {
        status: "Em Separação",
      }));
    });
