"use strict";
const test=require("node:test"),assert=require("node:assert/strict"),crypto=require("node:crypto"),fs=require("node:fs"),path=require("node:path");
const {assertAgeEvidence,requiredAge,restrictedProduct,assertDeliveryAge,AGE_POLICY_VERSION}=require("../age-eligibility");
const {verifyAttestation,ingestAttestation}=require("../age-attestation");
const {sanitizeIdentification,saveIdentification}=require("../customer-identification");
const {AgeVerificationService,publicStatus}=require("../age-verification-service");
const {checkPurchase,policyFingerprint}=require("../customer-onboarding");
const {assertOrderRecipient}=require("../age-delivery-policy");
const now=Date.parse("2026-11-07T12:00:00Z"),uid="unit_customer",other="unit_other",sessionId="unit_session_00000001";
const {publicKey,privateKey}=crypto.generateKeyPairSync("ed25519"); // TEST ONLY; never written to disk.
const keys={unit:{provider:"unit_provider",publicKey,maxValidityMs:60000}};
const trust={enabled:true,providers:["unit_provider"]};
function envelope(patch={}) {
 const payload=Buffer.from(JSON.stringify({uid,identityRevision:1,nonce:"unit_nonce",audience:"demo-age-local",provider:"unit_provider",
 ageAtLeast:20,ageVerified:true,identityVerified:true,subjectBoundToUid:true,issuedAtMs:now-1000,expiresAtMs:now+50000,...patch})).toString("base64url");
 return {keyId:"unit",payload,signature:crypto.sign(null,Buffer.from(payload,"base64url"),privateKey).toString("base64url")};
}
const verify=e=>verifyAttestation(e,{uid,nonce:"unit_nonce",audience:"demo-age-local",keys,now});
const proof=()=>verify(envelope());
const opts={uid,minimum:20,now,trust,identityRevision:1};
const reason=(fn,r)=>assert.throws(fn,e=>e.details?.reason===r);
function dbMock(seed={}) {
 const data=new Map(Object.entries(seed));let writes=0;
 const doc=p=>({path:p,get:async()=>snap(p)});
 const snap=p=>({exists:data.has(p),data:()=>data.get(p)});
 const db={doc,collection:p=>({doc:id=>doc(p+"/"+id)}),data,get writes(){return writes;},
 async runTransaction(fn){let writing=false;const pending=[];
 const tx={get:async r=>{assert.equal(writing,false,"all reads before writes");return snap(r.path);},
 set:(r,v,o)=>{writing=true;pending.push(()=>data.set(r.path,o?.merge?{...data.get(r.path),...v}:v));},
 update:(r,v)=>{writing=true;pending.push(()=>data.set(r.path,{...data.get(r.path),...v}));},
 create:(r,v)=>{writing=true;assert.ok(!data.has(r.path));pending.push(()=>data.set(r.path,v));}};
 const result=await fn(tx);for(const commit of pending){commit();writes++;}return result;
 }};return db;
}
const identity={fullName:"Pessoa de Teste",documentType:"cpf",documentIssuer:"BR",preferredLanguage:"es-PY",phone:"+59500000000"};
const auth={uid,token:{firebase:{sign_in_provider:"google.com"},roles:[]}};
const policy={revision:"unit-v1",termsVersion:"unit-v1",privacyVersion:"unit-v1",alcoholVersion:"unit-v1",termsText:"unit terms",privacyText:"unit privacy",alcoholNotice:"unit alcohol",termsUrl:"https://example.test/terms",privacyUrl:"https://example.test/privacy",minimumAgeByCountry:{BR:18,PY:20},published:true,draft:false};
policy.contentHash=policyFingerprint(policy);
function currentProfile(){return {birthDate:"2000-01-01",acceptedAt:1,termsVersion:policy.termsVersion,privacyVersion:policy.privacyVersion,alcoholVersion:policy.alcoholVersion,policyRevision:policy.revision,policyHash:policy.contentHash,identityRevision:1};}
test("document issuer, language and delivery country are independent",()=>{assert.equal(sanitizeIdentification(identity).preferredLanguage,"es-PY");assert.equal(sanitizeIdentification(identity).documentIssuer,"BR");});
test("PY identity does not use CPF validation or checksum on server",()=>assert.equal(sanitizeIdentification({...identity,documentType:"cedula",documentIssuer:"PY"}).documentStatus,"not_verified"));
test("third-jurisdiction identity stays available",()=>assert.equal(sanitizeIdentification({...identity,documentType:"other",documentIssuer:"AR"}).documentIssuer,"AR"));
test("raw document, DOB and verified flags rejected without data in error",()=>{for(const field of ["documentNumber","birthDate","ageVerified","uid","deliveryCountry"]){assert.throws(()=>sanitizeIdentification({...identity,[field]:"unit_secret"}),e=>e.code==="invalid-argument"&&!e.message.includes("unit_secret"));}});
test("profile merge preserves PIN, address and accepted legal versions",async()=>{const db=dbMock({"customerPolicies/current":policy,["customerProfiles/"+uid]:{...currentProfile(),identityRevision:0,pinRevision:2,addresses:["unit"]}});await saveIdentification(db,{auth,data:identity});assert.equal(db.data.get("customerProfiles/"+uid).pinRevision,2);assert.equal(db.data.get("customerProfiles/"+uid).termsVersion,policy.termsVersion);assert.equal(db.data.get("customerProfiles/"+uid).identityRevision,1);});
test("identity revision increments only for identity changes",async()=>{const db=dbMock({"customerPolicies/current":policy,["customerProfiles/"+uid]:{...currentProfile(),...identity,identityRevision:4}});await saveIdentification(db,{auth,data:{...identity,preferredLanguage:"pt-BR"}});assert.equal(db.data.get("customerProfiles/"+uid).identityRevision,4);await saveIdentification(db,{auth,data:{...identity,documentIssuer:"PY",documentType:"cedula"}});assert.equal(db.data.get("customerProfiles/"+uid).identityRevision,5);});
test("administrative and courier identities cannot use customer identification",async()=>{await assert.rejects(saveIdentification(dbMock(),{auth:{...auth,token:{...auth.token,roles:["superadmin"]}},data:identity}));await assert.rejects(saveIdentification(dbMock({["couriers/"+uid]:{}}),{auth,data:identity}));});
test("default provider cannot approve or initiate any real verification",async()=>{reason(()=>assertAgeEvidence(proof(),{...opts,trust:undefined}),"AGE_PROVIDER_UNAVAILABLE");await assert.rejects(new AgeVerificationService().begin(uid,"unit_request_0000001"),e=>e.details.reason==="AGE_PROVIDER_UNAVAILABLE");assert.equal(publicStatus(proof(),now).status,"unavailable");});
test("test-only adult assertion validates age and holder separately",()=>assert.equal(assertAgeEvidence(proof(),opts).verified,true));
for(const [name,patch,expected]of[
 ["minor",{ageAtLeast:17},"AGE_RESTRICTED"],["holder not verified",{identityVerified:false},"AGE_EVIDENCE_UNTRUSTED"],
 ["third party",{subjectBoundToUid:false},"AGE_EVIDENCE_UNTRUSTED"],["other UID",{uid:other},"AGE_VERIFICATION_REQUIRED"],
 ["expired",{expiresAtMs:now-1},"AGE_VERIFICATION_EXPIRED"],["revoked",{revoked:true},"AGE_VERIFICATION_REQUIRED"],
 ["appeal",{status:"appealPending"},"AGE_APPEAL_PENDING"],["changed identity",{identityRevision:2},"AGE_VERIFICATION_REQUIRED"]]){
 test(name,()=>reason(()=>assertAgeEvidence({...proof(),...patch},opts),expected));
}
test("country age floors BR18/PY20 cannot be lowered by UI policy",()=>{assert.equal(requiredAge("BR",18),18);assert.equal(requiredAge("PY",20),20);reason(()=>requiredAge("PY",18),"AGE_POLICY_UNAVAILABLE");});
test("catalog restriction uses authoritative flags/category, never product name",()=>{assert.equal(restrictedProduct({name:"alcohol",category:"Geral"}),false);assert.equal(restrictedProduct({isAlcoholic:true}),true);assert.equal(restrictedProduct({category:"Cervejas"}),true);});
test("tampered attestation rejected",()=>{const e=envelope();e.signature=(e.signature[0]==="A"?"B":"A")+e.signature.slice(1);reason(()=>verify(e),"AGE_SIGNATURE_INVALID");});
test("unsigned issuer and wrong nonce, UID, audience rejected",()=>{reason(()=>verify({...envelope(),keyId:"unknown"}),"AGE_ISSUER_UNTRUSTED");for(const p of [{uid:other},{nonce:"wrong"},{audience:"wrong"},{identityVerified:false}])assert.throws(()=>verify(envelope(p)));});
test("attestation stores minimal bound evidence, never raw documents or DOB",()=>{const p=proof();assert.equal(p.policyVersion,AGE_POLICY_VERSION);assert.ok(!JSON.stringify(p).includes("birthDate"));assert.ok(!JSON.stringify(p).includes("documentNumber"));});
test("signed evidence ingests once; replay produces no second write",async()=>{
 const db=dbMock({["ageVerificationSessions/"+sessionId]:{uid,identityRevision:1,nonce:"unit_nonce",audience:"demo-age-local",expiresAtMs:now+60000},["customerProfiles/"+uid]:{identityRevision:1}});
 const ctx={uid,sessionId,audience:"demo-age-local",keys,now},e=envelope();
 assert.equal((await ingestAttestation(db,e,ctx)).replayed,false);const n=db.writes;
 assert.equal((await ingestAttestation(db,e,ctx)).replayed,true);assert.equal(db.writes,n);
 await assert.rejects(ingestAttestation(db,envelope({ageAtLeast:18}),ctx),x=>x.details.reason==="AGE_ATTESTATION_REPLAY");
});
test("expired session and identity change prevent ingestion",async()=>{for(const profile of [{identityRevision:2},{identityRevision:1}]){
 const db=dbMock({["ageVerificationSessions/"+sessionId]:{uid,identityRevision:1,nonce:"unit_nonce",audience:"demo-age-local",expiresAtMs:profile.identityRevision===1?now-1:now+10000},["customerProfiles/"+uid]:profile});
 await assert.rejects(ingestAttestation(db,envelope(),{uid,sessionId,audience:"demo-age-local",keys,now}));assert.equal(db.writes,0);
}});
test("real purchase endpoint blocks declared adult while provider disabled",async()=>{
 const db=dbMock({"customerPolicies/current":policy,["customerProfiles/"+uid]:currentProfile(),"products/unit_alcohol":{isAlcoholic:true},["customerAgeVerifications/"+uid]:proof()});
 await assert.rejects(checkPurchase(db,{auth,data:{countryCode:"BR",productIds:["unit_alcohol"]}}),e=>e.details.reason==="AGE_PROVIDER_UNAVAILABLE");
 assert.equal(db.writes,0);
});
test("non-restricted checkout retains existing eligibility and financial independence",async()=>{
 const db=dbMock({"customerPolicies/current":policy,["customerProfiles/"+uid]:currentProfile(),"products/unit_water":{category:"Geral"}});
 assert.equal((await checkPurchase(db,{auth,data:{countryCode:"BR",productIds:["unit_water"]}})).eligible,true);assert.equal(db.writes,0);
});
test("missing physical check, failed check and wrong assignment block PIN gate",()=>{const d={orderId:"o",assignmentId:"a",courierUid:"c",minimum:20,now};for(const p of [null,{status:"declined"},{status:"approved",orderId:"o",assignmentId:"other",courierUid:"c",identityMatches:true,minimumAge:20,expiresAtMs:now+1000}])reason(()=>assertDeliveryAge(p,d),"RECIPIENT_AGE_CONFIRMATION_REQUIRED");});
test("physical check expires and cannot cross courier UID",()=>{const p={orderId:"o",assignmentId:"a",courierUid:"c",status:"approved",identityMatches:true,minimumAge:20,expiresAtMs:now+1000};assert.doesNotThrow(()=>assertDeliveryAge(p,{orderId:"o",assignmentId:"a",courierUid:"c",minimum:20,now}));reason(()=>assertDeliveryAge(p,{orderId:"o",assignmentId:"a",courierUid:"other",minimum:20,now}),"RECIPIENT_AGE_CONFIRMATION_REQUIRED");});
test("client order flag cannot remove catalog-driven age check",async()=>{const db=dbMock({"products/unit_alcohol":{isAlcoholic:true},"customerPolicies/current":policy});await assert.rejects(db.runTransaction(tx=>assertOrderRecipient(tx,db,{itemsList:[{id:"unit_alcohol"}],documentRequiredAtDelivery:false,deliveryAddress:{countryCode:"PY"}},{orderId:"o",assignmentId:"a",courierUid:"c"})),e=>e.details.reason==="RECIPIENT_AGE_CONFIRMATION_REQUIRED");});

