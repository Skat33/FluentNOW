#!/usr/bin/env node
// FluentNOW — generator indeksów: topics/index.json (§2) i dictionary-index.json (§3).
// Idempotentny i deterministyczny: przy niezmienionej treści pliki nie są przepisywane (zachowuje generatedAt).
//
// Użycie: node ios/tools/build-index.mjs [--root <katalog treści>] [--check]
//   --check  nic nie zapisuje; kod 1, jeśli indeksy są nieaktualne.

import fs from 'node:fs';
import path from 'node:path';
import { fileURLToPath } from 'node:url';
import { DEFAULT_ROOT, GROUPS, LEVELS, normalizeKey } from './validate-content.mjs';

const TOOLS_DIR = path.dirname(fileURLToPath(import.meta.url));
const MASTER = path.resolve(TOOLS_DIR, '../docs/TOPICS-MASTER.md');

export const GROUP_SYMBOLS = {
  basics: 'textformat.abc', travel: 'airplane', food: 'fork.knife', home: 'house', health: 'heart.text.square',
  work: 'briefcase', education: 'graduationcap', technology: 'desktopcomputer', money: 'cart',
  services: 'building.columns', people: 'person.2', daily: 'sun.max', leisure: 'theatermasks', nature: 'leaf',
  society: 'globe', communication: 'bubble.left.and.bubble.right',
};

/** Kolejność tematów z tabeli w TOPICS-MASTER.md (jeśli istnieje). */
function masterOrder() {
  const order = new Map();
  if (!fs.existsSync(MASTER)) return order;
  for (const line of fs.readFileSync(MASTER, 'utf8').split(/\r?\n/)) {
    const m = line.match(/^\|\s*([a-z0-9]+(?:-[a-z0-9]+)*)\s*\|/);
    if (m && m[1] !== 'id' && !order.has(m[1])) order.set(m[1], order.size);
  }
  return order;
}

function readJsonSafe(p) {
  try { return JSON.parse(fs.readFileSync(p, 'utf8').replace(/^﻿/, '')); } catch { return undefined; }
}

const collator = new Intl.Collator('pl', { sensitivity: 'base' });
const cmpStr = (a, b) => (a < b ? -1 : a > b ? 1 : 0);

export function buildIndexes(root = DEFAULT_ROOT) {
  const topicsDir = path.join(root, 'topics');
  const skipped = [];
  const topics = [];
  const dict = [];
  const files = fs.existsSync(topicsDir)
    ? fs.readdirSync(topicsDir).filter((f) => f.endsWith('.json') && f !== 'index.json' && !f.startsWith('_')).sort()
    : [];
  for (const f of files) {
    const data = readJsonSafe(path.join(topicsDir, f));
    const fileId = f.replace(/\.json$/, '');
    if (!data || typeof data !== 'object' || !Array.isArray(data.categories) || data.id !== fileId) {
      skipped.push(`${f}: niepoprawny JSON lub kształt (pominięto)`);
      continue;
    }
    const levels = Object.fromEntries(LEVELS.map((l) => [l, 0]));
    const categories = [];
    let entryCount = 0;
    for (const cat of data.categories) {
      const entries = Array.isArray(cat?.entries) ? cat.entries.filter((e) => e && typeof e === 'object') : [];
      categories.push({ id: String(cat?.id ?? ''), namePl: String(cat?.namePl ?? ''), entryCount: entries.length });
      for (const e of entries) {
        entryCount++;
        if (LEVELS.includes(e.level)) levels[e.level]++;
        if (typeof e.term === 'string' && e.term.trim() && typeof e.id === 'string') {
          dict.push({ t: e.term, k: normalizeKey(e.term), p: String(e.translation ?? ''), l: String(e.level ?? ''), f: String(e.frequency ?? ''), r: `${fileId}/${e.id}` });
        }
      }
    }
    topics.push({
      id: data.id, namePl: String(data.namePl ?? ''), nameEn: String(data.nameEn ?? ''), group: String(data.group ?? ''),
      symbol: String(data.symbol ?? ''), summaryPl: String(data.summaryPl ?? ''),
      aliases: Array.isArray(data.aliases) ? data.aliases.filter((a) => typeof a === 'string') : [],
      entryCount, levels, categories,
    });
  }

  const starter = readJsonSafe(path.join(root, 'starter-words.json'));
  if (starter && Array.isArray(starter.words)) {
    for (const e of starter.words) {
      if (e && typeof e.term === 'string' && e.term.trim() && typeof e.id === 'string') {
        dict.push({ t: e.term, k: normalizeKey(e.term), p: String(e.translation ?? ''), l: String(e.level ?? ''), f: String(e.frequency ?? ''), r: `starter/${e.id}` });
      }
    }
  }

  const groupIds = Object.keys(GROUPS);
  const order = masterOrder();
  topics.sort((a, b) => {
    const ga = groupIds.indexOf(a.group); const gb = groupIds.indexOf(b.group);
    if (ga !== gb) return (ga < 0 ? 99 : ga) - (gb < 0 ? 99 : gb);
    const oa = order.has(a.id) ? order.get(a.id) : 1e6; const ob = order.has(b.id) ? order.get(b.id) : 1e6;
    if (oa !== ob) return oa - ob;
    return collator.compare(a.namePl, b.namePl) || cmpStr(a.id, b.id);
  });
  dict.sort((a, b) => cmpStr(a.k, b.k) || cmpStr(a.r, b.r));

  const groups = groupIds.map((id) => ({ id, namePl: GROUPS[id], symbol: GROUP_SYMBOLS[id] }));
  return { topicsIndex: { schemaVersion: 1, generatedAt: '', groups, topics }, dictionaryIndex: { schemaVersion: 1, entries: dict }, skipped };
}

