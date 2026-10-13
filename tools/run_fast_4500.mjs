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
}).listen(8765, async () => {
  console.log('HTTP 8765 ready');
  const chrome = spawn('C:/Program Files/Google/Chrome/Application/chrome.exe', [
    '--headless=new',
    '--remote-debugging-port=9876',
    '--window-size=3840,2160',
    '--enable-gpu',
    '--use-gl=angle',
    '--use-angle=d3d11',
    '--user-data-dir=' + path.resolve('promo/dist/u_' + Date.now()),
    'http://127.0.0.1:8765/index.html'
  ]);

  for (let i = 0; i < 30; i++) {
    await new Promise(r => setTimeout(r, 200));
    try {
      const r = await fetch('http://127.0.0.1:9876/json');
      const list = await r.json();
      const page = list.find(x => x.type === 'page');
      if (page) {
        console.log('Page found:', page.webSocketDebuggerUrl);
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

        console.log('Seeking to 4500...');
        await send('Runtime.evaluate', { expression: 'window.setSeekFrame(4500)' });
        console.log('Getting DataURL...');
        const evalRes = await send('Runtime.evaluate', {
          expression: "document.getElementById('promoCanvas').toDataURL('image/jpeg', 0.95)",
          returnByValue: true
        });
        const len = evalRes.result.value.length;
        console.log('Success! DataURL length:', len);

        const b64 = evalRes.result.value.replace(/^data:image\/jpeg;base64,/, '');
        fs.writeFileSync('promo/dist/preview_05_Act4_Aurora_Poem_Ferris_OldG_4500.jpg', Buffer.from(b64, 'base64'));
        console.log('Saved preview_05_Act4_Aurora_Poem_Ferris_OldG_4500.jpg!');

        ws.close();
        chrome.kill();
        server.close();
        process.exit(0);
      }
    } catch (e) {}
  }
});
