"use strict";
const {createHash}=require("node:crypto");
const {isDeepStrictEqual}=require("node:util");
const {Timestamp,FieldValue}=require("firebase-admin/firestore");
const {HttpsError}=require("firebase-functions/v2/https");
const {authorize,readyForDispatch}=require("./courier-assignment");
const {isApprovedCourierProfile}=require("./courier-authorization");
const {assertCustomerAccountActive}=require("./customer-account-state");
const {validateQuote}=require("./delivery-pricing");
const {verifiedQuoteCountry,assertPaymentCountry}=require("./order-acceptance");
const {matchAssignment,validatePackage}=require("./courier-pickup");
const {cents}=require("./order-operations");
const {buildCourierDelivery}=require("./courier-deliveries");
const {createStoredRoutePackageProvider}=require("./courier-route-package-provider");
const reject=(reason)=>{throw new HttpsError("failed-precondition",reason,{reason});};
const id=value=>typeof value==="string"&&/^[A-Za-z0-9_-]{1,128}$/.test(value);
// No conversion, split decomposition or change formula is duplicated here.
// Complex collections stay blocked until their approved operational DTO exists.
function simplePayment(order,financial){
 const paid=order.paymentStatus==="Pago";
 if(order.splitPayment===true||order.paymentParts?.length||
   !paid&&((order.cashCurrency||"BRL")!=="BRL"||order.cashTendered!=null))
   reject("BORDER_PAYMENT_PROJECTION_REQUIRED");
 const method=order.paymentMethod==="PIX"?"pix":
   order.paymentMethod.startsWith("Maquininha")?"card":"cash";
 return {state:paid?"paid":"collect",method,amountMinor:paid?0:cents(financial.totalBRL),currency:"BRL"};
}
function createRoutePackageProducer(db,{producerId,routeProvider,checkFinancial,checkDeliveryPayment}){
 if(typeof producerId!=="string"||!/^[A-Za-z0-9_-]{1,80}$/.test(producerId)||
   ![routeProvider,checkFinancial,checkDeliveryPayment].every(v=>typeof v==="function"))
   throw new TypeError("ROUTE_PRODUCER_PORTS_REQUIRED");
 const reader=createStoredRoutePackageProvider(db,{producerId,checkFinancial,checkDeliveryPayment});
 async function snapshot(tx,request,orderId){
  authorize(request);
  if((await tx.get(db.doc("couriers/"+request.auth.uid))).exists)reject("ADMINISTRATIVE_IDENTITY_REQUIRED");
  const order=(await tx.get(db.doc("orders/"+orderId))).data();
  if(!order||!id(order.customerUid)||!id(order.courierUid)||!id(order.courierAssignmentId)||
    !matchAssignment(order,order.courierUid,order.courierAssignmentId,Date.now())||
    order.status!=="Em Separa\u00e7\u00e3o"||!(order.acceptedAt instanceof Timestamp)||!readyForDispatch(order))
    reject("PACKAGE_ASSIGNMENT_NOT_READY");
  await assertCustomerAccountActive(db,order.customerUid,tx);
  const profile=(await tx.get(db.doc("couriers/"+order.courierUid))).data();
  const binding=(await tx.get(db.doc("courierPickupAssignments/"+order.courierAssignmentId))).data();
  if(!isApprovedCourierProfile(profile)||!binding||binding.status!=="active"||
    binding.orderId!==orderId||binding.courierUid!==order.courierUid)reject("PACKAGE_ASSIGNMENT_NOT_READY");
  if(!/^[a-f0-9]{64}$/.test(order.deliveryQuoteId||""))reject("PACKAGE_QUOTE_REQUIRED");
  const financial=(await tx.get(db.doc("orderFinancials/"+orderId))).data();
  const quote=(await tx.get(db.doc("deliveryQuotes/"+order.deliveryQuoteId))).data();
  if(!financial||!Number.isSafeInteger(financial.version)||financial.version<1||quote?.orderId!==orderId)
    reject("PACKAGE_FINANCIAL_REQUIRED");
  validateQuote(quote,order,orderId);
  const country=verifiedQuoteCountry(quote,order.deliveryAddress);
  assertPaymentCountry(order,country);
  checkFinancial(order,financial);checkDeliveryPayment(order,financial);
  const payment=simplePayment(order,financial);
  if(!/^V8-(?:[0-9]{4}|[1-9][0-9]{4,})$/.test(order.displayOrderId||"")||order.displayOrderId==="V8-0000")
    reject("OPERATIONAL_ORDER_ID_REQUIRED");
  const address=order.deliveryAddress.addressText??order.address;
  if(typeof address!=="string"||!address.trim()||address.length>1000)reject("DELIVERY_ADDRESS_REQUIRED");
  const operational=buildCourierDelivery(orderId,order,{},Timestamp.now());
  if(!operational)reject("OPERATIONAL_INSTRUCTIONS_INVALID");
  const instructions={reference:operational.reference||"",note:operational.complement||""};
  return {order,profile,binding,financial,quote,country,payment,address,instructions};
 }
 return async function preparePackage(request){
  authorize(request); // Reject before reads or external work; accepts orderId only.
  if(!request.data||Object.keys(request.data).length!==1||!id(request.data.orderId))
    throw new HttpsError("invalid-argument","PACKAGE_ORDER_ID_REQUIRED");
  const orderId=request.data.orderId;
  const initial=await db.runTransaction(async tx=>{
   const s=await snapshot(tx,request,orderId);
   const ref=db.doc("customerDeliverySecrets/"+s.order.customerUid+"/courierRoutePackages/"+s.order.courierAssignmentId);
   const existing=await tx.get(ref);
   const ticket={orderId,assignmentId:s.order.courierAssignmentId,courierUid:s.order.courierUid,
    packageVersion:1,expiresAtMs:s.order.courierAssignmentExpiresAt.toMillis()};
   if(existing.exists){
    const bytes=await reader(ticket,s.order,tx);
    return {replayed:true,assignmentId:ticket.assignmentId,courierUid:ticket.courierUid,
     expiresAtMs:JSON.parse(bytes.toString("utf8")).assignment.expiresAtMs};
   }
   return {s,ticket,ref};
  });
  if(initial.replayed)return initial;
  const {s,ticket,ref}=initial;
  // Server-owned port sees no customer name, phone, notes, items, PIN or payment.
  // Deliberately outside Firestore retries: maps/network work is not a tx side effect.
  const route=await routeProvider({orderId,assignmentId:ticket.assignmentId,courierUid:ticket.courierUid,
   customerUid:s.order.customerUid,origin:{latitude:s.quote.origin.latitude,longitude:s.quote.origin.longitude},
   destination:{latitude:s.order.deliveryAddress.latitude,longitude:s.order.deliveryAddress.longitude},
   assignmentExpiresAtMs:ticket.expiresAtMs});
  if(!route||!Number.isSafeInteger(route.expiresAtMs)||route.expiresAtMs<=Date.now()||
    route.expiresAtMs>ticket.expiresAtMs||route.expiresAtMs>Date.now()+4*60*60*1000)reject("ROUTE_VALIDITY_INVALID");
  const expiresAtMs=route.expiresAtMs;
  const payload={schemaVersion:2,contingency:"Procure a Pit Stop V8 na retirada.",assignment:{...ticket,expiresAtMs},delivery:{
   orderId,courierUid:ticket.courierUid,number:s.order.displayOrderId,region:s.country,country:s.country.toLowerCase(),
   address:s.address,coordinates:{latitude:s.order.deliveryAddress.latitude,longitude:s.order.deliveryAddress.longitude},
   items:[],phase:"accepted",version:1,expiresAtMs,payment:s.payment,...s.instructions,
   pinVerifier:{orderId,verificationVersion:1,verificationMaterial:"server-only:v1",maxAttempts:5,expiresAtMs}},
   map:route.map};
  const bytes=Buffer.from(JSON.stringify(payload));
  // Base64 plus metadata fits the Firestore 1 MiB document cap with margin.
  if(bytes.length>512*1024)reject("ROUTE_PACKAGE_TOO_LARGE");
  validatePackage(bytes,ticket);
  const digest=createHash("sha256").update(bytes).digest("hex");
  return db.runTransaction(async tx=>{
   const current=await snapshot(tx,request,orderId);
   if(!isDeepStrictEqual(current,s))reject("PACKAGE_SOURCE_CHANGED");
   const existing=await tx.get(ref);
   if(existing.exists){
    const saved=await reader(ticket,current.order,tx);
    return {replayed:true,assignmentId:ticket.assignmentId,courierUid:ticket.courierUid,
     expiresAtMs:JSON.parse(saved.toString("utf8")).assignment.expiresAtMs};
   }
   if(expiresAtMs<=Date.now())reject("ROUTE_VALIDITY_INVALID");
   tx.create(ref,{status:"ready",producerId,orderId,assignmentId:ticket.assignmentId,courierUid:ticket.courierUid,
    packageVersion:1,expiresAt:Timestamp.fromMillis(expiresAtMs),payloadBase64:bytes.toString("base64"),
    payloadSha256:digest,financialVersion:s.financial.version,totalBRL:s.financial.totalBRL,
    paymentMethod:s.order.paymentMethod,paymentStatus:s.order.paymentStatus,paymentParts:s.order.paymentParts??null,
    cashCurrency:s.order.cashCurrency??null,cashTendered:s.order.cashTendered??null,paymentProjection:s.payment,
    createdAt:FieldValue.serverTimestamp()});
   tx.create(db.collection("courierPickupAudit").doc(),{code:"route_package_produced",actorUid:request.auth.uid,
    orderId,assignmentId:ticket.assignmentId,producerId,packageDigest:digest,at:FieldValue.serverTimestamp()});
   return {replayed:false,assignmentId:ticket.assignmentId,courierUid:ticket.courierUid,expiresAtMs};
  });
 };
}
module.exports={createRoutePackageProducer};
