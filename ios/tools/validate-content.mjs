#!/usr/bin/env node
// FluentNOW — walidator treści wbudowanej (ios/FluentNOW/Resources/Content).
// Kontrakt: ios/docs/CONTENT-SCHEMA.md. Node 24, bez zależności npm.
//
// Użycie:
//   node ios/tools/validate-content.mjs                 # cała baza
//   node ios/tools/validate-content.mjs --file <ścieżka> [--file <ścieżka> ...]
//   node ios/tools/validate-content.mjs --json          # wynik maszynowy
//   node ios/tools/validate-content.mjs --errors-only   # bez ostrzeżeń w wyniku tekstowym
//   node ios/tools/validate-content.mjs --root <katalog> # inny katalog treści
//   node ios/tools/validate-content.mjs --self-test     # testy walidatora (fixtures)
// Kody wyjścia: 0 = brak błędów (ostrzeżenia nie zmieniają kodu), 1 = błędy, 2 = złe argumenty.

import fs from 'node:fs';
import path from 'node:path';
import { fileURLToPath } from 'node:url';

const TOOLS_DIR = path.dirname(fileURLToPath(import.meta.url));
export const DEFAULT_ROOT = path.resolve(TOOLS_DIR, '../FluentNOW/Resources/Content');
const FIXTURES_DIR = path.join(TOOLS_DIR, 'fixtures');

// ---------------------------------------------------------------------------
// Stałe kontraktu
// ---------------------------------------------------------------------------

export const GROUPS = {
  basics: 'Podstawy', travel: 'Podróże', food: 'Jedzenie i picie', home: 'Dom', health: 'Zdrowie',
  work: 'Praca i biznes', education: 'Nauka', technology: 'Technologia', money: 'Pieniądze i zakupy',
  services: 'Urzędy i usługi', people: 'Ludzie i relacje', daily: 'Codzienność', leisure: 'Czas wolny',
  nature: 'Przyroda', society: 'Społeczeństwo', communication: 'Komunikacja',
};
export const POS = ['rzeczownik', 'czasownik', 'czasownik frazowy', 'przymiotnik', 'przysłówek', 'zwrot', 'idiom',
  'przyimek', 'spójnik', 'zaimek', 'wykrzyknik', 'liczebnik'];
export const LEVELS = ['A1', 'A2', 'B1', 'B2', 'C1', 'C2'];
export const FREQUENCIES = ['very_common', 'common', 'less_common', 'rare'];
export const REGISTERS = ['neutralny', 'potoczny', 'formalny', 'specjalistyczny', 'slangowy'];

const ENTRY_SCHEMA = {
  id: 'string', term: 'string', ipa: 'string', pos: 'string', level: 'string', frequency: 'string',
  translation: 'string', definition: 'string', register: 'string', contextPl: 'string', natural: 'string',
  forms: 'string', collocations: 'string', synonyms: 'string', antonyms: 'string', notePl: 'string',
  examples: 'array', acceptedAnswers: 'array', acceptedTranslations: 'array',
};
const EXAMPLE_SCHEMA = { en: 'string', pl: 'string', focusEn: 'string', focusPl: 'string' };
const TOPIC_SCHEMA = {
  schemaVersion: 'integer', id: 'string', namePl: 'string', nameEn: 'string', group: 'string', symbol: 'string',
  summaryPl: 'string', aliases: 'array', categories: 'array',
};
const CATEGORY_SCHEMA = { id: 'string', namePl: 'string', scenePl: 'string', entries: 'array' };

const KEBAB = /^[a-z0-9]+(?:-[a-z0-9]+)*$/;

// ---------------------------------------------------------------------------
// Raportowanie
// ---------------------------------------------------------------------------

export class Report {
  constructor() { this.errors = []; this.warnings = []; this.files = 0; this.entries = 0; }
  add(severity, file, id, rule, message) {
    const issue = { file, id: id || '', rule, message };
    (severity === 'error' ? this.errors : this.warnings).push(issue);
  }
  error(file, id, rule, message) { this.add('error', file, id, rule, message); }
  warn(file, id, rule, message) { this.add('warning', file, id, rule, message); }
}

// ---------------------------------------------------------------------------
// Pomocnicze
// ---------------------------------------------------------------------------

export function typeOf(v) {
  if (v === null) return 'null';
  if (Array.isArray(v)) return 'array';
  if (typeof v === 'number') return Number.isInteger(v) ? 'integer' : 'number';
  return typeof v;
}

function typeMatches(v, expected) {
  const t = typeOf(v);
  if (expected === 'number') return t === 'number' || t === 'integer';
  return t === expected;
}

/** Sprawdza wymagane klucze i typy. Zwraca true, gdy obiekt ma poprawny kształt. */
export function checkShape(obj, schema, ctx, label, { unknownIsError = false, optional = {} } = {}) {
  const { report, file, id } = ctx;
  if (typeOf(obj) !== 'object') {
    report.error(file, id, 'type', `${label}: oczekiwano obiektu, jest ${typeOf(obj)}`);
    return false;
  }
  let ok = true;
  for (const [key, type] of Object.entries(schema)) {
    if (!(key in obj)) { report.error(file, id, 'missing-key', `${label}: brak klucza "${key}"`); ok = false; continue; }
    const v = obj[key];
    if (v === null) continue; // zgłaszane osobno przez findNulls
    if (!typeMatches(v, type)) {
      report.error(file, id, 'type', `${label}: "${key}" powinno być typu ${type}, jest ${typeOf(v)}`);
      ok = false;
    }
  }
  for (const [key, type] of Object.entries(optional)) {
    if (key in obj && obj[key] !== null && !typeMatches(obj[key], type)) {
      report.error(file, id, 'type', `${label}: "${key}" powinno być typu ${type}, jest ${typeOf(obj[key])}`);
      ok = false;
    }
  }
  for (const key of Object.keys(obj)) {
    if (!(key in schema) && !(key in optional)) {
      if (unknownIsError) report.error(file, id, 'unknown-key', `${label}: nieznany klucz "${key}"`);
      else report.warn(file, id, 'unknown-key', `${label}: nieznany klucz "${key}" (literówka?)`);
    }
  }
  return ok;
}

function findNulls(value, p, out) {
  if (value === null) { out.push(p || '(korzeń)'); return; }
  if (Array.isArray(value)) value.forEach((v, i) => findNulls(v, `${p}[${i}]`, out));
  else if (typeof value === 'object') for (const [k, v] of Object.entries(value)) findNulls(v, p ? `${p}.${k}` : k, out);
}

const str = (v) => (typeof v === 'string' ? v : '');

