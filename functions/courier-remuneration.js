"use strict";
const {createHash,randomUUID}=require("node:crypto");
const {onCall,HttpsError}=require("firebase-functions/v2/https");
const {onDocumentWritten}=require("firebase-functions/v2/firestore");
const {Timestamp,FieldValue}=require("firebase-admin/firestore");
const core=require("./courier-offer-contract.cjs");
const {authorize,readyForDispatch}=require("./courier-assignment");
const {requireCourierAdministrator,requireCourierIdentity,requireApprovedCourier,isApprovedCourierProfile}=require("./courier-authorization");
const {assertCustomerAccountActive}=require("./customer-account-state");
const {assertCurrentCourierAcceptance}=require("./courier-policy");
const {prepareOperationalId}=require("./operational-order-id");
const {planCourierDelivery,writeCourierDelivery}=require("./courier-deliveries");
const {enqueueNotice}=require("./courier-notifications");
const digest=v=>createHash("sha256").update(JSON.stringify(v)).digest("hex");
const id=v=>typeof v==="string"&&/^[A-Za-z0-9_-]{1,128}$/.test(v);
const reject=(reason,code="failed-precondition")=>{throw new HttpsError(code,reason,{reason});};
function fields(d,allowed){if(!d||typeof d!=="object"||Array.isArray(d)||Object.keys(d).some(k=>!allowed.includes(k)))reject("INVALID_REQUEST","invalid-argument");}
function text(v,max=500){if(typeof v!=="string"||v.trim().length<3||v.length>max)reject("TEXT_REQUIRED","invalid-argument");return v.trim();}
function requestId(d){if(!id(d.requestId)||d.requestId.length<16)reject("REQUEST_ID_REQUIRED","invalid-argument");}
function table(input){
 fields(input,["bands","granularityMeters","mode","conditions","offerValiditySeconds"]);
 if(![1,100].includes(input.granularityMeters)||!["perDelivery","shiftClosing"].includes(input.mode)||
 !Number.isSafeInteger(input.offerValiditySeconds)||input.offerValiditySeconds<=0||input.offerValiditySeconds>86400||
 !Array.isArray(input.bands)||!input.bands.length||input.bands.length>300)reject("INVALID_TABLE","invalid-argument");
 let end=0;const bands=input.bands.map(b=>{
  fields(b,["fromMeters","toMeters","amountMinor"]);
  if(!Number.isSafeInteger(b.fromMeters)||!Number.isSafeInteger(b.toMeters)||b.fromMeters!==end||b.toMeters<=end||b.toMeters>30000||
   b.fromMeters%input.granularityMeters||b.toMeters%input.granularityMeters||!Number.isSafeInteger(b.amountMinor)||b.amountMinor<0)reject("INVALID_BAND","invalid-argument");
  end=b.toMeters;return {...b};
 });return {bands,granularityMeters:input.granularityMeters,mode:input.mode,conditions:text(input.conditions,2000),offerValiditySeconds:input.offerValiditySeconds};
}
function calculate(t,distance){
 const checked=table({bands:t.bands,granularityMeters:t.granularityMeters,mode:t.mode,conditions:t.conditions,offerValiditySeconds:t.offerValiditySeconds});
 if(!Number.isSafeInteger(distance)||distance<0)reject("DISTANCE_NOT_VERIFIED");
 const b=checked.bands.find((b,i)=>(distance>b.fromMeters||i===0&&distance===0)&&distance<=b.toMeters);
 if(!b)reject("REMUNERATION_OUT_OF_RANGE");return b.amountMinor;
}
async function admin(db,tx,r,superOnly=false){const uid=superOnly?requireCourierAdministrator(r):authorize(r);await assertCustomerAccountActive(db,uid,tx);if((await tx.get(db.doc("couriers/"+uid))).exists)reject("ADMIN_ACCOUNT_REQUIRED","permission-denied");return uid;}
async function receipt(tx,db,uid,d,operation){const ref=db.doc("courierRemunerationRequests/"+digest([uid,d.requestId])),old=(await tx.get(ref)).data(),fingerprint=digest([operation,d]);if(old&&old.fingerprint!==fingerprint)reject("REQUEST_REUSED","already-exists");return {ref,fingerprint,result:old?.result};}
function done(tx,rec,result){tx.create(rec.ref,{fingerprint:rec.fingerprint,result,createdAt:FieldValue.serverTimestamp()});return result;}
function motofrete(review,now){return review?.status==="verified"&&review.payerCnpj===core.PAYER&&id(review.reviewedBy)&&typeof review.evidenceRef==="string"&&review.evidenceRef.length>=3&&Number.isSafeInteger(review.validUntilMs)&&review.validUntilMs>now;}
async function saveTable(db,r){requireCourierAdministrator(r);const d=r.data;fields(d,["requestId","expectedVersion","table","reason"]);requestId(d);const next=table(d.table),reason=text(d.reason);
 return db.runTransaction(async tx=>{const uid=await admin(db,tx,r,true),rec=await receipt(tx,db,uid,d,"table");if(rec.result)return rec.result;
  const ref=db.doc("courierRemunerationConfig/current"),old=(await tx.get(ref)).data();if((old?.version??null)!==d.expectedVersion)reject("TABLE_CHANGED","aborted");
  const version=digest([uid,d.requestId]),record={...next,version,payerCnpj:core.PAYER,approvedBy:uid,reason,createdAt:Timestamp.now()};
  tx.create(db.doc("courierRemunerationVersions/"+version),record);tx.set(ref,record);
  return done(tx,rec,{version});});}
