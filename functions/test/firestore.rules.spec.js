const assert = require("node:assert/strict");
const fs = require("node:fs");
const path = require("node:path");
const {before, after, test} = require("node:test");
const {customerPolicyFixture, customerProfileFixture} =
    require("./customer-policy-fixture");
const {
  initializeTestEnvironment, assertFails, assertSucceeds,
} = require("@firebase/rules-unit-testing");
const {
  collection, doc, getDoc, getDocs, setDoc, updateDoc, deleteDoc,
  deleteField, writeBatch, query, where, serverTimestamp, Timestamp, GeoPoint,
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
    const policy = customerPolicyFixture();
    await setDoc(doc(db, "customerPolicies/current"), policy);
    await setDoc(doc(db, "customerProfiles/customer"),
        customerProfileFixture(policy, Timestamp.fromMillis(1000)));
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
  authenticated: () => environment.authenticatedContext("customer", {
    customerVerified: true, firebase: {sign_in_provider: "password"},
  }).firestore(),
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

test("temporary public access to orders has been removed",
    async () => {
      const db = clients.unauthenticated();
      await assertFails(setDoc(doc(db, "orders/compatibility"), {
        status: "Novo"}));
      await assertFails(getDocs(collection(db, "orders")));
      await assertFails(updateDoc(doc(db, "orders/existing"), {
        status: "Em Separação",
      }));
    });

// Contrato copiado de _montarDadosPedido: dinheiro, maquininha, PIX e dividido.
const checkoutOrder = (overrides = {}) => {
  return {
    id: "#CH-CHECKOUT", customerUid: "customer", customerName: "Cliente",
    customerFlowVersion: 2,
    customerPhone: "telefone-do-cliente", address: "Rua da Loja, 1",
    deliveryAddress: {addressText: "Rua da Loja, 1", latitude: -22.5,
      longitude: -55.7, street: "Rua da Loja", city: "Cidade",
      number: "1", confirmed: true, countryCode: "BR"},
    deliveryLocation: new GeoPoint(-22.5, -55.7),
    itemsList: [{id: "p1", name: "Produto", quantity: 1, price: 20}],
    itemsTotal: 20, deliveryFee: 5, customerFee: 1, merchantFee: 0.6,
    merchantNet: 19.4, platformFee: 1.6, totalBRL: 26,
    displayCurrency: "BRL", displayTotal: 26, exchangeRatePYGPerBRL: 1400,
    exchangeRateBRLPerUSD: 5, exchangeRateSource: "fixed_initial",
    exchangeRateCapturedAt: serverTimestamp(), paymentMethod: "Dinheiro",
    paymentStatus: "Pendente na entrega", cardType: null, cashCurrency: "BRL",
    cashTendered: 30, cashTenderedBRL: 30, changeBRL: 4,
    cashChangeRateUSDToBRL: null, cashChangeRatePYGPerBRL: null,
    splitPayment: false, paymentParts: null, splitPaidBRL: null,
    splitRemainingBRL: null, splitChangeBRL: null, status: "Novo",
    pixRequested: false, pixRequestVersion: null,
    courierName: "Entregador", courierPaid: false, createdAt: serverTimestamp(),
    ...overrides,
  };
};

const validatedOrder = (overrides = {}) => {
  return checkoutOrder({
    createdAt: Timestamp.fromMillis(1000),
    exchangeRateCapturedAt: Timestamp.fromMillis(1000),
    financialValidationStatus: "validated", stockReservationRequired: true,
    stockReservationStatus: "reserved", ...overrides,
  });
};

test("unverified customer browses but cannot place an order", async () => {
  const db = environment.authenticatedContext("customer", {
    firebase: {sign_in_provider: "password"},
  }).firestore();
  await assertSucceeds(getDoc(doc(db, "products/p1")));
  await assertFails(setDoc(doc(db, "orders/unverified"), checkoutOrder()));
});

test("anonymous cannot buy even with a verification claim", async () => {
  const db = environment.authenticatedContext("customer", {
    customerVerified: true, firebase: {sign_in_provider: "anonymous"},
  }).firestore();
  await assertFails(setDoc(doc(db, "orders/anon-claim"), checkoutOrder()));
});

for (const provider of ["google.com", "apple.com"]) {
  test(`${provider}: trusted Firebase identity buys with current consent`,
      async () => {
        const db = environment.authenticatedContext("customer", {
          firebase: {sign_in_provider: provider},
        }).firestore();
        await assertSucceeds(setDoc(doc(db, "orders", provider),
            checkoutOrder()));
      });
}

test("consent is server-only; stale/missing consent blocks new customer flow",
    async () => {
      const db = clients.authenticated();
      await assertFails(updateDoc(doc(db, "customerProfiles/customer"),
          {birthDate: "1990-01-01"}));
      await assertFails(setDoc(doc(db, "customerPolicies/current"),
          {published: true}));
      const stale = environment.authenticatedContext("stale", {
        firebase: {sign_in_provider: "google.com"},
      }).firestore();
      const p = customerPolicyFixture();
      await seed("stale", {...customerProfileFixture(p,
          Timestamp.fromMillis(1000)), termsVersion: "TEST-OLD"},
      "customerProfiles");
      await assertFails(setDoc(doc(stale, "orders/no-current-consent"),
          checkoutOrder({customerUid: "stale"})));
      await assertFails(getDoc(doc(stale, "customerProfiles/customer")));
      await assertFails(setDoc(doc(db,
          "customerConsentEvents/customer/events/forged"), {acceptedAt: true}));
    });

test("discarded proposal cannot arrive late; lock is private and server only",
    async () => {
      const id = "cancelled-order";
      const lock = `customerOrderCancellations/customer/orders/${id}`;
      await environment.withSecurityRulesDisabled(async (context) => {
        await setDoc(doc(context.firestore(), lock), {uid: "customer"});
      });
      const db = clients.authenticated();
      await assertFails(setDoc(doc(db, "orders", id), checkoutOrder()));
      await assertFails(getDoc(doc(db, lock)));
      await assertFails(setDoc(doc(db, lock), {uid: "customer"}));
    });

for (const address of [{confirmed: false}, {countryCode: "US"},
  {latitude: 91}, {longitude: -181}, {street: ""}, {city: ""},
  {number: "", noNumber: false}]) {
  test(`checkout refuses invalid destination ${JSON.stringify(address)}`,
      async () => {
        const valid = checkoutOrder();
        await assertFails(setDoc(doc(clients.authenticated(),
            "orders/bad-destination"), {...valid,
          deliveryAddress: {...valid.deliveryAddress, ...address}}));
      });
}

test("verified owner can use confirmed PY destination without a number",
    async () => {
      const order = checkoutOrder();
      await assertSucceeds(setDoc(doc(clients.authenticated(),
          "orders/confirmed-py"), {...order, deliveryAddress: {
        ...order.deliveryAddress, countryCode: "PY", noNumber: true, number: "",
      }}));
    });

test(
    "bootstrap: own missing profile is readable " +
    "and only minimal create is allowed",
    async () => {
      const db = environment.authenticatedContext("new-google", {
        firebase: {sign_in_provider: "google.com"},
      }).firestore();
      const ref = doc(db, "customerProfiles/new-google");
      assert.equal((await assertSucceeds(getDoc(ref))).exists(), false);
      await assertFails(setDoc(ref, {createdAt: serverTimestamp(),
        acceptedAt: serverTimestamp()}));
      await assertFails(setDoc(ref, {createdAt: serverTimestamp(),
        birthDate: "2000-01-01"}));
      await assertFails(setDoc(ref, {createdAt: Timestamp.fromMillis(0)}));
      await assertSucceeds(setDoc(ref, {createdAt: serverTimestamp()}));
      await assertSucceeds(getDoc(ref));
      await assertSucceeds(getDoc(doc(clients.authenticated(),
          "customerProfiles/customer")));
      await assertFails(updateDoc(ref, {customerVerified: true}));
      await assertFails(setDoc(ref, {createdAt: serverTimestamp()}));
      await assertFails(deleteDoc(ref));
      await assertFails(getDoc(doc(db, "customerProfiles/customer")));
      await assertFails(setDoc(doc(db, "customerProfiles/foreign"),
          {createdAt: serverTimestamp()}));
      await assertFails(getDocs(collection(db, "customerProfiles")));
    });

test("policy: authenticated get current only, never list or client writes",
    async () => {
      const db = clients.authenticated();
      await assertSucceeds(getDoc(doc(db, "customerPolicies/current")));
      await assertFails(getDoc(doc(db, "customerPolicies/draft-private")));
      await assertFails(getDocs(collection(db, "customerPolicies")));
      await assertFails(getDoc(doc(clients.unauthenticated(),
          "customerPolicies/current")));
      await assertFails(setDoc(doc(db, "customerPolicies/new"),
          {published: true}));
      await assertFails(updateDoc(doc(db, "customerPolicies/current"),
          {published: false}));
      await assertFails(deleteDoc(doc(db, "customerPolicies/current")));
    });

test(
    "linking: same UID keeps workspace, refreshed Google token unlocks profile",
    async () => {
      const uid = "linked-anonymous";
      const anonymous = environment.authenticatedContext(uid, {
        firebase: {sign_in_provider: "anonymous"},
      }).firestore();
      const google = environment.authenticatedContext(uid, {
        firebase: {sign_in_provider: "google.com"},
      }).firestore();
      const path = `customerWorkspaces/${uid}`;
      assert.equal(
          (await assertSucceeds(getDoc(doc(anonymous, path)))).exists(), false);
      await assertSucceeds(setDoc(doc(anonymous, path), {addresses: [],
        cart: [{id: "p1", quantity: 1}]}));
      const saved = await assertSucceeds(getDoc(doc(google, path)));
      assert.equal(saved.data().cart[0].id, "p1");
      await assertFails(getDoc(doc(anonymous, `customerProfiles/${uid}`)));
      await assertFails(setDoc(doc(anonymous, `customerProfiles/${uid}`),
          {createdAt: serverTimestamp()}));
      await assertSucceeds(setDoc(doc(google, `customerProfiles/${uid}`),
          {createdAt: serverTimestamp()}));
      await assertSucceeds(getDoc(doc(google, `customerProfiles/${uid}`)));
      const other = environment.authenticatedContext("switched-uid", {
        firebase: {sign_in_provider: "google.com"},
      }).firestore();
      await assertFails(getDoc(doc(other, path)));
      await assertFails(getDoc(doc(other, `customerProfiles/${uid}`)));
      await assertFails(getDocs(collection(google, "customerWorkspaces")));
      for (const db of [anonymous, google, other, clients.unauthenticated()]) {
        await assertFails(getDoc(doc(db, "orderFinancials/existing")));
        await assertFails(getDoc(doc(db, `customerDeliverySecrets/${uid}`)));
        await assertFails(getDoc(doc(db,
            `customerConsentEvents/${uid}/events/private`)));
      }
    });

test("courier cannot bootstrap a customer profile or workspace", async () => {
  await seed("bootstrap-courier", {administrativeState: "active"}, "couriers");
  const db = environment.authenticatedContext("bootstrap-courier", {
    firebase: {sign_in_provider: "google.com"},
  }).firestore();
  for (const name of ["customerProfiles", "customerWorkspaces"]) {
    const ref = doc(db, name, "bootstrap-courier");
    await assertFails(getDoc(ref));
    await assertFails(setDoc(ref, name === "customerProfiles" ?
      {createdAt: serverTimestamp()} : {addresses: [], cart: []}));
  }
});

test("workspace belongs only to owner and has no privileged fields",
    async () => {
      const owner = clients.authenticated();
      const foreign = environment.authenticatedContext("foreign").firestore();
      await assertSucceeds(setDoc(doc(owner, "customerWorkspaces/customer"), {
        addresses: [], cart: [], pending: null,
      }));
      await assertSucceeds(getDoc(doc(owner, "customerWorkspaces/customer")));
      await assertFails(getDoc(doc(foreign, "customerWorkspaces/customer")));
      await assertFails(updateDoc(doc(foreign, "customerWorkspaces/customer"),
          {cart: []}));
      await assertFails(updateDoc(doc(owner, "customerWorkspaces/customer"),
          {customerVerified: true}));
      await assertFails(updateDoc(doc(owner, "customerWorkspaces/customer"),
          {cart: Array(101).fill({id: "p1"})}));
    });

test("pricing versions: superadmin reads, no direct writes or other roles",
    async () => {
      await seed("test-version", {published: false},
          "deliveryPricingVersions");
      await assertSucceeds(getDoc(doc(roleDb("superadmin"),
          "deliveryPricingVersions/test-version")));
      for (const role of ["operations_admin", "catalog_admin", "finance"]) {
        await assertFails(getDoc(doc(roleDb(role),
            "deliveryPricingVersions/test-version")));
      }
      await assertFails(getDoc(doc(clients.authenticated(),
          "deliveryPricingVersions/test-version")));
      await assertFails(setDoc(doc(roleDb("superadmin"),
          "deliveryPricingVersions/direct"), {published: true}));
      await assertFails(setDoc(doc(roleDb("superadmin"),
          "deliveryConfiguration/current"), {mode: "routeBands"}));
    });

test("delivery configuration: superadmin reads; SDK writes denied",
    async () => {
      for (const id of ["current", "draft"]) {
        await seed(id, {activeVersion: "test-version"},
            "deliveryConfiguration");
        await assertSucceeds(getDoc(doc(roleDb("superadmin"),
            `deliveryConfiguration/${id}`)));
        for (const db of [clients.authenticated(), clients.unauthenticated(),
          roleDb("finance"), roleDb("operations_admin"),
          roleDb("catalog_admin")]) {
          await assertFails(getDoc(doc(db, `deliveryConfiguration/${id}`)));
          await assertFails(setDoc(doc(db, `deliveryConfiguration/${id}`),
              {mode: "routeBands"}));
        }
        await assertFails(updateDoc(doc(roleDb("superadmin"),
            `deliveryConfiguration/${id}`), {activeVersion: "forged"}));
      }
    });

for (const name of ["deliveryQuotes", "customerDeliverySecrets",
  "deliveryPinVerifiers", "deliveryPinAudit"]) {
  test(`${name}: customer, courier, admin cannot read/write private data`,
      async () => {
        await seed("private-rider", {administrativeState: "active"},
            "couriers");
        await seed("private", {secret: "not-for-clients"}, name);
        const rider = environment.authenticatedContext("private-rider")
            .firestore();
        for (const db of [clients.authenticated(), rider,
          roleDb("superadmin")]) {
          await assertFails(getDoc(doc(db, name, "private")));
          await assertFails(setDoc(doc(db, name, "forged"), {value: 1}));
        }
      });
}

const roleDb = (role, uid = role) => {
  return environment.authenticatedContext(uid, {roles: [role]}).firestore();
};

const seed = async (id, data, collectionName = "orders") => {
  await environment.withSecurityRulesDisabled(async (context) => {
    await setDoc(doc(context.firestore(), collectionName, id), data);
  });
};

for (const [name, overrides] of Object.entries({
  dinheiro: {},
  maquininha: {paymentMethod: "Maquininha - Débito à vista",
    cardType: "Débito"},
  pix: {paymentMethod: "PIX", pixRequested: true, pixRequestVersion: 1,
    paymentStatus: "Aguardando confirmação", status: "Aguardando pagamento"},
  dividido: {paymentMethod: "Pagamento dividido", splitPayment: true,
    paymentParts: [{method: "Dinheiro", amountBRL: 10},
      {method: "Maquininha", amountBRL: 16}],
    splitPaidBRL: 26, splitRemainingBRL: 0, splitChangeBRL: 0},
})) {
  test(`checkout ${name}: owner can create the actual payload`, async () => {
    await assertSucceeds(setDoc(doc(clients.authenticated(),
        `orders/create-${name}`),
    checkoutOrder(overrides)));
  });
}

test("anonymous: cannot buy; keeps historical order access", async () => {
  const db = environment.authenticatedContext("anonymous-customer", {
    firebase: {sign_in_provider: "anonymous"}, roles: ["superadmin"],
  }).firestore();
  await assertFails(setDoc(doc(db, "orders/anonymous-own"),
      checkoutOrder({customerUid: "anonymous-customer"})));
  await seed("anonymous-own", checkoutOrder({customerUid: "anonymous-customer",
    createdAt: Timestamp.fromMillis(1000),
    exchangeRateCapturedAt: Timestamp.fromMillis(1000)}));
  await assertSucceeds(getDoc(doc(db, "orders/anonymous-own")));
  await assertFails(getDoc(doc(db, "orders/existing")));
  await assertFails(setDoc(doc(db, "products/anonymous-fake"), product));
});

test("customer: foreign UID and unauthenticated create are denied",
    async () => {
      await assertFails(setDoc(doc(clients.authenticated(),
          "orders/foreign-create"),
      checkoutOrder({customerUid: "another-customer"})));
      await assertFails(setDoc(doc(clients.unauthenticated(),
          "orders/no-auth-create"),
      checkoutOrder()));
    });

for (const field of ["financialValidationStatus", "stockProcessingStatus",
  "stockReservationStatus", "stockReservationRequired", "completedAt",
  "courierSettlementId", "mercadoPagoPaymentId", "mercadoPagoOrderId",
  "mercadoPagoQrCode", "externalReference", "totalCentavos", "unknownField"]) {
  test(`customer: cannot pre-create backend field ${field}`, async () => {
    await assertFails(setDoc(doc(clients.authenticated(),
        `orders/injected-${field}`),
    checkoutOrder({[field]: "forged"})));
  });
}

for (const overrides of [
  {paymentStatus: "Pago"}, {status: "Concluído"}, {status: "Em Separação"},
  {courierPaid: true}, {createdAt: Timestamp.fromMillis(1000)},
  {totalBRL: 0}, {itemsList: []},
  {pixRequested: true, status: "Novo"},
]) {
  test(`customer: invalid creation state ${JSON.stringify(overrides)}`,
      async () => {
        await assertFails(setDoc(doc(clients.authenticated(),
            "orders/invalid-create"),
        checkoutOrder(overrides)));
      });
}

test("customer reads only own orders; queries require customerUid",
    async () => {
      await seed("owner-read", validatedOrder());
      const db = clients.authenticated();
      await assertSucceeds(getDoc(doc(db, "orders/owner-read")));
      await assertFails(getDoc(doc(environment.authenticatedContext(
          "other").firestore(),
      "orders/owner-read")));
      await assertSucceeds(getDocs(query(collection(db, "orders"),
          where("customerUid", "==", "customer"))));
      await assertFails(getDocs(query(collection(db, "orders"),
          where("id", "==", "#CH-CHECKOUT"))));
      await assertFails(getDocs(collection(db, "orders")));
      await assertFails(getDoc(doc(clients.unauthenticated(),
          "orders/owner-read")));
    });

for (const field of ["paymentStatus", "totalBRL", "status", "customerUid",
  "mercadoPagoPaymentId", "courierPaid", "itemsList",
  "financialValidationStatus"]) {
  test(`customer: cannot update ${field} even on own order`, async () => {
    await seed(`customer-update-${field}`, validatedOrder());
    await assertFails(updateDoc(doc(clients.authenticated(),
        `orders/customer-update-${field}`), {[field]: "forged"}));
  });
}

test("customer: no replace, delete or nested writes", async () => {
  await seed("customer-replace", validatedOrder());
  const db = clients.authenticated();
  await assertFails(setDoc(doc(db, "orders/customer-replace"),
      checkoutOrder()));
  await assertFails(deleteDoc(doc(db, "orders/customer-replace")));
  await assertFails(setDoc(doc(db, "orders/customer-replace/events/fake"), {}));
});

for (const role of ["operations_admin", "superadmin"]) {
  test(`${role}: reads operational queries; critical SDK writes denied`,
      async () => {
        const id = `operational-${role}`;
        await seed(id, validatedOrder());
        const db = roleDb(role);
        await assertSucceeds(getDocs(collection(db, "orders")));
        await assertSucceeds(getDocs(query(collection(db, "orders"),
            where("status", "not-in", ["Concluído", "Cancelado"]))));
        await assertSucceeds(getDocs(query(collection(db, "orders"),
            where("createdAt", ">=", Timestamp.fromMillis(0)))));
        const ref = doc(db, "orders", id);
        await assertFails(updateDoc(ref, {status: "Em Separação"}));
        await seed(id, validatedOrder({status: "Em Separação"}));
        await assertFails(updateDoc(ref, {status: "Saiu para Entrega"}));
        await seed(id, validatedOrder({status: "Saiu para Entrega"}));
        await assertFails(updateDoc(ref, {status: "Concluído",
          completedAt: serverTimestamp()}));
        await assertFails(updateDoc(ref, {status: "Novo"}));
        await assertFails(deleteDoc(ref));
      });
  for (const field of ["totalBRL", "itemsTotal", "customerFee", "merchantFee",
    "merchantNet", "platformFee", "deliveryFee", "paymentStatus", "customerUid",
    "itemsList", "mercadoPagoPaymentId", "mercadoPagoOrderId",
    "financialValidationStatus", "stockReservationStatus",
    "stockProcessingStatus",
    "courierName"]) {
    test(`${role}: cannot change ${field} alongside valid transition`,
        async () => {
          const id = `protected-${role}-${field}`;
          await seed(id, validatedOrder());
          await assertFails(updateDoc(doc(roleDb(role), "orders", id), {
            status: "Em Separação", [field]: "forged",
          }));
          await assertFails(updateDoc(doc(roleDb(role), "orders", id), {
            [field]: deleteField()}));
        });
  }
}

for (const [name, overrides] of Object.entries({
  unvalidated: {financialValidationStatus: "pending"},
  rejected: {financialValidationStatus: "rejected"},
  review: {stockReservationStatus: "requires_review"},
  unreserved: {stockReservationStatus: "pending"},
  stockError: {stockProcessingError: "failure"},
  pixPending: {paymentMethod: "PIX", paymentStatus: "Aguardando confirmação"},
  pixUnprocessed: {paymentMethod: "PIX", paymentStatus: "Pago"},
  splitPix: {paymentMethod: "Pagamento dividido", paymentParts: [{
    method: "Dinheiro"}, {method: "PIX"}]},
  splitPixLower: {paymentMethod: "Pagamento dividido",
    paymentParts: [{method: "pix"}]},
  splitPixAlias: {paymentMethod: "Pagamento dividido",
    paymentParts: [{paymentMethod: "Pix"}]},
  splitPixType: {paymentMethod: "Pagamento dividido",
    paymentParts: [{type: "PIX"}]},
})) {
  test(`operations: cannot advance ${name} order`, async () => {
    await seed(`blocked-${name}`, validatedOrder(overrides));
    await assertFails(updateDoc(doc(roleDb("operations_admin"), "orders",
        `blocked-${name}`),
    {status: "Em Separação"}));
  });
}

test("operations: even valid PIX cannot advance directly", async () => {
  await seed("pix-valid", validatedOrder({paymentMethod: "PIX",
    paymentStatus: "Pago",
    stockProcessingStatus: "processed"}));
  const db = roleDb("operations_admin");
  await assertFails(updateDoc(doc(db, "orders/pix-valid"), {
    status: "Em Separação"}));
  await assertFails(updateDoc(doc(db, "orders/pix-valid"), {
    status: "Concluído", completedAt: serverTimestamp()}));
  await seed("completion", validatedOrder({status: "Saiu para Entrega"}));
  await assertFails(updateDoc(doc(db, "orders/completion"), {
    status: "Concluído"}));
  await assertFails(updateDoc(doc(db, "orders/completion"), {
    status: "Concluído", completedAt: Timestamp.fromMillis(1000)}));
});

test("catalog_admin: product CRUD, other roles read-only", async () => {
  const db = roleDb("catalog_admin");
  await assertSucceeds(setDoc(doc(db, "products/catalog-managed"), product));
  await assertSucceeds(updateDoc(doc(db, "products/catalog-managed"), {
    stock: 5}));
  await assertSucceeds(getDoc(doc(db, "products/catalog-managed")));
  await assertSucceeds(deleteDoc(doc(db, "products/catalog-managed")));
  for (const role of ["operations_admin", "finance", "unknown"]) {
    await assertFails(setDoc(doc(roleDb(role),
        `products/forbidden-${role}`), product));
  }
  await assertFails(getDocs(collection(db, "orders")));
});

test("finance: reads orders and settlements but cannot write either",
    async () => {
      const db = roleDb("finance");
      await seed("finance-read", validatedOrder());
      await assertSucceeds(getDocs(collection(db, "orders")));
      await assertSucceeds(getDocs(collection(db, "courierSettlements")));
      for (const change of [{status: "Em Separação"}, {totalBRL: 1}, {
        courierPaid: true}]) {
        await assertFails(updateDoc(doc(db, "orders/finance-read"), change));
      }
      await assertFails(setDoc(doc(db, "courierSettlements/finance-fake"), {
        status: "paid"}));
      await seed("finance-settlement", validatedOrder({status: "Concluído",
        paymentStatus: "Pago"}));
      await assertFails(settlementBatch(db, "finance-settlement",
          "finance-valid-receipt"));
    });

for (const claims of [{roles: "superadmin"}, {role: "superadmin"}, {
  admin: true},
{roles: [true, 1, "unknown"]}, {roles: null}]) {
  test(`malformed claims: ${JSON.stringify(claims)}`, async () => {
    const db = environment.authenticatedContext("unprivileged",
        claims).firestore();
    await assertFails(getDocs(collection(db, "orders")));
  });
}

for (const role of ["operations_admin", "catalog_admin", "finance",
  "superadmin"]) {
  test(`${role}: private financial documents remain backend-only`, async () => {
    const db = roleDb(role);
    await assertFails(getDoc(doc(db, "orderFinancials/existing")));
    await assertFails(getDocs(collection(db, "orderFinancials")));
    await assertFails(setDoc(doc(db, `orderFinancials/${role}`), financial));
    await assertFails(setDoc(doc(db,
        `orderFinancials/existing/nested/${role}`), financial));
    await assertFails(updateDoc(doc(db, "orderFinancials/existing"), {
      totalBRL: 1}));
    await assertFails(deleteDoc(doc(db, "orderFinancials/existing")));
  });
}

for (const collectionName of ["couriers", "reviews"]) {
  const id = `operational-read-${collectionName}`;
  for (const role of ["operations_admin", "superadmin", "finance",
    "catalog_admin"]) {
    const allowed = ["operations_admin", "superadmin"].includes(role);
    const access = allowed ? "allowed" : "denied";
    test(`${role}: ${collectionName} get/list ${access}`,
        async () => {
          await seed(id, {name: "Registro", administrativeState: "active"},
              collectionName);
          const db = roleDb(role);
          const check = allowed ? assertSucceeds : assertFails;
          const [read, list] = await Promise.all([
            check(getDoc(doc(db, collectionName, id))),
            check(getDocs(collection(db, collectionName))),
          ]);
          if (allowed) {
            assert.equal(read.id, id);
            assert.ok(list.docs.some((d) => d.id === id));
            if (collectionName === "couriers") {
              const active = await assertSucceeds(getDocs(query(
                  collection(db, "couriers"),
                  where("administrativeState", "==", "active"))));
              assert.ok(active.docs.some((d) => d.id === id));
            }
          }
        });
    test(`${role}: ${collectionName} SDK writes remain denied`, async () => {
      const db = roleDb(role);
      const ref = doc(db, collectionName, id);
      await assertFails(setDoc(doc(db, collectionName, `new-${role}`), {
        name: "Forjado", administrativeState: "active"}));
      await assertFails(setDoc(ref, {name: "Substituido"}));
      await assertFails(updateDoc(ref, {name: "Alterado"}));
      await assertFails(deleteDoc(ref));
      const nested = doc(db, collectionName, id, "private", role);
      await assertFails(getDoc(nested));
      await assertFails(setDoc(nested, {name: "Forjado"}));
    });
  }
  for (const identity of ["unauthenticated", "customer", "unknown",
    "anonymous-operations", "anonymous-superadmin", "nonoperational-roles",
    "courier", "courier-operations", "courier-superadmin"]) {
    test(`${identity}: no administrative access to ${collectionName}`,
        async () => {
          const rider = `administrative-rider-${collectionName}`;
          await seed(rider, {name: "Entregador", administrativeState: "active"},
              "couriers");
          let db;
          if (identity === "unauthenticated") {
            db = environment.unauthenticatedContext().firestore();
          } else if (identity.startsWith("anonymous-")) {
            db = environment.authenticatedContext(identity, {
              roles: [identity.endsWith("superadmin") ?
                "superadmin" : "operations_admin"],
              firebase: {sign_in_provider: "anonymous"},
            }).firestore();
          } else if (identity.startsWith("courier")) {
            const roles = identity === "courier" ? [] :
              [identity.endsWith("superadmin") ?
                "superadmin" : "operations_admin"];
            db = environment.authenticatedContext(rider, {roles}).firestore();
          } else {
            db = environment.authenticatedContext(identity, {
              roles: identity === "nonoperational-roles" ?
                ["finance", "catalog_admin"] : [identity],
            }).firestore();
          }
          await assertFails(getDoc(doc(db, collectionName, id)));
          await assertFails(getDocs(collection(db, collectionName)));
          await assertFails(setDoc(doc(db, collectionName,
              `forged-${identity}`),
          {name: "Forjado"}));
          if (identity.startsWith("courier")) {
            await assertFails(getDoc(doc(db, "couriers", rider)));
          }
        });
  }
}

test("superadmin retains existing catalog management permission", async () => {
  await assertSucceeds(setDoc(doc(roleDb("superadmin"),
      "products/super-managed"), product));
});

test("courier: own deliveries, never full orders", async () => {
  await seed("rider", {name: "Entregador",
    administrativeState: "active"},
  "couriers");
  await seed("rider-other", {name: "Outro", administrativeState: "active"},
      "couriers");
  await seed("rider-own-order", validatedOrder({customerUid: "rider"}));
  const delivery = {orderId: "rider-own-order", courierUid: "rider",
    customerName: "Primeiro nome", address: "Rua, 1",
    deliveryLocation: new GeoPoint(-22.5, -55.7), status: "assigned"};
  await seed("assigned", delivery, "courierDeliveries");
  await seed("other", {...delivery, courierUid: "rider-other"},
      "courierDeliveries");
  const db = environment.authenticatedContext("rider").firestore();
  await assertSucceeds(getDoc(doc(db, "courierDeliveries/assigned")));
  await assertFails(getDocs(query(collection(db, "courierDeliveries"),
      where("courierUid", "==", "rider"))));
  await assertFails(getDoc(doc(db, "courierDeliveries/other")));
  await assertFails(getDocs(collection(db, "courierDeliveries")));
  for (const riderDb of [db, roleDb("superadmin", "rider")]) {
    await assertFails(getDoc(doc(riderDb, "orders/rider-own-order")));
    await assertFails(getDocs(collection(riderDb, "orders")));
    await assertFails(setDoc(doc(riderDb, "orders/rider-create"),
        checkoutOrder({customerUid: "rider"})));
    await assertFails(updateDoc(doc(riderDb, "orders/rider-own-order"), {
      status: "Em Separação"}));
  }
  await assertFails(setDoc(doc(db, "courierDeliveries/fake"), delivery));
  await assertFails(updateDoc(doc(db, "courierDeliveries/assigned"), {
    status: "completed"}));
  await assertFails(deleteDoc(doc(db, "courierDeliveries/assigned")));
  await assertFails(setDoc(doc(roleDb("superadmin"),
      "courierDeliveries/admin-fake"), delivery));
  await seed("unprovisioned", {...delivery, courierUid: "unprovisioned"},
      "courierDeliveries");
  await assertFails(getDoc(doc(environment.authenticatedContext(
      "unprovisioned").firestore(), "courierDeliveries/unprovisioned")));
  await assertFails(getDoc(doc(clients.unauthenticated(),
      "courierDeliveries/assigned")));
});

for (const field of ["customerPhone", "whatsapp", "email", "customerHistory",
  "mercadoPagoPaymentId", "merchantNet"]) {
  test(`courier projection rejects accidental sensitive field ${field}`,
      async () => {
        await seed("rider-safe", {name: "Entregador",
          administrativeState: "active"},
        "couriers");
        await seed(`unsafe-${field}`, {orderId: "owner-read",
          courierUid: "rider-safe",
          customerName: "Nome", status: "assigned", [field]: "private"},
        "courierDeliveries");
        await assertFails(getDoc(doc(environment.authenticatedContext(
            "rider-safe").firestore(),
        "courierDeliveries", `unsafe-${field}`)));
      });
}

for (const field of ["orderId", "customerName", "status", "createdAt"]) {
  test(`courier projection: nested data in ${field} denied`, async () => {
    await seed("typed-rider", {name: "Entregador",
      administrativeState: "active"},
    "couriers");
    const delivery = {
      orderId: "owner-read", courierUid: "typed-rider",
      customerName: "Nome", status: "assigned",
      [field]: {customerPhone: "private"},
    };
    await seed(`nested-${field}`, delivery, "courierDeliveries");
    const db = environment.authenticatedContext("typed-rider").firestore();
    await assertFails(getDoc(doc(db, "courierDeliveries", `nested-${field}`)));
  });
}

const singleReceipt = (orderId, overrides = {}) => {
  return {courierName: "Entregador", orderDocumentIds: [orderId],
    orders: [{documentId: orderId, id: "#CH-CHECKOUT", deliveryFee: 5}],
    total: 5, orderCount: 1, createdAt: serverTimestamp(), status: "paid",
    ...overrides};
};

const settlementBatch = async (db, orderId, receiptId, overrides = {}) => {
  const batch = writeBatch(db);
  batch.update(doc(db, "orders", orderId), {courierPaid: true,
    courierPaidAt: serverTimestamp(), courierSettlementId: receiptId});
  batch.set(doc(db, "courierSettlements", receiptId), singleReceipt(
      orderId, overrides));
  return batch.commit();
};

for (const role of ["operations_admin", "superadmin"]) {
  test(`${role}: atomic receipt with exact payload`, async () => {
    const id = `settle-${role}`;
    await seed(id, validatedOrder({status: "Concluído",
      paymentStatus: "Pago"}));
    const db = roleDb(role);
    await assertFails(settlementBatch(db, id, `receipt-${role}`));
    await seed(`receipt-${role}`, singleReceipt(id), "courierSettlements");
    await assertSucceeds(getDoc(doc(db, "courierSettlements",
        `receipt-${role}`)));
    await assertFails(settlementBatch(db, id, `receipt-duplicate-${role}`));
    await assertFails(updateDoc(doc(db, "courierSettlements",
        `receipt-${role}`), {total: 1}));
    await assertFails(deleteDoc(doc(db, "courierSettlements",
        `receipt-${role}`)));
  });
}

for (const [name, overrides] of Object.entries({
  inflated: {total: 5000}, wrongCourier: {courierName: "Outro"},
  extra: {customerPhone: "private"}, fakeCount: {orderCount: 2},
  fakeLine: {orders: [{documentId: "fake", id: "#CH-CHECKOUT",
    deliveryFee: 5}]},
  fakeFee: {orders: [{documentId: "invalid-fee", id: "#CH-CHECKOUT",
    deliveryFee: 5000}]},
  forgedTime: {createdAt: Timestamp.fromMillis(1000)},
})) {
  test(`settlement: reject ${name} without partial order update`, async () => {
    const id = `invalid-${name}`;
    await seed(id, validatedOrder({status: "Concluído",
      paymentStatus: "Pago"}));
    const db = roleDb("operations_admin");
    await assertFails(settlementBatch(db, id, `receipt-invalid-${name}`,
        overrides));
    const order = await getDoc(doc(db, "orders", id));
    assert.equal(order.data().courierPaid, false);
  });
}

test("settlement: atomic receipt and eligible order required", async () => {
  const db = roleDb("operations_admin");
  await seed("orphan-paid", validatedOrder({status: "Concluído",
    paymentStatus: "Pago"}));
  await assertFails(updateDoc(doc(db, "orders/orphan-paid"), {courierPaid: true,
    courierPaidAt: serverTimestamp(), courierSettlementId: "orphan-receipt"}));
  await assertFails(setDoc(doc(db, "courierSettlements/orphan-receipt"),
      singleReceipt("orphan-paid")));
  for (const [name, overrides] of Object.entries({
    unpaid: {paymentStatus: "Pendente na entrega"},
    rejected: {financialValidationStatus: "rejected"},
    active: {status: "Em Separação"},
    stockReview: {stockReservationStatus: "requires_review"},
  })) {
    await seed(`ineligible-${name}`, validatedOrder({status: "Concluído",
      paymentStatus: "Pago", ...overrides}));
    await assertFails(settlementBatch(db, `ineligible-${name}`,
        `ineligible-receipt-${name}`));
  }
});

test("multi-order settlement: denied without partial writes", async () => {
  await seed("batch-a", validatedOrder({status: "Concluído",
    paymentStatus: "Pago"}));
  await seed("batch-b", validatedOrder({status: "Concluído",
    paymentStatus: "Pago"}));
  const db = roleDb("operations_admin");
  const batch = writeBatch(db);
  for (const id of ["batch-a", "batch-b"]) {
    batch.update(doc(db, "orders", id), {courierPaid: true,
      courierPaidAt: serverTimestamp(), courierSettlementId: "multi-receipt"});
  }
  batch.set(doc(db, "courierSettlements/multi-receipt"), singleReceipt(
      "batch-a", {
        orderDocumentIds: ["batch-a", "batch-b"], orderCount: 2, total: 10,
        orders: ["batch-a", "batch-b"].map((id) => ({documentId: id,
          id: "#CH-CHECKOUT", deliveryFee: 5})),
      }));
  await assertFails(batch.commit());
  assert.equal((await getDoc(doc(db, "orders/batch-a"))).data(
  ).courierPaid, false);
});

test("deny by default: nested paths and superadmin", async () => {
  for (const db of [clients.unauthenticated(), clients.authenticated(),
    roleDb("superadmin")]) {
    for (const target of ["unknown/id", "users/customer",
      "orders/owner-read/private/id",
      "courierSettlements/missing/private/id", "products/p1/private/id"]) {
      await assertFails(setDoc(doc(db, target), {value: 1}));
      await assertFails(getDoc(doc(db, target)));
    }
  }
});
