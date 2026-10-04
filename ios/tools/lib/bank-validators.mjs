// Walidatory banków przeniesionych ze strony (CONTENT-SCHEMA §4–§5) oraz indeksów (§2, §3).
// Ładowane leniwie przez validate-content.mjs. Każdy walidator: (data, ctx) => void, ctx = { report, file, absPath }.

import fs from 'node:fs';
import path from 'node:path';
import {
  LEVELS, GROUPS, typeOf, checkShape, checkPlainString, englishHeuristics, bracketsBalanced, normalizeKey,
} from '../validate-content.mjs';

const DIAGNOSES = ['wrong_tense', 'wrong_aspect', 'wrong_voice', 'wrong_agreement', 'wrong_word'];
const AME_BRE_TAG = /\((?:AmE|BrE)\)/i;
const HEADER = { schemaVersion: 'integer', source: 'string' };

const nonEmpty = (v) => typeof v === 'string' && v.trim() !== '';
const answerKey = (s) => normalizeKey(s).replace(/[.!?,;:]+$/g, '');

function strings(arr, c, label, { allowEmptyList = true } = {}) {
  const { report, file, id } = c;
  if (!Array.isArray(arr)) return;
  if (!allowEmptyList && arr.length === 0) report.error(file, id, 'empty', `${label}: pusta lista`);
  arr.forEach((s, i) => {
    if (!nonEmpty(s)) report.error(file, id, 'type', `${label}[${i}]: musi być niepustym tekstem`);
    else checkPlainString(s, c, `${label}[${i}]`);
  });
}

function requireText(obj, keys, c) {
  for (const k of keys) {
    if (typeof obj[k] !== 'string') continue;
    if (!obj[k].trim()) c.report.error(c.file, c.id, 'empty', `${k}: puste pole`);
    else checkPlainString(obj[k], c, k);
  }
}

function polishText(s, c, label) {
  if (!nonEmpty(s)) return;
  if (AME_BRE_TAG.test(s)) c.report.error(c.file, c.id, 'ame-bre-tag', `${label} zawiera (AmE)/(BrE)`);
  if (!bracketsBalanced(s)) c.report.warn(c.file, c.id, 'unbalanced', `${label}: niezrównoważone nawiasy lub cudzysłowy: "${s}"`);
}

function englishSentence(s, c, label) {
  if (!nonEmpty(s)) return;
  if (!bracketsBalanced(s)) c.report.warn(c.file, c.id, 'unbalanced', `${label}: niezrównoważone nawiasy lub cudzysłowy: "${s}"`);
  if (/\s[,.?!](?!\.\.)/.test(s)) c.report.warn(c.file, c.id, 'space-before-punct', `${label}: spacja przed znakiem interpunkcyjnym: "${s}"`);
  englishHeuristics(s, c, label);
}

// ---------------------------------------------------------------------------
// ProductionItem (grammar/<L>.json, exercises.json)
// ---------------------------------------------------------------------------

const PRODUCTION_SCHEMA = {
  bankId: 'string', context: 'string', hintPl: 'string', answer: 'string', acceptedAnswers: 'array',
  distractors: 'array', rule: 'string', explanation: 'string', translation: 'string',
};