export function normalizeKey(s) {
  return str(s).normalize('NFD').replace(/[̀-ͯ]/g, '').replace(/ł/g, 'l').replace(/Ł/g, 'L')
    .replace(/[’‘`]/g, "'").toLowerCase().replace(/\s+/g, ' ').trim();
}

export function kebab(s) {
  return normalizeKey(s).replace(/'/g, '').replace(/[^a-z0-9]+/g, '-').replace(/^-+|-+$/g, '');
}

/** Podstawowe sprawdzenia każdego pola tekstowego. */
export function checkPlainString(s, ctx, label, { allowEmpty = true } = {}) {
  const { report, file, id } = ctx;
  if (typeof s !== 'string') return;
  if (!allowEmpty && s.trim() === '') { report.error(file, id, 'empty', `${label}: puste pole`); return; }
  if (s !== s.trim()) report.error(file, id, 'whitespace', `${label}: spacja na początku lub końcu: "${s}"`);
  if (/[\t\n\r]/.test(s)) report.error(file, id, 'whitespace', `${label}: tabulator lub nowa linia w tekście`);
  if (/ {2,}/.test(s)) report.error(file, id, 'double-space', `${label}: podwójna spacja: "${s}"`);
  if (s !== s.normalize('NFC')) report.error(file, id, 'unicode-nfc', `${label}: tekst nie jest w postaci Unicode NFC`);
  // eslint-disable-next-line no-control-regex
  if (/[\u0000-\u001f​﻿]/.test(s.replace(/[\t\n\r]/g, ''))) report.error(file, id, 'control-char', `${label}: niewidoczny znak sterujący`);
}

export function bracketsBalanced(s) {
  const pairs = { ')': '(', ']': '[', '}': '{' };
  const stack = [];
  for (const ch of s) {
    if (ch === '(' || ch === '[' || ch === '{') stack.push(ch);
    else if (ch in pairs) { if (stack.pop() !== pairs[ch]) return false; }
  }
  if (stack.length) return false;
  if ((s.match(/"/g) || []).length % 2) return false;
  if ((s.match(/[“”„]/g) || []).length % 2) return false;
  return true;
}

/** Sprawdzenia zdania (przykład en/pl). */
export function checkSentence(s, lang, ctx, label) {
  const { report, file, id } = ctx;
  if (typeof s !== 'string' || s.trim() === '') return;
  if (/\s[,.?!]/.test(s) && !/\s\.\.\./.test(s)) report.error(file, id, 'space-before-punct', `${label}: spacja przed znakiem interpunkcyjnym: "${s}"`);
  if (/\s[;:]/.test(s)) report.warn(file, id, 'space-before-punct', `${label}: spacja przed ; lub : — "${s}"`);
  if (/[,;:](?=[\p{L}])/u.test(s.replace(/\d[,:]\d/g, ''))) report.warn(file, id, 'space-after-punct', `${label}: brak spacji po przecinku/średniku/dwukropku: "${s}"`);
  if (!bracketsBalanced(s)) report.error(file, id, 'unbalanced', `${label}: niezrównoważone nawiasy lub cudzysłowy: "${s}"`);
  const first = s.match(/[\p{L}\p{N}]/u);
  if (first && /\p{Ll}/u.test(first[0])) report.error(file, id, 'capital-start', `${label}: zdanie nie zaczyna się wielką literą: "${s}"`);
  const endsOk = /[.?!]["'”’)\]»]*$/.test(s);
  if (!endsOk) {
    if (lang === 'en') report.error(file, id, 'end-punct', `${label}: zdanie musi kończyć się . ? lub !: "${s}"`);
    else report.warn(file, id, 'end-punct', `${label}: zdanie nie kończy się . ? lub !: "${s}"`);
  }
}

// --- Heurystyki angielskie ---------------------------------------------------

const BRITISH_SPELLING = [
  [/\b(colo|favo|behavio|neighbo|hono|humo|labo|flavo|harbo|rumo|savo|endeavo|vapo|armo|odo|parlo|vigo|rigo|splendo|tumo|clamo|ardo|cando)ur(s|ed|ing|ite|ites|able|ably|ful|fully|less|hood|hoods|ly|er|ers)?\b/i, (m) => m.replace(/our/i, 'or')],
  [/\b(cent|theat|met|lit|fib|sab|calib|somb|lust|spect|mit)re(s|d)?\b/i, (m) => m.replace(/re(s|d)?$/i, (x, suf) => 'er' + (suf || ''))],
  [/\b(organi|reali|recogni|apologi|speciali|criti|minimi|maximi|prioriti|categori|summari|memori|customi|finali|standardi|authori|utili|optimi|visuali|normali|personali|sociali|hospitali|sterili|immuni|stabili|moderni|legali|centrali|civili|globali|characteri|sympathi|harmoni|familiari|energi|fantasi|itemi|digiti|moneti|emphasi|computeri|vapori|scandali|tranquili|patroni|jeopardi|agoni|mobili|monopoli|subsidi|publici|baptis)s(e|es|ed|ing|ation|ations|er|ers)\b/i, (m) => m.replace(/s(e|es|ed|ing|ation|ations|er|ers)$/i, 'z$1')],
  [/\b(analy|paraly|cataly)s(e|ed|ing)\b/i, (m) => m.replace(/s(e|ed|ing)$/i, 'z$1')],
  [/\b(travel|cancel|label|model|fuel|level|signal|counsel|quarrel|tunnel|total|dial|channel|equal|marshal|pedal|shovel|snorkel|jewel|duel|cruel)l(ed|ing|er|ers|or|ors)\b/i, (m) => m.replace(/ll/i, 'l')],
  [/\b(jewellery|marvellous|enrolment|instalment|skilful|wilful|fulfil|enrol|enrols|distil)\b/i, null],
  [/\b(grey|greyish|cheque|cheques|tyre|tyres|kerb|pyjamas|aluminium|aeroplane|aeroplanes|programme|programmes|catalogue|analogue|licence|defence|offence|pretence|practise|practised|practising|practises|sceptic|sceptical|mould|mouldy|plough|storey|storeys|draught|manoeuvre|paediatric|paediatrician|anaemia|anaemic|anaesthesia|anaesthetic|haemorrhage|orthopaedic|oestrogen|foetus|diarrhoea|oesophagus|leukaemia|gynaecologist|gynaecology|encyclopaedia|whilst|amongst|learnt|spelt|dreamt|spoilt|ageing|cosy|moustache|sulphur|yoghurt|gaol|mum|mummy|mums)\b/i, null],
];
const BRITISH_SPELLING_SUGGEST = {
  jewellery: 'jewelry', marvellous: 'marvelous', enrolment: 'enrollment', instalment: 'installment', skilful: 'skillful',
  wilful: 'willful', fulfil: 'fulfill', enrol: 'enroll', enrols: 'enrolls', distil: 'distill', grey: 'gray', greyish: 'grayish',
  cheque: 'check', cheques: 'checks', tyre: 'tire', tyres: 'tires', kerb: 'curb', pyjamas: 'pajamas', aluminium: 'aluminum',
  aeroplane: 'airplane', aeroplanes: 'airplanes', programme: 'program', programmes: 'programs', catalogue: 'catalog',
  analogue: 'analog', licence: 'license', defence: 'defense', offence: 'offense', pretence: 'pretense', practise: 'practice',
  practised: 'practiced', practising: 'practicing', practises: 'practices', sceptic: 'skeptic', sceptical: 'skeptical',
  mould: 'mold', mouldy: 'moldy', plough: 'plow', storey: 'story', storeys: 'stories', draught: 'draft', manoeuvre: 'maneuver',
  paediatric: 'pediatric', paediatrician: 'pediatrician', anaemia: 'anemia', anaemic: 'anemic', anaesthesia: 'anesthesia',
  anaesthetic: 'anesthetic', haemorrhage: 'hemorrhage', orthopaedic: 'orthopedic', oestrogen: 'estrogen', foetus: 'fetus',
  diarrhoea: 'diarrhea', oesophagus: 'esophagus', leukaemia: 'leukemia', gynaecologist: 'gynecologist', gynaecology: 'gynecology',
  encyclopaedia: 'encyclopedia', whilst: 'while', amongst: 'among', learnt: 'learned', spelt: 'spelled', dreamt: 'dreamed',
  spoilt: 'spoiled', ageing: 'aging', cosy: 'cozy', moustache: 'mustache', sulphur: 'sulfur', yoghurt: 'yogurt', gaol: 'jail',
  // „mummy” pominięte: w AmE to też egipska mumia (temat history) — zbyt wiele fałszywych alarmów.
  mum: 'mom', mums: 'moms',
};

// Słownictwo typowo brytyjskie (często wieloznaczne → tylko ostrzeżenie).
const BRITISH_VOCAB = [
  [/(?<!\b(?:get|gets|got|gotten|getting|have|has|had)\s)\b(?:a|the|my|our|your|his|her|their|this|that|rented|shared|new|small|tiny|studio)\s+flat(?=\s*(?:[.!?;]|$)|\s+(?:in|on|at|near|with|is|was|has|had|for|downtown|upstairs|downstairs|above|below|and)\b)/,'apartment (jeśli „mieszkanie”)'],
  [/\bflat(?:mate|mates|share)\b/i, 'roommate'],
  [/\bblocks? of flats\b/i, 'apartment building'],
  [/\b(?:the|a)\s+lifts?\b/i, 'elevator / ride (jeśli „winda” / „podwózka”)'],
  [/\bqueu(?:e|es|ed|ing)\b/i, 'line / wait in line'],
  [/\b(?:on|go on|going on|went on|summer|school|christmas|easter)\s+holidays?\b|\bholiday(?:s)?\s+(?:home|let|maker|makers|abroad)\b|\bbank holiday\b/i, 'vacation (jeśli „urlop/wakacje”)'],
  [/\b(?:petrol|motorway|motorways|dustbin|postcode|postcodes|crisps|lorry|lorries|nappy|nappies|maths|aubergine|aubergines|courgette|courgettes|coriander|cashpoint|windscreen|candyfloss|candy floss|cling film|kitchen roll|tea towel|pram|prams)\b/i, 'odpowiednik amerykański'],
  [/\brubbish\b/i, 'trash / garbage'],
  [/\bpavements?\b/i, 'sidewalk'],
  [/\btrousers\b/i, 'pants'],
  [/\bbiscuits?\b/i, 'cookie(s) / cracker(s)'],
  [/\bcar parks?\b/i, 'parking lot'],
  [/\bchemist's\b|\b(?:at|to|from) the chemist\b/i, 'drugstore / pharmacy'],
  [/\bfortnights?\b/i, 'two weeks'],
  [/\bautumn\b/i, 'fall'],
  [/\bcooker\b/i, 'stove'],
  [/\b(?:mobile phones?|on (?:my|your|his|her|the) mobile)\b/i, 'cell phone'],
  [/\bhigh street\b/i, 'main street'],
  [/\bshop assistants?\b/i, 'sales clerk / salesperson'],
  [/\buni\b/i, 'college'],
  [/\bspring onions?\b/i, 'green onion(s) / scallion(s)'],
  [/\bjacket potato(?:es)?\b/i, 'baked potato'],
  [/\btakeaways?\b/i, 'takeout'],
  [/\bfizzy drinks?\b/i, 'soda'],
  [/\bnumber plates?\b/i, 'license plate'],
  [/\bzebra crossings?\b/i, 'crosswalk'],
  [/\breturn tickets?\b/i, 'round-trip ticket'],
  [/\bsingle ticket\b/i, 'one-way ticket'],
  [/\btrolley\b/i, 'cart'],
  [/\bcurrent account\b/i, 'checking account'],
  [/(?<!\breal )\bestate agents?\b/i, 'real estate agent'],
  [/\bA&E\b/, 'ER / emergency room'],
  [/\bGPs?\b/, 'doctor / primary care physician'],
  [/\bCVs?\b/, 'résumé'],
  [/\bhead ?teachers?\b/i, 'principal'],
  [/\bdressing gowns?\b/i, 'bathrobe'],
  [/\bwashing[- ]up\b/i, 'doing the dishes'],
  [/\bhoover(?:ed|ing|s)?\b/i, 'vacuum'],
  [/\bpostman\b/i, 'mail carrier / mailman'],
  [/\bfancy dress\b/i, 'costume'],
  [/\bfull stop\b/i, 'period'],
  [/\binverted commas\b/i, 'quotation marks'],
  [/\bsweets\b/i, 'candy'],
  [/\bloo\b/i, 'bathroom / restroom'],
  [/\b(?:the|to the)\s+cinema\b/i, 'movie theater / the movies'],
  [/\b(?:on|take|took|taking|by|ride|rode) the tube\b|\bthe tube (?:station|line|map)\b|\bthe underground\b/i, 'subway'],
  [/\b(?:pair of|running|gym|new|old|white|black) trainers\b/i, 'sneakers'],
  [/\bjumpers?\b(?!\s+cables?\b)/i, 'sweater'],
  [/\btorch(?:es)?\b/i, 'flashlight'],
  [/\bsolicitors?\b/i, 'lawyer / attorney'],
  [/\bminced meat\b|\b(?:the|some|of|beef|pork|lamb) mince\b/i, 'ground beef / ground meat'],
  [/\bporridge\b/i, 'oatmeal'],
  [/\bcar boot\b|\bboot of (?:the|my|your|his|her|our|their) car\b/i, 'trunk'],
  [/\bground floor\b/i, 'first floor'],
  [/\bparacetamol\b/i, 'acetaminophen / pain reliever'],
  [/\bwardrobes?\b/i, 'closet'],
  [/\btins? of\b/i, 'can of'],
  [/\b(?:give|gave|giving|gives) (?:me|you|him|her|us|them) a lift\b/i, 'give someone a ride'],
];

export function britishIssues(text) {
  const out = [];
  if (typeof text !== 'string' || !text) return out;
  for (const [re, suggest] of BRITISH_SPELLING) {
    const g = new RegExp(re.source, re.flags.includes('g') ? re.flags : re.flags + 'g');
    for (const m of text.matchAll(g)) {
      const word = m[0];
      const s = suggest ? suggest(word) : BRITISH_SPELLING_SUGGEST[word.toLowerCase()];
      out.push({ kind: 'spelling', word, suggest: s || '?' });
    }
  }
  for (const [re, suggest] of BRITISH_VOCAB) {
    const m = text.match(re);
    if (m) out.push({ kind: 'vocab', word: m[0], suggest });
  }
  return out;
}

const A_BEFORE_VOWEL_LETTER = /^(uni(?![nmd])|use|usa|usu|uti|ute|uto|ura|ure|uri|uro|ubiq|ukul|ukr|unanim|eu|ewe|one(?![a-z])|once|ouija)/i;
const AN_SILENT_H = /^(hour|honest|honor|honour|heir|herb)/i;
const LETTER_TAKES_AN = /^[AEFHILMNORSX]/;

export function articleIssues(text) {
  const out = [];
  if (typeof text !== 'string') return out;
  const re = /(^|[\s("“'‘—–-])(a|an|A|An)\s+([A-Za-z0-9][A-Za-z0-9'’-]*)/g;
  for (const m of text.matchAll(re)) {
    const article = m[2];
    const startIdx = m.index + m[1].length;
    if ((article === 'A' || article === 'An') && startIdx !== 0) {
      // „A” w środku zdania to zwykle litera (plan A), nie przedimek — pomiń, chyba że po końcu zdania.
      const before = text.slice(0, startIdx).trimEnd();
      if (!/[.?!:"“]$/.test(before)) continue;
    }
    const word = m[3];
    if (/^\d/.test(word)) continue;
    const isAn = article.toLowerCase() === 'an';
    let wantsAn;
    if (/^[A-Z]{2,}/.test(word) || /^[A-Z](-|$)/.test(word) || /^[a-z]-/.test(word)) wantsAn = LETTER_TAKES_AN.test(word[0].toUpperCase()); // skrótowiec / litera (X-ray, x-ray, e-mail, T-shirt)
    else if (AN_SILENT_H.test(word)) wantsAn = true;
    else if (/^[aeiou]/i.test(word)) wantsAn = !A_BEFORE_VOWEL_LETTER.test(word);
    else wantsAn = false;
    if (isAn !== wantsAn) out.push({ article, word, suggest: wantsAn ? 'an' : 'a' });
  }
  return out;
}

const REPEAT_OK = new Set(['had', 'that', 'is', 'bye', 'no', 'knock', 'so', 'very', 'really', 'well', 'now', 'there', 'ha', 'ho', 'oh', 'yes', 'tsk', 'chop', 'hush', 'night', 'far', 'more', 'over', 'round', 'again', 'on', 'and', 'by']);
export function repeatedWords(text) {
  const out = [];
  if (typeof text !== 'string') return out;
  for (const m of text.matchAll(/\b([A-Za-z']+)\s+\1\b/gi)) {
    if (m[1].toLowerCase() !== m[0].split(/\s+/)[1].toLowerCase()) continue;
    if (!REPEAT_OK.has(m[1].toLowerCase())) out.push(m[0]);
  }
  return out;
}

export function englishHeuristics(text, ctx, label, { article = true, repeat = true } = {}) {
  const { report, file, id } = ctx;
  for (const b of britishIssues(text)) {
    const what = b.kind === 'spelling' ? 'pisownia brytyjska' : 'możliwe słownictwo brytyjskie';
    report.warn(file, id, b.kind === 'spelling' ? 'british-spelling' : 'british-vocab', `${label}: ${what} "${b.word}" → AmE: ${b.suggest}`);
  }
  if (article) for (const a of articleIssues(text)) report.warn(file, id, 'article', `${label}: "${a.article} ${a.word}" — prawdopodobnie powinno być "${a.suggest}"`);
  if (repeat) for (const r of repeatedWords(text)) report.warn(file, id, 'repeated-word', `${label}: powtórzone słowo "${r}"`);
}

const AME_BRE_TAG = /\((?:AmE|BrE)\)/i;

// --- Heurystyki redakcyjne (z raportów english-qa; tylko ostrzeżenia) --------

// Comma splice: dwa zdania główne połączone samym przecinkiem („Hurry up, the bus…”, „He's so sweet, he left…”).
// Wyjątki: zdanie podrzędne lub wstęp przed przecinkiem, wtrącenia, zdanie relacjonujące („…, she told us.”),
// kontrast po przeczeniu („I didn't block him, I just muted him.”, „It's not X, it's Y.”), cytaty w cudzysłowie.
const SPLICE_SUBORD = /^(?:if|when|whenever|because|since|although|though|even|while|before|after|once|unless|as|until|till|now that|by the time|so that|in case|whether|where|wherever|whatever|whoever|however|no matter|every time|the moment|the minute|next time|last time|the first time|the last time|like i said|like you said|given that|considering|assuming|provided)\b/i;
const SPLICE_INTRO = /^(?:yes|yeah|yep|no|nope|oh|ah|well|ok|okay|sorry|please|thanks|thank you|honestly|actually|luckily|sadly|unfortunately|fortunately|hopefully|apparently|seriously|basically|anyway|besides|also|plus|first|second|third|finally|lastly|next|then|so|but|and|or|today|tonight|tomorrow|yesterday|usually|sometimes|normally|again|of course|excuse me|hey|hi|hello|wow|ugh|look|listen|trust me|believe me|in fact|for example|for instance|to be honest|to be fair|in my opinion|personally|frankly|by the way|at first|at least|after all|on the other hand|meanwhile|still|instead|otherwise|ideally|technically|in short|in general|generally|overall|right|sure|fine|great|perfect|alright|all right|this time|that way|either way|on second thought|come on|mark my words|between you and me|for what it's worth|if anything|last week|last year|last night|last month|this morning|this week|this weekend|this year|every morning|every day|every year|away from|the other day|one day|the next day|that day|that night|the next morning|the next thing i knew)\b/i;
const SPLICE_PREP = /^(?:in|on|off|at|after|before|during|for|from|to|with|without|by|like|unlike|despite|through|throughout|around|over|under|between|among|across|along|behind|beyond|near|outside|inside|within|upon|toward|towards|against|about|according to|thanks to|due to|because of|instead of|apart from|other than|compared to|compared with|as for)\b/i;
const SPLICE_AFTER = /,\s+(?:(?:I|you|we|they|he|she|it|that|there|this)(?:'s|'re|'m|'ll|'ve|'d)\b|(?:I|you|we|they|he|she|it|that|there|this)\s+(?:is|are|was|were|am|will|won't|have|has|had|can|can't|could|couldn't|should|shouldn't|must|need|needs|do|does|did|don't|doesn't|didn't|just|really|always|never|also|probably|still|already|totally|definitely|usually|look|looks|seem|seems|want|wants|think|know|love|hate|get|got|go|went|made|left|came)\b)/g;
const SPLICE_COMMENT = /^\s*(?:(?:I|you|he|she|we|they)\s+(?:said|says|told|tells|explained|added|admitted|joked|insisted|replied|warned|wrote|asked|promised|swear|bet|guess|think|mean|know|recall|remember|hope)\b[^,.;!?]{0,30}|you'll see|you know|I promise|I swear|I bet|I guess|I think|I hope)[.!?]["”]?$/;

/** Fragmenty zdania EN, w których przecinek łączy dwa zdania główne. */
export function commaSplices(text) {
  const out = [];
  if (typeof text !== 'string') return out;
  const clean = text.replace(/"[^"]*"|“[^”]*”/g, (m) => ' '.repeat(m.length));
  for (const m of clean.matchAll(SPLICE_AFTER)) {
    const before = clean.slice(0, m.index);
    const cut = Math.max(...['. ', '? ', '! ', '; ', ': ', ' — ', ' – '].map((p) => before.lastIndexOf(p)));
    const seg = before.slice(cut >= 0 ? cut + 2 : 0).trim();
    const lastComma = seg.lastIndexOf(',');
    const clause = lastComma >= 0 ? seg.slice(lastComma + 1).trim() : seg;
    const after = clean.slice(m.index + 1);
    if (seg.split(/\s+/).length < 3) continue; // „Yes, I…”, „Mom, we…”, „Hurry up, …”
    if ([seg, clause].some((x) => SPLICE_SUBORD.test(x) || SPLICE_INTRO.test(x) || SPLICE_PREP.test(x) || /^\w+ing\b/i.test(x))) continue;
    if (/\b(?:ago|later|earlier)$/i.test(seg)) continue; // „Five years ago, …”
    if (/^(?:the|my|our|your) (?:thing|problem|point|truth|fact|good news|bad news|best part|catch|question|idea|plan) is$/i.test(seg)) continue;
    if (/\b(?:if|when|because|since|although|though|while|unless|until|before|after|once|whenever|so that)\b/i.test(clause)) continue;
    if (SPLICE_COMMENT.test(after)) continue; // „…, she told us.” / „…, you know.”
    if (/^\s*(?:you know|I mean),/.test(after)) continue; // wtrącenie „…, you know, …”
    if (/^\w+ or \w+$/i.test(seg)) continue; // „Cabin or hotel, I…”
    const neg = /n't\b|\b(?:not|never|no longer)\b/i.test(clause);
    if (neg && /^\s*(?:\S+\s+){1,2}(?:just|only|simply|actually|rather)\b/i.test(after)) continue; // „I didn't X, I just Y”
    if (neg && /^(?:it|that|this)\b/i.test(clause) && /^\s*(?:it|that|this)\b/i.test(after)) continue; // „It's not X, it's Y”
    out.push(text.slice(Math.max(0, m.index - 30), m.index + 25).trim());
  }
  return out;
}

function thirdPersonOf(base) {
  const irregular = { have: 'has', be: 'is', do: 'does', go: 'goes' };
  if (irregular[base]) return irregular[base];
  if (/(s|sh|ch|x|z|o)$/.test(base)) return base + 'es';
  if (/[^aeiou]y$/.test(base)) return base.slice(0, -1) + 'ies';
  return base + 's';
}

/**
 * `forms` czasownika (CONTENT-SCHEMA §1): „forma bazowa – czas przeszły – imiesłów” od formy hasła.
 * Zwraca opis problemu albo null. Dla zwrotów/idiomów sprawdza tylko zapis trzech form zaczynający się od 3. os. lp.
 */
export function verbFormsIssue(term, pos, forms) {
  if (typeof forms !== 'string' || !forms || typeof term !== 'string') return null;
  const isVerb = pos === 'czasownik' || pos === 'czasownik frazowy';
  const verbal = isVerb || ((pos === 'zwrot' || pos === 'idiom') && (forms.match(/\s–\s/g) || []).length >= 2);
  if (!verbal) return null;
  const first = forms.split(/\s*;\s*/)[0].split(/\s+–\s+/)[0].trim();
  const words = term.split(' ');
  const third = [thirdPersonOf(words[0].toLowerCase()), ...words.slice(1)].join(' ');
  if (first.toLowerCase() !== term.toLowerCase() && first.toLowerCase() === third.toLowerCase()) return `zaczyna się od 3. os. lp. („${first}”) zamiast formy bazowej „${term}”`;
  if (!isVerb) return null;
  if (!/\s–\s/.test(forms)) return `brak zapisu „forma bazowa – czas przeszły – imiesłów” („${forms}”)`;
  if (first.toLowerCase() !== term.toLowerCase()) return `pierwsza forma „${first}” nie jest formą hasła „${term}”`;
  return null;
}

// Angielskie „Sorry/OK” w polskim zdaniu (po polsku: przepraszam, wybacz, dobrze, w porządku, okej).
export const PL_ENGLISH_WORD = /(?<![\p{L}])(?:Sorry|sorry|Okay|okay|OK|Ok|ok)(?![\p{L}])/u;

// Nieprzeliczone jednostki imperialne w polskim zdaniu (liczba + mila/stopa/cal/funt/jard/uncja/galon, mph, °F).
const PL_NUM = '(?:\\d+(?:[.,]\\d+)?|pół|półtorej|półtora|jed\\p{L}*|dw\\p{L}*|trz\\p{L}*|czter\\p{L}*|pię\\p{L}*|sze\\p{L}*|sied\\p{L}*|osi\\p{L}*|dziew\\p{L}*|dzies\\p{L}*|kilk\\p{L}*|par\\p{L}*|wiel\\p{L}*|set\\p{L}*|sto|stu|tysi\\p{L}*)';
const PL_UNIT = '(?:mil[ae]?|mili|milach|stóp|stopy|stopach|cal[ae]?|cali|calach|funt(?:ów|y|a|ach)?|jard(?:ów|y|a|ach)?|uncj[ie]|uncji|galon(?:ów|y|a|ach)?)';
export const PL_IMPERIAL = new RegExp(`(?<![\\p{L}])${PL_NUM}\\s+${PL_UNIT}(?![\\p{L}])|\\bmph\\b|°F|Fahrenheit\\p{L}*`, 'iu');
// Hasła, w których sama jednostka / pomiar jest tematem — wtedy jednostka zostaje w tłumaczeniu.
const UNIT_TERM = /\b(?:inch(?:es)?|foot|feet|pounds?|miles?|yards?|ounces?|gallons?|fahrenheit|mph|degrees?|width|depth|height|length|area|radius|volume|altitude|boiling point)\b/i;

// ---------------------------------------------------------------------------
// Entry (§1)
// ---------------------------------------------------------------------------

function ipaIssues(ipa, term) {
  const out = [];
  if (!ipa) return out;
  if (/ɒ/.test(ipa)) out.push('„ɒ” to samogłoska brytyjska (GA: ɑː / ɔː)');
  if (/əʊ/.test(ipa)) out.push('„əʊ” to dyftong brytyjski (GA: oʊ)');
  if (/(?<![aɔeo])(?:ɪə|ʊə)|eə/.test(ipa)) out.push('dyftong centralny brytyjski (ɪə/eə/ʊə) — GA: ɪr/er/ʊr');
  if (/ɜ(?!ːr|r)/.test(ipa)) out.push('„ɜː” bez „r” — GA jest rotyczny (ɜːr / ɝ)');
  const lastWord = str(term).trim().split(/\s+/).pop() || '';
  if (/(?:er|or|ar|ure|our)$/i.test(lastWord) && /ə\/$/.test(ipa)) out.push('końcowe „ə” dla -er/-or — GA wymawia r (ər / ɚ)');
  return out;
}

/**
 * Waliduje pojedynczy wpis Entry.
 * @param prefix — oczekiwany prefiks id (topicId lub "starter")
 */
export function validateEntry(e, prefix, ctx, loc) {
  const { report, file } = ctx;
  const id = typeOf(e) === 'object' && typeof e.id === 'string' && e.id ? e.id : loc;
  const c = { report, file, id };
  if (!checkShape(e, ENTRY_SCHEMA, c, 'wpis')) {
    if (typeOf(e) !== 'object') return;
  }
  report.entries++;

  // id
  if (typeof e.id === 'string') {
    const m = e.id.match(/^([a-z0-9]+(?:-[a-z0-9]+)*)\.([a-z0-9]+(?:-[a-z0-9]+)*)$/);
    if (!m) report.error(file, id, 'id-format', `id "${e.id}" musi mieć postać <${prefix}>.<kebab-case>`);
    else {
      if (prefix && m[1] !== prefix) report.error(file, id, 'id-prefix', `id "${e.id}" musi zaczynać się od "${prefix}."`);
      const slug = m[2].replace(/-\d+$/, '');
      const expected = kebab(e.term);
      if (expected && slug !== expected && m[2] !== expected) report.warn(file, id, 'id-slug', `id "${e.id}" nie odpowiada hasłu "${str(e.term)}" (oczekiwano ".${expected}" lub ".${expected}-2")`);
    }
  }

  for (const key of Object.keys(ENTRY_SCHEMA)) {
    if (ENTRY_SCHEMA[key] === 'string') checkPlainString(e[key], c, key);
  }

  // term
  if (typeof e.term === 'string') {
    if (!e.term.trim()) report.error(file, id, 'empty', 'term: puste hasło');
    if (/\.$/.test(e.term) && !/\b[a-z]\.[a-z]\.$/i.test(e.term)) report.error(file, id, 'term-period', `term "${e.term}" nie może kończyć się kropką`);
    const words = e.term.split(/[\s-]+/).filter((w) => w !== 'I' && !/^I'/.test(w));
    // Nazwy własne (Monday, French press, Wi-Fi) są OK; ostrzegamy, gdy przykłady używają hasła małymi literami.
    const lowerInExamples = Array.isArray(e.examples) && e.examples.some((x) => typeof x?.en === 'string' && x.en.slice(1).includes(e.term.toLowerCase()) && e.term.toLowerCase() !== e.term);
    if (lowerInExamples && words.some((w) => /\p{Lu}/u.test(w) && !/^[\p{Lu}\d&]+s?$/u.test(w))) report.warn(file, id, 'term-case', `term "${e.term}" zawiera wielkie litery (dozwolone tylko nazwy własne i „I”)`);
    englishHeuristics(e.term, c, 'term', { article: false, repeat: false });
  }

  // ipa
  if (typeof e.ipa === 'string') {
    if (e.ipa !== '' && !/^\/[^/]+\/$/.test(e.ipa)) report.error(file, id, 'ipa-format', `ipa "${e.ipa}" musi być w ukośnikach /.../ albo ""`);
    if (e.ipa === '' && typeof e.term === 'string' && e.term.trim() && !/\s/.test(e.term.trim())) report.warn(file, id, 'ipa-missing', `brak IPA dla pojedynczego słowa "${e.term}"`);
    for (const msg of ipaIssues(e.ipa, e.term)) report.warn(file, id, 'ipa-british', `ipa "${e.ipa}": ${msg}`);
  }

  // enumy
  if (typeof e.pos === 'string' && !POS.includes(e.pos)) report.error(file, id, 'enum-pos', `pos "${e.pos}" — dozwolone: ${POS.join(', ')}`);
  if (typeof e.level === 'string' && !LEVELS.includes(e.level)) report.error(file, id, 'enum-level', `level "${e.level}" — dozwolone: ${LEVELS.join(', ')}`);
  if (typeof e.frequency === 'string' && !FREQUENCIES.includes(e.frequency)) report.error(file, id, 'enum-frequency', `frequency "${e.frequency}" — dozwolone: ${FREQUENCIES.join(', ')}`);
  if (typeof e.register === 'string' && !REGISTERS.includes(e.register)) report.error(file, id, 'enum-register', `register "${e.register}" — dozwolone: ${REGISTERS.join(', ')}`);

  // translation
  if (typeof e.translation === 'string') {
    if (!e.translation.trim()) report.error(file, id, 'empty', 'translation: puste tłumaczenie');
    if (AME_BRE_TAG.test(e.translation)) report.error(file, id, 'ame-bre-tag', `translation "${e.translation}" zawiera (AmE)/(BrE)`);
  }

  // definition
  if (typeof e.definition === 'string') {
    if (!e.definition.trim()) report.error(file, id, 'empty', 'definition: pusta definicja');
    else {
      if (e.definition.length > 140) report.error(file, id, 'definition-length', `definition ma ${e.definition.length} znaków (max 140)`);
      if (/[.?!]\s+[A-Z]/.test(e.definition)) report.warn(file, id, 'definition-sentences', 'definition: powinna być jednym zdaniem');
      if (/^\p{Ll}/u.test(e.definition)) report.warn(file, id, 'definition-style', 'definition: zacznij wielką literą');
      if (!/[.?!]$/.test(e.definition)) report.warn(file, id, 'definition-style', 'definition: zakończ kropką');
      if (!bracketsBalanced(e.definition)) report.error(file, id, 'unbalanced', 'definition: niezrównoważone nawiasy lub cudzysłowy');
      englishHeuristics(e.definition, c, 'definition');
    }
  }

  // contextPl
  if (typeof e.contextPl === 'string') {
    if (!e.contextPl.trim()) report.warn(file, id, 'empty', 'contextPl: puste (kiedy się tego używa?)');
    if (e.contextPl.length > 80) report.error(file, id, 'contextpl-length', `contextPl ma ${e.contextPl.length} znaków (max 80)`);
    if (AME_BRE_TAG.test(e.contextPl)) report.error(file, id, 'ame-bre-tag', 'contextPl zawiera (AmE)/(BrE)');
  }
  if (typeof e.notePl === 'string' && AME_BRE_TAG.test(e.notePl)) report.warn(file, id, 'ame-bre-tag', 'notePl zawiera (AmE)/(BrE) — zwykle zbędne, cała treść jest amerykańska');

  for (const key of ['natural', 'forms', 'collocations']) {
    if (typeof e[key] === 'string' && e[key]) englishHeuristics(e[key], c, key, { article: key !== 'forms', repeat: key !== 'forms' });
  }
  const formsIssue = verbFormsIssue(e.term, e.pos, e.forms);
  if (formsIssue) report.warn(file, id, 'forms-base', `forms: ${formsIssue}`);
  const unitTopic = typeof e.term === 'string' && UNIT_TERM.test(e.term);

  // examples
  if (Array.isArray(e.examples)) {
    if (e.examples.length !== 2) report.error(file, id, 'examples-count', `examples: musi być dokładnie 2, jest ${e.examples.length}`);
    e.examples.forEach((ex, i) => {
      const lbl = `przykład ${i + 1}`;
      if (!checkShape(ex, EXAMPLE_SCHEMA, c, lbl)) { if (typeOf(ex) !== 'object') return; }
      for (const k of Object.keys(EXAMPLE_SCHEMA)) checkPlainString(ex[k], c, `${lbl}.${k}`, { allowEmpty: false });
      if (typeof ex.en === 'string' && typeof ex.focusEn === 'string' && ex.focusEn && !ex.en.includes(ex.focusEn)) {
        report.error(file, id, 'focus-en', `${lbl}: focusEn "${ex.focusEn}" nie jest dokładnym podciągiem en "${ex.en}"`);
      }
      if (typeof ex.pl === 'string' && typeof ex.focusPl === 'string' && ex.focusPl && !ex.pl.includes(ex.focusPl)) {
        report.error(file, id, 'focus-pl', `${lbl}: focusPl "${ex.focusPl}" nie jest dokładnym podciągiem pl "${ex.pl}"`);
      }
      checkSentence(ex.en, 'en', c, `${lbl}.en`);
      checkSentence(ex.pl, 'pl', c, `${lbl}.pl`);
      if (typeof ex.pl === 'string') {
        const en = ex.pl.match(PL_ENGLISH_WORD);
        if (en) report.warn(file, id, 'pl-english', `${lbl}.pl: angielskie „${en[0]}” w polskim zdaniu (przepraszam / wybacz / dobrze / w porządku): "${ex.pl}"`);
        const unit = ex.pl.match(PL_IMPERIAL);
        if (unit && !unitTopic) report.warn(file, id, 'pl-imperial-units', `${lbl}.pl: nieprzeliczona jednostka „${unit[0]}” — w polskim zdaniu użyj km, m, kg, °C: "${ex.pl}"`);
      }
      if (typeof ex.en === 'string') {
        for (const sp of commaSplices(ex.en)) report.warn(file, id, 'comma-splice', `${lbl}.en: przecinek łączy dwa zdania główne („${sp}”) — użyj ; . lub spójnika`);
        englishHeuristics(ex.en, c, `${lbl}.en`);
        const words = ex.en.split(/\s+/).filter(Boolean).length;
        if (words < 4 || words > 25) report.warn(file, id, 'example-length', `${lbl}.en ma ${words} słów (zalecane 6–20)`);
      }
      if (typeof ex.pl === 'string' && AME_BRE_TAG.test(ex.pl)) report.error(file, id, 'ame-bre-tag', `${lbl}.pl zawiera (AmE)/(BrE)`);
      if (typeof ex.en === 'string' && typeof ex.pl === 'string' && ex.en.trim() && ex.en.trim() === ex.pl.trim()) report.error(file, id, 'example-untranslated', `${lbl}: pl identyczne z en`);
    });
    if (e.examples.length === 2 && typeof e.examples[0]?.en === 'string' && e.examples[0]?.en === e.examples[1]?.en) {
      report.error(file, id, 'duplicate-example', 'oba przykłady są identyczne');
    }
  }

  // acceptedAnswers
  if (Array.isArray(e.acceptedAnswers)) {
    if (e.acceptedAnswers.length === 0) report.error(file, id, 'accepted-answers', 'acceptedAnswers: pusta lista (musi zawierać term)');
    if (e.acceptedAnswers.some((a) => typeof a !== 'string' || !a.trim())) report.error(file, id, 'accepted-answers', 'acceptedAnswers: elementy muszą być niepustymi tekstami');
    else {
      e.acceptedAnswers.forEach((a, i) => {
        checkPlainString(a, c, `acceptedAnswers[${i}]`);
        if (a.includes(';')) report.warn(file, id, 'accepted-format', `acceptedAnswers[${i}] "${a}": średnik — każdy wariant musi być osobną pozycją (grader nie dzieli pozycji)`);
      });
      const norm = e.acceptedAnswers.map(normalizeKey);
      if (typeof e.term === 'string' && e.term && !norm.includes(normalizeKey(e.term))) report.error(file, id, 'accepted-answers-term', `acceptedAnswers nie zawiera hasła "${e.term}"`);
      if (new Set(norm).size !== norm.length) report.warn(file, id, 'accepted-duplicates', 'acceptedAnswers: zdublowane warianty');
    }
  }

  // acceptedTranslations
  if (Array.isArray(e.acceptedTranslations)) {
    const n = e.acceptedTranslations.length;
    if (n < 1 || n > 8) report.error(file, id, 'accepted-translations-count', `acceptedTranslations: wymagane 1–8 elementów, jest ${n}`);
    if (e.acceptedTranslations.some((a) => typeof a !== 'string' || !a.trim())) report.error(file, id, 'accepted-translations', 'acceptedTranslations: elementy muszą być niepustymi tekstami');
    else {
      e.acceptedTranslations.forEach((a, i) => {
        checkPlainString(a, c, `acceptedTranslations[${i}]`);
        if (AME_BRE_TAG.test(a)) report.error(file, id, 'ame-bre-tag', `acceptedTranslations[${i}] zawiera (AmE)/(BrE)`);
        if (a.includes(';')) report.warn(file, id, 'accepted-format', `acceptedTranslations[${i}] "${a}": średnik — każdy wariant musi być osobną pozycją (grader nie dzieli pozycji)`);
      });
      const norm = e.acceptedTranslations.map((a) => a.toLowerCase().replace(/\s+/g, ' ').trim());
      if (new Set(norm).size !== norm.length) report.warn(file, id, 'accepted-duplicates', 'acceptedTranslations: zdublowane warianty');
      if (typeof e.translation === 'string' && e.translation.trim() && !translationCovered(e.translation, e.acceptedTranslations)) {
        report.error(file, id, 'accepted-translations-translation', `acceptedTranslations nie zawiera tłumaczenia "${e.translation}" ani jego rdzenia`);
      }
    }
  }
}

function translationCovered(translation, accepted) {
  const clean = (s) => normalizeKey(s).replace(/\([^)]*\)/g, ' ').replace(/[^\p{L}\p{N}' -]/gu, ' ').replace(/\s+/g, ' ').trim();
  const parts = translation.split(/[;,/]| lub | albo /).map(clean).filter(Boolean);
  const acc = accepted.map(clean).filter(Boolean);
  for (const p of parts) {
    for (const a of acc) {
      if (a === p) return true;
      if (a.length >= 3 && p.includes(a)) return true;
      if (p.length >= 3 && a.includes(p)) return true;
      const k = Math.min(5, p.length, a.length);
      if (k >= 4 && a.slice(0, k) === p.slice(0, k)) return true;
    }
  }
  return false;
}

// ---------------------------------------------------------------------------
// Pliki
// ---------------------------------------------------------------------------

function validateTopic(data, ctx, expectedId) {
  const { report, file } = ctx;
  const tid = typeof data?.id === 'string' ? data.id : '';
  const c = { report, file, id: tid || '(temat)' };
  checkShape(data, TOPIC_SCHEMA, c, 'temat');
  if (typeOf(data) !== 'object') return;
  if (data.schemaVersion !== 1) report.error(file, c.id, 'schema-version', `schemaVersion musi być 1, jest ${JSON.stringify(data.schemaVersion)}`);
  if (typeof data.id === 'string') {
    if (!KEBAB.test(data.id)) report.error(file, c.id, 'topic-id', `id tematu "${data.id}" musi być kebab-case (a-z, 0-9, -)`);
    if (expectedId && data.id !== expectedId) report.error(file, c.id, 'topic-id-filename', `id tematu "${data.id}" musi być równe nazwie pliku "${expectedId}.json"`);
  }
  for (const k of ['namePl', 'nameEn', 'summaryPl', 'symbol']) {
    checkPlainString(data[k], c, k, { allowEmpty: false });
  }
  if (typeof data.group === 'string' && !(data.group in GROUPS)) report.error(file, c.id, 'enum-group', `group "${data.group}" — dozwolone: ${Object.keys(GROUPS).join(', ')}`);
  if (typeof data.symbol === 'string' && data.symbol && !/^[a-z0-9]+(?:\.[a-z0-9]+)*$/.test(data.symbol)) report.error(file, c.id, 'symbol-format', `symbol "${data.symbol}" nie wygląda jak nazwa SF Symbol`);
  if (typeof data.summaryPl === 'string' && data.summaryPl.length > 160) report.warn(file, c.id, 'summary-length', `summaryPl ma ${data.summaryPl.length} znaków (zalecane ≤ 160)`);
  if (Array.isArray(data.aliases)) {
    if (data.aliases.length === 0) report.warn(file, c.id, 'aliases', 'aliases: pusta lista (wyszukiwanie tematu)');
    data.aliases.forEach((a, i) => {
      if (typeof a !== 'string' || !a.trim()) report.error(file, c.id, 'aliases', `aliases[${i}]: musi być niepustym tekstem`);
      else checkPlainString(a, c, `aliases[${i}]`);
    });
  }
  if (!Array.isArray(data.categories)) return;
  const nCat = data.categories.length;
  if (nCat < 4 || nCat > 9) report.warn(file, c.id, 'topic-size', `temat ma ${nCat} kategorii (zalecane 4–9)`);
  const catIds = new Set();
  const termTr = new Map();
  let total = 0;
  data.categories.forEach((cat, ci) => {
    const cid = typeof cat?.id === 'string' && cat.id ? cat.id : `${c.id}#kategoria${ci + 1}`;
    const cc = { report, file, id: cid };
    checkShape(cat, CATEGORY_SCHEMA, cc, 'kategoria');
    if (typeOf(cat) !== 'object') return;
    if (typeof cat.id === 'string') {
      if (!new RegExp(`^${escapeRe(tid)}\\.[a-z0-9]+(?:-[a-z0-9]+)*$`).test(cat.id)) report.error(file, cid, 'category-id', `id kategorii "${cat.id}" musi mieć postać ${tid}.<kebab-case>`);
      if (catIds.has(cat.id)) report.error(file, cid, 'duplicate-id', `zdublowane id kategorii "${cat.id}"`);
      catIds.add(cat.id);
    }
    checkPlainString(cat.namePl, cc, 'namePl', { allowEmpty: false });
    checkPlainString(cat.scenePl, cc, 'scenePl', { allowEmpty: false });
    if (!Array.isArray(cat.entries)) return;
    if (cat.entries.length === 0) report.error(file, cid, 'category-empty', 'kategoria nie ma wpisów');
    total += cat.entries.length;
    cat.entries.forEach((e, ei) => {
      validateEntry(e, tid, ctx, `${cid}#wpis${ei + 1}`);
      if (typeOf(e) === 'object' && typeof e.term === 'string' && typeof e.translation === 'string') {
        const key = normalizeKey(e.term) + '|' + normalizeKey(e.translation);
        if (termTr.has(key)) report.error(file, e.id || cid, 'duplicate-term-translation', `powtórzone term+translation "${e.term}" / "${e.translation}" (już w ${termTr.get(key)})`);
        else termTr.set(key, e.id || cid);
      }
    });
  });
  if (total < 60 || total > 120) report.warn(file, c.id, 'topic-size', `temat ma ${total} wpisów (zalecane 60–120)`);
}