test("identification legal gate: missing policy prevents all profile writes",async()=>{const db=dbMock();await assert.rejects(saveIdentification(db,{auth,data:identity}),e=>e.details?.reason==="POLICY_UNAVAILABLE");assert.equal(db.writes,0);});
test("identification legal gate: DRAFT policy cannot authorize personal data persistence",async()=>{const db=dbMock({"customerPolicies/current":{...policy,published:false,draft:true},["customerProfiles/"+uid]:currentProfile()});await assert.rejects(saveIdentification(db,{auth,data:identity}),e=>e.details?.reason==="POLICY_UNAVAILABLE");assert.equal(db.writes,0);});
test("identification legal gate: no policy acceptance fails without creating a profile",async()=>{const db=dbMock({"customerPolicies/current":policy});await assert.rejects(saveIdentification(db,{auth,data:identity}),e=>e.details?.reason==="CUSTOMER_POLICY_ACCEPTANCE_REQUIRED");assert.equal(db.writes,0);assert.equal(db.data.has("customerProfiles/"+uid),false);});
test("identification legal gate: stale consent hash is rejected without changing PIN",async()=>{const profile={...currentProfile(),policyHash:"outdated",pinRevision:9};const db=dbMock({"customerPolicies/current":policy,["customerProfiles/"+uid]:profile});await assert.rejects(saveIdentification(db,{auth,data:identity}),e=>e.details?.reason==="CUSTOMER_POLICY_ACCEPTANCE_REQUIRED");assert.equal(db.writes,0);assert.deepEqual(db.data.get("customerProfiles/"+uid),profile);});
test("identification legal gate: tampered official policy fails before any write",async()=>{const db=dbMock({"customerPolicies/current":{...policy,termsText:"tampered"},["customerProfiles/"+uid]:currentProfile()});await assert.rejects(saveIdentification(db,{auth,data:identity}),e=>e.details?.reason==="POLICY_UNAVAILABLE");assert.equal(db.writes,0);});
test("identification legal gate: accepted policy does not verify identity or age",async()=>{const db=dbMock({"customerPolicies/current":policy,["customerProfiles/"+uid]:currentProfile()});await saveIdentification(db,{auth,data:identity});const p=db.data.get("customerProfiles/"+uid);assert.equal(p.documentStatus,"not_verified");assert.equal(p.ageVerified,undefined);assert.equal(p.identityVerified,undefined);assert.equal(db.data.has("customerAgeVerifications/"+uid),false);assert.equal(db.writes,1);});

