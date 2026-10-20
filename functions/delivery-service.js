/* Route pricing: atomic explicit publication and server-only routing. */
const {onCall, HttpsError} = require("firebase-functions/v2/https");
const {defineSecret} = require("firebase-functions/params");
const {GoogleRoutesProvider} = require("./google-routes-provider");
const routesApiKey = defineSecret("CHAMAE_ROUTES_API_KEY");
const {FieldValue} = require("firebase-admin/firestore");
const {verifiedCustomerToken} = require("./customer-identity");
const {validateTable, canonicalTable, priceForDistance, buildQuote, validateQuote, RoutingProvider,
  fingerprint, point} = require("./delivery-pricing");
const options = {region: "southamerica-east1", enforceAppCheck: false};
const denied = () => {
  throw new HttpsError("permission-denied", "Acesso restrito.");
};

function customer(request, verified = false) {
  const auth = request.auth;
  if (!auth || !auth.uid) denied();
  const roles = auth.token.roles || [];
  if (roles.length || (verified && !verifiedCustomerToken(auth.token))) denied();
  return auth.uid;
}
function administrator(request) {
  if (!request.auth || request.auth.token.firebase?.sign_in_provider === "anonymous" ||
      !Array.isArray(request.auth.token.roles) ||
      !request.auth.token.roles.includes("superadmin")) denied();
  return request.auth.uid;
}
function requestKey(request, uid) {
  if (!/^[A-Za-z0-9_-]{16,100}$/.test(request.data?.requestId || "")) {
    throw new HttpsError("invalid-argument", "Tentativa inválida.");
  }
  return fingerprint([uid, request.data.requestId]);
}
function safeError(error) {
  if (error instanceof HttpsError) throw error;
  throw new HttpsError("failed-precondition", error.code === "OUT_OF_RANGE" ?
    "Este endereço está fora da área de entrega disponível no momento." :
    "Não foi possível calcular a entrega agora. Tente novamente.",
  {reason: error.code || "DELIVERY_UNAVAILABLE"});
}

async function saveVersion(db, request) {
  const uid = administrator(request);
  if ((await db.collection("couriers").doc(uid).get()).exists) denied();
  const id = requestKey(request, uid);
  let table = request.data.table;
  if (!table || !Array.isArray(table.bands) || table.bands.length > 300 ||
      JSON.stringify(table).length > 100000 ||
      Object.keys(table).some((key) => !["bands", "minimumPolicy", "origin",
        "schemaVersion", "maxDistanceMeters"].includes(key))) {
    throw new HttpsError("invalid-argument", "Tabela inválida.");
  }
  if (table.minimumPolicy !== "replace") {
    throw new HttpsError("invalid-argument", "A tabela oficial não aplica piso adicional de R$ 8,00.");
  }
  // Strip unknown band/origin fields, keeping a versioned canonical contract.
  table = canonicalTable(table);
  table = {schemaVersion: 2, minimumPolicy: "replace", maxDistanceMeters: table.maxDistanceMeters ?? null,
    origin: point(table.origin) ? {latitude: table.origin.latitude, longitude: table.origin.longitude} : null,
    bands: table.bands.map((b) => ({minExclusiveMeters: b.minExclusiveMeters ?? null,
      maxInclusiveMeters: b.maxInclusiveMeters ?? null, priceCents: b.priceCents ?? null,
      enabled: b.enabled === true, order: b.order ?? null}))};
  const publish = request.data.publish === true;
  if (publish) {
    try {
      validateTable(table);
    } catch (e) {
      throw new HttpsError("failed-precondition", "Revise faixas, preços, sequência e alcance da tabela.");
    }
    if (!point(table.origin)) {
      throw new HttpsError("failed-precondition", "Confirme a origem real da loja.");
    }
  }
  const ref = db.collection("deliveryPricingVersions").doc(id);
  const content = fingerprint({table, publish});
  return db.runTransaction(async (tx) => {
    const currentRef = db.collection("deliveryConfiguration").doc("current");
    const current = (await tx.get(currentRef)).data() || {};
    const old = await tx.get(ref);
    if (old.exists) {
      if (old.data().fingerprint !== content) {
        throw new HttpsError("already-exists", "Tentativa já utilizada.");
      }
      // A retry must never reactivate an older, superseded publication.
      return {version: id, published: publish, active: current.activeVersion === id};
    }
    const timestamp = FieldValue.serverTimestamp();
    tx.set(ref, {table, version: id, status: publish ? "published" : "draft",
      published: publish, fingerprint: content, maxDistanceMeters: table.maxDistanceMeters,
      authorUid: uid, createdBy: uid, createdAt: timestamp, updatedAt: timestamp,
      publishedAt: publish ? timestamp : null, publishedBy: publish ? uid : null});
    if (!publish) {
      tx.set(db.collection("deliveryConfiguration").doc("draft"),
          {draftVersion: id, updatedAt: timestamp, updatedBy: uid});
    }
    if (publish) {
      // No duplicate radius field: resolve maxDistanceMeters from this version.
      tx.set(currentRef, {...current, mode: "routeBands", activeVersion: id,
        activatedAt: current.activatedAt || timestamp, updatedAt: timestamp, updatedBy: uid});
    }
    return {version: id, published: publish, active: publish};
  });
}