function escapeRe(s) { return s.replace(/[.*+?^${}()|[\]\\]/g, '\\$&'); }

function validateStarterWords(data, ctx) {
  const { report, file } = ctx;
  const c = { report, file, id: '(plik)' };
  checkShape(data, { schemaVersion: 'integer', source: 'string', words: 'array' }, c, 'starter-words');
  if (typeOf(data) !== 'object' || !Array.isArray(data.words)) return;
  const termTr = new Map();
  data.words.forEach((e, i) => {
    validateEntry(e, 'starter', ctx, `starter#${i + 1}`);
    if (typeOf(e) === 'object' && typeof e.term === 'string' && typeof e.translation === 'string') {
      const key = normalizeKey(e.term) + '|' + normalizeKey(e.translation);
      if (termTr.has(key)) report.error(file, e.id, 'duplicate-term-translation', `powtórzone term+translation "${e.term}" / "${e.translation}"`);
      else termTr.set(key, e.id);
    }
  });
}

// Banki ze strony: walidatory dopisywane w bank-validators (ładowane leniwie, jeśli istnieją).
let bankValidators = null;
async function loadBankValidators() {
  if (bankValidators !== null) return bankValidators;
  const p = path.join(TOOLS_DIR, 'lib', 'bank-validators.mjs');
  if (fs.existsSync(p)) {
    try { bankValidators = await import(new URL(`file:///${p.replace(/\\/g, '/')}`).href); }
    catch (err) { bankValidators = {}; console.error(`Nie udało się wczytać ${p}: ${err.message}`); }
  } else bankValidators = {};
  return bankValidators;
}

