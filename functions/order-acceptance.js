const {HttpsError} = require("firebase-functions/v2/https");
const {point, validateQuote} = require("./delivery-pricing");

const timeZone = "America/Campo_Grande";
const hourFormatter = new Intl.DateTimeFormat("en-GB", {
  timeZone, hour: "2-digit", hourCycle: "h23",
});
// Server dependency, replaceable by isolated test harnesses, never by payload.
const serverClock = {now: () => Date.now()};
const reject = (reason) => {
  const messages = {
    STORE_CLOSED: "A loja está fechada. O delivery funciona das 08:00 às 00:00 (MS).",
    DESTINATION_COUNTRY_UNVERIFIED: "Não foi possível confirmar o país do destino. Confira o endereço.",
    PAYMENT_METHOD_NOT_ALLOWED_FOR_COUNTRY: "Esta forma de pagamento não está disponível para o país da entrega.",
  };
  const error = new HttpsError("failed-precondition", messages[reason], {reason});
  error.acceptanceCode = reason;
  throw error;
};

function storeIsOpen(now) {
  if (!Number.isFinite(now)) return false;
  return Number(hourFormatter.format(new Date(now))) >= 8;
}
function assertStoreOpen(now = serverClock.now()) {
  if (!storeIsOpen(now)) reject("STORE_CLOSED");
}

function assertPaymentCountry(order, country) {
  const cashSplit = order.splitPayment === true;
  if (!cashSplit && Array.isArray(order.paymentParts) && order.paymentParts.length) {
    reject("PAYMENT_METHOD_NOT_ALLOWED_FOR_COUNTRY");
  }
  const method = order.paymentMethod;
  const cash = method === "Dinheiro";
  const pix = method === "PIX" && !cashSplit && order.pixRequested === true;
  const card = ["Maquininha", "Maquininha - Débito à vista", "Maquininha - Crédito à vista"].includes(method);
  const split = cashSplit && method === "Pagamento dividido" && order.pixRequested !== true &&
    Array.isArray(order.paymentParts) && order.paymentParts.length >= 2 && order.paymentParts.length <= 3 &&
    order.paymentParts.every((part) => part && part.method === "Dinheiro");
  if (!["BR", "PY"].includes(country)) reject("DESTINATION_COUNTRY_UNVERIFIED");
  if (!(pix || (!cashSplit && order.pixRequested !== true && (cash || country === "BR" && card)) || split)) {
    reject("PAYMENT_METHOD_NOT_ALLOWED_FOR_COUNTRY");
  }
}

function verifiedQuoteCountry(quote, destination) {
  const evidence = quote?.destinationVerification;
  if (!point(destination) || !evidence || evidence.schemaVersion !== 1 ||
      evidence.provider !== "google-geocoding" || !["BR", "PY"].includes(evidence.countryCode) ||
      evidence.latitude !== destination.latitude || evidence.longitude !== destination.longitude ||
      evidence.countryCode !== destination.countryCode || !Number.isFinite(evidence.verifiedAtMs) ||
      evidence.verifiedAtMs <= 0 || evidence.verifiedAtMs > quote.createdAtMs) {
    reject("DESTINATION_COUNTRY_UNVERIFIED");
  }
  return evidence.countryCode;
}

async function prepareOrderAcceptance(tx, db, orderRef, order) {
  assertStoreOpen();
  if (!/^[a-f0-9]{64}$/.test(order.deliveryQuoteId || "")) reject("DESTINATION_COUNTRY_UNVERIFIED");
  const quote = (await tx.get(db.collection("deliveryQuotes").doc(order.deliveryQuoteId))).data();
  const country = verifiedQuoteCountry(quote, order.deliveryAddress);
  // Tickets/projections also read these legacy aliases. They cannot point to a
  // different country/location than the destination verified for this quote.
  const location = order.deliveryLocation;
  if (location != null && (!point(location) ||
      location.latitude !== order.deliveryAddress.latitude || location.longitude !== order.deliveryAddress.longitude) ||
      [order.country, order.deliveryAddress.country].some((alias) => alias != null && alias !== country)) {
    reject("DESTINATION_COUNTRY_UNVERIFIED");
  }
  try {
    // The same private quote already binds owner, point, country and order ID.
    validateQuote(quote, order, orderRef.id);
  } catch (_) {
    reject("DESTINATION_COUNTRY_UNVERIFIED");
  }
  assertPaymentCountry(order, country);
}

module.exports = {timeZone, serverClock, storeIsOpen, assertStoreOpen,
  assertPaymentCountry, verifiedQuoteCountry, prepareOrderAcceptance};
