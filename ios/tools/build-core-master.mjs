#!/usr/bin/env node
// FluentNOW — lista słownika rdzeniowego (core vocabulary): ios/docs/CORE-MASTER.json + CORE-MASTER.md.
//
// Źródła (ios/tools/data/core/):
//   ngsl-1.2.txt, nawl-1.2.txt   — listy NGSL 1.2 i NAWL 1.2 (Browne, Culligan, Phillips; CC BY-SA 4.0)
//   annotations-ngsl.txt, annotations-nawl.txt — redakcyjne adnotacje FluentNOW (hasło, części mowy, CEFR)
//   supplement.txt               — uzupełnienie FluentNOW (czasowniki frazowe, wyrażenia, słownictwo ogólne)
// Status „już w bazie” liczony z dictionary-index.json (rekordy tematów i starter) i z plików core/*.json.
//
// Użycie:
//   node ios/tools/build-core-master.mjs                 # przelicza statusy, zachowuje przydział shardów
//   node ios/tools/build-core-master.mjs --reshard       # przydziela shardy od nowa (tylko przed startem L2!)
//   node ios/tools/build-core-master.mjs --check         # nic nie zapisuje; kod 1, gdy pliki są nieaktualne
//   node ios/tools/build-core-master.mjs --shard C03     # lista robocza sharda (dla autora treści)
//   node ios/tools/build-core-master.mjs --shard C03 --all  # … łącznie z hasłami już gotowymi / do sprawdzenia
// Uruchamiaj PO build-index.mjs (korzysta z aktualnego dictionary-index.json).

import fs from 'node:fs';
import path from 'node:path';
import { fileURLToPath } from 'node:url';
import { DEFAULT_ROOT, LEVELS, normalizeKey, kebab } from './validate-content.mjs';

const TOOLS_DIR = path.dirname(fileURLToPath(import.meta.url));
const DATA_DIR = path.join(TOOLS_DIR, 'data', 'core');
const DOCS_DIR = path.resolve(TOOLS_DIR, '../docs');
const MASTER_JSON = path.join(DOCS_DIR, 'CORE-MASTER.json');
const MASTER_MD = path.join(DOCS_DIR, 'CORE-MASTER.md');

/** Docelowe obciążenie sharda (szacowana liczba wpisów do napisania). */
export const SHARD_TARGET = 500;
/** Waga hasła „do sprawdzenia” (jest w bazie, autor tylko weryfikuje, czy brakuje ogólnego znaczenia). */
const CHECK_WEIGHT = 0.25;

export const POS_CODES = {
  n: 'rzeczownik', v: 'czasownik', adj: 'przymiotnik', adv: 'przysłówek', prep: 'przyimek', conj: 'spójnik',
  pron: 'zaimek', int: 'wykrzyknik', num: 'liczebnik', pv: 'czasownik frazowy', phr: 'zwrot', idm: 'idiom',
};

export const SOURCES = [
  {
    id: 'ngsl', name: 'New General Service List (NGSL) 1.2', authors: 'Browne, C., Culligan, B., Phillips, J.',
    license: 'CC BY-SA 4.0', url: 'https://www.newgeneralservicelist.com/new-general-service-list',
    file: 'ngsl-1.2.txt', words: 2809,
  },
  {
    id: 'nawl', name: 'New Academic Word List (NAWL) 1.2', authors: 'Browne, C., Culligan, B., Phillips, J.',
    license: 'CC BY-SA 4.0', url: 'https://www.newgeneralservicelist.com/new-academic-word-list',
    file: 'nawl-1.2.txt', words: 957,
  },
  {
    id: 'fluentnow', name: 'Uzupełnienie FluentNOW (supplement.txt)', authors: 'FluentNOW (redakcja własna)',
    license: 'jak repozytorium; łącznie z listami CC BY-SA udostępniane na CC BY-SA 4.0', url: '',
    file: 'supplement.txt', words: 0,
  },
];

function readWords(file) {
  return fs.readFileSync(path.join(DATA_DIR, file), 'utf8').trim().split(/\s+/).filter(Boolean);
}

