/**
 * FerrisPulse 2.0 Keynote Presentation - Epic Melodic Tech Soundtrack
 * 
 * Aesthetic: Apple Keynote Launch Film / Tycho / M83 / Tourist
 * Style: Cinematic Melodic Tech (Inspiring, Emotionally Gripping, High-Tech Precision)
 * 
 * Structural Movements (120 BPM · 90.0s Exact Grid · 45 Bars):
 * - Movement 0 (0.0s - 4.0s, 2 bars): Prologue (Atmospheric drone, mystery chime)
 * - Movement 1 (4.0s - 10.0s, 3 bars): The Disruption (Punchy tech pulse, tense low melody)
 * - Movement 2 (10.0s - 22.0s, 6 bars): Ecosystem Matrix (Theme Debut! Singing analog lead, flowing arps)
 * - Movement 3 (22.0s - 44.0s, 11 bars): Razer 8000Hz & Game Engine (THE BIG CLIMAX DROP! High-octave lead, driving bass)
 * - Movement 4 (44.0s - 62.0s, 9 bars): Hardware Craftsmanship (Playful synth riffs, sleek groove)
 * - Movement 5 (62.0s - 70.0s, 4 bars): Tray Craftsmanship (BREAKDOWN! Drums drop out, intimate bell solo)
 * - Movement 6 (70.0s - 76.0s, 3 bars): SWR Hot-Reload (Building riser & pulse)
 * - Movement 7 (76.0s - 90.0s, 7 bars): Aurora & Poetic Closing (D Major Glory! Celestial bells, starlight decay)
 * 
 * Format: 44.1kHz, 16-bit Stereo PCM WAV (90.0 Seconds)
 */

import fs from 'node:fs';
import path from 'node:path';

const SAMPLE_RATE = 44100;
const DURATION_SEC = 90.0;
const TOTAL_SAMPLES = Math.floor(DURATION_SEC * SAMPLE_RATE);

console.log(`[BGM Synthesizer - Epic Melodic Tech] Synthesizing ${DURATION_SEC}s cinematic score (${TOTAL_SAMPLES} samples)...`);

// Multi-bus audio mixing
const busLeadL = new Float32Array(TOTAL_SAMPLES);
const busLeadR = new Float32Array(TOTAL_SAMPLES);

const busArpL = new Float32Array(TOTAL_SAMPLES);
const busArpR = new Float32Array(TOTAL_SAMPLES);

const busChordsL = new Float32Array(TOTAL_SAMPLES);
const busChordsR = new Float32Array(TOTAL_SAMPLES);

const busBassL = new Float32Array(TOTAL_SAMPLES);
const busBassR = new Float32Array(TOTAL_SAMPLES);

const busDrumsL = new Float32Array(TOTAL_SAMPLES);
const busDrumsR = new Float32Array(TOTAL_SAMPLES);

const busReverbL = new Float32Array(TOTAL_SAMPLES);
const busReverbR = new Float32Array(TOTAL_SAMPLES);

// Note dictionary (C0 to C8)
const NOTE_NAMES = ['C', 'Cs', 'D', 'Eb', 'E', 'F', 'Fs', 'G', 'Ab', 'A', 'Bb', 'B'];
const NOTE = {};
for (let oct = 0; oct <= 8; oct++) {
  for (let s = 0; s < 12; s++) {
    const midi = (oct + 1) * 12 + s;
    const name = NOTE_NAMES[s] + oct;
    NOTE[name] = 440 * Math.pow(2, (midi - 69) / 12);
  }
  NOTE['Db' + oct] = NOTE['Cs' + oct];
  NOTE['Ds' + oct] = NOTE['Eb' + oct];
  NOTE['Gb' + oct] = NOTE['Fs' + oct];
  NOTE['Gs' + oct] = NOTE['Ab' + oct];
  NOTE['As' + oct] = NOTE['Bb' + oct];
}

const kickHits = [];

// ==============================================================================
// 1. SYNTHESIS DSP INSTRUMENT ENGINES
// ==============================================================================

/**
 * 1. Singing Analog Lead Synth (优美动人的模拟主旋律合成器)
 * Dual-oscillator warmth with gentle lowpass filter and stereo ping-pong delay.
 */
function addLeadSynth(timeSec, durationSec, freq, amp = 0.22, pan = 0.0) {
  const startIdx = Math.floor(timeSec * SAMPLE_RATE);
  const len = Math.min(TOTAL_SAMPLES - startIdx, Math.floor(durationSec * SAMPLE_RATE));
  if (len <= 0) return;

  const attackSec = 0.035;
  const releaseSec = Math.min(0.12, durationSec * 0.3);

  for (let i = 0; i < len; i++) {
    const t = i / SAMPLE_RATE;
    let env = 1.0;
    if (t < attackSec) env = t / attackSec;
    else if (t > durationSec - releaseSec) env = Math.max(0, (durationSec - t) / releaseSec);

    // Warm analog dual-oscillator detuning (+- 2 cents)
    const d = 0.0015;
    const s1 = Math.sin(2 * Math.PI * freq * (1 - d) * t);
    const s2 = Math.sin(2 * Math.PI * freq * (1 + d) * t);
    const sub = 0.25 * Math.sin(2 * Math.PI * (freq * 0.5) * t);
    const harm = 0.20 * Math.sin(2 * Math.PI * freq * 2 * t);

    const val = (s1 * 0.5 + s2 * 0.5 + sub + harm) * amp * env;
    const pL = (1 - pan) * 0.5;
    const pR = (1 + pan) * 0.5;

    busLeadL[startIdx + i] += val * pL;
    busLeadR[startIdx + i] += val * pR;

    // Send to reverb
    busReverbL[startIdx + i] += val * pL * 0.35;
    busReverbR[startIdx + i] += val * pR * 0.35;

    // Fluid stereo delay (dotted 8th delay)
    const delay = startIdx + i + Math.floor(0.25 * SAMPLE_RATE);
    if (delay < TOTAL_SAMPLES) {
      busLeadL[delay] += val * 0.26 * pR;
      busLeadR[delay] += val * 0.26 * pL;
    }
  }
}

