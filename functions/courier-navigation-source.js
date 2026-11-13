"use strict";
const {Timestamp}=require("firebase-admin/firestore");
const {HttpsError}=require("firebase-functions/v2/https");
const {validNavigation}=require("./courier-navigation-package");
const {point}=require("./delivery-pricing");
const {isDeepStrictEqual}=require("node:util");
const fail=()=>{throw new HttpsError("failed-precondition","AUTHORITATIVE_NAVIGATION_SOURCE_REQUIRED",
 {reason:"AUTHORITATIVE_NAVIGATION_SOURCE_REQUIRED"});};
// Only trusted backend writers may populate this private source; no client URL,
// file path, uploaded payload, distance-only route or generated road fallback.
function createStoredNavigationProvider(db,{sourceId,engine}){
 if(typeof sourceId!=="string"||!/^[A-Za-z0-9_-]{1,80}$/.test(sourceId)||
   typeof engine!=="string"||!engine||engine.length>80)fail();
 return async function navigationSource(context){
  const {customerUid,assignmentId}=context;
  const source=(await db.doc("customerDeliverySecrets/"+customerUid+"/courierRouteInputs/"+assignmentId).get()).data();
  if(!source||Object.keys(source).some(k=>!["schemaVersion","status","sourceId","orderId","assignmentId",
    "courierUid","origin","destination","expiresAt","mapJson"].includes(k))||
    source.schemaVersion!==1||source.status!=="ready"||source.sourceId!==sourceId||
    ["orderId","assignmentId","courierUid"].some(k=>source[k]!==context[k])||
    !isDeepStrictEqual(source.origin,context.origin)||!isDeepStrictEqual(source.destination,context.destination)||
    !(source.expiresAt instanceof Timestamp)||source.expiresAt.toMillis()<=Date.now()||
    source.expiresAt.toMillis()>context.assignmentExpiresAtMs)fail();
  let m;
  try {
    if (typeof source.mapJson !== "string" || Buffer.byteLength(source.mapJson) > 512*1024) fail();
    m=JSON.parse(source.mapJson);
  } catch (_) { fail(); }
  if(!m||Object.keys(m).some(k=>!["geometry","asset","provider","navigation"].includes(k))||
    m.provider!==sourceId||typeof m.asset!=="string"||!/^[A-Za-z0-9_.:-]{1,128}$/.test(m.asset)||
    m.navigation?.engine!==engine||!validNavigation(m.navigation,context.destination,m.geometry)||
    !isDeepStrictEqual(m.geometry[0],context.origin))fail();
  // The bounded graph must at least connect origin to destination.
  const nodes=m.navigation.nodes,edges=m.navigation.edges;
  const same=(a,b)=>point(a)&&point(b)&&a.latitude===b.latitude&&a.longitude===b.longitude;
  const starts=nodes.filter(n=>same(n.point,context.origin)).map(n=>n.id),seen=new Set(starts);
  for(let i=0;i<starts.length;i++)for(const e of edges)if(e.from===starts[i]&&!seen.has(e.to)){seen.add(e.to);starts.push(e.to);}
  if(!nodes.some(n=>seen.has(n.id)&&same(n.point,context.destination)))fail();
  return {map:m,expiresAtMs:source.expiresAt.toMillis()};
 };
}
module.exports={createStoredNavigationProvider};
