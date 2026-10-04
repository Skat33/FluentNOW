// english-qa (banki): poprawki w plikach JSON banków. Idempotentny: uruchomiony drugi raz nic nie zmienia.
import fs from 'node:fs';
import { stringify } from '../export-web-content.mjs';
import { fileURLToPath } from 'node:url';

const C = fileURLToPath(new URL('../../FluentNOW/Resources/Content/', import.meta.url));
// Uruchomienie po eksporcie: node ios/tools/fixes/english-qa-banks-fix.mjs (idempotentne; 2 przebiegi = punkt stały).
const log = [];
const load = (f) => JSON.parse(fs.readFileSync(C + f, 'utf8'));
const save = (f, o) => fs.writeFileSync(C + f, stringify(o) + '\n');
function set(file, obj, id, field, value, cat) {
  const before = JSON.stringify(obj[field]);
  const after = JSON.stringify(value);
  if (before === after) return;
  log.push({ file, id, field, before: obj[field], after: value, cat });
  obj[field] = value;
}

// ---------------------------------------------------------------------------
// GRAMATYKA
// ---------------------------------------------------------------------------
const F = (base, s, past, pp, ing) => ({ base, s, past, pp, ing });
const reg = (b) => F(b, b + 's', b + 'ed', b + 'ed', b + 'ing');
const regE = (b) => F(b, b + 's', b + 'd', b + 'd', b.slice(0, -1) + 'ing');
const FORMS = {
  review: reg('review'), assess: F('assess', 'assesses', 'assessed', 'assessed', 'assessing'), evaluate: regE('evaluate'),
  investigate: regE('investigate'), verify: F('verify', 'verifies', 'verified', 'verified', 'verifying'), allocate: regE('allocate'),
  adapt: reg('adapt'), inspect: reg('inspect'), secure: regE('secure'), amend: reg('amend'), audit: reg('audit'),
  reconstruct: reg('reconstruct'), fix: F('fix', 'fixes', 'fixed', 'fixed', 'fixing'), choose: F('choose', 'chooses', 'chose', 'chosen', 'choosing'),
  collect: reg('collect'),
  analyze: regE('analyze'), examine: regE('examine'), 'look into': F('look into', 'looks into', 'looked into', 'looked into', 'looking into'),
  check: reg('check'), assign: reg('assign'), adjust: reg('adjust'), obtain: reg('obtain'), get: F('get', 'gets', 'got', 'gotten', 'getting'),
  change: regE('change'), modify: F('modify', 'modifies', 'modified', 'modified', 'modifying'), revise: regE('revise'),
  recreate: regE('recreate'), repair: reg('repair'), pick: reg('pick'), select: reg('select'), gather: reg('gather'),
};
// Synonimy zgodne z polską podpowiedzią i z obiektem w zdaniu (każdy czasownik występuje w jednej, stałej scenie).
const SYN = {
  review: ['analyze', 'examine'],            // analizować — the evidence in the fraud case
  assess: ['evaluate'], evaluate: ['assess'], // oceniać
  investigate: ['examine', 'look into'],     // badać — the cause of the power failure
  verify: ['check'],                         // weryfikować — the figures in the annual report
  allocate: ['assign'],                      // przydzielić — the emergency funds
  adapt: ['adjust'],                         // dostosować — the curriculum
  inspect: ['check', 'examine'],             // sprawdzić — the structural damage to the bridge
  secure: ['obtain', 'get'],                 // uzyskać — the permits
  amend: ['change', 'modify', 'revise'],     // zmienić — the disputed clause
  audit: ['check', 'inspect'],               // kontrolować — the charity accounts
  reconstruct: ['recreate'],                 // odtworzyć — the sequence of events
  fix: ['repair'],                           // naprawiać — bicycles
  choose: ['pick', 'select'],                // wybierać — books for the school library
  collect: ['gather'],                       // zbierać — leaves in the park
};
const PERFECT_AUX = new Set(['have', 'has', 'had', 'having']);
const SKIP = new Set(['we', 'already', 'not', 'ever', 'just', 'never']);
function formType(lemma, tok, prevWords) {
  const f = FORMS[lemma];
  if (tok === f.ing) return 'ing';
  if (tok === f.s) return 's';
  if (tok === f.base && tok !== f.past) return 'base';
  if (tok === f.pp && tok !== f.past) return 'pp';
  if (tok === f.past && tok !== f.pp) return 'past';
  if (tok === f.past) { // past == pp
    for (let i = prevWords.length - 1; i >= 0; i--) {
      const w = prevWords[i].toLowerCase();
      if (SKIP.has(w)) continue;
      return PERFECT_AUX.has(w) ? 'pp' : 'past';
    }
    return 'past';
  }
  return null;
}
function variant(answer, lemma, syn, contextBefore) {
  const toks = answer.split(' ');
  const out = [];
  let done = false;
  for (let i = 0; i < toks.length; i++) {
    const t = toks[i];
    if (!done) {
      const prev = [...contextBefore.split(/\s+/).filter(Boolean), ...toks.slice(0, i)];
      const type = formType(lemma, t, prev);
      if (type) { out.push(FORMS[syn][type]); done = true; continue; }
    }
    out.push(t);
  }
  return done ? out.join(' ') : null;
}
const LEMMA_BY_ANSWER_TOKEN = new Map();
for (const lemma of Object.keys(SYN)) for (const v of Object.values(FORMS[lemma])) LEMMA_BY_ANSWER_TOKEN.set(v, lemma);
function lemmaOf(item) {
  for (const t of item.answer.split(' ')) if (LEMMA_BY_ANSWER_TOKEN.has(t)) return LEMMA_BY_ANSWER_TOKEN.get(t);
  return null;
}

