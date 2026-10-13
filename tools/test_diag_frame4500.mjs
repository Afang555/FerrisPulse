import http from 'node:http';
import { spawn } from 'node:child_process';
import path from 'node:path';
import fs from 'node:fs';

const PROMO_DIR = path.resolve('promo');
const CHROME_PATH = 'C:/Program Files/Google/Chrome/Application/chrome.exe';

function startStaticServer(dir, port) {
  const mimeTypes = {
    '.html': 'text/html',
    '.css': 'text/css',
    '.js': 'application/javascript',
    '.png': 'image/png'
  };
  return new Promise((resolve) => {
    const server = http.createServer((req, res) => {
      let reqPath = req.url.split('?')[0];
      if (reqPath === '/') reqPath = '/index.html';
      const filePath = path.join(dir, reqPath);
      if (fs.existsSync(filePath) && fs.statSync(filePath).isFile()) {
        const ext = path.extname(filePath).toLowerCase();
        res.writeHead(200, { 'Content-Type': mimeTypes[ext] || 'application/octet-stream' });
        fs.createReadStream(filePath).pipe(res);
      } else {
        res.writeHead(404);
        res.end('Not Found');
      }
    });
    server.listen(port, () => resolve(server));
  });
}

async function test() {
  const server = await startStaticServer(PROMO_DIR, 8399);

  const tempDir = path.resolve('promo/dist/test_chrome_log');
  const chromeArgs = [
    '--headless=new',
    '--remote-debugging-port=9466',
    '--window-size=3840,2160',
    '--force-device-scale-factor=1',
    '--enable-logging=stderr',
    '--v=1',
    `--user-data-dir=${tempDir}`,
    'http://127.0.0.1:8399/index.html'
  ];

  const proc = spawn(CHROME_PATH, chromeArgs);
  proc.stdout.on('data', d => console.log('[Chrome out]:', d.toString()));
  proc.stderr.on('data', d => console.log('[Chrome err]:', d.toString()));

  await new Promise(r => setTimeout(r, 2000));

  const jsonRes = await fetch('http://127.0.0.1:9466/json');
  const targets = await jsonRes.json();
  const page = targets.find(t => t.type === 'page');

  const ws = new WebSocket(page.webSocketDebuggerUrl);
  await new Promise(r => ws.onopen = r);

  let reqId = 1;
  const cbs = new Map();
  ws.onmessage = (e) => {
    const msg = JSON.parse(e.data);
    if (msg.method === 'Runtime.consoleAPICalled') {
      console.log('  [Console]:', msg.params.args);
    } else if (msg.method === 'Runtime.exceptionThrown') {
      console.log('  [Exception]:', msg.params.exceptionDetails);
    }
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
  await send('Emulation.setDeviceMetricsOverride', { width: 3840, height: 2160, deviceScaleFactor: 1, mobile: false });

  console.log('Testing seek 4500 in browser...');
  const res1 = await send('Runtime.evaluate', {
    expression: `
      (() => {
        try {
          window.setSeekFrame(4500);
          return "SEEK_OK";
        } catch (e) {
          return "ERR: " + e.stack;
        }
      })()
    `,
    returnByValue: true
  });
  console.log('Result of seek 4500:', res1);

  console.log('Testing canvas toDataURL on frame 4500...');
  const res2 = await send('Runtime.evaluate', {
    expression: `
      (() => {
        try {
          const c = document.getElementById('promoCanvas');
          const data = c.toDataURL('image/jpeg', 0.9);
          return "URL_OK, length: " + data.length;
        } catch (e) {
          return "ERR: " + e.stack;
        }
      })()
    `,
    returnByValue: true
  });
  console.log('Result of toDataURL:', res2);

  ws.close();
  proc.kill();
  server.close();
}

test().catch(console.error);