function validateProductionItem(item, c, seenIds) {
  const { report, file } = c;
  checkShape(item, PRODUCTION_SCHEMA, c, 'zadanie', { optional: { scenarioId: 'string' } });
  if (typeOf(item) !== 'object') return;
  if (nonEmpty(item.bankId)) {
    if (seenIds.has(item.bankId)) report.error(file, c.id, 'duplicate-id', `zdublowane bankId "${item.bankId}"`);
    seenIds.add(item.bankId);
  }
  requireText(item, ['bankId', 'context', 'hintPl', 'answer', 'rule', 'explanation', 'translation'], c);
  if (typeof item.context === 'string') {
    if (!/_{2,}/.test(item.context)) report.error(file, c.id, 'gap-missing', `context nie zawiera luki ________: "${item.context}"`);
    if (nonEmpty(item.hintPl) && !item.context.includes(`(${item.hintPl})`)) report.warn(file, c.id, 'hint-missing', `context nie zawiera podpowiedzi "(${item.hintPl})"`);
    if (nonEmpty(item.answer)) {
      const filled = item.context.replace(/_{2,}\s*\([^)]*\)/, item.answer).replace(/_{2,}/, item.answer);
      englishSentence(filled, c, 'context (z odpowiedzią)');
      if (!/[.?!]["'”’)]*$/.test(filled)) report.warn(file, c.id, 'end-punct', `context nie kończy się . ? !: "${item.context}"`);
    }
  }
  polishText(item.translation, c, 'translation');
  strings(item.acceptedAnswers, c, 'acceptedAnswers');
  if (Array.isArray(item.distractors)) {
    if (item.distractors.length === 0) report.error(file, c.id, 'distractors-count', 'distractors: pusta lista');
    else if (item.distractors.length < 3) report.warn(file, c.id, 'distractors-count', `distractors: ${item.distractors.length} (strona uzupełnia do 3 formą „to …”)`);
    const correct = new Set([item.answer, ...(Array.isArray(item.acceptedAnswers) ? item.acceptedAnswers : [])].filter(nonEmpty).map(answerKey));
    const forms = new Set();
    item.distractors.forEach((d, i) => {
      const lbl = `distractors[${i}]`;
      checkShape(d, { form: 'string', diagnosis: 'string', explanation: 'string' }, c, lbl);
      if (typeOf(d) !== 'object') return;
      requireText(d, ['form', 'explanation'], c);
      if (nonEmpty(d.form)) englishHeuristics(d.form, c, `${lbl}.form`, { article: false, repeat: false });
      if (typeof d.diagnosis === 'string' && !DIAGNOSES.includes(d.diagnosis)) report.error(file, c.id, 'enum-diagnosis', `${lbl}.diagnosis "${d.diagnosis}" — dozwolone: ${DIAGNOSES.join(', ')}`);
      if (nonEmpty(d.form)) {
        if (correct.has(answerKey(d.form))) report.error(file, c.id, 'distractor-is-answer', `${lbl}: dystraktor "${d.form}" jest poprawną odpowiedzią`);
        if (forms.has(answerKey(d.form))) report.error(file, c.id, 'duplicate-distractor', `${lbl}: zdublowany dystraktor "${d.form}"`);
        forms.add(answerKey(d.form));
      }
    });
  }
}

function validateGrammarLevel(data, ctx) {
  const c = { ...ctx, id: '(plik)' };
  checkShape(data, { ...HEADER, version: 'integer', level: 'string', rules: 'array', items: 'array' }, c, 'grammar');
  if (typeOf(data) !== 'object') return;
  const expected = path.basename(ctx.absPath || '', '.json');
  if (typeof data.level === 'string' && !LEVELS.includes(data.level)) ctx.report.error(ctx.file, c.id, 'enum-level', `level "${data.level}"`);
  if (LEVELS.includes(expected) && data.level !== expected) ctx.report.error(ctx.file, c.id, 'level-filename', `level "${data.level}" różni się od nazwy pliku ${expected}.json`);
  strings(data.rules, c, 'rules');
  if (!Array.isArray(data.items)) return;
  if (data.items.length === 0) ctx.report.error(ctx.file, c.id, 'empty', 'items: pusta lista');
  const seen = new Set();
  data.items.forEach((item, i) => {
    const id = nonEmpty(item?.bankId) ? item.bankId : `item#${i + 1}`;
    validateProductionItem(item, { ...ctx, id }, seen);
    if (Array.isArray(data.rules) && nonEmpty(item?.rule) && !data.rules.includes(item.rule)) ctx.report.warn(ctx.file, id, 'rule-unknown', `rule "${item.rule}" nie występuje w rules poziomu`);
  });
}

function validateLevels(data, ctx, label, fn) {
  const c = { ...ctx, id: '(plik)' };
  if (typeOf(data?.levels) !== 'object') { ctx.report.error(ctx.file, c.id, 'missing-key', `${label}: brak obiektu "levels"`); return; }
  for (const l of LEVELS) if (!Array.isArray(data.levels[l]) || data.levels[l].length === 0) ctx.report.error(ctx.file, c.id, 'level-missing', `${label}: brak lub pusty poziom ${l}`);
  for (const k of Object.keys(data.levels)) if (!LEVELS.includes(k)) ctx.report.error(ctx.file, c.id, 'enum-level', `${label}: nieznany poziom "${k}"`);
  const seen = new Set();
  for (const l of LEVELS) (Array.isArray(data.levels[l]) ? data.levels[l] : []).forEach((item, i) => fn(item, { ...ctx, id: nonEmpty(item?.bankId) ? item.bankId : `${l}#${i + 1}` }, seen));
}

function validateExercises(data, ctx) {
  checkShape(data, { ...HEADER, version: 'integer', levels: 'object' }, { ...ctx, id: '(plik)' }, 'exercises');
  validateLevels(data, ctx, 'exercises', validateProductionItem);
}

// ---------------------------------------------------------------------------
// PracticeQuestion (idioms.json)
// ---------------------------------------------------------------------------

function validatePracticeQuestion(q, c, seen) {
  const { report, file } = c;
  checkShape(q, { category: 'string', prompt: 'string', context: 'string', options: 'array', answer: 'integer', explanation: 'string', translation: 'string' }, c, 'pytanie',
    { optional: { format: 'string', inputHint: 'string', acceptedAnswers: 'array', bankId: 'string', scenarioId: 'string' } });
  if (typeOf(q) !== 'object') return;
  if (nonEmpty(q.bankId)) { if (seen.has(q.bankId)) report.error(file, c.id, 'duplicate-id', `zdublowane bankId "${q.bankId}"`); seen.add(q.bankId); }
  if (typeof q.category === 'string' && !['grammar', 'idiom'].includes(q.category)) report.error(file, c.id, 'enum-category', `category "${q.category}"`);
  if (q.format !== undefined && !['choice', 'input'].includes(q.format)) report.error(file, c.id, 'enum-format', `format "${q.format}"`);
  requireText(q, ['prompt', 'context', 'explanation', 'translation'], c);
  strings(q.options, c, 'options', { allowEmptyList: false });
  if (q.acceptedAnswers !== undefined) strings(q.acceptedAnswers, c, 'acceptedAnswers');
  if (Array.isArray(q.options)) {
    if (q.options.length !== 4) report.error(file, c.id, 'options-count', `options: wymagane 4, jest ${q.options.length}`);
    if (new Set(q.options.map(answerKey)).size !== q.options.length) report.error(file, c.id, 'duplicate-option', 'options: zdublowane odpowiedzi');
    if (Number.isInteger(q.answer) && (q.answer < 0 || q.answer >= q.options.length)) report.error(file, c.id, 'answer-range', `answer ${q.answer} poza zakresem options`);
  }
  englishSentence(q.context, c, 'context');
  polishText(q.translation, c, 'translation');
}

function validateIdioms(data, ctx) {
  checkShape(data, { ...HEADER, levels: 'object' }, { ...ctx, id: '(plik)' }, 'idioms');
  validateLevels(data, ctx, 'idioms', validatePracticeQuestion);
}

// ---------------------------------------------------------------------------
// Reading (readings.json)
// ---------------------------------------------------------------------------

const flat = (s) => String(s).replace(/[“”„]/g, '"').replace(/[‘’]/g, "'").replace(/\s+/g, ' ').trim().toLowerCase();

function validateReadings(data, ctx) {
  const { report, file } = ctx;
  checkShape(data, { ...HEADER, readings: 'array' }, { ...ctx, id: '(plik)' }, 'readings');
  if (!Array.isArray(data?.readings)) return;
  const ids = new Set();
  const titles = new Map();
  data.readings.forEach((r, ri) => {
    const id = nonEmpty(r?.id) ? r.id : `reading#${ri + 1}`;
    const c = { ...ctx, id };
    checkShape(r, { id: 'string', title: 'string', level: 'string', topic: 'string', paragraphs: 'array', questions: 'array', source: 'string' }, c, 'czytanka');
    if (typeOf(r) !== 'object') return;
    if (ids.has(id)) report.error(file, id, 'duplicate-id', `zdublowane id "${id}"`);
    ids.add(id);
    if (nonEmpty(r.title)) {
      if (titles.has(r.title)) report.warn(file, id, 'duplicate-title', `tytuł "${r.title}" powtarza się (${titles.get(r.title)})`);
      titles.set(r.title, id);
    }
    if (typeof r.level === 'string' && !LEVELS.includes(r.level)) report.error(file, id, 'enum-level', `level "${r.level}"`);
    requireText(r, ['id', 'title'], c);
    strings(r.paragraphs, c, 'paragraphs', { allowEmptyList: false });
    const text = flat((Array.isArray(r.paragraphs) ? r.paragraphs : []).join(' '));
    (Array.isArray(r.paragraphs) ? r.paragraphs : []).forEach((p, i) => englishSentence(p, c, `paragraphs[${i}]`));
    if (!Array.isArray(r.questions)) return;
    if (r.questions.length === 0) report.error(file, id, 'empty', 'questions: brak pytań');
    else if (r.questions.length < 3) report.warn(file, id, 'questions-count', `tylko ${r.questions.length} pytania (zalecane ≥ 3)`);
    r.questions.forEach((q, qi) => {
      const lbl = `questions[${qi}]`;
      checkShape(q, { question: 'string', options: 'array', answer: 'integer', explanation: 'string', evidence: 'string' }, c, lbl, { optional: { meaningId: 'string' } });
      if (typeOf(q) !== 'object') return;
      requireText(q, ['question', 'explanation', 'evidence'], c);
      strings(q.options, c, `${lbl}.options`, { allowEmptyList: false });
      if (Array.isArray(q.options)) {
        if (q.options.length !== 4) report.error(file, id, 'options-count', `${lbl}: wymagane 4 opcje, jest ${q.options.length}`);
        if (new Set(q.options.map(answerKey)).size !== q.options.length) report.error(file, id, 'duplicate-option', `${lbl}: zdublowane opcje`);
        if (Number.isInteger(q.answer) && (q.answer < 0 || q.answer >= q.options.length)) report.error(file, id, 'answer-range', `${lbl}: answer ${q.answer} poza zakresem options (${q.options.length})`);
      }
      if (nonEmpty(q.evidence)) {
        const parts = flat(q.evidence).split(/\s*(?:\.\.\.|…)\s*/).filter(Boolean);
        if (!parts.every((p) => text.includes(p.replace(/[.,;:!?"]+$/, '')))) report.warn(file, id, 'evidence-not-found', `${lbl}: evidence nie jest dosłownym fragmentem tekstu: "${q.evidence}"`);
      }
      polishText(q.explanation, c, `${lbl}.explanation`);
    });
  });
}

// ---------------------------------------------------------------------------
// Recommendations, answer variants
// ---------------------------------------------------------------------------

function validateRecommendations(data, ctx) {
  const { report, file } = ctx;
  checkShape(data, { ...HEADER, items: 'array' }, { ...ctx, id: '(plik)' }, 'recommendations');
  if (!Array.isArray(data?.items)) return;
  const terms = new Set();
  data.items.forEach((r, i) => {
    const id = nonEmpty(r?.term) ? r.term : `item#${i + 1}`;
    const c = { ...ctx, id };
    checkShape(r, { known: 'string', term: 'string', level: 'string', translation: 'string', difference: 'string', example: 'string', examplePl: 'string' }, c, 'rekomendacja', { optional: { ipa: 'string' } });
    if (typeOf(r) !== 'object') return;
    requireText(r, ['known', 'term', 'translation', 'difference', 'example', 'examplePl'], c);
    if (terms.has(id)) report.error(file, id, 'duplicate-id', `zdublowany term "${id}"`);
    terms.add(id);
    if (typeof r.level === 'string' && !LEVELS.includes(r.level)) report.error(file, id, 'enum-level', `level "${r.level}"`);
    if (nonEmpty(r.ipa) && !/^\/[^/]+\/$/.test(r.ipa)) report.error(file, id, 'ipa-format', `ipa "${r.ipa}" musi być w /.../`);
    if (nonEmpty(r.example) && nonEmpty(r.term) && !r.example.toLowerCase().includes(r.term.toLowerCase())) report.warn(file, id, 'example-term', `example nie zawiera hasła "${r.term}"`);
    englishSentence(r.example, c, 'example');
    polishText(r.examplePl, c, 'examplePl');
  });
}

function validateAnswerVariants(data, ctx) {
  const { report, file } = ctx;
  const c = { ...ctx, id: '(plik)' };
  checkShape(data, { ...HEADER, polishSenseVariants: 'array', polishAspectPairs: 'array', englishAliases: 'object' }, c, 'answer-variants');
  if (typeOf(data) !== 'object') return;
  (Array.isArray(data.polishSenseVariants) ? data.polishSenseVariants : []).forEach((s, i) => {
    const cc = { ...ctx, id: `polishSenseVariants[${i}]` };
    checkShape(s, { term: 'string', variants: 'array' }, cc, 'grupa');
    if (typeOf(s) !== 'object') return;
    requireText(s, ['term'], cc);
    strings(s.variants, cc, 'variants', { allowEmptyList: false });
    if (Array.isArray(s.variants) && new Set(s.variants.map((v) => String(v).toLowerCase().trim())).size !== s.variants.length) report.warn(file, cc.id, 'duplicate-variant', `zdublowane warianty dla "${s.term}"`);
  });
  (Array.isArray(data.polishAspectPairs) ? data.polishAspectPairs : []).forEach((p, i) => {
    if (!Array.isArray(p) || p.length !== 2 || !p.every(nonEmpty)) report.error(file, `polishAspectPairs[${i}]`, 'type', 'para aspektowa musi mieć 2 niepuste teksty');
  });
  if (typeOf(data.englishAliases) === 'object') {
    for (const [k, v] of Object.entries(data.englishAliases)) {
      if (!Array.isArray(v)) report.error(file, `englishAliases.${k}`, 'type', 'wartość musi być tablicą tekstów');
      else strings(v, { ...ctx, id: `englishAliases.${k}` }, 'aliasy');
    }
  }
}

// ---------------------------------------------------------------------------
// Indeksy (generowane)
// ---------------------------------------------------------------------------

function validateTopicsIndex(data, ctx) {
  const { report, file } = ctx;
  const c = { ...ctx, id: '(indeks)' };
  checkShape(data, { schemaVersion: 'integer', generatedAt: 'string', groups: 'array', topics: 'array' }, c, 'topics/index');
  if (typeOf(data) !== 'object') return;
  if (Array.isArray(data.groups)) {
    const ids = data.groups.map((g) => g?.id);
    for (const g of Object.keys(GROUPS)) if (!ids.includes(g)) report.error(file, c.id, 'group-missing', `brak grupy "${g}"`);
    data.groups.forEach((g, i) => checkShape(g, { id: 'string', namePl: 'string', symbol: 'string' }, { ...ctx, id: `groups[${i}]` }, 'grupa'));
  }
  if (!Array.isArray(data.topics)) return;
  const dir = ctx.absPath ? path.dirname(ctx.absPath) : null;
  data.topics.forEach((t, i) => {
    const id = nonEmpty(t?.id) ? t.id : `topics[${i}]`;
    const cc = { ...ctx, id };
    checkShape(t, { id: 'string', namePl: 'string', nameEn: 'string', group: 'string', symbol: 'string', summaryPl: 'string', aliases: 'array', entryCount: 'integer', levels: 'object', categories: 'array' }, cc, 'temat');
    if (typeOf(t) !== 'object') return;
    if (typeOf(t.levels) === 'object') for (const l of LEVELS) if (!Number.isInteger(t.levels[l])) report.error(file, id, 'levels', `levels.${l} musi być liczbą całkowitą`);
    if (dir) {
      const p = path.join(dir, `${t.id}.json`);
      if (!fs.existsSync(p)) report.error(file, id, 'index-orphan', `w indeksie jest temat bez pliku topics/${t.id}.json — uruchom build-index.mjs`);
      else {
        try {
          const topic = JSON.parse(fs.readFileSync(p, 'utf8'));
          const n = (topic.categories || []).reduce((s, cat) => s + (Array.isArray(cat?.entries) ? cat.entries.length : 0), 0);
          if (n !== t.entryCount) report.warn(file, id, 'index-stale', `indeks nieaktualny (${t.entryCount} ≠ ${n} wpisów) — uruchom node ios/tools/build-index.mjs`);
        } catch { /* plik tematu w trakcie zapisu */ }
      }
    }
  });
  if (dir) {
    const listed = new Set(data.topics.map((t) => t?.id));
    for (const f of fs.readdirSync(dir)) {
      if (f.endsWith('.json') && f !== 'index.json' && !f.startsWith('_') && !listed.has(f.replace(/\.json$/, ''))) {
        report.warn(file, f.replace(/\.json$/, ''), 'index-stale', `temat ${f} nie jest w indeksie — uruchom node ios/tools/build-index.mjs`);
      }
    }
  }
}

function validateDictionaryIndex(data, ctx) {
  const { report, file } = ctx;
  checkShape(data, { schemaVersion: 'integer', entries: 'array' }, { ...ctx, id: '(indeks)' }, 'dictionary-index');
  if (!Array.isArray(data?.entries)) return;
  let prev = null;
  let unsorted = 0;
  const refs = new Set();
  data.entries.forEach((e, i) => {
    const id = nonEmpty(e?.r) ? e.r : `entries[${i}]`;
    checkShape(e, { t: 'string', k: 'string', p: 'string', l: 'string', f: 'string', r: 'string' }, { ...ctx, id }, 'rekord', { unknownIsError: true });
    if (typeOf(e) !== 'object') return;
    if (typeof e.t === 'string' && e.k !== normalizeKey(e.t)) report.error(file, id, 'dict-key', `k "${e.k}" ≠ znormalizowane t "${normalizeKey(e.t)}"`);
    if (typeof e.r === 'string' && !/^[a-z0-9-]+\/[a-z0-9-]+\.[a-z0-9-]+$/.test(e.r)) report.error(file, id, 'dict-ref', `r "${e.r}" musi mieć postać <plik>/<id>`);
    if (refs.has(e.r)) report.error(file, id, 'duplicate-id', `zdublowany rekord ${e.r}`);
    refs.add(e.r);
    if (prev && (prev.k > e.k || (prev.k === e.k && prev.r > e.r))) unsorted++;
    prev = e;
  });
  if (unsorted) report.error(file, '(indeks)', 'dict-sort', `${unsorted} rekordów poza kolejnością — uruchom build-index.mjs`);
}

function legacyGrammar(data, ctx) {
  ctx.report.error(ctx.file, '', 'legacy-file', 'grammar.json zastąpiono plikami grammar/<poziom>.json (CONTENT-SCHEMA §5.1) — usuń ten plik');
}

export const validators = {
  'grammar-level': validateGrammarLevel,
  grammar: legacyGrammar,
  exercises: validateExercises,
  idioms: validateIdioms,
  readings: validateReadings,
  recommendations: validateRecommendations,
  'answer-variants': validateAnswerVariants,
  'topics-index': validateTopicsIndex,
  'dictionary-index': validateDictionaryIndex,
};