// Polskie formy (z istniejących tłumaczeń banku): dokonane i niedokonane 1. os. lm. czasu przeszłego.
function polishForms(levels) {
  const c1 = levels.C1.items, b2 = levels.B2.items;
  const perf = [], imperf = [], obj = [];
  for (let k = 0; k < 20; k++) {
    const a = c1.find((it) => it.bankId === `grammar-36-C1-00-${String(k).padStart(2, '0')}`).translation;
    const m = a.match(/^Dopiero po otrzymaniu pisemnego upoważnienia (\S+) (.+)\.$/);
    const b = b2.find((it) => it.bankId === `grammar-36-B2-01-${String(k).padStart(2, '0')}`).translation;
    const n = b.match(/^Kiedy przełożony wreszcie przyjechał, od wielu godzin (\S+) (.+)\.$/);
    if (!m || !n || !m[1].endsWith('liśmy') || !n[1].endsWith('liśmy')) throw new Error('polishForms ' + k);
    perf.push(m[1]); obj.push(m[2]); imperf.push(n[1]);
  }
  return { perf, imperf, obj };
}
const cond = (v) => v.replace(/liśmy$/, 'libyśmy');
const pl3 = (v) => v.replace(/liśmy$/, 'li');

const LEVELS = ['A1', 'A2', 'B1', 'B2', 'C1', 'C2'];
const G = {};
for (const L of LEVELS) G[L] = load(`grammar/${L}.json`);
const PF = polishForms(G);

function retargetDistractors(file, it, oldAnswerForms, newForms) {
  // podmiana form dystraktorów i tekstów w ich wyjaśnieniach
  const ds = it.distractors.map((d) => {
    const nf = newForms[d.form];
    if (!nf) throw new Error(`${it.bankId}: brak mapy dla dystraktora ${d.form}`);
    return { ...d, form: nf, explanation: d.explanation.replace(`„${d.form}”`, `„${nf}”`) };
  });
  set(file, it, it.bankId, 'distractors', ds, 'naturalność (czasownik)');
}

