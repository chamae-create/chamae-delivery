"use strict";
const {HttpsError} = require("firebase-functions/v2/https");
const {assertPaymentCountry, verifiedQuoteCountry} = require("./order-acceptance");
async function assertSupervisedCollection(tx, db, order, orderId, financial, checkDeliveryPayment) {
  const reject = () => { throw new HttpsError("failed-precondition", "SUPERVISED_COLLECTION_REVIEW_REQUIRED",
    {reason: "SUPERVISED_COLLECTION_REVIEW_REQUIRED"}); };
  if (typeof checkDeliveryPayment !== "function" || !/^[a-f0-9]{64}$/.test(order.deliveryQuoteId || "")) reject();
  const quote = (await tx.get(db.doc("deliveryQuotes/" + order.deliveryQuoteId))).data();
  if (quote?.uid !== order.customerUid || quote?.orderId !== orderId) reject();
  assertPaymentCountry(order, verifiedQuoteCountry(quote, order.deliveryAddress));
  // Reuse existing currencies/tender validation, never duplicate its rates/formulas.
  checkDeliveryPayment(order, financial);
}
module.exports = {assertSupervisedCollection};