/** Parsuje plik adnotacji / uzupełnienia. Zwraca { rows, drops, errors }. */
export function parseAnnotations(text, fileLabel) {
  const rows = [];
  const drops = new Set();
  const errors = [];
  let section = '';
  text.split(/\r?\n/).forEach((raw, i) => {
    const line = raw.trim();
    if (!line || line.startsWith('#')) return;
    if (line.startsWith('drop:')) { line.slice(5).trim().split(/\s+/).filter(Boolean).forEach((w) => drops.add(w)); return; }
    if (line.startsWith('@')) { section = line.slice(1).trim(); return; }
    const f = line.split('|');
    const [head, posRaw, level, src = '', sensesRaw = ''] = f;
    const pos = (posRaw || '').split(',').map((p) => p.trim()).filter(Boolean);
    const bad = !head || !pos.length || pos.some((p) => !POS_CODES[p]) || !LEVELS.includes(level) || (sensesRaw && !/^\d+$/.test(sensesRaw));
    if (bad) { errors.push(`${fileLabel}:${i + 1}: niepoprawna linia "${line}"`); return; }
    rows.push({ head: head.trim(), pos, level, src: src.trim(), senses: sensesRaw ? Number(sensesRaw) : pos.length, section, line: i + 1 });
  });
  return { rows, drops, errors };
}

function readJsonSafe(p) {
  try { return JSON.parse(fs.readFileSync(p, 'utf8').replace(/^﻿/, '')); } catch { return undefined; }
}

/** Wpisy bazy (tematy + starter) i core: klucz → [{ r, p, l, pos }]. */
function loadContent(root) {
  const base = new Map();
  const core = new Map();
  const push = (map, e, r) => {
    if (!e || typeof e.term !== 'string' || typeof e.id !== 'string') return;
    const k = normalizeKey(e.term);
    if (!map.has(k)) map.set(k, []);
    map.get(k).push({ r, p: String(e.translation ?? ''), l: String(e.level ?? ''), pos: String(e.pos ?? '') });
  };
  const topicsDir = path.join(root, 'topics');
  for (const f of fs.existsSync(topicsDir) ? fs.readdirSync(topicsDir).sort() : []) {
    if (!f.endsWith('.json') || f === 'index.json' || f.startsWith('_')) continue;
    const data = readJsonSafe(path.join(topicsDir, f));
    const id = f.replace(/\.json$/, '');
    if (!data || data.id !== id || !Array.isArray(data.categories)) continue;
    for (const cat of data.categories) for (const e of cat?.entries ?? []) push(base, e, `${id}/${e?.id}`);
  }
  const starter = readJsonSafe(path.join(root, 'starter-words.json'));
  for (const e of starter?.words ?? []) push(base, e, `starter/${e?.id}`);
  const coreDir = path.join(root, 'core');
  for (const f of fs.existsSync(coreDir) ? fs.readdirSync(coreDir).sort() : []) {
    if (!f.endsWith('.json') || f.startsWith('_')) continue;
    const data = readJsonSafe(path.join(coreDir, f));
    const id = f.replace(/\.json$/, '');
    if (!data || data.id !== id || !Array.isArray(data.categories)) continue;
    for (const cat of data.categories) for (const e of cat?.entries ?? []) push(core, e, `${id}/${e?.id}`);
  }
  return { base, core };
}

const LEVEL_INDEX = Object.fromEntries(LEVELS.map((l, i) => [l, i]));
const SECTION_ORDER = { phrasal: 0, function: 1, phrase: 2, general: 3, advanced: 4 };

