const assert = require("node:assert/strict");
const fs = require("node:fs");
const path = require("node:path");
const vm = require("node:vm");
const {test} = require("node:test");

const source = fs.readFileSync(path.join(__dirname, "../index.js"), "utf8");
const clone = (value) => JSON.parse(JSON.stringify(value));
const reference = (documentPath) => ({
  path: documentPath, id: documentPath.split("/").pop(),
});

const fixture = (overrides = {}, product = {}, options = {}) => {
  const initial = {
    itemsList: [{id: "p1", quantity: 3, price: 0.01, unitPrice: 0.01}],
    itemsTotal: 1, subtotal: 1, customerFee: 1, merchantFee: 1,
    merchantNet: 1, platformFee: 1, totalBRL: 1, deliveryFee: 1,
    financialValidationStatus: "validated", financialValidationVersion: 1,
    paymentMethod: "PIX", pixRequested: true, splitPayment: false,
    paymentStatus: "Aguardando confirmação", status: "Aguardando pagamento",
    ...overrides,
  };
  const docs = new Map([
    ["orders/o1", clone(initial)],
    ["products/p1", {
      priceBRL: 20, stock: 20, reservedStock: 0, salesCount: 0, ...product,
    }],
  ]);
  if (options.financial) {
    docs.set("orderFinancials/o1", clone(options.financial));
  }
  const requests = [];
  const responses = [];
  let retry = options.retry;
  const snapshot = (ref) => ({
    exists: docs.has(ref.path), ref,
    data: () => clone(docs.get(ref.path)),
  });
  const apply = (ref, fields) => {
    const target = docs.get(ref.path);
    assert.ok(target, "update requires an existing document");
    for (const [key, value] of Object.entries(fields)) {
      target[key] = value && typeof value === "object" && "increment" in value ?
        (target[key] || 0) + value.increment : value;
    }
  };
  const db = {
    collection: (name) => ({doc: (id) => {
      const ref = reference(`${name}/${id}`);
      ref.update = async (fields) => apply(ref, fields);
      return ref;
    }}),
    runTransaction: async (callback) => {
      const run = async () => {
        const writes = [];
        await callback({
          get: async (ref) => {
            assert.equal(writes.length, 0, "reads must precede writes");
            return snapshot(ref);
          },
          update: (ref, fields) => writes.push(["update", ref, fields]),
          set: (ref, fields) => writes.push(["set", ref, fields]),
        });
        return writes;
      };
      let writes = await run();
      if (retry) {
        retry(docs);
        retry = null;
        writes = await run();
      }
      for (const [operation, ref, fields] of writes) {
        if (operation === "set") docs.set(ref.path, clone(fields));
        else apply(ref, fields);
      }
    },
  };
  const context = {
    exports: {}, Buffer, AbortSignal,
    console: {log: () => {}, warn: () => {}, error: () => {}},
    fetch: async (url, init) => {
      requests.push({url, ...init});
      const body = init.method === "POST" ? JSON.parse(init.body) : {};
      return {ok: true, status: 200, json: async () => ({
        id: "ORD1", status: "processed", status_detail: "accredited",
        external_reference: "o1", processing_mode: "automatic",
        total_amount: options.mpAmount || body.total_amount || "70.60",
        transactions: {payments: [{
          id: "PAY1", status: "processed",
          payment_method: {
            id: "pix", type: "bank_transfer", qr_code: "QR",
          },
        }]},
      })};
    },
    require: (name) => {
      switch (name) {
        case "node:crypto": return require(name);
        case "./courier-deliveries": return require("../courier-deliveries");
        case "./courier-assignment": return require("../courier-assignment");
        case "./order-operations": return require("../order-operations");
        case "./order-chat": return require("../order-chat");
        case "./order-printing": return require("../order-printing");
        case "firebase-functions/v2/https":
          return {onRequest: (_, handler) => handler};
        case "firebase-functions/v2/firestore":
          return {
            onDocumentCreated: (_, handler) => handler,
            onDocumentUpdated: (_, handler) => handler,
          };
        case "firebase-functions/params":
          return {defineSecret: () => ({value: () => "test-secret"})};
        case "mercadopago": return {
          WebhookSignatureValidator: {validate: () => {}},
          InvalidWebhookSignatureError: class extends Error {},
        };
        case "firebase-admin/app":
          return {getApps: () => [{}], initializeApp: () => {}};
        case "firebase-admin/firestore": return {
          getFirestore: () => db,
          FieldValue: {
            serverTimestamp: () => "server-timestamp",
            increment: (value) => ({increment: value}),
          },
        };
        default: throw new Error(`Unexpected import: ${name}`);
      }
    },
  };
  vm.runInNewContext(source, context);
  const ref = db.collection("orders").doc("o1");
  const event = {params: {orderId: "o1"}, data: {
    exists: true, ref, data: () => clone(initial),
    before: {data: () => clone(initial)},
    after: {exists: true, ref, data: () => clone(initial)},
  }};
  const invoke = async (flow) => {
    const functions = context.exports;
    if (flow === "auto") return functions.chamaeCriarPixAutomatico(event);
    if (flow === "reserve") {
      return functions.chamaeReservarEstoquePagamentoEntrega(event);
    }
    if (flow === "resolve") {
      return functions.chamaeResolverReservaEstoque({
        ...event, data: {...event.data, after: snapshot(ref)},
      });
    }
    const response = {
      status: (status) => {
        responses.push({status});
        return response;
      },
      json: (body) => {
        responses[responses.length - 1].body = body;
      },
      send: () => {},
    };
    const request = {
      method: "POST", body: {orderDocumentId: "o1", type: "order"},
      query: {"data.id": "ORD1"}, get: () => "test-secret",
    };
    return flow === "manual" ? functions.chamaeCriarPix(request, response) :
      functions.chamaeMercadoPagoWebhook(request, response);
  };
  return {docs, requests, responses, invoke};
};

