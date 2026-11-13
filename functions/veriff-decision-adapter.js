"use strict";
const {createHmac,timingSafeEqual,createHash}=require("node:crypto");
const {HttpsError}=require("firebase-functions/v2/https");
const fail=r=>{throw new HttpsError("failed-precondition",r,{reason:r});};
function normalizeVeriffDecision(raw,{clientId,sharedSecret,authClient,signature,sessionId,subjectRef,
  assuranceProfile,expectedFullName,now=Date.now(),maxDeliveryAgeMs=5*60*1000}) {
  if(!Buffer.isBuffer(raw)||raw.length>256*1024||!clientId||!sharedSecret||authClient!==clientId||
    !/^[a-f0-9]{64}$/i.test(signature||""))fail("AGE_PROVIDER_SIGNATURE_INVALID");
  const expected=createHmac("sha256",sharedSecret).update(raw).digest();
  if(!timingSafeEqual(expected,Buffer.from(signature,"hex")))fail("AGE_PROVIDER_SIGNATURE_INVALID");
  let data;try{data=JSON.parse(raw.toString("utf8"));}catch{fail("AGE_PROVIDER_PAYLOAD_INVALID");}
  const v=data?.verification;
  if(!sessionId||!subjectRef||v?.id!==sessionId||v?.vendorData!==subjectRef||
      assuranceProfile!=="document_face_liveness")fail("AGE_PROVIDER_SESSION_INVALID");
  const decision=Date.parse(v.decisionTime);
  if(!Number.isFinite(decision)||decision>now||now-decision>maxDeliveryAgeMs)fail("AGE_PROVIDER_DECISION_EXPIRED");
  if(data.status!=="success"||v.status!=="approved"||v.code!==9001)return {status:"required"};
  // Date is used transiently. No raw body, document image/number or birthday
  // belongs in the normalized evidence or logs.
  const normalizeName=v=>typeof v==="string"?v.normalize("NFKC").trim().replace(/\s+/g," ").toLocaleUpperCase("pt-BR"):"";
  const actualName=normalizeName([v.person?.firstName,v.person?.lastName].filter(Boolean).join(" "));
  if(!expectedFullName||normalizeName(expectedFullName).length<3||actualName!==normalizeName(expectedFullName))fail("AGE_PROVIDER_IDENTITY_MISMATCH");
  const birth=v.person?.dateOfBirth;
  if(typeof birth!=="string"||!/^\d{4}-\d{2}-\d{2}$/.test(birth))fail("AGE_PROVIDER_BIRTH_INVALID");
  const date=new Date(birth+"T00:00:00Z"),today=new Date(now);
  if(!Number.isFinite(date.getTime())||date.toISOString().slice(0,10)!==birth||date>today||date.getUTCFullYear()<1900)fail("AGE_PROVIDER_BIRTH_INVALID");
  let age=today.getUTCFullYear()-date.getUTCFullYear();
  if(today.getUTCMonth()<date.getUTCMonth()||today.getUTCMonth()===date.getUTCMonth()&&today.getUTCDate()<date.getUTCDate())age--;
  return {status:"approved",ageVerified:true,identityVerified:true,subjectBoundToUid:true,
    ageAtLeast:age>=20?20:age>=18?18:0,
    evidenceDigest:createHash("sha256").update(raw).digest("hex")};
}
// Disconnected adapter only. No endpoint, credentials, HTTP client or provider
// activation. Host must map a server-created UID session to sessionId/subjectRef,
// attest the contracted document+face+liveness profile, consume once in a
// transaction, and issue our internal evidence. Vendor HMAC is NOT Ed25519.
module.exports={normalizeVeriffDecision};
