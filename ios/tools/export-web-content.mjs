#!/usr/bin/env node
// FluentNOW — eksport wbudowanych banków treści strony (web-source, tylko do odczytu) do JSON-ów aplikacji iOS.
// Moduły TS strony są wykonywane bezpośrednio (lib/web-loader.mjs), więc obiekty powstają DOKŁADNIE tak jak na stronie
// (idiomPool, productionPool, additionalProduction, starterLookup, polishAnswers…).
//
// Użycie: node ios/tools/export-web-content.mjs [--root <katalog treści>]
// Wynik: grammar/A1..C2.json, exercises.json, idioms.json, readings.json, starter-words.json,
//        recommendations.json, answer-variants.json (CONTENT-SCHEMA §4–§5).

import fs from 'node:fs';
import path from 'node:path';
import { fileURLToPath } from 'node:url';
import { importWeb } from './lib/web-loader.mjs';
import { DEFAULT_ROOT, kebab } from './validate-content.mjs';
import { loadGlossarySource, mergeGlossary } from './lib/reading-glossary.mjs';

const SOURCE = 'web-v42';
const LEVELS = ['A1', 'A2', 'B1', 'B2', 'C1', 'C2'];

// ---------------------------------------------------------------------------
// Serializacja: obiekty czytelne, elementy tablic obiektów w jednej linii (małe pliki, czytelne diffy).
// ---------------------------------------------------------------------------
export function stringify(value, indent = '') {
  if (Array.isArray(value)) {
    if (value.length === 0) return '[]';
    if (value.every((v) => v === null || typeof v !== 'object')) return JSON.stringify(value);
    const inner = indent + '  ';
    return '[\n' + value.map((v) => inner + JSON.stringify(v)).join(',\n') + '\n' + indent + ']';
  }
  if (value && typeof value === 'object') {
    const keys = Object.keys(value);
    if (keys.length === 0) return '{}';
    const inner = indent + '  ';
    return '{\n' + keys.map((k) => `${inner}${JSON.stringify(k)}: ${stringify(value[k], inner)}`).join(',\n') + '\n' + indent + '}';
  }
  return JSON.stringify(value);
}

function write(root, rel, obj, log) {
  const p = path.join(root, rel);
  fs.mkdirSync(path.dirname(p), { recursive: true });
  const text = stringify(obj) + '\n';
  const old = fs.existsSync(p) ? fs.readFileSync(p, 'utf8') : null;
  if (old !== text) fs.writeFileSync(p, text, 'utf8');
  log.push(`${old === text ? 'bez zmian' : 'zapisano'}: ${rel} (${(Buffer.byteLength(text) / 1024).toFixed(1)} KB)`);
}

/** Kanoniczna kolejność kluczy ProductionItem (jak w tutor-types.ts). */
function productionItem(item) {
  const out = {};
  if (item.bankId !== undefined) out.bankId = item.bankId;
  if (item.scenarioId !== undefined) out.scenarioId = item.scenarioId;
  Object.assign(out, {
    context: item.context, hintPl: item.hintPl, answer: item.answer, acceptedAnswers: item.acceptedAnswers ?? [],
    distractors: (item.distractors ?? []).map((d) => ({ form: d.form, diagnosis: d.diagnosis, explanation: d.explanation })),
    rule: item.rule, explanation: item.explanation, translation: item.translation,
  });
  return out;
}

function practiceQuestion(q) {
  const out = {};
  for (const k of ['format', 'inputHint', 'acceptedAnswers', 'bankId', 'scenarioId']) if (q[k] !== undefined) out[k] = q[k];
  Object.assign(out, { category: q.category, prompt: q.prompt, context: q.context, options: q.options, answer: q.answer, explanation: q.explanation, translation: q.translation });
  return out;
}

