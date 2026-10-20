const {createHash} = require("node:crypto");

class DeliveryError extends Error {
  constructor(code) {
    super(code); this.code = code;
  }
}
const fail = (code) => {
  throw new DeliveryError(code);
};
const point = (p) => p && Number.isFinite(p.latitude) &&
  Number.isFinite(p.longitude) && Math.abs(p.latitude) <= 90 &&
  Math.abs(p.longitude) <= 180;

// Old field names are accepted only to read historical versions. All new
// saves use schemaVersion 2, without a fixed minimum surcharge.
function canonicalTable(table) {
  if (!table || !Array.isArray(table.bands)) fail("INVALID_BANDS");
  if (table.schemaVersion === 2 || table.bands.some((b) => b && "maxInclusiveMeters" in b)) return table;
  return {schemaVersion: 2, minimumPolicy: table.minimumPolicy,
    origin: table.origin ?? null,
    maxDistanceMeters: table.bands.at(-1)?.toMeters,
    bands: table.bands.map((b, order) => ({minExclusiveMeters: b.fromMeters,
      maxInclusiveMeters: b.toMeters, priceCents: b.feeCents,
      enabled: b.status === "active", order}))};
}

function validateTable(table) {
  if (!table || !Array.isArray(table.bands) || !table.bands.length ||
      table.bands.length > 300) fail("INVALID_BANDS");
  const legacy = table.schemaVersion !== 2 && !table.bands.some((b) => b && "maxInclusiveMeters" in b);
  if (legacy ? !["replace", "floor800"].includes(table.minimumPolicy) :
    table.minimumPolicy !== "replace") fail("MINIMUM_POLICY_PENDING");
  const canonical = canonicalTable(table);
  if (!Number.isSafeInteger(canonical.maxDistanceMeters) ||
      canonical.maxDistanceMeters <= 0 || canonical.maxDistanceMeters > 30000) fail("INVALID_MAX_DISTANCE");
  let end = 0;
  for (const [index, band] of canonical.bands.entries()) {
    if (!band || !Number.isSafeInteger(band.minExclusiveMeters) ||
        !Number.isSafeInteger(band.maxInclusiveMeters) || band.minExclusiveMeters !== end ||
        band.minExclusiveMeters < 0 || band.maxInclusiveMeters <= band.minExclusiveMeters ||
        band.maxInclusiveMeters > 30000 || band.order !== index) fail("GAP_OVERLAP_OR_INVALID_LIMIT");
    if (!Number.isSafeInteger(band.priceCents) || band.priceCents < 0 ||
        band.enabled !== true) fail("INVALID_PRICE_OR_DRAFT");
    end = band.maxInclusiveMeters;
  }
  if (end !== canonical.maxDistanceMeters) fail("INVALID_MAX_DISTANCE");
  return table;
}

function priceForDistance(table, meters) {
  validateTable(table);
  if (!Number.isFinite(meters) || meters < 0) fail("INVALID_DISTANCE");
  const canonical = canonicalTable(table);
  // The validated active table is the only operational radius, never a separate setting.
  if (meters > canonical.maxDistanceMeters) fail("OUT_OF_RANGE");
  // Compare the original distance, before any visual rounding.
  const band = canonical.bands.find((b) => meters <= b.maxInclusiveMeters &&
    (meters > b.minExclusiveMeters || b.minExclusiveMeters === 0));
  if (!band) fail("OUT_OF_RANGE");
  // Compatibility for immutable historical versions only. New saves reject floor800.
  return table.schemaVersion !== 2 && table.minimumPolicy === "floor800" ?
    Math.max(800, band.priceCents) : band.priceCents;
}

function subdivide100(band) {
  if (!Number.isSafeInteger(band.fromMeters) ||
      !Number.isSafeInteger(band.toMeters) || band.fromMeters < 0 ||
      band.toMeters > 30000 || band.toMeters <= band.fromMeters) {
    fail("INVALID_LIMIT");
  }
  const result = [];
  for (let start = band.fromMeters; start < band.toMeters; start += 100) {
    result.push({...band, fromMeters: start,
      toMeters: Math.min(start + 100, band.toMeters), status: "draft"});
  }
  return result;
}

class RoutingProvider {
  async route() {
    fail("ROUTING_PROVIDER_NOT_CONFIGURED");
  }
}

async function buildQuote({table, provider, origin, destination, uid,
  version, now = Date.now(), ttlMs = 300000}) {
  validateTable(table);
  if (!point(origin) || !point(destination)) fail("INVALID_COORDINATES");
  if (!uid || !version) fail("INVALID_QUOTE_OWNER");
  const route = await provider.route({origin, destination});
  if (!route || route.status !== "ok" ||
      !Number.isFinite(route.distanceMeters) || route.distanceMeters < 0) {
    fail("ROUTE_UNAVAILABLE");
  }
  const feeCents = priceForDistance(table, route.distanceMeters);
  return {uid, version, origin, destination, feeCents,
    distanceMeters: route.distanceMeters,
    durationSeconds: Number.isFinite(route.durationSeconds) &&
      route.durationSeconds >= 0 ? route.durationSeconds : null,
    provider: String(route.provider || "configured").slice(0, 60),
    createdAtMs: now, expiresAtMs: now + ttlMs};
}

const fingerprint = (value) => createHash("sha256")
    .update(JSON.stringify(value)).digest("hex");
const samePoint = (a, b) => point(a) && point(b) &&
  a.latitude === b.latitude && a.longitude === b.longitude;

function validateQuote(quote, order, orderId, now = Date.now()) {
  if (!quote || quote.uid !== order.customerUid ||
      !samePoint(quote.destination, order.deliveryAddress) ||
      quote.destination.countryCode !== order.deliveryAddress.countryCode ||
      !Number.isSafeInteger(quote.feeCents) || quote.feeCents < 0 ||
      !Number.isFinite(quote.distanceMeters) || quote.distanceMeters > 30000 ||
      quote.distanceMeters < 0 || !quote.version || !point(quote.origin) ||
      !Number.isFinite(quote.createdAtMs) || !Number.isFinite(quote.expiresAtMs) ||
      quote.expiresAtMs <= quote.createdAtMs ||
      (quote.orderId && quote.orderId !== orderId) ||
      (!quote.orderId && quote.expiresAtMs <= now)) fail("INVALID_OR_EXPIRED_QUOTE");
  return {distanceMeters: quote.distanceMeters, deliveryFee: quote.feeCents / 100,
    configurationVersion: quote.version, quotedAtMs: quote.createdAtMs,
    origin: quote.origin, destination: quote.destination,
    routingProvider: quote.provider || "legacy-configured"};
}

module.exports = {DeliveryError, canonicalTable, validateTable, priceForDistance, subdivide100,
  RoutingProvider, buildQuote, validateQuote, fingerprint, point};
