#!/usr/bin/env node
// FluentNOW — weryfikacja eksportu: porównuje banki strony (web-source, tylko odczyt) z JSON-ami w Resources/Content.
// Liczności, pełne porównanie pól (po kanonicznej kolejności kluczy), zakresy odpowiedzi, próbki.
// Użycie: node ios/tools/verify-export.mjs [--root <katalog treści>]   (kod 1 przy rozbieżnościach)

import fs from 'node:fs';
import path from 'node:path';
import { importWeb, WEB_ROOT } from './lib/web-loader.mjs';
import { DEFAULT_ROOT } from './validate-content.mjs';

const LEVELS = ['A1', 'A2', 'B1', 'B2', 'C1', 'C2'];
let root = DEFAULT_ROOT;
const argv = process.argv.slice(2);
for (let i = 0; i < argv.length; i++) if (argv[i] === '--root' && argv[i + 1]) root = path.resolve(argv[++i]);

const rows = [];
let failures = 0;
function check(name, expected, actual, note = '') {
  const ok = JSON.stringify(expected) === JSON.stringify(actual);
  if (!ok) failures++;
  rows.push(`${ok ? 'OK  ' : 'BŁĄD'} ${name}: źródło=${fmt(expected)} eksport=${fmt(actual)}${note ? ' — ' + note : ''}`);
}
function info(line) { rows.push(`INFO ${line}`); }
const fmt = (v) => { const s = typeof v === "object" ? JSON.stringify(v) : String(v); return s.length > 140 ? s.slice(0, 137) + "…" : s; };
const read = (rel) => JSON.parse(fs.readFileSync(path.join(root, rel), 'utf8'));
/** Porównanie niezależne od kolejności kluczy obiektów. */
function canon(v) {
  if (Array.isArray(v)) return v.map(canon);
  if (v && typeof v === 'object') return Object.fromEntries(Object.keys(v).filter((k) => v[k] !== undefined).sort().map((k) => [k, canon(v[k])]));
  return v;
}
const same = (a, b) => JSON.stringify(canon(a)) === JSON.stringify(canon(b));
function diffCount(src, out, key) {
  const m = new Map(out.map((x) => [key(x), x]));
  let missing = 0; let different = 0; const examples = [];
  for (const s of src) {
    const o = m.get(key(s));
    if (!o) { missing++; continue; }
    if (!same(s, o)) { different++; if (examples.length < 3) examples.push(key(s)); }
  }
  return { missing, different, examples };
}

const gb = await importWeb('lib/grammar-bank.ts');
const prod = await importWeb('lib/production.ts');
const ib = await importWeb('lib/data/idiom-bank.ts');
const ie = await importWeb('lib/data/idiom-expansion.ts');
const eb = await importWeb('lib/data/exercise-bank.ts');
const rb = await importWeb('lib/reading-bank.ts');
const ar = await importWeb('lib/data/advanced-readings.ts');
const tl = await importWeb('lib/tutor-local.ts');
const av = await importWeb('lib/answer-variants.ts');

// --- Gramatyka: surowy grammar-bank.json (bez wykonywania kodu strony) ---
const rawGrammar = JSON.parse(fs.readFileSync(path.join(WEB_ROOT, 'lib/data/grammar-bank.json'), 'utf8'));
let gTotalSrc = 0; let gTotalOut = 0;
for (const l of LEVELS) {
  const out = read(`grammar/${l}.json`);
  gTotalSrc += rawGrammar[l].length; gTotalOut += out.items.length;
  check(`grammar ${l} liczba zadań`, rawGrammar[l].length, out.items.length);
  const d = diffCount(rawGrammar[l], out.items, (x) => x.bankId);
  check(`grammar ${l} zadania identyczne`, { missing: 0, different: 0 }, { missing: d.missing, different: d.different }, d.examples.join(', '));
  check(`grammar ${l} version/level`, [gb.GRAMMAR_BANK_VERSION, l], [out.version, out.level]);
  check(`grammar ${l} rules`, prod.productionRules[l], out.rules);
  const badDistr = out.items.filter((i) => i.distractors.some((dd) => dd.form === i.answer)).length;
  check(`grammar ${l} dystraktor ≠ odpowiedź`, 0, badDistr);
}
check('grammar razem (1800)', 1800, gTotalOut, `źródło ${gTotalSrc}`);