for (const L of LEVELS) {
  const file = `grammar/${L}.json`;
  for (const it of G[L].items) {
    const id = it.bankId;
    const k = Number(id.slice(-2));
    const rule = id.split('-')[3];
    const tag = `${L}-${rule}`;

    // --- 1. „znajdować” w czasach ciągłych / zakazie / radzie → „szukać” (look for)
    if (k === 12 && ['A1-03', 'A1-05', 'A2-03', 'B1-03', 'A1-10', 'A2-09'].includes(tag) && it.hintPl === 'znajdować') {
      const map = {
        'A1-03': { ans: 'looking for', d: { find: 'look for', finds: 'looks for', 'to find': 'to look for' }, pl: 'Spójrz! Właśnie szukamy muszli na plaży.' },
        'A1-05': { ans: 'looking for', d: { find: 'look for', finds: 'looks for', 'to find': 'to look for' }, pl: 'Czy w tej chwili szukamy muszli na plaży?' },
        'A2-03': { ans: 'looking for', d: { find: 'look for', finds: 'looks for', 'to find': 'to look for' }, pl: it.translation },
        'B1-03': { ans: 'looking for', d: { finds: 'looks for', find: 'look for', 'to find': 'to look for' }, pl: it.translation },
        'A1-10': { ans: 'look for', d: { finds: 'looks for', finding: 'looking for', 'to find': 'to look for' }, pl: 'Nie należy dziś szukać muszli na plaży; trzeba poczekać do jutra.' },
        'A2-09': { ans: 'look for', d: { finds: 'looks for', finding: 'looking for', 'to find': 'to look for' }, pl: 'Następnym razem powinniśmy staranniej szukać muszli na plaży.' },
      }[tag];
      set(file, it, id, 'context', it.context.replace('(znajdować)', '(szukać)'), 'naturalność (czasownik)');
      set(file, it, id, 'hintPl', 'szukać', 'naturalność (czasownik)');
      set(file, it, id, 'answer', map.ans, 'naturalność (czasownik)');
      retargetDistractors(file, it, null, map.d);
      set(file, it, id, 'translation', map.pl, 'tłumaczenie PL');
    }
    if (k === 12 && ['A1-04', 'A2-04'].includes(tag) && it.context.includes('finding shells')) {
      set(file, it, id, 'context', it.context.replace('finding shells', 'looking for shells'), 'naturalność (czasownik)');
      if (tag === 'A1-04') set(file, it, id, 'translation', 'Teraz szukamy muszli na plaży, więc proszę poczekać.', 'tłumaczenie PL');
    }

    // --- 2. Zdania nielogiczne / tautologiczne
    if (id === 'grammar-36-A1-12-03') {
      set(file, it, id, 'context', it.context.replace('for lunch before lunch.', 'for lunch before noon.'), 'logika zdania');
      set(file, it, id, 'translation', 'Chcemy zrobić kanapki na lunch przed południem.', 'logika zdania');
    }
    if (id === 'grammar-36-A1-12-14') {
      set(file, it, id, 'context', it.context.replace('for dinner before lunch.', 'for dinner this afternoon.'), 'logika zdania');
      set(file, it, id, 'translation', 'Chcemy dziś po południu ugotować ryż na obiad.', 'logika zdania');
    }
    if (id === 'grammar-36-A2-13-00') {
      set(file, it, id, 'context', it.context.replace('after the long trip.', 'after the long day.'), 'logika zdania');
      set(file, it, id, 'translation', 'Po długim dniu byliśmy zbyt zmęczeni, żeby spakować torby na wyjazd.', 'logika zdania');
    }
    if (id === 'grammar-36-B1-04-14') {
      set(file, it, id, 'context', it.context.replace('for dinner before dinner.', 'for dinner before five.'), 'logika zdania');
      set(file, it, id, 'translation', 'Jeśli skończymy wcześniej, przed piątą ugotujemy ryż na obiad.', 'logika zdania');
    }
    if (id === 'grammar-36-B1-04-03') {
      set(file, it, id, 'context', it.context.replace('sandwiches for lunch before dinner.', "sandwiches for tomorrow's lunch before dinner."), 'logika zdania');
      set(file, it, id, 'translation', 'Jeśli skończymy wcześniej, przed kolacją zrobimy kanapki na jutrzejszy lunch.', 'logika zdania');
    }
    if (id === 'grammar-36-B2-11-14') {
      set(file, it, id, 'context', it.context.replace('again before the inspection.', 'again before the official visit.'), 'styl (powtórzenie)');
      set(file, it, id, 'translation', it.translation.replace('przed kontrolą.', 'przed oficjalną wizytą.'), 'styl (powtórzenie)');
    }
    if (['B2', 'C1', 'C2'].includes(L) && k === 19 && it.context.includes('the sequence of events before the accident')) {
      set(file, it, id, 'context', it.context.replace('the sequence of events before the accident', 'the sequence of events leading up to the accident'), 'styl (before … before)');
    }
    if (tag === 'C1-08') {
      set(file, it, id, 'context', it.context.replace('we were finally able to publish our findings.', 'we were finally able to move on to the next stage.'), 'logika zdania');
      set(file, it, id, 'translation', it.translation.replace('mogliśmy wreszcie opublikować ustalenia.', 'mogliśmy wreszcie przejść do kolejnego etapu.'), 'logika zdania');
    }
    if (tag === 'C2-01') {
      set(file, it, id, 'context', it.context.replace('than the findings were challenged', 'than our work was challenged'), 'logika zdania');
      set(file, it, id, 'translation', it.translation.replace('ustalenia zakwestionowano', 'naszą pracę zakwestionowano'), 'logika zdania');
    }
    if (tag === 'C2-08') {
      set(file, it, id, 'context', it.context.replace('vouch for the reliability of the conclusions.', 'vouch for the quality of the work.'), 'logika zdania');
      set(file, it, id, 'translation', it.translation.replace('ręczyć za wiarygodność wniosków.', 'ręczyć za jakość tej pracy.'), 'logika zdania');
    }

    // --- 3. Tłumaczenia polskie nieoddające konstrukcji
    if (id === 'grammar-36-B1-00-04') set(file, it, id, 'translation', 'Już przeczytaliśmy dzieciom opowiadania, więc to zadanie jest skończone.', 'tłumaczenie PL');
    if (tag === 'B1-05') {
      const m = it.translation.match(/^(Gdybyśmy mieli więcej wolnego czasu, częściej) moglibyśmy (\S+ć) (.+)$/);
      if (m) set(file, it, id, 'translation', `${m[1]} ${m[2].replace(/ć$/, 'libyśmy')} ${m[3]}`, 'tłumaczenie PL (would ≠ moglibyśmy)');
    }
    if (tag === 'B1-10') {
      const m = it.translation.match(/^Rozmawialiśmy o planie, żeby (.+) podczas następnej wizyty\.$/);
      if (m) set(file, it, id, 'translation', `Rozmawialiśmy o tym, żeby podczas następnej wizyty ${m[1]}.`, 'tłumaczenie PL');
    }
    if (['B2', 'C1', 'C2'].includes(L)) {
      const p = PF.perf[k], i = PF.imperf[k], o = PF.obj[k];
      const T = {
        'B2-03': `Gdybyśmy wczoraj mieli dość czasu, ${cond(p)} ${o}.`,
        'C1-02': `Komisja nalegała, żebyśmy ${pl3(p)} ${o}, zanim wydamy jakiekolwiek publiczne oświadczenie.`,
        'C1-03': `Gdybyśmy w zeszłym roku uzyskali finansowanie, teraz ${cond(i)} ${o}.`,
        'C1-04': `Gdybyśmy z natury byli mniej ostrożni, już w zeszłym miesiącu ${cond(p)} ${o}.`,
        'C1-09': `Gdybyśmy wcześniej ${pl3(p)} ${o}, wynik mógłby być inny.`,
        'C1-13': `Sądząc po tym, jak wszyscy byli wyczerpani, najwyraźniej godzinami ${i} ${o}.`,
        'C1-14': `Dyrektor wolałby, żebyśmy ${pl3(p)} ${o} jutro, a nie dziś.`,
        'C2-04': `Gdyby nie obowiązywała nas poufność, już w zeszłym roku publicznie ${cond(p)} ${o}.`,
        'C2-05': `Gdyby zniesiono embargo, teraz wspólnie z zagranicznymi partnerami ${cond(i)} ${o}.`,
        'C2-12': `Przewodniczący wolałby, żebyśmy ${pl3(p)} ${o} przed rozesłaniem wstępnych wniosków.`,
      }[tag];
      if (T) set(file, it, id, 'translation', T, 'tłumaczenie PL (tryb/aspekt)');
      if (tag === 'C1-01') {
        const m = it.translation.match(/^Nigdy wcześniej nie (\S+) (.+)$/);
        if (m && m[1] !== i) set(file, it, id, 'translation', `Nigdy wcześniej nie ${i} ${m[2]}`, 'tłumaczenie PL (aspekt)');
      }
      if (tag === 'C2-14') set(file, it, id, 'translation', it.translation.replace('chcielibyśmy byli', 'chcieliśmy'), 'tłumaczenie PL (styl)');
    }

    // --- 4. acceptedAnswers: synonimy zgodne z podpowiedzią + warianty bez „already” + perfect infinitive po would have liked
    const lemma = lemmaOf(it);
    const before = it.context.split('________')[0];
    const bases = [it.answer, ...it.acceptedAnswers];
    const acc = new Set(it.acceptedAnswers);
    if (tag === 'C2-14') {
      const lem = lemma ?? Object.keys(FORMS).find((l) => FORMS[l].base === it.answer.replace(/^to /, ''));
      const f = lem ? FORMS[lem] : null;
      const verb = it.answer.replace(/^to /, '');
      const pp = f ? f.pp : (verb.endsWith('e') ? verb + 'd' : verb + 'ed');
      acc.add('to have ' + pp);
    }
    if (lemma) for (const syn of SYN[lemma]) for (const b of bases) {
      const v = variant(b, lemma, syn, before);
      if (v) acc.add(v);
    }
    if (tag === 'B1-00' || tag === 'B2-00') for (const a of [it.answer, ...acc]) acc.add(a.replace(' already ', ' '));
    acc.delete(it.answer);
    const dforms = new Set(it.distractors.map((d) => d.form.toLowerCase()));
    for (const a of acc) if (dforms.has(a.toLowerCase())) throw new Error(`${id}: wariant ${a} = dystraktor`);
    const next = [...acc];
    if (next.length !== it.acceptedAnswers.length) set(file, it, id, 'acceptedAnswers', next, 'acceptedAnswers (synonimy podpowiedzi)');
  }
  save(file, G[L]);
}

