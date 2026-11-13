"use strict";
const {restrictedProduct,requiredAge,assertDeliveryAge}=require("./age-eligibility");
const {HttpsError}=require("firebase-functions/v2/https");
async function deliveryRequirement(tx,db,order) {
  const items=order.itemsList;
  if (!Array.isArray(items)||!items.length||items.length>100) throw new HttpsError("failed-precondition","DELIVERY_CATALOG_REQUIRED");
  let restricted=false;
  for(const item of items){
    if(typeof item.id!=="string"||!item.id||item.id.includes("/")) throw new HttpsError("failed-precondition","DELIVERY_CATALOG_REQUIRED");
    const product=(await tx.get(db.doc("products/"+item.id))).data();
    if(!product)throw new HttpsError("failed-precondition","DELIVERY_CATALOG_REQUIRED");
    restricted ||= restrictedProduct(product);
  }
  if(!restricted)return {required:false};
  const policy=(await tx.get(db.doc("customerPolicies/current"))).data();
  require("./customer-onboarding").validPolicy(policy);
  const country=order.deliveryAddress?.countryCode;
  return {required:true,minimumAge:requiredAge(country,policy.minimumAgeByCountry?.[country])};
}
async function assertOrderRecipient(tx,db,order,{orderId,assignmentId,courierUid}) {
  const requirement=await deliveryRequirement(tx,db,order);
  if(requirement.required)assertDeliveryAge((await tx.get(db.doc("deliveryAgeChecks/"+orderId))).data(),
    {orderId,assignmentId,courierUid,minimum:requirement.minimumAge});
  return requirement;
}
module.exports={deliveryRequirement,assertOrderRecipient};
