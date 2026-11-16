"use strict";
const {Compute} = require("google-auth-library");
const {DeliveryError} = require("./delivery-pricing");
const ALLOWED_PROJECTS = new Set([
  "chamae-delivery-staging",
  "chamae-delivery",
]);

// Metadata identity only. Never reads ADC credential files or service-account keys.
function createRuntimeMapsAuth({env = process.env, clientFactory = () =>
  new Compute({scopes: ["https://www.googleapis.com/auth/cloud-platform"]})} = {}) {
  let client;
  return async () => {
    try {
      const projects = [env.GCLOUD_PROJECT, env.GCP_PROJECT, env.GOOGLE_CLOUD_PROJECT].filter(Boolean);
      const unique = new Set(projects);
      const projectId = unique.size === 1 ? projects[0] : "";
      if (!env.K_SERVICE || !ALLOWED_PROJECTS.has(projectId)) {
        throw Error("RUNTIME_IDENTITY_REQUIRED");
      }
      if (!client) client = clientFactory();
      const result = await client.getAccessToken();
      const token = typeof result === "string" ? result : result?.token;
      if (typeof token !== "string" || !token || /[\r\n]/.test(token)) throw Error("TOKEN_UNAVAILABLE");
      return {Authorization: "Bearer " + token, "X-Goog-User-Project": projectId};
    } catch (_) {
      throw new DeliveryError("MAPS_RUNTIME_AUTH_UNAVAILABLE");
    }
  };
}
module.exports = {createRuntimeMapsAuth};