/** Buduje listę haseł (bez statusów). */
export function buildLemmas() {
  const errors = [];
  const ngsl = readWords('ngsl-1.2.txt');
  const nawl = readWords('nawl-1.2.txt');
  const annN = parseAnnotations(fs.readFileSync(path.join(DATA_DIR, 'annotations-ngsl.txt'), 'utf8'), 'annotations-ngsl.txt');
  const annA = parseAnnotations(fs.readFileSync(path.join(DATA_DIR, 'annotations-nawl.txt'), 'utf8'), 'annotations-nawl.txt');
  const sup = parseAnnotations(fs.readFileSync(path.join(DATA_DIR, 'supplement.txt'), 'utf8'), 'supplement.txt');
  errors.push(...annN.errors, ...annA.errors, ...sup.errors);

  // Kompletność adnotacji: każdy lemat listy źródłowej ma hasło albo jest na liście „drop”.
  const coverage = (words, ann, label) => {
    const covered = new Set(ann.rows.map((r) => r.src || r.head));
    for (const w of words) if (!covered.has(w) && !ann.drops.has(w)) errors.push(`${label}: lemat "${w}" bez adnotacji (dodaj hasło albo wpisz na listę drop:)`);
    for (const r of ann.rows) if (!words.includes(r.src || r.head)) errors.push(`${label}:${r.line}: "${r.src || r.head}" nie występuje na liście źródłowej`);
  };
  coverage(ngsl, annN, 'annotations-ngsl.txt');
  coverage(nawl, annA, 'annotations-nawl.txt');

  const ngslRank = new Map(ngsl.map((w, i) => [w, i + 1]));
  const nawlOrder = new Map(nawl.map((w, i) => [w, i + 1]));
  const byKey = new Map();
  const duplicates = [];
  const add = (row, source, sourceRef, priority) => {
    const key = normalizeKey(row.head);
    const prev = byKey.get(key);
    if (prev) {
      if (!prev.sources.includes(sourceRef)) prev.sources.push(sourceRef);
      prev.priority = Math.min(prev.priority, priority);
      if (source === 'fluentnow') duplicates.push(`${row.head} (supplement.txt:${row.line}) — już z ${prev.sources[0]}`);
      return;
    }
    byKey.set(key, {
      id: kebab(row.head), lemma: row.head, pos: row.pos.map((p) => POS_CODES[p]), level: row.level,
      priority, sources: [sourceRef], senses: Math.max(1, row.senses),
    });
  };
  for (const r of annN.rows) {
    const src = r.src || r.head;
    add(r, 'ngsl', `NGSL #${ngslRank.get(src)}`, ngslRank.get(src));
  }
  // Poza NGSL: priorytet = pasmo poziomu (A1 → C2), w paśmie NAWL i uzupełnienie wg kolejności na liście.
  const rest = [];
  for (const r of annA.rows) rest.push({ r, source: 'nawl', ref: `NAWL ${r.src || r.head}`, order: 0, sub: nawlOrder.get(r.src || r.head) ?? 0 });
  sup.rows.forEach((r, i) => rest.push({ r, source: 'fluentnow', ref: `FluentNOW/${r.section || 'general'}`, order: 1 + (SECTION_ORDER[r.section] ?? 3), sub: i }));
  rest.sort((a, b) => (LEVEL_INDEX[a.r.level] - LEVEL_INDEX[b.r.level]) || (a.order - b.order) || (a.sub - b.sub));
  rest.forEach((x, i) => add(x.r, x.source, x.ref, 3000 + i));

  const lemmas = [...byKey.values()].sort((a, b) => a.priority - b.priority || (a.id < b.id ? -1 : 1));
  // Unikalne id (np. „lot” vs „a lot” mają różne klucze, ale kebab mógłby się zderzyć).
  const ids = new Map();
  for (const l of lemmas) {
    if (ids.has(l.id)) errors.push(`zderzenie id "${l.id}": "${l.lemma}" i "${ids.get(l.id)}"`);
    ids.set(l.id, l.lemma);
  }
  return { lemmas, errors, duplicates, stats: { ngsl: ngsl.length, nawl: nawl.length, ngslDropped: annN.drops.size, nawlDropped: annA.drops.size, supplement: sup.rows.length } };
}

/** Status hasła względem bazy i core. */
function classify(lemma, base, core) {
  const key = normalizeKey(lemma.lemma);
  const inBase = base.get(key) ?? [];
  const inCore = core.get(key) ?? [];
  const covered = new Set([...inBase, ...inCore].map((x) => x.pos));
  const missingPos = lemma.pos.filter((p) => !covered.has(p));
  let status;
  if (inCore.length) status = missingPos.length ? 'partial' : 'done';
  else if (!inBase.length) status = 'new';
  else status = missingPos.length ? 'partial' : 'check';
  const estimate = status === 'new' ? lemma.senses : status === 'partial' ? Math.max(1, missingPos.length) : 0;
  return { status, missingPos, estimate, base: inBase.slice(0, 8), core: inCore.map((x) => x.r) };
}

