// Bounded navigation component contract, not a road-routing engine.
const point = (p) => p && typeof p === "object" && !Array.isArray(p) &&
  Object.keys(p).every((k) => ["latitude", "longitude"].includes(k)) &&
  Number.isFinite(p.latitude) && Math.abs(p.latitude) <= 90 &&
  Number.isFinite(p.longitude) && Math.abs(p.longitude) <= 180;
const line = (v) => Array.isArray(v) && v.length >= 2 && v.length <= 2048 && v.every(point);
function validNavigation(n, destination, primary) {
  if (!n || n.schemaVersion !== 1 || Object.keys(n).some((k) =>
    !["schemaVersion", "engine", "datasetVersion", "destination", "coverage", "nodes", "edges",
      "alternatives"].includes(k)) || typeof n.engine !== "string" || !n.engine || n.engine.length > 80 ||
    typeof n.datasetVersion !== "string" || !n.datasetVersion || n.datasetVersion.length > 128 ||
    !point(n.destination) || !point(destination) || n.destination.latitude !== destination.latitude ||
    n.destination.longitude !== destination.longitude || !line(primary) ||
    primary.at(-1).latitude !== destination.latitude || primary.at(-1).longitude !== destination.longitude ||
    !Array.isArray(n.nodes) || n.nodes.length < 2 || n.nodes.length > 256 ||
    !Array.isArray(n.edges) || !n.edges.length || n.edges.length > 1024 ||
    !Array.isArray(n.alternatives) || n.alternatives.length > 16 || !n.alternatives.every(line)) return false;
  const c = n.coverage;
  if (!c || Object.keys(c).some((k) => !["marginMeters", "corridors"].includes(k)) ||
    !Number.isFinite(c.marginMeters) || c.marginMeters < 30 || c.marginMeters > 1000 ||
    !Array.isArray(c.corridors) || !c.corridors.length || c.corridors.length > 16 ||
    !c.corridors.every(line)) return false;
  const ids = new Set();
  for (const node of n.nodes) {
    if (!node || Object.keys(node).some((k) => !["id", "point"].includes(k)) ||
      typeof node.id !== "string" || !/^[A-Za-z0-9_-]{1,64}$/.test(node.id) ||
      ids.has(node.id) || !point(node.point)) return false;
    ids.add(node.id);
  }
  return n.nodes.some((node) => node.point.latitude === destination.latitude &&
      node.point.longitude === destination.longitude) && n.edges.every((e) => e &&
    Object.keys(e).every((k) => ["from", "to"].includes(k)) &&
    ids.has(e.from) && ids.has(e.to) && e.from !== e.to);
}
module.exports = {validNavigation};
