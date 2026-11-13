"use strict";
const {onCall, HttpsError} = require("firebase-functions/v2/https");
const {verifiedCustomerToken} = require("./customer-identity");
const {runtimeTrust} = require("./age-eligibility");
const statuses = new Set(["notStarted","required","inProgress","approved","declined","expired","appealPending","unavailable"]);
class AgeVerificationProvider {
  get id() {throw Error("PROVIDER_NOT_IMPLEMENTED");}
  async begin() {throw Error("PROVIDER_NOT_IMPLEMENTED");}
  async resolveVerified() {throw Error("PROVIDER_NOT_IMPLEMENTED");}
}
class UnavailableAgeVerificationProvider extends AgeVerificationProvider {
  get id() {return "unavailable";}
  async begin() {throw new HttpsError("failed-precondition","AGE_PROVIDER_UNAVAILABLE",{reason:"AGE_PROVIDER_UNAVAILABLE"});}
}
class AgeVerificationService {
  constructor(provider = new UnavailableAgeVerificationProvider()) {this.provider = provider;}
  async begin(uid, requestId) {
    if (typeof uid !== "string" || !uid || !/^[A-Za-z0-9_-]{16,100}$/.test(requestId || "")) throw new HttpsError("invalid-argument","AGE_REQUEST_INVALID");
    // No retries. No raw identity parameters are forwarded by this layer.
    return this.provider.begin({uid, requestId});
  }
}
function customer(request) {
  if (!request.auth || !verifiedCustomerToken(request.auth.token) || (!Array.isArray(request.auth.token.roles || []) || (request.auth.token.roles || []).length || request.auth.token.superadmin === true)) throw new HttpsError("permission-denied","CUSTOMER_REQUIRED");
  return request.auth.uid;
}
function publicStatus(record, now = Date.now()) {
  let status = statuses.has(record?.status) ? record.status : "notStarted";
  if (status === "approved" && (!runtimeTrust.enabled || !runtimeTrust.providers.includes(record.provider))) status = "unavailable";
  if (status === "approved" && !(record.expiresAtMs > now)) status = "expired";
  return {status, ageVerified: status === "approved" && record.ageVerified === true,
    identityVerified: status === "approved" && record.identityVerified === true};
}
function createAgeVerificationFunctions(db) {
  const service = new AgeVerificationService();
  async function owner(request) {
    const uid = customer(request);
    await require("./customer-account-state").assertCustomerAccountActive(db, uid);
    if ((await db.doc("couriers/" + uid).get()).exists) throw new HttpsError("permission-denied","CUSTOMER_REQUIRED");
    return uid;
  }
  return {
    chamaeIniciarVerificacaoEtaria: onCall({region:"southamerica-east1",maxInstances:1},async request => {
      const uid = await owner(request);
      if (!request.data || Object.keys(request.data).some(k=>k!=="requestId")) throw new HttpsError("invalid-argument","AGE_REQUEST_INVALID");
      return service.begin(uid, request.data.requestId);
    }),
    chamaeConsultarVerificacaoEtaria: onCall({region:"southamerica-east1",maxInstances:1},async request => {
      const uid = await owner(request);
      return publicStatus((await db.doc("customerAgeVerifications/" + uid).get()).data());
    })
  };
}
module.exports = {AgeVerificationProvider, UnavailableAgeVerificationProvider, AgeVerificationService, publicStatus, createAgeVerificationFunctions};