async function quoteDelivery(db, request, provider = new RoutingProvider()) {
  const uid = customer(request);
  if ((await db.collection("couriers").doc(uid).get()).exists) denied();
  const id = requestKey(request, uid);
  const config = (await db.collection("deliveryConfiguration").doc("current").get()).data();
  if (!config) safeError({code: "DELIVERY_CONFIGURATION_MISSING"});
  if (config.mode === "legacy") return {mode: "legacy", deliveryFee: 10};
  if (config.mode !== "routeBands") throw new HttpsError("failed-precondition", "Entrega indisponível.");
  const supplied = request.data.destination;
  const destination = supplied && {latitude: supplied.latitude, longitude: supplied.longitude,
    countryCode: supplied.countryCode, confirmed: supplied.confirmed};
  if (!point(destination) || destination.confirmed !== true || !["BR", "PY"].includes(destination.countryCode)) {
    throw new HttpsError("invalid-argument", "Confirme o destino da entrega.");
  }
  const doc = await db.collection("deliveryPricingVersions").doc(config.activeVersion).get();
  if (!doc.exists || !doc.data().published) throw new HttpsError("failed-precondition", "Entrega indisponível.");
  const table = doc.data().table;
  // Historical floor tables may be read for old finance, never quoted for new deliveries.
  if (!table || table.minimumPolicy !== "replace") safeError({code: "LEGACY_MINIMUM_NOT_ALLOWED"});
  if (provider == null) {
    provider = new GoogleRoutesProvider({apiKey: routesApiKey.value(),
      travelMode: config.travelMode});
  }
  const ref = db.collection("deliveryQuotes").doc(id);
  const hash = fingerprint([uid, config.activeVersion, destination]);
  const previous = await ref.get();
  if (previous.exists) {
    const value = previous.data();
    if (value.fingerprint !== hash || value.expiresAtMs <= Date.now()) {
      throw new HttpsError("failed-precondition", "Atualize a cotação de entrega.");
    }
    return {mode: "routeBands", quoteId: id, deliveryFee: value.feeCents / 100,
      distanceMeters: value.distanceMeters, version: value.version,
      routingProvider: value.provider, quotedAtMs: value.createdAtMs, expiresAtMs: value.expiresAtMs};
  }
  let quote;
  try {
    quote = await buildQuote({table, provider, origin: table.origin,
      destination, uid, version: config.activeVersion});
  } catch (e) {
    safeError(e);
  }
  await db.runTransaction(async (tx) => {
    const active = (await tx.get(db.collection("deliveryConfiguration").doc("current"))).data();
    if (active?.mode !== "routeBands" || active.activeVersion !== config.activeVersion) {
      throw new HttpsError("failed-precondition", "Atualize a cotação de entrega.");
    }
    const current = await tx.get(ref);
    if (current.exists) {
      if (current.data().fingerprint !== hash) throw new HttpsError("already-exists", "Tentativa já utilizada.");
      quote = current.data();
    } else tx.set(ref, {...quote, fingerprint: hash});
  });
  return {mode: "routeBands", quoteId: id, deliveryFee: quote.feeCents / 100,
    distanceMeters: quote.distanceMeters, version: quote.version,
    routingProvider: quote.provider, quotedAtMs: quote.createdAtMs, expiresAtMs: quote.expiresAtMs};
}

