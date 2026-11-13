"use strict";
const {HttpsError} = require("firebase-functions/v2/https");
function assertStagingQuoteCaller(request, configuredUids) {
  if (!request.auth?.uid) throw new HttpsError("unauthenticated", "Autenticacao necessaria.");
  const ids = typeof configuredUids === "string" ? configuredUids.split(",").map(s => s.trim()).filter(Boolean) : [];
  if (!ids.length || ids.length > 20 || ids.some(id => !/^[A-Za-z0-9_-]{1,128}$/.test(id))) {
    throw new HttpsError("failed-precondition", "STAGING_QUOTE_UIDS_NOT_CONFIGURED");
  }
  if (!ids.includes(request.auth.uid)) throw new HttpsError("permission-denied", "STAGING_QUOTE_CALLER_NOT_APPROVED");
}
// Atomic across instances. Every new attempt consumes UID, global-minute and UTC-day admission.
async function admitDeliveryQuote(db, uid, {now = Date.now(), limit = 10, windowMs = 60000, globalLimit = 20, dailyLimit = 100} = {}) {
  if (!uid || ![limit,globalLimit,dailyLimit].every(v => Number.isSafeInteger(v) && v > 0) ||
      !Number.isSafeInteger(now) || now < 0 || !Number.isSafeInteger(windowMs) || windowMs < 1000) {
    throw new HttpsError("failed-precondition", "QUOTE_LIMIT_CONFIGURATION");
  }
  const specs = [
    {ref: db.collection("deliveryQuoteLimits").doc(uid), duration: windowMs, limit},
    {ref: db.collection("deliveryQuoteLimitGlobals").doc("minute"), duration: 60000, limit: globalLimit},
    {ref: db.collection("deliveryQuoteLimitGlobals").doc("daily"), duration: 86400000, limit: dailyLimit},
  ];
  await db.runTransaction(async tx => {
    const snapshots = await Promise.all(specs.map(s => tx.get(s.ref)));
    const writes = specs.map((s,i) => {
      const window = Math.floor(now / s.duration), old = snapshots[i].data();
      if (old && (!Number.isSafeInteger(old.window) || !Number.isSafeInteger(old.count) || old.count < 0 || old.window > window)) {
        throw new HttpsError("resource-exhausted", "QUOTE_LIMIT_STATE");
      }
      const count = old?.window === window ? old.count : 0;
      if (count >= s.limit) throw new HttpsError("resource-exhausted", "Aguarde para cotar novamente.",
        {reason: "DELIVERY_QUOTE_RATE_LIMIT", retryAfterMs: (window + 1) * s.duration - now});
      return {ref: s.ref, value: {window, count: count + 1}};
    });
    for (const w of writes) tx.set(w.ref, w.value);
  });
}
module.exports = {admitDeliveryQuote, assertStagingQuoteCaller};