/**
 * 2. Liquid Glass Arpeggio Pluck (流光玻璃琶音)
 */
function addGlassPluck(timeSec, freq, amp = 0.14, pan = 0.0) {
  const startIdx = Math.floor(timeSec * SAMPLE_RATE);
  const durationSec = 0.36;
  const len = Math.min(TOTAL_SAMPLES - startIdx, Math.floor(durationSec * SAMPLE_RATE));
  if (len <= 0) return;

  for (let i = 0; i < len; i++) {
    const t = i / SAMPLE_RATE;
    const env = Math.exp(-t * 10.0) * Math.min(1.0, t / 0.002);

    const s1 = Math.sin(2 * Math.PI * freq * t);
    const s2 = Math.sin(2 * Math.PI * freq * 2 * t) * 0.30;
    const s3 = Math.sin(2 * Math.PI * freq * 3 * t) * 0.10;

    const val = (s1 + s2 + s3) * amp * env;
    const pL = (1 - pan) * 0.5;
    const pR = (1 + pan) * 0.5;

    busArpL[startIdx + i] += val * pL;
    busArpR[startIdx + i] += val * pR;

    const delay = startIdx + i + Math.floor(0.1875 * SAMPLE_RATE);
    if (delay < TOTAL_SAMPLES) {
      busArpL[delay] += val * 0.25 * pR;
      busArpR[delay] += val * 0.25 * pL;
    }
  }
}

function playGlassArp(startSec, durationSec, pattern, baseAmp = 0.11) {
  const stepSec = 0.125; // 16th note at 120 BPM
  const steps = Math.floor(durationSec / stepSec);
  for (let s = 0; s < steps; s++) {
    const t = startSec + s * stepSec;
    const noteName = pattern[s % pattern.length];
    const pan = Math.sin(s * 0.7) * 0.45;
    const vel = baseAmp * (0.85 + 0.25 * Math.sin(s * 0.6));
    addGlassPluck(t, NOTE[noteName], vel, pan);
  }
}

/**
 * 3. Warm Juno Analog Chords (Juno 温暖复音合成衬底)
 */
function addJunoChords(startSec, durationSec, freqs, amp = 0.18, attackSec = 0.5, releaseSec = 0.8) {
  const startIdx = Math.floor(startSec * SAMPLE_RATE);
  const len = Math.min(TOTAL_SAMPLES - startIdx, Math.floor(durationSec * SAMPLE_RATE));
  if (len <= 0) return;

  for (let i = 0; i < len; i++) {
    const t = i / SAMPLE_RATE;
    let env = 1.0;
    if (t < attackSec) env = Math.sin((t / attackSec) * Math.PI * 0.5);
    else if (t > durationSec - releaseSec) {
      const relProg = (durationSec - t) / releaseSec;
      env = Math.max(0, Math.sin(Math.max(0, relProg) * Math.PI * 0.5));
    }

    let sumL = 0, sumR = 0;
    for (let f = 0; f < freqs.length; f++) {
      const baseFreq = freqs[f];
      const d = 0.0012;
      const s1 = Math.sin(2 * Math.PI * baseFreq * (1 - d) * t);
      const s2 = Math.sin(2 * Math.PI * baseFreq * (1 + d) * t);
      const sWarm = 0.28 * Math.sin(2 * Math.PI * baseFreq * 2 * t);
      const sub = 0.18 * Math.sin(2 * Math.PI * (baseFreq * 0.5) * t);

      sumL += (s1 * 0.6 + sWarm + sub);
      sumR += (s2 * 0.6 + sWarm + sub);
    }

    const valL = (sumL / freqs.length) * amp * env;
    const valR = (sumR / freqs.length) * amp * env;

    busChordsL[startIdx + i] += valL;
    busChordsR[startIdx + i] += valR;

    busReverbL[startIdx + i] += valL * 0.32;
    busReverbR[startIdx + i] += valR * 0.32;
  }
}

/**
 * 4. Deep Moog Sub-Bass (纯净模拟低频)
 */
function addMoogBass(timeSec, durationSec, freq, amp = 0.38) {
  const startIdx = Math.floor(timeSec * SAMPLE_RATE);
  const len = Math.min(TOTAL_SAMPLES - startIdx, Math.floor(durationSec * SAMPLE_RATE));
  if (len <= 0) return;

  for (let i = 0; i < len; i++) {
    const t = i / SAMPLE_RATE;
    const attack = Math.min(1.0, t / 0.012);
    const env = Math.exp(-t * 2.8) * attack;

    const f1 = Math.sin(2 * Math.PI * freq * t);
    const f2 = Math.sin(2 * Math.PI * (freq * 2) * t) * 0.22;
    const sub = Math.sin(2 * Math.PI * (freq * 0.5) * t) * 0.28;

    const sat = Math.tanh((f1 + f2 + sub) * 1.25);
    const val = sat * amp * env;

    busBassL[startIdx + i] += val * 0.5;
    busBassR[startIdx + i] += val * 0.5;
  }
}

