import { spawn } from 'node:child_process';
import path from 'node:path';
import fs from 'node:fs';
import http from 'node:http';
import os from 'node:os';
import { PromoAudioEngine } from '../promo/audio.js';

const FFMPEG_PATH = 'E:/Program Files (x86)/JianyingPro/11.5.0.14471/ffmpeg.exe';
const CHROME_PATH = 'C:/Program Files/Google/Chrome/Application/chrome.exe';
const PROMO_DIR = path.resolve('promo');
const DIST_DIR = path.resolve('promo/dist');
const CHUNKS_DIR = path.resolve('promo/dist/chunks');

if (!fs.existsSync(DIST_DIR)) fs.mkdirSync(DIST_DIR, { recursive: true });
if (!fs.existsSync(CHUNKS_DIR)) fs.mkdirSync(CHUNKS_DIR, { recursive: true });

// Parse CLI worker count & frames or default based on RTX 5070 Laptop + Core Ultra 9 275HX
const workerArgIndex = process.argv.indexOf('--workers');
const NUM_WORKERS = workerArgIndex !== -1 ? parseInt(process.argv[workerArgIndex + 1], 10) : 8;
const framesArgIndex = process.argv.indexOf('--frames');
const TOTAL_FRAMES = framesArgIndex !== -1 ? parseInt(process.argv[framesArgIndex + 1], 10) : 5100;
const FPS = 60;
const SERVER_PORT = 8299;

