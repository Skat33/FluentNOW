// Generuje ikonę FluentNOW (1024×1024, RGB bez kanału alfa) w trzech wariantach:
// jasny (domyślny), ciemny i „tinted” (iOS 18+). Bez zależności npm — tylko node:zlib.
// Użycie: node ios/design/make-app-icon.mjs
// Wynik: ios/FluentNOW/Resources/Assets.xcassets/AppIcon.appiconset/*.png
import { deflateSync } from "node:zlib";
import { writeFileSync, mkdirSync } from "node:fs";
import { dirname, join } from "node:path";
import { fileURLToPath } from "node:url";

const SIZE = 1024;
const here = dirname(fileURLToPath(import.meta.url));
const outDir = join(here, "..", "FluentNOW", "Resources", "Assets.xcassets", "AppIcon.appiconset");

// ---------- geometria (SDF, jednostki = piksele) ----------
const clamp = (v, a, b) => Math.min(Math.max(v, a), b);
const mix = (a, b, t) => a + (b - a) * t;

function sdRoundBox(px, py, cx, cy, hw, hh, r) {
  const qx = Math.abs(px - cx) - (hw - r);
  const qy = Math.abs(py - cy) - (hh - r);
  const ox = Math.max(qx, 0), oy = Math.max(qy, 0);
  return Math.hypot(ox, oy) + Math.min(Math.max(qx, qy), 0) - r;
}

// Odległość ze znakiem od trójkąta (Inigo Quilez).
function sdTriangle(px, py, [ax, ay], [bx, by], [cx, cy]) {
  const e0 = [bx - ax, by - ay], e1 = [cx - bx, cy - by], e2 = [ax - cx, ay - cy];
  const v0 = [px - ax, py - ay], v1 = [px - bx, py - by], v2 = [px - cx, py - cy];
  const proj = (v, e) => {
    const t = clamp((v[0] * e[0] + v[1] * e[1]) / (e[0] * e[0] + e[1] * e[1]), 0, 1);
    return [v[0] - e[0] * t, v[1] - e[1] * t];
  };
  const pq0 = proj(v0, e0), pq1 = proj(v1, e1), pq2 = proj(v2, e2);
  const s = Math.sign(e0[0] * e2[1] - e0[1] * e2[0]);
  const d0 = [pq0[0] ** 2 + pq0[1] ** 2, s * (v0[0] * e0[1] - v0[1] * e0[0])];
  const d1 = [pq1[0] ** 2 + pq1[1] ** 2, s * (v1[0] * e1[1] - v1[1] * e1[0])];
  const d2 = [pq2[0] ** 2 + pq2[1] ** 2, s * (v2[0] * e2[1] - v2[1] * e2[0])];
  const dMin = Math.min(d0[0], d1[0], d2[0]);
  const sMin = Math.min(d0[1], d1[1], d2[1]);
  return -Math.sqrt(dMin) * Math.sign(sMin);
}

// Dymek: zaokrąglony prostokąt + ogonek w lewym dolnym rogu (zaokrąglony o 10 px).
function bubble(x, y) {
  const body = sdRoundBox(x, y, 512, 470, 312, 250, 160);
  const tail = sdTriangle(x, y, [292, 640], [246, 828], [450, 690]) - 12;
  return Math.min(body, tail);
}

// Litera „F” z zaokrąglonymi narożnikami, optycznie wyśrodkowana w dymku.
function letterF(x, y) {
  const stem = sdRoundBox(x, y, 438, 470, 46, 150, 22);
  const top = sdRoundBox(x, y, 528, 360, 136, 40, 22);
  const middle = sdRoundBox(x, y, 506, 478, 114, 38, 22);
  return Math.min(stem, top, middle);
}

const coverage = (d) => clamp(0.5 - d, 0, 1);
const hex = (h) => [parseInt(h.slice(1, 3), 16), parseInt(h.slice(3, 5), 16), parseInt(h.slice(5, 7), 16)];