async function getTable(db,r){requireCourierAdministrator(r);return db.runTransaction(async tx=>{await admin(db,tx,r,true);const current=(await tx.get(db.doc("courierRemunerationConfig/current"))).data();const history=await tx.get(db.collection("courierRemunerationVersions").orderBy("createdAt","desc").limit(30));return {current:current??null,history:history.docs.map(x=>x.data())};});}
async function reviewDocuments(db,r){requireCourierAdministrator(r);const d=r.data;fields(d,["requestId","courierUid","evidenceRef","validUntilMs","reason","checks"]);requestId(d);
 if(!id(d.courierUid)||!Number.isSafeInteger(d.validUntilMs)||d.validUntilMs<=Date.now())reject("DOCUMENT_REVIEW_INVALID");
 fields(d.checks,["identityLicense","professionalRequirements","vehicleEquipment","localRules"]);
 if(!["identityLicense","professionalRequirements","vehicleEquipment","localRules"].every(k=>d.checks[k]===true))reject("DOCUMENT_REVIEW_INCOMPLETE");
 const evidenceRef=text(d.evidenceRef),reason=text(d.reason);
 return db.runTransaction(async tx=>{const uid=await admin(db,tx,r,true),rec=await receipt(tx,db,uid,d,"documents");if(rec.result)return rec.result;
  const courier=(await tx.get(db.doc("couriers/"+d.courierUid))).data();if(!courier)reject("COURIER_NOT_FOUND");
  const record={courierUid:d.courierUid,status:"verified",payerCnpj:core.PAYER,evidenceRef,reason,checks:d.checks,validUntilMs:d.validUntilMs,reviewedBy:uid,reviewedAt:Timestamp.now()};
  tx.set(db.doc("courierMotofreteReviews/"+d.courierUid),record);tx.create(db.doc("courierMotofreteReviewHistory/"+digest([uid,d.requestId])),record);return done(tx,rec,{status:"verified"});});}
function routeDistance(quote,order,orderId){
 if(!quote||quote.uid!==order.customerUid||quote.orderId!==orderId||quote.provider!=="google-routes"||
 !Number.isSafeInteger(quote.distanceMeters)||quote.distanceMeters<0||!quote.destination||
 quote.destination.latitude!==order.deliveryAddress?.latitude||quote.destination.longitude!==order.deliveryAddress?.longitude)reject("DISTANCE_NOT_VERIFIED");
 return quote.distanceMeters;
}
function finance(order,official){const keys=["itemsTotal","deliveryFee","customerFee","merchantFee","merchantNet","platformFee","totalBRL"];
 if(!official||keys.some(k=>typeof official[k]!=="number"||!Number.isFinite(official[k])||official[k]<0||official[k]!==order[k]))reject("FINANCIAL_CONTRACT_INVALID");}