function shardId(n) { return `C${String(n).padStart(2, '0')}`; }

/** Przydział shardów: zachowuje istniejący, nowe hasła dokłada wg priorytetu. */
function assignShards(lemmas, previous, reshard) {
  const prevShard = new Map();
  if (!reshard && previous && Array.isArray(previous.lemmas)) for (const l of previous.lemmas) if (l.shard) prevShard.set(l.id, l.shard);
  const load = new Map();
  let current = 0;
  for (const l of lemmas) if (prevShard.has(l.id)) { l.shard = prevShard.get(l.id); current = Math.max(current, Number(l.shard.slice(1))); }
  for (const l of lemmas) if (l.shard) load.set(l.shard, (load.get(l.shard) ?? 0) + weight(l));
  if (current === 0) current = 1;
  for (const l of lemmas) {
    if (l.shard) continue;
    const w = weight(l);
    let id = shardId(current);
    if ((load.get(id) ?? 0) + w > SHARD_TARGET + 25 && (load.get(id) ?? 0) > 0) { current++; id = shardId(current); }
    l.shard = id;
    load.set(id, (load.get(id) ?? 0) + w);
  }
}

function weight(l) { return l.status === 'check' ? CHECK_WEIGHT : l.estimate; }

export function buildMaster({ root = DEFAULT_ROOT, previous = null, reshard = false } = {}) {
  const { lemmas, errors, duplicates, stats } = buildLemmas();
  const { base, core } = loadContent(root);
  for (const l of lemmas) Object.assign(l, classify(l, base, core));
  // Przydział shardów jest stały; hasło „done” mogło zostać napisane w innym pliku core (pole core podaje gdzie).
  assignShards(lemmas, previous, reshard);
  const shards = new Map();
  for (const l of lemmas) {
    if (!shards.has(l.shard)) shards.set(l.shard, { id: l.shard, file: `core/core-${l.shard.toLowerCase()}.json`, lemmas: 0, toWrite: 0, toCheck: 0, done: 0, estimatedEntries: 0, levels: Object.fromEntries(LEVELS.map((x) => [x, 0])), priorityFrom: l.priority, priorityTo: l.priority });
    const s = shards.get(l.shard);
    s.lemmas++;
    s.levels[l.level]++;
    s.estimatedEntries += l.estimate;
    if (l.status === 'new' || l.status === 'partial') s.toWrite++;
    if (l.status === 'check') s.toCheck++;
    if (l.status === 'done') s.done++;
    s.priorityFrom = Math.min(s.priorityFrom, l.priority);
    s.priorityTo = Math.max(s.priorityTo, l.priority);
  }
  const count = (fn) => lemmas.filter(fn).length;
  const summary = {
    lemmas: lemmas.length,
    status: { new: count((l) => l.status === 'new'), partial: count((l) => l.status === 'partial'), check: count((l) => l.status === 'check'), done: count((l) => l.status === 'done') },
    estimatedEntries: lemmas.reduce((s, l) => s + l.estimate, 0),
    levels: Object.fromEntries(LEVELS.map((x) => [x, count((l) => l.level === x)])),
    levelsToWrite: Object.fromEntries(LEVELS.map((x) => [x, count((l) => l.level === x && (l.status === 'new' || l.status === 'partial'))])),
    sources: { ngsl: count((l) => l.sources.some((s) => s.startsWith('NGSL'))), nawl: count((l) => l.sources.some((s) => s.startsWith('NAWL'))), fluentnow: count((l) => l.sources.every((s) => s.startsWith('FluentNOW'))) },
    pos: Object.fromEntries(Object.values(POS_CODES).map((p) => [p, count((l) => l.pos[0] === p)]).filter(([, n]) => n > 0)),
    inputs: stats,
  };
  const master = {
    schemaVersion: 1,
    generatedAt: '',
    description: 'Lista lematów słownika rdzeniowego FluentNOW (FEEDBACK-7 L1). Opis pól: CORE-MASTER.md. Generowane: node ios/tools/build-core-master.mjs',
    license: 'CC BY-SA 4.0 (zawiera NGSL 1.2 i NAWL 1.2: Browne, C., Culligan, B., Phillips, J.)',
    sources: SOURCES.map(({ file, ...s }) => s),
    shardTarget: SHARD_TARGET,
    summary,
    shards: [...shards.values()].sort((a, b) => (a.id < b.id ? -1 : 1)),
    lemmas: lemmas.map((l) => ({
      id: l.id, lemma: l.lemma, pos: l.pos, level: l.level, priority: l.priority, sources: l.sources, senses: l.senses,
      status: l.status, missingPos: l.missingPos, estimate: l.estimate, shard: l.shard, base: l.base, core: l.core,
    })),
  };
  return { master, errors, duplicates };
}

