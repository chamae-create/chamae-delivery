const assert = require("node:assert/strict");
const {test} = require("node:test");
const {profileInput, createCourierApprovalFunctions} = require("../courier-approval");
const {isApprovedCourierProfile, requireApprovedCourier,
  requireCourierAdministrator} = require("../courier-authorization");
const valid = {profilePhoto: "fixture-selfie", name: "Ana Exemplo", phone: "67900000000", city: "Ponta Pora",
  vehicleType: "motorcycle"};
const denied = (code) => (error) => error.code === code;
for (const status of [undefined, null, "pendingApproval", "rejected", "suspended", "APPROVED", true]) {
  test(`guard denies status ${status} even with legacy active flags`, () => {
    assert.equal(isApprovedCourierProfile({role: "courier", approvalStatus: status, administrativeState: "active",
      enabled: true}),
    false);
  });
}
for (const patch of [{administrativeState: "blocked"}, {enabled: false}, {active: false}, {isActive: false}]) {
  test(`approval does not bypass legacy block ${JSON.stringify(patch)}`, () => {
    assert.equal(isApprovedCourierProfile({role: "courier", approvalStatus: "approved", administrativeState: "active",
      ...patch}),
    false);
  });
}
for (const key of ["approvalStatus", "approvedBy", "approvedAt", "rejectedBy", "rejectedAt", "rejectionReason",
  "suspendedBy", "suspendedAt", "suspensionReason", "enabled", "courierUid", "uid", "roles"]) {
  test(`registration and profile updates reject client-controlled ${key}`, () => {
    for (const partial of [false, true]) {
      assert.throws(() => profileInput({...valid, [key]: "forged"}, partial),
          denied("invalid-argument"));
    }
  });
}
for (const patch of [{phone: "x"}, {name: ""}, {profilePhoto: ""}, {vehicleType: "unknown"},
  {vehicleDescription: "x".repeat(161)}, {name: "x\nname"}]) {
  test(`invalid profile rejected ${JSON.stringify(patch)}`, () => {
    assert.throws(() => profileInput({...valid, ...patch}), denied("invalid-argument"));
  });
}
for (const roles of [undefined, [], ["courier"], ["operations_admin"], ["finance"], ["catalog_admin"], "superadmin"]) {
  test(`ordinary/nonprivileged account cannot review ${JSON.stringify(roles)}`, () => {
    assert.throws(() => requireCourierAdministrator({auth: {uid: "user", token: {roles}}}),
        denied("permission-denied"));
  });
}
test("guard requires named authenticated identity before any database read", async () => {
  const db = {collection: () => assert.fail("unexpected read")};
  for (const auth of [null, undefined, {uid: "user", token: {firebase: {sign_in_provider: "anonymous"}}}]) {
    await assert.rejects(requireApprovedCourier(db, {auth}), denied("unauthenticated"));
  }
});
test("guard reads stored approval instead of a client boolean", async () => {
  for (const exists of [false, true]) {
    const db = {collection: (name) => ({doc: (uid) => ({get: async () => ({
      exists: name === "couriers" && exists,
      data: () => ({approvalStatus: "pendingApproval", administrativeState: "active", enabled: true}),
    })})})};
    await assert.rejects(requireApprovedCourier(db, {auth: {uid: "rider", token: {}},
      data: {approved: true}}), denied("permission-denied"));
  }
});
test("callables stay in the existing region and declare no secrets", () => {
  const functions = createCourierApprovalFunctions({});
  assert.equal(Object.keys(functions).length, 5);
  for (const fn of Object.values(functions)) {
    assert.deepEqual(fn.__endpoint.region, ["southamerica-east1"]);
    assert.ok(fn.__endpoint.callableTrigger);
    assert.deepEqual(fn.__endpoint.secretEnvironmentVariables || [], []);
  }
});
