const assert = require("node:assert/strict");
const {test} = require("node:test");
const {
  buildOrderStatusNotification,
  collectCustomerTokens,
  registerCustomerPushToken,
  notifyOrderStatusChange,
} = require("../customer-push-notifications");

test("buildOrderStatusNotification maps tracked stages accurately", () => {
  const sep = buildOrderStatusNotification("Em Separação", "abc123456", "#CH-ABC12345");
  assert.equal(sep.key, "separacao");
  assert.match(sep.title, /#CH-ABC12345/);

  const route = buildOrderStatusNotification("Saiu para Entrega", "abc", "#CH-01");
  assert.equal(route.key, "saiu_para_entrega");

  const done = buildOrderStatusNotification("Concluído", "abc", "#CH-01");
  assert.equal(done.key, "entregue");

  const deliveredAlias = buildOrderStatusNotification("Entregue", "abc", "#CH-01");
  assert.equal(deliveredAlias.key, "entregue");

  const cancelled = buildOrderStatusNotification("Cancelado", "abc", "#CH-01");
  assert.equal(cancelled.key, "cancelado");

  assert.equal(buildOrderStatusNotification("Novo", "abc", "#CH-01"), null);
});

test("collectCustomerTokens deduplicates single token and token arrays", () => {
  const tokens = collectCustomerTokens([
    {fcmToken: "t1", fcmTokens: ["t1", "t2", " "]},
    {fcmToken: "t2", fcmTokens: ["t3"]},
  ]);
  assert.deepEqual(tokens, ["t1", "t2", "t3"]);
});

test("registerCustomerPushToken rejects unauthenticated or anonymous callers", async () => {
  await assert.rejects(
      registerCustomerPushToken({}, {auth: null, data: {token: "x".repeat(32), platform: "ios"}}),
      (err) => err.code === "unauthenticated");
  await assert.rejects(
      registerCustomerPushToken({}, {
        auth: {uid: "u1", token: {firebase: {sign_in_provider: "anonymous"}}},
        data: {token: "x".repeat(32), platform: "ios"},
      }),
      (err) => err.code === "unauthenticated");
});

test("notifyOrderStatusChange skips unchanged status and sends for Em Separação", async () => {
  const noop = await notifyOrderStatusChange({}, {
    params: {orderId: "o1"},
    data: {
      before: {exists: true, data: () => ({status: "Novo", customerUid: "u1"})},
      after: {exists: true, id: "o1", data: () => ({status: "Novo", customerUid: "u1"})},
    },
  });
  assert.equal(noop.reason, "status_unchanged");

  const sentPayloads = [];
  const fakeDb = {
    collection: () => ({
      doc: (uid) => ({
        get: async () => ({exists: true, data: () => ({fcmToken: `token-${uid}-1234567890`})}),
        set: async () => {},
      }),
    }),
  };
  const fakeMessaging = {
    sendEachForMulticast: async (payload) => {
      sentPayloads.push(payload);
      return {successCount: 1, failureCount: 0, responses: [{success: true}]};
    },
  };

  const res = await notifyOrderStatusChange(fakeDb, {
    params: {orderId: "zoSJeyNHrpUH46SABIaI"},
    data: {
      before: {exists: true, data: () => ({status: "Novo", customerUid: "cust1"})},
      after: {exists: true, id: "zoSJeyNHrpUH46SABIaI", data: () => ({status: "Em Separação", id: "#CH-ZOSJEYNH", customerUid: "cust1"})},
    },
  }, fakeMessaging);

  assert.equal(res.sent, 1);
  assert.equal(sentPayloads.length, 1);
  assert.match(sentPayloads[0].notification.title, /#CH-ZOSJEYNH/);
  assert.equal(sentPayloads[0].data.stage, "separacao");
});
