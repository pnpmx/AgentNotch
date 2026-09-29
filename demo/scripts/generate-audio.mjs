// Original deterministic ambient score and UI sounds. MIT, no sampled media.
// Run from demo/: node scripts/generate-audio.mjs
import {mkdirSync, writeFileSync} from 'node:fs';
import {fileURLToPath} from 'node:url';

const rate = 24000;
const seconds = 34;
const count = rate * seconds;
const left = new Float64Array(count);
const right = new Float64Array(count);
const tau = Math.PI * 2;
const hz = midi => 440 * 2 ** ((midi - 69) / 12);
let seed = 7341;
const noise = () => {seed = (1664525 * seed + 1013904223) >>> 0; return seed / 2147483648 - 1;};

function add(start, duration, voice, gain = 1, pan = 0) {
  const startIndex = Math.round(start * rate);
  const end = Math.min(count, startIndex + Math.round(duration * rate));
  const l = Math.sqrt((1 - pan) / 2);
  const r = Math.sqrt((1 + pan) / 2);
  for (let i = Math.max(0, startIndex); i < end; i++) {
    const t = (i - startIndex) / rate;
    const sample = voice(t, duration) * gain;
    left[i] += sample * l;
    right[i] += sample * r;
  }
}

// Dmaj9 -> Bm7 -> Gmaj9 -> Asus. Soft pad attacks, no borrowed melody.
const chords = [[50, 57, 61, 66, 69], [47, 54, 57, 62, 66], [43, 50, 54, 57, 62], [45, 52, 57, 59, 64]];
for (let bar = 0; bar < 6; bar++) {
  const chord = chords[bar % chords.length];
  const start = bar * 6;
  chord.forEach((midi, index) => {
    const f = hz(midi);
    add(start, 7.2, (t, d) => {
      const env = Math.min(1, t / 1.5) * Math.min(1, (d - t) / 2);
      return env * (Math.sin(tau * f * t) + 0.25 * Math.sin(tau * f * 2.001 * t)) * (0.93 + 0.07 * Math.sin(t * 1.1));
    }, 0.025, (index - 2) * 0.32);
  });
}

// Felt-like plucks with quiet stereo echoes at an 80 BPM pulse.
for (let note = 0; note < 42; note++) {
  const start = 1.5 + note * 0.75;
  const chord = chords[Math.floor(start / 6) % chords.length];
  const midi = chord[[2, 4, 3, 1, 4, 2, 3, 4][note % 8]] + 12;
  const f = hz(midi);
  for (let echo = 0; echo < 3; echo++) {
    add(start + echo * 0.375, 2.2, t => Math.min(1, t / 0.012) * Math.exp(-t * 3.8) * (Math.sin(tau * f * t) + 0.18 * Math.sin(tau * f * 2 * t)), 0.037 * 0.27 ** echo, note % 2 ? 0.35 : -0.35);
  }
}

// Air movements for visual transitions (not sampled whooshes).
for (const start of [0, 5, 13, 22, 28]) {
  let smooth = 0;
  add(start, 0.85, (t, d) => {
    smooth = smooth * 0.92 + noise() * 0.08;
    return smooth * Math.sin(Math.PI * t / d) ** 2;
  }, 0.095);
}

// Click: expanding UI, Space down, Space up. Timeline is 30 fps.
for (const start of [5 + 34 / 30, 13 + 38 / 30, 13 + 153 / 30]) {
  add(start, 0.09, t => Math.min(1, t / 0.002) * Math.exp(-t * 75) * (noise() * 0.45 + Math.sin(tau * 230 * t) * 0.55), 0.15);
}
// Confirmation when the transcript lands; final gentle resolution.
for (const start of [13 + 179 / 30, 28.7]) {
  [74, 81].forEach((midi, i) => add(start + i * 0.1, 1.6, t => Math.min(1, t / 0.008) * Math.exp(-t * 4) * Math.sin(tau * hz(midi) * t), 0.055, i ? 0.2 : -0.2));
}

let peak = 0;
let energy = 0;
for (let i = 0; i < count; i++) {
  const t = i / rate;
  const fade = Math.min(1, t / 0.8, Math.max(0, (seconds - t) / 2));
  left[i] *= fade;
  right[i] *= fade;
  peak = Math.max(peak, Math.abs(left[i]), Math.abs(right[i]));
}
const gain = 0.4 / peak; // Peak ceiling -7.96 dBFS; no clipping.
const bytes = count * 4;
const wav = Buffer.alloc(44 + bytes);
wav.write('RIFF', 0); wav.writeUInt32LE(36 + bytes, 4); wav.write('WAVE', 8);
wav.write('fmt ', 12); wav.writeUInt32LE(16, 16); wav.writeUInt16LE(1, 20);
wav.writeUInt16LE(2, 22); wav.writeUInt32LE(rate, 24); wav.writeUInt32LE(rate * 4, 28);
wav.writeUInt16LE(4, 32); wav.writeUInt16LE(16, 34); wav.write('data', 36); wav.writeUInt32LE(bytes, 40);
for (let i = 0; i < count; i++) {
  const l = left[i] * gain;
  const r = right[i] * gain;
  energy += l * l + r * r;
  wav.writeInt16LE(Math.round(l * 32767), 44 + i * 4);
  wav.writeInt16LE(Math.round(r * 32767), 46 + i * 4);
}
const output = fileURLToPath(new URL('../public/audio/', import.meta.url));
mkdirSync(output, {recursive: true});
writeFileSync(output + 'agentnotch-score.wav', wav);
console.log(JSON.stringify({seconds, sampleRate: rate, channels: 2, peakDbFS: 20 * Math.log10(peak * gain), rmsDbFS: 10 * Math.log10(energy / (2 * count)), bytes: wav.length}));