/**
 * 5. Minimalist Tech Percussion & Fills (电子打击乐与转场滚奏)
 */
function addKick(timeSec, amp = 0.56) {
  kickHits.push(timeSec);
  const startIdx = Math.floor(timeSec * SAMPLE_RATE);
  const durationSec = 0.32;
  const len = Math.min(TOTAL_SAMPLES - startIdx, Math.floor(durationSec * SAMPLE_RATE));
  if (len <= 0) return;

  for (let i = 0; i < len; i++) {
    const t = i / SAMPLE_RATE;
    const phase = 2 * Math.PI * (48 * t + (67 / 35.0) * (1 - Math.exp(-t * 35.0)));
    const env = Math.exp(-t * 9.2);
    const click = Math.exp(-t * 90.0) * Math.sin(2 * Math.PI * 180 * t) * 0.15;

    const val = (Math.sin(phase) + click) * amp * env;
    busDrumsL[startIdx + i] += val * 0.5;
    busDrumsR[startIdx + i] += val * 0.5;
  }
}

function addSnareClap(timeSec, amp = 0.40) {
  const startIdx = Math.floor(timeSec * SAMPLE_RATE);
  const durationSec = 0.20;
  const len = Math.min(TOTAL_SAMPLES - startIdx, Math.floor(durationSec * SAMPLE_RATE));
  if (len <= 0) return;

  let filt = 0;
  for (let i = 0; i < len; i++) {
    const t = i / SAMPLE_RATE;
    const tone = Math.sin(2 * Math.PI * 170 * t) * Math.exp(-t * 35.0) * 0.35;
    const noise = Math.random() * 2 - 1;
    filt += 0.38 * (noise - filt);
    const snap = filt * Math.exp(-t * 20.0) * 0.60;

    const val = (tone + snap) * amp;
    busDrumsL[startIdx + i] += val * 0.52;
    busDrumsR[startIdx + i] += val * 0.48;

    busReverbL[startIdx + i] += val * 0.25;
    busReverbR[startIdx + i] += val * 0.25;
  }
}

function addTick(timeSec, amp = 0.09, pan = 0.2) {
  const startIdx = Math.floor(timeSec * SAMPLE_RATE);
  const durationSec = 0.05;
  const len = Math.min(TOTAL_SAMPLES - startIdx, Math.floor(durationSec * SAMPLE_RATE));
  if (len <= 0) return;

  let filt = 0;
  for (let i = 0; i < len; i++) {
    const t = i / SAMPLE_RATE;
    const env = Math.exp(-t * 58.0);
    const noise = Math.random() * 2 - 1;
    filt = 0.72 * (filt + noise - filt * 0.32);
    const val = filt * amp * env;

    busDrumsL[startIdx + i] += val * (1 - pan) * 0.5;
    busDrumsR[startIdx + i] += val * (1 + pan) * 0.5;
  }
}

/**
 * Snare roll build before drops (21.0s - 22.0s)
 */
function addSnareRoll(startSec, durationSec = 1.0, baseAmp = 0.20) {
  const count = 8;
  const step = durationSec / count;
  for (let i = 0; i < count; i++) {
    const t = startSec + i * step;
    const prog = i / (count - 1);
    addSnareClap(t, baseAmp * (0.4 + 0.6 * prog));
  }
}

/**
 * White noise riser sweep before drops
 */
function addRiserSweep(startSec, durationSec, amp = 0.22) {
  const startIdx = Math.floor(startSec * SAMPLE_RATE);
  const len = Math.min(TOTAL_SAMPLES - startIdx, Math.floor(durationSec * SAMPLE_RATE));
  if (len <= 0) return;

  let filt = 0;
  for (let i = 0; i < len; i++) {
    const t = i / SAMPLE_RATE;
    const prog = t / durationSec;
    const env = Math.pow(prog, 2.2) * amp;
    const noise = Math.random() * 2 - 1;
    filt += (0.1 + 0.6 * prog) * (noise - filt);
    const val = filt * env;

    busDrumsL[startIdx + i] += val * 0.5;
    busDrumsR[startIdx + i] += val * 0.5;
  }
}

/**
 * 6. Celestial Prism Chimes (极光棱镜音钟)
 */
function addPrismChime(timeSec, freq, amp = 0.22, pan = 0.0) {
  const startIdx = Math.floor(timeSec * SAMPLE_RATE);
  const durationSec = 3.6;
  const len = Math.min(TOTAL_SAMPLES - startIdx, Math.floor(durationSec * SAMPLE_RATE));
  if (len <= 0) return;

  for (let i = 0; i < len; i++) {
    const t = i / SAMPLE_RATE;
    const env = Math.exp(-t * 1.9) * Math.min(1.0, t / 0.002);
    const s1 = Math.sin(2 * Math.PI * freq * t) * 0.72;
    const s2 = Math.sin(2 * Math.PI * freq * 2.002 * t) * 0.20 * Math.exp(-t * 5.0);
    const s3 = Math.sin(2 * Math.PI * freq * 3.0 * t) * 0.08 * Math.exp(-t * 10.0);

    const val = (s1 + s2 + s3) * amp * env;
    const pL = (1 - pan) * 0.5;
    const pR = (1 + pan) * 0.5;

    busLeadL[startIdx + i] += val * pL;
    busLeadR[startIdx + i] += val * pR;

    busReverbL[startIdx + i] += val * 0.38 * pR;
    busReverbR[startIdx + i] += val * 0.38 * pL;
  }
}

