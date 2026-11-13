const {test} = require("node:test");
const assert = require("node:assert/strict");
const {createHash} = require("node:crypto");
const {parseEvent, createCourierEventFunctions} = require("../courier-events");
const {createCourierPhotoFunctions} = require("../courier-photo");
function event(extra = {}) {
  const data = {protocolVersion: 2, eventId: "f03-event-000000001", orderId: "shift", courierUid: "rider",
    type: "availability", localTimestampMs: 1000, sequence: 1, payload: {on: true}, ...extra};
  const canonical = {...(data.assignmentId === undefined ? {} : {assignmentId: data.assignmentId}),
    protocolVersion: data.protocolVersion, eventId: data.eventId, orderId: data.orderId, courierUid: data.courierUid,
    type: data.type, localTimestampMs: data.localTimestampMs, sequence: data.sequence, payload: data.payload};
  return {...data, fingerprint: createHash("sha256").update(JSON.stringify(canonical)).digest("hex")};
}
test("v2 event fingerprint matches canonical client order without local sync flags", () => {
  const data = event(); assert.equal(parseEvent(data, "rider").fingerprint, data.fingerprint);
  const pickup = event({type: "pickupAction", orderId: "order", assignmentId: "binding", payload: {action: "accept"}});
  assert.equal(parseEvent(pickup, "rider").assignmentId, "binding");
});
test("foreign UID, altered bytes, arbitrary privilege or legacy protocol are rejected", () => {
  for (const patch of [{courierUid: "other"}, {fingerprint: "forged"}, {protocolVersion: 1}, {roles: ["superadmin"]},
    {syncStatus: "acked"}, {payload: {on: true, approved: true}}, {orderId: "../other"}]) {
    assert.throws(() => parseEvent({...event(), ...patch}, "rider"));
  }
});
test("synthetic PIN and demo delivery confirmations are never accepted by phase one", () => {
  for (const type of ["confirmDelivery", "pickedUp", "acceptDelivery", "startRoute", "reportProblem"]) {
    assert.throws(() => parseEvent(event({type, payload: {proof: {simulation: true}}}), "rider"),
        (error) => error.code === "invalid-argument" || error.details?.reason === "OPERATION_NOT_ENABLED");
  }
});
test("pickup action needs assignment and a strictly allowed payload", () => {
  for (const patch of [{assignmentId: ""}, {payload: {action: "confirmDelivery"}},
    {payload: {action: "accept", pin: "synthetic"}}, {payload: {action: "decline", reason: "x".repeat(241)}}]) {
    assert.throws(() => parseEvent(event({type: "pickupAction", orderId: "order", ...patch}), "rider"));
  }
});
test("new bridges keep regional callables with no secret dependency", () => {
  const handlers = {...createCourierEventFunctions({}), ...createCourierPhotoFunctions({})};
  assert.equal(Object.keys(handlers).length, 3);
  for (const fn of Object.values(handlers)) {
    assert.ok(fn.__endpoint.callableTrigger);
    assert.deepEqual(fn.__endpoint.region, ["southamerica-east1"]);
    assert.deepEqual(fn.__endpoint.secretEnvironmentVariables || [], []);
  }
});