const BANK_FILES = ['grammar.json', 'exercises.json', 'idioms.json', 'readings.json', 'recommendations.json', 'answer-variants.json'];

/** Klasyfikuje plik na podstawie ścieżki i zawartości. */
function classify(absPath, data) {
  const base = path.basename(absPath);
  const parent = path.basename(path.dirname(absPath));
  if (parent === 'topics' && base === 'index.json') return 'topics-index';
  if (base === 'dictionary-index.json') return 'dictionary-index';
  if (base === 'starter-words.json') return 'starter-words';
  if (BANK_FILES.includes(base)) return base.replace('.json', '');
  if (parent === 'grammar' && /^(A1|A2|B1|B2|C1|C2)\.json$/.test(base)) return 'grammar-level';
  if (parent === 'topics') return 'topic';
  if (typeOf(data) === 'object' && Array.isArray(data.categories)) return 'topic';
  if (typeOf(data) === 'object' && Array.isArray(data.words)) return 'starter-words';
  // Rozpoznanie po kształcie (fixtures poza katalogiem treści).
  if (typeOf(data) === 'object') {
    if (typeof data.level === 'string' && Array.isArray(data.items)) return 'grammar-level';
    if (Array.isArray(data.readings)) return 'readings';
    if (typeOf(data.levels) === 'object') {
      const first = Object.values(data.levels).find((v) => Array.isArray(v) && v.length)?.[0];
      return first && 'distractors' in first ? 'exercises' : 'idioms';
    }
  }
  return 'unknown';
}