// Mapa `extra` z starterPractice (tutor-local.ts) + diagnoza błędu.
const EXTRA_DISTRACTOR = {
  'are running': ['is running', 'wrong_agreement'], visited: ['visits', 'wrong_tense'], Close: ['To close', 'wrong_word'],
  'have known': ['has known', 'wrong_agreement'], 'was cooking': ['were cooking', 'wrong_agreement'],
  'would travel': ['would travels', 'wrong_word'], 'are cleaned': ['is cleaned', 'wrong_agreement'],
  'had been flying': ['has been flying', 'wrong_tense'], 'had left': ['has left', 'wrong_tense'],
  'has been studying': ['have been studying', 'wrong_agreement'], 'would have helped': ['would helped', 'wrong_word'],
};

// Oczywiste poprawki pisowni amerykańskiej w czytankach (stosowane do WSZYSTKICH tekstów czytanki:
// akapity, pytania, opcje, evidence — żeby evidence pozostało dosłownym fragmentem).
const READING_FIXES = [
  [/^reading-legacy-a-useful-interview-lesson$/, /\bpractised\b/g, 'practiced'],
  [/^reading-legacy-when-efficiency-becomes-a-habit$/, /\brecognised\b/g, 'recognized'],
  [/^reading-v39-river-cleanup$/, /\brubbish\b/g, 'trash'],
];
function deepReplace(v, re, to) {
  if (typeof v === 'string') return v.replace(re, to);
  if (Array.isArray(v)) return v.map((x) => deepReplace(x, re, to));
  if (v && typeof v === 'object') return Object.fromEntries(Object.entries(v).map(([k, x]) => [k, k === 'id' ? x : deepReplace(x, re, to)]));
  return v;
}
function applyReadingFixes(r, fixes) {
  let out = r;
  for (const [idRe, re, to] of READING_FIXES) {
    if (!idRe.test(r.id)) continue;
    const before = JSON.stringify(out);
    out = deepReplace(out, re, to);
    const n = (before.match(re) || []).length;
    if (n) fixes.push(`${r.id}: ${re.source.replace(/\\b/g, '')} → ${to} (${n}×)`);
  }
  return out;
}

function reading(r) {
  return {
    id: r.id, title: r.title, level: r.level, topic: r.topic ?? '',
    paragraphs: r.paragraphs,
    questions: r.questions.map((q) => {
      const o = { question: q.question, options: q.options, answer: q.answer, explanation: q.explanation, evidence: q.evidence };
      if (q.meaningId !== undefined) o.meaningId = q.meaningId;
      return o;
    }),
    source: r.source ?? 'starter',
  };
}

// ---------------------------------------------------------------------------
// Starter words — uzupełnienia, których strona nie ma (IPA General American, częstość, formy w formacie schematu).
// ---------------------------------------------------------------------------
const IPA_GA = {
  'get the hang of': '/ˌɡet ðə ˈhæŋ əv/', borrow: '/ˈbɑːroʊ/', lend: '/lend/', 'boarding pass': '/ˈbɔːrdɪŋ ˌpæs/',
  accomplish: '/əˈkɑːmplɪʃ/', 'it depends': '/ɪt dɪˈpendz/', bank: '/bæŋk/', reservation: '/ˌrezərˈveɪʃən/',
  deadline: '/ˈdedlaɪn/', say: '/seɪ/', tell: '/tel/', make: '/meɪk/', do: '/duː/', appointment: '/əˈpɔɪntmənt/',
  recommend: '/ˌrekəˈmend/', strength: '/streŋθ/', 'take your time': '/ˌteɪk jʊr ˈtaɪm/', 'figure out': '/ˌfɪɡjər ˈaʊt/',
  // rekomendacje
  ascertain: '/ˌæsərˈteɪn/', 'carry out': '/ˌkæri ˈaʊt/', create: '/kriˈeɪt/', advocate: '/ˈædvəkeɪt/', attain: '/əˈteɪn/',
};
const FREQUENCY = {
  'starter.get-the-hang-of': 'common', 'starter.borrow': 'very_common', 'starter.lend': 'common', 'starter.boarding-pass': 'common',
  'starter.accomplish': 'less_common', 'starter.it-depends': 'very_common', 'starter.bank': 'very_common', 'starter.bank-2': 'less_common',
  'starter.reservation': 'common', 'starter.deadline': 'common', 'starter.say': 'very_common', 'starter.tell': 'very_common',
  'starter.make': 'very_common', 'starter.do': 'very_common', 'starter.do-2': 'very_common', 'starter.do-3': 'common',
  'starter.appointment': 'common', 'starter.recommend': 'common', 'starter.strength': 'common', 'starter.take-your-time': 'common',
  'starter.figure-out': 'very_common',
};
const TRANSLATION_OVERRIDE = { 'starter.bank': 'bank' }; // strona: „bank — instytucja finansowa” (etykieta, nie tłumaczenie)
const REGISTER_MAP = { zawodowy: 'neutralny' }; // spoza enumu schematu

