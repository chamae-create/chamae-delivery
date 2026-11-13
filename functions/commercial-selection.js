"use strict";
const manifest = require("./commercial-selection.json");
const local = (host) => typeof host === "string" && /^(127\.0\.0\.1|localhost):[1-9][0-9]{0,4}$/.test(host);
function integrationProject(env) {
  let config = {};
  if (env.FIREBASE_CONFIG) {
    try { config = JSON.parse(env.FIREBASE_CONFIG); } catch (_) { throw Error("EXPLICIT_PROJECT_REQUIRED"); }
  }
  const ids = [env.GCLOUD_PROJECT, env.GCP_PROJECT, config.projectId].filter(Boolean);
  if (!ids.length || ids.some((id) => id !== ids[0])) throw Error("PROJECT_IDENTITY_MISMATCH");
  const project = ids[0];
  const emulator = Object.entries(env).filter(([k, v]) => v &&
    ["FIRESTORE_EMULATOR_HOST", "FIREBASE_AUTH_EMULATOR_HOST", "FIREBASE_STORAGE_EMULATOR_HOST"].includes(k));
  if (emulator.some(([, host]) => !local(host))) throw Error("NONLOCAL_EMULATOR_REFUSED");
  if (project === "demo-chamae-m9" && local(env.FIRESTORE_EMULATOR_HOST)) return project;
  if (project !== manifest.projectId || emulator.length) throw Error("STAGING_OR_ISOLATED_LOCAL_ONLY");
  return project;
}
function selectCommercialExports(available) {
  const selected = {};
  for (const name of Object.values(manifest.groups).flat()) {
    if (Object.hasOwn(selected, name)) throw Error(`DUPLICATE_EXPORT:${name}`);
    if (!Object.hasOwn(available, name) || typeof available[name] !== "function" || !available[name].__endpoint) {
      throw Error(`MISSING_CALLABLE_OR_TRIGGER:${name}`);
    }
    if (manifest.excluded.includes(name)) throw Error(`EXCLUDED_EXPORT:${name}`);
    selected[name] = available[name];
  }
  return selected;
}
module.exports = {integrationProject, selectCommercialExports};
