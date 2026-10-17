const assert = require("node:assert/strict");
const {getFirestore} = require("firebase-admin/firestore");

/** Loads real exported handlers against the default emulator application.
 * @param {Object} db Real emulator Firestore.
 * @return {Object} Native handlers; no financial or stock algorithm mocked.
 */
function loadBackend(db) {
  assert.equal(getFirestore(), db);
  const exported = require("../index");
  const functions = {};
  for (const [name, fn] of Object.entries(exported)) {
    functions[name] = fn.run;
  }
  return {functions, endpoints: exported};
}
module.exports = {loadBackend};
