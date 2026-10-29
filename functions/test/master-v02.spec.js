const {test} = require("node:test");
const assert = require("node:assert/strict");
const {formatOrderId, validDisplayOrderId} = require("../operational-order-id");
const {pickupAction, createPickupLifecycleFunctions} = require("../courier-pickup-lifecycle");
for (const [number, label] of [[1, "V8-0001"], [4827, "V8-4827"], [9999, "V8-9999"], [10000, "V8-10000"]]) {
  test(`official sequential formatting ${label}`, () => {
    assert.equal(formatOrderId(number), label); assert.equal(validDisplayOrderId(label), true);
  });
}
for (const number of [-1, 0, 1.5, Number.MAX_SAFE_INTEGER + 1, "1"]) {
  test(`invalid sequence ${number}`, () => assert.throws(() => formatOrderId(number)));
}
test("public code without authentication fails before data access", async () => {
  await assert.rejects(pickupAction({runTransaction: (body) => body({})}, {data: {orderId: "V8-4827",
    assignmentId: "assignment", requestId: "request-public-code"}}, "accept"),
  (e) => e.code === "unauthenticated");
});
test("pickup callables have protected regional endpoints and no secrets", () => {
  const endpoints = createPickupLifecycleFunctions({}); assert.equal(Object.keys(endpoints).length, 8);
  for (const fn of Object.values(endpoints)) {
    assert.ok(fn.__endpoint.callableTrigger); assert.deepEqual(fn.__endpoint.region, ["southamerica-east1"]);
  }
});
