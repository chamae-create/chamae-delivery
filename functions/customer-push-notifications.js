const {onCall, HttpsError} = require("firebase-functions/v2/https");
const {onDocumentUpdated} = require("firebase-functions/v2/firestore");
const {FieldValue} = require("firebase-admin/firestore");
const {getMessaging} = require("firebase-admin/messaging");

const ALLOWED_PLATFORMS = new Set(["ios", "android", "web"]);

/** Normalizes order status for comparison across variants.
 * @param {*} raw Status string.
 * @return {string} Normalized status key.
 */
function normalizeStatusKey(raw) {
  if (typeof raw !== "string") return "";
  return raw
      .trim()
      .toLowerCase()
      .normalize("NFD")
      .replace(/[\u0300-\u036f]/g, "");
}

/** Builds notification title/body for supported order status transitions.
 * @param {string} status New status label.
 * @param {string} orderId Document ID.
 * @param {*} friendlyId Optional human-readable code (e.g. #CH-...).
 * @return {?{key: string, title: string, body: string}} Notification payload or null.
 */
function buildOrderStatusNotification(status, orderId, friendlyId) {
  const key = normalizeStatusKey(status);
  const code = typeof friendlyId === "string" && friendlyId.trim() ?
    friendlyId.trim() :
    `#${String(orderId || "").slice(0, 8).toUpperCase()}`;

  if (key === "em separacao") {
    return {
      key: "separacao",
      title: `Pedido ${code} em separação`,
      body: "Sua solicitação foi aceita e já está sendo preparada na Pit Stop V8.",
    };
  }
  if (key === "saiu para entrega") {
    return {
      key: "saiu_para_entrega",
      title: `Pedido ${code} saiu para entrega`,
      body: "O entregador já está a caminho do seu endereço.",
    };
  }
  if (key === "concluido" || key === "entregue") {
    return {
      key: "entregue",
      title: `Pedido ${code} entregue`,
      body: "Entrega confirmada. Obrigado por pedir no Chamaê Delivery!",
    };
  }
  if (key === "cancelado" || key === "cancelada") {
    return {
      key: "cancelado",
      title: `Pedido ${code} cancelado`,
      body: "Seu pedido foi cancelado. Abra o aplicativo para conferir os detalhes.",
    };
  }
  return null;
}

/** Extracts valid unique FCM tokens from user and profile documents.
 * @param {Array<Object|undefined>} docs Snapshots or plain objects.
 * @return {string[]} Unique FCM registration tokens.
 */
function collectCustomerTokens(docs) {
  const seen = new Set();
  for (const doc of docs) {
    if (!doc || typeof doc !== "object") continue;
    if (typeof doc.fcmToken === "string" && doc.fcmToken.trim()) {
      seen.add(doc.fcmToken.trim());
    }
    if (Array.isArray(doc.fcmTokens)) {
      for (const token of doc.fcmTokens) {
        if (typeof token === "string" && token.trim()) {
          seen.add(token.trim());
        }
      }
    }
  }
  return Array.from(seen);
}

/** Validates caller auth and registers/updates a customer's FCM token.
 * @param {Object} db Firestore Admin SDK.
 * @param {Object} request CallableRequest.
 * @return {Promise<{registered: boolean, platform: string}>} Status.
 */
async function registerCustomerPushToken(db, request) {
  const auth = request.auth;
  const firebaseInfo = auth && auth.token && auth.token.firebase;
  if (!auth || typeof auth.uid !== "string" || !auth.uid ||
      (firebaseInfo && firebaseInfo.sign_in_provider === "anonymous")) {
    throw new HttpsError("unauthenticated", "Entre para ativar notificações.");
  }
  const data = request.data || {};
  const token = typeof data.token === "string" ? data.token.trim() : "";
  const platform = typeof data.platform === "string" ?
    data.platform.trim().toLowerCase() : "";

  if (token.length < 20 || token.length > 4096) {
    throw new HttpsError("invalid-argument", "Token de notificação inválido.");
  }
  if (!ALLOWED_PLATFORMS.has(platform)) {
    throw new HttpsError("invalid-argument", "Plataforma inválida.");
  }

  const uid = auth.uid;
  const payload = {
    fcmToken: token,
    fcmTokens: FieldValue.arrayUnion(token),
    fcmPlatform: platform,
    fcmTokenUpdatedAt: FieldValue.serverTimestamp(),
  };

  await Promise.all([
    db.collection("users").doc(uid).set(payload, {merge: true}),
    db.collection("customerProfiles").doc(uid).set(payload, {merge: true}),
  ]);

  return {registered: true, platform};
}

