const {test} = require("node:test");
const assert = require("node:assert/strict");
const {validateTable, priceForDistance, subdivide100, RoutingProvider,
  buildQuote, validateQuote} = require("../delivery-pricing");
const {administrator, customer, saveVersion, discardProposal} = require("../delivery-service");
const {generatePin, encryptPin, decryptPin, newOrderVerifier, checkAttempt} = require("../delivery-pin");
const {ownPin} = require("../customer-security");

const origin = {latitude: -20, longitude: -50}; // Synthetic test coordinates, NOT the store.
const destination = {latitude: -20.01, longitude: -50.01, countryCode: "BR", confirmed: true};
const table = () => ({minimumPolicy: "replace", origin, bands: [
  {fromMeters: 0, toMeters: 1100, feeCents: 450, status: "active"},
  {fromMeters: 1100, toMeters: 3000, feeCents: 725, status: "active"},
]}); // Synthetic prices only. Never runtime configuration.
const auth = (roles = [], provider = "password", verified = true) => ({uid: "customer", token: {
  roles, customerVerified: verified, auth_time: Date.now() / 1000,
  firebase: {sign_in_provider: provider},
}});
const memory = () => {
  const docs = new Map();
  const db = {collection: (collection) => ({doc: (id = "audit") => ({id, path: `${collection}/${id}`}),
    where: () => ({where: () => ({limit: () => ({query: true})})})}),
  runTransaction: async (fn) => {
    const writes = [];
    const result = await fn({get: async (ref) => {
      assert.equal(writes.length, 0);
      if (ref.query) return {empty: true};
      return {exists: docs.has(ref.path), data: () => docs.get(ref.path)};
    }, set: (ref, data, options) => writes.push([ref.path,
      options?.merge ? {...docs.get(ref.path), ...data} : data])});
    for (const [path, data] of writes) docs.set(path, data);
    return result;
  }};
  // Also supply direct get for courier-account exclusion.
  const collection = db.collection;
  db.collection = (name) => {
    const c = collection(name); const doc = c.doc;
    c.doc = (id) => {
      const ref = doc(id);
      ref.get = async () => ({exists: docs.has(ref.path), data: () => docs.get(ref.path)});
      return ref;
    };
    return c;
  };
  return {db, docs};
};

test("bands: inclusive edge, +1m, fractional real distance, non-cumulative price", () => {
  assert.equal(priceForDistance(table(), 1100), 450);
  assert.equal(priceForDistance(table(), 1101), 725);
  assert.equal(priceForDistance(table(), 1100.01), 725);
  assert.equal(priceForDistance(table(), 2300), 725);
  assert.throws(() => priceForDistance(table(), 3000.1), /OUT_OF_RANGE/);
  const max = table(); max.bands[1].toMeters = 30000;
  assert.equal(priceForDistance(max, 30000), 725);
  assert.throws(() => priceForDistance(max, 30001), /OUT_OF_RANGE/);
});
test("bands: no gaps, overlap, negative, reversed, invalid price or >30km", () => {
  for (const change of [{fromMeters: 1101}, {fromMeters: 1099}, {toMeters: 30001},
    {toMeters: 1000}, {feeCents: -1}, {feeCents: NaN}, {feeCents: null}, {status: "draft"}]) {
    const t = table(); Object.assign(t.bands[1], change);
    assert.throws(() => validateTable(t));
  }
  const t = table(); t.bands[0].fromMeters = -1;
  assert.throws(() => validateTable(t));
});
test("100m subdivisions are drafts and keep the previous complete price", () => {
  const rows = subdivide100({fromMeters: 1000, toMeters: 1300, feeCents: 1234, status: "active"});
  assert.equal(rows.length, 3);
  assert.deepEqual(rows.map((r) => r.toMeters), [1100, 1200, 1300]);
  assert.ok(rows.every((r) => r.status === "draft" && r.feeCents === 1234));
});
test("pending and historical floor cannot price new deliveries", () => {
  const t = table(); t.minimumPolicy = "pending";
  assert.throws(() => validateTable(t), /MINIMUM_POLICY_PENDING/);
  t.minimumPolicy = "floor800";
  assert.throws(() => priceForDistance(t, 2000), /MINIMUM_POLICY_PENDING/);
  t.minimumPolicy = "replace";
  assert.equal(priceForDistance(t, 2000), 725);
});
test("route provider fake; failure and unconfigured provider never fall back to straight line", async () => {
  const args = {table: table(), origin, destination, uid: "customer", version: "v1", now: 100};
  const q = await buildQuote({...args, provider: {route: async () => ({
    status: "ok", distanceMeters: 2300, provider: "test-route"})}});
  assert.equal(q.feeCents, 725); assert.equal(q.distanceMeters, 2300);
  await assert.rejects(buildQuote({...args, provider: new RoutingProvider()}), /NOT_CONFIGURED/);
  await assert.rejects(buildQuote({...args, provider: {route: async () => ({status: "error"})}}), /ROUTE_UNAVAILABLE/);
});
test("frozen quote ignores forged client fee; owner, destination, expiration and reuse are bound", async () => {
  const q = await buildQuote({table: table(), origin, destination, uid: "customer", version: "v1", now: 100,
    provider: {route: async () => ({status: "ok", distanceMeters: 2300, provider: "test-route"})}});
  const order = {customerUid: "customer", deliveryAddress: destination, deliveryFee: 99999};
  const frozen = validateQuote(q, order, "o1", 200);
  assert.equal(frozen.deliveryFee, 7.25); assert.equal(frozen.configurationVersion, "v1");
  const newer = table(); newer.bands[1].feeCents = 5000;
  assert.equal(frozen.deliveryFee, 7.25);
  assert.throws(() => validateQuote(q, {...order, customerUid: "other"}, "o1", 200));
  assert.throws(() => validateQuote(q, {...order, deliveryAddress: {...destination, latitude: 0}}, "o1", 200));
  assert.throws(() => validateQuote(q, order, "o1", 999999));
  assert.throws(() => validateQuote({...q, expiresAtMs: undefined}, order, "o1", 200));
  assert.throws(() => validateQuote({...q, orderId: "o1"}, order, "o2", 200));
});
test("config is superadmin-only; immutable publication is idempotent and updates the active pointer", async () => {
  for (const roles of [[], ["operations_admin"], ["finance"], ["catalog_admin"]]) {
    assert.throws(() => administrator({auth: auth(roles)}));
  }
  assert.throws(() => administrator({auth: auth(["superadmin"], "anonymous")}));
  const {db, docs} = memory();
  const request = {auth: auth(["superadmin"]), data: {table: table(), publish: true, requestId: "a".repeat(24)}};
  const first = await saveVersion(db, request); const second = await saveVersion(db, request);
  assert.deepEqual(first, second); assert.equal(docs.size, 2); assert.equal(first.active, true);
  assert.equal(docs.get("deliveryConfiguration/current").activeVersion, first.version);
  assert.equal([...docs.values()][0].authorUid, "customer");
  await assert.rejects(saveVersion(db, {...request,
    data: {...request.data, table: {...table(), minimumPolicy: "floor800"}}}));
});
test("verification requires trusted claim and non-anonymous identity", () => {
  assert.equal(customer({auth: auth()}, true), "customer");
  assert.throws(() => customer({auth: auth([], "anonymous")}, true));
  assert.throws(() => customer({auth: auth([], "password", false)}, true));
});