function serializeMaster(m) {
  const head = { ...m };
  delete head.lemmas;
  const top = JSON.stringify(head, null, 2).replace(/\n}$/, '');
  const lines = m.lemmas.map((l) => '    ' + JSON.stringify(l));
  return `${top},\n  "lemmas": [\n${lines.join(',\n')}\n  ]\n}\n`;
}

function table(rows) { return rows.map((r) => `| ${r.join(' | ')} |`).join('\n'); }

function renderMarkdown(m) {
  const s = m.summary;
  const lv = (o) => LEVELS.map((l) => o[l]);
  const shardRows = m.shards.map((x) => [x.id, `\`${x.file}\``, x.lemmas, x.toWrite, x.toCheck, x.done, x.estimatedEntries, ...lv(x.levels)]);
  return `# CORE-MASTER — słownik rdzeniowy (FEEDBACK-7 L1)

> **Plik generowany** przez \`node ios/tools/build-core-master.mjs\` (nie edytuj ręcznie — zmieniaj źródła w \`ios/tools/data/core/\`).
> Dane: \`ios/docs/CORE-MASTER.json\`. Format wpisów treści: \`ios/docs/CONTENT-SCHEMA.md\` §6. Instrukcja autorów: \`ios/docs/agents/03b-core-content.md\`.

## Źródła i licencje

| Źródło | Autorzy | Licencja | Użycie |
|---|---|---|---|
| [New General Service List (NGSL) 1.2](https://www.newgeneralservicelist.com/new-general-service-list) (2809 lematów, ranking częstości) | Browne, C., Culligan, B., Phillips, J. | CC BY-SA 4.0 | rdzeń listy; ranking NGSL = priorytet |
| [New Academic Word List (NAWL) 1.2](https://www.newgeneralservicelist.com/new-academic-word-list) (957 lematów) | Browne, C., Culligan, B., Phillips, J. | CC BY-SA 4.0 | słownictwo akademickie / ogólne B2–C1 (bez terminologii ścisłej) |
| Uzupełnienie FluentNOW (\`supplement.txt\`) | redakcja FluentNOW | jak repozytorium | czasowniki frazowe, wyrażenia łączące, kolokacje, słownictwo ogólne i C1–C2 spoza NGSL/NAWL |

Listy NGSL i NAWL zweryfikowano na stronie projektu (WebFetch, 2026-10-24): obie z dopiskiem „licensed under a Creative Commons Attribution-ShareAlike 4.0 International License”. Kopie list źródłowych: \`ios/tools/data/core/ngsl-1.2.txt\`, \`nawl-1.2.txt\`. Lista pochodna (ten plik i \`CORE-MASTER.json\`) jest udostępniana na tej samej licencji **CC BY-SA 4.0** z uznaniem autorstwa jak wyżej.

**Nie korzystamy** z list zastrzeżonych (Oxford 3000/5000, English Vocabulary Profile, Cambridge, Longman Communication 3000) — ani do kopiowania, ani do importu poziomów. CEFR, części mowy i formy haseł to **własne oceny redakcyjne** FluentNOW (\`annotations-*.txt\`, \`supplement.txt\`).

## Jak powstała lista

1. NGSL: lematy przypisane do haseł dla ucznia (\`excite\` → *excited*, *exciting*; \`accord\` → *according to*; \`TRUE\` → *true*), z częściami mowy i CEFR. Pominięte (${s.inputs.ngslDropped}): słowa gramatyczne A1 (the, of, will, can…), zaimki, liczebniki, wykrzyknienia, wulgaryzmy, formy brytyjskie (*whilst*, *autumn*, *pub*), tematy drażliwe.
2. NAWL: bez terminologii specjalistycznej i przedrostków (pominięto ${s.inputs.nawlDropped}).
3. Uzupełnienie FluentNOW (${s.inputs.supplement} pozycji): czasowniki frazowe, spójniki i przyimki złożone (*despite*, *whereas*, *nevertheless* są w NGSL; tu m.in. *in spite of*, *as long as*, *provided that*), kolokacje i zwroty (*make a decision*, *take into account*), słownictwo ogólne B1–C1 (np. *attain*, *reluctant*, *thorough*) i ograniczona lista C1–C2 „przydatnych w życiu”.
4. Duplikaty między źródłami są scalane (pole \`sources\` wymienia wszystkie).
5. Status względem bazy (\`dictionary-index\`: ${'tematy + starter'}) i plików \`core/\`.

## Pola \`lemmas[]\`

| Pole | Znaczenie |
|---|---|
| \`id\` | kebab-case hasła — z niego powstaje \`id\` wpisu: \`core.<id>\`, kolejne znaczenia \`core.<id>-2\`, \`-3\` |
| \`lemma\` | hasło w formie słownikowej (tak jak \`term\` wpisu) |
| \`pos\` | części mowy do pokrycia (PL, wg CONTENT-SCHEMA §1), w kolejności ważności |
| \`level\` | szacowany CEFR **głównego** znaczenia (wpisy dostają CEFR per znaczenie) |
| \`priority\` | mniejszy = ważniejszy: ranking NGSL (1–2809), potem pasma poziomów A1→C2 dla NAWL i uzupełnienia (od 3000) |
| \`sources\` | \`NGSL #ranking\`, \`NAWL <lemat>\`, \`FluentNOW/<sekcja>\` |
| \`senses\` | szacowana liczba ważnych znaczeń (wpisów) dla nowego hasła |
| \`status\` | \`new\` — brak w bazie; \`partial\` — hasło jest, ale brakuje części mowy z \`missingPos\`; \`check\` — hasło jest we wszystkich częściach mowy, autor sprawdza tylko, czy brakuje **ogólnego** znaczenia (wpisy tematów bywają wąskie); \`done\` — są wpisy w \`core/\` |
| \`missingPos\` | części mowy bez wpisu w bazie ani w core |
| \`estimate\` | szacowana liczba wpisów do napisania (do bilansowania shardów) |
| \`shard\` | przydział \`C01\`…; plik \`core/core-c01.json\` |
| \`base\` | do 8 istniejących wpisów bazy o tym samym haśle: \`r\` (referencja), \`p\` (tłumaczenie), \`l\` (CEFR), \`pos\` |
| \`core\` | referencje istniejących wpisów core |

**Shardy** grupują hasła **wg priorytetu (częstości)**: C01 zawiera najczęstsze brakujące słowa, kolejne coraz rzadsze — każdy shard ma spójny zakres poziomów, a niedokończona fala L2 i tak pokryje to, co najważniejsze. Cel: ok. ${m.shardTarget} szacowanych wpisów na shard. Przydział jest **stały** (ponowne uruchomienie zachowuje shardy; \`--reshard\` tylko przed startem L2).

## Podsumowanie

- Hasła: **${s.lemmas}** (NGSL: ${s.sources.ngsl}, NAWL: ${s.sources.nawl}, tylko uzupełnienie FluentNOW: ${s.sources.fluentnow}).
- Status: nowe **${s.status.new}**, częściowe ${s.status.partial}, do sprawdzenia ${s.status.check}, gotowe w core ${s.status.done}.
- Szacowane wpisy do napisania: **${s.estimatedEntries}**.

| CEFR | ${LEVELS.join(' | ')} |
|---|${LEVELS.map(() => '---').join('|')}|
${table([['wszystkie hasła', ...lv(s.levels)], ['do napisania (new + partial)', ...lv(s.levelsToWrite)]])}

| Część mowy (główna) | Hasła |
|---|---|
${table(Object.entries(s.pos))}

## Shardy

| Shard | Plik | Hasła | Do napisania | Do sprawdzenia | Gotowe | Szac. wpisy | ${LEVELS.join(' | ')} |
|---|---|---|---|---|---|---|${LEVELS.map(() => '---').join('|')}|
${table(shardRows)}

Lista robocza sharda: \`node ios/tools/build-core-master.mjs --shard C03\` (z \`--all\` także hasła gotowe i do sprawdzenia).
`;
}