const RULE="deliveryFee100-v1";
const CONDITIONS="Chamaê Delivery 1.0: repasse de 100% do frete autoritativo da entrega concluída normalmente. Retenção R$ 0,00; sem desconto de R$ 1,00 e sem fundo de investimento. Pit Stop V8 responsável pelo acerto. Cancelamentos, retornos e execução parcial sujeitos à revisão, sem cálculo arbitrário.";
function freightMinor(order,official){
 finance(order,official);
 // The private server financial is the source; never caller data or a new route calculation.
 const value=official.deliveryFee;
 if(!Number.isFinite(value)||value<0||!/^\d+(?:\.\d{1,2})?$/.test(String(value)))reject("INVALID_DELIVERY_FEE");
 const [whole,fraction=""]=String(value).split(".");const minor=Number(whole)*100+Number(fraction.padEnd(2,"0"));
 if(!Number.isSafeInteger(minor))reject("INVALID_DELIVERY_FEE");return minor;
}
function offerOptions(d){if(!["perDelivery","shiftClosing"].includes(d.mode)||!Number.isSafeInteger(d.offerValiditySeconds)||d.offerValiditySeconds<1||d.offerValiditySeconds>86400)reject("OFFER_OPTIONS_REQUIRED");}
function offerView(o){return {id:o.id,orderId:o.orderId,courierUid:o.courierUid,displayOrderId:o.displayOrderId,distanceMeters:o.distanceMeters,revision:o.revision,status:o.status,expiresAtMs:o.expiresAtMs,terms:o.terms};}
async function propose(db,r){authorize(r);const d=r.data;fields(d,["requestId","orderId","courierUid","mode","offerValiditySeconds"]);requestId(d);offerOptions(d);if(!id(d.orderId)||!id(d.courierUid))reject("INVALID_REQUEST");
 return db.runTransaction(async tx=>{const uid=await admin(db,tx,r),rec=await receipt(tx,db,uid,d,"offer");if(rec.result)return rec.result;
  const order=(await tx.get(db.doc("orders/"+d.orderId))).data();if(!order||order.courierUid||order.h03OfferId||order.courierPaid||order.courierSettlementId||order.courierPickedUpAt)reject("ORDER_ALREADY_ASSIGNED");
  if(!readyForDispatch(order)||!["Novo","Em Separação"].includes(order.status))reject("ORDER_NOT_ELIGIBLE");
  const c=(await tx.get(db.doc("couriers/"+d.courierUid))).data(),review=(await tx.get(db.doc("courierMotofreteReviews/"+d.courierUid))).data(),now=Date.now();
  await assertCustomerAccountActive(db,d.courierUid,tx);await assertCurrentCourierAcceptance(db,d.courierUid,tx);
  if(!isApprovedCourierProfile(c)||c.online!==true||!motofrete(review,now))reject("COURIER_NOT_ELIGIBLE");
  if((await tx.get(db.doc("courierRemunerationOrders/"+d.orderId))).exists)reject("ORDER_REMUNERATION_REQUIRES_REVIEW");
  if(!/^[a-f0-9]{64}$/.test(order.deliveryQuoteId||""))reject("DISTANCE_NOT_VERIFIED");
  const quote=(await tx.get(db.doc("deliveryQuotes/"+order.deliveryQuoteId))).data(),distanceMeters=routeDistance(quote,order,d.orderId);
  const amountMinor=freightMinor(order,(await tx.get(db.doc("orderFinancials/"+d.orderId))).data());
  const identity=await prepareOperationalId(tx,db,d.orderId,order),offerId=digest([uid,d.requestId]);
  const terms={id:offerId,revision:1,orderId:d.orderId,courierUid:d.courierUid,amountMinor,currency:"BRL",mode:d.mode,conditions:CONDITIONS,payerCnpj:core.PAYER,validUntilMs:now+d.offerValiditySeconds*1000,status:"approved",approvedBy:uid,approvalEvidenceId:RULE,tableVersion:RULE,remunerationRule:RULE,sourceDeliveryFeeMinor:amountMinor,retentionMinor:0,distanceMeters,quoteId:order.deliveryQuoteId};terms.digest=core.termsDigest(terms);
  const input={order:{...order,id:d.orderId,revision:1},terms};
  const planned=core.propose(input,{uid,authenticated:true,anonymous:false,canOfferForPitStop:true,existingDispatchGuardsPassed:true,currentPolicyAccepted:true,courierApproved:true,motofreteVerified:true,available:true},{requestId:d.requestId,offerId,orderId:d.orderId,courierUid:d.courierUid,termsId:offerId,expectedOrderRevision:1},now);
  const offer={...planned.result,displayOrderId:identity.displayOrderId,distanceMeters,createdBy:uid,createdAt:Timestamp.now()};
  identity.write();tx.create(db.doc("courierOffers/"+offerId),offer);tx.create(db.doc("courierOfferAudit/"+digest([offerId,"offered"])),{offerId,type:"offered",actorUid:uid,at:Timestamp.now()});
  return done(tx,rec,offerView(offer));});}