// ==============================================================================
// 2. MUSICAL TIMELINE (120.0 BPM · 90.0s NATURAL GRID · 45 BARS)
// ==============================================================================

console.log('[BGM Synthesizer - Epic Melodic Tech] Composing 90.0s score with genuine lead melody...');

// 120 BPM:
// 1 Beat = 0.500s | 1 Bar (4 Beats) = 2.000s | 8th note = 0.250s | 16th note = 0.125s
const BEAT = 0.500;
const BAR = 2.000;

// Rich Modal Chords
const CHORD_DM9 = [NOTE['D2'], NOTE['A2'], NOTE['F3'], NOTE['C4'], NOTE['E4']];
const CHORD_BBMAJ9 = [NOTE['Bb1'], NOTE['F2'], NOTE['D3'], NOTE['A3'], NOTE['C4']];
const CHORD_FMAJ7 = [NOTE['F1'], NOTE['C2'], NOTE['A2'], NOTE['E3'], NOTE['G3']];
const CHORD_C9 = [NOTE['C2'], NOTE['G2'], NOTE['E3'], NOTE['Bb3'], NOTE['D4']];
const CHORD_GM9 = [NOTE['G1'], NOTE['D2'], NOTE['Bb2'], NOTE['F3'], NOTE['A3']];
const CHORD_A7SUS = [NOTE['A1'], NOTE['E2'], NOTE['G3'], NOTE['D4'], NOTE['E4']];
const CHORD_DMAJ9 = [NOTE['D2'], NOTE['A2'], NOTE['Fs3'], NOTE['Cs4'], NOTE['E4']];
const CHORD_GMAJ9 = [NOTE['G1'], NOTE['D2'], NOTE['B2'], NOTE['Fs3'], NOTE['A3']];

// Arpeggio patterns
const ARP_PATTERNS = {
  Dm9:   ['D4', 'F4', 'A4', 'C5', 'E5', 'A5', 'F5', 'D5'],
  Bbmaj9: ['Bb3', 'D4', 'F4', 'A4', 'C5', 'F5', 'D5', 'Bb4'],
  Fmaj7:  ['F3', 'A3', 'C4', 'E4', 'G4', 'C5', 'A4', 'F4'],
  C9:     ['C4', 'E4', 'G4', 'Bb4', 'D5', 'G5', 'E5', 'C5'],
  Gm9:    ['G3', 'Bb3', 'D4', 'F4', 'A4', 'D5', 'Bb4', 'G4'],
  Dmaj9:  ['D4', 'Fs4', 'A4', 'Cs5', 'E5', 'A5', 'Fs5', 'D5']
};

/**
 * Helper to play melodic sequences
 */
function playMelodyNotes(sequence) {
  sequence.forEach(item => {
    addLeadSynth(item.t, item.dur, NOTE[item.n], item.amp || 0.22, item.pan || 0.0);
  });
}

// ------------------------------------------------------------------------------
// ACT 0: PROLOGUE (0.0s - 4.0s, 2 BARS) [Birth of Digital Light]
// ------------------------------------------------------------------------------
addJunoChords(0.0, 4.2, CHORD_DM9, 0.20, 0.6, 0.8);
addPrismChime(0.6, NOTE['D5'], 0.22, -0.2);
addPrismChime(1.8, NOTE['A5'], 0.24, 0.2);
addPrismChime(2.8, NOTE['F5'], 0.22, -0.1);
addSnareClap(3.5, 0.28); // Pickup clap into 4.0s

// ------------------------------------------------------------------------------
// ACT 1: THE DISRUPTION (4.0s - 10.0s, 3 BARS) [6.0s Compact! Tense Tech Pulse]
// ------------------------------------------------------------------------------
// Chords: Dm9 (4.0s - 6.0s) -> Bbmaj9 (6.0s - 8.0s) -> Fmaj7 (8.0s - 10.0s)
const act1Chords = [
  { t: 4.0, chord: CHORD_DM9,    bass: NOTE['D2'],  arp: ARP_PATTERNS.Dm9 },
  { t: 6.0, chord: CHORD_BBMAJ9, bass: NOTE['Bb1'], arp: ARP_PATTERNS.Bbmaj9 },
  { t: 8.0, chord: CHORD_FMAJ7,  bass: NOTE['F1'],  arp: ARP_PATTERNS.Fmaj7 }
];

act1Chords.forEach(c => {
  addJunoChords(c.t, 2.3, c.chord, 0.18, 0.3, 0.4);
  playGlassArp(c.t, 2.0, c.arp, 0.10);
});

// Low-octave theme motif hint
playMelodyNotes([
  { t: 4.5, dur: 0.45, n: 'A3', amp: 0.18 },
  { t: 5.0, dur: 0.45, n: 'C4', amp: 0.18 },
  { t: 5.5, dur: 0.90, n: 'D4', amp: 0.20 },
  { t: 6.5, dur: 0.45, n: 'F4', amp: 0.18 },
  { t: 7.0, dur: 0.45, n: 'E4', amp: 0.18 },
  { t: 7.5, dur: 0.90, n: 'D4', amp: 0.20 },
  { t: 8.5, dur: 0.45, n: 'C4', amp: 0.18 },
  { t: 9.0, dur: 0.85, n: 'D4', amp: 0.22 }
]);