// ---------------------------------------------------------------------------
// ĆWICZENIA
// ---------------------------------------------------------------------------
{
  const file = 'exercises.json';
  const ex = load(file);
  const all = Object.values(ex.levels).flat();
  const byId = (id) => all.find((x) => x.bankId === id);
  const addAcc = (id, vals) => {
    const it = byId(id);
    const acc = [...new Set([...it.acceptedAnswers, ...vals])];
    set(file, it, id, 'acceptedAnswers', acc, 'acceptedAnswers (poprawny wariant)');
  };
  addAcc('legacy-grammar-600374084', ['having broken']);
  addAcc('legacy-grammar-3423518032', ['should resign']);
  addAcc('legacy-grammar-3194024353', ['should be']);
  addAcc('legacy-grammar-1510987045', ['should be refunded']);
  addAcc('legacy-grammar-2478347154', ['should be removed']);
  addAcc('legacy-grammar-4044529832', ['should be disclosed']);
  addAcc('legacy-grammar-1084959712', ['should receive']);
  const w = byId('legacy-grammar-600374084');
  set(file, w, w.bankId, 'context', w.context.replace('(złamać)', '(wybić)'), 'podpowiedź PL (kalka)');
  set(file, w, w.bankId, 'hintPl', 'wybić', 'podpowiedź PL (kalka)');
  save(file, ex);
}

