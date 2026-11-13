"use strict";
const {createHash} = require("node:crypto");
const {Timestamp} = require("firebase-admin/firestore");
const {HttpsError} = require("firebase-functions/v2/https");
const {validatePackage} = require("./courier-pickup");
const {assertPaymentCountry, verifiedQuoteCountry} = require("./order-acceptance");
const {cents} = require("./order-operations");
const {buildCourierDelivery} = require("./courier-deliveries");
const {assertCustomerAccountActive} = require("./customer-account-state");
const {isDeepStrictEqual} = require("node:util");
const reject = () => { throw new HttpsError("failed-precondition", "AUTHORITATIVE_ROUTE_PACKAGE_UNAVAILABLE", {reason: "AUTHORITATIVE_ROUTE_PACKAGE_UNAVAILABLE"}); };
// Read-only adapter. A separately authorized backend producer must supply this
// immutable snapshot. No endpoint, customer file or generated road is trusted.
function createStoredRoutePackageProvider(db, {producerId, checkFinancial, checkDeliveryPayment}) {
  if (typeof producerId !== "string" || !/^[A-Za-z0-9_-]{1,80}$/.test(producerId) ||
      typeof checkFinancial !== "function" || typeof checkDeliveryPayment !== "function") {
    throw new TypeError("AUTHORITATIVE_ROUTE_PROVIDERS_REQUIRED");
  }
  return async function packageProvider(ticket, order, tx) {
    if (!tx || typeof tx.get !== "function") reject();
    await assertCustomerAccountActive(db, order.customerUid, tx);
    const saved = (await tx.get(db.doc("customerDeliverySecrets/" + order.customerUid +
      "/courierRoutePackages/" + ticket.assignmentId))).data();
    if (!saved || saved.status !== "ready" || saved.producerId !== producerId ||
        saved.orderId !== ticket.orderId || saved.assignmentId !== ticket.assignmentId ||
        saved.courierUid !== ticket.courierUid || saved.packageVersion !== ticket.packageVersion ||
        !(saved.expiresAt instanceof Timestamp) || saved.expiresAt.toMillis() <= Date.now() ||
        typeof saved.payloadBase64 !== "string" || saved.payloadBase64.length > 2796204 ||
        !/^[a-f0-9]{64}$/.test(saved.payloadSha256 || "")) reject();
    const bytes = Buffer.from(saved.payloadBase64, "base64");
    if (bytes.toString("base64") !== saved.payloadBase64 ||
        createHash("sha256").update(bytes).digest("hex") !== saved.payloadSha256) reject();
    const data = validatePackage(bytes, ticket);
    if (data.assignment.expiresAtMs > saved.expiresAt.toMillis()) reject();
    const financial = (await tx.get(db.doc("orderFinancials/" + ticket.orderId))).data();
    if (!financial || !/^[a-f0-9]{64}$/.test(order.deliveryQuoteId || "")) reject();
    const quote = (await tx.get(db.doc("deliveryQuotes/" + order.deliveryQuoteId))).data();
    const country = verifiedQuoteCountry(quote, order.deliveryAddress);
    if (quote?.uid !== order.customerUid || quote?.orderId !== ticket.orderId) reject();
    assertPaymentCountry(order, country);
    checkFinancial(order, financial);
    checkDeliveryPayment(order, financial);
    const operational = buildCourierDelivery(ticket.orderId, order, {}, Timestamp.now());
    if (!operational || (data.delivery.reference ?? "") !== (operational.reference || "") ||
        (data.delivery.note ?? "") !== (operational.complement || "")) reject();
    const paid = order.paymentStatus === "Pago";
    const card = typeof order.paymentMethod === "string" && order.paymentMethod.startsWith("Maquininha");
    const method = order.paymentMethod === "PIX" ? "pix" : card ? "card" : "cash";
    const point = data.delivery.coordinates, expected = order.deliveryAddress;
    if (data.delivery.country !== country.toLowerCase() ||
        point.latitude !== expected.latitude || point.longitude !== expected.longitude ||
        data.delivery.address !== (expected.addressText ?? order.address) ||
        data.delivery.payment.state !== (paid ? "paid" : "collect") ||
        data.delivery.payment.method !== method ||
        paid && data.delivery.payment.amountMinor !== 0 ||
        !paid && data.delivery.payment.currency === "BRL" && data.delivery.payment.amountMinor !== cents(financial.totalBRL)) reject();
    // The approved producer freezes currency conversion/change against the same
    // financial version and tender inputs. This adapter never reprices them.
    if (saved.financialVersion !== financial.version || saved.totalBRL !== financial.totalBRL ||
        saved.paymentMethod !== order.paymentMethod || saved.paymentStatus !== order.paymentStatus ||
        !isDeepStrictEqual(saved.paymentParts ?? null, order.paymentParts ?? null) ||
        saved.cashCurrency !== (order.cashCurrency ?? null) || saved.cashTendered !== (order.cashTendered ?? null) ||
        !isDeepStrictEqual(saved.paymentProjection, data.delivery.payment)) reject();
    return bytes;
  };
}
module.exports = {createStoredRoutePackageProvider};
