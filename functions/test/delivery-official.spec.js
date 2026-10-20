const {test} = require("node:test");
const assert = require("node:assert/strict");
const initial = require("../config/delivery-pricing-initial.json");
const {validateTable, priceForDistance} = require("../delivery-pricing");
const {saveVersion, quoteDelivery, prepareDelivery, createDeliveryFunctions} = require("../delivery-service");
const {GoogleRoutesProvider} = require("../google-routes-provider");
const origin = {latitude: -20, longitude: -50}; // Synthetic test point, never store coordinates.
const table = () => ({...structuredClone(initial), origin});
const auth = (roles = []) => ({uid: "buyer", token: {roles, firebase: {sign_in_provider: "google.com"}}});
const destination = (countryCode = "BR") => ({latitude: -20.01, longitude: -50.01, countryCode, confirmed: true});
function memory() {
  const docs = new Map();
  const snap = (ref) => ({exists: docs.has(ref.path), data: () => docs.get(ref.path)});
  const db = {collection: (name) => ({doc: (id) => {
    const ref = {id, path: `${name}/${id}`};
    ref.get = async () => snap(ref); return ref;
  }}), runTransaction: async (fn) => {
    const writes = [];
    const result = await fn({get: async (ref) => {
      assert.equal(writes.length, 0, "reads before writes"); return snap(ref);
    }, set: (ref, data) => writes.push([ref.path, data])});
    for (const [path, data] of writes) docs.set(path, data);
    return result;
  }};
  return {db, docs};
}
const req = (country = "BR", requestId = "q".repeat(24)) => ({auth: auth(), data: {
  destination: destination(country), requestId, deliveryFee: 0.01,
  distanceMeters: 0, version: "forged", origin: {latitude: 0, longitude: 0},
}});
function configured() {
  const f = memory();
  f.docs.set("deliveryConfiguration/current", {mode: "routeBands", activeVersion: "v1", travelMode: "DRIVE"});
  f.docs.set("deliveryPricingVersions/v1", {published: true, status: "published", table: table()});
  return f;
}
const router = (distanceMeters = 8243) => ({route: async () => ({status: "ok", distanceMeters,
  durationSeconds: 100, provider: "google-routes"})});