// ---------- warianty ----------
const variants = {
  "AppIcon.png": {
    bgA: hex("#8F6EF2"), bgB: hex("#5530C2"), glow: 0.16,
    bubble: hex("#FFFFFF"), letter: hex("#6A46CF"),
  },
  "AppIcon-Dark.png": {
    bgA: hex("#2A2147"), bgB: hex("#120F22"), glow: 0.08,
    bubble: hex("#B39CF5"), letter: hex("#1A1530"),
  },
  "AppIcon-Tinted.png": {
    bgA: hex("#000000"), bgB: hex("#000000"), glow: 0,
    bubble: hex("#F2F2F2"), letter: hex("#3A3A3A"),
  },
};

function render(v) {
  const rowLen = SIZE * 3 + 1;
  const raw = Buffer.alloc(rowLen * SIZE);
  for (let y = 0; y < SIZE; y++) {
    raw[y * rowLen] = 0; // filtr: brak
    for (let x = 0; x < SIZE; x++) {
      const px = x + 0.5, py = y + 0.5;
      // gradient po przekątnej + miękka poświata w lewym górnym rogu
      const t = clamp((px + py) / (2 * SIZE), 0, 1);
      const g = Math.max(0, 1 - Math.hypot(px - 240, py - 200) / 620) * v.glow;
      let c = [0, 1, 2].map((i) => mix(v.bgA[i], v.bgB[i], t) + 255 * g);
      // cień dymka (delikatny, przesunięty w dół)
      const shadow = coverage(bubble(px, py - 18) / 18 + 0.5) * 0.18 * (v.glow > 0 ? 1 : 0);
      c = c.map((ch) => ch * (1 - shadow));
      const b = coverage(bubble(px, py));
      c = c.map((ch, i) => mix(ch, v.bubble[i], b));
      const f = coverage(letterF(px, py));
      c = c.map((ch, i) => mix(ch, v.letter[i], f));
      const o = y * rowLen + 1 + x * 3;
      raw[o] = clamp(Math.round(c[0]), 0, 255);
      raw[o + 1] = clamp(Math.round(c[1]), 0, 255);
      raw[o + 2] = clamp(Math.round(c[2]), 0, 255);
    }
  }
  return raw;
}

// ---------- PNG ----------
const crcTable = new Uint32Array(256).map((_, n) => {
  let c = n;
  for (let k = 0; k < 8; k++) c = c & 1 ? 0xedb88320 ^ (c >>> 1) : c >>> 1;
  return c >>> 0;
});
function crc32(buf) {
  let c = 0xffffffff;
  for (const byte of buf) c = crcTable[(c ^ byte) & 0xff] ^ (c >>> 8);
  return (c ^ 0xffffffff) >>> 0;
}
function chunk(type, data) {
  const len = Buffer.alloc(4); len.writeUInt32BE(data.length);
  const td = Buffer.concat([Buffer.from(type, "ascii"), data]);
  const crc = Buffer.alloc(4); crc.writeUInt32BE(crc32(td));
  return Buffer.concat([len, td, crc]);
}
function png(raw) {
  const ihdr = Buffer.alloc(13);
  ihdr.writeUInt32BE(SIZE, 0); ihdr.writeUInt32BE(SIZE, 4);
  ihdr[8] = 8; ihdr[9] = 2; ihdr[10] = 0; ihdr[11] = 0; ihdr[12] = 0; // 8 bit, RGB
  return Buffer.concat([
    Buffer.from([0x89, 0x50, 0x4e, 0x47, 0x0d, 0x0a, 0x1a, 0x0a]),
    chunk("IHDR", ihdr),
    chunk("IDAT", deflateSync(raw, { level: 9 })),
    chunk("IEND", Buffer.alloc(0)),
  ]);
}

mkdirSync(outDir, { recursive: true });
for (const [name, v] of Object.entries(variants)) {
  const file = join(outDir, name);
  writeFileSync(file, png(render(v)));
  console.log("zapisano", file);
}