async function listOffers(db,r){const uid=requireCourierIdentity(r);return db.runTransaction(async tx=>{await assertCustomerAccountActive(db,uid,tx);const rows=await tx.get(db.collection("courierOffers").where("courierUid","==",uid).where("status","==","offered").where("expiresAtMs",">",Date.now()).orderBy("expiresAtMs").limit(200));return {offers:rows.docs.map(x=>x.data()).filter(o=>o.status==="offered"&&o.expiresAtMs>Date.now()).map(offerView)};});}
async function decide(db,r){const uid=requireCourierIdentity(r),d=r.data;fields(d,["requestId","offerId","decision","offerRevision","termsDigest"]);requestId(d);if(!id(d.offerId)||!["accept","decline"].includes(d.decision))reject("INVALID_REQUEST");
 return db.runTransaction(async tx=>{await assertCustomerAccountActive(db,uid,tx);const rec=await receipt(tx,db,uid,d,"decision");if(rec.result)return rec.result;
  const ref=db.doc("courierOffers/"+d.offerId),offer=(await tx.get(ref)).data();if(!offer||offer.courierUid!==uid)reject("OFFER_NOT_OWNED","permission-denied");
  const now=Date.now(),orderRef=db.doc("orders/"+offer.orderId),order=(await tx.get(orderRef)).data();
  const state={offers:{[offer.id]:offer},order:{...order,id:offer.orderId,revision:1},terms:offer.terms};
  const ctx={uid,authenticated:true,anonymous:false};let identity,plan,c,assignmentId,previous;
  if(d.decision==="accept"){
   c=await requireApprovedCourier(db,r,tx);await assertCurrentCourierAcceptance(db,uid,tx);
   const review=(await tx.get(db.doc("courierMotofreteReviews/"+uid))).data();
   if((await tx.get(db.doc("courierRemunerationOrders/"+offer.orderId))).exists)reject("ORDER_REMUNERATION_REQUIRES_REVIEW");
   if(!order||order.h03OfferId||!readyForDispatch(order))reject("ORDER_NOT_ELIGIBLE");
   if(offer.terms.remunerationRule!==RULE||offer.terms.tableVersion!==RULE||offer.terms.retentionMinor!==0||offer.terms.sourceDeliveryFeeMinor!==offer.terms.amountMinor)reject("TERMS_CHANGED");
   const quote=(await tx.get(db.doc("deliveryQuotes/"+offer.terms.quoteId))).data();
   if(order.deliveryQuoteId!==offer.terms.quoteId||routeDistance(quote,order,offer.orderId)!==offer.distanceMeters)reject("TERMS_CHANGED");
   if(freightMinor(order,(await tx.get(db.doc("orderFinancials/"+offer.orderId))).data())!==offer.terms.amountMinor)reject("TERMS_CHANGED");
   ctx.existingDispatchGuardsPassed=true;ctx.currentPolicyAccepted=true;ctx.courierApproved=true;ctx.motofreteVerified=motofrete(review,now);ctx.available=c.profile.online===true;
   identity=await prepareOperationalId(tx,db,offer.orderId,order);
   previous=(await tx.get(db.doc("courierDeliveries/"+offer.orderId))).data();
   plan=planCourierDelivery({orderId:offer.orderId,order:{...order,displayOrderId:identity.displayOrderId},previous:previous||{},exists:!!previous,registered:true,now:Timestamp.fromMillis(now),binding:{courierUid:uid,status:order.status}});
   if(plan.revoked)reject("DELIVERY_PROJECTION_INVALID");assignmentId=randomUUID();
  }
  const out=core.decide(state,ctx,d,now);tx.update(ref,{status:out.state.offers[offer.id].status,revision:offer.revision+1,decidedAt:Timestamp.fromMillis(now)});
  tx.create(db.doc("courierOfferAudit/"+digest([uid,d.requestId])),{offerId:offer.id,type:d.decision,actorUid:uid,at:Timestamp.fromMillis(now),termsDigest:offer.terms.digest});
  if(d.decision==="accept"){
   identity.write();
   tx.update(orderRef,{courierUid:uid,courierName:c.profile.name,displayOrderId:identity.displayOrderId,courierAssignedAt:Timestamp.fromMillis(now),courierAssignmentId:assignmentId,courierAssignmentExpiresAt:Timestamp.fromMillis(now+8*60*60*1000),courierPickupState:"assigned",h03OfferId:offer.id,updatedAt:Timestamp.fromMillis(now)});
   tx.create(db.doc("courierPickupAssignments/"+assignmentId),{orderId:offer.orderId,courierUid:uid,status:"active",createdAt:Timestamp.fromMillis(now)});
   tx.create(db.doc("courierRemunerationOrders/"+offer.orderId),{orderId:offer.orderId,offerId:offer.id,courierUid:uid,assignmentId,amountMinor:offer.terms.amountMinor,termsDigest:offer.terms.digest,acceptedAt:Timestamp.fromMillis(now)});
   tx.create(db.doc("courierRemunerationAgreements/"+offer.id),{offerId:offer.id,orderId:offer.orderId,courierUid:uid,assignmentId,displayOrderId:identity.displayOrderId,terms:offer.terms,distanceMeters:offer.distanceMeters,acceptedAt:Timestamp.fromMillis(now),status:"accepted"});
   writeCourierDelivery(tx,{plan,deliveryRef:db.doc("courierDeliveries/"+offer.orderId),auditRef:db.collection("courierDeliveryAudit").doc(),orderId:offer.orderId,previous:previous||{},actorUid:uid});
   enqueueNotice(tx,db,offer.orderId,assignmentId,uid,c.profile);
  }
  return done(tx,rec,{status:d.decision==="accept"?"accepted":"declined",offerId:offer.id});});}