for (const [meters, cents] of [[0, 600], [1000, 600], [1001, 700], [1500, 700], [1501, 800],
  [8000, 2000], [8001, 2100], [8243, 2100], [10500, 2500], [10501, 2700],
  [14000, 3900], [14001, 4000], [14500, 4000]]) {
  test(`official table: ${meters} m costs ${cents} cents without extra floor`, () => {
    assert.equal(priceForDistance(table(), meters), cents);
  });
}
test("published range is 14500 m; future 30000 m requires an explicit valid table", () => {
  assert.throws(() => priceForDistance(table(), 14501), /OUT_OF_RANGE/);
  assert.throws(() => priceForDistance(table(), 14500.01), /OUT_OF_RANGE/);
  const extended = table();
  extended.bands.push({minExclusiveMeters: 14500, maxInclusiveMeters: 30000,
    priceCents: 5000, enabled: true, order: 28});
  extended.maxDistanceMeters = 30000;
  assert.equal(priceForDistance(extended, 30000), 5000);
  assert.throws(() => priceForDistance(extended, 30001), /OUT_OF_RANGE/);
});
test("official publication validates gaps/overlap/reversal/duplicate/order/negative/disabled/30km/max", () => {
  for (const change of [{minExclusiveMeters: 1001}, {minExclusiveMeters: 999},
    {maxInclusiveMeters: 900}, {priceCents: -1}, {priceCents: 1.1},
    {enabled: false}, {order: 0}, {maxInclusiveMeters: 30001}]) {
    const t = table(); Object.assign(t.bands[1], change); assert.throws(() => validateTable(t));
  }
  const duplicate = table(); duplicate.bands.splice(1, 0, {...duplicate.bands[0]});
  assert.throws(() => validateTable(duplicate));
  assert.throws(() => validateTable({...table(), maxDistanceMeters: 15000}));
  assert.throws(() => validateTable({...table(), minimumPolicy: "floor800"}));
});
test("explicit publication activates an immutable version; draft stays isolated", async () => {
  const {db, docs} = configured(); const activeBefore = structuredClone(docs.get("deliveryConfiguration/current"));
  const request = {auth: auth(["superadmin"]), data: {requestId: "s".repeat(24), table: table()}};
  request.data.table.bands[0].priceCents = 650;
  const draft = await saveVersion(db, request);
  assert.equal(docs.get("deliveryConfiguration/draft").draftVersion, draft.version);
  assert.equal(docs.get(`deliveryPricingVersions/${draft.version}`).status, "draft");
  assert.deepEqual(docs.get("deliveryConfiguration/current"), activeBefore);
  request.data = {...request.data, publish: true, requestId: "p".repeat(24)};
  const published = await saveVersion(db, request);
  assert.deepEqual(await saveVersion(db, request), published);
  const value = docs.get(`deliveryPricingVersions/${published.version}`);
  for (const field of ["version", "status", "createdAt", "updatedAt", "createdBy", "publishedAt", "publishedBy"]) {
    assert.ok(value[field]);
  }
  assert.equal(value.maxDistanceMeters, 14500); assert.equal(published.active, true);
  assert.equal(docs.get("deliveryConfiguration/current").activeVersion, published.version);
  assert.equal(docs.get("deliveryConfiguration/current").travelMode, "DRIVE");
  assert.equal("serviceRadiusMeters" in docs.get("deliveryConfiguration/current"), false);
  request.data.table.bands[0].priceCents = 700;
  await assert.rejects(saveVersion(db, request), /Tentativa/);
});
test("new drafts reject the old floor, require real origin to publish and deny unauthorized roles", async () => {
  const {db} = memory();
  for (const roles of [[], ["finance"], ["operations_admin"], ["catalog_admin"]]) {
    await assert.rejects(saveVersion(db, {auth: auth(roles), data: {table: table(), requestId: "x".repeat(24)}}));
  }
  await assert.rejects(saveVersion(db, {auth: auth(["superadmin"]), data: {
    table: {...table(), minimumPolicy: "floor800"}, requestId: "x".repeat(24)}}));
  await assert.rejects(saveVersion(db, {auth: auth(["superadmin"]), data: {
    table: {...table(), origin: null}, publish: true, requestId: "x".repeat(24)}}));
});
for (const country of ["BR", "PY"]) {
  test(`server quote to ${country}: ignores forged values and freezes original version`, async () => {
    const {db} = configured(); let calls = 0;
    const provider = {route: async (args) => {
      calls++; assert.deepEqual(args.origin, origin);
      assert.equal(args.destination.countryCode, country);
      return router().route();
    }};
    const request = req(country);
    const first = await quoteDelivery(db, request, provider);
    assert.equal(first.deliveryFee, 21); assert.equal(first.distanceMeters, 8243);
    assert.equal(first.version, "v1"); assert.equal(first.routingProvider, "google-routes");
    assert.deepEqual(await quoteDelivery(db, request, provider), first); assert.equal(calls, 1);
    const order = {customerUid: "buyer", deliveryAddress: destination(country), deliveryQuoteId: first.quoteId,
      deliveryFee: 0.01, deliveryDistanceMeters: 0, deliveryPricingVersion: "forged"};
    const frozen = await db.runTransaction((tx) => prepareDelivery(tx, db, {id: "order1"}, order));
    assert.equal(frozen.feeCents, 2100); assert.equal(frozen.snapshot.configurationVersion, "v1");
    assert.equal(frozen.snapshot.routingProvider, "google-routes");
  });
}
test("Routes failure, missing config/table/origin and out of area block without a quote", async () => {
  for (const mode of ["missing", "table", "draft", "floor", "origin", "failure", "range"]) {
    const {db, docs} = configured();
    if (mode === "missing") docs.delete("deliveryConfiguration/current");
    if (mode === "table") docs.delete("deliveryPricingVersions/v1");
    if (mode === "draft") docs.get("deliveryPricingVersions/v1").published = false;
    if (mode === "floor") {
      docs.get("deliveryPricingVersions/v1").table = {
        minimumPolicy: "floor800", origin,
        bands: [{fromMeters: 0, toMeters: 14500, feeCents: 600, status: "active"}],
      };
    }
    if (mode === "origin") docs.get("deliveryPricingVersions/v1").table.origin = null;
    const provider = mode === "failure" ? {route: async () => {
      throw new Error("network");
    }} :
      router(mode === "range" ? 14501 : 1000);
    await assert.rejects(quoteDelivery(db, req(), provider));
    assert.equal([...docs.keys()].some((k) => k.startsWith("deliveryQuotes/")), false);
  }
});
test("new flow without configuration fails closed; historical order keeps existing freight", async () => {
  const {db} = memory();
  await assert.rejects(db.runTransaction((tx) => prepareDelivery(tx, db, {id: "new"}, {customerFlowVersion: 2})));
  assert.equal((await db.runTransaction((tx) => prepareDelivery(tx, db, {id: "old"}, {}, 1000))).feeCents, 1000);
});
test("callable binds dedicated Routes secret; missing credential and Google error never fall back", async () => {
  const f = createDeliveryFunctions(memory().db);
  assert.ok(f.chamaeCotarEntrega.__endpoint.secretEnvironmentVariables.some((s) => s.key === "CHAMAE_ROUTES_API_KEY"));
  for (const response of [{ok: false}, {ok: true, json: async () => ({routes: []})},
    {ok: true, json: async () => ({fallbackInfo: {}, routes: [{distanceMeters: 100}]})}]) {
    const p = new GoogleRoutesProvider({apiKey: "TEST-ONLY", travelMode: "DRIVE", fetchImpl: async () => response});
    await assert.rejects(p.route({origin, destination: destination()}), /ROUTE_UNAVAILABLE/);
  }
  await assert.rejects(new GoogleRoutesProvider({travelMode: "DRIVE"}).route({origin, destination: destination()}));
});