// ---------------------------------------------------------------------------
// IDIOMY
// ---------------------------------------------------------------------------
{
  const file = 'idioms.json';
  const id = load(file);
  const all = Object.values(id.levels).flat();
  const q = (bid) => all.find((x) => x.bankId === bid);
  const tmpl = (en, pl) => `W tej sytuacji „${en}” oznacza: ${pl}. To znaczenie wynika z całej wypowiedzi, nie z dosłownego tłumaczenia każdego słowa.`;
  // A1: „Proszę, oto to” — nienaturalne
  for (const x of id.levels.A1) {
    const opts = x.options.map((o) => (o === 'Proszę, oto to' ? 'Proszę (podając coś)' : o));
    set(file, x, x.bankId, 'options', opts, 'polski (nienaturalna etykieta)');
  }
  const h = q('idiom-v1-A1-08');
  set(file, h, h.bankId, 'explanation', tmpl('Here you are', 'proszę (gdy coś komuś podajemy)'), 'polski (nienaturalna etykieta)');
  // B2
  const b3 = q('idiom-v1-B2-03');
  set(file, b3, b3.bankId, 'translation', 'To, że spóźniłem się na autobus, wyszło mi na dobre: spotkałem starego znajomego.', 'tłumaczenie PL');
  const b14 = q('idiom-v1-B2-14');
  set(file, b14, b14.bankId, 'context', 'The experiment failed, so we were back to square one.', 'gramatyka/kolokacja');
  set(file, b14, b14.bankId, 'translation', 'Eksperyment się nie udał, więc wróciliśmy do punktu wyjścia.', 'gramatyka/kolokacja');
  // C1: storm in a teacup (BrE) → tempest in a teapot (AmE)
  const c12 = q('idiom-v1-C1-12');
  set(file, c12, c12.bankId, 'prompt', 'Co oznacza „A tempest in a teapot” w tym kontekście?', 'AmE (idiom brytyjski)');
  set(file, c12, c12.bankId, 'context', 'The argument over the logo was a tempest in a teapot.', 'AmE (idiom brytyjski)');
  set(file, c12, c12.bankId, 'explanation', tmpl('A tempest in a teapot', 'wielkie zamieszanie z błahego powodu'), 'AmE (idiom brytyjski)');
  // C2
  const c2 = q('idiom-v1-C2-02');
  set(file, c2, c2.bankId, 'prompt', 'Co oznacza „Hoisted by his own petard” w tym kontekście?', 'AmE (forma idiomu)');
  set(file, c2, c2.bankId, 'context', 'His attempt to expose a rival revealed his own fraud: he was hoisted by his own petard.', 'AmE (forma idiomu)');
  const OLD = 'Robić coś zbędnego tam, gdzie tego nie brakuje', NEW = 'Przekonywać przekonanych';
  for (const x of id.levels.C2) set(file, x, x.bankId, 'options', x.options.map((o) => (o === OLD ? NEW : o)), 'AmE (idiom brytyjski)');
  const c3 = q('idiom-v1-C2-03');
  set(file, c3, c3.bankId, 'prompt', 'Co oznacza „Preach to the choir” w tym kontekście?', 'AmE (idiom brytyjski)');
  set(file, c3, c3.bankId, 'context', 'Lecturing these volunteers about recycling is preaching to the choir; they already sort everything.', 'AmE (idiom brytyjski)');
  set(file, c3, c3.bankId, 'translation', 'Pouczanie tych wolontariuszy o recyklingu to przekonywanie przekonanych; oni już wszystko segregują.', 'AmE (idiom brytyjski)');
  set(file, c3, c3.bankId, 'explanation', 'Przekonujemy osoby, które już podzielają nasze zdanie, więc wysiłek jest zbędny.', 'AmE (idiom brytyjski)');
  const c4 = q('idiom-v1-C2-04');
  set(file, c4, c4.bankId, 'prompt', "Co oznacza „Stir up a hornet's nest” w tym kontekście?", 'AmE (idiom brytyjski)');
  set(file, c4, c4.bankId, 'context', "Her candid memo stirred up a hornet's nest at headquarters.", 'AmE (idiom brytyjski)');
  set(file, c4, c4.bankId, 'explanation', 'Wypowiedź wywołała w grupie gwałtowne, nieprzyjazne reakcje.', 'AmE (idiom brytyjski)');
  const c5 = q('idiom-v1-C2-05');
  set(file, c5, c5.bankId, 'prompt', 'Co oznacza „A mixed bag” w tym kontekście?', 'AmE (idiom brytyjski)');
  set(file, c5, c5.bankId, 'context', 'The report is a mixed bag: excellent evidence but deeply flawed conclusions.', 'AmE (idiom brytyjski)');
  set(file, c5, c5.bankId, 'explanation', 'Rzecz łączy mocne i słabe strony; jej jakość jest nierówna.', 'AmE (idiom brytyjski)');
  const c11 = q('idiom-v1-C2-11');
  set(file, c11, c11.bankId, 'prompt', 'Co oznacza „Take the bull by the horns” w tym kontekście?', 'AmE (idiom brytyjski)');
  set(file, c11, c11.bankId, 'context', 'Rather than delay the difficult reform, the minister took the bull by the horns.', 'AmE (idiom brytyjski)');
  set(file, c11, c11.bankId, 'translation', 'Zamiast odkładać trudną reformę, minister wziął byka za rogi.', 'AmE (idiom brytyjski)');
  set(file, c11, c11.bankId, 'explanation', tmpl('Take the bull by the horns', 'zmierzyć się stanowczo z trudnym problemem'), 'AmE (idiom brytyjski)');
  save(file, id);
}

