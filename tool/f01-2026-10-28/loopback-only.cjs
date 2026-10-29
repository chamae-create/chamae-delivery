// Test-runner boundary: local emulators only. No ADC/provider/production network fallback.
const allowed = (host) => ["localhost", "127.0.0.1", "::1", "[::1]"].includes(host);
const check = (host) => { if (!allowed(host)) throw new Error("F01_EXTERNAL_NETWORK_DISABLED"); };
const originalFetch = global.fetch;
global.fetch = (url, ...args) => { check(new URL(typeof url === "string" ? url : url instanceof URL ? url.href : url.url).hostname);
  return originalFetch(url, ...args); };
for (const name of ["node:http", "node:https"]) {
  const module = require(name);
  for (const method of ["request", "get"]) {
    const original = module[method];
    module[method] = function(...args) {
      const first = args[0];
      const host = typeof first === "string" || first instanceof URL ? new URL(first).hostname :
        first.hostname || first.host || "localhost";
      check(host); return original.apply(this, args);
    };
  }
}
