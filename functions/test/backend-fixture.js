const assert = require("node:assert/strict");
const {getFirestore} = require("firebase-admin/firestore");
const {useOpenClock} = require("./operational-fixture");

/** Loads real exported handlers against the default emulator application.
 * @param {Object} db Real emulator Firestore.
 * @return {Object} Native handlers; no financial or stock algorithm mocked.
 */
function loadBackend(db) {
  useOpenClock();
  assert.equal(getFirestore(), db);
  const exported = require("../index");
  const functions = {};
  for (const [name, fn] of Object.entries(exported)) {
    functions[name] = fn.run;
  }
  return {functions, endpoints: exported};
}
module.exports = {loadBackend};