// Immutable, minimal server-observed stages. Trigger retry uses the event ID.
async function observe(db,orderId,eventId,order){if(!id(orderId)||!order?.h03OfferId)return;const offerId=order.h03OfferId;
 return db.runTransaction(async tx=>{const ref=db.doc("courierRemunerationAgreements/"+offerId),a=(await tx.get(ref)).data(),eventRef=db.doc("courierRemunerationStages/"+digest([orderId,eventId]));if(!a||(await tx.get(eventRef)).exists)return;
  const stage={offerId,orderId,courierUid:a.courierUid,assignmentId:a.assignmentId,status:order.status||null,pickupState:order.courierPickupState||null,phase:order.courierDeliveryPhase||null,serverAcknowledged:true,observedAt:Timestamp.now()};
  for(const k of ["courierPickedUpAt","courierArrivedAt","completedAt","courierAssignedAt","dispatchedAt"])if(order[k] instanceof Timestamp)stage[k]=order[k];
  tx.create(eventRef,stage);
  if(/cancel/i.test(order.status||"")||order.deliveryIncidentStatus&&order.deliveryIncidentStatus!=="resolved"||order.courierUid!==a.courierUid)tx.set(db.doc("courierRemunerationReviews/"+offerId),{offerId,orderId,courierUid:a.courierUid,status:"pendingRulesAndReview",amountMinor:null,calculationEnabled:false,reason:"Ocorrência operacional autoritativa",updatedAt:Timestamp.now()},{merge:true});
 });}
async function incident(db,r){const uid=requireCourierIdentity(r),d=r.data;fields(d,["requestId","offerId","kind","reason"]);requestId(d);if(!id(d.offerId)||!["cancellation","return"].includes(d.kind))reject("INVALID_REQUEST");const reason=text(d.reason);
 return db.runTransaction(async tx=>{await assertCustomerAccountActive(db,uid,tx);const rec=await receipt(tx,db,uid,d,"incident");if(rec.result)return rec.result;
  const a=(await tx.get(db.doc("courierRemunerationAgreements/"+d.offerId))).data();if(!a)reject("AGREEMENT_NOT_FOUND");if(a.courierUid!==uid)await admin(db,tx,r);
  const order=(await tx.get(db.doc("orders/"+a.orderId))).data();if(!order||a.settlementId)reject("REVIEW_NOT_AVAILABLE");
  const event={offerId:d.offerId,orderId:a.orderId,courierUid:a.courierUid,kind:d.kind,reason,actorUid:uid,at:Timestamp.now(),status:"reportedPendingVerification"};
  tx.create(db.doc("courierRemunerationIncidentEvents/"+digest([uid,d.requestId])),event);
  tx.set(db.doc("courierRemunerationReviews/"+d.offerId),{...event,status:"pendingRulesAndReview",amountMinor:null,deductionsMinor:null,calculationEnabled:false},{merge:true});return done(tx,rec,{status:"pendingRulesAndReview"});});}