const assertFinancial = (data) => {
  for (const [key, expected] of Object.entries({
    itemsTotal: 60, deliveryFee: 10, customerFee: 0.60, merchantFee: 1.80,
    merchantNet: 58.20, platformFee: 2.40, totalBRL: 70.60,
  })) assert.equal(data[key], expected, key);
};

for (const flow of ["auto", "manual"]) {
  test(`${flow}: ignores client prices, totals and flags`, async () => {
    const f = fixture({mercadoPagoAmountBRL: 0.01});
    await f.invoke(flow);
    assertFinancial(f.docs.get("orders/o1"));
    assertFinancial(f.docs.get("orderFinancials/o1"));
    assert.equal(f.docs.get("orders/o1").itemsList[0].price, 20);
    assert.equal(f.docs.get("orders/o1").itemsList[0].unitPrice, 20);
    assert.equal(JSON.parse(f.requests[0].body).total_amount, "70.60");
    assert.equal(f.docs.get("products/p1").stock, 20);
  });

  test(`${flow}: retry freezes price and ignores modified order totals`,
      async () => {
        const f = fixture();
        await f.invoke(flow);
        const key = f.requests[0].headers["X-Idempotency-Key"];
        const order = f.docs.get("orders/o1");
        delete order.mercadoPagoOrderId;
        order.totalBRL = 0.01;
        order.mercadoPagoAmountBRL = 0.01;
        order.mercadoPagoIdempotencyKey = "forged-key";
        f.docs.get("products/p1").priceBRL = 100;
        await f.invoke(flow);
        assertFinancial(order);
        assert.equal(JSON.parse(f.requests[1].body).total_amount, "70.60");
        assert.equal(f.requests[1].headers["X-Idempotency-Key"], key);
      });

  test(`${flow}: changed quantities cannot reuse payment`, async () => {
    const f = fixture();
    await f.invoke(flow);
    const order = f.docs.get("orders/o1");
    delete order.mercadoPagoOrderId;
    order.itemsList[0].quantity = 4;
    await f.invoke(flow);
    assert.equal(f.requests.length, 1);
  });

  test(`${flow}: legacy matching amount reuses idempotency key`, async () => {
    const f = fixture({
      mercadoPagoIdempotencyKey: "legacy-key", mercadoPagoAmountBRL: 70.60,
    });
    await f.invoke(flow);
    assert.equal(f.requests[0].headers["X-Idempotency-Key"], "legacy-key");
    assertFinancial(f.docs.get("orders/o1"));
  });

  test(`${flow}: legacy mismatched amount is blocked without a charge`,
      async () => {
        const f = fixture({
          mercadoPagoIdempotencyKey: "legacy-key", mercadoPagoAmountBRL: 1,
        });
        await f.invoke(flow);
        assert.equal(f.requests.length, 0);
        assert.equal(f.docs.has("orderFinancials/o1"), false);
      });

  test(`${flow}: already issued legacy PIX is not repriced`, async () => {
    const f = fixture({mercadoPagoOrderId: "OLD", totalBRL: 33});
    await f.invoke(flow);
    assert.equal(f.requests.length, 0);
    assert.equal(f.docs.get("orders/o1").totalBRL, 33);
  });
}

