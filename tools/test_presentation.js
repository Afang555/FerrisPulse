const http = require('http');
const fs = require('fs');
const path = require('path');
const { execSync } = require('child_process');

const rootDir = path.resolve(__dirname, '..');
const PORT = 8399;

const mimeTypes = {
  '.html': 'text/html; charset=utf-8',
  '.css': 'text/css; charset=utf-8',
  '.js': 'application/javascript; charset=utf-8',
  '.png': 'image/png',
  '.ico': 'image/x-icon',
  '.svg': 'image/svg+xml'
};

const server = http.createServer((req, res) => {
  let reqPath = decodeURI(req.url.split('?')[0]);
  if (reqPath === '/') reqPath = '/promo/presentation.html';
  const filePath = path.join(rootDir, reqPath);

  if (fs.existsSync(filePath) && fs.statSync(filePath).isFile()) {
    const ext = path.extname(filePath).toLowerCase();
    res.writeHead(200, { 'Content-Type': mimeTypes[ext] || 'application/octet-stream' });
    fs.createReadStream(filePath).pipe(res);
  } else {
    res.writeHead(404);
    res.end('Not found: ' + reqPath);
  }
});

const tempProfileDir = path.join(rootDir, 'promo', 'dist', 'chrome_temp_profile');
if (!fs.existsSync(tempProfileDir)) {
  fs.mkdirSync(tempProfileDir, { recursive: true });
}

server.listen(PORT, () => {
  console.log(`Test server running on http://127.0.0.1:${PORT}`);
  const chromePath = 'C:\\Program Files\\Google\\Chrome\\Application\\chrome.exe';

  const chaptersToCapture = [
    { id: 0, name: 'keynote_ch0_prologue.png' },
    { id: 3, name: 'keynote_ch3_mouse_8000hz.png' },
    { id: 4, name: 'keynote_ch4_game_auto_switch.png' },
    { id: 5, name: 'keynote_ch5_keyboard_console.png' },
    { id: 6, name: 'keynote_ch6_gamepad_xinput.png' },
    { id: 9, name: 'keynote_ch9_aurora_poem.png' }
  ];

  try {
    for (const ch of chaptersToCapture) {
      const outShot = path.join(rootDir, 'promo', 'dist', ch.name);
      const url = `http://127.0.0.1:${PORT}/promo/presentation.html#${ch.id}`;
      const cmd = `"${chromePath}" --headless=new --disable-gpu --no-sandbox --hide-scrollbars --user-data-dir="${tempProfileDir}" --screenshot="${outShot}" --window-size=1920,1080 --virtual-time-budget=1000 "${url}"`;
      console.log(`Capturing Chapter ${ch.id} -> ${ch.name}...`);
      execSync(cmd, { stdio: 'ignore' });
      console.log(`Saved: ${ch.name}`);
    }
  } catch (err) {
    console.error('Error during test capture:', err);
  } finally {
    server.close();
    console.log('All test captures complete.');
    process.exit(0);
  }
});
