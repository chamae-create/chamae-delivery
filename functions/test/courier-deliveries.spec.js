const assert = require("node:assert/strict");
const {test} = require("node:test");
const {GeoPoint, Timestamp} = require("firebase-admin/firestore");
const {buildCourierDelivery, createCourierDeliveryTrigger} =
    require("../courier-deliveries");

const now = Timestamp.fromMillis(1700000000000);
const later = Timestamp.fromMillis(1700000060000);
const order = (overrides = {}) => ({
  id: "#CH-ID-AMIGAVEL", courierUid: "rider-a", courierName: "Nome legado",
  customerName: "Maria da Silva", status: "Em Separação",
  address: "Rua das Flores, 123", deliveryLocation: new GeoPoint(-22.5, -55.7),
  deliveryAddress: {
    addressText: "Rua das Flores, 123", complement: "Casa 2",
    reference: "Portão azul", latitude: -22.5, longitude: -55.7,
  },
  ...overrides,
});
const build = (data, previous = {}, time = now) =>
  buildCourierDelivery("document-id", data, previous, time);

for (const uid of [undefined, null, "", " ", 123, {}, [], "a/b", " a", "a ",
  ".", "..", "a\n", "a".repeat(129)]) {
  test(`no invented courier binding: ${JSON.stringify(uid)}`, () => {
    assert.equal(build(order({courierUid: uid})), null);
  });
}

test("allowlist uses document ID, name and explicit route fields", () => {
  const delivery = build(order());
  assert.deepEqual(Object.keys(delivery).sort(), [
    "orderId", "courierUid", "customerName", "address", "deliveryLocation",
    "status", "createdAt", "assignedAt", "complement", "reference",
  ].sort());
  assert.equal(delivery.orderId, "document-id");
  assert.equal(delivery.customerName, "Maria da Silva");
  assert.equal(delivery.address, "Rua das Flores, 123");
  assert.equal(delivery.complement, "Casa 2");
  assert.equal(delivery.reference, "Portão azul");
  assert.ok(delivery.deliveryLocation.isEqual(new GeoPoint(-22.5, -55.7)));
});

const privateFields = [
  "customerPhone", "phone", "whatsapp", "WhatsApp", "email", "customerEmail",
  "customerUid", "history", "customerHistory", "financials", "orderFinancials",
  "itemsList", "totalBRL", "cashTendered", "cashCurrency", "changeBRL",
  "paymentParts", "paymentMethod", "paymentStatus", "deliveryFee",
  "customerFee", "merchantFee", "merchantNet", "platformFee", "courierPaid",
  "mercadoPagoOrderId", "mercadoPagoPaymentId", "mercadoPagoIdempotencyKey",
  "mercadoPagoQrCode", "mercadoPagoQrCodeBase64", "secretFutureField",
];
for (const field of privateFields) {
  test(`never projects ${field}`, () => {
    const data = order({[field]: {private: "PRIVATE_SENTINEL"}});
    const before = JSON.stringify(data);
    const delivery = build(data);
    assert.ok(delivery);
    assert.equal(Object.hasOwn(delivery, field), false);
    assert.equal(JSON.stringify(delivery).includes("PRIVATE_SENTINEL"), false);
    assert.equal(JSON.stringify(data), before, "order must not be mutated");
  });
}

test("nested address metadata is not copied", () => {
  const data = order();
  for (const field of privateFields) {
    data.deliveryAddress[field] = "PRIVATE_SENTINEL";
  }
  assert.equal(JSON.stringify(build(data)).includes("PRIVATE_SENTINEL"), false);
});

