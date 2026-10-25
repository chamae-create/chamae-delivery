const {test} = require("node:test");
const assert = require("node:assert/strict");
const {closedOrder, requestClosure, createCustomerAccountFunctions} = require("../customer-account");

const request = () => ({auth: {uid: "buyer", token: {
  firebase: {sign_in_provider: "google.com"}, auth_time: Date.now() / 1000,
}}, data: {confirmation: "EXCLUIR MINHA CONTA", expectedUid: "buyer", requestId: "test-request-0001"}});

test("closed-order preflight denies pending payments, unknown states and stock review", () => {
  const done = {status: "Concluído", paymentStatus: "Pago"};
  assert.equal(closedOrder(done), true);
  assert.equal(closedOrder({status: "Cancelado"}), true);
  for (const extra of [{status: "Novo"}, {status: "unknown"}, {paymentStatus: "Pendente"},
    {stockReservationStatus: "reserved"}, {stockReservationStatus: "error"},
    {stockProcessingStatus: "processing"}, {stockProcessingStatus: "requires_review"}]) {
    assert.equal(closedOrder({...done, ...extra}), false, JSON.stringify(extra));
  }
  for (const extra of [{mercadoPagoCreateStatus: "creating"}, {mercadoPagoOrderId: "issued"},
    {mercadoPagoQrCode: "issued", mercadoPagoStatus: "approved"}]) {
    assert.equal(closedOrder({status: "Cancelado", ...extra}), false);
  }
  assert.equal(closedOrder({status: "Cancelado", mercadoPagoOrderId: "issued",
    mercadoPagoStatus: "expired"}), true);
});

test("identity and payload validation reject foreign UIDs and privileged/anonymous accounts before IO", async () => {
  const db = {collection: () => assert.fail("must not read before validation")};
  for (const auth of [null, {uid: "buyer"}, {uid: "a/b", token: request().auth.token},
    {uid: "buyer", token: {firebase: {sign_in_provider: "anonymous"}}},
    {uid: "buyer", token: {...request().auth.token, roles: ["superadmin"]}},
    {uid: "buyer", token: {...request().auth.token, roles: "finance"}}]) {
    await assert.rejects(requestClosure(db, {...request(), auth}), {code: "permission-denied"});
  }
  for (const data of [null, [], {...request().data, expectedUid: "other"},
    {...request().data, uid: "other"}, {...request().data, confirmation: "yes"},
    {...request().data, requestId: 123}, {...request().data, requestId: "short"}]) {
    await assert.rejects(requestClosure(db, {...request(), data}), {code: "invalid-argument"});
  }
});

test("registered worker is durable, retries and ignores its own processing/completion writes", async () => {
  const handlers = createCustomerAccountFunctions({});
  const worker = handlers.chamaeProcessarExclusaoConta;
  assert.equal(worker.__endpoint.eventTrigger.retry, true);
  for (const status of ["processing", "completed", "blocked"]) {
    await worker.run({data: {after: {data: () => ({status})}}, params: {uid: "buyer"}});
  }
});