async function cash(db,r){authorize(r,["superadmin","finance","operations_admin"]);return db.runTransaction(async tx=>{const actor=authorize(r,["superadmin","finance","operations_admin"]);await assertCustomerAccountActive(db,actor,tx);if((await tx.get(db.doc("couriers/"+actor))).exists)reject("ADMIN_ACCOUNT_REQUIRED");const agreements=await tx.get(db.collection("courierRemunerationAgreements").orderBy("acceptedAt","desc").limit(100)),receipts=await tx.get(db.collection("courierRemunerationSettlements").orderBy("createdAt","desc").limit(30));const rows=[];
 for(const doc of agreements.docs){const a=doc.data(),o=(await tx.get(db.doc("orders/"+a.orderId))).data(),review=(await tx.get(db.doc("courierRemunerationReviews/"+doc.id))).data();rows.push({...a,review:review??null,orderStatus:o?.status??null,eligible:!!o&&o.status==="Concluído"&&o.paymentStatus==="Pago"&&!review&&!a.settlementId});}
 return {agreements:rows,receipts:receipts.docs.map(d=>({id:d.id,...d.data()}))};});}
async function reviewDetail(db,r){authorize(r,["superadmin","finance","operations_admin"]);fields(r.data,["offerId"]);if(!id(r.data.offerId))reject("INVALID_REQUEST");
 return db.runTransaction(async tx=>{const uid=authorize(r,["superadmin","finance","operations_admin"]);await assertCustomerAccountActive(db,uid,tx);if((await tx.get(db.doc("couriers/"+uid))).exists)reject("ADMIN_ACCOUNT_REQUIRED");
  const a=(await tx.get(db.doc("courierRemunerationAgreements/"+r.data.offerId))).data();if(!a)reject("AGREEMENT_NOT_FOUND");
  const review=(await tx.get(db.doc("courierRemunerationReviews/"+r.data.offerId))).data();const result={agreement:a,review:review??null,calculationEnabled:false};
  for(const [key,collection] of [["stages","courierRemunerationStages"],["reports","courierRemunerationIncidentEvents"]]){const rows=await tx.get(db.collection(collection).where("offerId","==",r.data.offerId).limit(201));result[key]=rows.docs.slice(0,200).map(d=>({id:d.id,...d.data()}));result[key+"Truncated"]=rows.size>200;}
  return result;});}
