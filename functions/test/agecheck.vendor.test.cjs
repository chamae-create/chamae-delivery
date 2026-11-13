"use strict";
const test=require("node:test"),assert=require("node:assert/strict"),crypto=require("node:crypto");
const {normalizeVeriffDecision}=require("../veriff-decision-adapter");
const {AgeVerificationService}=require("../age-verification-service");
const now=Date.parse("2026-11-07T12:00:00Z");
function fixture(patch={}) {
 const data={status:"success",verification:{id:"unit_session",vendorData:"unit_subject",status:"approved",code:9001,
 decisionTime:new Date(now-1000).toISOString(),person:{firstName:"Pessoa",lastName:"Teste",dateOfBirth:"2000-01-01"},...patch}};
 const raw=Buffer.from(JSON.stringify(data)),ctx={clientId:"unit_client",sharedSecret:"unit_test_secret_only",authClient:"unit_client",
 signature:crypto.createHmac("sha256","unit_test_secret_only").update(raw).digest("hex"),sessionId:"unit_session",subjectRef:"unit_subject",
 assuranceProfile:"document_face_liveness",expectedFullName:"Pessoa Teste",now};return {raw,ctx};
}
test("vendor adapter authenticates raw webhook and minimizes birth data",()=>{const f=fixture(),p=normalizeVeriffDecision(f.raw,f.ctx);assert.equal(p.ageAtLeast,20);assert.equal(p.identityVerified,true);assert.ok(!JSON.stringify(p).includes("2000-01-01"));});
test("adulterated vendor payload or HMAC cannot produce proof",()=>{const f=fixture();assert.throws(()=>normalizeVeriffDecision(Buffer.from(f.raw.toString().replace("unit_subject","other_subject")),f.ctx));assert.throws(()=>normalizeVeriffDecision(f.raw,{...f.ctx,signature:"0".repeat(64)}));});
test("wrong vendor subject or session is blocked",()=>{for(const change of [{sessionId:"other"},{subjectRef:"other"},{authClient:"other"}]){const f=fixture();assert.throws(()=>normalizeVeriffDecision(f.raw,{...f.ctx,...change}));}});
test("document-only or unknown contract cannot assert holder verification",()=>{const f=fixture();assert.throws(()=>normalizeVeriffDecision(f.raw,{...f.ctx,assuranceProfile:"document_only"}));});
test("minor and 18-year adult produce distinct thresholds for PY",()=>{for(const [birth,threshold]of [["2010-01-01",0],["2008-01-01",18]]){const f=fixture({person:{firstName:"Pessoa",lastName:"Teste",dateOfBirth:birth}});assert.equal(normalizeVeriffDecision(f.raw,f.ctx).ageAtLeast,threshold);}});
test("stale callback and invalid date are blocked",()=>{for(const change of [{decisionTime:"2000-01-01T00:00:00Z"},{person:{firstName:"Pessoa",lastName:"Teste",dateOfBirth:"2000-02-31"}}]){const f=fixture(change);assert.throws(()=>normalizeVeriffDecision(f.raw,f.ctx));}});
test("declined vendor cannot become approved",()=>{const f=fixture({status:"declined",code:9102});assert.equal(normalizeVeriffDecision(f.raw,f.ctx).status,"required");});
test("provider network failure does not retry automatically",async()=>{let calls=0;const unitProvider={begin:async()=>{calls++;throw Error("UNIT_NETWORK_DOWN");}};await assert.rejects(new AgeVerificationService(unitProvider).begin("unit_customer","unit_request_00000001"));assert.equal(calls,1);});
test("invalid request never calls provider",async()=>{let calls=0;const unitProvider={begin:async()=>{calls++;return {};}};await assert.rejects(new AgeVerificationService(unitProvider).begin("unit_customer","bad"));assert.equal(calls,0);});

test("different declared holder name cannot become bound evidence",()=>{const f=fixture();assert.throws(()=>normalizeVeriffDecision(f.raw,{...f.ctx,expectedFullName:"Outra Pessoa"}),e=>e.details.reason==="AGE_PROVIDER_IDENTITY_MISMATCH");});