// Tight tech groove
let act1Beats = 0;
for (let t = 4.0; t < 10.0; t += BEAT) {
  addKick(t, 0.50);
  if (act1Beats % 2 === 1) addSnareClap(t, 0.34);
  addTick(t + BEAT * 0.5, 0.08, 0.2);

  const curChord = act1Chords[Math.min(2, Math.floor((t - 4.0) / 2.0))];
  addMoogBass(t, 0.35, curChord.bass, 0.38);
  addMoogBass(t + BEAT * 0.75, 0.20, curChord.bass, 0.25);

  act1Beats++;
}

// ------------------------------------------------------------------------------
// ACT 2: ECOSYSTEM MATRIX (10.0s - 22.0s, 6 BARS) [THEME DEBUT! 流畅主旋律初展]
// ------------------------------------------------------------------------------
// 10.0s: The scene opens up, the lead melody sings!
const act2Chords = [
  { t: 10.0, chord: CHORD_BBMAJ9, bass: NOTE['Bb1'], arp: ARP_PATTERNS.Bbmaj9 },
  { t: 13.0, chord: CHORD_C9,     bass: NOTE['C2'],  arp: ARP_PATTERNS.C9 },
  { t: 16.0, chord: CHORD_DM9,    bass: NOTE['D2'],  arp: ARP_PATTERNS.Dm9 },
  { t: 19.0, chord: CHORD_FMAJ7,  bass: NOTE['F1'],  arp: ARP_PATTERNS.Fmaj7 }
];

act2Chords.forEach(c => {
  addJunoChords(c.t, 3.4, c.chord, 0.20, 0.3, 0.4);
  playGlassArp(c.t, 3.0, c.arp, 0.12);
});

// ★ THE MAIN THEME (主旋律 Phrase 1) - Singing, emotional, memorable!
playMelodyNotes([
  // Bar 1: A4 -> C5 -> D5
  { t: 10.5, dur: 0.45, n: 'A4', amp: 0.24 },
  { t: 11.0, dur: 0.45, n: 'C5', amp: 0.24 },
  { t: 11.5, dur: 1.10, n: 'D5', amp: 0.26 },

  // Bar 2: F5 -> E5 -> D5 -> C5
  { t: 13.0, dur: 0.45, n: 'F5', amp: 0.24 },
  { t: 13.5, dur: 0.45, n: 'E5', amp: 0.24 },
  { t: 14.0, dur: 0.45, n: 'D5', amp: 0.24 },
  { t: 14.5, dur: 0.85, n: 'C5', amp: 0.22 },

  // Bar 3: A4 -> C5 -> D5
  { t: 16.0, dur: 0.45, n: 'A4', amp: 0.24 },
  { t: 16.5, dur: 0.45, n: 'C5', amp: 0.24 },
  { t: 17.0, dur: 1.10, n: 'D5', amp: 0.26 },

  // Bar 4: E5 -> G5 -> F5
  { t: 18.5, dur: 0.45, n: 'E5', amp: 0.24 },
  { t: 19.0, dur: 0.45, n: 'G5', amp: 0.26 },
  { t: 19.5, dur: 1.40, n: 'F5', amp: 0.28 }
]);

// Build riser into the 22.0s climax drop
addRiserSweep(20.5, 1.5, 0.26);
addSnareRoll(21.0, 1.0, 0.30);

let act2Beats = 0;
for (let t = 10.0; t < 22.0; t += BEAT) {
  addKick(t, 0.54);
  if (act2Beats % 2 === 1) addSnareClap(t, 0.38);
  addTick(t + BEAT * 0.5, 0.09, 0.25);
  addTick(t + BEAT * 0.25, 0.05, -0.2);

  const curChord = act2Chords[Math.min(3, Math.floor((t - 10.0) / 3.0))];
  addMoogBass(t, 0.38, curChord.bass, 0.40);
  addMoogBass(t + BEAT * 0.75, 0.22, curChord.bass, 0.28);

  act2Beats++;
}

// ------------------------------------------------------------------------------
// ACT 3: RAZER 8000Hz & GAME ENGINE (22.0s - 44.0s, 11 BARS) [THE EPIC CLIMAX DROP!]
// ------------------------------------------------------------------------------
// 22.0s: BASS DROP! Maximum power, soaring high-octave lead, driving punchy beat!
const act3Chords = [
  // Round 1 (22.0s - 33.0s)
  { t: 22.0, chord: CHORD_DM9,    bass: NOTE['D2'],  arp: ARP_PATTERNS.Dm9 },
  { t: 25.0, chord: CHORD_BBMAJ9, bass: NOTE['Bb1'], arp: ARP_PATTERNS.Bbmaj9 },
  { t: 28.0, chord: CHORD_FMAJ7,  bass: NOTE['F1'],  arp: ARP_PATTERNS.Fmaj7 },
  { t: 30.5, chord: CHORD_C9,     bass: NOTE['C2'],  arp: ARP_PATTERNS.C9 },
  // Round 2 (33.0s - 44.0s)
  { t: 33.0, chord: CHORD_DM9,    bass: NOTE['D2'],  arp: ARP_PATTERNS.Dm9 },
  { t: 36.0, chord: CHORD_GM9,    bass: NOTE['G1'],  arp: ARP_PATTERNS.Gm9 },
  { t: 39.0, chord: CHORD_BBMAJ9, bass: NOTE['Bb1'], arp: ARP_PATTERNS.Bbmaj9 },
  { t: 41.5, chord: CHORD_C9,     bass: NOTE['C2'],  arp: ARP_PATTERNS.C9 }
];

act3Chords.forEach(c => {
  addJunoChords(c.t, 3.4, c.chord, 0.24, 0.2, 0.3);
  playGlassArp(c.t, 3.0, c.arp, 0.14);
});

