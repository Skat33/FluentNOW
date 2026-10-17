// Słowniczki kontekstowe czytanek (CONTENT-SCHEMA §5.4, FEEDBACK-2 G1).
//
// Źródło prawdy: ios/tools/data/reading-glossary.json — { schemaVersion: 1, readings: { "<id czytanki>": [GlossaryEntry…] } }.
// readings.json jest generowany przez export-web-content.mjs (ze strony), więc słowniczek NIE jest edytowany w readings.json,
// tylko w pliku źródłowym; scalanie: export-web-content.mjs (automatycznie) albo apply-reading-glossary.mjs (bez ponownego eksportu).
//
// GlossaryEntry { form: String, lemma: String, translation: String, ipa?: String, ref?: String }
//   form        — forma DOKŁADNIE jak w akapicie (podciąg, na granicy słów), np. "booked", "took a photo"
//   lemma       — forma bazowa ("book", "take a photo")
//   translation — polskie tłumaczenie w znaczeniu z tego tekstu
//   ipa         — wymowa formy bazowej, General American, w /…/
//   ref         — odwołanie do wpisu bazy (`dictionary-index.json` r: "<plik tematu>/<id>" lub "starter/<id>") o tym samym znaczeniu

import fs from 'node:fs';
import path from 'node:path';
import { fileURLToPath } from 'node:url';

const TOOLS_DIR = path.resolve(path.dirname(fileURLToPath(import.meta.url)), '..');
export const GLOSSARY_SOURCE = path.join(TOOLS_DIR, 'data', 'reading-glossary.json');
export const GLOSSARY_MIN = 8;
export const GLOSSARY_MAX = 20;

const ENTRY_KEYS = ['form', 'lemma', 'translation', 'ipa', 'ref'];
const isWordChar = (c) => c !== undefined && /[\p{L}\p{N}]/u.test(c);
const nonEmpty = (v) => typeof v === 'string' && v.trim() !== '';

/** Wczytuje plik źródłowy słowniczków. Brak pliku → `{}` (eksport działa dalej bez słowniczków). */
export function loadGlossarySource(file = GLOSSARY_SOURCE) {
  if (!fs.existsSync(file)) return {};
  const data = JSON.parse(fs.readFileSync(file, 'utf8').replace(/^﻿/, ''));
  return data && typeof data.readings === 'object' && !Array.isArray(data.readings) ? data.readings : {};
}

/** Kanoniczna kolejność kluczy wpisu (stabilne diffy). */
export function canonicalEntry(e) {
  const out = { form: e.form, lemma: e.lemma, translation: e.translation };
  if (nonEmpty(e.ipa)) out.ipa = e.ipa;
  if (nonEmpty(e.ref)) out.ref = e.ref;
  return out;
}

/**
 * Scala słowniczki ze źródła z czytankami (mutuje kopie, zwraca nową tablicę).
 * Czytanka ze słowniczkiem w źródle dostaje pole `glossary` (ostatnie pole obiektu); bez — pole jest usuwane.
 * @returns {{ readings: object[], merged: number, unknown: string[] }} unknown = id ze źródła bez czytanki
 */
export function mergeGlossary(readings, source) {
  const ids = new Set(readings.map((r) => r.id));
  let merged = 0;
  const out = readings.map((r) => {
    const { glossary: _old, ...rest } = r;
    const entries = source[r.id];
    if (!Array.isArray(entries) || entries.length === 0) return rest;
    merged++;
    return { ...rest, glossary: entries.map(canonicalEntry) };
  });
  const unknown = Object.keys(source).filter((id) => !ids.has(id));
  return { readings: out, merged, unknown };
}

/** Czy `form` występuje w którymś akapicie dosłownie, na granicy słów. */
export function formOccurs(paragraphs, form) {
  if (!nonEmpty(form)) return false;
  return paragraphs.some((p) => {
    if (typeof p !== 'string') return false;
    let i = p.indexOf(form);
    while (i >= 0) {
      if (!isWordChar(p[i - 1]) && !isWordChar(p[i + form.length])) return true;
      i = p.indexOf(form, i + 1);
    }
    return false;
  });
}

let dictionaryRefsCache = null;
/** Zbiór `r` z dictionary-index.json leżącego obok readings.json (null, gdy brak pliku — np. fixtures). */
function dictionaryRefs(contentDir) {
  if (!contentDir) return null;
  const p = path.join(contentDir, 'dictionary-index.json');
  if (dictionaryRefsCache && dictionaryRefsCache.path === p) return dictionaryRefsCache.refs;
  if (!fs.existsSync(p)) return null;
  try {
    const data = JSON.parse(fs.readFileSync(p, 'utf8'));
    const refs = new Set((data.entries || []).map((e) => e.r));
    dictionaryRefsCache = { path: p, refs };
    return refs;
  } catch {
    return null;
  }
}