// ---------------------------------------------------------------------------
// CZYTANKI
// ---------------------------------------------------------------------------
{
  const file = 'readings.json';
  const rd = load(file);
  const r = (rid) => rd.readings.find((x) => x.id === rid);
  const rep = (rid, path, from, to, cat) => {
    const x = r(rid);
    const [kind, i, sub] = path; // ['p', n] | ['q', n, field] | ['o', n, k]
    if (kind === 'p') {
      const ps = [...x.paragraphs]; if (!ps[i].includes(from)) throw new Error(`${rid} p${i}: ${from}`);
      ps[i] = ps[i].replace(from, to); set(file, x, rid, 'paragraphs', ps, cat);
    } else {
      const qs = x.questions.map((qq) => ({ ...qq, options: [...qq.options] }));
      if (kind === 'q') { if (!qs[i][sub].includes(from)) throw new Error(`${rid} q${i}.${sub}: ${from}`); qs[i][sub] = qs[i][sub].replace(from, to); }
      if (kind === 'o') { if (!qs[i].options[sub].includes(from)) throw new Error(`${rid} q${i}.o${sub}: ${from}`); qs[i].options[sub] = qs[i].options[sub].replace(from, to); }
      set(file, x, rid, 'questions', qs, cat);
    }
  };
  const has = (rid, s) => JSON.stringify(r(rid)).includes(s);
  if (has('reading-legacy-lunch-for-two', 'some of his salad')) rep('reading-legacy-lunch-for-two', ['p', 0], 'Ben orders it and gives Ana some of his salad.', 'Ben orders it and shares it with Ana.', 'spójność treści');
  if (has('reading-legacy-a-better-way-to-work', 'cancelled')) rep('reading-legacy-a-better-way-to-work', ['o', 1, 3], 'cancelled', 'canceled', 'pisownia BrE');
  if (has('reading-legacy-when-efficiency-becomes-a-habit', 'behaviour')) rep('reading-legacy-when-efficiency-becomes-a-habit', ['q', 1, 'question'], 'behaviour', 'behavior', 'pisownia BrE');
  if (has('reading-legacy-the-value-of-an-unfinished-answer', 'criticised')) rep('reading-legacy-the-value-of-an-unfinished-answer', ['o', 1, 2], 'criticised', 'criticized', 'pisownia BrE');
  const nt = 'reading-v39-night-trains';
  if (has(nt, 'carriages')) {
    rep(nt, ['p', 0], 'several carriages ran half empty', 'several passenger cars ran half empty', 'słownictwo BrE');
    rep(nt, ['p', 1], 'certain empty carriages could be removed', 'certain empty cars could be removed', 'słownictwo BrE');
    rep(nt, ['p', 1], 'keeping the timetable and train length unchanged', 'keeping the schedule and train length unchanged', 'słownictwo BrE');
    rep(nt, ['o', 1, 1], 'Running fewer carriages on quieter nights', 'Running fewer cars on quieter nights', 'słownictwo BrE');
    rep(nt, ['q', 1, 'evidence'], 'certain empty carriages could be removed', 'certain empty cars could be removed', 'słownictwo BrE');
  }
  const wl = 'reading-v39-waiting-list';
  if (has(wl, 'queue')) {
    rep(wl, ['p', 3], 'created a queue for patients', 'created a separate call-in list for patients', 'słownictwo BrE');
    rep(wl, ['p', 3], 'between that queue and the online list', 'between that call-in list and the online list', 'słownictwo BrE');
    rep(wl, ['q', 2, 'question'], 'the new queue', 'the new call-in list', 'słownictwo BrE');
    rep(wl, ['q', 2, 'explanation'], 'Kolejka wspierała', 'Nowa lista telefoniczna wspierała', 'słownictwo BrE');
  }
  if (has('reading-v39-perfect-minutes', 'the scheme as presented')) rep('reading-v39-perfect-minutes', ['p', 2], 'endorsed the scheme as presented', 'endorsed the plan as presented', 'słownictwo BrE (scheme)');
  const TOPICS = {
    'reading-legacy-a-small-favor': 'praca biuro pożyczać office work',
    'reading-legacy-lunch-for-two': 'restauracja jedzenie restaurant food',
    'reading-legacy-a-change-of-plans': 'lotnisko podróż hotel airport travel',
    'reading-legacy-the-doctors-appointment': 'lekarz zdrowie doctor health',
    'reading-legacy-the-deadline': 'praca termin work deadline',
    'reading-legacy-a-useful-interview-lesson': 'praca rozmowa kwalifikacyjna work interview',
    'reading-legacy-a-better-way-to-work': 'praca zespół work team',
    'reading-legacy-the-quiet-experiment': 'praca biuro work office',
    'reading-legacy-when-efficiency-becomes-a-habit': 'praca biznes logistyka work business',
    'reading-legacy-the-value-of-an-unfinished-answer': 'nauka technologia debata science technology',
    'reading-legacy-the-value-of-leaving-a-question-open': 'środowisko powódź miasto environment flood',
    'reading-legacy-an-archive-that-tells-two-stories': 'historia muzeum kultura history museum',
  };
  for (const [rid, t] of Object.entries(TOPICS)) { const x = r(rid); if (!x) throw new Error(rid); set(file, x, rid, 'topic', t, 'metadane (topic)'); }
  save(file, rd);
}