// ★ THE CLIMAX LEAD MELODY (高八度爆发与升华)
playMelodyNotes([
  // Round 1 (22.0s - 33.0s): High octave soaring theme!
  { t: 22.0, dur: 0.45, n: 'D5', amp: 0.28 },
  { t: 22.5, dur: 0.45, n: 'F5', amp: 0.28 },
  { t: 23.0, dur: 1.20, n: 'A5', amp: 0.32 },

  { t: 24.5, dur: 0.45, n: 'C6', amp: 0.32 },
  { t: 25.0, dur: 0.45, n: 'A5', amp: 0.30 },
  { t: 25.5, dur: 0.45, n: 'G5', amp: 0.28 },
  { t: 26.0, dur: 0.85, n: 'F5', amp: 0.26 },

  { t: 27.5, dur: 0.45, n: 'G5', amp: 0.28 },
  { t: 28.0, dur: 0.45, n: 'A5', amp: 0.30 },
  { t: 28.5, dur: 1.20, n: 'D5', amp: 0.28 },

  { t: 30.0, dur: 0.45, n: 'E5', amp: 0.26 },
  { t: 30.5, dur: 0.45, n: 'F5', amp: 0.28 },
  { t: 31.0, dur: 1.40, n: 'D5', amp: 0.30 },

  // Round 2 (33.0s - 44.0s): Counter-melody variation!
  { t: 33.0, dur: 0.45, n: 'A5', amp: 0.30 },
  { t: 33.5, dur: 0.45, n: 'C6', amp: 0.32 },
  { t: 34.0, dur: 1.20, n: 'D6', amp: 0.34 },

  { t: 35.5, dur: 0.45, n: 'F6', amp: 0.34 },
  { t: 36.0, dur: 0.45, n: 'E6', amp: 0.32 },
  { t: 36.5, dur: 0.45, n: 'D6', amp: 0.30 },
  { t: 37.0, dur: 0.85, n: 'C6', amp: 0.28 },

  { t: 38.5, dur: 0.45, n: 'A5', amp: 0.28 },
  { t: 39.0, dur: 0.45, n: 'C6', amp: 0.30 },
  { t: 39.5, dur: 1.20, n: 'D6', amp: 0.32 },

  { t: 41.0, dur: 0.45, n: 'E6', amp: 0.30 },
  { t: 41.5, dur: 0.45, n: 'G6', amp: 0.32 },
  { t: 42.0, dur: 1.60, n: 'F6', amp: 0.34 }
]);

// Driving full-power electronic beat: Kick every beat, snappy clap on 2 & 4, double-time ticks
let act3Beats = 0;
for (let t = 22.0; t < 44.0; t += BEAT) {
  addKick(t, 0.60);
  if (act3Beats % 2 === 1) addSnareClap(t, 0.44);
  addTick(t, 0.05, -0.2);
  addTick(t + BEAT * 0.5, 0.11, 0.25);

  let cIdx = 0;
  for (let i = 0; i < act3Chords.length; i++) {
    if (t >= act3Chords[i].t) cIdx = i;
  }
  const curChord = act3Chords[cIdx];
  // Pumping octaves
  addMoogBass(t, 0.38, curChord.bass, 0.46);
  addMoogBass(t + BEAT * 0.75, 0.25, curChord.bass * 2, 0.34);

  act3Beats++;
}

// ------------------------------------------------------------------------------
// ACT 4: HARDWARE CRAFTSMANSHIP (44.0s - 62.0s, 9 BARS) [NuPhy & Xbox: Sleek Groove]
// ------------------------------------------------------------------------------
const act4Chords = [
  { t: 44.0, chord: CHORD_GM9,    bass: NOTE['G1'],  arp: ARP_PATTERNS.Gm9 },
  { t: 48.5, chord: CHORD_A7SUS,  bass: NOTE['A1'],  arp: ARP_PATTERNS.Dm9 },
  { t: 53.0, chord: CHORD_BBMAJ9, bass: NOTE['Bb1'], arp: ARP_PATTERNS.Bbmaj9 },
  { t: 57.5, chord: CHORD_C9,     bass: NOTE['C2'],  arp: ARP_PATTERNS.C9 }
];

act4Chords.forEach(c => {
  addJunoChords(c.t, 4.8, c.chord, 0.20, 0.4, 0.5);
  playGlassArp(c.t, 4.5, c.arp, 0.12);
});

// Playful syncopated lead riff
playMelodyNotes([
  { t: 44.5, dur: 0.40, n: 'G4', amp: 0.22 },
  { t: 45.0, dur: 0.40, n: 'Bb4', amp: 0.22 },
  { t: 45.5, dur: 0.80, n: 'D5', amp: 0.24 },
  { t: 47.0, dur: 0.40, n: 'C5', amp: 0.22 },
  { t: 47.5, dur: 0.70, n: 'Bb4', amp: 0.20 },

  { t: 49.0, dur: 0.40, n: 'A4', amp: 0.22 },
  { t: 49.5, dur: 0.40, n: 'C5', amp: 0.22 },
  { t: 50.0, dur: 0.80, n: 'E5', amp: 0.24 },
  { t: 51.5, dur: 0.40, n: 'D5', amp: 0.22 },
  { t: 52.0, dur: 0.70, n: 'C5', amp: 0.20 },

  { t: 53.5, dur: 0.40, n: 'Bb4', amp: 0.24 },
  { t: 54.0, dur: 0.40, n: 'D5', amp: 0.24 },
  { t: 54.5, dur: 0.90, n: 'F5', amp: 0.26 },
  { t: 56.0, dur: 0.40, n: 'E5', amp: 0.22 },
  { t: 56.5, dur: 0.70, n: 'D5', amp: 0.22 },

  { t: 58.0, dur: 0.40, n: 'C5', amp: 0.24 },
  { t: 58.5, dur: 0.40, n: 'E5', amp: 0.24 },
  { t: 59.0, dur: 1.20, n: 'G5', amp: 0.26 }
]);

