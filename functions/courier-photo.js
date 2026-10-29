const {createHash} = require("node:crypto");
const {getStorage} = require("firebase-admin/storage");
const {FieldValue} = require("firebase-admin/firestore");
const {HttpsError, onCall} = require("firebase-functions/v2/https");
const {requireCourierIdentity} = require("./courier-authorization");
async function confirmCourierPhoto(db, storage, request) {
  const uid = requireCourierIdentity(request);
  const roles = request.auth.token && request.auth.token.roles;
  const d = request.data;
  if (roles && (!Array.isArray(roles) || roles.length) || !d || typeof d !== "object" ||
      Array.isArray(d) || Object.keys(d).some((key) => key !== "reference") || typeof d.reference !== "string" ||
      !d.reference.startsWith(`courier-photos/${uid}/`) ||
      !/^[a-f0-9]{64}\.(png|jpg)$/.test(d.reference.slice(`courier-photos/${uid}/`.length))) {
    throw new HttpsError("permission-denied", "Foto não pertence a esta conta.");
  }
  const [metadata] = await storage.file(d.reference).getMetadata();
  if (!Number.isSafeInteger(Number(metadata.size)) || Number(metadata.size) < 8 || Number(metadata.size) > 512 * 1024 ||
      !["image/png", "image/jpeg"].includes(metadata.contentType) || !metadata.generation) {
    throw new HttpsError("invalid-argument", "Escolha uma imagem de até 512 KB.");
  }
  const [bytes] = await storage.file(d.reference, {generation: metadata.generation}).download();
  const digest = createHash("sha256").update(bytes).digest("hex");
  const png = bytes.subarray(0, 8).equals(Buffer.from([137, 80, 78, 71, 13, 10, 26, 10]));
  const jpeg = bytes[0] === 255 && bytes[1] === 216 && bytes[2] === 255;
  if (bytes.length !== Number(metadata.size) ||
      !(png && metadata.contentType === "image/png" || jpeg && metadata.contentType === "image/jpeg") ||
      !d.reference.endsWith(`${digest}.${png ? "png" : "jpg"}`)) {
    throw new HttpsError("invalid-argument", "A imagem enviada não corresponde ao comprovante.");
  }
  await db.runTransaction(async (tx) => {
    const closure = await tx.get(db.doc(`courierAccountClosures/${uid}`));
    const customer = await tx.get(db.doc(`customerAccountClosures/${uid}`));
    if (closure.exists || customer.exists && customer.data().status !== "blocked") {
      throw new HttpsError("failed-precondition", "A conta está em encerramento.");
    }
    tx.set(db.doc(`courierProfilePhotos/${uid}`), {verified: true, reference: d.reference,
      generation: String(metadata.generation), digest, verification: "storage_ownership_and_image_header",
      verifiedAt: FieldValue.serverTimestamp()});
  });
  return {reference: d.reference, verified: true};
}
function createCourierPhotoFunctions(db) {
  return {chamaeConfirmarFotoMotoboy: onCall({region: "southamerica-east1", maxInstances: 10},
      (r) => confirmCourierPhoto(db, getStorage().bucket(), r))};
}
module.exports = {confirmCourierPhoto, createCourierPhotoFunctions};
