import assert from 'node:assert';
import { PromoRenderer } from '../promo/renderer.js';

function run() {
  console.log('Testing PromoRenderer...');
  
  // Create mock 4K canvas context
  const fakeCanvas = {
    width: 3840,
    height: 2160,
    getContext: () => ({
      fillRect: () => {},
      strokeRect: () => {},
      clearRect: () => {},
      save: () => {},
      restore: () => {},
      beginPath: () => {},
      closePath: () => {},
      moveTo: () => {},
      lineTo: () => {},
      bezierCurveTo: () => {},
      quadraticCurveTo: () => {},
      arc: () => {},
      fill: () => {},
      stroke: () => {},
      fillText: () => {},
      strokeText: () => {},
      measureText: (txt) => ({ width: txt ? txt.length * 20 : 100 }),
      createLinearGradient: () => ({ addColorStop: () => {} }),
      createRadialGradient: () => ({ addColorStop: () => {} }),
      setLineDash: () => {},
      translate: () => {},
      scale: () => {},
      rotate: () => {},
      transform: () => {},
      clip: () => {},
      drawImage: () => {}
    })
  };

  const renderer = new PromoRenderer(fakeCanvas);

  // 1. Total Frames Check: 85s * 60fps = 5100 frames
  assert.strictEqual(renderer.getTotalFrames(), 5100, 'Total frames must be exactly 5100 (85s @ 60fps)');

  // 2. Scene Timeline Classification Check
  assert.strictEqual(renderer.getCurrentScene(100).name, 'PROLOGUE', 'Frame 100 must be PROLOGUE');
  assert.strictEqual(renderer.getCurrentScene(1000).name, 'ACT_1_ECOSYSTEM', 'Frame 1000 must be ACT_1_ECOSYSTEM');
  assert.strictEqual(renderer.getCurrentScene(2000).name, 'ACT_2_AESTHETICS', 'Frame 2000 must be ACT_2_AESTHETICS');
  assert.strictEqual(renderer.getCurrentScene(3500).name, 'ACT_3_GAMING', 'Frame 3500 must be ACT_3_GAMING');
  assert.strictEqual(renderer.getCurrentScene(4500).name, 'ACT_4_AURORA_POEM', 'Frame 4500 must be ACT_4_AURORA_POEM');

  // 3. Hardware Profiles Check in Act 1
  const devices = renderer.getDeviceProfiles();
  assert.strictEqual(devices.length, 5, 'Must have exactly 5 spotlight hardware devices');
  assert(devices[0].name.includes('DeathAdder V4 Pro'), 'Device 1 must be Razer DeathAdder V4 Pro');
  assert(devices[1].name.includes('GPW'), 'Device 2 must be Logitech GPW 3 代');
  assert(devices[2].name.includes('VT9 PRO'), 'Device 3 must be Rapoo VT9 PRO');
  assert(devices[3].name.includes('WH80') && devices[3].tag.includes('磁轴'), 'Device 4 must be NuPhy WH80 三模磁轴键盘');
  assert(devices[4].name.includes('Galaxy Buds 4 Pro') && devices[4].batteryDetails.length === 3, 'Device 5 must be Galaxy Buds 4 Pro with 3-battery details');

  // 4. Poem and Tribute Check in Act 4
  const poem = renderer.getPoemLines();
  assert.strictEqual(poem.lines[0], '从最初的一行代码，到如今的万行重构。');
  assert.strictEqual(poem.lines[1], '每一个像素的呼吸，都是我们与热爱对齐的频率。');
  assert.strictEqual(poem.lines[2], '愿这束灵脉微光，陪你赢下每一场深夜的战局。');
  assert.strictEqual(poem.author, '—— Ferris-echo × 老G 联合呈现');

  // 5. Test rendering frame at various stages without throwing
  assert.doesNotThrow(() => renderer.renderFrame(0), 'Frame 0 must render without error');
  assert.doesNotThrow(() => renderer.renderFrame(500), 'Frame 500 must render without error');
  assert.doesNotThrow(() => renderer.renderFrame(1200), 'Frame 1200 must render without error');
  assert.doesNotThrow(() => renderer.renderFrame(2400), 'Frame 2400 must render without error');
  assert.doesNotThrow(() => renderer.renderFrame(3600), 'Frame 3600 must render without error');
  assert.doesNotThrow(() => renderer.renderFrame(4600), 'Frame 4600 must render without error');
  assert.doesNotThrow(() => renderer.renderFrame(5099), 'Frame 5099 must render without error');

  console.log('Task 2 Test PASSED: PromoRenderer timeline, devices, poem, and frame rendering pass all assertions');
}

run();
