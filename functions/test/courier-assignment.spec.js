const assert = require("node:assert/strict");
const {test} = require("node:test");
const {authorize, changeCourier, listCouriers, readyForDispatch,
  createCourierAssignmentFunctions} = require("../courier-assignment");
const {isAssignableCourier} = require("../courier-deliveries");

for (const roles of [undefined, [], ["customer"],
  ["finance"], ["catalog_admin"],
  "operations_admin", {operations_admin: true}]) {
  test(`assignment/list reject roles ${JSON.stringify(roles)} before reads`,
      async () => {
        const db = {collection: () => assert.fail("unauthorized read")};
        const request = {auth: {uid: "actor", token: {roles}}, data: {}};
        for (const method of [changeCourier, listCouriers]) {
          await assert.rejects(method(db, request),
              (error) => error.code === "permission-denied");
        }
      });
}
for (const auth of [undefined, null, {uid: "actor", token: {
  roles: ["superadmin"], firebase: {sign_in_provider: "anonymous"},
}}]) {
  test(`reject missing/anonymous Auth: ${JSON.stringify(auth)}`, () => {
    assert.throws(() => authorize({auth}),
        (error) => error.code === "unauthenticated");
  });
}
for (const role of ["operations_admin", "superadmin"]) {
  test(`allows ${role}`, () => {
    assert.equal(authorize({auth: {uid: "actor", token: {roles: [role]}}}),
        "actor");
  });
}
for (const profile of [{name: "Nome"},
  {name: "Nome", administrativeState: "suspended"},
  {name: "Nome", administrativeState: "blocked"},
  {name: "Nome", administrativeState: "active", enabled: false},
  {name: "Nome", administrativeState: "active", isActive: false},
  {name: "", administrativeState: "active"}]) {
  test(`profile is not assignable: ${JSON.stringify(profile)}`, () => {
    assert.equal(isAssignableCourier(profile), false);
  });
}
test("explicit active profile is assignable", () => {
  assert.equal(isAssignableCourier({
    name: "Nome", administrativeState: "active",
  }),
  true);
});

const ready = {customerUid: "buyer", financialValidationStatus: "validated",
  paymentMethod: "PIX", paymentStatus: "Pago",
  stockProcessingStatus: "processed"};
test("dispatch preserves payment and stock readiness requirements", () => {
  assert.equal(readyForDispatch(ready), true);
  for (const patch of [{paymentStatus: "Pendente"},
    {stockProcessingStatus: "pending"}, {financialValidationStatus: "rejected"},
    {stockProcessingError: "error"}, {stockReservationStatus: "released"},
    {stockReservationError: "error"}]) {
    assert.equal(readyForDispatch({...ready, ...patch}), false);
  }
  assert.equal(readyForDispatch({}), false, "unvalidated legacy blocked");
  assert.equal(readyForDispatch({...ready, paymentMethod: "Dinheiro",
    stockReservationRequired: true, stockReservationStatus: "pending"}), false);
});

test("callables are registered in the panel region without secrets", () => {
  const functions = createCourierAssignmentFunctions({});
  assert.deepEqual(Object.keys(functions).sort(), ["chamaeAtribuirMotoboy",
    "chamaeDespacharPedido", "chamaeListarMotoboysAtribuiveis"].sort());
  for (const fn of Object.values(functions)) {
    assert.ok(fn.__endpoint.callableTrigger);
    assert.deepEqual(fn.__endpoint.region, ["southamerica-east1"]);
    assert.deepEqual(fn.__endpoint.secretEnvironmentVariables || [], []);
  }
});