// ---------------------------------------------------------------------------
// SŁOWA STARTOWE
// ---------------------------------------------------------------------------
{
  const file = 'starter-words.json';
  const sw = load(file);
  const w = (wid) => sw.words.find((x) => x.id === wid);
  const ex = (wid, i, en, pl, focusEn, focusPl) => {
    const x = w(wid);
    const exs = x.examples.map((e) => ({ ...e }));
    exs[i] = { en, pl, focusEn, focusPl };
    if (!en.includes(focusEn) || !pl.includes(focusPl)) throw new Error(`focus ${wid}`);
    set(file, x, wid, 'examples', exs, 'przykład < 6 słów / scena');
  };
  ex('starter.borrow', 0, 'Can I borrow your pen for a minute?', 'Czy mogę na chwilę pożyczyć twój długopis?', 'borrow', 'pożyczyć');
  ex('starter.boarding-pass', 1, 'Keep your boarding pass ready at the gate.', 'Miej kartę pokładową pod ręką przy bramce.', 'boarding pass', 'kartę pokładową');
  ex('starter.it-depends', 0, 'It depends on the weather this weekend.', 'To zależy od pogody w ten weekend.', 'It depends', 'To zależy');
  ex('starter.bank', 0, 'The bank near our house closes at five.', 'Bank niedaleko naszego domu zamyka się o piątej.', 'bank', 'Bank');
  ex('starter.bank-2', 1, 'Tall grass grows along the bank of the stream.', 'Wzdłuż brzegu strumienia rośnie wysoka trawa.', 'bank', 'brzegu');
  ex('starter.reservation', 1, 'Can I change my reservation to Friday?', 'Czy mogę zmienić rezerwację na piątek?', 'reservation', 'rezerwację');
  ex('starter.deadline', 0, 'The deadline for the report is next Friday.', 'Termin oddania raportu mija w przyszły piątek.', 'deadline', 'Termin oddania');
  ex('starter.say', 0, 'Sorry, what did you say about the meeting?', 'Przepraszam, co powiedziałeś o spotkaniu?', 'say', 'powiedziałeś');
  ex('starter.say', 1, 'Could you please say that again more slowly?', 'Czy możesz powiedzieć to jeszcze raz, wolniej?', 'say', 'powiedzieć');
  ex('starter.tell', 0, 'Please tell me the truth about what happened.', 'Proszę, powiedz mi prawdę o tym, co się stało.', 'tell', 'powiedz mi');
  ex('starter.make', 0, 'Let’s make a plan for the weekend.', 'Zróbmy plan na weekend.', 'make', 'Zróbmy');
  ex('starter.make', 1, 'I want to make dinner for my parents tonight.', 'Chcę dziś wieczorem zrobić kolację dla rodziców.', 'make', 'zrobić');
  ex('starter.do-2', 0, 'Do you like coffee with milk in the morning?', 'Czy lubisz rano kawę z mlekiem?', 'Do', 'Czy');
  ex('starter.do-2', 1, 'Do you work here, or are you a customer?', 'Czy pan tu pracuje, czy jest pan klientem?', 'Do', 'Czy');
  ex('starter.do-3', 1, 'A small bag will do for a weekend trip.', 'Na weekendowy wyjazd wystarczy mała torba.', 'do', 'wystarczy');
  ex('starter.appointment', 1, 'Can I book an appointment for next week?', 'Czy mogę umówić wizytę na przyszły tydzień?', 'appointment', 'umówić wizytę');
  ex('starter.recommend', 0, 'What dish do you recommend for dinner tonight?', 'Jakie danie polecasz na dzisiejszą kolację?', 'recommend', 'polecasz');
  ex('starter.recommend', 1, "I recommend the vegetable soup; it's homemade.", 'Polecam zupę warzywną, jest domowej roboty.', 'recommend', 'Polecam');
  ex('starter.strength', 0, 'I think my greatest strength is patience.', 'Myślę, że moją największą mocną stroną jest cierpliwość.', 'strength', 'mocną stroną');
  const d = w('starter.do');
  set(file, d, d.id, 'translation', 'robić, wykonywać', 'tłumaczenie (opis zamiast odpowiednika)');
  set(file, d, d.id, 'acceptedTranslations', ['robić, wykonywać', 'robić', 'zrobić', 'wykonywać', 'wykonać'], 'tłumaczenie (opis zamiast odpowiednika)');
  const d2 = w('starter.do-2');
  set(file, d2, d2.id, 'translation', 'czy (w pytaniach)', 'tłumaczenie (opis zamiast odpowiednika)');
  set(file, d2, d2.id, 'acceptedTranslations', ['czy (w pytaniach)', 'czy'], 'tłumaczenie (opis zamiast odpowiednika)');
  set(file, d2, d2.id, 'notePl', 'Do jako czasownik pomocniczy tworzy pytania w Present Simple i samo nic nie znaczy: Do you like…? = Czy lubisz…?', 'tłumaczenie (opis zamiast odpowiednika)');
  save(file, sw);
}


const byCat = {}; const byFile = {};
for (const l of log) { byCat[l.cat] = (byCat[l.cat] || 0) + 1; byFile[l.file] = (byFile[l.file] || 0) + 1; }
console.log('zmian pól:', log.length); console.log(byFile); console.log(byCat);