/** Sends FCM push when an order status moves to a tracked milestone.
 * @param {Object} db Firestore Admin SDK.
 * @param {Object} event DocumentUpdated event.
 * @param {?Object} messaging Optional messaging client for testing.
 * @return {Promise<{sent: number, failed: number, reason?: string}>} Result.
 */
async function notifyOrderStatusChange(db, event, messaging = null) {
  const change = event && event.data;
  if (!change || !change.after || !change.after.exists) {
    return {sent: 0, failed: 0, reason: "no_snapshot"};
  }
  const before = change.before && change.before.exists ?
    (change.before.data() || {}) : {};
  const after = change.after.data() || {};

  const prevStatus = normalizeStatusKey(before.status);
  const nextStatusRaw = typeof after.status === "string" ? after.status.trim() : "";
  const nextStatus = normalizeStatusKey(nextStatusRaw);
  if (!nextStatus || prevStatus === nextStatus) {
    return {sent: 0, failed: 0, reason: "status_unchanged"};
  }

  const orderId = (event.params && event.params.orderId) || change.after.id || "";
  const messageContent = buildOrderStatusNotification(
      nextStatusRaw, orderId, after.id);
  if (!messageContent) {
    return {sent: 0, failed: 0, reason: "untracked_status"};
  }

  const customerUid = typeof after.customerUid === "string" ?
    after.customerUid.trim() : "";
  if (!customerUid) {
    return {sent: 0, failed: 0, reason: "missing_customer_uid"};
  }

  const [userSnap, profileSnap] = await Promise.all([
    db.collection("users").doc(customerUid).get(),
    db.collection("customerProfiles").doc(customerUid).get(),
  ]);
  const tokens = collectCustomerTokens([
    userSnap.exists ? userSnap.data() : null,
    profileSnap.exists ? profileSnap.data() : null,
  ]);
  if (tokens.length === 0) {
    return {sent: 0, failed: 0, reason: "no_tokens"};
  }

  const sender = messaging || getMessaging();
  const payload = {
    tokens,
    notification: {
      title: messageContent.title,
      body: messageContent.body,
    },
    data: {
      type: "order_status",
      orderId: String(orderId),
      friendlyId: typeof after.id === "string" ? after.id : "",
      status: nextStatusRaw,
      stage: messageContent.key,
    },
    android: {
      priority: "high",
      notification: {
        channelId: "chamae_orders_high",
        sound: "default",
      },
    },
    apns: {
      headers: {
        "apns-priority": "10",
      },
      payload: {
        aps: {
          sound: "default",
          contentAvailable: true,
        },
      },
    },
  };

  const response = await sender.sendEachForMulticast(payload);
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
    const removal = {
      fcmTokens: FieldValue.arrayRemove(...invalidTokens),
    };
    const cleanupOps = [
      db.collection("users").doc(customerUid).set(removal, {merge: true}),
      db.collection("customerProfiles").doc(customerUid).set(removal, {merge: true}),
    ];
    await Promise.all(cleanupOps);
  }

  return {
    sent: response.successCount || 0,
    failed: response.failureCount || 0,
  };
}

/** Creates Firebase v2 push notification triggers and callables.
 * @param {Object} db Firestore Admin SDK.
 * @return {Object} Exported handlers.
 */
function createCustomerPushFunctions(db) {
  return {
    chamaeRegistrarTokenPushCliente: onCall(
        {region: "southamerica-east1", maxInstances: 10},
        (request) => registerCustomerPushToken(db, request)),
    chamaeNotificarStatusPedido: onDocumentUpdated(
        {
          document: "orders/{orderId}",
          region: "southamerica-east1",
          maxInstances: 10,
        },
        (event) => notifyOrderStatusChange(db, event)),
  };
}

module.exports = {
  normalizeStatusKey,
  buildOrderStatusNotification,
  collectCustomerTokens,
  registerCustomerPushToken,
  notifyOrderStatusChange,
  createCustomerPushFunctions,
};