let act4Beats = 0;
for (let t = 44.0; t < 62.0; t += BEAT) {
  if (act4Beats % 2 === 0) addKick(t, 0.48);
  if (act4Beats % 2 === 1) addSnareClap(t, 0.36);
  addTick(t + BEAT * 0.5, 0.07, 0.2);

  const cIdx = Math.min(3, Math.floor((t - 44.0) / 4.5));
  addMoogBass(t, 0.34, act4Chords[cIdx].bass, 0.36);

  act4Beats++;
}

// ------------------------------------------------------------------------------
// ACT 5: TRAY CRAFTSMANSHIP (62.0s - 70.0s, 4 BARS) [BREAKDOWN! 鼓点骤停，极致微距]
// ------------------------------------------------------------------------------
// DRUMS SUDDENLY STOP! Pure quiet breathing space, highlighting "12MB 纯净微距"
addJunoChords(62.0, 4.2, CHORD_DM9, 0.18, 0.8, 0.8);
playGlassArp(62.0, 4.0, ARP_PATTERNS.Dm9, 0.09);

addJunoChords(66.0, 4.2, CHORD_DMAJ9, 0.20, 0.8, 0.8);
playGlassArp(66.0, 4.0, ARP_PATTERNS.Dmaj9, 0.09);

// Delicate crystalline music box melody (Intimate, heartfelt)
addPrismChime(62.5, NOTE['D5'], 0.22, -0.1);
addPrismChime(63.5, NOTE['F5'], 0.22, 0.1);
addPrismChime(64.5, NOTE['A5'], 0.24, 0.0);
addPrismChime(66.5, NOTE['Fs5'], 0.24, -0.1);
addPrismChime(67.5, NOTE['A5'], 0.24, 0.1);
addPrismChime(68.5, NOTE['D6'], 0.26, 0.0);

// Gentle heartbeat pulse once per 2 bars
addKick(62.0, 0.35);
addKick(66.0, 0.35);

// ------------------------------------------------------------------------------
// ACT 6: SWR HOT-RELOAD (70.0s - 76.0s, 3 BARS) [Building Riser Pulse]
// ------------------------------------------------------------------------------
addJunoChords(70.0, 6.2, CHORD_BBMAJ9, 0.20, 0.5, 0.6);
playGlassArp(70.0, 6.0, ARP_PATTERNS.Bbmaj9, 0.11);

// Gentle building pulse
for (let t = 70.0; t < 76.0; t += BEAT) {
  addKick(t, 0.44);
  addTick(t + BEAT * 0.5, 0.07, 0.2);
  addMoogBass(t, 0.32, NOTE['Bb1'], 0.34);
}

// Grand harmonic riser into 76.0s Aurora
addRiserSweep(74.0, 2.0, 0.25);
addSnareRoll(74.8, 1.2, 0.28);

// ------------------------------------------------------------------------------
// ACT 7: THE AURORA & POETIC RESOLUTION (76.0s - 90.0s, 7 BARS) [TRIUMPHANT D MAJOR!]
// ------------------------------------------------------------------------------
// Percussion completely dissolves into majestic, expansive, glowing light!
addJunoChords(76.0, 13.5, CHORD_DMAJ9, 0.26, 1.2, 3.5);
addJunoChords(81.5, 8.5, CHORD_GMAJ9, 0.24, 1.0, 3.0);

// Poetry Line-by-Line Crystalline Chimes (Matches Slide 9 perfectly):
// 77.0s: Line 1 ("从最初的一行代码，到如今的万行重构。")
addPrismChime(77.0, NOTE['D5'], 0.26, -0.2);
addPrismChime(77.8, NOTE['Fs5'], 0.26, -0.1);
addPrismChime(78.5, NOTE['A5'], 0.28, 0.0);

// 79.5s: Line 2 ("每一个像素的呼吸，都是我们与热爱对齐的频率。")
addPrismChime(79.5, NOTE['G5'], 0.28, 0.2);
addPrismChime(80.3, NOTE['B5'], 0.28, 0.1);
addPrismChime(81.0, NOTE['D6'], 0.30, 0.0);

// 82.0s: Line 3 Highlight ("愿这束灵脉微光，陪你赢下每一场深夜的战局。")
addPrismChime(82.0, NOTE['A5'], 0.32, -0.2);
addPrismChime(82.6, NOTE['Cs6'], 0.32, 0.0);
addPrismChime(83.2, NOTE['E6'], 0.34, 0.2);
addPrismChime(83.8, NOTE['Fs6'], 0.38, 0.0);

// 84.5s: Line 4 Author ("—— Ferris-echo × 老G 联合呈现")
addPrismChime(84.5, NOTE['D6'], 0.30, -0.1);
addPrismChime(85.3, NOTE['A5'], 0.26, 0.1);

// 86.5s: Badges (GitHub / Gitee settled, serene, peaceful decay to 90.0s)
addPrismChime(86.5, NOTE['D5'], 0.25, 0.0);
addPrismChime(87.5, NOTE['A4'], 0.22, 0.0);
addPrismChime(88.5, NOTE['D4'], 0.20, 0.0);

