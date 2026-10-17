const {parseArgs} = require("node:util");
const {initializeApp, applicationDefault, deleteApp} =
    require("firebase-admin/app");
const {getFirestore, FieldPath, Timestamp} =
    require("firebase-admin/firestore");
const {courierUid} = require("../courier-deliveries");
const {readyForDispatch} = require("../courier-assignment");
const {cents} = require("../order-operations");

const MONEY = ["itemsTotal", "deliveryFee", "customerFee", "merchantFee",
  "merchantNet", "platformFee", "totalBRL"];
const FIELDS = MONEY.concat(["id", "customerUid", "courierUid", "status",
  "createdAt", "financialValidationStatus", "itemsList", "courierAssignedAt",
  "dispatchedAt", "completedAt", "paymentStatus", "paymentMethod",
  "paymentParts", "pixRequested", "stockReservationRequired",
  "stockReservationStatus", "stockProcessingStatus", "stockProcessingError",
  "stockReservationError"]);

/** Classifies structure using the existing backend validators, without writes.
 * @param {Object} order Selected order fields.
 * @param {?Object} official Selected immutable financial fields.
 * @return {Object[]} Reasons; observation-only absence is explicit.
 */
function auditReasons(order, official) {
  const reasons = [];
  const add = (code, blocking = true) => reasons.push({code, blocking});
  if (!order.customerUid) add("missingCustomerUid");
  else if (!courierUid(order.customerUid)) add("invalidCustomerUid");
  if (!order.financialValidationStatus) add("missingFinancialValidationStatus");
  if (order.financialValidationStatus !== "validated") {
    add("unconfirmedFinancialValidation");
  }
  if (!official) add("missingOfficialFinance");
  else {
    try {
      const divergent = MONEY.some((field) => {
        return cents(order[field]) !== cents(official[field]);
      });
      if (divergent) {
        add("divergentOfficialAmounts");
      }
    } catch (_) {
      add("invalidOrMissingOfficialAmounts");
    }
  }
  if (!(order.createdAt instanceof Timestamp)) {
    add("missingOrInvalidCreatedAt");
  }
  if (typeof order.id !== "string" || !order.id) add("missingFriendlyId");
  if (!Array.isArray(order.itemsList) || !order.itemsList.length) {
    add("missingItemsList");
  }
  if (!["Novo", "Aguardando pagamento", "Em Separação", "Saiu para Entrega",
    "Concluído", "Cancelado", "Revisão financeira", "Revisão de estoque"]
      .includes(order.status)) add("unknownOperationalStatus");
  const dispatched = ["Saiu para Entrega", "Concluído"].includes(order.status);
  if (!order.courierUid) add("missingCourierUid", dispatched);
  else if (!courierUid(order.courierUid)) add("invalidCourierUid");
  if (dispatched && !(order.courierAssignedAt instanceof Timestamp)) {
    add("missingOrInvalidCourierAssignedAt");
  }
  if (dispatched && !(order.dispatchedAt instanceof Timestamp)) {
    add("missingOrInvalidDispatchedAt");
  }
  if (order.status === "Concluído") {
    if (!(order.completedAt instanceof Timestamp)) {
      add("missingOrInvalidCompletedAt");
    }
    if (order.paymentStatus !== "Pago") add("completedPaymentUnconfirmed");
    if (order.stockReservationStatus !== "finalized" &&
        order.stockProcessingStatus !== "processed") {
      add("completedStockUnconfirmed");
    }
  }
  if (["Em Separação", "Saiu para Entrega"].includes(order.status) &&
      !readyForDispatch(order)) add("operationalPrerequisitesUnconfirmed");
  if (["Revisão financeira", "Revisão de estoque"].includes(order.status) ||
      ["requires_review", "error"].includes(order.stockReservationStatus) ||
      order.stockProcessingStatus === "requires_review" ||
      order.stockProcessingError != null ||
      order.stockReservationError != null) add("backendReviewRequired");
  return reasons;
}

/** Paginated read-only report; never outputs names, contacts, UIDs or amounts.
 * @param {Object} db Admin Firestore with read permission.
 * @param {Object} options Optional internal document IDs.
 * @return {Promise<Object>} Complete counts, only after all reads succeed.
 */
