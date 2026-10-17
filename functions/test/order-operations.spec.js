const assert = require("node:assert/strict");
const {test} = require("node:test");
const {moveOrder, settleCourier, authorizeSettlement, cents,
  createOrderOperations} = require("../order-operations");

for (const roles of [undefined, [], ["catalog_admin"], ["customer"],
  "superadmin", {superadmin: true}]) {
  test(`settlement rejects roles ${JSON.stringify(roles)} before data access`,
      async () => {
        await assert.rejects(settleCourier({}, {
          auth: {uid: "actor", token: {roles}}, data: {},
        }), (error) => error.code === "permission-denied");
      });
}
for (const auth of [null, undefined, {uid: "anon", token: {
  roles: ["superadmin", "finance"],
  firebase: {sign_in_provider: "anonymous"}}}]) {
  test(`all new writes reject absent/anonymous Auth ${JSON.stringify(auth)}`,
      async () => {
        for (const action of [
          () => moveOrder({}, {auth}, "complete"),
          () => moveOrder({}, {auth}, "separate"),
          () => settleCourier({}, {auth}),
        ]) {
          await assert.rejects(action,
              (error) => error.code === "unauthenticated");
        }
      });
}
for (const role of ["finance", "operations_admin", "superadmin"]) {
  test(`${role} explicitly authorized for cashier`, () => {
    assert.equal(authorizeSettlement({auth: {
      uid: "cashier", token: {roles: [role]}}}), "cashier");
  });
}
for (const role of ["finance", "catalog_admin", "customer"]) {
  test(`${role} cannot complete/separate`, async () => {
    await assert.rejects(moveOrder({}, {auth: {
      uid: "user", token: {roles: [role]}}}, "complete"),
    (error) => error.code === "permission-denied");
  });
}
for (const value of [-1, NaN, Infinity, "10", null, 0.001,
  Number.MAX_SAFE_INTEGER]) {
  test(`invalid official money rejected: ${value}`, () => {
    assert.throws(() => cents(value),
        (error) => error.code === "failed-precondition");
  });
}
test("official cents preserve existing fee, including zero", () => {
  assert.equal(cents(7.50), 750);
  assert.equal(cents(0), 0);
});
test("new callables use correct region and no secrets", () => {
  const functions = createOrderOperations({}, {});
  assert.deepEqual(Object.keys(functions).sort(), ["chamaeIniciarSeparacao",
    "chamaeConcluirEntrega", "chamaeRegistrarAcertoMotoboy"].sort());
  for (const fn of Object.values(functions)) {
    assert.ok(fn.__endpoint.callableTrigger);
    assert.deepEqual(fn.__endpoint.region, ["southamerica-east1"]);
    assert.deepEqual(fn.__endpoint.secretEnvironmentVariables || [], []);
  }
});

for (const patch of [
  {total: 0.01}, {courierName: "Forged"}, {orderDocumentIds: []},
  {orderDocumentIds: ["a", "a"]}, {orderDocumentIds: ["a/b"]},
  {orderDocumentIds: Array.from({length: 401}, (_, i) => String(i))},
  {requestId: "short"},
]) {
  test("invalid settlement input rejected before any reads: " +
      JSON.stringify(Object.keys(patch)), async () => {
    await assert.rejects(settleCourier({}, {auth: {
      uid: "cashier", token: {roles: ["finance"]}},
    data: {orderDocumentIds: ["a"], requestId: "valid-request-key", ...patch}}),
    (error) => error.code === "invalid-argument");
  });
}
