import http from 'node:http';
import { spawn } from 'node:child_process';
import path from 'node:path';
import fs from 'node:fs';

const FFMPEG_PATH = 'E:/Program Files (x86)/JianyingPro/11.5.0.14471/ffmpeg.exe';
const CHROME_PATH = 'C:/Program Files/Google/Chrome/Application/chrome.exe';

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
}).listen(8769, async () => {
  console.log('Testing Pipe NVENC Pipeline...');
  const outMp4 = path.resolve('promo/dist/test_sample_nvenc.mp4');
  
  const ffmpeg = spawn(FFMPEG_PATH, [
    '-y',
    '-f', 'image2pipe',
    '-vcodec', 'mjpeg',
    '-r', '60',
    '-i', '-',
    '-c:v', 'h264_nvenc',
    '-preset', 'p6',
    '-b:v', '30M',
    '-pix_fmt', 'yuv420p',
    outMp4
  ]);

  ffmpeg.stderr.on('data', d => {
    // console.log('[ffmpeg]:', d.toString());
  });

  const chrome = spawn(CHROME_PATH, [
    '--headless=new',
    '--remote-debugging-port=9880',
    '--window-size=3840,2160',
    '--enable-gpu',
    '--use-gl=angle',
    '--use-angle=d3d11',
    '--user-data-dir=' + path.resolve('promo/dist/u_' + Date.now()),
    'http://127.0.0.1:8769/index.html'
  ]);

  for (let i = 0; i < 30; i++) {
    await new Promise(r => setTimeout(r, 200));
    try {
      const r = await fetch('http://127.0.0.1:9880/json');
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

        for (let w = 0; w < 50; w++) {
          const chk = await send('Runtime.evaluate', {
            expression: "typeof window.setSeekFrame === 'function'",
            returnByValue: true
          });
          if (chk.result.value === true) break;
          await new Promise(r => setTimeout(r, 50));
        }

        console.log('Rendering 120 frames directly into FFmpeg NVENC stdin...');
        const t0 = Date.now();
        for (let f = 0; f < 120; f++) {
          await send('Runtime.evaluate', { expression: `window.setSeekFrame(${f})` });
          const evalRes = await send('Runtime.evaluate', {
            expression: "document.getElementById('promoCanvas').toDataURL('image/jpeg', 0.95)",
            returnByValue: true
          });
          const b64 = evalRes.result.value.slice(23);
          const buf = Buffer.from(b64, 'base64');
          ffmpeg.stdin.write(buf);
          if (f % 30 === 0) process.stdout.write(`  Rendered & Piped: ${f}/120 frames\r`);
        }
        console.log(`\n120 frames piped in ${(Date.now() - t0) / 1000}s (${(120 / ((Date.now() - t0) / 1000)).toFixed(1)} fps)`);

        ffmpeg.stdin.end();
        await new Promise(res => ffmpeg.on('close', res));
        console.log('FFmpeg finished! Output size:', fs.statSync(outMp4).size);

        ws.close();
        chrome.kill();
        server.close();
        process.exit(0);
      }
    } catch(e) {}
  }
});
