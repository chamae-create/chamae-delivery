'use strict';
// Candidate domain only. No Firebase imports, callable exports or payment writer.
// Context/state are supplied by a future authenticated server transaction, never request data.
const {createHash}=require('node:crypto');
const PAYER='41.952.465/0001-20';
const fail=code=>{throw Object.assign(new Error(code),{code});};
const hash=v=>createHash('sha256').update(JSON.stringify(v)).digest('hex');
const id=v=>typeof v==='string'&&/^[A-Za-z0-9_-]{1,128}$/.test(v);
function serverTime(now){if(!Number.isSafeInteger(now)||now<0)fail('INVALID_SERVER_TIME');}
function exact(value,keys){if(!value||Array.isArray(value)||typeof value!=='object'||Object.keys(value).some(k=>!keys.includes(k)))fail('INVALID_REQUEST');}
function termsDigest(t){const source=t.remunerationRule===undefined?[]:[t.remunerationRule,t.sourceDeliveryFeeMinor,t.retentionMinor];return hash([t.id,t.revision,t.orderId,t.courierUid,t.amountMinor,t.currency,t.mode,t.conditions,t.payerCnpj,t.validUntilMs,t.tableVersion??null,t.distanceMeters??null,t.quoteId??null,...source]);}
function validTerms(t,orderId,courierUid,now){
 if(!t||!id(t.id)||!Number.isSafeInteger(t.revision)||t.revision<1||t.orderId!==orderId||t.courierUid!==courierUid||
 t.status!=='approved'||!id(t.approvedBy)||!id(t.approvalEvidenceId)||t.payerCnpj!==PAYER||t.currency!=='BRL'||
 !Number.isSafeInteger(t.amountMinor)||t.amountMinor<0||!['perDelivery','shiftClosing'].includes(t.mode)||
 typeof t.conditions!=='string'||!t.conditions.trim()||!Number.isSafeInteger(t.validUntilMs)||t.validUntilMs<=now||
 t.digest!==termsDigest(t))fail('REMUNERATION_NOT_APPROVED');
}
function identity(ctx){if(!ctx||!id(ctx.uid)||ctx.authenticated!==true||ctx.anonymous!==false)fail('UNAUTHENTICATED');}
function ready(state,ctx){
 if(!state.order||state.order.courierUid||!['Novo','Em Separação'].includes(state.order.status)||
 state.order.financialValidationStatus!=='validated'||state.order.courierPaid===true||state.order.courierSettlementId||
 state.order.courierPickedUpAt||ctx.existingDispatchGuardsPassed!==true)fail('ORDER_NOT_ELIGIBLE');
}
function eligible(ctx){if(ctx.currentPolicyAccepted!==true||ctx.courierApproved!==true||ctx.motofreteVerified!==true||ctx.available!==true)fail('COURIER_NOT_ELIGIBLE');}
function requestCheck(r,keys){exact(r,keys);if(!id(r.requestId)||r.requestId.length<16)fail('INVALID_REQUEST');}
function replay(state,ctx,r){const key=ctx.uid+':'+r.requestId, fingerprint=hash(r),old=state.receipts?.[key];if(old){if(old.fingerprint!==fingerprint)fail('REQUEST_REUSED');return {key,fingerprint,old};}return {key,fingerprint};}
function finish(state,receipt,result){state.receipts[receipt.key]={fingerprint:receipt.fingerprint,result};return {state,result};}
function offerSnapshot(offer){return {id:offer.id,orderId:offer.orderId,courierUid:offer.courierUid,status:offer.status,revision:offer.revision,expiresAtMs:offer.expiresAtMs,terms:structuredClone(offer.terms)};}
function propose(current,ctx,r,now){
 serverTime(now);
 identity(ctx);if(ctx.canOfferForPitStop!==true)fail('FORBIDDEN');
 requestCheck(r,['requestId','offerId','orderId','courierUid','termsId','expectedOrderRevision']);
 if(![r.offerId,r.orderId,r.courierUid,r.termsId].every(id))fail('INVALID_REQUEST');
 const replayed=replay(current,ctx,r);if(replayed.old)return {state:current,result:replayed.old.result,replayed:true};
 if(current.order.id!==r.orderId||current.order.revision!==r.expectedOrderRevision)fail('STALE_ORDER');
 ready(current,ctx);eligible(ctx);validTerms(current.terms,r.orderId,r.courierUid,now);
 if(current.terms.id!==r.termsId)fail('REMUNERATION_NOT_APPROVED');
 if(current.offers?.[r.offerId])fail('OFFER_EXISTS');
 const state=structuredClone(current);state.offers??={};state.receipts??={};state.audit??=[];
 const offer={id:r.offerId,orderId:r.orderId,courierUid:r.courierUid,status:'offered',revision:1,expiresAtMs:current.terms.validUntilMs,terms:structuredClone(current.terms)};
 state.offers[r.offerId]=offer;state.audit.push({type:'offerCreated',offerId:r.offerId,actorUid:ctx.uid,atMs:now});
 // No courierUid, assignment, QR grant, reliability event or financial write on proposal.
 return finish(state,replayed,offerSnapshot(offer));
}
function decide(current,ctx,r,now){
 serverTime(now);
 identity(ctx);requestCheck(r,['requestId','offerId','decision','offerRevision','termsDigest']);
 if(!id(r.offerId)||!['accept','decline'].includes(r.decision))fail('INVALID_REQUEST');
 const old=replay(current,ctx,r);if(old.old)return {state:current,result:old.old.result,replayed:true};
 const offer=current.offers?.[r.offerId];
 if(!offer||offer.courierUid!==ctx.uid)fail('FORBIDDEN');
 if(offer.status!=='offered'||offer.revision!==r.offerRevision||offer.expiresAtMs<=now)fail('OFFER_NOT_CURRENT');
 const state=structuredClone(current),target=state.offers[r.offerId];state.receipts??={};state.audit??=[];
 if(r.decision==='decline'){
  target.status='declined';target.revision++;state.audit.push({type:'offerDeclined',offerId:r.offerId,actorUid:ctx.uid,atMs:now});
  // Refusal is allowed OFF, requires no reason and never writes penalties or assignment.
  return finish(state,old,{status:'declined',offerId:r.offerId});
 }
 ready(current,ctx);eligible(ctx);
 if(current.order.id!==offer.orderId)fail('ORDER_NOT_ELIGIBLE');
 validTerms(offer.terms,offer.orderId,ctx.uid,now);
 validTerms(current.terms,offer.orderId,ctx.uid,now);
 if(r.termsDigest!==offer.terms.digest||current.terms.digest!==offer.terms.digest)fail('TERMS_CHANGED');
 // Final assignment intent must be committed atomically with existing assignment guards/projections.
 target.status='accepted';target.revision++;state.order.courierUid=ctx.uid;state.order.revision++;
 state.assignmentIntent={orderId:offer.orderId,courierUid:ctx.uid,offerId:offer.id,acceptedTerms:structuredClone(offer.terms),acceptedAtMs:now};
 for(const other of Object.values(state.offers))if(other.id!==offer.id&&other.status==='offered'){other.status='superseded';other.revision++;}
 state.audit.push({type:'offerAccepted',offerId:r.offerId,actorUid:ctx.uid,termsDigest:offer.terms.digest,atMs:now});
 return finish(state,old,{status:'accepted',offerId:r.offerId,assignmentPendingAdapter:true});
}
function recordIncident(current,ctx,r,now){
 serverTime(now);
 identity(ctx);requestCheck(r,['requestId','offerId','kind','stageEventIds','reason']);
 if(!['cancellation','return'].includes(r.kind)||!id(r.offerId)||!Array.isArray(r.stageEventIds)||!r.stageEventIds.every(id)||new Set(r.stageEventIds).size!==r.stageEventIds.length||typeof r.reason!=='string'||!r.reason.trim())fail('INVALID_REQUEST');
 const old=replay(current,ctx,r);if(old.old)return {state:current,result:old.old.result,replayed:true};
 const offer=current.offers?.[r.offerId];if(!offer||offer.status!=='accepted'||(offer.courierUid!==ctx.uid&&ctx.canReviewForPitStop!==true))fail('FORBIDDEN');
 const all=(current.stageEvents??[]).filter(e=>e.offerId===offer.id&&e.courierUid===offer.courierUid&&e.serverAcknowledged===true);
 if(r.stageEventIds.some(x=>!all.some(e=>e.id===x)))fail('UNVERIFIED_STAGE');
 const state=structuredClone(current);state.receipts??={};state.audit??=[];state.claims??=[];
 const claim={id:hash([ctx.uid,r.requestId]),offerId:offer.id,courierUid:offer.courierUid,payerCnpj:PAYER,kind:r.kind,
  stageEvents:structuredClone(all),acceptedTerms:structuredClone(offer.terms),status:'pendingRulesAndReview',amountMinor:null,
  deductionsMinor:null,calculationEnabled:false,paymentEnabled:false,reason:r.reason,recordedBy:ctx.uid,atMs:now};
 state.claims.push(claim);state.audit.push({type:'remunerationReviewRequested',claimId:claim.id,actorUid:ctx.uid,reason:r.reason,atMs:now});
 // Snapshot every acknowledged stage, not just the subset supplied by the caller.
 return finish(state,old,claim);
}
function settlePartial(){fail('PARTIAL_RULES_NOT_APPROVED');}
function activateLegacySettlement(){fail('FINANCIAL_COMPATIBILITY_NOT_APPROVED');}
module.exports={PAYER,termsDigest,propose,decide,recordIncident,settlePartial,activateLegacySettlement};