test("resumed integration: accepted identification allows only the existing non-restricted BR path",async()=>{
 const db=dbMock({"customerPolicies/current":policy,["customerProfiles/"+uid]:currentProfile(),"products/unit_water":{category:"Geral"}});
 await saveIdentification(db,{auth,data:identity});const count=db.writes;
 assert.equal((await checkPurchase(db,{auth,data:{countryCode:"BR",productIds:["unit_water"]}})).eligible,true);
 assert.equal(db.writes,count);assert.equal([...db.data.keys()].some(p=>p.startsWith("orders/")),false);
});
test("resumed integration: identification cannot enable the Paraguayan commercial operation",async()=>{
 const db=dbMock({"customerPolicies/current":policy,["customerProfiles/"+uid]:currentProfile(),"products/unit_water":{category:"Geral"}});
 await saveIdentification(db,{auth,data:{...identity,documentType:"cedula",documentIssuer:"PY"}});
 const count=db.writes;
 await assert.rejects(checkPurchase(db,{auth,data:{countryCode:"PY",productIds:["unit_water"]}}),e=>e.details?.reason==="CROSS_BORDER_OPERATION_NOT_AUTHORIZED");
 assert.equal(db.writes,count);
});
test("resumed integration: accepted identification and declared adult cannot enable alcohol",async()=>{
 const db=dbMock({"customerPolicies/current":policy,["customerProfiles/"+uid]:currentProfile(),"products/unit_alcohol":{isAlcoholic:true}});
 await saveIdentification(db,{auth,data:identity});const count=db.writes;
 await assert.rejects(checkPurchase(db,{auth,data:{countryCode:"BR",productIds:["unit_alcohol"]}}),e=>e.details?.reason==="AGE_PROVIDER_UNAVAILABLE");
 assert.equal(db.writes,count);assert.equal(db.data.has("customerAgeVerifications/"+uid),false);
});