function readJson(absPath, report, rel) {
  let text;
  try { text = fs.readFileSync(absPath, 'utf8'); }
  catch (err) { report.error(rel, '', 'read', `nie można odczytać pliku: ${err.message}`); return undefined; }
  if (text.charCodeAt(0) === 0xfeff) report.error(rel, '', 'bom', 'plik zaczyna się od BOM — zapisz jako UTF-8 bez BOM');
  if (/\r\n/.test(text)) report.warn(rel, '', 'crlf', 'końce linii CRLF — zalecane LF');
  try { return JSON.parse(text.replace(/^﻿/, '')); }
  catch (err) { report.error(rel, '', 'json-parse', `niepoprawny JSON: ${err.message}`); return undefined; }
}

async function validateFile(absPath, data, report, rel) {
  report.files++;
  const nulls = [];
  findNulls(data, '', nulls);
  for (const p of nulls.slice(0, 20)) report.error(rel, '', 'null', `wartość null w "${p}" (użyj "" lub [])`);
  if (nulls.length > 20) report.error(rel, '', 'null', `… i jeszcze ${nulls.length - 20} wartości null`);
  const kind = classify(absPath, data);
  const ctx = { report, file: rel, absPath };
  if (kind !== 'topic' && kind !== 'unknown' && typeOf(data) === 'object' && data.schemaVersion !== 1) {
    report.error(rel, '', 'schema-version', `schemaVersion musi być 1, jest ${JSON.stringify(data.schemaVersion)}`);
  }
  switch (kind) {
    case 'topic': {
      const inTopics = path.basename(path.dirname(absPath)) === 'topics';
      validateTopic(data, ctx, inTopics ? path.basename(absPath, '.json') : null);
      break;
    }
    case 'starter-words': validateStarterWords(data, ctx); break;
    case 'unknown': report.warn(rel, '', 'unknown-file', 'nieznany typ pliku — sprawdzono tylko poprawność JSON i null'); break;
    default: {
      const bv = await loadBankValidators();
      const fn = bv.validators?.[kind];
      if (typeof fn === 'function') fn(data, ctx, { checkEntry: validateEntry, checkSentence, checkPlainString, englishHeuristics, checkShape, typeOf });
    }
  }
  return kind;
}