for (const method of [
  "Dinheiro", "Maquininha", "Maquininha - Débito à vista",
  "Maquininha - Crédito à vista",
]) {
  test(`${method}: reserves with official totals and preserves method`,
      async () => {
        const f = fixture({
          paymentMethod: method, pixRequested: false, status: "Novo",
          cashCurrency: "BRL", cashTendered: 100,
        });
        await f.invoke("reserve");
        assertFinancial(f.docs.get("orders/o1"));
        assert.equal(f.docs.get("orders/o1").paymentMethod, method);
        assert.equal(f.docs.get("products/p1").reservedStock, 3);
        await f.invoke("reserve");
        assert.equal(f.docs.get("products/p1").reservedStock, 3);
      });
}

test("cash: rejects insufficient tender against official total", async () => {
  const f = fixture({
    paymentMethod: "Dinheiro", pixRequested: false,
    cashTendered: 1, cashTenderedBRL: 9999,
  });
  await f.invoke("reserve");
  assert.equal(f.docs.get("orders/o1").financialValidationError,
      "PAGAMENTO_INSUFICIENTE");
  assert.equal(f.docs.get("products/p1").reservedStock, 0);
});

for (const [currency, amount] of [["BRL", 70.60], ["USD", 14.12],
  ["PYG", 105900]]) {
  test(`cash: accepts existing ${currency} conversion`, async () => {
    const f = fixture({
      paymentMethod: "Dinheiro", pixRequested: false,
      cashCurrency: currency, cashTendered: amount,
    });
    await f.invoke("reserve");
    assertFinancial(f.docs.get("orders/o1"));
    assert.equal(f.docs.get("products/p1").reservedStock, 3);
  });
}

const split = (amount) => ({
  paymentMethod: "Pagamento dividido", pixRequested: false,
  splitPayment: true, splitPaidBRL: 99999, splitRemainingBRL: 0,
  paymentParts: [
    {method: "Dinheiro", currency: "PYG", amountCurrency: 75000, amountBRL: 1},
    {method: "Dinheiro", currency: "USD", amountCurrency: amount, amountBRL: 1},
  ],
});

test("split: validates original currencies, ignores client conversions",
    async () => {
      const f = fixture(split(4.12));
      await f.invoke("reserve");
      assertFinancial(f.docs.get("orders/o1"));
      assert.equal(f.docs.get("products/p1").reservedStock, 3);
    });

test("split: rejects insufficient sum despite forged paid totals", async () => {
  const f = fixture(split(1));
  await f.invoke("reserve");
  assert.equal(f.docs.get("orders/o1").financialValidationError,
      "PAGAMENTO_INSUFICIENTE");
  assert.equal(f.docs.get("products/p1").reservedStock, 0);
});

test("rounding: rounds each percentage to cents", async () => {
  const f = fixture({itemsList: [{id: "p1", quantity: 1}]}, {priceBRL: 0.50});
  await f.invoke("auto");
  const data = f.docs.get("orders/o1");
  assert.equal(data.customerFee, 0.01);
  assert.equal(data.merchantFee, 0.02);
  assert.equal(data.merchantNet, 0.48);
  assert.equal(data.totalBRL, 10.51);
});

test("compatibility: official price fallback and duplicate items", async () => {
  const f = fixture({itemsList: [
    {id: "p1", quantity: 1, price: 999},
    {id: " p1 ", quantity: 2, price: 0.01},
  ]}, {priceBRL: null, price: 20});
  await f.invoke("auto");
  assertFinancial(f.docs.get("orders/o1"));
  assert.equal(f.docs.get("orderFinancials/o1").items.length, 1);
});

for (const product of [{priceBRL: -1}, {priceBRL: "20"},
  {priceBRL: 1.001}, {isActive: false}]) {
  test(`invalid official product: ${JSON.stringify(product)}`, async () => {
    const f = fixture({}, product);
    await f.invoke("auto");
    assert.equal(f.requests.length, 0);
    assert.equal(f.docs.get("orders/o1").financialValidationStatus, "rejected");
  });
}

test("missing product cannot produce a charge", async () => {
  const f = fixture();
  f.docs.delete("products/p1");
  await f.invoke("auto");
  assert.equal(f.requests.length, 0);
});

test("transaction retry reads the updated official price", async () => {
  const f = fixture({}, {}, {retry: (docs) => {
    docs.get("products/p1").priceBRL = 30;
  }});
  await f.invoke("auto");
  assert.equal(JSON.parse(f.requests[0].body).total_amount, "100.90");
});