async function prepareDelivery(tx, db, orderRef, order, legacyFeeCents = 1000) {
  const configDoc = await tx.get(db.collection("deliveryConfiguration").doc("current"));
  const config = configDoc.exists ? configDoc.data() : null;
  if (!config && order.customerFlowVersion === 2) throw new Error("DELIVERY_CONFIGURATION_MISSING");
  if (!config || config.mode === "legacy") return {feeCents: legacyFeeCents};
  if (config.mode !== "routeBands" || !/^[a-f0-9]{64}$/.test(order.deliveryQuoteId || "")) {
    throw new Error("DELIVERY_QUOTE_REQUIRED");
  }
  const ref = db.collection("deliveryQuotes").doc(order.deliveryQuoteId);
  const quote = (await tx.get(ref)).data();
  const snapshot = validateQuote(quote, order, orderRef.id);
  const active = await tx.get(db.collection("deliveryPricingVersions").doc(config.activeVersion));
  const table = active.data()?.table;
  if (!active.exists || !active.data().published || table?.minimumPolicy !== "replace") {
    throw new Error("DELIVERY_CONFIGURATION_INVALID");
  }
  // Revalidate the private server quote against the active published table.
  // A changed table/origin requires a fresh route; client prices/distances never count.
  const feeCents = priceForDistance(table, quote.distanceMeters);
  if (quote.version !== config.activeVersion || feeCents !== quote.feeCents ||
      quote.origin.latitude !== table.origin?.latitude || quote.origin.longitude !== table.origin?.longitude) {
    throw new Error("DELIVERY_QUOTE_REFRESH_REQUIRED");
  }
  return {feeCents, snapshot, quoteRef: ref};
}

function createDeliveryFunctions(db) {
  return {
    chamaeDescartarPropostaPedido: onCall(options, (r) => discardProposal(db, r)),
    chamaeSalvarConfiguracaoEntrega: onCall(options, (r) => saveVersion(db, r)),
    chamaeCotarEntrega: onCall({...options, secrets: [routesApiKey]}, (r) => quoteDelivery(db, r, null)),
    chamaeAtivarConfiguracaoEntrega: onCall(options, (r) => {
      administrator(r);
      throw new HttpsError("failed-precondition",
          "A versão ativa é definida pela publicação explícita de uma configuração válida.");
    }),
  };
}
async function discardProposal(db, request) {
  const uid = customer(request);
  if ((await db.collection("couriers").doc(uid).get()).exists) denied();
  const id = request.data?.orderDocumentId;
  if (!/^[A-Za-z0-9]{20}$/.test(id || "")) {
    throw new HttpsError("invalid-argument", "Pedido inválido.");
  }
  const orderRef = db.collection("orders").doc(id);
  const workspace = db.collection("customerWorkspaces").doc(uid);
  const cancelled = db.collection(`customerOrderCancellations/${uid}/orders`).doc(id);
  return db.runTransaction(async (tx) => {
    const order = await tx.get(orderRef);
    const state = await tx.get(workspace);
    const lock = await tx.get(cancelled);
    if (order.exists) {
      if (order.data().customerUid !== uid) denied();
      return {cancelled: false, exists: true};
    }
    if (lock.exists) {
      if (state.data()?.pending?.documentId === id) {
        tx.set(workspace, {pending: null}, {merge: true});
      }
      return {cancelled: true, exists: false};
    }
    if (state.data()?.pending?.documentId !== id) {
      throw new HttpsError("failed-precondition", "Proposta indisponível.");
    }
    // This tombstone and Rules prevent a previously queued client write from
    // arriving after cancellation. It does not cancel an existing order.
    tx.set(cancelled, {uid, at: FieldValue.serverTimestamp()});
    tx.set(workspace, {pending: null}, {merge: true});
    return {cancelled: true, exists: false};
  });
}
module.exports = {customer, administrator, saveVersion, quoteDelivery,
  prepareDelivery, createDeliveryFunctions, discardProposal};
