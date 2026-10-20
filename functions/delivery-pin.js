const {randomInt, randomBytes, createCipheriv, createDecipheriv,
  createHmac, timingSafeEqual} = require("node:crypto");

function generatePin() {
  return randomInt(10000).toString().padStart(4, "0");
}
function keyBytes(key) {
  if (!/^[a-fA-F0-9]{64}$/.test(key || "")) throw new Error("PIN_KEY_NOT_CONFIGURED");
  return Buffer.from(key, "hex");
}
function encryptPin(pin, uid, key) {
  if (!/^\d{4}$/.test(pin) || !uid) throw new Error("INVALID_PIN");
  const iv = randomBytes(12);
  const cipher = createCipheriv("aes-256-gcm", keyBytes(key), iv);
  cipher.setAAD(Buffer.from(uid));
  const value = Buffer.concat([cipher.update(pin, "utf8"), cipher.final()]);
  return {iv: iv.toString("hex"), value: value.toString("hex"), tag: cipher.getAuthTag().toString("hex")};
}
function decryptPin(secret, uid, key) {
  const decipher = createDecipheriv("aes-256-gcm", keyBytes(key), Buffer.from(secret.iv, "hex"));
  decipher.setAAD(Buffer.from(uid));
  decipher.setAuthTag(Buffer.from(secret.tag, "hex"));
  return Buffer.concat([decipher.update(Buffer.from(secret.value, "hex")), decipher.final()]).toString("utf8");
}
function verifier(pin, uid, orderId, salt, key) {
  return createHmac("sha256", keyBytes(key))
      .update(JSON.stringify([uid, orderId, salt, pin])).digest("hex");
}
function newOrderVerifier(pin, uid, orderId, key) {
  const salt = randomBytes(24).toString("hex");
  return {salt, digest: verifier(pin, uid, orderId, salt, key), attempts: 0,
    maxAttempts: 5, reconciled: false};
}
// Must be called INSIDE a server transaction; persist attempts plus audit event
// atomically. This is not an offline verifier and is never sent to a courier.
function checkAttempt(record, pin, uid, orderId, key) {
  if (!record || !Number.isSafeInteger(record.attempts) || record.attempts < 0 ||
      !Number.isSafeInteger(record.maxAttempts) || record.maxAttempts < 1 || record.maxAttempts > 5 ||
      !/^[a-f0-9]{48}$/.test(record.salt || "") || !/^[a-f0-9]{64}$/.test(record.digest || "") ||
      record.attempts >= record.maxAttempts || record.reconciled !== false) {
    return {allowed: false, matched: false, record};
  }
  const expected = Buffer.from(record.digest, "hex");
  const actual = Buffer.from(verifier(pin, uid, orderId, record.salt, key), "hex");
  const matched = /^\d{4}$/.test(pin) && expected.length === actual.length && timingSafeEqual(expected, actual);
  return {allowed: true, matched, record: {...record, attempts: record.attempts + 1,
    reconciled: matched}};
}
module.exports = {generatePin, encryptPin, decryptPin, newOrderVerifier, checkAttempt};