/** Zbiera wpisy Entry (tematy + starter) do kontroli globalnych. */
function collectEntries(data, kind) {
  const out = [];
  if (typeOf(data) !== 'object') return out;
  if (kind === 'topic' && Array.isArray(data.categories)) {
    for (const cat of data.categories) if (cat && Array.isArray(cat.entries)) for (const e of cat.entries) if (typeOf(e) === 'object') out.push(e);
  } else if (kind === 'starter-words' && Array.isArray(data.words)) {
    for (const e of data.words) if (typeOf(e) === 'object') out.push(e);
  }
  return out;
}

function listJsonFiles(dir) {
  const out = [];
  if (!fs.existsSync(dir)) return out;
  for (const ent of fs.readdirSync(dir, { withFileTypes: true })) {
    const p = path.join(dir, ent.name);
    if (ent.isDirectory()) out.push(...listJsonFiles(p));
    else if (ent.isFile() && ent.name.endsWith('.json')) out.push(p);
  }
  return out.sort();
}

function relPath(abs, root) {
  const r = path.relative(root, abs);
  if (!r.startsWith('..') && !path.isAbsolute(r)) return r.split(path.sep).join('/');
  return abs.split(path.sep).join('/');
}

/**
 * Główna funkcja walidacji.
 * @param {{root?: string, files?: string[]}} opts — gdy `files` podane, raportowane są tylko problemy tych plików,
 *   ale unikalność id i przykładów sprawdzana jest względem całej bazy (jeśli plik leży w katalogu treści).
 */
