const {test} = require("node:test");
const assert = require("node:assert/strict");
const {timeZone, storeIsOpen, assertStoreOpen, assertPaymentCountry, verifiedQuoteCountry} =
  require("../order-acceptance");
const {GoogleDestinationCountry} = require("../destination-country");
const {deliveryFixture} = require("./delivery-fixture");

for (const [instant, expected] of [
  ["2026-10-24T11:59:59.999Z", false], ["2026-10-24T12:00:00.000Z", true],
  ["2026-10-24T16:00:00Z", true], ["2026-10-25T03:59:59.999Z", true],
  ["2026-10-25T04:00:00.000Z", false],
]) {
  test(`MS boundary ${instant}: ${expected}`, () => {
    assert.equal(timeZone, "America/Campo_Grande");
    assert.equal(storeIsOpen(Date.parse(instant)), expected);
    if (!expected) {
      assert.throws(() => assertStoreOpen(Date.parse(instant)),
          (error) => error.details.reason === "STORE_CLOSED");
    }
  });
}
test("backend machine timezone and invalid clock cannot override named MS schedule", () => {
  const previous = process.env.TZ;
  try {
    for (const zone of ["UTC", "Asia/Tokyo", "Pacific/Honolulu", "America/Sao_Paulo"]) {
      process.env.TZ = zone;
      assert.equal(storeIsOpen(Date.parse("2026-10-24T12:00:00Z")), true);
      assert.equal(storeIsOpen(Date.parse("2026-10-25T04:00:00Z")), false);
    }
    assert.equal(storeIsOpen(NaN), false);
  } finally {
    if (previous === undefined) delete process.env.TZ; else process.env.TZ = previous;
  }
});

test("PY split cannot hide card/PIX; unknown methods and countries fail closed", () => {
  for (const method of ["Maquininha", "Maquininha - Débito à vista", "Maquininha - Crédito à vista", "unknown"]) {
    assert.throws(() => assertPaymentCountry({paymentMethod: method}, "PY"),
        (e) => e.details.reason === "PAYMENT_METHOD_NOT_ALLOWED_FOR_COUNTRY");
  }
  for (const method of ["PIX", "Maquininha"]) {
    assert.throws(() => assertPaymentCountry({paymentMethod: "Pagamento dividido", splitPayment: true,
      paymentParts: [{method: "Dinheiro"}, {method}]}, "PY"));
  }
  assert.throws(() => assertPaymentCountry({paymentMethod: "Dinheiro"}, undefined));
  assert.throws(() => assertPaymentCountry({paymentMethod: "Dinheiro", splitPayment: false,
    paymentParts: [{method: "Maquininha"}]}, "PY"));
});

const result = (country) => ({types: ["country", "political"],
  address_components: [{types: ["country", "political"], short_name: country}]});
for (const country of ["BR", "PY"]) {
  test(`server country ${country} is based on coordinates without a client country bias`, async () => {
    const address = {...deliveryFixture().destination, countryCode: country};
    const provider = new GoogleDestinationCountry({apiKey: "TEST_ONLY", fetchImpl: async (url) => {
      const request = new URL(url);
      assert.equal(request.hostname, "maps.googleapis.com");
      assert.equal(request.searchParams.get("result_type"), "country");
      assert.equal(request.searchParams.has("region"), false);
      assert.equal(request.searchParams.get("latlng"), `${address.latitude},${address.longitude}`);
      return {ok: true, json: async () => ({status: "OK", results: [result(country)]})};
    }});
    const evidence = await provider.verify(address);
    assert.equal(evidence.countryCode, country); assert.equal(evidence.latitude, address.latitude);
    const quote = {createdAtMs: Date.now(), destinationVerification: evidence};
    assert.equal(verifiedQuoteCountry(quote, address), country);
    assert.throws(() => verifiedQuoteCountry(quote, {...address, longitude: 0}));
  });
}
for (const [name, body] of [
  ["absent", {}], ["zero", {status: "ZERO_RESULTS", results: []}],
  ["ambiguous", {status: "OK", results: [result("BR"), result("PY")]}],
  ["forged", {status: "OK", results: [result("PY")]}],
  ["unsupported", {status: "OK", results: [result("AR")]}],
  ["partial", {status: "OK", results: [{...result("BR"), partial_match: true}]}],
  ["nearest street", {status: "OK", results: [{...result("BR"), types: ["street_address"]}]}],
]) {
  test(`country ${name} fails closed without provider details or key`, async () => {
    const provider = new GoogleDestinationCountry({apiKey: "PRIVATE_TEST_KEY", fetchImpl: async () =>
      ({ok: true, json: async () => body})});
    await assert.rejects(provider.verify(deliveryFixture().destination), (error) => {
      assert.equal(error.details.reason, "DESTINATION_COUNTRY_UNVERIFIED");
      assert.equal(error.message.includes("PRIVATE_TEST_KEY"), false); return true;
    });
  });
}
test("unconfigured, network timeout and provider rejection fail closed", async () => {
  for (const options of [{}, {apiKey: "TEST", fetchImpl: async () => {
    throw new Error("timeout");
  }},
  {apiKey: "TEST", fetchImpl: async () => ({ok: false})}]) {
    await assert.rejects(new GoogleDestinationCountry(options).verify(deliveryFixture().destination),
        (e) => e.details.reason === "DESTINATION_COUNTRY_UNVERIFIED");
  }
});
