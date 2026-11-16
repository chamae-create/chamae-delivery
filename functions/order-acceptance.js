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
    ACTIVE_ORDER_EXISTS: "Você já possui um pedido em andamento. Acompanhe o pedido atual antes de finalizar outro.",
  };
  const error = new HttpsError("failed-precondition", messages[reason], {reason});
  error.acceptanceCode = reason;
  throw error;
};

const TERMINAL_ORDER_STATUSES = new Set([
  "concluído",
  "concluido",
  "entregue",
  "cancelado",
  "cancelada",
]);

function isTerminalOrderStatus(status) {
  return TERMINAL_ORDER_STATUSES.has(String(status || "").trim().toLowerCase());
}

async function syncCustomerActiveOrder(db, customerUid) {
  if (!db || typeof db.collection !== "function" || !customerUid) return null;
  const snap = await db.collection("orders")
      .where("customerUid", "==", customerUid)
      .limit(25)
      .get();
  const activeDoc = snap.docs.find((d) => !isTerminalOrderStatus(d.data()?.status));
  const ref = db.collection("customerActiveOrders").doc(customerUid);
  if (activeDoc) {
    const data = activeDoc.data() || {};
    const payload = {
      customerUid,
      orderId: activeDoc.id,
      friendlyId: data.id || null,
      status: data.status || "Novo",
      active: true,
    };
    await ref.set(payload, {merge: true});
    return payload;
  }
  const payload = {
    customerUid,
    orderId: null,
    friendlyId: null,
    status: null,
    active: false,
  };
  await ref.set(payload, {merge: true});
  return payload;
}

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
  if (order.customerUid && typeof db?.collection === "function") {
    const activeLockSnap = await tx.get(db.collection("customerActiveOrders").doc(order.customerUid));
    const activeLock = activeLockSnap?.exists ? activeLockSnap.data() : null;
    if (activeLock && activeLock.active === true && activeLock.orderId && activeLock.orderId !== orderRef.id) {
      const otherOrderSnap = await tx.get(db.collection("orders").doc(activeLock.orderId));
      const otherStatus = otherOrderSnap?.exists ? otherOrderSnap.data()?.status : null;
      if (otherOrderSnap?.exists && !isTerminalOrderStatus(otherStatus)) {
        reject("ACTIVE_ORDER_EXISTS");
      }
    }
    const ordersCol = db.collection("orders");
    if (ordersCol && typeof ordersCol.where === "function") {
      const activeOrdersSnap = await tx.get(
          ordersCol.where("customerUid", "==", order.customerUid).limit(25));
      const conflict = activeOrdersSnap?.docs?.find((d) =>
        d.id !== orderRef.id && !isTerminalOrderStatus(d.data()?.status));
      if (conflict) {
        reject("ACTIVE_ORDER_EXISTS");
      }
    }
  }
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
  const {assertDestinationOperation, assertSinglePayment} = require("./checkout-policy");
  assertDestinationOperation(country);
  assertSinglePayment(order);
  assertPaymentCountry(order, country);
}

module.exports = {timeZone, serverClock, storeIsOpen, assertStoreOpen,
  assertPaymentCountry, verifiedQuoteCountry, prepareOrderAcceptance,
  isTerminalOrderStatus, syncCustomerActiveOrder};
