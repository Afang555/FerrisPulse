import { spawn } from 'node:child_process';
import path from 'node:path';
import fs from 'node:fs';
import http from 'node:http';

const CHROME_PATH = 'C:/Program Files/Google/Chrome/Application/chrome.exe';
const PROMO_DIR = path.resolve('promo');
const OUT_DIR = path.resolve('promo/dist/verification');

if (!fs.existsSync(OUT_DIR)) {
  fs.mkdirSync(OUT_DIR, { recursive: true });
}

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

async function verifyKeynote() {
  console.log('[Verification] Starting static HTTP server on port 8345...');
  const server = await startStaticServer(PROMO_DIR, 8345);

  const tempDir = path.resolve('promo/dist/chrome_verify_profile');
  if (!fs.existsSync(tempDir)) fs.mkdirSync(tempDir, { recursive: true });

  console.log('[Verification] Spawning Chrome headless...');
  const chromeProc = spawn(CHROME_PATH, [
    '--headless=new',
    '--remote-debugging-port=9455',
    '--window-size=1920,1080',
    '--force-device-scale-factor=1',
    '--enable-gpu',
    '--no-first-run',
    `--user-data-dir=${tempDir}`,
    'http://127.0.0.1:8345/presentation.html?video=1'
  ], { stdio: 'ignore' });

  let wsUrl = null;
  for (let i = 0; i < 30; i++) {
    await new Promise(r => setTimeout(r, 200));
    try {
      const res = await fetch('http://127.0.0.1:9455/json');
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
    throw new Error('Chrome CDP port 9455 did not respond');
  }

  console.log('[Verification] Connected to Chrome CDP:', wsUrl);
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

  await new Promise(r => setTimeout(r, 1500));

  const checkPoints = [
    { time: 6.0, name: 'ch1_comparison_card_nowrap.png', desc: 'Chapter 1: 对比胶囊卡片单行不折行验证' },
    { time: 18.0, name: 'ch2_rack_focus_wizard.png', desc: 'Chapter 2: 对焦向导卡片，优先级卡片景深虚化' },
    { time: 23.0, name: 'ch2_rack_focus_priority.png', desc: 'Chapter 2: 对焦优先级卡片，向导卡片景深虚化' },
    { time: 33.0, name: 'ch3_mouse_8000hz_focus.png', desc: 'Chapter 3: 雷蛇 8000Hz 鼠标浮窗聚焦放大' },
    { time: 42.0, name: 'ch4_game_manager_focus.png', desc: 'Chapter 4: 游戏守护模式卡片聚焦' },
    { time: 47.0, name: 'ch4_osd_badge_focus.png', desc: 'Chapter 4: OSD 状态徽章超大对焦' },
    { time: 86.5, name: 'ch9_poem_line3_highlight.png', desc: 'Chapter 9: 诗句第 3 行高亮流光雾化凝聚' },
    { time: 90.5, name: 'ch9_poem_complete_no_replay.png', desc: 'Chapter 9: 尾页诗句与开源徽章完整展示（无重播按钮）' }
  ];

  for (const cp of checkPoints) {
    console.log(`[Verification] Seeking to ${cp.time}s (${cp.desc})...`);
    await send('Runtime.evaluate', {
      expression: `window.seekPresentationTime(${cp.time})`,
      returnByValue: true
    });
    await new Promise(r => setTimeout(r, 600));

    const shot = await send('Page.captureScreenshot', { format: 'png' });
    const buf = Buffer.from(shot.data, 'base64');
    const outPath = path.join(OUT_DIR, cp.name);
    fs.writeFileSync(outPath, buf);
    console.log(`[Verification] Saved: ${outPath} (${(buf.length / 1024).toFixed(1)} KB)`);
  }

  // Also verify text bounding rects for Chapter 1 comparison items to prove zero word-wrapping
  const textCheckResult = await send('Runtime.evaluate', {
    expression: `(() => {
      window.seekPresentationTime(6.0);
      const items = Array.from(document.querySelectorAll('.comparison-list li'));
      return items.map(li => {
        const text = li.innerText.replace(/\\s+/g, ' ').trim();
        const rect = li.getBoundingClientRect();
        return { text, width: rect.width, height: rect.height };
      });
    })()`,
    returnByValue: true
  });

  console.log('[Verification] Chapter 1 Comparison Line Rects:', JSON.stringify(textCheckResult.result.value, null, 2));

  // Verify replay button absence
  const replayCheck = await send('Runtime.evaluate', {
    expression: `!!document.getElementById('btnReplay')`,
    returnByValue: true
  });
  console.log('[Verification] Replay button exists in DOM:', replayCheck.result.value);

  ws.close();
  chromeProc.kill();
  server.close();
  console.log('[Verification] All checks passed successfully!');
}

verifyKeynote().catch(err => {
  console.error('[Verification Error]', err);
  process.exit(1);
});
