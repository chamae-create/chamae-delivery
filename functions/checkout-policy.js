"use strict";
const {HttpsError} = require("firebase-functions/v2/https");
// Operational defaults for NEW purchases. Historical settlement and refunds
// continue through their existing contracts. Changing these gates requires
// evidence and a separately reviewed publication; client payload cannot opt in.
const checkoutPolicy = Object.freeze({
  splitPaymentEnabled: true,
  crossBorderEnabled: true,
  foreignCashEnabled: true,
});
const ALLOWED_CASH_CURRENCIES = new Set(["BRL", "PYG", "USD"]);
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
  const isSplit = order.splitPayment === true;
  if (!isSplit) {
    if (order.paymentMethod === "Pagamento dividido" ||
        (order.paymentParts != null && (!Array.isArray(order.paymentParts) || order.paymentParts.length > 0))) {
      reject("SINGLE_PAYMENT_REQUIRED");
    }
    if (order.paymentMethod === "Dinheiro" && order.cashCurrency != null &&
        !ALLOWED_CASH_CURRENCIES.has(order.cashCurrency)) {
      reject("EXCHANGE_RATE_UNAVAILABLE");
    }
    return;
  }
  if (!checkoutPolicy.splitPaymentEnabled) reject("SINGLE_PAYMENT_REQUIRED");
  if (order.paymentMethod !== "Pagamento dividido" || order.pixRequested === true ||
      !Array.isArray(order.paymentParts) || order.paymentParts.length < 2 || order.paymentParts.length > 3) {
    reject("SINGLE_PAYMENT_REQUIRED");
  }
  for (const part of order.paymentParts) {
    if (!part || part.method !== "Dinheiro") reject("SINGLE_PAYMENT_REQUIRED");
    if (!ALLOWED_CASH_CURRENCIES.has(part.currency)) reject("EXCHANGE_RATE_UNAVAILABLE");
    if (typeof part.amountCurrency !== "number" || !Number.isFinite(part.amountCurrency) || part.amountCurrency <= 0) {
      reject("SINGLE_PAYMENT_REQUIRED");
    }
  }
}
module.exports = {checkoutPolicy, assertDestinationOperation, assertSinglePayment};
