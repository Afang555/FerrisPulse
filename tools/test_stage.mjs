import assert from 'node:assert';
import fs from 'node:fs';
import path from 'node:path';

function run() {
  console.log('Testing Promo Stage HTML & CSS...');
  const htmlPath = path.resolve('promo/index.html');
  const cssPath = path.resolve('promo/style.css');

  assert(fs.existsSync(htmlPath), 'promo/index.html must exist');
  assert(fs.existsSync(cssPath), 'promo/style.css must exist');

  const html = fs.readFileSync(htmlPath, 'utf-8');
  const css = fs.readFileSync(cssPath, 'utf-8');

  // 1. Verify 4K Canvas
  assert(html.includes('<canvas id="promoCanvas" width="3840" height="2160">'), 'Must contain 3840x2160 4K Canvas');

  // 2. Verify Module Imports
  assert(html.includes('type="module"'), 'Must load JS as ES module');
  assert(html.includes('renderer.js') && html.includes('audio.js'), 'Must reference renderer.js and audio.js');

  // 3. Verify Cinema Controls
  assert(html.includes('id="btnPlay"'), 'Must contain play/pause button');
  assert(html.includes('id="timeline"'), 'Must contain timeline scrubber');
  assert(html.includes('id="timeDisplay"'), 'Must contain time display');
  assert(html.includes('id="btnFullscreen"'), 'Must contain fullscreen toggle');
  assert(html.includes('id="btnAudio"'), 'Must contain audio toggle');

  // 4. Verify 5 Scene Jump Buttons
  assert(html.includes('data-scene="0"') && html.includes('data-scene="4"'), 'Must contain 5-scene jump targets');

  // 5. Verify CSS styling features
  assert(css.includes('aspect-ratio: 16 / 9'), 'CSS must maintain 16:9 4K aspect ratio');
  assert(css.includes('backdrop-filter: blur'), 'CSS must include modern dark glassmorphism styling');

  console.log('Task 3 Test PASSED: promo/index.html & promo/style.css have valid 4K cinema stage structure');
}

run();