function serializeTopicsIndex(idx) { return JSON.stringify(idx, null, 2) + '\n'; }

/** Kompaktowo: jeden rekord na linię (czytelne diffy, mały rozmiar). */
function serializeDictionary(idx) {
  const lines = idx.entries.map((e) => '    ' + JSON.stringify(e));
  return `{\n  "schemaVersion": ${idx.schemaVersion},\n  "entries": [\n${lines.join(',\n')}${lines.length ? '\n' : ''}  ]\n}\n`;
}

function main(argv) {
  let root = DEFAULT_ROOT; let check = false;
  for (let i = 0; i < argv.length; i++) {
    if (argv[i] === '--root' && argv[i + 1]) root = argv[++i];
    else if (argv[i] === '--check') check = true;
    else { console.error('Użycie: node ios/tools/build-index.mjs [--root <katalog>] [--check]'); return 2; }
  }
  root = path.resolve(root);
  const { topicsIndex, dictionaryIndex, skipped } = buildIndexes(root);
  for (const s of skipped) console.warn(`UWAGA ${s}`);

  const topicsPath = path.join(root, 'topics', 'index.json');
  const dictPath = path.join(root, 'dictionary-index.json');

  // generatedAt: zachowaj poprzedni, jeśli treść indeksu się nie zmieniła (idempotencja).
  const prev = fs.existsSync(topicsPath) ? (() => { try { return JSON.parse(fs.readFileSync(topicsPath, 'utf8')); } catch { return null; } })() : null;
  const sameAsPrev = prev && JSON.stringify({ ...prev, generatedAt: '' }) === JSON.stringify(topicsIndex);
  topicsIndex.generatedAt = sameAsPrev && typeof prev.generatedAt === 'string' ? prev.generatedAt : new Date().toISOString().replace(/\.\d{3}Z$/, 'Z');

  const outputs = [[topicsPath, serializeTopicsIndex(topicsIndex)], [dictPath, serializeDictionary(dictionaryIndex)]];
  let stale = 0;
  for (const [p, text] of outputs) {
    const old = fs.existsSync(p) ? fs.readFileSync(p, 'utf8') : null;
    if (old === text) { console.log(`bez zmian: ${path.relative(root, p)}`); continue; }
    stale++;
    if (check) { console.log(`NIEAKTUALNY: ${path.relative(root, p)}`); continue; }
    fs.mkdirSync(path.dirname(p), { recursive: true });
    fs.writeFileSync(p, text, 'utf8');
    console.log(`zapisano: ${path.relative(root, p)} (${(Buffer.byteLength(text) / 1024).toFixed(1)} KB)`);
  }
  const total = topicsIndex.topics.reduce((s, t) => s + t.entryCount, 0);
  console.log(`tematów: ${topicsIndex.topics.length}, wpisów w tematach: ${total}, rekordów słownika: ${dictionaryIndex.entries.length}`);
  return check && stale ? 1 : 0;
}

const isMain = process.argv[1] && path.resolve(process.argv[1]) === fileURLToPath(import.meta.url);
if (isMain) process.exitCode = main(process.argv.slice(2));