export async function validate({ root = DEFAULT_ROOT, files = null } = {}) {
  const report = new Report();
  const absRoot = path.resolve(root);
  const targets = files ? files.map((f) => path.resolve(f)) : listJsonFiles(absRoot);
  const targetSet = new Set(targets);

  // Pula globalna: id i przykłady z pozostałych plików tematów/starter (tylko do porównań).
  const pool = []; // { file, kind, entries, isTarget }
  for (const abs of targets) {
    const rel = relPath(abs, absRoot);
    if (!fs.existsSync(abs)) { report.error(rel, '', 'read', 'plik nie istnieje'); continue; }
    const data = readJson(abs, report, rel);
    if (data === undefined) continue;
    const kind = await validateFile(abs, data, report, rel);
    pool.push({ file: rel, entries: collectEntries(data, kind), isTarget: true });
  }
  if (files) {
    const inRoot = targets.some((t) => !path.relative(absRoot, t).startsWith('..'));
    if (inRoot) {
      for (const abs of listJsonFiles(absRoot)) {
        if (targetSet.has(abs)) continue;
        const base = path.basename(abs);
        const parent = path.basename(path.dirname(abs));
        const isTopic = parent === 'topics' && base !== 'index.json';
        if (!isTopic && base !== 'starter-words.json') continue;
        let data;
        try { data = JSON.parse(fs.readFileSync(abs, 'utf8').replace(/^﻿/, '')); } catch { continue; } // cudzy plik w trakcie zapisu
        pool.push({ file: relPath(abs, absRoot), entries: collectEntries(data, isTopic ? 'topic' : 'starter-words'), isTarget: false });
      }
    }
  }

  // Kontrole globalne: id wpisów, identyczne przykłady.
  const ids = new Map();
  const examples = new Map();
  // Najpierw pliki nie-docelowe, żeby duplikat był zgłaszany w pliku docelowym.
  const ordered = [...pool.filter((p) => !p.isTarget), ...pool.filter((p) => p.isTarget)];
  for (const { file, entries, isTarget } of ordered) {
    for (const e of entries) {
      if (typeof e.id === 'string' && e.id) {
        const prev = ids.get(e.id);
        if (prev && isTarget) report.error(file, e.id, 'duplicate-id', `id "${e.id}" występuje już w ${prev}`);
        if (!prev) ids.set(e.id, file);
      }
      if (Array.isArray(e.examples)) {
        e.examples.forEach((ex, i) => {
          if (!ex || typeof ex.en !== 'string' || !ex.en.trim()) return;
          const key = ex.en.trim().replace(/\s+/g, ' ');
          const prev = examples.get(key);
          if (prev && isTarget && !(prev.file === file && prev.id === e.id)) {
            report.error(file, e.id, 'duplicate-example', `przykład ${i + 1} "${ex.en}" jest identyczny z przykładem w ${prev.file}:${prev.id}`);
          }
          if (!prev) examples.set(key, { file, id: e.id });
        });
      }
    }
  }
  return report;
}

// ---------------------------------------------------------------------------
// Wyjście
// ---------------------------------------------------------------------------

function printText(report, { errorsOnly = false } = {}) {
  const line = (i) => `  ${i.file}${i.id ? ':' + i.id : ''}: ${i.message}`;
  if (report.errors.length) {
    console.log(`BŁĘDY (${report.errors.length}):`);
    for (const i of report.errors) console.log(line(i));
  }
  if (!errorsOnly && report.warnings.length) {
    console.log(`OSTRZEŻENIA (${report.warnings.length}):`);
    for (const i of report.warnings) console.log(line(i));
  }
  const status = report.errors.length ? 'NIE PRZESZŁO' : 'OK';
  console.log(`${status}: plików ${report.files}, wpisów ${report.entries}, błędów ${report.errors.length}, ostrzeżeń ${report.warnings.length}`);
}

function toJson(report) {
  return {
    ok: report.errors.length === 0,
    files: report.files,
    entries: report.entries,
    errorCount: report.errors.length,
    warningCount: report.warnings.length,
    errors: report.errors,
    warnings: report.warnings,
  };
}

// ---------------------------------------------------------------------------
// Self-test
// ---------------------------------------------------------------------------

