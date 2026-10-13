import assert from 'node:assert';
import { PromoAudioEngine } from '../promo/audio.js';

async function run() {
  console.log('Testing PromoAudioEngine...');
  const engine = new PromoAudioEngine();
  
  // 1. Verify instance and methods exist
  assert(typeof engine.generatePromoAudioWav === 'function', 'generatePromoAudioWav must be a function');
  assert(typeof engine.playCue === 'function', 'playCue must be a function');
  assert(typeof engine.getAudioTimeline === 'function', 'getAudioTimeline must be a function');

  // 2. Test generating a 3-second offline audio snippet (sampleRate: 44100)
  const durationSec = 3.0;
  const sampleRate = 44100;
  const wavBuffer = await engine.generatePromoAudioWav(durationSec, sampleRate);
  
  assert(wavBuffer instanceof ArrayBuffer, 'Must return an ArrayBuffer');
  assert(wavBuffer.byteLength > 44, 'Must be larger than standard 44-byte WAV header');
  
  // 3. Inspect standard RIFF WAV header
  const view = new DataView(wavBuffer);
  const riff = String.fromCharCode(view.getUint8(0), view.getUint8(1), view.getUint8(2), view.getUint8(3));
  assert.strictEqual(riff, 'RIFF', 'Header must start with RIFF');
  
  const wave = String.fromCharCode(view.getUint8(8), view.getUint8(9), view.getUint8(10), view.getUint8(11));
  assert.strictEqual(wave, 'WAVE', 'Header must contain WAVE');

  const fmt = String.fromCharCode(view.getUint8(12), view.getUint8(13), view.getUint8(14), view.getUint8(15));
  assert.strictEqual(fmt, 'fmt ', 'Header must contain fmt chunk');

  const numChannels = view.getUint16(22, true);
  assert.strictEqual(numChannels, 2, 'Audio must be 2-channel stereo');

  const sampleRateHeader = view.getUint32(24, true);
  assert.strictEqual(sampleRateHeader, sampleRate, 'Sample rate in header must match');

  const bitsPerSample = view.getUint16(34, true);
  assert.strictEqual(bitsPerSample, 16, 'Bits per sample must be 16-bit PCM');

  // 4. Verify data length: 3s * 44100 * 2 channels * 2 bytes/sample = 529200 bytes + 44 = 529244
  const expectedDataLength = durationSec * sampleRate * numChannels * 2;
  assert.strictEqual(wavBuffer.byteLength, 44 + expectedDataLength, 'WAV byte length must precisely match duration');

  console.log('Task 1 Test PASSED: PromoAudioEngine generates valid RIFF WAV with exact duration & headers');
}

run().catch(err => {
  console.error('Task 1 Test FAILED:', err);
  process.exit(1);
});
