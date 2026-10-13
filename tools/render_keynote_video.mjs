/**
 * FerrisPulse 2.0 · Official Keynote Broadcast Video Renderer
 * 
 * Hardware Accelerated End-to-End Pipeline:
 * - Headless Chrome 1920x1080 @ 30fps
 * - Deterministic frame-by-frame time seeking (window.seekPresentationTime)
 * - Real-time MJPEG memory pipe direct into FFmpeg
 * - NVIDIA NVENC Hardware Video Encoding (RTX 5070 Laptop)
 * - Merges bespoke 44.1kHz stereo orchestral electronic BGM
 * - Output: promo/FerrisPulse_2.0_Keynote_Presentation.mp4
 */

import { spawn } from 'node:child_process';
import path from 'node:path';
import fs from 'node:fs';
import http from 'node:http';

const CHROME_PATH = 'C:/Program Files/Google/Chrome/Application/chrome.exe';
const FFMPEG_PATH = 'E:/Program Files (x86)/JianyingPro/11.5.0.14471/ffmpeg.exe';
const PROMO_DIR = path.resolve('promo');
const OUTPUT_VIDEO = path.resolve('promo/FerrisPulse_2.0_Keynote_Presentation.mp4');
const BGM_AUDIO = path.resolve('promo/custom_keynote_bgm.wav');

const FPS = 30;
const DURATION_SEC = 88.0;
const TOTAL_FRAMES = Math.floor(DURATION_SEC * FPS); // 2640 frames
const PORT_HTTP = 8444;
const PORT_CDP = 9555;

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

