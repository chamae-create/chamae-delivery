const {FieldValue} = require("firebase-admin/firestore");

// Durable outbox only. No offers, availability, FCM, GPS or automatic routing
// are fabricated before the courier application and trusted worker exist.
const dispatchPolicy = Object.freeze({version: 1,
  phase: "awaiting_integration", firstWave: "longest_idle_first",
  offerSeconds: 15, secondWave: "all_available",
  acceptance: "atomic_first_valid_accept", pickup: "validated_app_qr_event",
  completion: "validated_app_delivery_event"});

/** Prepares a durable request for a future trusted worker.
 * @param {Object} tx Transaction.
 * @param {Object} ref Request reference.
 * @param {string} orderId Documentary ID.
 */
function prepareCourierDispatch(tx, ref, orderId) {
  tx.set(ref, {orderId, ...dispatchPolicy,
    requestedAt: FieldValue.serverTimestamp()}, {merge: false});
}

module.exports = {dispatchPolicy, prepareCourierDispatch};