function printShard(master, id, all) {
  const list = master.lemmas.filter((l) => l.shard === id && (all || l.status === 'new' || l.status === 'partial' || l.status === 'check'));
  if (!list.length) { console.log(`Shard ${id}: brak haseł`); return 1; }
  console.log(`Shard ${id}: ${list.length} haseł (status | hasło | części mowy | CEFR | szac. wpisy | istniejące wpisy)`);
  for (const l of list) {
    const existing = [...l.base.map((b) => `${b.p} [${b.pos}, ${b.l}] ${b.r}`), ...l.core.map((r) => `core ${r}`)].join('; ');
    const pos = l.status === 'partial' ? `${l.pos.join(', ')} (brak: ${l.missingPos.join(', ')})` : l.pos.join(', ');
    console.log(`${l.status.padEnd(7)} | ${l.lemma} | ${pos} | ${l.level} | ${l.estimate} | ${existing}`);
  }
  return 0;
}

function main(argv) {
  let root = DEFAULT_ROOT; let check = false; let reshard = false; let shard = null; let all = false;
  for (let i = 0; i < argv.length; i++) {
    const a = argv[i];
    if (a === '--root' && argv[i + 1]) root = argv[++i];
    else if (a === '--check') check = true;
    else if (a === '--reshard') reshard = true;
    else if (a === '--shard' && argv[i + 1]) shard = argv[++i].toUpperCase();
    else if (a === '--all') all = true;
    else { console.error('Użycie: node ios/tools/build-core-master.mjs [--root <katalog>] [--check] [--reshard] [--shard C01 [--all]]'); return 2; }
  }
  const previous = readJsonSafe(MASTER_JSON) ?? null;
  if (shard) {
    if (!previous) { console.error('Brak CORE-MASTER.json — uruchom najpierw bez --shard.'); return 1; }
    return printShard(previous, shard, all);
  }
  const { master, errors, duplicates } = buildMaster({ root: path.resolve(root), previous, reshard });
  for (const d of duplicates) console.warn(`UWAGA duplikat: ${d}`);
  if (errors.length) { for (const e of errors) console.error(`BŁĄD ${e}`); return 1; }
  const sameAsPrev = previous && JSON.stringify({ ...previous, generatedAt: '' }) === JSON.stringify(master);
  master.generatedAt = sameAsPrev && typeof previous.generatedAt === 'string' ? previous.generatedAt : new Date().toISOString().replace(/\.\d{3}Z$/, 'Z');
  const outputs = [[MASTER_JSON, serializeMaster(master)], [MASTER_MD, renderMarkdown(master)]];
  let stale = 0;
  for (const [p, text] of outputs) {
    const old = fs.existsSync(p) ? fs.readFileSync(p, 'utf8') : null;
    if (old === text) { console.log(`bez zmian: ${path.basename(p)}`); continue; }
    stale++;
    if (check) { console.log(`NIEAKTUALNY: ${path.basename(p)}`); continue; }
    fs.writeFileSync(p, text, 'utf8');
    console.log(`zapisano: ${path.basename(p)} (${(Buffer.byteLength(text) / 1024).toFixed(0)} KB)`);
  }
  const s = master.summary;
  console.log(`haseł: ${s.lemmas} (new ${s.status.new}, partial ${s.status.partial}, check ${s.status.check}, done ${s.status.done}); szac. wpisów: ${s.estimatedEntries}; shardów: ${master.shards.length}`);
  return check && stale ? 1 : 0;
}

const isMain = process.argv[1] && path.resolve(process.argv[1]) === fileURLToPath(import.meta.url);
if (isMain) process.exitCode = main(process.argv.slice(2));
