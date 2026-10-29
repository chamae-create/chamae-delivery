const {isApprovedCourierProfile} = require("./courier-authorization");
const {FieldValue} = require("firebase-admin/firestore");
// Opaque assignment identifiers only. Never customer/payment/address data.
function assignmentNotice(orderId, assignmentId) {
  return {kind: "courier_assignment", version: "2", orderId, assignmentId,
    title: "Nova entrega Chamaê", body: "Você recebeu uma nova entrega da Pit Stop V8."};
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
module.exports = {assignmentNotice, enqueueNotice, deliverNotice};