test("webhook uses official amount even after client mirror is modified",
    async () => {
      const f = fixture();
      await f.invoke("auto");
      const order = f.docs.get("orders/o1");
      order.totalBRL = 1;
      order.mercadoPagoAmountBRL = 1;
      order.merchantNet = 999;
      await f.invoke("webhook");
      assert.equal(order.paymentStatus, "Pago");
      assertFinancial(order);
      assert.equal(f.docs.get("products/p1").stock, 17);
      await f.invoke("webhook");
      assert.equal(f.docs.get("products/p1").stock, 17);
    });

test("webhook rejects underpayment matching the forged client total",
    async () => {
      const f = fixture({}, {}, {mpAmount: "1.00"});
      await f.invoke("auto");
      const order = f.docs.get("orders/o1");
      order.totalBRL = 1;
      order.mercadoPagoAmountBRL = 1;
      await f.invoke("webhook");
      assert.notEqual(order.paymentStatus, "Pago");
      assert.equal(f.docs.get("products/p1").stock, 20);
    });

test("legacy webhook preserves an already issued amount", async () => {
  const f = fixture({
    mercadoPagoOrderId: "ORD1", mercadoPagoAmountBRL: 33, totalBRL: 33,
  }, {}, {mpAmount: "33.00"});
  await f.invoke("webhook");
  assert.equal(f.docs.get("orders/o1").paymentStatus, "Pago");
  assert.equal(f.docs.get("orders/o1").totalBRL, 33);
});

test("delivery completion restores frozen financial fields without repricing",
    async () => {
      const f = fixture({paymentMethod: "Dinheiro", pixRequested: false});
      await f.invoke("reserve");
      const order = f.docs.get("orders/o1");
      order.status = "Concluído";
      order.totalBRL = 1;
      f.docs.get("products/p1").priceBRL = 100;
      await f.invoke("resolve");
      assertFinancial(order);
      assert.equal(order.stockReservationStatus, "finalized");
      assert.equal(f.docs.get("products/p1").stock, 17);
      await f.invoke("resolve");
      assert.equal(f.docs.get("products/p1").stock, 17);
    });

test("legacy reserved order completes without a financial migration",
    async () => {
      const f = fixture({
        paymentMethod: "Dinheiro", pixRequested: false,
        stockReservationStatus: "reserved", status: "Concluído", totalBRL: 33,
      }, {reservedStock: 3});
      await f.invoke("resolve");
      assert.equal(f.docs.get("orders/o1").stockReservationStatus, "finalized");
      assert.equal(f.docs.get("orders/o1").totalBRL, 33);
    });

test("multiple official products contribute to the same subtotal", async () => {
  const f = fixture({itemsList: [
    {id: "p1", quantity: 2, price: 0},
    {id: "p2", quantity: 1, price: 999},
  ]});
  f.docs.set("products/p2", {
    priceBRL: 19.99, stock: 10, reservedStock: 0, salesCount: 0,
  });
  await f.invoke("auto");
  const data = f.docs.get("orders/o1");
  assert.equal(data.itemsTotal, 59.99);
  assert.equal(data.customerFee, 0.60);
  assert.equal(data.merchantFee, 1.80);
  assert.equal(data.totalBRL, 70.59);
});

for (const itemsList of [[], [{id: "p1", quantity: -1}],
  [{id: "p1", quantity: 1.5}], [{id: "p1", quantity: 0}]]) {
  test(`invalid quantities: ${JSON.stringify(itemsList)}`, async () => {
    const f = fixture({itemsList});
    await f.invoke("auto");
    assert.equal(f.requests.length, 0);
    assert.equal(f.docs.has("orderFinancials/o1"), false);
  });
}

test("legacy PIX without frozen amount does not trust totalBRL", async () => {
  const f = fixture({mercadoPagoOrderId: "ORD1", totalBRL: 70.60});
  await f.invoke("webhook");
  assert.notEqual(f.docs.get("orders/o1").paymentStatus, "Pago");
  assert.equal(f.docs.get("products/p1").stock, 20);
});

test("split rejects overflow in declared converted amounts", async () => {
  const f = fixture(split(1e308));
  await f.invoke("reserve");
  assert.equal(f.docs.get("orders/o1").financialValidationError,
      "VALOR_PAGAMENTO_INVALIDO");
  assert.equal(f.docs.get("products/p1").reservedStock, 0);
});

test("financial totals exceeding safe cent arithmetic cannot be charged",
    async () => {
      const f = fixture({
        itemsList: [{id: "p1", quantity: Number.MAX_SAFE_INTEGER}],
      });
      await f.invoke("auto");
      assert.equal(f.requests.length, 0);
    });