function verbForms(term, forms) {
  if (!forms) return '';
  const parts = forms.split('·').map((s) => s.trim()).filter(Boolean);
  return parts.length === 2 ? `${term} – ${parts[0]} – ${parts[1]}` : parts.join('; ');
}
const listField = (s) => (s ? s.split('·').map((x) => x.trim()).filter(Boolean).join('; ') : '');

/** focusEn musi być dokładnym podciągiem en — strona używa hasła (np. „take your time” w „Take your time.”). */
function exactFocus(sentence, focus) {
  if (sentence.includes(focus)) return focus;
  const i = sentence.toLowerCase().indexOf(focus.toLowerCase());
  return i >= 0 ? sentence.slice(i, i + focus.length) : focus;
}

function starterEntries(tl, av, fixes) {
  const out = [];
  for (const w of tl.__STARTER.words) {
    const lookup = tl.starterLookup(w.en);
    if (!lookup) continue;
    lookup.meanings.forEach((m, j) => {
      const id = `starter.${kebab(w.en)}${j ? `-${j + 1}` : ''}`;
      const translation = TRANSLATION_OVERRIDE[id] ?? m.translation;
      if (TRANSLATION_OVERRIDE[id]) fixes.push(`${id}: translation „${m.translation}” → „${translation}”`);
      const register = REGISTER_MAP[m.register] ?? m.register;
      if (register !== m.register) fixes.push(`${id}: register „${m.register}” → „${register}” (spoza enumu)`);
      const ipa = IPA_GA[w.en] ?? w.ipa;
      if (j === 0 && ipa !== w.ipa) fixes.push(`${id}: IPA ${w.ipa} → ${ipa} (General American)`);
      const examples = m.examples.filter(Boolean).map((ex) => {
        const focusEn = exactFocus(ex.en, ex.focusEn);
        if (focusEn !== ex.focusEn) fixes.push(`${id}: focusEn „${ex.focusEn}” → „${focusEn}” (dokładny podciąg)`);
        return { en: ex.en, pl: ex.pl, focusEn, focusPl: exactFocus(ex.pl, ex.focusPl) };
      });
      // Strona dzieli tłumaczenie po przecinku — „załapać, jak coś działa” dawało osobny wariant „jak coś działa”.
      // Odrzucamy takie fragmenty zdań podrzędnych (zaczynające się od spójnika/zaimka względnego).
      const all = av.polishAnswers(w.en, translation);
      const acceptedTranslations = all.filter((a) => a === translation || !/^(jak|że|co|który|która|które|aby|żeby|gdy|kiedy|gdzie)\b/i.test(a)).slice(0, 8);
      for (const a of all) if (!acceptedTranslations.includes(a) && all.indexOf(a) < 8) fixes.push(`${id}: odrzucono wariant „${a}” (fragment po przecinku)`);
      if (all.length > 8) fixes.push(`${id}: acceptedTranslations przycięte z ${all.length} do 8 (pełna lista w answer-variants.json)`);
      out.push({
        id, term: w.en, ipa, pos: m.pos ?? w.pos, level: m.level ?? w.level, frequency: FREQUENCY[id] ?? 'common',
        translation, definition: m.definition, register, contextPl: m.context, natural: m.natural ?? '',
        forms: verbForms(w.en, w.forms), collocations: j === 0 ? listField(w.collocations) : '',
        synonyms: j === 0 ? listField(w.synonyms) : '', antonyms: j === 0 ? listField(w.antonyms) : '',
        notePl: j === 0 ? (w.note ?? '') : '',
        examples,
        acceptedAnswers: [...new Set([w.en, ...(m.acceptedAnswers ?? [])])],
        acceptedTranslations,
      });
    });
  }
  return out;
}

