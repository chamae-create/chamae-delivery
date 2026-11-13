"use strict";
const {Compute} = require("google-auth-library");
const {DeliveryError} = require("./delivery-pricing");
// Metadata identity only. Never reads ADC credential files or service-account keys.
function createRuntimeMapsAuth({env = process.env, clientFactory = () =>
  new Compute({scopes: ["https://www.googleapis.com/auth/cloud-platform"]})} = {}) {
  let client;
  return async () => {
    try {
      const projects = [env.GCLOUD_PROJECT, env.GCP_PROJECT, env.GOOGLE_CLOUD_PROJECT].filter(Boolean);
      if (!env.K_SERVICE || !projects.length || projects.some((p) => p !== "chamae-delivery-staging")) {
        throw Error("RUNTIME_IDENTITY_REQUIRED");
      }
      if (!client) client = clientFactory();
      const result = await client.getAccessToken();
      const token = typeof result === "string" ? result : result?.token;
      if (typeof token !== "string" || !token || /[\r\n]/.test(token)) throw Error("TOKEN_UNAVAILABLE");
      return {Authorization: "Bearer " + token, "X-Goog-User-Project": "chamae-delivery-staging"};
    } catch (_) {
      throw new DeliveryError("MAPS_RUNTIME_AUTH_UNAVAILABLE");
    }
  };
}
module.exports = {createRuntimeMapsAuth};
