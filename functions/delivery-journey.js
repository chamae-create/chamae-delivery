"use strict";
const {HttpsError,onCall}=require("firebase-functions/v2/https");
const {defineSecret,defineString}=require("firebase-functions/params");
const {Timestamp}=require("firebase-admin/firestore");
const {requireApprovedCourier}=require("./courier-authorization");
const {assertCurrentCourierAcceptance}=require("./courier-policy");
const {assertCustomerAccountActive}=require("./customer-account-state");
const {point}=require("./delivery-pricing");
const key=defineSecret("CHAMAE_ROUTES_API_KEY");
const mode=defineString("CHAMAE_COURIER_ROUTE_MODE",{default:""});
const reject=(code,reason)=>{throw new HttpsError(code,reason,{reason});};
const id=v=>typeof v==="string"&&/^[A-Za-z0-9_-]{1,128}$/.test(v);
const live=v=>v instanceof Timestamp&&v.toMillis()>Date.now();
function decodePolyline(encoded){
 if(typeof encoded!=="string"||!encoded||encoded.length>200000)reject("unavailable","ROUTE_INVALID");
 const points=[];let i=0,lat=0,lng=0;
 function delta(){let result=0,shift=0,b;do{
  if(i>=encoded.length||shift>30)reject("unavailable","ROUTE_INVALID");
  b=encoded.charCodeAt(i++)-63;if(b<0||b>63)reject("unavailable","ROUTE_INVALID");
  result+=(b&31)*2**shift;shift+=5;
 }while(b>=32);return result%2?-(Math.floor(result/2)+1):result/2;}
 while(i<encoded.length){lat+=delta();lng+=delta();const p={latitude:lat/1e5,longitude:lng/1e5};
  if(!point(p)||points.length>=10000)reject("unavailable","ROUTE_INVALID");points.push(p);}
 if(points.length<2)reject("unavailable","ROUTE_INVALID");return points;
}
async function googleRoute({origin,destination,apiKey,travelMode,fetchImpl=fetch}){
 if(!apiKey||!["DRIVE","TWO_WHEELER"].includes(travelMode))reject("failed-precondition","ONLINE_ROUTE_NOT_CONFIGURED");
 const waypoint=p=>({location:{latLng:p}});
 try{
  const r=await fetchImpl("https://routes.googleapis.com/directions/v2:computeRoutes",{
   method:"POST",signal:AbortSignal.timeout(10000),headers:{"Content-Type":"application/json","X-Goog-Api-Key":apiKey,
    "X-Goog-FieldMask":"routes.duration,routes.polyline.encodedPolyline,routes.legs.steps.navigationInstruction.instructions,fallbackInfo"},
   body:JSON.stringify({origin:waypoint(origin),destination:waypoint(destination),travelMode,computeAlternativeRoutes:false})});
  if(!r.ok)throw Error();const data=await r.json(),route=data.routes?.[0];
  if(data.fallbackInfo||!route||!/^\d+(\.\d+)?s$/.test(route.duration||""))throw Error();
  const durationSeconds=Number(route.duration.slice(0,-1));
  if(!Number.isFinite(durationSeconds)||durationSeconds<=0||durationSeconds>86400)throw Error();
  const geometry=decodePolyline(route.polyline?.encodedPolyline);
  const instructions=(route.legs||[]).flatMap(l=>(l.steps||[]).map(s=>s.navigationInstruction?.instructions))
   .filter(s=>typeof s==="string"&&s.trim()&&s.length<=500).slice(0,1024);
  if(!instructions.length)throw Error();
  return {provider:"google-routes",geometry,instructions,durationSeconds};
 }catch(_){reject("unavailable","ONLINE_ROUTE_UNAVAILABLE");}
}
async function courierContext(db,tx,request){
 const courier=await requireApprovedCourier(db,request,tx);await assertCurrentCourierAcceptance(db,courier.uid,tx);
 const data=request.data;
 if(!data||Object.keys(data).some(k=>!["orderId","assignmentId","origin"].includes(k))||
  !id(data.orderId)||!id(data.assignmentId)||!point(data.origin)||
  Object.keys(data.origin).some(k=>!["latitude","longitude"].includes(k)))reject("invalid-argument","ROUTE_REQUEST_INVALID");
 const order=(await tx.get(db.doc("orders/"+data.orderId))).data();
 const binding=(await tx.get(db.doc("courierPickupAssignments/"+data.assignmentId))).data();
 const grant=(await tx.get(db.doc("courierPickupGrants/"+data.orderId))).data();
 if(courier.profile.online!==true||!order||order.status!=="Saiu para Entrega"||
  order.courierUid!==courier.uid||order.courierAssignmentId!==data.assignmentId||
  !live(order.courierAssignmentExpiresAt)||!live(grant?.expiresAt)||
  grant?.courierUid!==courier.uid||grant?.assignmentId!==data.assignmentId||
  binding?.courierUid!==courier.uid||binding?.orderId!==data.orderId||binding?.status!=="pickedUp"||
  !point(order.deliveryAddress))reject("permission-denied","ROUTE_NOT_ASSIGNED");
 await assertCustomerAccountActive(db,order.customerUid,tx);
 return {uid:courier.uid,destination:{latitude:order.deliveryAddress.latitude,longitude:order.deliveryAddress.longitude},
  orderId:data.orderId,assignmentId:data.assignmentId};
}
async function onlineRoute(db,request,provider){
 const ctx=await db.runTransaction(async tx=>{
  const c=await courierContext(db,tx,request),ref=db.doc("couriers/"+c.uid+"/privateRuntime/onlineRouting"),old=(await tx.get(ref)).data();
  if(old?.nextAllowedAt instanceof Timestamp&&old.nextAllowedAt.toMillis()>Date.now())
   reject("resource-exhausted","ROUTE_RATE_LIMIT");
  // No GPS coordinates are stored, logged, or published to the customer.
  tx.set(ref,{nextAllowedAt:Timestamp.fromMillis(Date.now()+15000)});return c;
 });
 const route=await provider({origin:request.data.origin,destination:ctx.destination});
 const latest=await db.runTransaction(tx=>courierContext(db,tx,request));
 if(JSON.stringify(latest)!==JSON.stringify(ctx))reject("permission-denied","ROUTE_NOT_ASSIGNED");
 return {schemaVersion:1,...ctx,...route,generatedAtMs:Date.now(),expiresAtMs:Date.now()+60000};
}
async function customerEstimate(db,request){
 if(!request.auth?.uid||request.auth.token?.firebase?.sign_in_provider==="anonymous")
  reject("unauthenticated","CUSTOMER_SESSION_REQUIRED");
 if(!request.data||Object.keys(request.data).length!==1||!id(request.data.orderId))
  reject("invalid-argument","ORDER_ID_REQUIRED");
 return db.runTransaction(async tx=>{
  const order=(await tx.get(db.doc("orders/"+request.data.orderId))).data();
  if(!order||order.customerUid!==request.auth.uid)reject("permission-denied","ORDER_NOT_OWNED");
  await assertCustomerAccountActive(db,request.auth.uid,tx);
  if(!["Em Separa\u00e7\u00e3o","Saiu para Entrega"].includes(order.status))return {available:false};
  if(!/^[a-f0-9]{64}$/.test(order.deliveryQuoteId||""))return {available:false};
  const quote=(await tx.get(db.doc("deliveryQuotes/"+order.deliveryQuoteId))).data();
  if(quote?.uid!==request.auth.uid||quote?.orderId!==request.data.orderId||
    !Number.isFinite(quote.durationSeconds)||quote.durationSeconds<=0||quote.durationSeconds>86400||
    quote.provider!=="google-routes"||!point(quote.origin)||!point(order.deliveryAddress)||
    quote.destination?.latitude!==order.deliveryAddress.latitude||quote.destination?.longitude!==order.deliveryAddress.longitude)
   return {available:false};
  return {available:true,orderId:request.data.orderId,status:order.status,provider:"google-routes",
   durationSeconds:Math.ceil(quote.durationSeconds),departureAtMs:order.dispatchedAt instanceof Timestamp?order.dispatchedAt.toMillis():null,
   origin:{latitude:quote.origin.latitude,longitude:quote.origin.longitude},
   destination:{latitude:order.deliveryAddress.latitude,longitude:order.deliveryAddress.longitude},
   illustrativeOnly:true,liveGps:false};
 });
}
function createDeliveryJourneyFunctions(db,config={}){
 const options={region:"southamerica-east1",maxInstances:1};
 return {chamaeRotaOnlineMotoboy:onCall({...options,secrets:[key]},r=>onlineRoute(db,r,config.provider||
   (args=>googleRoute({...args,apiKey:key.value(),travelMode:mode.value()})))),
 chamaePrevisaoEntrega:onCall(options,r=>customerEstimate(db,r))};
}
module.exports={createDeliveryJourneyFunctions,onlineRoute,customerEstimate,googleRoute,decodePolyline};
