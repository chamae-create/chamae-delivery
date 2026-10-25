const {HttpsError} = require("firebase-functions/v2/https");

// A blocked request has not erased anything and leaves the account usable.
async function assertCustomerAccountActive(db, uid, tx) {
  const ref = db.collection("customerAccountClosures").doc(uid);
  const doc = await (tx ? tx.get(ref) : ref.get());
  if (doc.exists && doc.data().status !== "blocked") {
    throw new HttpsError("failed-precondition",
        "A exclusão desta conta está em andamento. Confira o status no perfil.",
        {reason: "ACCOUNT_CLOSING"});
  }
}
module.exports = {assertCustomerAccountActive};
