const {HttpsError} = require("firebase-functions/v2/https");
const {FieldValue} = require("firebase-admin/firestore");
const {createHash} = require("node:crypto");

const isCancelled = (order) => /cancel/i.test(order.status || "") || order.cancellationStatus === "cancelled";
const fail = (reason) => {
  const error = new HttpsError("failed-precondition", "Confira o estado atual do pedido.", {reason});
  error.acceptanceCode = reason;
  throw error;
};
function assertPurchasable(order) {
  if (isCancelled(order)) fail("ORDER_CANCELLED");
  if (order.status === "Concluído" || order.paymentStatus === "Pago") fail("ORDER_FINALIZED");
}
async function assertPixCanStart(db, ref) {
  const order = await ref.get();
  if (!order.exists) fail("ORDER_NOT_FOUND");
  assertPurchasable(order.data());
}
async function updateActiveOrder(db, ref, patch) {
  return db.runTransaction(async (tx) => {
    const doc = await tx.get(ref);
    if (!doc.exists || isCancelled(doc.data()) || doc.data().status === "Concluído" ||
        doc.data().paymentStatus === "Pago") {
      return;
    }
    tx.update(ref, patch);
  });
}

function financialCompensation(order, financial) {
  const paid = order.paymentStatus === "Pago";
  const pix = order.pixRequested === true || order.paymentMethod === "PIX";
  const issued = order.mercadoPagoOrderId || order.mercadoPagoPaymentId ||
    order.mercadoPagoCreateStartedAt || order.mercadoPagoIdempotencyKey ||
    ["creating", "created", "error"].includes(order.mercadoPagoCreateStatus);
  return {schemaVersion: 1, refundStatus: paid ? "required" : pix && issued ? "verification_required" : "not_required",
    financialAction: paid ? pix ? "external_pix_refund_required" : "external_payment_review_required" :
      pix && issued ? "verify_and_cancel_provider_charge" : "none",
    providerCancellationStatus: pix && issued ? "unconfirmed" : "not_required",
    officialTotalBRL: financial?.totalBRL ?? null, originalMerchantFee: financial?.merchantFee ?? null,
    commissionAdjustmentStatus: order.status === "Concluído" ? "return_review_required" : "excluded_from_closing"};
}

async function savePixCreation(db, ref, patch) {
  return db.runTransaction(async (tx) => {
    const snapshot = await tx.get(ref);
    if (!snapshot.exists) fail("ORDER_NOT_FOUND");
    const order = snapshot.data();
    if (order.mercadoPagoOrderId && patch.mercadoPagoOrderId && order.mercadoPagoOrderId !== patch.mercadoPagoOrderId) {
      const key = createHash("sha256").update(JSON.stringify([order.mercadoPagoOrderId, patch.mercadoPagoOrderId]))
          .digest("hex");
      tx.set(db.collection("orderCompensationAudit").doc(key), {
        orderId: ref.id, operation: "provider_id_conflict", actorUid: "pix_creation",
        originalProviderId: order.mercadoPagoOrderId, observedProviderId: patch.mercadoPagoOrderId,
        createdAt: FieldValue.serverTimestamp(),
      });
      tx.set(db.collection("orderCompensations").doc(ref.id), {schemaVersion: 1,
        refundStatus: "verification_required", financialAction: "provider_id_conflict_review_required",
        updatedAt: FieldValue.serverTimestamp()}, {merge: true});
      tx.update(ref, {compensationStatus: "required"});
      return;
    }
    const metadataForClosed = () => {
      const metadata = {...patch};
      delete metadata.paymentStatus; delete metadata.status;
      if (order.paymentStatus === "Pago" || ["canceled", "cancelled", "refunded"].includes(order.mercadoPagoStatus)) {
        for (const key of ["mercadoPagoStatus", "mercadoPagoStatusDetail", "mercadoPagoPaymentStatus"]) {
          delete metadata[key];
        }
      }
      return metadata;
    };
    if (isCancelled(order)) {
      const metadata = metadataForClosed();
      const terminal = ["canceled", "cancelled"].includes(order.mercadoPagoStatus) && order.paymentStatus !== "Pago";
      tx.update(ref, {...metadata, ...(!terminal ? {compensationStatus: "required"} : {})});
      tx.set(db.collection("orderCompensations").doc(ref.id), {
        schemaVersion: 1, refundStatus: order.paymentStatus === "Pago" ? "required" :
          terminal ? "not_required" : "verification_required",
        financialAction: order.paymentStatus === "Pago" ?
          "external_pix_refund_required" : terminal ? "none" : "verify_and_cancel_provider_charge",
        providerCancellationStatus: terminal ? "confirmed" : "unconfirmed",
        pixCreationInFlight: true,
        mercadoPagoOrderId: patch.mercadoPagoOrderId || null,
        updatedAt: FieldValue.serverTimestamp(),
      }, {merge: true});
      return;
    }
    // A webhook may arrive before the POST response is saved.
    if (order.paymentStatus === "Pago" || order.status === "Concluído") {
      const metadata = metadataForClosed();
      tx.update(ref, metadata);
    } else tx.update(ref, patch);
  });
}

async function recordCancelledPayment(tx, db, ref, order, patch, financial) {
  // Called only after the existing signature, provider lookup, ID and amount checks.
  tx.update(ref, {...patch, paymentStatus: "Pago", compensationStatus: "required"});
  tx.set(db.collection("orderCompensations").doc(ref.id), {
    ...financialCompensation({...order, paymentStatus: "Pago"}, financial),
    financialAction: "external_pix_refund_required", latePaymentConfirmed: true,
    mercadoPagoOrderId: order.mercadoPagoOrderId,
    updatedAt: FieldValue.serverTimestamp(),
  }, {merge: true});
  tx.set(db.collection("orderCompensationAudit").doc(ref.id + "_late_payment"), {
    orderId: ref.id, actorUid: "mercado_pago_webhook", operation: "late_payment",
    previousPaymentStatus: order.paymentStatus, nextPaymentStatus: "Pago",
    stockAction: "none", financialAction: "external_pix_refund_required",
    createdAt: FieldValue.serverTimestamp(),
  });
}

module.exports = {isCancelled, fail, assertPurchasable, assertPixCanStart, updateActiveOrder,
  financialCompensation, savePixCreation, recordCancelledPayment};
