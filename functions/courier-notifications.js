const {isApprovedCourierProfile, requireApprovedCourier} = require("./courier-authorization");
const {FieldValue} = require("firebase-admin/firestore");
const {getMessaging} = require("firebase-admin/messaging");
const {onCall, HttpsError} = require("firebase-functions/v2/https");
const {onDocumentCreated} = require("firebase-functions/v2/firestore");
// Opaque assignment identifiers only. Never customer/payment/address data.
function assignmentNotice(orderId, assignmentId) {
  return {kind: "courier_assignment", version: "2", orderId, assignmentId,
    title: "Nova entrega Chamaê", body: "Você recebeu uma nova entrega da Pit Stop V8."};
}
function collectCourierTokens(profile) {
  const seen = new Set();
  const pushValid = (candidate) => {
    if (typeof candidate !== "string") return;
    const trimmed = candidate.trim();
    if (trimmed.length >= 32 && trimmed.length <= 4096) seen.add(trimmed);
  };
  if (profile && typeof profile === "object") {
    if (Array.isArray(profile.fcmTokens)) {
      for (const t of profile.fcmTokens) pushValid(t);
    }
    pushValid(profile.fcmToken);
    pushValid(profile.pushToken);
  }
  return Array.from(seen);
}
async function registerCourierPushToken(db, request) {
  const courier = await requireApprovedCourier(db, request);
  const data = request.data || {};
  const token = typeof data.token === "string" ? data.token.trim() : "";
  if (token.length < 32 || token.length > 4096 || /\s/.test(token)) {
    throw new HttpsError("invalid-argument", "Token de notificação inválido.");
  }
  const platform = typeof data.platform === "string" && ["android", "ios"].includes(data.platform.trim()) ?
    data.platform.trim() : null;
  await db.collection("couriers").doc(courier.uid).set({
    fcmTokens: FieldValue.arrayUnion(token),
    fcmToken: token,
    ...(platform ? {pushPlatform: platform} : {}),
    pushTokenUpdatedAt: FieldValue.serverTimestamp(),
    updatedAt: FieldValue.serverTimestamp(),
  }, {merge: true});
  return {registered: true};
}
function createFcmCourierTransport(db, messaging = null) {
  return {
    async send(uid, payload, assignmentId) {
      const snap = await db.collection("couriers").doc(uid).get();
      const profile = snap.exists ? snap.data() : null;
      const tokens = collectCourierTokens(profile);
      if (tokens.length === 0) {
        console.warn("Motoboy sem token FCM registrado.", {uid, assignmentId});
        return {sent: 0, failed: 0, reason: "no_tokens"};
      }
      const sender = messaging || getMessaging();
      const response = await sender.sendEachForMulticast({
        tokens,
        notification: {
          title: payload.title,
          body: payload.body,
        },
        data: {
          kind: String(payload.kind || "courier_assignment"),
          version: String(payload.version || "2"),
          orderId: String(payload.orderId || ""),
          assignmentId: String(payload.assignmentId || assignmentId || ""),
        },
        android: {
          priority: "high",
          notification: {
            channelId: "chamae_assignments_v2",
            sound: "default",
          },
        },
        apns: {
          headers: {"apns-priority": "10"},
          payload: {aps: {sound: "default", contentAvailable: true}},
        },
      });
      const invalidTokens = [];
      if (Array.isArray(response.responses)) {
        response.responses.forEach((item, index) => {
          const code = item && item.error && item.error.code;
          if (!item.success && (
            code === "messaging/registration-token-not-registered" ||
            code === "messaging/invalid-registration-token"
          )) {
            invalidTokens.push(tokens[index]);
          }
        });
      }
      if (invalidTokens.length > 0) {
        const invalidSet = new Set(invalidTokens);
        const cleanup = {fcmTokens: FieldValue.arrayRemove(...invalidTokens)};
        if (profile && invalidSet.has(profile.fcmToken)) {
          cleanup.fcmToken = FieldValue.delete();
        }
        await db.collection("couriers").doc(uid).set(cleanup, {merge: true});
      }
      return {sent: response.successCount || 0, failed: response.failureCount || 0};
    },
  };
}
function createCourierNotificationFunctions(db) {
  return {
    chamaeRegistrarTokenPushMotoboy: onCall(
        {region: "southamerica-east1", maxInstances: 10},
        (request) => registerCourierPushToken(db, request)),
    chamaeEnviarNotificacaoMotoboy: onDocumentCreated(
        {
          document: "courierNotificationOutbox/{assignmentId}",
          region: "southamerica-east1",
          retry: true,
          maxInstances: 10,
        },
        async (event) => {
          const assignmentId = event.params && event.params.assignmentId;
          if (!assignmentId) return false;
          return deliverNotice(db, assignmentId, createFcmCourierTransport(db));
        }),
  };
}
function enqueueNotice(tx, db, orderId, assignmentId, uid, profile) {
  if (!uid || !isApprovedCourierProfile(profile) || profile.online !== true) return;
  tx.create(db.doc(`courierNotificationOutbox/${assignmentId}`), {courierUid: uid,
    ...assignmentNotice(orderId, assignmentId), createdAt: FieldValue.serverTimestamp()});
}
// FCM transport is injected. At-least-once delivery requires receiver dedup by assignmentId.
async function deliverNotice(db, assignmentId, transport) {
  const ref = db.doc(`courierNotificationOutbox/${assignmentId}`);
  const notice = (await ref.get()).data();
  if (!notice || notice.sentAt || notice.discardedAt) return false;
  const profile = (await db.doc(`couriers/${notice.courierUid}`).get()).data();
  const order = (await db.doc(`orders/${notice.orderId}`).get()).data();
  if (!isApprovedCourierProfile(profile) || profile.online !== true || !order ||
      order.courierUid !== notice.courierUid || order.courierAssignmentId !== notice.assignmentId ||
      !order.courierAssignmentExpiresAt || order.courierAssignmentExpiresAt.toMillis() <= Date.now() ||
      notice.kind !== "courier_assignment" && (order.courierPickedUpAt || !order.expectedPickupBy ||
        order.expectedPickupBy.toMillis() !== notice.deadlineMs) ||
      ["Concluído", "Cancelado"].includes(order.status)) {
    await ref.update({discardedAt: FieldValue.serverTimestamp()}); return false;
  }
  if (!transport) throw new Error("FCM_NOT_CONFIGURED");
  await transport.send(notice.courierUid, notice.kind === "courier_assignment" ? assignmentNotice(notice.orderId,
      notice.assignmentId) :
    {kind: notice.kind, version: "2", orderId: notice.orderId, assignmentId: notice.assignmentId,
      title: notice.title, body: notice.body}, assignmentId);
  await ref.update({sentAt: FieldValue.serverTimestamp()});
  return true;
}
module.exports = {assignmentNotice, enqueueNotice, deliverNotice, collectCourierTokens,
  registerCourierPushToken, createFcmCourierTransport, createCourierNotificationFunctions};
