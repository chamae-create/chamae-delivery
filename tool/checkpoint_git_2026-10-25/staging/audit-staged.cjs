const fs = require('fs');
const cp = require('child_process');
const crypto = require('crypto');
const path = require('path');
const dir = 'tool/checkpoint_git_2026-10-25/staging';
const pre = JSON.parse(fs.readFileSync(`${dir}/preflight.json`, 'utf8'));
const git = args => cp.execFileSync('git', ['-c', 'core.quotepath=false', ...args], {maxBuffer: 40*1024*1024, stdio:['ignore','pipe','pipe']});
const names = git(['diff','--cached','--name-only','-z']).toString().split('\0').filter(Boolean);
const statusFields = git(['diff','--cached','--name-status','-z']).toString().split('\0').filter(Boolean);
const statuses=[];
for(let i=0;i<statusFields.length;){const type=statusFields[i++];const p=statusFields[i++];if(/^[RC]/.test(type))statuses.push({type,path:p,to:statusFields[i++]});else statuses.push({type,path:p});}
const counts={total:statuses.length,modified:statuses.filter(s=>s.type==='M').length,added:statuses.filter(s=>s.type==='A').length,deleted:statuses.filter(s=>s.type==='D').length,renamed:statuses.filter(s=>s.type.startsWith('R')).length,other:statuses.filter(s=>!['M','A','D'].includes(s.type)&&!s.type.startsWith('R')).length};
const hash = p => crypto.createHash('sha256').update(fs.readFileSync(p)).digest('hex');
const unsafeName=p=>/(^|\/)(?:key\.properties|local\.properties|\.env(?:\..*)?|\.runtimeconfig\.json|GeneratedPluginRegistrant\.(?:java|m))$|\.(?:jks|keystore|pem|p12|pfx|key|log|tmp|bak|aab|apk)$/i.test(p)||/(^|\/)(?:build|node_modules|secrets|credentials|\.dart_tool|\.gradle|before|backups)\//i.test(p);
const patterns=[['password',/password/ig],['secret',/secret/ig],['token',/token/ig],['private_key',/private_key/ig],['client_secret',/client_secret/ig],['BEGIN PRIVATE KEY',/BEGIN (?:RSA |EC |OPENSSH |ENCRYPTED )?PRIVATE KEY/ig],['storePassword',/storePassword/g],['keyPassword',/keyPassword/g]];
const hits=[],literals=[],danger=[],absolutePaths=[],markers=[];
let textFiles=0,binaryFiles=0;
for(const p of names){
 const b=git(['show',':'+p]);
 if(b.includes(0)){binaryFiles++;continue;}
 textFiles++;const text=b.toString('utf8');
 for(const [rule,regex] of patterns){const matches=[...text.matchAll(regex)];if(matches.length)hits.push({path:p,rule,count:matches.length});}
 const lines=text.split(/\r?\n/);
 lines.forEach((line,i)=>{
  if(/(?:[A-Z]:[\\/](?:Users|Program Files)|(?:^|[\s"'`(=])\/(?:Users|home)\/)/i.test(line))absolutePaths.push({path:p,line:i+1,documentation:p.startsWith('docs/')});
  if(/^(?:<{7}|={7}|>{7})(?:\s|$)/.test(line))markers.push({path:p,line:i+1});
  const literal=/\b([A-Za-z0-9_]*(?:password|secret|token|private_key|client_secret|apiKey)[A-Za-z0-9_]*)\b["']?\s*[:=]\s*(["'])([^"'\r\n]*)\2/ig;
  for(const m of line.matchAll(literal)) {
    const value=m[3];if(!value.trim())continue;
    const testFile=/(^|\/)(?:test|tests)\//.test(p);
    const placeholder=/^(?:TEST[-_]?ONLY|PRIVATE_TEST_KEY|TEST|test|fake|mock|fixture|dummy|invalid|expired|revoked|apple|google|token|nonce|none|not-configured|sign-in-with-apple|sign-in-with-google)(?:[-_ ].*)?$/i.test(value)||/^(?:test|fake|mock|fixture|dummy)[-_]/i.test(value);
    literals.push({path:p,line:i+1,field:m[1],characters:value.length,testFile,placeholder});
  }
  const risks=[['private-key-material',/-----BEGIN (?:RSA |EC |OPENSSH |ENCRYPTED )?PRIVATE KEY-----/],['service-account-private-key',/["']private_key["']\s*:\s*["'][^"']{10,}/],['production-provider-token',/\b(?:APP_USR|APP-USR|sk_live)[-_][A-Za-z0-9_-]{12,}/],['jwt-literal',/eyJ[A-Za-z0-9_-]{12,}\.eyJ[A-Za-z0-9_-]{12,}\.[A-Za-z0-9_-]{12,}/]];
  for(const [rule,regex] of risks)if(regex.test(line))danger.push({path:p,line:i+1,rule});
 });
}
const preservedExcluded=pre.excluded.every(p=>fs.existsSync(p)&&hash(p)===pre.excludedHashes[p]);
const checks={counts,exactApprovedSet:names.length===pre.approved.length&&pre.approved.every(p=>names.includes(p)),excludedStaged:names.filter(p=>pre.excluded.includes(p)),unsafeNames:names.filter(unsafeName),textFiles,binaryFiles,patternHits:hits,literalAssignments:literals,danger,absolutePaths,conflictMarkers:markers,excludedCount:pre.excluded.length,excludedPreserved:preservedExcluded,headUnchanged:git(['rev-parse','HEAD']).toString().trim()===pre.head,officialKeyOutsideRepo:!path.resolve('C:/Users/DELL/LoumakSecure/Android/chamae-upload.jks').toLowerCase().startsWith(path.resolve('.').toLowerCase()+path.sep)};
fs.writeFileSync(`${dir}/audit.json`,JSON.stringify(checks,null,2));
fs.writeFileSync(`${dir}/git-status-short.txt`,git(['status','--short']));
fs.writeFileSync(`${dir}/git-diff-cached-stat.txt`,git(['diff','--cached','--stat']));
fs.writeFileSync(`${dir}/git-diff-cached-name-status.txt`,git(['diff','--cached','--name-status']));
console.log(JSON.stringify({...checks,patternHits:patterns.map(([rule])=>({rule,files:hits.filter(h=>h.rule===rule).length,occurrences:hits.filter(h=>h.rule===rule).reduce((n,h)=>n+h.count,0)}))},null,2));
if(!checks.exactApprovedSet||checks.excludedStaged.length||checks.unsafeNames.length||counts.deleted||counts.renamed||counts.other||!preservedExcluded||danger.length||markers.length||!checks.headUnchanged)process.exit(1);