// ---------------------------------------------------------------------------

export async function exportAll(root = DEFAULT_ROOT) {
  const log = [];
  const fixes = [];
  const counts = {};

  const gb = await importWeb('lib/grammar-bank.ts');
  const prod = await importWeb('lib/production.ts');
  const eb = await importWeb('lib/data/exercise-bank.ts');
  const ib = await importWeb('lib/data/idiom-bank.ts');
  const rb = await importWeb('lib/reading-bank.ts');
  const ar = await importWeb('lib/data/advanced-readings.ts');
  const tl = await importWeb('lib/tutor-local.ts');
  const av = await importWeb('lib/answer-variants.ts');

  // 1. Gramatyka: authoredGrammar (grammar-bank.json, v36) — podział na poziomy (§5).
  counts.grammar = {};
  for (const level of LEVELS) {
    const items = gb.authoredGrammar(level).map(productionItem);
    counts.grammar[level] = items.length;
    write(root, `grammar/${level}.json`, {
      schemaVersion: 1, source: SOURCE, version: gb.GRAMMAR_BANK_VERSION, level,
      rules: prod.productionRules[level] ?? [], items,
    }, log);
  }

  // 2. Ćwiczenia: productionPool bez authoredGrammar = startery z production.ts + wiersze exercise-bank.ts,
  //    z bankId nadanym przez stronę (grammarTaskId → legacy-grammar-<hash>).
  counts.exercises = {};
  const exLevels = {};
  for (const level of LEVELS) {
    const authored = new Set(gb.authoredGrammar(level).map((i) => i.bankId));
    const items = prod.productionPool(level).filter((i) => !authored.has(i.bankId)).map(productionItem);
    exLevels[level] = items;
    counts.exercises[level] = items.length;
  }
  // Strona w trybie wyboru (starterPractice) dokłada trzeci błędny wariant z zaszytej mapy `extra`, gdy zadanie ma < 3
  // dystraktorów. Zapisujemy go w danych, żeby aplikacja nie musiała znać tej mapy.
  for (const level of LEVELS) {
    exLevels[level] = exLevels[level].map((item) => {
      let it = item;
      if (JSON.stringify(it).includes('travelled')) {
        it = JSON.parse(JSON.stringify(it).replace(/travelled/g, 'traveled'));
        fixes.push(`${it.bankId}: dystraktor „would have travelled” → „would have traveled” (pisownia AmE)`);
      }
      if (it.distractors.length < 3) {
        const extra = EXTRA_DISTRACTOR[it.answer];
        const [form, diagnosis] = extra ?? [`to ${it.answer}`, 'wrong_word'];
        it = { ...it, distractors: [...it.distractors, { form, diagnosis, explanation: `„${form}” nie pasuje do tej konstrukcji. ${it.explanation}` }] };
        fixes.push(`${it.bankId}: dodano 3. dystraktor „${form}” (jak starterPractice na stronie)`);
      }
      return it;
    });
  }
  write(root, 'exercises.json', { schemaVersion: 1, source: SOURCE, version: eb.EXERCISE_BANK_VERSION, levels: exLevels }, log);

  // 3. Idiomy: idiomPool(level, 0) — dokładnie jak strona; bankId dodany dla śledzenia „widzianych”.
  counts.idioms = {};
  const idLevels = {};
  for (const level of LEVELS) {
    idLevels[level] = ib.idiomPool(level, 0).map((q, i) => practiceQuestion({ ...q, bankId: `idiom-v1-${level}-${String(i).padStart(2, '0')}` }));
    counts.idioms[level] = idLevels[level].length;
  }
  write(root, 'idioms.json', { schemaVersion: 1, source: SOURCE, levels: idLevels }, log);

  // 4. Czytanki: bank v39 (readings/*.json) + advanced-readings.ts + dawne czytanki z tutor-local.ts (martwy kod na stronie).
  const readings = rb.readingBank.map(reading);
  const legacy = [
    ...Object.values(tl.__readings),
    ...Object.values(tl.__extraReadings).flat(),
    ...ar.advancedReadings,
  ];
  const usedIds = new Set(readings.map((r) => r.id));
  for (const r of legacy) {
    let id = `reading-legacy-${kebab(r.title)}`;
    for (let n = 2; usedIds.has(id); n++) id = `reading-legacy-${kebab(r.title)}-${n}`;
    usedIds.add(id);
    readings.push(reading({ ...r, id, topic: '', source: 'starter' }));
  }
  for (let i = 0; i < readings.length; i++) readings[i] = applyReadingFixes(readings[i], fixes);
  readings.sort((a, b) => LEVELS.indexOf(a.level) - LEVELS.indexOf(b.level));
  // Słowniczki kontekstowe (G1) nie pochodzą ze strony — źródło: ios/tools/data/reading-glossary.json.
  // Scalane tutaj, żeby ponowny eksport ich nie skasował (szczegóły: lib/reading-glossary.mjs).
  const glossary = mergeGlossary(readings, loadGlossarySource());
  for (const id of glossary.unknown) fixes.push(`słowniczek: brak czytanki "${id}" (pominięty)`);
  counts.readings = { bank: rb.readingBank.length, legacy: legacy.length, total: readings.length, withGlossary: glossary.merged };
  write(root, 'readings.json', { schemaVersion: 1, source: SOURCE, readings: glossary.readings }, log);

  // 5. Słowa startowe (format Entry §1).
  const words = starterEntries(tl, av, fixes);
  counts.starterWords = words.length;
  write(root, 'starter-words.json', { schemaVersion: 1, source: SOURCE, words }, log);

  // 6. Rekomendacje „krok dalej”.
  const items = tl.__advancedCandidates.map((r) => ({
    known: r.known, term: r.term, level: r.level, translation: r.translation, difference: r.difference,
    example: r.example, examplePl: r.examplePl, ipa: IPA_GA[r.term] ?? tl.recommendationLookup(r).ipa,
  }));
  counts.recommendations = items.length;
  write(root, 'recommendations.json', { schemaVersion: 1, source: SOURCE, items }, log);

  // 7. Warianty odpowiedzi.
  write(root, 'answer-variants.json', {
    schemaVersion: 1, source: SOURCE,
    polishSenseVariants: av.polishSenseVariants.map((s) => ({ term: s.term, variants: s.variants })),
    polishAspectPairs: av.polishAspectPairs,
    englishAliases: tl.__aliases,
  }, log);
  counts.answerVariants = { polishSenseVariants: av.polishSenseVariants.length, polishAspectPairs: av.polishAspectPairs.length, englishAliases: Object.keys(tl.__aliases).length };

  // Stary plik grammar.json (sprzed podziału) — usuń, żeby nie dublować danych.
  const legacyGrammar = path.join(root, 'grammar.json');
  if (fs.existsSync(legacyGrammar)) { fs.rmSync(legacyGrammar); log.push('usunięto: grammar.json (zastąpiony przez grammar/<poziom>.json)'); }

  return { log, fixes, counts };
}

const isMain = process.argv[1] && path.resolve(process.argv[1]) === fileURLToPath(import.meta.url);
if (isMain) {
  let root = DEFAULT_ROOT;
  const argv = process.argv.slice(2);
  for (let i = 0; i < argv.length; i++) if (argv[i] === '--root' && argv[i + 1]) root = path.resolve(argv[++i]);
  exportAll(root).then(({ log, fixes, counts }) => {
    for (const l of log) console.log(l);
    if (fixes.length) { console.log(`Poprawki w eksporcie (${fixes.length}):`); for (const f of fixes) console.log('  ' + f); }
    console.log('Liczności:', JSON.stringify(counts));
    console.log('UWAGA: eksport nadpisał korekty english-qa. Uruchom teraz dwukrotnie: node ios/tools/fixes/english-qa-banks-fix.mjs, potem node ios/tools/fixes/readings-ame-fix.mjs, potem node ios/tools/apply-reading-glossary.mjs (słowniczki czytanek względem poprawionego tekstu) i node ios/tools/build-index.mjs');
  }, (err) => { console.error(err); process.exitCode = 1; });
}
