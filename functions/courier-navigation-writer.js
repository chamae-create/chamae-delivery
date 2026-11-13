"use strict";
// Server adapter only: no callable export, HTTP listener, provider URL or fallback dataset.
const {Timestamp, FieldValue}=require('firebase-admin/firestore');
const {HttpsError}=require('firebase-functions/v2/https');
const {createHash}=require('node:crypto');
const {isDeepStrictEqual}=require('node:util');
const {authorize}=require('./courier-assignment');
const {matchAssignment}=require('./courier-pickup');
const {isApprovedCourierProfile}=require('./courier-authorization');
const {assertCustomerAccountActive}=require('./customer-account-state');
const {validateQuote}=require('./delivery-pricing');
const {verifiedQuoteCountry}=require('./order-acceptance');
const {createStoredNavigationProvider}=require('./courier-navigation-source');
const fail=reason=>{throw new HttpsError('failed-precondition',reason,{reason});};
const digest=value=>createHash('sha256').update(value).digest('hex');
const id=value=>typeof value==='string'&&/^[A-Za-z0-9_-]{1,128}$/.test(value);
function createNavigationSourceWriter(db,{sourceId,engine,provider,provenance}={}){
 if(db.app?.options?.projectId!=='chamae-delivery-staging')fail('STAGING_WRITER_ONLY');
 // Validate identifiers through the existing reader, never duplicate graph validation.
 createStoredNavigationProvider(db,{sourceId,engine});
 async function snapshot(tx,request,orderId){
  const actor=authorize(request);
  if((await tx.get(db.doc('couriers/'+actor))).exists)fail('ADMINISTRATIVE_IDENTITY_REQUIRED');
  const order=(await tx.get(db.doc('orders/'+orderId))).data();
  if(!order||!id(order.customerUid)||!id(order.courierUid)||!id(order.courierAssignmentId)||
    order.status!=='Em Separação'||!(order.acceptedAt instanceof Timestamp)||
    !matchAssignment(order,order.courierUid,order.courierAssignmentId,Date.now()))fail('ROUTE_ASSIGNMENT_NOT_READY');
  await assertCustomerAccountActive(db,order.customerUid,tx);
  await assertCustomerAccountActive(db,order.courierUid,tx);
  const courier=(await tx.get(db.doc('couriers/'+order.courierUid))).data();
  const binding=(await tx.get(db.doc('courierPickupAssignments/'+order.courierAssignmentId))).data();
  if(!isApprovedCourierProfile(courier)||binding?.status!=='active'||binding.orderId!==orderId||binding.courierUid!==order.courierUid)fail('ROUTE_ASSIGNMENT_NOT_READY');
  if(!/^[a-f0-9]{64}$/.test(order.deliveryQuoteId||''))fail('ROUTE_QUOTE_REQUIRED');
  const quote=(await tx.get(db.doc('deliveryQuotes/'+order.deliveryQuoteId))).data();
  validateQuote(quote,order,orderId);
  if(quote.orderId!==orderId)fail('ROUTE_QUOTE_REQUIRED');
  const country=verifiedQuoteCountry(quote,order.deliveryAddress);
  // Current commercial scope is Brazil. Technical PY coverage is not authorization.
  if(country!=='BR')fail('COMMERCIAL_TERRITORY_BLOCKED');
  return {context:{customerUid:order.customerUid,orderId,assignmentId:order.courierAssignmentId,courierUid:order.courierUid,
   origin:{latitude:quote.origin.latitude,longitude:quote.origin.longitude},
   destination:{latitude:order.deliveryAddress.latitude,longitude:order.deliveryAddress.longitude},
   assignmentExpiresAtMs:order.courierAssignmentExpiresAt.toMillis()},country,
   quoteVersion:quote.version,quoteId:order.deliveryQuoteId};
 }
 async function validate(source,context){
  const fake={doc:()=>({get:async()=>({data:()=>source})})};
  return createStoredNavigationProvider(fake,{sourceId,engine})(context);
 }
 return async function write(request){
  authorize(request); // Firebase verified request required; callers must not construct auth from input.
  if(!request.data||Object.keys(request.data).some(k=>k!=='orderId')||!id(request.data.orderId))throw new HttpsError('invalid-argument','ORDER_ID_ONLY');
  if(typeof provider!=='function'||!provenance||provenance.sourceId!==sourceId||
   !['licenseReference','geographicValidationReference','datasetVersion'].every(k=>typeof provenance[k]==='string'&&provenance[k].trim()))fail('AUTHORITATIVE_PROVIDER_UNAVAILABLE');
  const orderId=request.data.orderId;
  const initial=await db.runTransaction(async tx=>{
   const state=await snapshot(tx,request,orderId);
   const ref=db.doc('customerDeliverySecrets/'+state.context.customerUid+'/courierRouteInputs/'+state.context.assignmentId);
   const prior=(await tx.get(ref)).data();
   if(prior){await validate(prior,state.context);return {replayed:true,mapSha256:digest(prior.mapJson)};}
   return {state,ref};
  });
  if(initial.replayed)return initial;
  const {state,ref}=initial;
  // No UID, name, PIN, phone, notes, items or financial payload sent to the provider.
  const route=await provider({origin:state.context.origin,destination:state.context.destination,country:state.country});
  if(!route||!Number.isSafeInteger(route.expiresAtMs)||route.expiresAtMs>Date.now()+4*60*60*1000||
   route.map?.navigation?.datasetVersion!==provenance.datasetVersion)fail('AUTHORITATIVE_ROUTE_INVALID');
  const source={schemaVersion:1,status:'ready',sourceId,orderId,assignmentId:state.context.assignmentId,
   courierUid:state.context.courierUid,origin:state.context.origin,destination:state.context.destination,
   expiresAt:Timestamp.fromMillis(route.expiresAtMs),mapJson:JSON.stringify(route.map)};
  await validate(source,state.context);
  return db.runTransaction(async tx=>{
   const current=await snapshot(tx,request,orderId);
   if(!isDeepStrictEqual(current,state))fail('ROUTE_SOURCE_CHANGED');
   const existing=(await tx.get(ref)).data();
   if(existing){await validate(existing,current.context);return {replayed:true,mapSha256:digest(existing.mapJson)};}
   await validate(source,current.context);
   const mapSha256=digest(source.mapJson);
   tx.create(ref,source); // Never overwrite an established assignment route.
   tx.create(db.collection('courierRouteSourceAudit').doc(),{actorUid:request.auth.uid,orderId,
    assignmentId:state.context.assignmentId,sourceId,engine,datasetVersion:provenance.datasetVersion,
    mapSha256,licenseReference:provenance.licenseReference,geographicValidationReference:provenance.geographicValidationReference,
    at:FieldValue.serverTimestamp()});
   return {replayed:false,mapSha256};
  });
 };
}
module.exports={createNavigationSourceWriter};
