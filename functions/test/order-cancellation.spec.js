const {test} = require("node:test");
const assert = require("node:assert/strict");
const {input, inventoryState, itemsFor, cancelFromProvider} = require("../order-cancellation");
const {assertPurchasable, financialCompensation} = require("../order-cancellation-state");
const request = (extra = {}) => ({auth: {uid: "operator", token: {roles: ["superadmin"],
  firebase: {sign_in_provider: "password"}}}, data: {orderId: "order1", requestId: "request-1234567890",
  reason: "Motivo operacional de teste", confirmation: "CANCELAR order1", ...extra}});

test("cancellation authority never comes from client flags or arbitrary state/amount", () => {
  assert.equal(input(request(), "cancel").actorUid, "operator");
  for (const key of ["refundStatus", "paymentStatus", "release", "restock", "amount", "actorUid", "stockState"]) {
    assert.throws(() => input(request({[key]: "forged"}), "cancel"), {code: "invalid-argument"});
  }
  for (const auth of [null, {uid: "customer", token: {roles: []}},
    {uid: "operator", token: {roles: ["superadmin"], firebase: {sign_in_provider: "anonymous"}}}]) {
    assert.throws(() => input({...request(), auth}, "cancel"));
  }
});
test("reason, confirmation, request ID and full-return authorization are mandatory", () => {
  for (const extra of [{orderId: "a/b"}, {requestId: "short"}, {reason: "short"}, {confirmation: "yes"}]) {
    assert.throws(() => input(request(extra), "cancel"));
  }
  assert.throws(() => input({...request({confirmation: "DEVOLVER order1"}),
    auth: {uid: "ops", token: {roles: ["operations_admin"]}}}, "restock"));
  assert.equal(input(request({confirmation: "DEVOLVER order1"}), "restock").privileged, true);
});
test("only backend-proven local reservation/commit can be compensated", () => {
  assert.equal(inventoryState({}), "pending");
  assert.equal(inventoryState({stockReservationStatus: "released"}), "released");
  assert.equal(inventoryState({stockReservationStatus: "reserved", stockReservedBy: "firestore_order_trigger"}),
      "reserved");
  assert.equal(inventoryState({stockReservationStatus: "finalized", stockProcessed: true,
    stockProcessedBy: "stock_reservation_finalizer"}), "committed");
  assert.equal(inventoryState({stockProcessingStatus: "processed", stockProcessed: true,
    stockProcessedBy: "mercado_pago_webhook"}), "committed");
  for (const value of [{stockReservationStatus: "committed"}, {stockReservationStatus: "reserved"},
    {stockReservationStatus: "requires_review"}, {stockReservationStatus: "reserved", stockProcessed: true}]) {
    assert.throws(() => inventoryState(value));
  }
});
test("new purchases cannot reopen cancelled/completed/paid orders", () => {
  for (const value of [{status: "Cancelado"}, {cancellationStatus: "cancelled"},
    {status: "Concluído"}, {paymentStatus: "Pago"}]) assert.throws(() => assertPurchasable(value));
});
test("frozen official quantities, not client return quantities, define compensation", () => {
  assert.deepEqual(itemsFor({itemsList: [{id: "fake", quantity: 100}]}, {items: [{id: "p1", quantity: 2}]}),
      [{id: "p1", quantity: 2}]);
  for (const items of [[], [{id: "p", quantity: -1}], [{id: "p", quantity: 1.5}], [{id: "a/b", quantity: 1}]]) {
    assert.throws(() => itemsFor({itemsList: items}, null));
  }
});
test("refund need never means refund confirmed; unknown POST outcome still requires verification", () => {
  for (const method of ["PIX", "Dinheiro", "Maquininha"]) {
    const value = financialCompensation({paymentMethod: method, paymentStatus: "Pago"},
        {merchantFee: 3, totalBRL: 100});
    assert.equal(value.refundStatus, "required"); assert.equal(value.originalMerchantFee, 3);
    assert.notEqual(value.refundStatus, "confirmed");
  }
  assert.equal(financialCompensation({paymentMethod: "PIX", mercadoPagoCreateStatus: "error"}, null)
      .refundStatus, "verification_required");
  assert.equal(financialCompensation({paymentMethod: "Dinheiro", paymentStatus: "Pendente na entrega"}, null)
      .refundStatus, "not_required");
});

test("pending provider status is never enough to cancel an order", async () => {
  await assert.rejects(cancelFromProvider({}, "order", {status: "action_required", detail: "waiting_transfer"}, {}),
      (error) => error.details.reason === "PROVIDER_TERMINAL_UNCONFIRMED");
});
