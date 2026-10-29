const {HttpsError} = require("firebase-functions/v2/https");
const {assertCustomerAccountActive} = require("./customer-account-state");

// Shared by callables, assignment and projection. Missing/unknown status denies.
function isApprovedCourierProfile(profile) {
  return !!profile && profile.role === "courier" && profile.approvalStatus === "approved" &&
    profile.administrativeState === "active" && profile.enabled !== false &&
    profile.isActive !== false && profile.active !== false && !profile.accountClosureStatus;
}

function requireCourierIdentity(request) {
  const auth = request.auth;
  if (!auth || typeof auth.uid !== "string" || !auth.uid ||
      auth.uid.includes("/") || auth.uid === "." || auth.uid === ".." ||
      auth.uid.length > 128 ||
      (auth.token && auth.token.firebase &&
       auth.token.firebase.sign_in_provider === "anonymous")) {
    throw new HttpsError("unauthenticated", "Entre para continuar.");
  }
  return auth.uid;
}

async function requireApprovedCourier(db, request, transaction) {
  const uid = requireCourierIdentity(request);
  await assertCustomerAccountActive(db, uid, transaction);
  const ref = db.collection("couriers").doc(uid);
  const snapshot = await (transaction ? transaction.get(ref) : ref.get());
  if (!snapshot.exists || !isApprovedCourierProfile(snapshot.data())) {
    throw new HttpsError("permission-denied",
        "Seu acesso operacional não está liberado.");
  }
  return {uid, ref, profile: snapshot.data()};
}

function requireCourierAdministrator(request) {
  const uid = requireCourierIdentity(request);
  const roles = request.auth.token && request.auth.token.roles;
  if (!Array.isArray(roles) || !roles.includes("superadmin")) {
    throw new HttpsError("permission-denied", "Ação administrativa não autorizada.");
  }
  return uid;
}

module.exports = {isApprovedCourierProfile, requireCourierIdentity,
  requireApprovedCourier, requireCourierAdministrator};
