import { spawn } from 'node:child_process';
import path from 'node:path';
import fs from 'node:fs';
import http from 'node:http';

const CHROME_PATH = 'C:/Program Files/Google/Chrome/Application/chrome.exe';
const PROMO_DIR = path.resolve('promo');

function startStaticServer(dir, port) {
  const mimeTypes = {
    '.html': 'text/html; charset=utf-8',
    '.css': 'text/css; charset=utf-8',
    '.js': 'application/javascript; charset=utf-8',
    '.png': 'image/png',
    '.jpg': 'image/jpeg',
    '.wav': 'audio/wav',
    '.ico': 'image/x-icon'
  };

  return new Promise((resolve) => {
    const server = http.createServer((req, res) => {
      let reqPath = req.url.split('?')[0];
      if (reqPath === '/') reqPath = '/presentation.html';
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

async function testCapture() {
  const server = await startStaticServer(PROMO_DIR, 8333);
  const tempDir = path.resolve('promo/dist/chrome_test_profile');
  if (!fs.existsSync(tempDir)) fs.mkdirSync(tempDir, { recursive: true });

  const chromeProc = spawn(CHROME_PATH, [
    '--headless=new',
    '--remote-debugging-port=9444',
    '--window-size=1920,1080',
    '--force-device-scale-factor=1',
    '--enable-gpu',
    '--no-first-run',
    `--user-data-dir=${tempDir}`,
    'http://127.0.0.1:8333/presentation.html?video=1'
  ], { stdio: 'ignore' });

  // Wait for Chrome debugging port
  let wsUrl = null;
  for (let i = 0; i < 30; i++) {
    await new Promise(r => setTimeout(r, 200));
    try {
      const res = await fetch('http://127.0.0.1:9444/json');
      const targets = await res.json();
      const page = targets.find(t => t.type === 'page');
      if (page && page.webSocketDebuggerUrl) {
        wsUrl = page.webSocketDebuggerUrl;
        break;
      }
    } catch (e) {}
  }

  if (!wsUrl) {
    chromeProc.kill();
    server.close();
    throw new Error('Chrome did not open CDP port');
  }

  console.log('Connected to Chrome WebSocket:', wsUrl);
  const ws = new WebSocket(wsUrl);
  await new Promise(r => ws.onopen = r);

  let id = 1;
  const send = (method, params = {}) => new Promise((resolve) => {
    const curId = id++;
    const handler = (evt) => {
      const msg = JSON.parse(evt.data);
      if (msg.id === curId) {
        ws.removeEventListener('message', handler);
        resolve(msg.result);
      }
    };
    ws.addEventListener('message', handler);
    ws.send(JSON.stringify({ id: curId, method, params }));
  });

  await send('Page.enable');
  await send('Runtime.enable');
  await send('Emulation.setDeviceMetricsOverride', {
    width: 1920,
    height: 1080,
    deviceScaleFactor: 1,
    mobile: false
  });

  // Wait a moment for page to stabilize
  await new Promise(r => setTimeout(r, 1200));

  // Test seeking to chapter 2 zoom wizard card
  console.log('Testing seekPresentationTime(22.0)...');
  await send('Runtime.evaluate', {
    expression: 'window.seekPresentationTime(22.0)',
    returnByValue: true
  });
  await new Promise(r => setTimeout(r, 500));

  console.log('Capturing test screenshot at 22.0s...');
  const shot = await send('Page.captureScreenshot', { format: 'jpeg', quality: 95 });
  const buf = Buffer.from(shot.data, 'base64');
  const outPath = path.resolve('promo/dist/test_capture_zoom_ch2.jpg');
  fs.writeFileSync(outPath, buf);
  console.log('Test screenshot saved to:', outPath, `(${buf.length} bytes)`);

  // Test seeking to chapter 3 mouse
  console.log('Testing seekPresentationTime(36.0)...');
  await send('Runtime.evaluate', {
    expression: 'window.seekPresentationTime(36.0)',
    returnByValue: true
  });
  await new Promise(r => setTimeout(r, 500));

  const shot2 = await send('Page.captureScreenshot', { format: 'jpeg', quality: 95 });
  const buf2 = Buffer.from(shot2.data, 'base64');
  const outPath2 = path.resolve('promo/dist/test_capture_mouse_ch3.jpg');
  fs.writeFileSync(outPath2, buf2);
  console.log('Test screenshot saved to:', outPath2, `(${buf2.length} bytes)`);

  ws.close();
  chromeProc.kill();
  server.close();
}

testCapture().catch(console.error);
