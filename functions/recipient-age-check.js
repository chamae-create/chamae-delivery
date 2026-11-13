"use strict";
const {createHash} = require("node:crypto");
const {onCall, HttpsError} = require("firebase-functions/v2/https");
const {Timestamp, FieldValue} = require("firebase-admin/firestore");
const {requireApprovedCourier} = require("./courier-authorization");
const {assertCurrentCourierAcceptance} = require("./courier-policy");

const fail = reason => {throw new HttpsError("failed-precondition",reason,{reason});};
async function checkRecipient(db, request) {
  const d = request.data;
  if (!d || Object.keys(d).some(k=>!["orderId","assignmentId","requestId","identityMatches","ageEligible","action"].includes(k)) ||
      !["orderId","assignmentId","requestId"].every(k=>typeof d[k]==="string"&&/^[A-Za-z0-9_-]{1,128}$/.test(d[k])) ||
      d.requestId.length<16 || !["inspect","confirm"].includes(d.action) || d.action==="confirm" && (typeof d.identityMatches!=="boolean" || typeof d.ageEligible!=="boolean")) fail("RECIPIENT_REQUEST_INVALID");
  return db.runTransaction(async tx=>{
    const courier = await requireApprovedCourier(db,request,tx);
    await assertCurrentCourierAcceptance(db,courier.uid,tx);
    const order = (await tx.get(db.doc("orders/"+d.orderId))).data();
    const binding = (await tx.get(db.doc("courierPickupAssignments/"+d.assignmentId))).data();
    const now=Date.now();
    if (!order || courier.profile.online!==true || order.status!=="Saiu para Entrega" ||
        order.courierDeliveryPhase!=="arrived" || order.courierUid!==courier.uid ||
        order.courierAssignmentId!==d.assignmentId || !(order.courierAssignmentExpiresAt instanceof Timestamp) ||
        order.courierAssignmentExpiresAt.toMillis()<=now || binding?.orderId!==d.orderId ||
        binding?.courierUid!==courier.uid || binding?.status!=="pickedUp") fail("RECIPIENT_ASSIGNMENT_INVALID");
    const profile = (await tx.get(db.doc("customerProfiles/"+order.customerUid))).data();
    const policy = (await tx.get(db.doc("customerPolicies/current"))).data();
    const {validPolicy,profileCurrent} = require("./customer-onboarding");
    validPolicy(policy);
    if (!profileCurrent(profile,policy)) fail("RECIPIENT_POLICY_CHANGED");
    const requirement=await require("./age-delivery-policy").deliveryRequirement(tx,db,order);
    if(!requirement.required)return {status:"notRequired"};
    const minimum=requirement.minimumAge;
    if(d.action==="inspect")return {status:"required",minimumAge:minimum};
    const key=createHash("sha256").update(JSON.stringify([courier.uid,d.requestId])).digest("hex");
    const auditRef=db.doc("deliveryAgeAudit/"+key),ref=db.doc("deliveryAgeChecks/"+d.orderId);
    const old=(await tx.get(auditRef)).data(),previous=(await tx.get(ref)).data();
    const fingerprint=createHash("sha256").update(JSON.stringify([d.orderId,d.assignmentId,d.identityMatches,d.ageEligible])).digest("hex");
    if(old){if(old.fingerprint!==fingerprint)fail("RECIPIENT_REQUEST_REUSED");return old.result;}
    if (previous?.status==="declined" && previous.assignmentId===d.assignmentId) fail("RECIPIENT_REVIEW_REQUIRED");
    if ((previous?.attemptCount || 0)>=5) fail("RECIPIENT_ATTEMPT_LIMIT");
    const status=d.identityMatches&&d.ageEligible?"approved":"declined";
    const result={status,minimumAge:minimum};
    tx.set(ref,{orderId:d.orderId,assignmentId:d.assignmentId,courierUid:courier.uid,
      customerUid:order.customerUid,attemptCount:(previous?.attemptCount || 0)+1,minimumAge:minimum,status,identityMatches:d.identityMatches,
      expiresAtMs:Math.min(order.courierAssignmentExpiresAt.toMillis(),now+5*60*1000),updatedAt:FieldValue.serverTimestamp()});
    tx.create(auditRef,{orderId:d.orderId,uid:order.customerUid,fingerprint,result,at:FieldValue.serverTimestamp()});
    return result;
  });
}
function createRecipientAgeCheck(db){return {chamaeConferirDestinatarioMaioridade:onCall({region:"southamerica-east1",maxInstances:2},r=>checkRecipient(db,r))};}
module.exports={checkRecipient,createRecipientAgeCheck};