function radiusTable(maxDistanceMeters) {
  const t = table();
  t.bands = t.bands.filter((b) => b.maxInclusiveMeters <= maxDistanceMeters);
  if (maxDistanceMeters > 14500) {
    t.bands.push({minExclusiveMeters: 14500,
      maxInclusiveMeters: maxDistanceMeters, priceCents: 4500, enabled: true, order: 28});
  }
  t.maxDistanceMeters = maxDistanceMeters;
  return t;
}
const publishTable = (db, max, id, publish = true) => saveVersion(db, {
  auth: auth(["superadmin"]), data: {requestId: id.repeat(24), table: radiusTable(max), publish},
});

test("active 14500: inclusive 14500 allowed, 14501 blocked with forged fee/distance", async () => {
  const {db} = configured();
  const edge = await quoteDelivery(db, req(), router(14500));
  assert.equal(edge.distanceMeters, 14500); assert.equal(edge.deliveryFee, 40);
  await assert.rejects(quoteDelivery(db, req("BR", "x".repeat(24)), router(14501)),
      (e) => e.details.reason === "OUT_OF_RANGE" &&
      e.message === "Este endereço está fora da área de entrega disponível no momento.");
});

test("draft 20km ignored; publication expands to 20km then reduces to 12km; retry cannot roll back", async () => {
  const {db, docs} = configured();
  await publishTable(db, 20000, "d", false);
  assert.equal(docs.get("deliveryConfiguration/current").activeVersion, "v1");
  await assert.rejects(quoteDelivery(db, req(), router(14501)), (e) => e.details.reason === "OUT_OF_RANGE");
  const expanded = await publishTable(db, 20000, "e");
  assert.equal(docs.get("deliveryConfiguration/current").activeVersion, expanded.version);
  assert.equal((await quoteDelivery(db, req(), router(14501))).deliveryFee, 45);
  const reduced = await publishTable(db, 12000, "r");
  assert.equal(docs.get("deliveryConfiguration/current").activeVersion, reduced.version);
  await assert.rejects(quoteDelivery(db, req("BR", "z".repeat(24)), router(12001)),
      (e) => e.details.reason === "OUT_OF_RANGE");
  assert.equal((await quoteDelivery(db, req("BR", "y".repeat(24)), router(12000))).distanceMeters, 12000);
  await publishTable(db, 20000, "e");
  assert.equal(docs.get("deliveryConfiguration/current").activeVersion, reduced.version);
});

test("acceptance rechecks active radius; pre-reduction quote and forged freight cannot bypass", async () => {
  const {db} = configured();
  const q = await quoteDelivery(db, req(), router(14500));
  await publishTable(db, 12000, "r");
  const order = {customerUid: "buyer", deliveryAddress: destination(), deliveryQuoteId: q.quoteId,
    deliveryFee: 0.01, deliveryDistanceMeters: 1, deliveryPricingVersion: "forged",
    createdAt: {toMillis: () => 1}};
  await assert.rejects(db.runTransaction((tx) => prepareDelivery(tx, db, {id: "new"}, order)), /OUT_OF_RANGE/);
});

test("new unconfirmed order requires active quote version even when both radii include its destination", async () => {
  const {db} = configured();
  const q = await quoteDelivery(db, req(), router(1000));
  await publishTable(db, 20000, "e");
  await assert.rejects(db.runTransaction((tx) => prepareDelivery(tx, db, {id: "new"}, {
    customerUid: "buyer", deliveryAddress: destination(), deliveryQuoteId: q.quoteId,
  })), /REFRESH_REQUIRED/);
});

test("publication racing with Routes invalidates the in-flight quote", async () => {
  const {db, docs} = configured();
  await assert.rejects(quoteDelivery(db, req(), {route: async () => {
    await publishTable(db, 12000, "r"); return router(14500).route();
  }}));
  assert.equal([...docs.keys()].some((k) => k.startsWith("deliveryQuotes/")), false);
});
