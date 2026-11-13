const assert = require("node:assert/strict");
const {test} = require("node:test");
const {generateKeyPairSync} = require("node:crypto");
const {parseTicket, signTicket, verifyTicket} = require("../courier-pickup");
const {assignmentNotice} = require("../courier-notifications");
const {profileInput} = require("../courier-approval");
const {publicKey, privateKey} = generateKeyPairSync("ed25519");
const ticket = () => signTicket({keyId: "test-key", orderId: "order", assignmentId: "assignment",
  courierUid: "rider", packageVersion: 1, expiresAtMs: Date.now() + 60000, nonce: "nonce"}, privateKey);
test("real Ed25519 local key pair verifies the canonical pickup token", () => {
  assert.equal(verifyTicket(ticket(), publicKey).assignmentId, "assignment");
});
for (const key of ["orderId", "assignmentId", "courierUid", "nonce", "keyId", "expiresAtMs", "packageVersion",
  "signature"]) {
  test(`tampered ${key} rejected by standard cryptographic verification`, () => {
    const data = JSON.parse(ticket());
    data[key] = typeof data[key] === "number" ? data[key] + 1 : `${data[key]}x`;
    assert.throws(() => verifyTicket(JSON.stringify(data), publicKey));
  });
}
for (const key of ["pin", "plainPin", "address", "customerName", "phone", "payment", "privateKey"]) {
  test(`QR never accepts additional ${key}`, () => {
    assert.throws(() => parseTicket(JSON.stringify({...JSON.parse(ticket()), [key]: "PRIVATE"})));
  });
}
test("expired ticket, wrong public key and wrong algorithm are refused", () => {
  assert.throws(() => verifyTicket(ticket(), publicKey, Date.now() + 120000));
  assert.throws(() => verifyTicket(ticket(), generateKeyPairSync("ed25519").publicKey));
  assert.throws(() => parseTicket(JSON.stringify({...JSON.parse(ticket()), algorithm: "none"})));
});
test("notification contract contains no PII and is stable per assignment", () => {
  assert.deepEqual(Object.keys(assignmentNotice("order", "assignment")).sort(),
      ["kind", "version", "orderId", "assignmentId", "title", "body"].sort());
  assert.deepEqual(assignmentNotice("order", "assignment"), assignmentNotice("order", "assignment"));
});
for (const optional of ["vehiclePlate", "vehicleCountry", "driverLicense", "city", "vehicleDescription"]) {
  test(`registration approves shape without optional ${optional}`, () => {
    const data = profileInput({name: "Pessoa Exemplo", phone: "67900000000", profilePhoto: "fixture-photo"});
    assert.equal(data[optional], "");
  });
}
test("photo is a required technical field, plate/license are never requirements", () => {
  assert.throws(() => profileInput({name: "Pessoa", phone: "67900000000"}));
});

const {validNavigation} = require("../courier-navigation-package");
function navigationFixture() {
  const geometry = [{latitude: -22.53, longitude: -55.73}, {latitude: -22.53, longitude: -55.72}];
  return {schemaVersion: 1, engine: "fixture-graph-v1", datasetVersion: "synthetic-1",
    destination: geometry[1], coverage: {marginMeters: 250, corridors: [geometry]},
    nodes: [{id: "A", point: geometry[0]}, {id: "D", point: geometry[1]}],
    edges: [{from: "A", to: "D"}], alternatives: [geometry]};
}
test("navigation package requires bounded roads, corridor and the original destination", () => {
  const n = navigationFixture();
  assert.equal(validNavigation(n, n.destination, n.coverage.corridors[0]), true);
});
for (const [name, mutate] of [
  ["absent", () => null], ["version", (n) => ({...n, schemaVersion: 99})],
  ["no roads", (n) => ({...n, edges: []})], ["unknown edge", (n) => ({...n, edges: [{from: "A", to: "Z"}]})],
  ["duplicate nodes", (n) => ({...n, nodes: [n.nodes[0], n.nodes[0]]})],
  ["unbounded margin", (n) => ({...n, coverage: {...n.coverage, marginMeters: Infinity}})],
  ["unbounded graph", (n) => ({...n, nodes: Array(257).fill(n.nodes[0])})],
  ["different destination", (n) => ({...n, destination: {latitude: 0, longitude: 0}})],
  ["extra private field", (n) => ({...n, customerPhone: "PRIVATE"})],
  ["invalid coordinate", (n) => ({...n, nodes: [{id: "A", point: {latitude: 999, longitude: 1}}, n.nodes[1]]})],
]) {
  test(`navigation rejects ${name}`, () => {
    const n = navigationFixture();
    assert.equal(validNavigation(mutate(n), n.destination, n.coverage.corridors[0]), false);
  });
}

const {validatePackage} = require("../courier-pickup");
for (const field of ["pin", "plainPin", "plaintextPin", "privateKey", "private_key", "secretKey", "signingKey"]) {
  test(`offline package refuses nested ${field} before it can be downloaded`, () => {
    const n = navigationFixture(); const expiry = Date.now() + 60000;
    const t = {orderId: "order", assignmentId: "assignment", courierUid: "rider", packageVersion: 1,
      expiresAtMs: expiry};
    const p = {schemaVersion: 2, assignment: {...t}, delivery: {orderId: "order", courierUid: "rider",
      address: "Synthetic example", expiresAtMs: expiry, coordinates: n.destination,
      payment: {state: "paid", amountMinor: 0, currency: "BRL"},
      pinVerifier: {orderId: "order", verificationVersion: 1, expiresAtMs: expiry, maxAttempts: 3,
        verificationMaterial: "server-only:v1"}},
    map: {geometry: n.coverage.corridors[0], asset: "synthetic-map", navigation: n}};
    assert.doesNotThrow(() => validatePackage(Buffer.from(JSON.stringify(p)), t));
    p.delivery.extra = {nested: [{[field]: "synthetic-placeholder-never-a-real-secret"}]};
    assert.throws(() => validatePackage(Buffer.from(JSON.stringify(p)), t), (e) => e.code === "failed-precondition");
  });
}
