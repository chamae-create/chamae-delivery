const {test} = require("node:test");
const {createHash} = require("node:crypto");
const assert = require("node:assert/strict");
const {input, reasons, createDeliveryContingency} = require("../delivery-contingency");
const {assertCompletion, assertReturnProof, needsReturnProof} = require("../delivery-contingency-state");
const request = (patch = {}) => ({auth: {uid: "operator", token: {roles: ["superadmin"]}}, data: {
  orderId: "o1", requestId: "incident-request-12345", action: "attempt",
  contingencyReason: "Tentativa operacional documentada", confirmation: "CONFIRMAR o1",
  expectedStatus: "Saiu para Entrega", expectedRevision: 0, reasonCode: "no_answer", ...patch}});

for (const reasonCode of reasons) {
  test(`bounded operational reason: ${reasonCode}`, () => {
    assert.equal(input(request({reasonCode})).data.reasonCode, reasonCode);
  });
}
test("incident rejects client payment, stock, timestamps and actor authority", () => {
  for (const key of ["paymentStatus", "stockAction", "createdAt", "actorUid", "fee", "phase"]) {
    assert.throws(() => input(request({[key]: "forged"})), {code: "invalid-argument"});
  }
  for (const patch of [{expectedRevision: -1}, {reasonCode: "anything"}, {requestId: "short"},
    {action: "return", reasonCode: null, returnCondition: "intact", returnAuthorized: false}]) {
    assert.throws(() => input(request(patch)));
  }
});
test("incident requires named superadmin and typed confirmation", () => {
  for (const auth of [null, {uid: "ops", token: {roles: ["operations_admin"]}},
    {uid: "anon", token: {roles: ["superadmin"], firebase: {sign_in_provider: "anonymous"}}}]) {
    assert.throws(() => input({...request(), auth}));
  }
  assert.throws(() => input(request({confirmation: "yes"})));
});
test("completion requires physical delivery, collection and exact incident version", () => {
  const data = {deliveryConfirmed: true, collectionConfirmed: true, expectedDeliveryRevision: 2};
  const order = {paymentStatus: "Pendente na entrega", deliveryIncidentStatus: "pending", deliveryIncidentRevision: 2};
  assert.doesNotThrow(() => assertCompletion(order, data));
  for (const patch of [{deliveryConfirmed: false}, {collectionConfirmed: false}, {expectedDeliveryRevision: 1}]) {
    assert.throws(() => assertCompletion(order, {...data, ...patch}));
  }
  assert.doesNotThrow(() => assertCompletion({...order, paymentStatus: "Pago"}, {...data, collectionConfirmed: false}));
  for (const phase of ["returned", "redelivery_pending", "unknown"]) {
    assert.throws(() => assertCompletion({...order, deliveryIncidentStatus: phase}, data));
  }
});
test("only current, intact, physically attested return authorizes full stock compensation", () => {
  const order = {deliveryIncidentRevision: 1};
  const record = {schemaVersion: 1, revision: 1, phase: "returned", returnCondition: "intact",
    returnAuthorized: true, returnedAt: "TEST_SERVER_TIMESTAMP", returnedBy: "operator"};
  assert.doesNotThrow(() => assertReturnProof(order, record));
  for (const patch of [{revision: 0}, {returnCondition: "partial"}, {returnCondition: "nonreturnable"},
    {returnAuthorized: false}, {returnedAt: null}, {returnedBy: null}, {phase: "pending"}]) {
    assert.throws(() => assertReturnProof(order, {...record, ...patch}));
  }
  assert.equal(needsReturnProof({status: "Saiu para Entrega"}), true);
  assert.equal(needsReturnProof({dispatchedAt: "timestamp"}), true);
  assert.equal(needsReturnProof({status: "Em Separação"}), false);
});
test("incident callable is private operations, correct region and no external secret", () => {
  const fn = createDeliveryContingency({}).chamaeRegistrarContingenciaEntrega;
  assert.deepEqual(fn.__endpoint.region, ["southamerica-east1"]);
  assert.deepEqual(fn.__endpoint.secretEnvironmentVariables || [], []);
});
test("pre-KB05 completion receipt remains a read-only replay, never a new legacy completion", async () => {
  const {moveOrder} = require("../order-operations");
  const old = request();
  old.data = {orderId: "o1", requestId: "old-completion-12345", contingencyReason: old.data.contingencyReason,
    confirmation: "CONFIRMAR o1"};
  const fingerprint = createHash("sha256").update(`complete:o1:${old.data.contingencyReason}`).digest("hex");
  let reads = 0;
  const db = {doc: (path) => ({path}), collection: () => ({doc: () => ({})}),
    runTransaction: (fn) => fn({get: () => {
      reads++; return {exists: true, data: () => ({fingerprint})};
    }})};
  assert.equal((await moveOrder(db, old, "complete")).replayed, true);
  assert.equal(reads, 1);
});