function startStaticServer(dir, port) {
  const mimeTypes = {
    '.html': 'text/html; charset=utf-8',
    '.css': 'text/css; charset=utf-8',
    '.js': 'application/javascript; charset=utf-8',
    '.png': 'image/png',
    '.jpg': 'image/jpeg',
    '.wav': 'audio/wav'
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

class DedicatedChromeWorker {
  constructor(workerId, port) {
    this.id = workerId;
    this.port = port;
    this.ws = null;
    this.chromeProc = null;
    this.reqId = 1;
    this.pendingCallbacks = new Map();
    this.tempDir = path.resolve(`promo/dist/chrome_profile_w${workerId}_${Date.now()}`);
  }

  async launch(targetUrl) {
    if (!fs.existsSync(this.tempDir)) fs.mkdirSync(this.tempDir, { recursive: true });

    const chromeArgs = [
      '--headless=new',
      `--remote-debugging-port=${this.port}`,
      '--window-size=3840,2160',
      '--force-device-scale-factor=1',
      '--enable-gpu',
      '--enable-gpu-rasterization',
      '--use-gl=angle',
      '--use-angle=d3d11',
      '--ignore-gpu-blocklist',
      '--disable-gpu-vsync',
      '--disable-background-timer-throttling',
      '--no-first-run',
      `--user-data-dir=${this.tempDir}`,
      targetUrl
    ];

    this.chromeProc = spawn(CHROME_PATH, chromeArgs, { stdio: 'ignore' });

    let wsUrl = null;
    for (let i = 0; i < 40; i++) {
      await new Promise(r => setTimeout(r, 150));
      try {
        const json = await this._httpGet(`http://127.0.0.1:${this.port}/json`);
        const targets = JSON.parse(json);
        const pageTarget = targets.find(t => t.type === 'page');
        if (pageTarget && pageTarget.webSocketDebuggerUrl) {
          wsUrl = pageTarget.webSocketDebuggerUrl;
          break;
        }
      } catch (e) {}
    }

    if (!wsUrl) throw new Error(`[Worker ${this.id}] Failed to connect to CDP on port ${this.port}`);
    await this._connectWs(wsUrl);

    await this.send('Page.enable');
    await this.send('Runtime.enable');
    await this.send('Emulation.setDeviceMetricsOverride', {
      width: 3840,
      height: 2160,
      deviceScaleFactor: 1,
      mobile: false
    });

    // Wait until PromoRenderer is ready
    for (let w = 0; w < 60; w++) {
      const chk = await this.evaluate(`typeof window.setSeekFrame === 'function'`);
      if (chk === true) break;
      await new Promise(r => setTimeout(r, 50));
    }

    await this.evaluate(`document.body.classList.add('recording-mode')`);
  }

  _httpGet(url) {
    return new Promise((resolve, reject) => {
      http.get(url, res => {
        let data = '';
        res.on('data', chunk => data += chunk);
        res.on('end', () => resolve(data));
      }).on('error', reject);
    });
  }

  _connectWs(url) {
    return new Promise((resolve, reject) => {
      this.ws = new WebSocket(url);
      this.ws.onopen = () => resolve();
      this.ws.onerror = reject;
      this.ws.onmessage = (event) => {
        const msg = JSON.parse(event.data);
        if (msg.id && this.pendingCallbacks.has(msg.id)) {
          const { res, rej } = this.pendingCallbacks.get(msg.id);
          this.pendingCallbacks.delete(msg.id);
          if (msg.error) rej(msg.error);
          else res(msg.result);
        }
      };
    });
  }

  send(method, params = {}) {
    return new Promise((resolve, reject) => {
      const id = this.reqId++;
      this.pendingCallbacks.set(id, { res: resolve, rej: reject });
      this.ws.send(JSON.stringify({ id, method, params }));
    });
  }

  async evaluate(expression) {
    const res = await this.send('Runtime.evaluate', {
      expression,
      awaitPromise: true,
      returnByValue: true
    });
    return res.result ? res.result.value : null;
  }

  async captureFrameJpeg(quality = 0.95) {
    const dataUrl = await this.evaluate(`document.getElementById('promoCanvas').toDataURL('image/jpeg', ${quality})`);
    if (!dataUrl) throw new Error(`[Worker ${this.id}] Failed to capture canvas`);
    return Buffer.from(dataUrl.slice(23), 'base64');
  }

  async close() {
    if (this.ws) {
      try { this.ws.close(); } catch (e) {}
    }
    if (this.chromeProc) {
      try { this.chromeProc.kill('SIGKILL'); } catch (e) {}
    }
    // Clean temp profile
    try {
      fs.rmSync(this.tempDir, { recursive: true, force: true });
    } catch (e) {}
  }
}

async function renderChunk(worker, startFrame, endFrame, outputPath, onProgress) {
  const frameCount = endFrame - startFrame;
  const ffmpegArgs = [
    '-y',
    '-f', 'image2pipe',
    '-vcodec', 'mjpeg',
    '-r', String(FPS),
    '-i', '-',
    '-c:v', 'h264_nvenc',
    '-preset', 'p6',
    '-b:v', '35M',
    '-maxrate', '50M',
    '-bufsize', '50M',
    '-pix_fmt', 'yuv420p',
    outputPath
  ];

  const ffmpeg = spawn(FFMPEG_PATH, ffmpegArgs);
  let ffmpegErr = '';
  ffmpeg.stderr.on('data', d => ffmpegErr += d.toString());

  return new Promise(async (resolve, reject) => {
    ffmpeg.on('error', reject);
    ffmpeg.on('close', code => {
      if (code === 0) resolve();
      else reject(new Error(`Worker ${worker.id} FFmpeg exited with code ${code}: ${ffmpegErr}`));
    });

    try {
      for (let f = startFrame; f < endFrame; f++) {
        await worker.evaluate(`window.setSeekFrame(${f})`);
        const jpgBuf = await worker.captureFrameJpeg(0.95);
        ffmpeg.stdin.write(jpgBuf);
        onProgress(1);
      }
      ffmpeg.stdin.end();
    } catch (err) {
      ffmpeg.kill();
      reject(err);
    }
  });
}

async function main() {
  console.log('╔════════════════════════════════════════════════════════════════════════════╗');
  console.log('║   FerrisPulse v2.0 Launch Video — Extreme Parallel Multi-Worker Renderer   ║');
  console.log('║   Architecture: Intel Ultra 9 275HX (24C) + RTX 5070 Laptop (Blackwell)    ║');
  console.log('╚════════════════════════════════════════════════════════════════════════════╝');
  console.log(`Parallel Workers: ${NUM_WORKERS} | Target: 4K 60FPS UHD (3840x2160, 5100 frames)`);

  const startTime = Date.now();

  // 1. Audio Master Generation
  const audioDuration = Math.max(1.0, TOTAL_FRAMES / FPS);
  console.log(`\n[1/4] Generating 44.1kHz Stereo PCM Master Audio (${audioDuration.toFixed(1)}s)...`);
  const audioEngine = new PromoAudioEngine();
  const wavBuffer = await audioEngine.generatePromoAudioWav(audioDuration, 44100);
  const masterAudioPath = path.join(DIST_DIR, 'promo_audio_master.wav');
  fs.writeFileSync(masterAudioPath, Buffer.from(wavBuffer));
  console.log(`✓ Audio master ready: ${masterAudioPath}`);

  // 2. Shared Static HTTP Server
  console.log(`\n[2/4] Starting local static server on port ${SERVER_PORT}...`);
  const server = await startStaticServer(PROMO_DIR, SERVER_PORT);

  // 3. Launch N Workers
  console.log(`\n[3/4] Launching ${NUM_WORKERS} hardware-accelerated Chrome workers concurrently...`);
  const workers = [];
  const chunkRanges = [];
  const framesPerWorker = Math.ceil(TOTAL_FRAMES / NUM_WORKERS);

  for (let i = 0; i < NUM_WORKERS; i++) {
    const sFrame = i * framesPerWorker;
    const eFrame = Math.min(TOTAL_FRAMES, (i + 1) * framesPerWorker);
    chunkRanges.push({ id: i, start: sFrame, end: eFrame, count: eFrame - sFrame });
    workers.push(new DedicatedChromeWorker(i, 9400 + i));
  }

  await Promise.all(workers.map(w => w.launch(`http://127.0.0.1:${SERVER_PORT}/index.html`)));
  console.log(`✓ All ${NUM_WORKERS} workers connected and synchronized to 3840x2160 viewport.`);

  // 4. Concurrent Chunk Rendering
  console.log('\n[4/4] Commencing parallel NVENC stream encoding...');
  let totalRenderedFrames = 0;
  const chunkFiles = [];

  const progressInterval = setInterval(() => {
    const elapsedSec = (Date.now() - startTime) / 1000;
    const overallFps = totalRenderedFrames / (elapsedSec || 0.001);
    const percent = ((totalRenderedFrames / TOTAL_FRAMES) * 100).toFixed(1);
    const remainingFrames = TOTAL_FRAMES - totalRenderedFrames;
    const etaSec = remainingFrames / (overallFps || 1);
    process.stdout.write(`  ⚡ [${percent}%] ${totalRenderedFrames}/${TOTAL_FRAMES} Frames | Rate: ${overallFps.toFixed(1)} FPS | ETA: ${etaSec.toFixed(1)}s    \r`);
  }, 250);

  try {
    const renderPromises = chunkRanges.map(chunk => {
      const chunkPath = path.join(CHUNKS_DIR, `chunk_${String(chunk.id).padStart(2, '0')}.mp4`);
      chunkFiles.push(chunkPath);
      return renderChunk(workers[chunk.id], chunk.start, chunk.end, chunkPath, (inc) => {
        totalRenderedFrames += inc;
      });
    });

    await Promise.all(renderPromises);
    clearInterval(progressInterval);
    console.log(`\n✓ All ${NUM_WORKERS} chunks successfully rendered in ${((Date.now() - startTime) / 1000).toFixed(1)}s!`);

  } finally {
    clearInterval(progressInterval);
    await Promise.all(workers.map(w => w.close()));
    server.close();
  }

  // 5. Lossless Stream Concatenation & Audio Muxing (< 1s)
  console.log('\n[Assembly] Performing zero-loss hardware stream stitching & audio muxing...');
  const concatListPath = path.join(CHUNKS_DIR, 'concat_list.txt');
  const concatContent = chunkFiles.map(f => `file '${f.replace(/\\/g, '/')}'`).join('\n');
  fs.writeFileSync(concatListPath, concatContent);

  const finalOutputPath = path.resolve('promo/FerrisPulse_v2.0_Launch_4K_Extreme.mp4');
  const assembleArgs = [
    '-y',
    '-f', 'concat',
    '-safe', '0',
    '-i', concatListPath,
    '-i', masterAudioPath,
    '-c:v', 'copy',
    '-c:a', 'aac_mf',
    '-b:a', '320k',
    '-shortest',
    finalOutputPath
  ];

  await new Promise((resolve, reject) => {
    const assemble = spawn(FFMPEG_PATH, assembleArgs);
    assemble.on('close', code => {
      if (code === 0) resolve();
      else reject(new Error(`FFmpeg concat exited with code ${code}`));
    });
  });

  // Clean chunk files
  try {
    fs.rmSync(CHUNKS_DIR, { recursive: true, force: true });
  } catch (e) {}

  const totalElapsedSec = (Date.now() - startTime) / 1000;
  const avgFps = TOTAL_FRAMES / totalElapsedSec;

  console.log('\n╔════════════════════════════════════════════════════════════════════════════╗');
  console.log('║                     EXTREME RENDER COMPLETED SUCCESSFULLY                  ║');
  console.log('╠════════════════════════════════════════════════════════════════════════════╣');
  console.log(`║ Output File:    ${finalOutputPath}`);
  console.log(`║ File Size:      ${(fs.statSync(finalOutputPath).size / 1024 / 1024).toFixed(2)} MB`);
  console.log(`║ Total Time:     ${totalElapsedSec.toFixed(1)}s (vs ~405s Single-thread)`);
  console.log(`║ Effective Rate: ${avgFps.toFixed(1)} FPS (${(avgFps / 12.6).toFixed(1)}x Real-world Speedup)`);
  console.log('╚════════════════════════════════════════════════════════════════════════════╝');
}

main().catch(err => {
  console.error('\n[Parallel Engine Error]:', err);
  process.exit(1);
});
