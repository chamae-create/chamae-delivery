const {onCall, HttpsError} = require("firebase-functions/v2/https");
const {defineSecret} = require("firebase-functions/params");
const {FieldValue} = require("firebase-admin/firestore");
const {customer} = require("./delivery-service");
const {verifiedCustomerToken} = require("./customer-identity");
const {generatePin, encryptPin, decryptPin} = require("./delivery-pin");
const pinKey = defineSecret("CHAMAE_DELIVERY_PIN_KEY");

async function ownPin(db, request, key, reset = false) {
  const uid = customer(request, true);
  if ((await db.collection("couriers").doc(uid).get()).exists) {
    throw new HttpsError("permission-denied", "Acesso restrito.");
  }
  if (reset && (!request.auth.token.auth_time ||
      Date.now() / 1000 - request.auth.token.auth_time > 300)) {
    throw new HttpsError("unauthenticated", "Confirme sua identidade novamente para redefinir o PIN.");
  }
  const secretRef = db.collection("customerDeliverySecrets").doc(uid);
  const audit = db.collection("deliveryPinAudit").doc();
  return db.runTransaction(async (tx) => {
    const old = await tx.get(secretRef);
    // Reset only with no unfinished orders. Query errors (including missing
    // index) fail closed. Existing order PINs must never silently change.
    if (reset) {
      const active = await tx.get(db.collection("orders").where("customerUid", "==", uid)
          .where("status", "in", ["Novo", "Aguardando pagamento", "Em Separação",
            "Aguardando Retirada", "Saiu para Entrega"]).limit(1));
      if (!active.empty) {
        throw new HttpsError("failed-precondition", "Redefina após concluir seus pedidos em andamento.");
      }
    }
    if (old.exists && !reset) return {pin: decryptPin(old.data().encrypted, uid, key)};
    let pin = generatePin();
    if (old.exists && reset) {
      const previous = decryptPin(old.data().encrypted, uid, key);
      while (pin === previous) pin = generatePin();
    }
    const revision = old.exists ? old.data().revision + 1 : 1;
    tx.set(secretRef, {encrypted: encryptPin(pin, uid, key), revision,
      updatedAt: FieldValue.serverTimestamp()});
    tx.set(audit, {uid, operation: reset ? "reset" : "created", revision,
      at: FieldValue.serverTimestamp()});
    return {pin};
  });
}
function createCustomerSecurity(db) {
  const options = {region: "southamerica-east1", secrets: [pinKey]};
  return {
    chamaeObterPinEntrega: onCall(options, (r) => ownPin(db, r, pinKey.value())),
    chamaeRedefinirPinEntrega: onCall(options, (r) => ownPin(db, r, pinKey.value(), true)),
    chamaeEstadoVerificacao: onCall({region: options.region}, async (r) => {
      if (!r.auth) throw new HttpsError("unauthenticated", "Conecte-se novamente.");
      return {verified: verifiedCustomerToken(r.auth.token),
        providers: ["google.com", "apple.com"], configured: true};
    }),
  };
}
module.exports = {ownPin, createCustomerSecurity};
