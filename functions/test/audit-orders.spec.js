const assert = require("node:assert/strict");
const {test} = require("node:test");
const {Timestamp} = require("firebase-admin/firestore");
const {auditOrders, auditReasons, diagnose, optionsFrom, FIELDS} =
    require("../scripts/audit-orders");

const official = {itemsTotal: 20, deliveryFee: 10, customerFee: 0.2,
  merchantFee: 1.6, merchantNet: 18.4, platformFee: 1.8, totalBRL: 30.2};
const order = () => Object.assign({}, official, {id: "test-order",
  customerUid: "buyer", financialValidationStatus: "validated",
  itemsList: [{id: "product", quantity: 1}], status: "Novo",
  createdAt: Timestamp.now()});
const codes = (data, finance = official) =>
  auditReasons(data, finance).map((reason) => reason.code);

test("unassigned new order is compatible; missing UID is only observed", () => {
  const reasons = auditReasons(order(), official);
  assert.deepEqual(reasons, [{code: "missingCourierUid", blocking: false}]);
});

test("separates missing status, unconfirmed finance and absent official record",
    () => {
      const data = order();
      delete data.financialValidationStatus;
      const result = codes(data, null);
      for (const code of ["missingFinancialValidationStatus",
        "unconfirmedFinancialValidation", "missingOfficialFinance"]) {
        assert.ok(result.includes(code));
      }
    });

test("does not approve forged mirrors or incomplete financial records", () => {
  assert.ok(codes(Object.assign(order(), {deliveryFee: 0}))
      .includes("divergentOfficialAmounts"));
  assert.ok(codes(order(), {}).includes("invalidOrMissingOfficialAmounts"));
});

test("dispatched/completed orders require operational UID and timestamps",
    () => {
      const data = Object.assign(order(), {status: "Concluído"});
      const result = auditReasons(data, official);
      assert.ok(result.find((reason) =>
        reason.code === "missingCourierUid" && reason.blocking));
      for (const code of ["missingOrInvalidCourierAssignedAt",
        "missingOrInvalidDispatchedAt", "missingOrInvalidCompletedAt",
        "completedPaymentUnconfirmed", "completedStockUnconfirmed"]) {
        assert.ok(codes(data).includes(code));
      }
    });

test("malformed identity and backend review are reported, never repaired",
    () => {
      const data = Object.assign(order(), {customerUid: "bad/path",
        courierUid: "bad/path", stockReservationStatus: "requires_review"});
      const before = JSON.stringify(data);
      for (const code of ["invalidCustomerUid", "invalidCourierUid",
        "backendReviewRequired"]) assert.ok(codes(data).includes(code));
      assert.equal(JSON.stringify(data), before);
    });

test("complete order with canonical stock/payment contract is compatible",
    () => {
      const data = Object.assign(order(), {courierUid: "rider",
        status: "Concluído", courierAssignedAt: Timestamp.now(),
        dispatchedAt: Timestamp.now(), completedAt: Timestamp.now(),
        paymentStatus: "Pago", stockReservationStatus: "finalized"});
      assert.deepEqual(auditReasons(data, official), []);
    });

/** Read-only fixture deliberately exposes no mutation methods.
 * @return {Object} Fake database and observed reads.
 */
function fixture() {
  const rows = [
    {id: "a", data: () => Object.assign(order(), {customerPhone: "PRIVATE",
      customerName: "PRIVATE", email: "PRIVATE", address: "PRIVATE"})},
    {id: "b", data: () => Object.assign(order(), {customerUid: null})},
  ];
  let index = 0;
  const masks = [];
  const cursors = [];
  const query = {
    orderBy: () => query,
    select: (...fields) => {
      assert.deepEqual(fields, FIELDS);
      return query;
    },
    limit: (limit) => {
      assert.equal(limit, 200);
      return query;
    },
    startAfter: (cursor) => {
      cursors.push(cursor.id);
      return query;
    },
    get: async () => {
      const docs = index < rows.length ? [rows[index++]] : [];
      return {docs, size: docs.length, empty: docs.length === 0};
    },
  };
  const db = {
    collection: (name) => {
      assert.equal(name, "orders");
      return query;
    },
    doc: (path) => ({path}),
    getAll: async (...args) => {
      const options = args.pop();
      masks.push(options.fieldMask);
      assert.ok(args.every((ref) => ref.path.startsWith("orderFinancials/")));
      return args.map(() => ({exists: true, data: () => official}));
    },
  };
  return {db, cursors, masks};
}

