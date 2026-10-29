const {test} = require("node:test");
const assert = require("node:assert/strict");
const {ownRequest, terminal, publicClosure} = require("../courier-account");
const {isApprovedCourierProfile} = require("../courier-authorization");
const {Timestamp} = require("firebase-admin/firestore");
const current = 1793203200000;
const request = (uid = "courier-a", extra = {}) => ({auth: {uid,
  token: {auth_time: current / 1000, firebase: {sign_in_provider: "password"}, ...extra}}});
test("closure requires named identity and recent reauthentication without privilege escalation", () => {
  assert.equal(ownRequest(request(), true, current), "courier-a");
  for (const input of [{}, request("../other"), request("courier-a", {firebase: {sign_in_provider: "anonymous"}})]) {
    assert.throws(() => ownRequest(input, true, current));
  }
  for (const claims of [{roles: ["superadmin"]}, {role: "admin"}, {admin: true}, {roles: "courier"}]) {
    assert.throws(() => ownRequest(request("courier-a", claims), true, current), {code: "permission-denied"});
  }
  assert.throws(() => ownRequest(request("courier-a", {auth_time: current / 1000 - 301}), true, current),
      (error) => error.details.reason === "REAUTH_REQUIRED");
});
test("unknown order status remains an operational hold", () => {
  for (const status of ["Novo", "Saiu para Entrega", "delivered", undefined]) assert.equal(terminal({status}), false);
  for (const status of ["Concluído", "Cancelado"]) assert.equal(terminal({status}), true);
});
test("closing or closed courier is never assignable even with stale approved flags", () => {
  const profile = {role: "courier", approvalStatus: "approved", administrativeState: "active", enabled: true};
  assert.equal(isApprovedCourierProfile(profile), true);
  for (const status of ["requested", "processing", "awaiting_operation", "completed", "provider_review_required"]) {
    assert.equal(isApprovedCourierProfile({...profile, accountClosureStatus: status}), false);
  }
});
test("public protocol contains no profile, credential, raw exception or internal lease", () => {
  const job = {protocol: "synthetic", status: "requested", requestedAt: Timestamp.fromMillis(current),
    reviewDueAt: Timestamp.fromMillis(current + 86400000), password: "fixture-secret", name: "Private Name",
    leaseOwner: "private-lease", lastFailureCode: "RETRY_REQUIRED", pendingEventIds: []};
  const result = publicClosure("courier-a", job);
  assert.equal(result.protocol, "synthetic");
  for (const value of ["fixture-secret", "Private Name", "private-lease", "password", "lastFailureCode"]) {
    assert.equal(JSON.stringify(result).includes(value), false);
  }
});

test("F02 handlers have independent registration, local region and durable retries", () => {
  const handlers = require("../courier-account").createCourierAccountFunctions({});
  assert.equal(Object.keys(handlers).length, 6);
  for (const name of ["chamaeSolicitarExclusaoMotoboy", "chamaeStatusExclusaoMotoboy",
    "chamaeResolverExclusaoMotoboy", "chamaeListarExclusoesMotoboy"]) {
    assert.ok(handlers[name].__endpoint.callableTrigger);
    assert.deepEqual(handlers[name].__endpoint.region, ["southamerica-east1"]);
    assert.deepEqual(handlers[name].__endpoint.secretEnvironmentVariables || [], []);
  }
  assert.equal(handlers.chamaeProcessarExclusaoMotoboy.__endpoint.eventTrigger.retry, true);
  assert.ok(handlers.chamaeRetomarExclusoesMotoboy.__endpoint.scheduleTrigger);
});
