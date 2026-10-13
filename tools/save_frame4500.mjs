import http from 'node:http';
import { spawn } from 'node:child_process';
import path from 'node:path';
import fs from 'node:fs';

const PROMO_DIR = path.resolve('promo');
const CHROME_PATH = 'C:/Program Files/Google/Chrome/Application/chrome.exe';

function startStaticServer(dir, port) {
  const mimeTypes = { '.html': 'text/html', '.css': 'text/css', '.js': 'application/javascript', '.png': 'image/png' };
  return new Promise((resolve) => {
    const server = http.createServer((req, res) => {
      let reqPath = req.url.split('?')[0];
      if (reqPath === '/') reqPath = '/index.html';
      const filePath = path.join(dir, reqPath);
      if (fs.existsSync(filePath) && fs.statSync(filePath).isFile()) {
        const ext = path.extname(filePath).toLowerCase();
        res.writeHead(200, { 'Content-Type': mimeTypes[ext] || 'application/octet-stream' });
        fs.createReadStream(filePath).pipe(res);
      } else { res.writeHead(404); res.end('Not Found'); }
    });
    server.listen(port, () => resolve(server));
  });
}

async function test() {
  const server = await startStaticServer(PROMO_DIR, 8499);
  const tempDir = path.resolve('promo/dist/test_chrome_4500_data');
  const chromeArgs = [
    '--headless=new',
    '--remote-debugging-port=9477',
    '--window-size=3840,2160',
    '--force-device-scale-factor=1',
    '--enable-gpu',
    '--enable-gpu-rasterization',
    '--use-gl=angle',
    '--use-angle=d3d11',
    '--ignore-gpu-blocklist',
    '--user-data-dir=' + tempDir,
    'http://127.0.0.1:8499/index.html'
  ];

  const proc = spawn(CHROME_PATH, chromeArgs, { stdio: 'ignore' });
  await new Promise(r => setTimeout(r, 2000));
  const jsonRes = await fetch('http://127.0.0.1:9477/json');
  const targets = await jsonRes.json();
  const page = targets.find(t => t.type === 'page');

  const ws = new WebSocket(page.webSocketDebuggerUrl);
  await new Promise(r => ws.onopen = r);

  let reqId = 1;
  const cbs = new Map();
  ws.onmessage = (e) => {
    const msg = JSON.parse(e.data);
    if (msg.id && cbs.has(msg.id)) {
      const { res, rej } = cbs.get(msg.id);
      cbs.delete(msg.id);
      if (msg.error) rej(msg.error);
      else res(msg.result);
    }
  };

  function send(method, params = {}) {
    return new Promise((resolve, reject) => {
      const id = reqId++;
      cbs.set(id, { res: resolve, rej: reject });
      ws.send(JSON.stringify({ id, method, params }));
    });
  }

  await send('Page.enable');
  await send('Runtime.enable');
  await send('Runtime.evaluate', { expression: `document.body.classList.add('recording-mode')` });
  await send('Runtime.evaluate', { expression: `window.setSeekFrame(4500)` });

  const evalRes = await send('Runtime.evaluate', {
    expression: `document.getElementById('promoCanvas').toDataURL('image/png')`,
    returnByValue: true
  });

  const base64Data = evalRes.result.value.replace(/^data:image\/png;base64,/, '');
  const outPath = 'promo/dist/preview_05_Act4_Aurora_Poem_Ferris_OldG_4500.png';
  fs.writeFileSync(outPath, Buffer.from(base64Data, 'base64'));
  console.log('SUCCESS: preview_05 written, bytes:', fs.statSync(outPath).size);

  ws.close();
  proc.kill();
  server.close();
}

test().catch(console.error);
