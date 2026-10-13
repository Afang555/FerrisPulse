import { spawn } from 'node:child_process';
import path from 'node:path';
import fs from 'node:fs';
import http from 'node:http';
import { PromoAudioEngine } from '../promo/audio.js';

const FFMPEG_PATH = 'E:/Program Files (x86)/JianyingPro/11.5.0.14471/ffmpeg.exe';
const CHROME_PATH = 'C:/Program Files/Google/Chrome/Application/chrome.exe';
const PROMO_DIR = path.resolve('promo');
const DIST_DIR = path.resolve('promo/dist');
const FRAMES_DIR = path.resolve('promo/dist/frames');

if (!fs.existsSync(DIST_DIR)) fs.mkdirSync(DIST_DIR, { recursive: true });
if (!fs.existsSync(FRAMES_DIR)) fs.mkdirSync(FRAMES_DIR, { recursive: true });

const isPreview = process.argv.includes('--preview');
const isFull = process.argv.includes('--full') || !isPreview;

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

    server.listen(port, () => {
      resolve(server);
    });
  });
}

class ChromeCdpClient {
  constructor(port) {
    this.port = port;
    this.ws = null;
    this.chromeProc = null;
    this.reqId = 1;
    this.pendingCallbacks = new Map();
  }

  async launch(targetUrl) {
    console.log(`[CDP] Launching Hardware-Accelerated Chrome on port ${this.port}...`);
    const tempDir = path.resolve(`promo/dist/chrome_profile_${Date.now()}`);
    if (!fs.existsSync(tempDir)) fs.mkdirSync(tempDir, { recursive: true });

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
      `--user-data-dir=${tempDir}`,
      targetUrl
    ];

    this.chromeProc = spawn(CHROME_PATH, chromeArgs, { stdio: 'ignore' });

    let wsUrl = null;
    for (let i = 0; i < 40; i++) {
      await new Promise(r => setTimeout(r, 200));
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

    if (!wsUrl) {
      throw new Error(`[CDP] Failed to connect to Chrome debugging endpoint on port ${this.port}`);
    }

    console.log(`[CDP] Connecting to WebSocket: ${wsUrl}`);
    await this._connectWs(wsUrl);

    // Enable CDP domains
    await this.send('Page.enable');
    await this.send('Runtime.enable');
    await this.send('Emulation.setDeviceMetricsOverride', {
      width: 3840,
      height: 2160,
      deviceScaleFactor: 1,
      mobile: false
    });

    // Wait until window.setSeekFrame is fully initialized
    console.log('[CDP] Waiting for PromoRenderer module to load...');
    for (let w = 0; w < 60; w++) {
      const chk = await this.evaluate(`typeof window.setSeekFrame === 'function'`);
      if (chk === true) break;
      await new Promise(r => setTimeout(r, 50));
    }

    await this.evaluate(`document.body.classList.add('recording-mode')`);
    console.log('[CDP] Headless Chrome initialized at 3840x2160 with clean recording-mode.');
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
    if (!dataUrl) throw new Error('Failed to capture canvas dataURL');
    const b64 = dataUrl.slice(23); // strip 'data:image/jpeg;base64,'
    return Buffer.from(b64, 'base64');
  }

  async close() {
    if (this.ws) {
      try { this.ws.close(); } catch (e) {}
    }
    if (this.chromeProc) {
      try { this.chromeProc.kill('SIGKILL'); } catch (e) {}
    }
  }
}