async function main() {
  console.log('================================================================');
  console.log(' FerrisPulse 2.0 · Keynote Presentation Video Broadcast Pipeline ');
  console.log('================================================================');
  console.log(`Resolution   : 1920 × 1080 (Full HD 16:9, Pure Clean Mode)`);
  console.log(`Framerate    : ${FPS} FPS | Duration: ${DURATION_SEC}s | Total Frames: ${TOTAL_FRAMES}`);
  console.log(`Audio Track  : ${BGM_AUDIO}`);
  console.log(`Target Video : ${OUTPUT_VIDEO}`);
  console.log('----------------------------------------------------------------');

  if (!fs.existsSync(BGM_AUDIO)) {
    throw new Error(`BGM audio track not found: ${BGM_AUDIO}. Run tools/generate_keynote_bgm.mjs first!`);
  }

  // 1. Start Local Static Server
  console.log(`[1/4] Starting local static server on port ${PORT_HTTP}...`);
  const server = await startStaticServer(PROMO_DIR, PORT_HTTP);

  // 2. Launch Hardware-Accelerated Headless Chrome
  console.log(`[2/4] Launching headless Chrome on port ${PORT_CDP}...`);
  const tempProfile = path.resolve(`promo/dist/chrome_render_profile_${Date.now()}`);
  if (!fs.existsSync(tempProfile)) fs.mkdirSync(tempProfile, { recursive: true });

  const chromeProc = spawn(CHROME_PATH, [
    '--headless=new',
    `--remote-debugging-port=${PORT_CDP}`,
    '--window-size=1920,1080',
    '--force-device-scale-factor=1',
    '--enable-gpu',
    '--enable-gpu-rasterization',
    '--use-gl=angle',
    '--use-angle=d3d11',
    '--ignore-gpu-blocklist',
    '--disable-gpu-vsync',
    '--no-first-run',
    `--user-data-dir=${tempProfile}`,
    `http://127.0.0.1:${PORT_HTTP}/presentation.html?video=1`
  ], { stdio: 'ignore' });

  // Connect to Chrome CDP WebSocket
  let wsUrl = null;
  for (let i = 0; i < 40; i++) {
    await new Promise(r => setTimeout(r, 200));
    try {
      const res = await fetch(`http://127.0.0.1:${PORT_CDP}/json`);
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
    throw new Error('[CDP] Failed to connect to Chrome debugging WebSocket.');
  }

  console.log(`[CDP] Connected: ${wsUrl}`);
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

  // Warmup page & wait for all assets to load
  console.log('[CDP] Warming up stage and caching texture assets...');
  await new Promise(r => setTimeout(r, 1500));

  // 3. Launch FFmpeg NVENC Hardware Encoding Pipeline
  console.log('[3/4] Initializing FFmpeg NVIDIA NVENC pipeline...');
  const ffmpegArgs = [
    '-y',
    '-f', 'image2pipe',
    '-vcodec', 'mjpeg',
    '-r', String(FPS),
    '-i', '-',
    '-i', BGM_AUDIO,
    '-c:v', 'h264_nvenc',
    '-preset', 'p6',
    '-b:v', '25M',
    '-maxrate', '35M',
    '-bufsize', '35M',
    '-pix_fmt', 'yuv420p',
    '-c:a', 'aac',
    '-b:a', '320k',
    '-movflags', '+faststart',
    '-shortest',
    OUTPUT_VIDEO
  ];

  const ffmpeg = spawn(FFMPEG_PATH, ffmpegArgs);
  let ffmpegErr = '';
  ffmpeg.stderr.on('data', d => { ffmpegErr += d.toString(); });

  const startTime = Date.now();
  console.log('[4/4] Starting frame-by-frame rendering and encoding...');

  try {
    for (let f = 0; f < TOTAL_FRAMES; f++) {
      const timeSec = f / FPS;

      // Deterministic timeline seek
      await send('Runtime.evaluate', {
        expression: `window.seekPresentationTime(${timeSec.toFixed(4)})`,
        returnByValue: true
      });

      // Capture lossless JPEG frame at 92% quality
      const shot = await send('Page.captureScreenshot', { format: 'jpeg', quality: 92 });
      const frameBuf = Buffer.from(shot.data, 'base64');

      // Pipe into FFmpeg stdin
      const canWrite = ffmpeg.stdin.write(frameBuf);
      if (!canWrite) {
        await new Promise(r => ffmpeg.stdin.once('drain', r));
      }

      // Progress reporting every 60 frames (2 seconds)
      if (f % 60 === 0 || f === TOTAL_FRAMES - 1) {
        const elapsedSec = (Date.now() - startTime) / 1000;
        const currentFps = (f + 1) / (elapsedSec || 0.001);
        const remainingSec = (TOTAL_FRAMES - f - 1) / (currentFps || 1);
        const progressPct = ((f / TOTAL_FRAMES) * 100).toFixed(1);
        process.stdout.write(`  [${progressPct}%] Frame ${f}/${TOTAL_FRAMES} (${timeSec.toFixed(1)}s) | ${currentFps.toFixed(1)} FPS | ETA: ${(remainingSec / 60).toFixed(1)}m\r`);
      }
    }

    console.log(`\n[FFmpeg] All ${TOTAL_FRAMES} frames successfully written in ${((Date.now() - startTime) / 1000).toFixed(1)}s.`);
    ffmpeg.stdin.end();

    await new Promise((resolve, reject) => {
      ffmpeg.on('close', code => {
        if (code === 0) resolve();
        else reject(new Error(`FFmpeg exited with code ${code}:\n${ffmpegErr}`));
      });
      ffmpeg.on('error', reject);
    });

    const stat = fs.statSync(OUTPUT_VIDEO);
    console.log('================================================================');
    console.log(`✅ VIDEO RENDERING COMPLETE!`);
    console.log(`File: ${OUTPUT_VIDEO}`);
    console.log(`Size: ${(stat.size / 1024 / 1024).toFixed(2)} MB`);
    console.log('================================================================');

  } finally {
    ws.close();
    chromeProc.kill();
    server.close();
    // Clean up temp chrome profile
    try { fs.rmSync(tempProfile, { recursive: true, force: true }); } catch (e) {}
  }
}

main().catch(err => {
  console.error('[Render Error]:', err);
  process.exit(1);
});
