"use strict";
// Shadow contract only: never replaces existing products/reservations/orders.
const {createHash} = require("node:crypto");
const {isCommerciallyBlocked, categoryReviewRequired} =
    require("./catalog-commercial-policy");
const digest = (x) => createHash("sha256").update(JSON.stringify(x))
    .digest("hex");
const fail = (reason) => {
  throw Error(reason);
};
const positive = (x) => Number.isSafeInteger(x) && x > 0;
/** Calculates conservative shadow availability.
 * @param {Object} s Shadow state.
 * @param {number} now Current time.
 * @param {number} staleMs Approved age limit.
 * @return {number} Available units.
 */
function available(s, now, staleMs) {
  if (!Number.isSafeInteger(now) || !positive(staleMs)) {
    fail("EXPLICIT_FRESHNESS_REQUIRED");
  }
  if (s.observedAtMs == null || now < s.observedAtMs || now - s
      .observedAtMs > staleMs || !Number.isSafeInteger(s.observedBalance) || s
      .observedBalance < 0 || s.blocked || s.commercialBlocked !== false) {
    return 0;
  }
  const reserved = Object.values(s.orders).filter((o) => o
      .status === "reserved").reduce((n, o) => n + o.quantity, 0);
  return Math.max(0, Math.min(s.firebaseStock - reserved, s
      .observedBalance - s.unreconciled - reserved));
}
/** Creates isolated synthetic shadow state.
 * @param {Object} input Existing authoritative stock and source identity.
 * @return {Object} Shadow state.
 */
function initial({firebaseStock, sourceProductId, catalogProduct}) {
  if (!Number.isSafeInteger(firebaseStock) || firebaseStock < 0 ||
      !positive(sourceProductId) || sourceProductId > 999999) {
    fail("INVALID_SHADOW_BOOTSTRAP");
  }
  return {
    commercialBlocked: !catalogProduct ||
      isCommerciallyBlocked(catalogProduct) ||
      categoryReviewRequired(catalogProduct),
    schemaVersion: 1,
    sourceProductId,
    firebaseStock,
    observedBalance: null,
    observedAtMs: null,
    sequence: 0,
    unreconciled: 0,
    orders: {},
    events: {},
    proofs: {},
    blocked: false,
  };
}
/** Applies one idempotent synthetic shadow event.
 * @param {Object} old Prior shadow state.
 * @param {Object} event Trusted internal event.
 * @param {Object} options Time and independently verified proof.
 * @return {Object} New state and availability.
 */