async function selfTest() {
  let failures = 0;
  const check = (cond, msg) => { if (!cond) { failures++; console.log(`  ✗ ${msg}`); } };

  // Heurystyki jednostkowe
  const art = (s) => articleIssues(s).map((x) => `${x.article} ${x.word}`);
  check(art('I need an umbrella and a car.').length === 0, 'a/an: poprawne zdanie bez uwag');
  check(art('She is a honest person.').join() === 'a honest', 'a/an: „a honest” → an');
  check(art('It was an useful tip.').join() === 'an useful', 'a/an: „an useful” → a');
  check(art('He studies at a university and has an MBA.').length === 0, 'a/an: wyjątki university / MBA');
  check(art('I waited an hour for a one-way ticket.').length === 0, 'a/an: wyjątki hour / one-way');
  check(art('She got an X-ray and a T-shirt.').length === 0, 'a/an: litery X-ray / T-shirt');
  check(art('He needs an x-ray and an e-mail, not a u-turn.').length === 0, 'a/an: x-ray / e-mail / u-turn małymi literami');
  check(ipaIssues('/ˈtiːm ˌpleɪər ˈloʊər/', 'player').length === 0, 'IPA: trójgłoski eɪə / oʊə w GA');
  check(art('That was an unforgettable trip and an uninformed choice.').length === 0, 'a/an: un- przedrostek');
  check(art('It was a apple.').join() === 'a apple', 'a/an: „a apple” → an');
  check(art('Plan A is ready.').length === 0, 'a/an: „Plan A” to nie przedimek');
  check(art('A apple a day.').join() === 'A apple', 'a/an: wielkie A na początku zdania');
  check(britishIssues('My favourite colour is grey.').length === 3, 'BrE: favourite/colour/grey');
  check(britishIssues('We travelled to the city centre to organise it.').length === 3, 'BrE: travelled/centre/organise');
  check(britishIssues('The rise of a promise is wise.').length === 0, 'BrE: brak fałszywych -ise');
  check(britishIssues('We stood in the queue for the lift.').length === 2, 'BrE: queue / lift');
  check(britishIssues('I got a flat tire on the way.').length === 0, 'BrE: flat tire nie jest „flat” = mieszkanie');
  check(britishIssues('My color and favorite theater are here.').length === 0, 'AmE: brak uwag');
  check(britishIssues('A flat, moving path at the airport.').length === 0, 'BrE: „A flat,” przymiotnik na początku definicji');
  check(britishIssues('We rented a small flat downtown.').length === 1, 'BrE: „small flat downtown” = mieszkanie');
  check(ipaIssues('/ˈpaʊər ˈwaɪərləs ˈtɜːrmɪnl/', 'power').length === 0, 'IPA: trójgłoski GA i ɜːr bez uwag');
  check(ipaIssues('/ˈkʌlə/', 'colour').length === 1 && ipaIssues('/bɜːd/', 'bird').length === 1 && ipaIssues('/ɡəʊ/', 'go').length === 1, 'IPA: wzorce brytyjskie');
  check(repeatedWords('I put the the bag down.').join() === 'the the', 'powtórzone słowo „the the”');
  check(repeatedWords('She had had enough.').length === 0, '„had had” jest dozwolone');
  check(bracketsBalanced('He said "hi" (twice).') && !bracketsBalanced('He said "hi (twice).'), 'nawiasy i cudzysłowy');
  check(bracketsBalanced('Powiedział „cześć”.') && !bracketsBalanced('Powiedział „cześć.'), 'polskie cudzysłowy');
  // Reguły redakcyjne (comma splice, forms, „Sorry/OK” po polsku, średnik w wariantach, jednostki)
  check(commaSplices('Hurry up, the bus leaves soon. He is so sweet, he left me a note.').length === 1, 'comma splice: „He is so sweet, he left…”');
  check(commaSplices("He's so cheap, he won't pay his share.").length === 1, 'comma splice: „He\'s so cheap, he won\'t…”');
  check(commaSplices("Don't touch that plant, it's poison ivy.").length === 1, 'comma splice: tryb rozkazujący + uzasadnienie');
  check(commaSplices("I didn't block him, I just muted him.").length === 0, 'comma splice: wyjątek kontrastu „I didn\'t…, I just…”');
  check(commaSplices("It's not a bug, it's a feature.").length === 0, 'comma splice: wyjątek „It\'s not X, it\'s Y”');
  check(commaSplices('If you need help, I can stay late.').length === 0, 'comma splice: zdanie podrzędne przed przecinkiem');
  check(commaSplices('Yes, I saw it. Mom, we are home.').length === 0, 'comma splice: krótki wstęp / wołacz');
  check(commaSplices('Ten publishers rejected her first book, she told us.').length === 0, 'comma splice: zdanie relacjonujące');
  check(commaSplices('"Wait, I forgot my keys," she said.').length === 0, 'comma splice: cytat pomijany');
  check(commaSplices('After dinner, we watched a movie, and then we went to bed.').length === 0, 'comma splice: wstęp + spójnik');
  check(verbFormsIssue('cancel', 'czasownik', 'cancels – canceled – canceled') !== null, 'forms: 3. os. lp. zamiast formy bazowej');
  check(verbFormsIssue('hurry up', 'czasownik frazowy', 'hurries up – hurried up – hurried up') !== null, 'forms: 3. os. lp. w czasowniku frazowym');
  check(verbFormsIssue('watch', 'czasownik', 'watched; watching') !== null, 'forms: brak trzech form („past; -ing”)');
  check(verbFormsIssue('go', 'czasownik', 'go – went – gone') === null, 'forms: „go – went – gone” poprawne');
  check(verbFormsIssue('stop', 'czasownik', 'stop – stopped – stopped; stopping') === null, 'forms: grupa -ing po średniku poprawna');
  check(verbFormsIssue('take a nap', 'zwrot', 'takes a nap – took a nap – taken a nap') !== null, 'forms: zwrot od 3. os. lp.');
  check(verbFormsIssue('couch potato', 'idiom', 'couch potatoes') === null && verbFormsIssue('boarding pass', 'rzeczownik', 'boarding passes') === null, 'forms: liczba mnoga rzeczownika bez uwag');
  check(PL_ENGLISH_WORD.test('Sorry, kochanie, dziś nie mogę.') && PL_ENGLISH_WORD.test('Czy dżinsy są OK?'), 'pl: „Sorry” / „OK” w polskim zdaniu');
  check(!PL_ENGLISH_WORD.test('Przepraszam, w porządku, okej.') && !PL_ENGLISH_WORD.test('Okno w pokoju było otwarte.'), 'pl: brak fałszywych trafień „ok” w wyrazach');
  check(PL_IMPERIAL.test('Nasz dom jest dwie mile stąd.') && PL_IMPERIAL.test('Poproszę pięć funtów ziemniaków.') && PL_IMPERIAL.test('Jest siedemdziesiąt stopni Fahrenheita.'), 'pl: jednostki imperialne');
  check(!PL_IMPERIAL.test('Mile widziani są wszyscy goście.') && !PL_IMPERIAL.test('Bolą mnie stopy po dwóch godzinach marszu.') && !PL_IMPERIAL.test('Dom jest trzy kilometry stąd.'), 'pl: „mile widziany”, „stopy” (część ciała) i km bez uwag');
  check(normalizeKey(' Żółć  Don’t ') === "zolc don't", 'normalizeKey');
  check(kebab('check-in desk') === 'check-in-desk' && kebab("don't") === 'dont', 'kebab');

  // Fixtures
  const fixtures = fs.existsSync(FIXTURES_DIR) ? fs.readdirSync(FIXTURES_DIR).filter((f) => f.endsWith('.json') && !f.endsWith('.expected.json')).sort() : [];
  check(fixtures.length > 0, 'brak plików w ios/tools/fixtures');
  for (const f of fixtures) {
    const abs = path.join(FIXTURES_DIR, f);
    const expPath = abs.replace(/\.json$/, '.expected.json');
    const report = await validate({ root: FIXTURES_DIR, files: [abs] });
    if (fs.existsSync(expPath)) {
      const exp = JSON.parse(fs.readFileSync(expPath, 'utf8'));
      const gotE = new Set(report.errors.map((i) => i.rule));
      const gotW = new Set(report.warnings.map((i) => i.rule));
      for (const r of exp.errors || []) check(gotE.has(r), `${f}: oczekiwano błędu "${r}"`);
      for (const r of exp.warnings || []) check(gotW.has(r), `${f}: oczekiwano ostrzeżenia "${r}"`);
      for (const r of exp.notErrors || []) check(!gotE.has(r), `${f}: nieoczekiwany błąd "${r}"`);
      for (const r of exp.notWarnings || []) check(!gotW.has(r), `${f}: nieoczekiwane ostrzeżenie "${r}"`);
      if (exp.exactErrorRules) {
        const extra = [...gotE].filter((r) => !(exp.errors || []).includes(r));
        check(extra.length === 0, `${f}: nieoczekiwane reguły błędów: ${extra.join(', ')}`);
      }
      console.log(`  • ${f}: ${report.errors.length} błędów, ${report.warnings.length} ostrzeżeń (zgodnie z ${path.basename(expPath)})`);
    } else {
      check(report.errors.length === 0, `${f}: plik poprawny nie powinien mieć błędów, ma ${report.errors.length}: ${report.errors.slice(0, 5).map((i) => `${i.id}: ${i.message}`).join(' | ')}`);
      console.log(`  • ${f}: ${report.errors.length} błędów, ${report.warnings.length} ostrzeżeń`);
    }
  }
  if (failures) { console.log(`SELF-TEST NIE PRZESZEDŁ (${failures} niepowodzeń)`); return 1; }
  console.log('SELF-TEST OK');
  return 0;
}

// ---------------------------------------------------------------------------
// CLI
// ---------------------------------------------------------------------------

function usage() {
  console.error('Użycie: node ios/tools/validate-content.mjs [--file <ścieżka>]... [--json] [--errors-only] [--root <katalog>] [--self-test]');
}

async function main(argv) {
  const files = [];
  let json = false; let errorsOnly = false; let root = DEFAULT_ROOT; let self = false;
  for (let i = 0; i < argv.length; i++) {
    const a = argv[i];
    if (a === '--file' || a === '-f') { if (!argv[i + 1]) { usage(); return 2; } files.push(argv[++i]); }
    else if (a.startsWith('--file=')) files.push(a.slice(7));
    else if (a === '--json') json = true;
    else if (a === '--errors-only' || a === '--quiet') errorsOnly = true;
    else if (a === '--root') { if (!argv[i + 1]) { usage(); return 2; } root = argv[++i]; }
    else if (a === '--self-test') self = true;
    else if (a === '--help' || a === '-h') { usage(); return 0; }
    else if (!a.startsWith('-')) files.push(a);
    else { console.error(`Nieznana opcja: ${a}`); usage(); return 2; }
  }
  if (self) return selfTest();
  const report = await validate({ root, files: files.length ? files : null });
  if (json) process.stdout.write(JSON.stringify(toJson(report), null, 2) + '\n');
  else printText(report, { errorsOnly });
  return report.errors.length ? 1 : 0;
}

const isMain = process.argv[1] && path.resolve(process.argv[1]) === fileURLToPath(import.meta.url);
if (isMain) {
  main(process.argv.slice(2)).then((code) => { process.exitCode = code; }, (err) => { console.error(err); process.exitCode = 1; });
}
