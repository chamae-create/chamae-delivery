const {point} = require("./delivery-pricing");
const {HttpsError} = require("firebase-functions/v2/https");
const unverified = () => new HttpsError("failed-precondition",
    "Não foi possível confirmar o país do destino. Confira o endereço e tente novamente.",
    {reason: "DESTINATION_COUNTRY_UNVERIFIED"});

class GoogleDestinationCountry {
  constructor({apiKey, fetchImpl = fetch}) {
    this.apiKey = apiKey; this.fetchImpl = fetchImpl;
  }
  async verify(destination) {
    if (!this.apiKey || !point(destination)) throw unverified();
    // No client country/region bias. Require an unambiguous country-level result.
    const url = new URL("https://maps.googleapis.com/maps/api/geocode/json");
    url.searchParams.set("latlng", `${destination.latitude},${destination.longitude}`);
    url.searchParams.set("result_type", "country");
    url.searchParams.set("key", this.apiKey);
    try {
      const response = await this.fetchImpl(url.toString(), {signal: AbortSignal.timeout(8000)});
      if (!response.ok) throw unverified();
      const data = await response.json();
      if (data.status !== "OK" || !Array.isArray(data.results) || !data.results.length) throw unverified();
      const countries = data.results.map((result) => {
        if (result.partial_match || !result.types?.includes("country")) throw unverified();
        const components = result.address_components?.filter((c) => c.types?.includes("country"));
        if (components?.length !== 1 || !["BR", "PY"].includes(components[0].short_name)) throw unverified();
        return components[0].short_name;
      });
      if (new Set(countries).size !== 1 || countries[0] !== destination.countryCode) throw unverified();
      return {schemaVersion: 1, provider: "google-geocoding", countryCode: countries[0],
        latitude: destination.latitude, longitude: destination.longitude, verifiedAtMs: Date.now()};
    } catch (_) {
      // Never leak provider URL/key or treat nearest address/error as a country.
      throw unverified();
    }
  }
}
module.exports = {GoogleDestinationCountry};
