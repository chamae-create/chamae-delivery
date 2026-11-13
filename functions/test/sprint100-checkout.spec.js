"use strict";
const {test} = require("node:test");
const assert = require("node:assert/strict");
const {assertDestinationOperation, assertSinglePayment, checkoutPolicy} = require("../checkout-policy");
const {requiredAge, assertAgeEvidence, runtimeTrust} = require("../age-eligibility");
test("new checkout accepts a single BRL method without an FX dependency", () => {
  for (const paymentMethod of ["PIX", "Dinheiro", "Maquininha"]) {
    assert.doesNotThrow(() => assertSinglePayment({paymentMethod, cashCurrency:"BRL"}));
  }
  assert.doesNotThrow(() => assertDestinationOperation("BR"));
});
test("old clients cannot opt into split payments with flags, method or hidden parts", () => {
  for (const patch of [{splitPayment:true},{paymentMethod:"Pagamento dividido"},
    {paymentParts:[{method:"Dinheiro"},{method:"PIX"}]},{paymentParts:{0:{method:"Dinheiro"}}}]) {
    assert.throws(() => assertSinglePayment({paymentMethod:"Dinheiro",...patch}), e=>e.details.reason==="SINGLE_PAYMENT_REQUIRED");
  }
  assert.doesNotThrow(() => assertSinglePayment({paymentMethod:"Dinheiro",paymentParts:[]}));
});
test("foreign cash cannot consume fictitious exchange or change rates", () => {
  for(const cashCurrency of ["USD","PYG","unknown",""]) {
    assert.throws(() => assertSinglePayment({paymentMethod:"Dinheiro",cashCurrency,
      exchangeRateBRLPerUSD:5,exchangeRatePYGPerBRL:1500}),e=>e.details.reason==="EXCHANGE_RATE_UNAVAILABLE");
  }
});
test("PY commerce stays closed independently from identity, language and a successful route", () => {
  assert.throws(() => assertDestinationOperation("PY"),e=>e.details.reason==="CROSS_BORDER_OPERATION_NOT_AUTHORIZED");
  for(const value of [undefined,null,"US","br"])assert.throws(()=>assertDestinationOperation(value));
  assert.equal(Object.isFrozen(checkoutPolicy),true);
});
test("no runtime provider approves age; BR18 and PY20 floors cannot be reduced", () => {
  assert.equal(runtimeTrust.enabled,false);
  assert.equal(requiredAge("BR",18),18);
  assert.equal(requiredAge("PY",20),20);
  assert.throws(()=>requiredAge("PY",18));
  assert.throws(()=>assertAgeEvidence({ageVerified:true,ageAtLeast:99},{uid:"synthetic",minimum:18}),e=>e.details.reason==="AGE_PROVIDER_UNAVAILABLE");
});

test("head shop stays outside customer commerce without blocking lawful convenience", () => {
  const {isCommerciallyBlocked} = require("../catalog-commercial-policy");
  assert.equal(isCommerciallyBlocked({name:"Artigo",category:"Head Shop"}),true);
  assert.equal(isCommerciallyBlocked({name:"Erva para tereré",category:"Conveniência"}),false);
});
