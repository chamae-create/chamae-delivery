const {RoutingProvider, DeliveryError, point} = require("./delivery-pricing");

// Server-only adapter. No browser/Android key, straight-line or zero-fee fallback.
// The active configuration must explicitly select DRIVE or TWO_WHEELER.
class GoogleRoutesProvider extends RoutingProvider {
  constructor({apiKey, travelMode, fetchImpl = fetch}) {
    super(); this.apiKey = apiKey; this.travelMode = travelMode; this.fetchImpl = fetchImpl;
  }
  async route({origin, destination}) {
    if (!this.apiKey || !["DRIVE", "TWO_WHEELER"].includes(this.travelMode)) {
      throw new DeliveryError("ROUTING_PROVIDER_NOT_CONFIGURED");
    }
    if (!point(origin) || !point(destination)) throw new DeliveryError("INVALID_COORDINATES");
    const waypoint = ({latitude, longitude}) => ({location: {latLng: {latitude, longitude}}});
    try {
      const response = await this.fetchImpl("https://routes.googleapis.com/directions/v2:computeRoutes", {
        method: "POST", signal: AbortSignal.timeout(10000), headers: {
          "Content-Type": "application/json", "X-Goog-Api-Key": this.apiKey,
          "X-Goog-FieldMask": "routes.distanceMeters,routes.duration,fallbackInfo",
        }, body: JSON.stringify({origin: waypoint(origin), destination: waypoint(destination),
          travelMode: this.travelMode, computeAlternativeRoutes: false}),
      });
      if (!response.ok) throw new Error("unavailable");
      const data = await response.json(); const route = data.routes?.[0];
      if (data.fallbackInfo || !route || !Number.isSafeInteger(route.distanceMeters) || route.distanceMeters < 0) {
        throw new Error("unavailable");
      }
      const duration = typeof route.duration === "string" && /^\d+(\.\d+)?s$/.test(route.duration) ?
        Number(route.duration.slice(0, -1)) : null;
      return {status: "ok", distanceMeters: route.distanceMeters, durationSeconds: duration, provider: "google-routes"};
    } catch (_) {
      throw new DeliveryError("ROUTE_UNAVAILABLE");
    }
  }
}
module.exports = {GoogleRoutesProvider};