async function main() {
  console.log('=== FerrisPulse v2.0 4K Video Pipeline (Direct NVENC Pipe) ===');
  console.log(`Mode: ${isPreview ? 'PREVIEW (Keyframes + 3s sample)' : 'FULL (5100 frames 85s @ 60fps)'}`);

  // 1. Generate Audio Master
  console.log('[1/4] Generating 44.1kHz stereo audio master...');
  const audioEngine = new PromoAudioEngine();
  const audioDuration = isPreview ? 3.0 : 85.0;
  const wavBuffer = await audioEngine.generatePromoAudioWav(audioDuration, 44100);
  const wavPath = path.join(DIST_DIR, 'promo_audio.wav');
  fs.writeFileSync(wavPath, Buffer.from(wavBuffer));
  console.log(`[1/4] Audio saved to ${wavPath} (${(wavBuffer.byteLength / 1024 / 1024).toFixed(2)} MB)`);

  // 2. Start Local Static HTTP Server
  const serverPort = 8199;
  console.log(`[2/4] Starting local HTTP static server on port ${serverPort}...`);
  const server = await startStaticServer(PROMO_DIR, serverPort);

  // 3. Launch Chrome CDP
  const cdp = new ChromeCdpClient(9333);
  await cdp.launch(`http://127.0.0.1:${serverPort}/index.html`);

  try {
    if (isPreview) {
      // Capture 5 Keyframes across the 5 acts
      const keyframes = [
        { frame: 100, desc: '01_Prologue_Shatter' },
        { frame: 750, desc: '02_Act1_Ecosystem_Cards' },
        { frame: 1950, desc: '03_Act2_SelfCrafted_UI' },
        { frame: 3200, desc: '04_Act3_8000Hz_Gaming_HUD' },
        { frame: 4700, desc: '05_Act4_Aurora_Poem_Ferris_OldG' }
      ];

      console.log('[3/4] Capturing 5 4K keyframe snapshots for visual verification...');
      for (const k of keyframes) {
        await cdp.evaluate(`window.setSeekFrame(${k.frame})`);
        const jpgBuf = await cdp.captureFrameJpeg(0.96);
        const framePath = path.join(DIST_DIR, `preview_${k.desc}_${String(k.frame).padStart(4, '0')}.jpg`);
        fs.writeFileSync(framePath, jpgBuf);
        console.log(`  Captured: ${path.basename(framePath)} (${(jpgBuf.length / 1024 / 1024).toFixed(2)} MB)`);
      }

      // Render 180 frames (3s 4K @ 60fps) piped directly to FFmpeg
      console.log('[4/4] Piped-rendering 180 frames (3s 4K @ 60fps) into FFmpeg NVENC...');
      const previewMp4 = path.join(DIST_DIR, 'preview_3s_4K.mp4');
      await renderPipedVideo(cdp, wavPath, previewMp4, 180, 60);
      console.log(`=== Preview Complete! File: ${previewMp4} ===`);

    } else {
      // FULL BROADCAST RUN: 5100 frames directly piped into NVENC
      console.log('[3/4] Piped-rendering all 5100 4K frames (85s @ 60fps) into NVIDIA NVENC...');
      const totalFrames = 5100;
      const finalMp4 = path.resolve('promo/FerrisPulse_v2.0_Launch_4K.mp4');
      await renderPipedVideo(cdp, wavPath, finalMp4, totalFrames, 60);
      console.log(`\n=== FULL 4K BROADCAST VIDEO COMPLETE! File: ${finalMp4} ===`);
    }

  } finally {
    await cdp.close();
    server.close();
  }
}

function renderPipedVideo(cdp, audioPath, outputPath, totalFrames, fps) {
  return new Promise(async (resolve, reject) => {
    const ffmpegArgs = [
      '-y',
      '-f', 'image2pipe',
      '-vcodec', 'mjpeg',
      '-r', String(fps),
      '-i', '-',
      '-i', audioPath,
      '-c:v', 'h264_nvenc',
      '-preset', 'p6',
      '-b:v', '35M',
      '-maxrate', '50M',
      '-bufsize', '50M',
      '-pix_fmt', 'yuv420p',
      '-c:a', 'aac_mf',
      '-b:a', '320k',
      '-shortest',
      outputPath
    ];

    console.log(`[FFmpeg NVENC] Launching hardware pipeline: ${path.basename(outputPath)}`);
    const ffmpeg = spawn(FFMPEG_PATH, ffmpegArgs);

    let ffmpegErr = '';
    ffmpeg.stderr.on('data', d => {
      ffmpegErr += d.toString();
    });

    ffmpeg.on('error', reject);

    const startTime = Date.now();

    try {
      for (let f = 0; f < totalFrames; f++) {
        await cdp.evaluate(`window.setSeekFrame(${f})`);
        const jpgBuf = await cdp.captureFrameJpeg(0.95);
        ffmpeg.stdin.write(jpgBuf);

        if (f % 60 === 0 || f === totalFrames - 1) {
          const elapsedSec = (Date.now() - startTime) / 1000;
          const fpsRate = (f + 1) / (elapsedSec || 0.001);
          const remainingSec = (totalFrames - f - 1) / (fpsRate || 1);
          process.stdout.write(`  [${(f / totalFrames * 100).toFixed(1)}%] Frame ${f}/${totalFrames} | ${fpsRate.toFixed(1)} FPS | ETA: ${(remainingSec / 60).toFixed(1)}m\r`);
        }
      }

      console.log(`\n  All ${totalFrames} frames dispatched in ${((Date.now() - startTime) / 1000).toFixed(1)}s.`);
      ffmpeg.stdin.end();

      ffmpeg.on('close', code => {
        if (code === 0) {
          resolve();
        } else {
          reject(new Error(`FFmpeg exited with code ${code}: ${ffmpegErr}`));
        }
      });

    } catch (err) {
      ffmpeg.kill();
      reject(err);
    }
  });
}

main().catch(err => {
  console.error('[Pipeline Error]:', err);
  process.exit(1);
});