test("discard: atomic tombstone blocks late creation and preserves cart", async () => {
  const {db, docs} = memory(); const id = "o".repeat(20);
  docs.set("customerWorkspaces/customer", {pending: {documentId: id}, cart: [{id: "p1"}]});
  const request = {auth: auth(), data: {orderDocumentId: id}};
  assert.deepEqual(await discardProposal(db, request), {cancelled: true, exists: false});
  assert.equal(docs.get("customerWorkspaces/customer").pending, null);
  assert.deepEqual(docs.get("customerWorkspaces/customer").cart, [{id: "p1"}]);
  assert.ok(docs.has(`customerOrderCancellations/customer/orders/${id}`));
  // A previously queued workspace save can arrive after the first response.
  docs.get("customerWorkspaces/customer").pending = {documentId: id};
  assert.deepEqual(await discardProposal(db, request), {cancelled: true, exists: false});
  assert.equal(docs.get("customerWorkspaces/customer").pending, null);
});

test("discard: existing order is retained; foreign/missing proposal is denied", async () => {
  const {db, docs} = memory(); const id = "o".repeat(20);
  const request = {auth: auth(), data: {orderDocumentId: id}};
  await assert.rejects(discardProposal(db, request));
  docs.set(`orders/${id}`, {customerUid: "foreign"});
  await assert.rejects(discardProposal(db, request));
  docs.set(`orders/${id}`, {customerUid: "customer"});
  assert.deepEqual(await discardProposal(db, request), {cancelled: false, exists: true});
  assert.equal(docs.size, 1);
});
test("PIN generation, encryption, per-order verifier, attempt limit and reconciliation", () => {
  const key = "a".repeat(64);
  for (let i = 0; i < 100; i++) assert.match(generatePin(), /^\d{4}$/);
  const secret = encryptPin("0123", "u1", key);
  assert.equal(decryptPin(secret, "u1", key), "0123");
  assert.throws(() => decryptPin(secret, "other", key));
  assert.throws(() => encryptPin("0123", "u1", ""));
  let record = newOrderVerifier("0123", "u1", "order1", key);
  assert.notEqual(record.digest, newOrderVerifier("0123", "u1", "order2", key).digest);
  for (let i = 0; i < 5; i++) record = checkAttempt(record, "9999", "u1", "order1", key).record;
  assert.equal(checkAttempt(record, "0123", "u1", "order1", key).allowed, false);
  assert.equal(checkAttempt({...record, attempts: -1}, "0123", "u1", "order1", key).allowed, false);
  const valid = checkAttempt(newOrderVerifier("0123", "u1", "order1", key), "0123", "u1", "order1", key);
  assert.equal(valid.matched, true); assert.equal(valid.record.reconciled, true);
  assert.equal(checkAttempt(valid.record, "0123", "u1", "order1", key).allowed, false);
});
test("PIN creation/reset persist encrypted data and audit, never a plaintext courier value", async () => {
  const {db, docs} = memory(); const request = {auth: auth()};
  const first = await ownPin(db, request, "b".repeat(64));
  assert.match(first.pin, /^\d{4}$/);
  const saved = docs.get("customerDeliverySecrets/customer");
  assert.equal(saved.pin, undefined); assert.ok(saved.encrypted);
  assert.equal(docs.get("deliveryPinAudit/audit").operation, "created");
  await ownPin(db, request, "b".repeat(64), true);
  assert.equal(docs.get("customerDeliverySecrets/customer").revision, 2);
  assert.equal(docs.get("deliveryPinAudit/audit").operation, "reset");
  await assert.rejects(ownPin(db, {auth: {...auth(), token: {...auth().token, auth_time: 1}}}, "b".repeat(64), true));
});