async function settle(db,r){authorize(r,["superadmin","finance"]);const d=r.data;fields(d,["requestId","offerIds","proofReference","reason","confirmExternalPayment"]);requestId(d);
 if(d.confirmExternalPayment!==true||!Array.isArray(d.offerIds)||!d.offerIds.length||d.offerIds.length>100||!d.offerIds.every(id)||new Set(d.offerIds).size!==d.offerIds.length)reject("INVALID_SETTLEMENT");const proofReference=text(d.proofReference),reason=text(d.reason);
 return db.runTransaction(async tx=>{const uid=authorize(r,["superadmin","finance"]);await assertCustomerAccountActive(db,uid,tx);if((await tx.get(db.doc("couriers/"+uid))).exists)reject("ADMIN_ACCOUNT_REQUIRED");const rec=await receipt(tx,db,uid,d,"settlement");if(rec.result)return rec.result;
  let courierUid,mode,totalMinor=0;const lines=[];for(const offerId of d.offerIds){const a=(await tx.get(db.doc("courierRemunerationAgreements/"+offerId))).data();if(!a||a.settlementId)reject("ALREADY_SETTLED_OR_MISSING");
   const o=(await tx.get(db.doc("orders/"+a.orderId))).data(),review=await tx.get(db.doc("courierRemunerationReviews/"+offerId));
   const ledger=(await tx.get(db.doc("courierRemunerationOrders/"+a.orderId))).data();
   if(ledger&&(ledger.settlementId||ledger.offerId!==offerId||ledger.courierUid!==a.courierUid||ledger.assignmentId!==a.assignmentId||ledger.termsDigest!==a.terms.digest)||a.terms.remunerationRule===RULE&&!ledger||lines.some(l=>l.orderId===a.orderId))reject("ORDER_REMUNERATION_REQUIRES_REVIEW");
   if(review.exists||!o||o.h03OfferId!==offerId||o.courierUid!==a.courierUid||o.courierAssignmentId!==a.assignmentId||o.status!=="Concluído"||o.paymentStatus!=="Pago"||!(o.completedAt instanceof Timestamp)||o.courierPaid||o.courierSettlementId||o.deliveryIncidentStatus&&o.deliveryIncidentStatus!=="resolved")reject("SETTLEMENT_REQUIRES_REVIEW");
   if(a.terms.digest!==core.termsDigest(a.terms)||a.terms.payerCnpj!==core.PAYER||!Number.isSafeInteger(a.terms.amountMinor)||a.terms.amountMinor<0)reject("REMUNERATION_INVALID");
   if(courierUid&&courierUid!==a.courierUid||mode&&mode!==a.terms.mode)reject("MIXED_SETTLEMENT");courierUid=a.courierUid;mode=a.terms.mode;totalMinor+=a.terms.amountMinor;
   if(!Number.isSafeInteger(totalMinor))reject("TOTAL_INVALID");lines.push({offerId,orderId:a.orderId,displayOrderId:a.displayOrderId,amountMinor:a.terms.amountMinor,termsDigest:a.terms.digest,tableVersion:a.terms.tableVersion});
  }
  const c=(await tx.get(db.doc("couriers/"+courierUid))).data();if(!c)reject("COURIER_NOT_FOUND");if(mode==="shiftClosing"&&c.online!==false)reject("SHIFT_NOT_CLOSED");
  const settlementId=digest([uid,d.requestId]),record={id:settlementId,payerCnpj:core.PAYER,courierUid,mode,totalMinor,currency:"BRL",lines,proofReference,reason,recordedBy:uid,createdAt:Timestamp.now(),status:"externalPaymentRecorded",transferExecuted:false};
  for(const line of lines){tx.update(db.doc("courierRemunerationAgreements/"+line.offerId),{settlementId,status:"settled"});tx.set(db.doc("courierRemunerationOrders/"+line.orderId),{orderId:line.orderId,offerId:line.offerId,courierUid,settlementId,amountMinor:line.amountMinor,termsDigest:line.termsDigest,settledAt:Timestamp.now()},{merge:true});}
  tx.create(db.doc("courierRemunerationSettlements/"+settlementId),record);return done(tx,rec,{settlementId});});}
async function ownAgreements(db,r){const uid=requireCourierIdentity(r);await assertCustomerAccountActive(db,uid);const rows=await db.collection("courierRemunerationAgreements").where("courierUid","==",uid).limit(200).get();return {agreements:rows.docs.map(d=>{const a=d.data();return {offerId:d.id,displayOrderId:a.displayOrderId,amountMinor:a.terms.amountMinor,mode:a.terms.mode,status:a.status};})};}
function createCourierRemuneration(db){const options={region:"southamerica-east1",maxInstances:10};const methods={chamaeObterRemuneracaoMotoboy:getTable,chamaeSalvarRemuneracaoMotoboy:saveTable,chamaeVerificarDocumentosMotofrete:reviewDocuments,chamaeOfertarEntrega:propose,chamaeMinhasOfertas:listOffers,chamaeResponderOferta:decide,chamaeMeusAcertosRemuneracao:ownAgreements,chamaeRegistrarOcorrenciaRemuneracao:incident,chamaeCaixaRemuneracao:cash,chamaeDetalharRevisaoRemuneracao:reviewDetail,chamaeRegistrarAcertoRemuneracao:settle};const exports={};for(const [name,fn] of Object.entries(methods))exports[name]=onCall(options,async r=>{try{return await fn(db,r);}catch(e){if(e instanceof HttpsError)throw e;throw new HttpsError("failed-precondition",e.code||"H03_OPERATION_BLOCKED");}});
 exports.chamaeRegistrarEtapasRemuneracao=onDocumentWritten({document:"orders/{orderId}",region:"southamerica-east1",retry:true},e=>e.data?.after.exists?observe(db,e.params.orderId,e.id,e.data.after.data()):null);return exports;}
module.exports={freightMinor,RULE,table,calculate,routeDistance,motofrete,saveTable,getTable,reviewDocuments,propose,listOffers,decide,observe,incident,cash,reviewDetail,settle,createCourierRemuneration};