// --- Ćwiczenia ---
const ex = read('exercises.json');
let exTotal = 0;
for (const l of LEVELS) {
  const authored = new Set(gb.authoredGrammar(l).map((i) => i.bankId));
  const src = prod.productionPool(l).filter((i) => !authored.has(i.bankId));
  const starters = (prod.__starters?.[l] ?? []).length;
  const rowsN = eb.additionalProduction(l).length;
  exTotal += ex.levels[l].length;
  check(`exercises ${l} liczba (startery ${starters} + exercise-bank ${rowsN})`, starters + rowsN, ex.levels[l].length);
  // Eksport dokłada 3. dystraktor (mapa extra z starterPractice) i poprawia „travelled” — porównujemy bez tych dodatków.
  const srcN = new Map(src.map((i) => [i.bankId, i.distractors.length]));
  const outCmp = ex.levels[l].map((i) => JSON.parse(JSON.stringify({ ...i, distractors: i.distractors.slice(0, srcN.get(i.bankId)) }).replace(/traveled/g, 'travelled')));
  const d = diffCount(src, outCmp, (x) => x.bankId);
  check(`exercises ${l} identyczne z productionPool (bez dodanych dystraktorów)`, { missing: 0, different: 0 }, { missing: d.missing, different: d.different }, d.examples.join(', '));
  check(`exercises ${l} każde zadanie ma ≥ 3 dystraktory`, 0, ex.levels[l].filter((i) => i.distractors.length < 3).length);
  check(`exercises ${l} bankId = grammarTaskId`, 0, ex.levels[l].filter((i) => i.bankId !== gb.grammarTaskId({ context: i.context })).length);
}
info(`exercises razem: ${exTotal}`);

// --- Idiomy ---
const id = read('idioms.json');
for (const l of LEVELS) {
  const src = ib.idiomPool(l, 0);
  const expectedN = ib.__rows[l].length + ie.extraIdioms[l].length;
  check(`idioms ${l} liczba (bazowe ${ib.__rows[l].length} + rozszerzenie ${ie.extraIdioms[l].length})`, expectedN, id.levels[l].length);
  const stripped = id.levels[l].map(({ bankId: _b, ...q }) => q);
  check(`idioms ${l} identyczne z idiomPool(level, 0)`, true, src.length === stripped.length && src.every((q, i) => same(q, stripped[i])));
  check(`idioms ${l} answer w zakresie i 4 unikalne opcje`, 0, id.levels[l].filter((q) => q.answer < 0 || q.answer >= q.options.length || new Set(q.options).size !== 4).length);
}

// --- Czytanki ---
const rd = read('readings.json').readings;
const legacy = [...Object.values(tl.__readings), ...Object.values(tl.__extraReadings).flat(), ...ar.advancedReadings];
check('readings liczba (bank v39 + dawne)', rb.readingBank.length + legacy.length, rd.length, `bank ${rb.readingBank.length}, dawne ${legacy.length}`);
const byId = new Map(rd.map((r) => [r.id, r]));
const bankMissing = rb.readingBank.filter((r) => !byId.has(r.id)).map((r) => r.id);
check('readings: wszystkie id banku obecne', [], bankMissing);
const changed = rb.readingBank.filter((r) => byId.has(r.id) && !same(r, byId.get(r.id))).map((r) => r.id);
info(`readings banku zmienione przez poprawki eksportu: ${changed.join(', ') || 'brak'}`);
const legacyTitles = new Set(rd.map((r) => r.title));
check('readings: dawne czytanki obecne (po tytule)', [], legacy.filter((r) => !legacyTitles.has(r.title)).map((r) => r.title));
const qs = rd.flatMap((r) => r.questions.map((q) => ({ r, q })));
check('readings: pytania z answer w zakresie options', 0, qs.filter(({ q }) => !Number.isInteger(q.answer) || q.answer < 0 || q.answer >= q.options.length).length, `pytań ${qs.length}`);
check('readings: każda czytanka ma ≥ 1 pytanie', 0, rd.filter((r) => !r.questions.length).length);
check('readings: srcQuestions = expQuestions', rb.readingBank.reduce((s, r) => s + r.questions.length, 0) + legacy.reduce((s, r) => s + r.questions.length, 0), qs.length);
const perLevel = Object.fromEntries(LEVELS.map((l) => [l, rd.filter((r) => r.level === l).length]));
info(`readings na poziom: ${JSON.stringify(perLevel)}`);

