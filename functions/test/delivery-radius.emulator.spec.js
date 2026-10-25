const assert = require("node:assert/strict");
const {test, before, after} = require("node:test");
const {initializeApp, deleteApp} = require("firebase-admin/app");
const {getFirestore} = require("firebase-admin/firestore");
const {saveVersion, quoteDelivery: realQuoteDelivery, prepareDelivery} =
    require("../delivery-service");
const {countryVerifier} = require("./operational-fixture");
const quoteDelivery = (db, request, provider) =>
  realQuoteDelivery(db, request, provider, countryVerifier);
let app; let db;
const origin = {latitude: -20, longitude: -50}; // Synthetic fixture only.
const destination = {...origin, countryCode: "BR", confirmed: true};
const table = (max) => ({schemaVersion: 2, minimumPolicy: "replace",
  maxDistanceMeters: max, origin, bands: [{minExclusiveMeters: 0,
    maxInclusiveMeters: max, priceCents: 600, enabled: true, order: 0}]});
const request = (id, max, publish) => ({auth: {uid: "radius-admin",
  token: {roles: ["superadmin"]}}, data: {requestId: id.repeat(24),
  table: table(max), publish}});
before(() => {
  assert.equal(process.env.FIRESTORE_EMULATOR_HOST, "127.0.0.1:8187");
  app = initializeApp({projectId: "demo-chamae-rules"}, "radius-tests");
  db = getFirestore(app);
});
after(async () => {
  if (db) await db.terminate();
  if (app) await deleteApp(app);
});
test("Firestore transaction: draft, publication and radius", async () => {
  const activeRef = db.doc("deliveryConfiguration/current");
  await activeRef.set({mode: "legacy", travelMode: "DRIVE"});
  const first = await saveVersion(db, request("i", 14500, true));
  await saveVersion(db, request("d", 20000, false));
  assert.equal((await activeRef.get()).data().activeVersion, first.version);
  const buyer = {auth: {uid: "radius-buyer", token: {roles: []}},
    data: {destination, requestId: "q".repeat(24), deliveryFee: 0.01,
      distanceMeters: 1}};
  const provider = {route: async () => ({status: "ok",
    distanceMeters: 14500, provider: "google-routes"})};
  const quote = await quoteDelivery(db, buyer, provider);
  const reduced = await saveVersion(db, request("r", 12000, true));
  assert.equal((await activeRef.get()).data().activeVersion, reduced.version);
  await assert.rejects(db.runTransaction((tx) => prepareDelivery(tx, db,
      {id: "radius-new"}, {customerUid: "radius-buyer",
        deliveryAddress: destination, deliveryQuoteId: quote.quoteId,
        deliveryFee: 0.01, deliveryDistanceMeters: 1})), /OUT_OF_RANGE/);
  await saveVersion(db, request("i", 14500, true));
  assert.equal((await activeRef.get()).data().activeVersion, reduced.version);
  const expanded = await saveVersion(db, request("e", 20000, true));
  assert.equal((await activeRef.get()).data().activeVersion, expanded.version);
  const extended = await quoteDelivery(db, {...buyer,
    data: {...buyer.data, requestId: "x".repeat(24)}}, provider);
  assert.equal(extended.distanceMeters, 14500);
  // Leave no active configuration for another isolated emulator suite.
  await activeRef.delete();
});
