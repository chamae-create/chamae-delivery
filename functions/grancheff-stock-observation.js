"use strict";
// Additive receiver for the EXISTING read-only POC contract. No Oracle adapter,
// price selection, product creation, stock projection or public/cloud endpoint.
const {createHash} = require("node:crypto");
const {isCommerciallyBlocked, categoryReviewRequired} =
    require("./catalog-commercial-policy");
const digest = (value) => createHash("sha256").update(JSON.stringify(value)).digest("hex");
const fail = (reason) => {throw Error(reason);};
const id = (value) => typeof value === "string" && /^[A-Za-z0-9_-]{1,128}$/.test(value);
const exact = (value, keys) => value && typeof value === "object" &&
  !Array.isArray(value) && Object.keys(value).sort().join(",") === [...keys].sort().join(",");

function normalize(input, policy) {
  if (!exact(input, ["schemaVersion", "sourceId", "storeId", "sequence", "product"]) ||
      input.schemaVersion !== 1 || !id(input.sourceId) || !id(input.storeId) ||
      input.sourceId !== policy.sourceId || input.storeId !== policy.storeId ||
      !Number.isSafeInteger(input.sequence) || input.sequence < 1) fail("INVALID_OBSERVATION_ENVELOPE");
  const p = input.product;
  if (!exact(p, ["sourceProductId", "barcode", "name", "rawPhysicalStock",
    "availablePhysicalStock", "source", "syncedAt"]) || p.source !== "grancheff" ||
      !Number.isInteger(p.sourceProductId) || p.sourceProductId < 1 || p.sourceProductId > 999999 ||
      ![p.name, p.barcode].every(v => v === null || typeof v === "string" && v.length <= 512) ||
      p.rawPhysicalStock !== null && (typeof p.rawPhysicalStock !== "number" || !Number.isFinite(p.rawPhysicalStock)) ||
      p.availablePhysicalStock !== (p.rawPhysicalStock === null ? null : Math.max(0, p.rawPhysicalStock)) ||
      typeof p.syncedAt !== "string" || !/^\d{4}-\d\d-\d\dT\d\d:\d\d:\d\d(?:\.\d{1,7})?Z$/.test(p.syncedAt) ||
      !Number.isFinite(Date.parse(p.syncedAt))) fail("INVALID_BRIDGE_SNAPSHOT");
  // Fixed field order makes a replay independent of JSON object key order.
  return {schemaVersion: 1, sourceId: input.sourceId, storeId: input.storeId,
    sequence: input.sequence, product: {sourceProductId: p.sourceProductId,
      barcode: p.barcode, name: p.name, rawPhysicalStock: p.rawPhysicalStock,
      availablePhysicalStock: p.availablePhysicalStock, source: p.source, syncedAt: p.syncedAt}};
}

async function receiveObservation(db, input, policy) {
  // This stage deliberately cannot write to a real Firebase project. The future
  // authenticated sender, durable sequence/outbox and rules require separate review.
  const env = process.env;
  if (env.FIRESTORE_EMULATOR_HOST !== "127.0.0.1:8341" ||
      env.GCLOUD_PROJECT !== "demo-chamae-maximo" ||
      db.projectId !== "demo-chamae-maximo") fail("LOCAL_OBSERVATION_EMULATOR_ONLY");
  if (!policy || !Number.isSafeInteger(policy.nowMs) ||
      !Number.isSafeInteger(policy.maxReadAgeMs) || policy.maxReadAgeMs < 1) fail("EXPLICIT_READ_FRESHNESS_REQUIRED");
  const observation = normalize(input, policy);
  const code = observation.product.sourceProductId;
  const key = digest([observation.storeId, observation.sourceId, code]);
  const fingerprint = digest(observation);
  const cursorRef = db.collection("grancheffStockObservations").doc(key);
  const receiptRef = cursorRef.collection("receipts").doc(String(observation.sequence));
  return db.runTransaction(async tx => {
    const receipt = await tx.get(receiptRef);
    if (receipt.exists) {
      if (receipt.data().fingerprint !== fingerprint) fail("OBSERVATION_SEQUENCE_CONFLICT");
      return {...receipt.data().ack, replayed: true};
    }
    const cursor = await tx.get(cursorRef);
    if (cursor.exists && observation.sequence <= cursor.data().sequence) fail("OBSERVATION_OUT_OF_ORDER");
    const observedAtMs = Date.parse(observation.product.syncedAt);
    if (observedAtMs > policy.nowMs || policy.nowMs - observedAtMs > policy.maxReadAgeMs) fail("OBSERVATION_STALE_OR_FUTURE");
    if (cursor.exists && observedAtMs < cursor.data().observedAtMs) fail("OBSERVATION_TIME_REGRESSION");
    const matches = await tx.get(db.collection("products")
        .where("PRO_CODIGO", "in", [code, String(code)]).limit(2));
    if (matches.size !== 1) fail(matches.empty ? "PRODUCT_MAPPING_MISSING" : "PRODUCT_MAPPING_DUPLICATE");
    const product = matches.docs[0], data = product.data();
    if (isCommerciallyBlocked({...data, id: product.id}) ||
        categoryReviewRequired(data)) fail("RESTRICTED_OR_UNCLASSIFIED_NO_SYNC");
    if (data.synthetic === true || /^hml-/i.test(product.id)) fail("SYNTHETIC_NOT_COMMERCIAL");
    if (cursor.exists && cursor.data().productId !== product.id) fail("PRODUCT_MAPPING_CHANGED");
    const raw = observation.product.rawPhysicalStock;
    const issues = ["PHYSICAL_CONCURRENCY_UNCONFIRMED", "PRICE_UNCONFIRMED"];
    if (raw === null) issues.push("UNKNOWN_OPERATIONAL_BALANCE");
    else if (raw <= 0) issues.push("OPERATIONAL_BALANCE_NONPOSITIVE");
    else if (!Number.isSafeInteger(raw)) issues.push("PRODUCT_UNIT_UNCONFIRMED");
    if (raw !== null && observation.product.availablePhysicalStock !== data.stock) issues.push("BALANCE_DIVERGENCE");
    if (!Number.isSafeInteger(data.reservedStock) || data.reservedStock < 0) issues.push("INVALID_RESERVED_STOCK");
    else if (raw !== null && data.reservedStock > observation.product.availablePhysicalStock) issues.push("RESERVATIONS_EXCEED_OBSERVED_BALANCE");
    const ack = {schemaVersion: 1, sequence: observation.sequence, sourceProductId: code,
      productId: product.id, fingerprint, accepted: true, sellable: false, issues};
    // Never update products or orders: receipts acknowledge OBSERVATION only.
    tx.set(cursorRef, {sequence: observation.sequence, productId: product.id,
      sourceId: observation.sourceId, storeId: observation.storeId, observedAtMs,
      receivedAtMs: policy.nowMs, observation, fingerprint, sellable: false, issues});
    tx.create(receiptRef, {fingerprint, ack, receivedAtMs: policy.nowMs});
    return {...ack, replayed: false};
  });
}
module.exports = {receiveObservation};
