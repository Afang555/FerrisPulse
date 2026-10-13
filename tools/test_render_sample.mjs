import { spawn } from 'node:child_process';
import path from 'node:path';
import fs from 'node:fs';
import http from 'node:http';

const CHROME_PATH = 'C:/Program Files/Google/Chrome/Application/chrome.exe';
const FFMPEG_PATH = 'E:/Program Files (x86)/JianyingPro/11.5.0.14471/ffmpeg.exe';
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

async function testRenderSample() {
  const server = await startStaticServer(PROMO_DIR, 8336);
  const tempDir = path.resolve('promo/dist/chrome_sample_profile');
  if (!fs.existsSync(tempDir)) fs.mkdirSync(tempDir, { recursive: true });

  const chromeProc = spawn(CHROME_PATH, [
    '--headless=new',
    '--remote-debugging-port=9447',
    '--window-size=1920,1080',
    '--force-device-scale-factor=1',
    '--enable-gpu',
    '--no-first-run',
    `--user-data-dir=${tempDir}`,
    'http://127.0.0.1:8336/presentation.html?video=1'
  ], { stdio: 'ignore' });

  let wsUrl = null;
  for (let i = 0; i < 30; i++) {
    await new Promise(r => setTimeout(r, 200));
    try {
      const res = await fetch('http://127.0.0.1:9447/json');
      const targets = await res.json();
      const page = targets.find(t => t.type === 'page');
      if (page && page.webSocketDebuggerUrl) {
        wsUrl = page.webSocketDebuggerUrl;
        break;
      }
    } catch (e) {}
  }

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

  await new Promise(r => setTimeout(r, 1000));

  const fps = 30;
  const totalFrames = 150; // 5 seconds
  const sampleMp4 = path.resolve('promo/dist/sample_5s.mp4');

  const ffmpegArgs = [
    '-y',
    '-f', 'image2pipe',
    '-vcodec', 'mjpeg',
    '-r', String(fps),
    '-i', '-',
    '-c:v', 'h264_nvenc',
    '-preset', 'p6',
    '-b:v', '20M',
    '-pix_fmt', 'yuv420p',
    sampleMp4
  ];

  console.log('Launching FFmpeg NVENC for 5s sample...');
  const ffmpeg = spawn(FFMPEG_PATH, ffmpegArgs);

  for (let f = 0; f < totalFrames; f++) {
    const t = 20.0 + (f / fps); // testing around 20s - 25s (Ecosystem Matrix zoom!)
    await send('Runtime.evaluate', {
      expression: `window.seekPresentationTime(${t})`,
      returnByValue: true
    });
    const shot = await send('Page.captureScreenshot', { format: 'jpeg', quality: 90 });
    const buf = Buffer.from(shot.data, 'base64');
    ffmpeg.stdin.write(buf);
  }

  ffmpeg.stdin.end();

  await new Promise(resolve => ffmpeg.on('close', resolve));
  console.log('Sample video completed:', sampleMp4);

  ws.close();
  chromeProc.kill();
  server.close();
}

testRenderSample().catch(console.error);
