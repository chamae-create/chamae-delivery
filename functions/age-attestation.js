"use strict";
const {verify,createHash} = require("node:crypto");
const {HttpsError} = require("firebase-functions/v2/https");
const {AGE_POLICY_VERSION} = require("./age-eligibility");
const bad=reason=>{throw new HttpsError("failed-precondition",reason,{reason});};
function verifyAttestation(envelope,{uid,nonce,audience,keys={},now=Date.now()}) {
  if (!envelope || Object.keys(envelope).some(k=>!["keyId","payload","signature"].includes(k)) ||
      typeof envelope.payload!=="string" || envelope.payload.length>4096 ||
      !/^[A-Za-z0-9_-]+$/.test(envelope.payload) || !/^[A-Za-z0-9_-]{86}$/.test(envelope.signature||"")) bad("AGE_ATTESTATION_INVALID");
  const trusted=keys[envelope.keyId];
  if (!trusted || !trusted.provider || !trusted.publicKey || !Number.isSafeInteger(trusted.maxValidityMs) || trusted.maxValidityMs<=0) bad("AGE_ISSUER_UNTRUSTED");
  const bytes=Buffer.from(envelope.payload,"base64url");
  if (!verify(null,bytes,trusted.publicKey,Buffer.from(envelope.signature,"base64url"))) bad("AGE_SIGNATURE_INVALID");
  let d;try{d=JSON.parse(bytes.toString("utf8"));}catch{bad("AGE_ATTESTATION_INVALID");}
  const fields=["uid","identityRevision","nonce","audience","provider","ageAtLeast","ageVerified","identityVerified","subjectBoundToUid","issuedAtMs","expiresAtMs"];
  if (!d || Array.isArray(d) || Object.keys(d).length!==fields.length || Object.keys(d).some(k=>!fields.includes(k)) ||
      d.uid!==uid || !Number.isSafeInteger(d.identityRevision) || d.identityRevision<1 || d.nonce!==nonce || d.audience!==audience || d.provider!==trusted.provider ||
      d.ageVerified!==true || d.identityVerified!==true || d.subjectBoundToUid!==true ||
      !Number.isInteger(d.ageAtLeast) || d.ageAtLeast<0 || d.ageAtLeast>120 ||
      !Number.isSafeInteger(d.issuedAtMs) || !Number.isSafeInteger(d.expiresAtMs) ||
      d.issuedAtMs>now || d.expiresAtMs<=now || d.expiresAtMs<=d.issuedAtMs ||
      d.expiresAtMs-d.issuedAtMs>trusted.maxValidityMs) bad("AGE_ATTESTATION_BINDING_INVALID");
  return {schemaVersion:1,policyVersion:AGE_POLICY_VERSION,uid:d.uid,identityRevision:d.identityRevision,provider:d.provider,
    status:"approved",ageAtLeast:d.ageAtLeast,ageVerified:true,identityVerified:true,subjectBoundToUid:true,
    issuedAtMs:d.issuedAtMs,expiresAtMs:d.expiresAtMs,revoked:false,
    evidenceDigest:createHash("sha256").update(envelope.payload+"."+envelope.signature).digest("hex")};
}
async function ingestAttestation(db,envelope,{uid,sessionId,audience,keys,now=Date.now()}) {
  if (!/^[A-Za-z0-9_-]{16,128}$/.test(sessionId||"")) bad("AGE_SESSION_INVALID");
  return db.runTransaction(async tx=>{
    const ref=db.doc("ageVerificationSessions/"+sessionId),session=(await tx.get(ref)).data();
    if (!session || session.uid!==uid || session.audience!==audience || !(session.expiresAtMs>now)) bad("AGE_SESSION_INVALID");
    const proof=verifyAttestation(envelope,{uid,nonce:session.nonce,audience,keys,now});
    const profile=(await tx.get(db.doc("customerProfiles/"+uid))).data();
    if(proof.identityRevision!==session.identityRevision || proof.identityRevision!==profile?.identityRevision)bad("AGE_IDENTITY_CHANGED");
    if (session.consumedDigest) {
      if (session.consumedDigest!==proof.evidenceDigest) bad("AGE_ATTESTATION_REPLAY");
      return {status:"approved",replayed:true};
    }
    tx.set(db.doc("customerAgeVerifications/"+uid),proof);
    tx.update(ref,{consumedDigest:proof.evidenceDigest,status:"completed"});
    tx.create(db.doc("ageVerificationAudit/"+sessionId),{uid,status:"approved",evidenceDigest:proof.evidenceDigest,atMs:now});
    return {status:"approved",replayed:false};
  });
}
// No public endpoint accepts arbitrary provider payloads. A contracted adapter
// must authenticate its transport and bind its session before invoking ingestion.
// This is our internal attestation contract, NOT a claimed vendor API.
module.exports={verifyAttestation,ingestAttestation};