function reduce(old, event, {nowMs, staleMs, proofVerified = false} = {}) {
  if (!event || typeof event.eventId !== "string" || !/^[A-Za-z0-9_-]{1,128}$/
      .test(event.eventId) || !Number.isSafeInteger(nowMs) ||
      !positive(staleMs)) {
    fail("INVALID_SHADOW_EVENT");
  }
  const fingerprint = digest(event);
  if (old.events[event.eventId]) {
    if (old.events[event.eventId] !== fingerprint) {
      fail("SHADOW_EVENT_REPLAY_CONFLICT");
    }
    return {
      state: old,
      replayed: true,
      available: available(old, nowMs, staleMs),
    };
  }
  const s = JSON.parse(JSON.stringify(old));
  const order = s.orders[event.orderId];
  switch (event.type) {
    case "observation": {
      if (!positive(event.sequence) || event.sequence <= s.sequence || !Number
          .isSafeInteger(event.observedAtMs) || event.observedAtMs > nowMs ||
          nowMs - event.observedAtMs > staleMs || s.observedAtMs !== null &&
          event.observedAtMs < s.observedAtMs || event.balance !== null &&
          (typeof event.balance !== "number" || !Number.isFinite(event
              .balance))) {
        fail("SHADOW_OBSERVATION_INVALID_OR_STALE");
      }
      s.sequence = event.sequence;
      s.observedAtMs = event.observedAtMs;
      s.observedBalance = event.balance;
      s.blocked = event.balance === null || !Number.isSafeInteger(event
          .balance) || event.balance < 0;
      break;
    }
    case "reserve":
      if (typeof event.orderId !== "string" || !/^[A-Za-z0-9_-]{1,128}$/
          .test(event.orderId) || !positive(event.quantity) || !Number
          .isSafeInteger(event.expiresAtMs) || event.expiresAtMs <= nowMs ||
          order) {
        fail("SHADOW_RESERVATION_CONFLICT");
      }
      if (available(s, nowMs, staleMs) < event.quantity) {
        fail("SHADOW_STOCK_UNAVAILABLE");
      }
      s.orders[event.orderId] = {
        quantity: event.quantity,
        expiresAtMs: event.expiresAtMs,
        status: "reserved",
        paid: false,
      };
      break;
    case "payment":
      if (!order || order.status !== "reserved") {
        fail("PAYMENT_REVIEW_REQUIRED");
      }
      order.paid = true;
      break;
    case "commit":
      if (s.commercialBlocked !== false) fail("COMMERCIAL_CATEGORY_BLOCKED");
      if (!order || order.status !== "reserved" || !order.paid) {
        fail("COMMIT_REQUIRES_AUTHORIZED_PAYMENT");
      }
      if (s.blocked || s.observedAtMs === null || nowMs < s.observedAtMs ||
          nowMs - s.observedAtMs > staleMs || !Number.isSafeInteger(s
          .observedBalance) || s.observedBalance - s.unreconciled < Object
          .values(s.orders).filter((o) => o.status === "reserved").reduce((n,
              o) => n + o.quantity, 0)) {
        fail("PHYSICAL_SHORTFALL_PAID_ORDER_REVIEW");
      }
      // Existing Firebase commits own live stock; this copy is shadow only.
      if (s.firebaseStock < order.quantity) {
        fail("SHADOW_NEGATIVE_LOGICAL_STOCK");
      }
      s.firebaseStock -= order.quantity;
      s.unreconciled += order.quantity;
      order.status = "committed";
      break;
    case "cancel":
    case "expire":
      if (!order || order.status !== "reserved" || order.paid) {
        fail("PAID_OR_COMMITTED_CANCEL_REQUIRES_REVIEW");
      }
      if (event.type === "expire" && nowMs < order.expiresAtMs) {
        fail("RESERVATION_NOT_EXPIRED");
      }
      order.status = event.type === "expire" ? "expired" : "cancelled";
      break;
    case "refund":
      if (!order || order.status !== "committed") {
        fail("REFUND_REVIEW_REQUIRED");
      }
      order.refunded = true;
      // Refund never invents physical stock or clears debt.
      break;
    case "reconcile":
      if (!proofVerified || !order || order.status !== "committed" || order
          .reconciled || typeof event.proofHash !== "string" ||
          !/^[a-f0-9]{64}$/.test(event.proofHash) || s.proofs[event
          .proofHash] || event.sequence !== s.sequence || event
          .observedAtMs !== s.observedAtMs || s.observedBalance === null) {
        fail("AUTHORITATIVE_ERP_LINK_REQUIRED");
      }
      // The verifier MUST bind ERP sale, source code, order, quantity and exact
      // post-sale observation. A balance drop or manual checkbox is not proof.
      s.unreconciled -= order.quantity;
      order.reconciled = true;
      s.proofs[event.proofHash] = event.orderId;
      break;
    default:
      fail("UNKNOWN_SHADOW_ACTION");
  }
  s.events[event.eventId] = fingerprint;
  return {
    state: s,
    replayed: false,
    available: available(s, nowMs, staleMs),
  };
}
/** Creates a local emulator transaction adapter. No live deployment.
 * @param {Object} db Emulator Firestore.
 * @param {Object} options Freshness and external proof verifier.
 * @return {Function} Shadow-only transaction handler.
 */
function createShadowInventory(db, {staleMs, verifyErpProof} = {}) {
  if (process.env.FIRESTORE_EMULATOR_HOST !== "127.0.0.1:8341" || process.env
      .GCLOUD_PROJECT !== "demo-chamae-maximo" || db
      .projectId !== "demo-chamae-maximo") {
    fail("SHADOW_EMULATOR_ONLY");
  }
  if (!positive(staleMs)) {
    fail("EXPLICIT_FRESHNESS_REQUIRED");
  }
  return async ({productId, bootstrap, event, nowMs, actor}) => {
    if (![
      "trusted-server",
      "original-bridge",
    ].includes(actor) || actor === "original-bridge" && event
        .type !== "observation") {
      fail("SHADOW_AUTHORIZATION_REQUIRED");
    }
    if (typeof productId !== "string" || !/^[A-Za-z0-9_-]{1,128}$/
        .test(productId)) {
      fail("INVALID_MAPPING");
    }
    const proofVerified = event.type === "reconcile" &&
        typeof verifyErpProof === "function" ? await verifyErpProof({
          event,
          productId,
        }) : false;
    const ref = db.collection("grancheffShadowInventory").doc(productId);
    return db.runTransaction(async (tx) => {
      const snap = await tx.get(ref);
      const catalogProduct = {...bootstrap.catalogProduct, id: productId};
      const old = snap.exists ? snap.data() :
        initial({...bootstrap, catalogProduct});
      old.commercialBlocked = old.commercialBlocked !== false ||
        isCommerciallyBlocked(catalogProduct) ||
        categoryReviewRequired(catalogProduct);
      const result = reduce(old, event, {
        nowMs,
        staleMs,
        proofVerified: proofVerified === true,
      });
      if (!result.replayed) {
        tx.set(ref, result.state);
      }
      return {
        available: result.available,
        replayed: result.replayed,
        commercialRelease: false,
      };
    });
  };
}
module.exports = {
  initial,
  reduce,
  available,
  createShadowInventory,
};