test("paginates and counts each document once; default output is aggregated",
    async () => {
      const f = fixture();
      const report = await auditOrders(f.db);
      assert.equal(report.complete, true);
      assert.equal(report.readOnly, true);
      assert.equal(report.total, 2);
      assert.equal(report.compatible, 1);
      assert.equal(report.legacy, 1);
      assert.equal(report.reasons.missingCourierUid.count, 2);
      assert.equal(report.reasons.missingCourierUid.blockingCount, 0);
      assert.equal(report.reasons.missingCustomerUid.count, 1);
      assert.deepEqual(f.cursors, ["a", "b"]);
      assert.equal(f.masks.length, 2);
      assert.equal(JSON.stringify(report).includes("PRIVATE"), false);
      assert.ok(Object.values(report.reasons).every((reason) =>
        !Object.hasOwn(reason, "documentIds")));
      const forbidden = ["customerPhone", "customerName", "address", "email"];
      for (const field of forbidden) {
        assert.ok(!FIELDS.includes(field));
      }
    });

test("document IDs require explicit internal report option", async () => {
  const report = await auditOrders(fixture().db, {includeIds: true});
  assert.deepEqual(report.reasons.missingCustomerUid.documentIds, ["b"]);
});

test("read failure never produces a complete report", async () => {
  const f = fixture();
  f.db.getAll = async () => {
    throw Object.assign(new Error("PRIVATE"), {code: 7});
  };
  await assert.rejects(auditOrders(f.db), {code: 7});
});

test("CLI refuses wrong project, emulator, write modes and credential args",
    () => {
      assert.deepEqual(optionsFrom(["--project", "chamae-delivery"], {}),
          {includeIds: false});
      assert.deepEqual(optionsFrom(["--project", "chamae-delivery",
        "--include-ids"], {}), {includeIds: true});
      for (const args of [[], ["--project", "other-project"],
        ["--project", "chamae-delivery", "--backfill"],
        ["--project", "chamae-delivery", "--token", "PRIVATE"]]) {
        assert.throws(() => optionsFrom(args, {}), {code: "INVALID_ARGUMENT"});
      }
      assert.throws(() => optionsFrom(["--project", "chamae-delivery"],
          {FIRESTORE_EMULATOR_HOST: "localhost:8187"}),
      {code: "INVALID_ARGUMENT"});
    });

for (const [error, expected] of [
  [{code: 7, message: "PRIVATE"}, "FIRESTORE_PERMISSION_DENIED"],
  [{code: 16, message: "PRIVATE"}, "ADC_REAUTH_REQUIRED"],
  [{code: 14, message: "PRIVATE"}, "NETWORK_UNAVAILABLE"],
  [{message: "Could not load the default credentials PRIVATE"},
    "ADC_NOT_CONFIGURED"],
  [{message: "invalid_grant PRIVATE"}, "ADC_REAUTH_REQUIRED"],
  [{message: "EPERM PRIVATE"}, "LOCAL_ACCESS_DENIED"],
  [{message: "SERVICE_DISABLED PRIVATE"}, "API_DISABLED"],
  [{message: "ACCESS_TOKEN_SCOPE_INSUFFICIENT PRIVATE"},
    "OAUTH_SCOPE_INSUFFICIENT"],
  [{message: "USER_PROJECT PRIVATE"}, "QUOTA_PROJECT_REQUIRED"],
  [{message: "PRIVATE"}, "AUDIT_FAILED"],
]) {
  test("redacts SDK failure: " + expected, () => {
    const result = diagnose(error);
    assert.equal(result.code, expected);
    assert.equal(JSON.stringify(result).includes("PRIVATE"), false);
  });
}
