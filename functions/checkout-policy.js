"use strict";
const {HttpsError} = require("firebase-functions/v2/https");
// Operational defaults for NEW purchases. Historical settlement and refunds
// continue through their existing contracts. Changing these gates requires
// evidence and a separately reviewed publication; client payload cannot opt in.
const checkoutPolicy = Object.freeze({
  splitPaymentEnabled: false,
  crossBorderEnabled: false,
  foreignCashEnabled: false,
});
function reject(reason) {
  const error = new HttpsError("failed-precondition", reason, {reason});
  error.acceptanceCode = reason;
  throw error;
}
function assertDestinationOperation(country) {
  if (!["BR", "PY"].includes(country)) reject("DESTINATION_COUNTRY_UNVERIFIED");
  if (country === "PY" && !checkoutPolicy.crossBorderEnabled) {
    reject("CROSS_BORDER_OPERATION_NOT_AUTHORIZED");
  }
}
function assertSinglePayment(order) {
  if (!checkoutPolicy.splitPaymentEnabled && (order.splitPayment === true ||
      order.paymentMethod === "Pagamento dividido" ||
      order.paymentParts != null && (!Array.isArray(order.paymentParts) || order.paymentParts.length > 0))) {
    reject("SINGLE_PAYMENT_REQUIRED");
  }
  // No invented FX rate. BRL cash remains usable while a real, versioned
  // commercial exchange contract is pending. Legacy reconciliation is intact.
  if (!checkoutPolicy.foreignCashEnabled && order.paymentMethod === "Dinheiro" &&
      order.cashCurrency != null && order.cashCurrency !== "BRL") {
    reject("EXCHANGE_RATE_UNAVAILABLE");
  }
}
module.exports = {checkoutPolicy, assertDestinationOperation, assertSinglePayment};