/**
 * Walidacja słowniczka jednej czytanki. `c` = { report, file, id, absPath }; `helpers` = { checkPlainString, typeOf }.
 * Reguły (błędy): glossary-type, glossary-form (forma nie występuje dosłownie w akapicie), glossary-duplicate,
 * glossary-empty, ipa-format, glossary-ref (zły format lub brak w dictionary-index.json).
 * Ostrzeżenia: glossary-count (poza 8–20), glossary-missing (brak słowniczka), unknown-key.
 */
export function validateGlossary(r, c, helpers) {
  const { report, file, id } = c;
  const { checkPlainString, typeOf } = helpers;
  if (r.glossary === undefined) {
    report.warn(file, id, 'glossary-missing', `brak słowniczka kontekstowego (dopisz w ios/tools/data/reading-glossary.json i uruchom apply-reading-glossary.mjs)`);
    return;
  }
  if (!Array.isArray(r.glossary)) { report.error(file, id, 'glossary-type', 'glossary musi być tablicą'); return; }
  const n = r.glossary.length;
  if (n < GLOSSARY_MIN || n > GLOSSARY_MAX) report.warn(file, id, 'glossary-count', `słowniczek ma ${n} pozycji (zalecane ${GLOSSARY_MIN}–${GLOSSARY_MAX})`);
  const paragraphs = Array.isArray(r.paragraphs) ? r.paragraphs : [];
  const refs = dictionaryRefs(c.absPath ? path.dirname(c.absPath) : null);
  const forms = new Set();
  r.glossary.forEach((e, i) => {
    const lbl = `glossary[${i}]`;
    if (typeOf(e) !== 'object') { report.error(file, id, 'glossary-type', `${lbl}: oczekiwano obiektu`); return; }
    for (const k of Object.keys(e)) if (!ENTRY_KEYS.includes(k)) report.warn(file, id, 'unknown-key', `${lbl}: nieznany klucz "${k}"`);
    for (const k of ['form', 'lemma', 'translation']) {
      if (!nonEmpty(e[k])) report.error(file, id, 'glossary-empty', `${lbl}.${k}: wymagany niepusty tekst`);
      else checkPlainString(e[k], c, `${lbl}.${k}`);
    }
    for (const k of ['ipa', 'ref']) if (e[k] !== undefined && typeof e[k] !== 'string') report.error(file, id, 'glossary-type', `${lbl}.${k}: musi być tekstem`);
    if (nonEmpty(e.form)) {
      const key = e.form.toLowerCase();
      if (forms.has(key)) report.error(file, id, 'glossary-duplicate', `${lbl}: zdublowana forma "${e.form}"`);
      forms.add(key);
      if (!formOccurs(paragraphs, e.form)) report.error(file, id, 'glossary-form', `${lbl}: forma "${e.form}" nie występuje dosłownie w tekście (dokładny podciąg na granicy słów)`);
    }
    if (nonEmpty(e.ipa) && !/^\/[^/]+\/$/.test(e.ipa)) report.error(file, id, 'ipa-format', `${lbl}: ipa "${e.ipa}" musi być w /.../`);
    if (e.ref !== undefined && typeof e.ref === 'string') {
      if (!/^[a-z0-9-]+\/[a-z0-9.-]+$/.test(e.ref)) report.error(file, id, 'glossary-ref', `${lbl}: ref "${e.ref}" musi mieć postać <plik>/<id>`);
      else if (refs && !refs.has(e.ref)) report.error(file, id, 'glossary-ref', `${lbl}: ref "${e.ref}" nie istnieje w dictionary-index.json`);
    }
  });
}

/**
 * Porównuje słowniczki w readings.json ze źródłem: lista id, w których są różnice (nieaktualne scalenie).
 */
export function staleGlossaries(readings, source) {
  const out = [];
  for (const r of readings) {
    const want = Array.isArray(source[r.id]) && source[r.id].length ? source[r.id].map(canonicalEntry) : undefined;
    const have = Array.isArray(r.glossary) ? r.glossary : undefined;
    if (JSON.stringify(want) !== JSON.stringify(have)) out.push(r.id);
  }
  return out;
}
