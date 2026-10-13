import http from 'node:http';
import { spawn } from 'node:child_process';
import path from 'node:path';
import fs from 'node:fs';

const server = http.createServer((req, res) => {
  let p = req.url.split('?')[0];
  if (p === '/') p = '/index.html';
  const fullPath = path.join(path.resolve('promo'), p);
  if (fs.existsSync(fullPath)) {
    const ext = path.extname(fullPath).toLowerCase();
    const mime = ext === '.html' ? 'text/html' : ext === '.js' ? 'application/javascript' : ext === '.css' ? 'text/css' : 'application/octet-stream';
    res.writeHead(200, { 'Content-Type': mime });
    fs.createReadStream(fullPath).pipe(res);
  } else {
    res.writeHead(404);
    res.end();
  }
}).listen(8766, async () => {
  const chrome = spawn('C:/Program Files/Google/Chrome/Application/chrome.exe', [
    '--headless=new',
    '--remote-debugging-port=9877',
    '--window-size=3840,2160',
    '--enable-gpu',
    '--use-gl=angle',
    '--use-angle=d3d11',
    '--user-data-dir=' + path.resolve('promo/dist/u_' + Date.now()),
    'http://127.0.0.1:8766/index.html'
  ]);

  for (let i = 0; i < 30; i++) {
    await new Promise(r => setTimeout(r, 200));
    try {
      const r = await fetch('http://127.0.0.1:9877/json');
      const list = await r.json();
      const page = list.find(x => x.type === 'page');
      if (page) {
        const ws = new WebSocket(page.webSocketDebuggerUrl);
        await new Promise(res => ws.onopen = res);

        let id = 1;
        const send = (method, params = {}) => new Promise((res, rej) => {
          const curId = id++;
          const handler = (e) => {
            const m = JSON.parse(e.data);
            if (m.id === curId) {
              ws.removeEventListener('message', handler);
              if (m.error) rej(m.error); else res(m.result);
            }
          };
          ws.addEventListener('message', handler);
          ws.send(JSON.stringify({ id: curId, method, params }));
        });

        await send('Page.enable');
        await send('Runtime.enable');
        await send('Emulation.setDeviceMetricsOverride', { width: 3840, height: 2160, deviceScaleFactor: 1, mobile: false });

        for (const f of [4700, 5050]) {
          await send('Runtime.evaluate', { expression: `window.setSeekFrame(${f})` });
          const evalRes = await send('Runtime.evaluate', {
            expression: "document.getElementById('promoCanvas').toDataURL('image/jpeg', 0.95)",
            returnByValue: true
          });
          const b64 = evalRes.result.value.replace(/^data:image\/jpeg;base64,/, '');
          fs.writeFileSync(`promo/dist/preview_frame_${f}.jpg`, Buffer.from(b64, 'base64'));
          console.log(`Saved preview_frame_${f}.jpg!`);
        }

        ws.close();
        chrome.kill();
        server.close();
        process.exit(0);
      }
    } catch (e) {}
  }
});
