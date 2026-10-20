// Windows Flutter 3.47 test-server workaround: serve the installed SDK's own
// CanvasKit files to the headless test page through CDP. No SDK/app patch and
// no external asset service. Usage: node tool/chrome_test_assets.mjs PORT SDK
import { readFile } from 'node:fs/promises';
import path from 'node:path';

const port = Number(process.argv[2]);
if (!Number.isInteger(port) || port < 1 || port > 65535 || !process.argv[3]) {
  throw new Error('Usage: node tool/chrome_test_assets.mjs DEBUG_PORT FLUTTER_SDK');
}
const root = path.resolve(process.argv[3], 'bin/cache/flutter_web_sdk/canvaskit');
const targets = await (await fetch(`http://127.0.0.1:${port}/json`)).json();
const target = targets.find(t => {
  if (t.type !== 'page') return false;
  const url = new URL(t.url);
  return url.hostname === 'localhost' && url.pathname === '/static/index.html' &&
    url.searchParams.has('managerUrl');
});
if (!target) throw new Error('No Flutter headless test page found on this port.');
const origin = new URL(target.url).origin;
const ws = new WebSocket(target.webSocketDebuggerUrl);
let id = 0;
const send = (method, params = {}) => ws.send(JSON.stringify({ id: ++id, method, params }));
ws.onopen = () => send('Fetch.enable', { patterns: [{ urlPattern: `${origin}/canvaskit/*` }] });
ws.onmessage = async ({ data }) => {
  const message = JSON.parse(data);
  if (message.id === 1 && !message.error) {
    send('Runtime.evaluate', { expression:
      "document.querySelectorAll('iframe').forEach(f => { if(new URL(f.src).origin === location.origin) f.contentWindow.location.reload(); })" });
    console.log('Serving SDK CanvasKit to the local test page.');
  }
  if (message.method !== 'Fetch.requestPaused') return;
  const { requestId, request } = message.params;
  try {
    const url = new URL(request.url);
    const relative = decodeURIComponent(url.pathname.slice('/canvaskit/'.length));
    const file = path.resolve(root, relative);
    if (url.origin !== origin || !file.startsWith(root + path.sep) ||
        !['.js', '.wasm'].includes(path.extname(file))) throw new Error('Unexpected test asset');
    const bytes = await readFile(file);
    send('Fetch.fulfillRequest', { requestId, responseCode: 200,
      responseHeaders: [{ name: 'Content-Type', value: file.endsWith('.wasm') ?
        'application/wasm' : 'text/javascript' }], body: bytes.toString('base64') });
    console.log(`Served ${relative}`);
  } catch (error) {
    console.error(error.message);
    send('Fetch.failRequest', { requestId, errorReason: 'Failed' });
  }
};
ws.onerror = () => process.exitCode = 1;
// A full suite can exceed ten minutes while release compilers share memory.
// The socket still closes immediately when the test browser is shut down.
const timeout = setTimeout(() => ws.close(), 1800000);
ws.onclose = () => clearTimeout(timeout);