// --- Słowa startowe ---
const sw = read('starter-words.json').words;
const lookups = tl.__STARTER.words.map((w) => tl.starterLookup(w.en)).filter(Boolean);
const srcMeanings = lookups.reduce((s, l) => s + l.meanings.length, 0);
check('starter-words liczba znaczeń (seed + starterLookup)', srcMeanings, sw.length, `${tl.__STARTER.words.length} słów`);
const srcPairs = lookups.flatMap((l) => l.meanings.flatMap((m) => m.examples.map((e) => `${e.en}|${e.pl}`)));
const outPairs = sw.flatMap((e) => e.examples.map((x) => `${x.en}|${x.pl}`));
check('starter-words przykłady EN/PL identyczne', srcPairs, outPairs);
check('starter-words terminy', lookups.flatMap((l) => l.meanings.map(() => l.term)), sw.map((e) => e.term));
check('starter-words: dokładnie 2 przykłady', 0, sw.filter((e) => e.examples.length !== 2).length);

// --- Rekomendacje i warianty ---
const rec = read('recommendations.json').items;
check('recommendations liczba', tl.__advancedCandidates.length, rec.length);
check('recommendations pola zgodne', true, tl.__advancedCandidates.every((r, i) => same(r, (({ ipa: _i, ...x }) => x)(rec[i]))));
const avOut = read('answer-variants.json');
check('answer-variants polishSenseVariants', canon(av.polishSenseVariants), canon(avOut.polishSenseVariants));
check('answer-variants polishAspectPairs', av.polishAspectPairs, avOut.polishAspectPairs);
check('answer-variants englishAliases', canon(tl.__aliases), canon(avOut.englishAliases));

// --- Próbki ---
const sample = (arr, n) => Array.from({ length: n }, (_, i) => arr[Math.floor(((i + 1) * arr.length) / (n + 1))]);
for (const l of ['A1', 'C2']) for (const item of sample(read(`grammar/${l}.json`).items, 2)) info(`próbka grammar ${l}: ${item.bankId} „${item.context}” → ${item.answer}`);
for (const q of sample(id.levels.B2, 1)) info(`próbka idioms B2: ${q.prompt} → ${q.options[q.answer]}`);
for (const r of sample(rd, 2)) info(`próbka readings: ${r.id} (${r.level}), pytań ${r.questions.length}, odp. 1: „${r.questions[0].options[r.questions[0].answer]}”`);

// --- Rozmiary ---
const sizes = [];
(function walk(dir) {
  for (const e of fs.readdirSync(dir, { withFileTypes: true })) {
    const p = path.join(dir, e.name);
    if (e.isDirectory()) walk(p); else if (e.name.endsWith('.json')) sizes.push([path.relative(root, p).split(path.sep).join('/'), fs.statSync(p).size]);
  }
})(root);
const nonTopic = sizes.filter(([p]) => !p.startsWith('topics/') || p === 'topics/index.json');
for (const [p, s] of nonTopic.sort()) info(`rozmiar ${p}: ${(s / 1024).toFixed(1)} KB`);
const topicFiles = sizes.filter(([p]) => p.startsWith('topics/') && p !== 'topics/index.json');
info(`tematy: ${topicFiles.length} plików, razem ${(topicFiles.reduce((s, [, n]) => s + n, 0) / 1024).toFixed(1)} KB`);
const big = sizes.filter(([, s]) => s > 1.5 * 1024 * 1024).map(([p]) => p);
check('żaden plik > 1,5 MB', [], big);

for (const r of rows) console.log(r);
console.log(failures ? `WERYFIKACJA NIE PRZESZŁA: ${failures} rozbieżności` : 'WERYFIKACJA OK');
process.exitCode = failures ? 1 : 0;