async function auditOrders(db, {includeIds = false} = {}) {
  const report = {schemaVersion: 2, projectId: "chamae-delivery",
    readOnly: true, complete: true, consistency: "paginated-live-read",
    startedAt: new Date().toISOString(), total: 0, compatible: 0, legacy: 0,
    reasons: {}};
  let cursor;
  for (;;) {
    let query = db.collection("orders").orderBy(FieldPath.documentId())
        .select(...FIELDS).limit(200);
    if (cursor) query = query.startAfter(cursor);
    const page = await query.get();
    if (page.empty) break;
    const records = await db.getAll(...page.docs.map((doc) =>
      db.doc("orderFinancials/" + doc.id)), {fieldMask: MONEY});
    page.docs.forEach((snapshot, index) => {
      const reasons = auditReasons(snapshot.data(),
          records[index].exists ? records[index].data() : null);
      report.total++;
      if (reasons.some((reason) => reason.blocking)) report.legacy++;
      else report.compatible++;
      for (const reason of reasons) {
        if (!report.reasons[reason.code]) {
          report.reasons[reason.code] = {count: 0, blockingCount: 0};
          if (includeIds) report.reasons[reason.code].documentIds = [];
        }
        const bucket = report.reasons[reason.code];
        bucket.count++;
        if (reason.blocking) bucket.blockingCount++;
        if (includeIds) bucket.documentIds.push(snapshot.id);
      }
    });
    cursor = page.docs[page.size - 1];
  }
  report.finishedAt = new Date().toISOString();
  return report;
}

/** Safe fixed diagnostics, never the raw error/response/credential.
 * @param {Error} error SDK failure.
 * @return {Object} Non-sensitive classification.
 */
function diagnose(error) {
  const message = String(error.message || "") + " " +
    String(error.details || "");
  let code = "AUDIT_FAILED";
  if (error.code === "INVALID_ARGUMENT") code = "INVALID_ARGUMENT";
  else if (/SERVICE_DISABLED|API.*not.*enabled/i.test(message)) {
    code = "API_DISABLED";
  } else if (/ACCESS_TOKEN_SCOPE_INSUFFICIENT|authentication scopes/i
      .test(message)) code = "OAUTH_SCOPE_INSUFFICIENT";
  else if (/quota.*project|USER_PROJECT|serviceusage/i.test(message)) {
    code = "QUOTA_PROJECT_REQUIRED";
  } else if (/Could not load.*default credentials|ENOENT/i.test(message)) {
    code = "ADC_NOT_CONFIGURED";
  } else if (/invalid_grant|reauth|invalid_rapt/i.test(message) ||
      error.code === 16) code = "ADC_REAUTH_REQUIRED";
  else if (/EPERM|EACCES/i.test(message)) code = "LOCAL_ACCESS_DENIED";
  else if (error.code === 7 || /PERMISSION_DENIED/i.test(message)) {
    code = "FIRESTORE_PERMISSION_DENIED";
  } else if (error.code === 14 ||
      /ENOTFOUND|ECONN|ETIMEDOUT|UNAVAILABLE/i.test(message)) {
    code = "NETWORK_UNAVAILABLE";
  }
  return {code, grpcCode: Number.isInteger(error.code) ? error.code : null,
    procedure: "chamae_admin/docs/pilot_legacy_audit.md"};
}

/** Production CLI accepts no write/backfill modes or credentials.
 * @param {string[]} args Explicit project and optional ID flag.
 * @param {Object} env Process environment.
 * @return {Object} Validated flags.
 */
function optionsFrom(args, env = process.env) {
  let parsed;
  try {
    parsed = parseArgs({args, strict: true, allowPositionals: false, options: {
      "project": {type: "string"}, "include-ids": {type: "boolean"},
    }});
  } catch (_) {
    throw Object.assign(new Error("Invalid audit options"),
        {code: "INVALID_ARGUMENT"});
  }
  if (parsed.values.project !== "chamae-delivery" ||
      env.FIRESTORE_EMULATOR_HOST) {
    throw Object.assign(new Error("Explicit production project required"),
        {code: "INVALID_ARGUMENT"});
  }
  return {includeIds: parsed.values["include-ids"] === true};
}

/** Prints one complete report, or a redacted failure; never writes remotely.
 * @param {string[]} args CLI arguments.
 * @return {Promise<void>} Completion.
 */
async function main(args = process.argv.slice(2)) {
  const options = optionsFrom(args);
  const app = initializeApp({credential: applicationDefault(),
    projectId: "chamae-delivery"});
  try {
    console.log(JSON.stringify(await auditOrders(getFirestore(app), options),
        null, 2));
  } finally {
    await deleteApp(app);
  }
}

if (require.main === module) {
  main().catch((error) => {
    console.error(JSON.stringify({projectId: "chamae-delivery",
      readOnly: true, complete: false, total: null, compatible: null,
      legacy: null, error: diagnose(error)}, null, 2));
    process.exitCode = 1;
  });
}
module.exports = {auditOrders, auditReasons, diagnose, optionsFrom, FIELDS};