for (const field of ["customerName", "address", "complement", "reference"]) {
  for (const value of ["Maria user@example.com", "WhatsApp: 67999990000",
    "Ligar (67) 99999-0000", "https://wa.me/5567999990000", {phone: "private"},
    "９９９９９-００００", "67\u200b999990000", "\u0000"]) {
    test(`contact or map in ${field} fails closed: ${JSON.stringify(value)}`,
        () => {
          const data = order();
          if (field === "customerName") {
            data.customerName = value;
          } else {
            data.deliveryAddress[field === "address" ? "addressText" :
              field] = value;
          }
          assert.equal(build(data), null);
        });
  }
}

for (const address of ["Rua A, 123, CEP 79900-000", "Av. Brasil, 1000",
  "Rua 13 de Maio, 45", "Rua 7, 12345"]) {
  test(`keeps legitimate address numbers: ${address}`, () => {
    const data = order();
    data.deliveryAddress.addressText = address;
    assert.equal(build(data).address, address);
  });
}

for (const status of ["Novo", "Em Separação", "Saiu para Entrega", "Concluído",
  "Cancelado"]) {
  test(`preserves operational status ${status}`, () => {
    assert.equal(build(order({status})).status, status);
  });
}

test("cancellation details are not exposed", () => {
  assert.equal(build(order({status: "Cancelado: informação privada"})).status,
      "Cancelado");
});

for (const status of ["Aguardando pagamento", "Revisão de estoque",
  "Revisão financeira", "user@example.com", null, {}, ""]) {
  test(`unknown or non-operational status is not published: ${status}`, () => {
    assert.equal(build(order({status})), null);
  });
}

test("numeric coordinates fallback does not copy its container", () => {
  const delivery = build(order({deliveryLocation: null}));
  assert.ok(delivery.deliveryLocation instanceof GeoPoint);
  assert.ok(delivery.deliveryLocation.isEqual(new GeoPoint(-22.5, -55.7)));
  const data = order({deliveryLocation: null});
  data.deliveryAddress.latitude = 0;
  data.deliveryAddress.longitude = 0;
  assert.ok(build(data).deliveryLocation.isEqual(new GeoPoint(0, 0)));
});

for (const latitude of [undefined, "-22.5", NaN, Infinity, 91]) {
  test(`invalid coordinates never produce a usable projection: ${latitude}`,
      () => {
        const data = order({deliveryLocation: null});
        data.deliveryAddress.latitude = latitude;
        assert.equal(build(data), null);
      });
}

test("re-execution preserves assignment and creation timestamps", () => {
  const first = build(order());
  assert.deepEqual(build(order(), first, later), first);
});

test("reassignment replaces UID, assignment time and previous pickup", () => {
  const previous = build(order({status: "Saiu para Entrega"}));
  const next = build(order({courierUid: "rider-b"}), previous, later);
  assert.equal(next.courierUid, "rider-b");
  assert.ok(next.assignedAt.isEqual(later));
  assert.ok(next.createdAt.isEqual(now));
  assert.equal(Object.hasOwn(next, "pickedUpAt"), false);
});

test("completion remains consistent on duplicate execution", () => {
  const picked = build(order({status: "Saiu para Entrega"}));
  const completed = build(order({status: "Concluído"}), picked, later);
  assert.equal(completed.status, "Concluído");
  assert.ok(completed.completedAt.isEqual(later));
  assert.ok(completed.pickedUpAt.isEqual(now));
  assert.deepEqual(build(order({status: "Concluído"}), completed,
      Timestamp.fromMillis(1800000000000)), completed);
});

test("trigger subscribes to all order writes, retries, without secrets", () => {
  const trigger = createCourierDeliveryTrigger({});
  assert.equal(trigger.__endpoint.platform, "gcfv2");
  assert.equal(trigger.__endpoint.eventTrigger.eventType,
      "google.cloud.firestore.document.v1.written");
  assert.equal(trigger.__endpoint.eventTrigger.retry, true);
  assert.equal(trigger.__endpoint.eventTrigger.eventFilterPathPatterns.document,
      "orders/{orderId}");
  assert.deepEqual(trigger.__endpoint.secretEnvironmentVariables || [], []);
});