// ==============================================================================
// 3. STEREO CONCERT HALL REVERB & DYNAMIC MASTERING
// ==============================================================================

console.log('[BGM Synthesizer - Epic Melodic Tech] Applying Reverb & Dynamic Sidechain Mastering...');

const masterL = new Float32Array(TOTAL_SAMPLES);
const masterR = new Float32Array(TOTAL_SAMPLES);

// 4-tap stereo Schroeder reverb
const delaySamples = [
  Math.floor(0.041 * SAMPLE_RATE),
  Math.floor(0.057 * SAMPLE_RATE),
  Math.floor(0.079 * SAMPLE_RATE),
  Math.floor(0.095 * SAMPLE_RATE)
];

const wetL = new Float32Array(TOTAL_SAMPLES);
const wetR = new Float32Array(TOTAL_SAMPLES);

for (let d = 0; d < delaySamples.length; d++) {
  const dLen = delaySamples[d];
  const feedback = 0.50 - d * 0.04;
  for (let i = dLen; i < TOTAL_SAMPLES; i++) {
    wetL[i] += busReverbR[i - dLen] * feedback;
    wetR[i] += busReverbL[i - dLen] * feedback;
  }
}

// Sidechain Ducking Curve
kickHits.sort((a, b) => a - b);
let kickCursor = 0;

for (let i = 0; i < TOTAL_SAMPLES; i++) {
  const t = i / SAMPLE_RATE;

  while (kickCursor < kickHits.length - 1 && kickHits[kickCursor + 1] <= t) {
    kickCursor++;
  }

  let duck = 1.0;
  if (kickHits.length > 0) {
    const dt = t - kickHits[kickCursor];
    if (dt >= 0 && dt < 0.25) {
      duck = 0.65 + 0.35 * (1.0 - Math.exp(-dt * 14.0));
    }
  }

  const leadL = busLeadL[i];
  const leadR = busLeadR[i];

  const chordsL = busChordsL[i] * duck;
  const chordsR = busChordsR[i] * duck;

  const bassL = busBassL[i] * duck;
  const bassR = busBassR[i] * duck;

  const arpL = busArpL[i] * (0.75 + 0.25 * duck);
  const arpR = busArpR[i] * (0.75 + 0.25 * duck);

  const drumsL = busDrumsL[i];
  const drumsR = busDrumsR[i];

  const hallL = wetL[i] * 0.30;
  const hallR = wetR[i] * 0.30;

  masterL[i] = drumsL + bassL + chordsL + arpL + leadL + hallL;
  masterR[i] = drumsR + bassR + chordsR + arpR + leadR + hallR;
}

// Peak Normalization & Limiting
let peak = 0;
for (let i = 0; i < TOTAL_SAMPLES; i++) {
  if (Math.abs(masterL[i]) > peak) peak = Math.abs(masterL[i]);
  if (Math.abs(masterR[i]) > peak) peak = Math.abs(masterR[i]);
}

const targetPeak = 0.94;
const masterGain = peak > 0 ? targetPeak / peak : 1.0;
console.log(`[BGM Synthesizer - Epic Melodic Tech] Raw Peak: ${peak.toFixed(3)}, Master Gain: ${masterGain.toFixed(3)}`);

// Final master fade out at 88.0s - 90.0s
const fadeStartSample = Math.floor(88.0 * SAMPLE_RATE);

// 16-bit PCM WAV File Output
const pcmBytes = TOTAL_SAMPLES * 4;
const wavBuffer = Buffer.alloc(44 + pcmBytes);

wavBuffer.write('RIFF', 0);
wavBuffer.writeUInt32LE(36 + pcmBytes, 4);
wavBuffer.write('WAVE', 8);
wavBuffer.write('fmt ', 12);
wavBuffer.writeUInt32LE(16, 16);
wavBuffer.writeUInt16LE(1, 20); // PCM format
wavBuffer.writeUInt16LE(2, 22); // Stereo
wavBuffer.writeUInt32LE(SAMPLE_RATE, 24);
wavBuffer.writeUInt32LE(SAMPLE_RATE * 4, 28);
wavBuffer.writeUInt16LE(4, 32);
wavBuffer.writeUInt16LE(16, 34);
wavBuffer.write('data', 36);
wavBuffer.writeUInt32LE(pcmBytes, 40);

let offset = 44;
for (let i = 0; i < TOTAL_SAMPLES; i++) {
  let fade = 1.0;
  if (i > fadeStartSample) {
    fade = Math.max(0, 1.0 - (i - fadeStartSample) / (TOTAL_SAMPLES - fadeStartSample));
  }

  // Soft tape saturation limiter
  const limL = Math.tanh(masterL[i] * masterGain * fade);
  const limR = Math.tanh(masterR[i] * masterGain * fade);

  const sampleL = Math.max(-32767, Math.min(32767, Math.floor(limL * 32767)));
  const sampleR = Math.max(-32767, Math.min(32767, Math.floor(limR * 32767)));

  wavBuffer.writeInt16LE(sampleL, offset);
  wavBuffer.writeInt16LE(sampleR, offset + 2);
  offset += 4;
}

const outputPath = path.resolve('promo/custom_keynote_bgm.wav');
fs.writeFileSync(outputPath, wavBuffer);

console.log(`[BGM Synthesizer - Epic Melodic Tech] Success! Exported to: ${outputPath} (${(wavBuffer.length / 1024 / 1024).toFixed(2)} MB, ${DURATION_SEC}s)`);
