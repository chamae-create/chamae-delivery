"use strict";
const {test} = require("node:test");
const assert = require("node:assert/strict");
const {assertDestinationOperation, assertSinglePayment, checkoutPolicy} = require("../checkout-policy");
const {requiredAge, assertAgeEvidence, runtimeTrust} = require("../age-eligibility");
test("new checkout accepts BR/PY, BRL/PYG/USD cash and split cash parts", () => {
  for (const paymentMethod of ["PIX", "Dinheiro", "Maquininha"]) {
    assert.doesNotThrow(() => assertSinglePayment({paymentMethod, cashCurrency:"BRL"}));
  }
  for (const cashCurrency of ["BRL", "PYG", "USD"]) {
    assert.doesNotThrow(() => assertSinglePayment({paymentMethod:"Dinheiro", cashCurrency}));
  }
  assert.doesNotThrow(() => assertSinglePayment({
    paymentMethod:"Pagamento dividido",
    splitPayment:true,
    paymentParts:[
      {method:"Dinheiro", currency:"PYG", amountCurrency:75000},
      {method:"Dinheiro", currency:"USD", amountCurrency:4},
    ],
  }));
  assert.doesNotThrow(() => assertDestinationOperation("BR"));
  assert.doesNotThrow(() => assertDestinationOperation("PY"));
});
test("split payments reject non-cash parts, PIX or missing/malformed parts", () => {
  for (const patch of [
    {splitPayment:true, paymentMethod:"Dinheiro"},
    {splitPayment:true, paymentMethod:"Pagamento dividido", pixRequested:true,
      paymentParts:[{method:"Dinheiro", currency:"BRL", amountCurrency:10},
        {method:"Dinheiro", currency:"BRL", amountCurrency:10}]},
    {paymentMethod:"Pagamento dividido"},
    {paymentParts:[{method:"Dinheiro"},{method:"PIX"}]},
    {paymentParts:{0:{method:"Dinheiro"}}},
  ]) {
    assert.throws(() => assertSinglePayment({paymentMethod:"Dinheiro",...patch}),
      e=>e.details.reason==="SINGLE_PAYMENT_REQUIRED");
  }
  assert.doesNotThrow(() => assertSinglePayment({paymentMethod:"Dinheiro",paymentParts:[]}));
});
test("unsupported cash currencies remain blocked while BRL/PYG/USD succeed", () => {
  for(const cashCurrency of ["EUR","ARS","unknown",""]) {
    assert.throws(() => assertSinglePayment({paymentMethod:"Dinheiro",cashCurrency}),
      e=>e.details.reason==="EXCHANGE_RATE_UNAVAILABLE");
  }
});
test("unsupported destination countries fail closed independently from identity", () => {
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
