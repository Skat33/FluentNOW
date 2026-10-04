import test from "node:test";
import assert from "node:assert/strict";
import { seed, recordAnswer, mastery, masterySkills } from "../lib/learning.ts";
import {
  starterLookup,
  mergeSuggestions,
  localGrade,
  examplePair,
  estimatedLevel,
  starterReading,
  recommendations,
  starterPractice,
  resolveExistingCollection,
} from "../lib/tutor-local.ts";
import {
  lookupSchema,
  readingSchema,
  readingSessionSchema,
  practiceSetSchema,
  topicListSchema,
  topicHydrateSchema,
  cefrAuditSchema,
} from "../lib/tutor-schema.ts";
import { stateSchema } from "../lib/state-schema.ts";

test("do offers separate senses and only selected senses are added to automatically created collections", () => {
  const lookup = starterLookup("do");
  assert.equal(lookup.meanings.length, 3);
  assert.ok(lookupSchema.safeParse(lookup).success);
  const s = { ...seed(), words: [], reviews: [], collections: [] };
  const next = mergeSuggestions(s, lookup, [1, 2]);
  assert.equal(next.words.flatMap((w) => w.meanings).length, 2);
  assert.equal(next.collections.length, 2);
  assert.ok(next.words.every((w) => w.meanings.length === 1));
  assert.equal(s.words.length, 0);
  assert.ok(stateSchema.safeParse(next).success);
});
test("re-adding an existing sense preserves its identity and learning history even when suggested collection differs", () => {
  const s = seed(),
    lookup = starterLookup("lend"),
    before = s.words.find((w) => w.en === "lend");
  lookup.meanings[0].collection = "Inna kolekcja";
  const next = mergeSuggestions(s, lookup, [0]);
  assert.deepEqual(
    next.words.find((w) => w.en === "lend"),
    before,
  );
  assert.equal(next.words.length, s.words.length);
  assert.deepEqual(next.reviews, s.reviews);
});
test("topic vocabulary reuses the earliest matching situational collection", () => {
  assert.equal(
    resolveExistingCollection(
      ["W restauracji", "Restauracja", "Podróże"],
      "Restauracja",
      "Restauracja",
    ),
    "W restauracji",
  );
  assert.equal(
    resolveExistingCollection(["W podróży"], "Podróż", "Podróż"),
    "W podróży",
  );
  assert.equal(
    resolveExistingCollection(["Lotnictwo"], "Lotnisko", "Lotnisko"),
    null,
    "nearby but different subjects must not be merged",
  );
  const lookup = starterLookup("reservation");
  lookup.meanings[0].collection = "Restauracja";
  lookup.meanings[0].topic = "Restauracja";
  const state = {
    ...seed(),
    words: [],
    reviews: [],
    collections: ["W restauracji"],
  };
  const automatic = mergeSuggestions(state, lookup, [0]);
  assert.deepEqual(automatic.collections, ["W restauracji"]);
  assert.equal(automatic.words[0].collection, "W restauracji");
  const manual = mergeSuggestions(state, lookup, [0], "Moja restauracja");
  assert.ok(manual.collections.includes("Moja restauracja"));
  assert.equal(manual.words[0].collection, "Moja restauracja");
});
test("accepts lend someone for recall but preserves directional, grammatical and dictation distinctions", () => {
  const w = seed().words.find((w) => w.en === "lend"),
    m = w.meanings[0];
  assert.equal(localGrade("lend someone", w, m, 1).verdict, "correct");
  assert.equal(localGrade("to lend somebody", w, m, 1).verdict, "correct");
  assert.equal(localGrade("borrow from someone", w, m, 1).verdict, "incorrect");
  assert.notEqual(localGrade("never lend someone", w, m, 1).verdict, "correct");
  assert.equal(localGrade("lend someone", w, m, 2).verdict, "incorrect");
  assert.equal(localGrade("to lend", w, m, 2).verdict, "incorrect");
  assert.equal(localGrade("to lend", w, m, 4).verdict, "incorrect");
  assert.equal(localGrade("lend", w, m, 4).verdict, "correct");
  assert.equal(
    localGrade("lend someone", w, { ...m, translation: "nadawać wsparcie" }, 1)
      .verdict,
    "incorrect",
  );
});
test("vocabulary recall and dictation reject unlisted spelling mistakes", () => {
  const w = seed().words.find((w) => w.en === "lend"),
    m = w.meanings[0];
  const recall = localGrade("lnd", w, m, 1),
    dictation = localGrade("lnd", w, m, 4);
  assert.equal(recall.verdict, "incorrect");
  assert.equal(recall.spellingCorrect, false);
  assert.equal(dictation.verdict, "incorrect");
  assert.equal(dictation.spellingCorrect, false);
});
test("all starter meanings have complete Polish sentence translations with actual highlighted spans", () => {
  for (const w of seed().words)
    for (const m of w.meanings)
      for (let i = 0; i < m.examples.length; i++) {
        const p = examplePair(w, m, i);
        assert.ok(p, `${w.en}: missing translation`);
        assert.equal(p.en, m.examples[i]);
        assert.ok(p.pl.toLowerCase().includes(p.focusPl.toLowerCase()));
        assert.ok(p.en.toLowerCase().includes(p.focusEn.toLowerCase()));
      }
  assert.equal(starterLookup("zzxxyybogus"), null);
});
test("spelling errors do not erase correct meaning recall and another bank sense remains untouched", () => {
  const s = seed(),
    w = s.words.find((w) => w.en === "bank"),
    m = w.meanings[0];
  const other = structuredClone(w.meanings[1]);
  const next = recordAnswer(
    s,
    { wordId: w.id, meaningId: m.id, type: 1, example: 0 },
    true,
    4,
    3,
    false,
    false,
  );
  const actual = next.words.find((x) => x.id === w.id);
  assert.ok(actual.meanings[0].scores.recall.value > m.scores.recall.value);
  assert.ok(actual.meanings[0].scores.spelling.value < m.scores.spelling.value);
  assert.deepEqual(actual.meanings[1], other);
  assert.equal(next.reviews.at(-1).error, "Pisownia");
});
test("reading level is based on practiced senses; passages have four choices and supporting evidence", () => {
  assert.equal(estimatedLevel({ ...seed(), words: [] }).level, "A1");
  for (const level of ["A1", "A2", "B1", "B2", "C1", "C2"]) {
    const r = starterReading(level);
    assert.ok(readingSchema.safeParse(r).success);
    assert.ok(
      readingSessionSchema.safeParse({
        reading: r,
        answers: r.questions.map(() => -1),
        submitted: false,
      }).success,
    );
    assert.equal(
      readingSessionSchema.safeParse({
        reading: r,
        answers: [],
        submitted: false,
      }).success,
      false,
    );
  }
  const old = seed();
  assert.ok(stateSchema.safeParse(old).success);
  const reading = starterReading("A2");
  old.reading = {
    reading,
    answers: reading.questions.map((q) => q.answer),
    submitted: true,
  };
  assert.ok(stateSchema.safeParse(old).success);
});
test("higher-level suggestions appear only after mastery and omit existing words", () => {
  const s = seed();
  s.words.forEach((w) =>
    w.meanings.forEach((m) =>
      Object.values(m.scores).forEach((x) => (x.interval = 0)),
    ),
  );
  assert.equal(recommendations(s).length, 0);
  const w = s.words.find((w) => w.en === "do");
  const template = Object.values(w.meanings[0].scores)[0];
  for (const skill of masterySkills)
    w.meanings[0].scores[skill] = {...template, interval:90, value:100};
  assert.ok(recommendations(s).some((r) => r.term === "carry out"));
  assert.ok(lookupSchema.safeParse(starterLookup("carry out")).success);
});
test("grammar, idiom and mixed practice sets remain valid at every learner level", () => {
  for (const level of ["A1", "A2", "B1", "B2", "C1", "C2"])
    for (const kind of ["grammar", "idioms", "mixed"]) {
      const set = starterPractice(kind, level);
      assert.ok(practiceSetSchema.safeParse(set).success, `${kind} ${level}`);
      assert.equal(set.items.length, 6);
      if (kind === "mixed")
        assert.deepEqual(
          new Set(set.items.map((item) => item.category)),
          new Set(["grammar", "idiom"]),
        );
      const state = seed();
      state.practice = {
        set,
        answers: set.items.map(() => -1),
        index: 0,
      };
      assert.ok(stateSchema.safeParse(state).success);
    }
});
test("topic list stays lightweight and topic hydration contains complete meanings", () => {
  const item = (term) => ({
    term,
    pl: `tłumaczenie ${term}`,
    pos: "rzeczownik",
    level: "A1",
    spokenFrequency: "common",
  });
  const parsed = topicListSchema.safeParse({
    topic: "praca",
    categories: Array.from({ length: 5 }, (_, categoryIndex) => ({
      name: `Kategoria ${categoryIndex + 1}`,
      items: [item(`hasło ${categoryIndex + 1}`)],
    })),
  });
  assert.ok(parsed.success);
  const hydrated = ["do", "bank", "lend"].map((term) => {
    const lookup = starterLookup(term);
    lookup.meanings = lookup.meanings.slice(0, 1);
    return lookup;
  });
  assert.ok(topicHydrateSchema.safeParse({ items: hydrated }).success);
});
test("topic list accepts more than two hundred lightweight items", () => {
  const categories = Array.from({ length: 5 }, (_, categoryIndex) => ({
    name: `Kategoria ${categoryIndex + 1}`,
    items: Array.from({ length: 45 }, (_, itemIndex) => ({
      term: `term ${categoryIndex}-${itemIndex}`,
      pl: `hasło ${categoryIndex}-${itemIndex}`,
      pos: "rzeczownik",
      level: ["A1", "A2", "B1", "B2", "C1", "C2"][itemIndex % 6],
      spokenFrequency: "common",
    })),
  }));
  assert.ok(topicListSchema.safeParse({ topic: "praca", categories }).success);
  const items = Array.from({ length: 40 }, () => starterLookup("lend"));
  assert.ok(
    cefrAuditSchema.safeParse({
      assessments: items.map((_, itemIndex) => ({
        itemIndex,
        meaningIndex: 0,
        level: "B1",
        confidence: "high",
        spokenFrequency: "common",
        reason: "Częste słowo używane samodzielnie w typowych sytuacjach.",
      })),
    }).success,
  );
});
import { gradeProduction, starterProduction, normalizeProduction, productionRules, productionPool } from "../lib/production.ts";
import { productionSetSchema } from "../lib/tutor-schema.ts";
import { readPrepared, rememberPrepared, warmPrepared } from "../lib/prepared-content.ts";

test("prepared sets are validated, scoped to the request, deduplicated and stop retrying on outage", async () => {
  const original = globalThis.fetch;
  const valid = value => { assert.equal(value?.ready,true); return value; };
  const ready = {action:"practice",topic:"cache test",variant:0};
  rememberPrepared(ready,{ready:true});
  assert.deepEqual(readPrepared(ready,valid),{ready:true});
  assert.equal(readPrepared({...ready,topic:"different"},valid),null);
  rememberPrepared({...ready,variant:1},{corrupt:true});
  assert.equal(readPrepared({...ready,variant:1},valid),null);
  let calls = 0, finish;
  globalThis.fetch = async () => { calls++; return await new Promise(resolve => {finish = resolve;}); };
  const next = {...ready,variant:2};
  try {
    warmPrepared(next,valid);
    warmPrepared(next,valid);
    assert.equal(calls,1);
    assert.equal(readPrepared(next,valid),null,"current session cannot read unfinished preparation");
    finish(Response.json({ready:true}));
    await new Promise(resolve=>setTimeout(resolve,10));
    assert.deepEqual(readPrepared(next,valid),{ready:true});
    globalThis.fetch = async () => { calls++; return Response.json({code:"PROVIDER",error:"outage"},{status:503}); };
    warmPrepared({...ready,variant:3},valid);
    await new Promise(resolve=>setTimeout(resolve,10));
    warmPrepared({...ready,variant:4},valid);
    assert.equal(calls,2,"provider outage must not trigger a background retry storm");
    assert.equal(readPrepared({...ready,variant:3},valid),null);
    assert.equal(starterPractice("grammar","B1",3).items.length,6,"offline bank remains available");
  } finally { globalThis.fetch = original; }
});

test("C: all twelve offline production tasks are valid; tense, agreement and typos differ", () => {
  for (const level of ["A2","B1","B2"]) {
    const set = starterProduction(level);
    assert.equal(set.items.length, 4);
    assert.equal(productionSetSchema.safeParse(set).success,true);
    for (const item of set.items) {
      assert.ok(productionRules[level].includes(item.rule));
      assert.equal(gradeProduction(item.answer,item).correct,true);
      for (const accepted of item.acceptedAnswers) assert.equal(gradeProduction(accepted,item).correct,true);
      for (const d of item.distractors) {
        const grade = gradeProduction(d.form,item);
        assert.equal(grade.correct,false);
        assert.equal(grade.diagnosis,d.diagnosis);
        assert.equal(grade.explanation,d.explanation);
      }
    }
  }
  const item = starterProduction("B2").items[0];
  assert.equal(gradeProduction("had been flyng",item).spellingCorrect,false);
  assert.equal(gradeProduction("had been flyng",item).correct,true);
  assert.equal(gradeProduction("They’d been flying!",item).correct,true);
  assert.equal(gradeProduction("flew",item).diagnosis,"wrong_aspect");
  const near = {...item,answer:"is flying",rule:"present continuous",distractors:[{form:"was flying",diagnosis:"wrong_tense",explanation:"Przeszłość zamiast teraźniejszości."}]};
  assert.equal(gradeProduction("was flying",near).correct,false);
  assert.equal(gradeProduction("was",productionPool("A1")[0]).correct,false,"unlisted auxiliary changes are not typos");
  assert.equal(gradeProduction("",item).correct,false);
  assert.equal(normalizeProduction("didn't",item),"did not");
  assert.equal(normalizeProduction("they'd called",{...item,context:"If they ________ (zadzwonić) yesterday, we would have come.",answer:"had called",rule:"third conditional"}),"had called");
  assert.equal(normalizeProduction("I'd help",{...item,context:"If you asked, I ________ (pomóc).",answer:"would help",rule:"second conditional"}),"would help");
  assert.equal(normalizeProduction("she's studying",{...item,context:"She ________ (uczyć się) now.",answer:"is studying",rule:"present continuous"}),"is studying");
  assert.equal(normalizeProduction("she's studied",{...item,context:"She ________ (uczyć się) today.",answer:"has studied",rule:"present perfect"}),"has studied");
  assert.equal(starterProduction("C2").level,"C2");
  const ten = {...starterProduction("B2"),items:Array.from({length:10},(_,i)=>starterProduction("B2").items[i%4])};
  assert.ok(Buffer.byteLength(JSON.stringify(ten),"utf8") < 32768);
});

test("expanded bank has at least 300 distinct grammar contexts at every CEFR and rotating valid sets", () => {
  const seen = new Set();
  for (const level of ["A1","A2","B1","B2","C1","C2"]) {
    const pool = productionPool(level);
    assert.ok(pool.length>=300);
    for (const item of pool) {
      assert.ok(!seen.has(item.context)); seen.add(item.context);
      assert.ok(productionRules[level].includes(item.rule), `${level}: ${item.rule}`);
      assert.equal(gradeProduction(item.answer,item).correct,true);
      for (const accepted of item.acceptedAnswers) assert.equal(gradeProduction(accepted,item).correct,true);
      for (const d of item.distractors) assert.equal(gradeProduction(d.form,item).correct,false, `${item.answer}: ${d.form}`);
    }
    for (let variant=0;variant<3;variant++) {
      assert.ok(productionSetSchema.safeParse(starterProduction(level,variant)).success,level);
      for (const kind of ["grammar","idioms","mixed"])
        assert.ok(practiceSetSchema.safeParse(starterPractice(kind,level,variant)).success, `${level} ${kind} ${variant}`);
    }
    assert.notEqual(starterProduction(level,0).items[0].context,starterProduction(level,1).items[0].context);
    assert.notEqual(starterPractice("grammar",level,0).items[0].context,starterPractice("grammar",level,1).items[0].context);
    const r=starterReading(level,[]);
    assert.equal(r.level,level);
    assert.ok(readingSchema.safeParse(r).success);
  }
  assert.equal(seen.size,1872);
});

import { appendExampleGroup, applyEnrichment, meaningSignature, hydrateMeaning } from "../lib/meaning-enrichment.ts";
import { idiomPool } from "../lib/data/idiom-bank.ts";

test("new vocabulary accumulates fifteen distinct examples, preserves progress and rejects stale responses",()=>{
  const s=seed(),w=s.words[0];
  const base={...w.meanings[0],examples:[],exampleTranslations:[],enrichment:{phase:"examples",detailsPending:true,groups:[],attempts:0,retryAt:0}};
  w.meanings=[base];
  const batch=kind=>Array.from({length:5},(_,i)=>({en:`${kind} example ${i}`,pl:`${kind} zdanie ${i}`,focusEn:"example",focusPl:"zdanie"}));
  let m=appendExampleGroup(base,"affirmative",batch("affirmative"));
  assert.equal(m.examples.length,5);
  assert.equal(appendExampleGroup(m,"affirmative",batch("affirmative")),m,"retry must not duplicate a completed group");
  assert.throws(()=>appendExampleGroup(m,"negative",batch("affirmative")),/DUPLICATE/);
  m=appendExampleGroup(m,"negative",batch("negative"));
  m=appendExampleGroup(m,"question",batch("question"));
  assert.equal(m.examples.length,15);
  assert.deepEqual(m.enrichment.groups,["affirmative","negative","question"]);
  assert.equal(m.enrichment.phase,"details");
  const hydrated=hydrateMeaning(m,starterLookup("lend"));
  assert.equal(hydrated.enrichment.phase,"ready");
  assert.deepEqual(hydrated.examples,m.examples,"metadata must not replace the 15 prepared examples with two");
  assert.deepEqual(hydrated.scores,base.scores);
  const updated=applyEnrichment(s,w.id,base.id,meaningSignature(w.en,base),()=>m);
  assert.equal(updated.words[0].meanings[0].examples.length,15);
  assert.ok(updated.words[0].updatedAt);
  const edited=structuredClone(s);edited.words[0].meanings[0].translation="zmieniono znaczenie";
  assert.deepEqual(applyEnrichment(edited,w.id,base.id,meaningSignature(w.en,base),()=>m),edited);
  const deleted={...s,words:[]};
  assert.deepEqual(applyEnrichment(deleted,w.id,base.id,meaningSignature(w.en,base),()=>m),deleted);
  assert.ok(stateSchema.safeParse(JSON.parse(JSON.stringify(updated))).success);
});

test("idiom bank has 18 contexts per level and three disjoint sessions with different distractors",()=>{
  for (const level of ["A1","A2","B1","B2","C1","C2"]) {
    assert.equal(idiomPool(level).length,18);
    const seen=new Set();
    for(let variant=0;variant<3;variant++) {
      const set=starterPractice("idioms",level,variant);
      assert.ok(practiceSetSchema.safeParse(set).success);
      for(const item of set.items){assert.ok(!seen.has(item.context),level);seen.add(item.context);}
    }
    assert.equal(seen.size,18);
    assert.notDeepEqual(idiomPool(level,0)[0].options,idiomPool(level,1)[0].options);
  }
});

import { authoredGrammar, selectGrammarItems, grammarTaskId, markGrammarSeen } from "../lib/grammar-bank.ts";
import { productionItemSchema } from "../lib/tutor-schema.ts";
test("v36 bank has 300 new complete exercises per level, unique stable IDs and balanced patterns",()=>{
 const ids=new Set(),contexts=new Set();
 for(const level of ["A1","A2","B1","B2","C1","C2"]) {
  const items=authoredGrammar(level);assert.equal(items.length,300);
  const rules=new Map();
  for(const item of items) {
   const valid=productionItemSchema.safeParse(item);
   assert.ok(valid.success,`${item.bankId}: ${valid.error?.message}`);
   assert.ok(!ids.has(item.bankId));ids.add(item.bankId);
   assert.ok(!contexts.has(item.context));contexts.add(item.context);
   rules.set(item.rule,(rules.get(item.rule)||0)+1);
   assert.equal(gradeProduction(item.answer,item).correct,true);
   for(const answer of item.acceptedAnswers) assert.equal(gradeProduction(answer,item).correct,true);
   for(const wrong of item.distractors) assert.equal(gradeProduction(wrong.form,item).correct,false,item.bankId);
  }
  assert.equal(rules.size,15);assert.ok([...rules.values()].every(n=>n===20));
 }
 assert.equal(ids.size,1800);
});

test("v36 never repeats a sentence across grammar and typed sessions until the level is exhausted",()=>{
 for(const level of ["A1","A2","B1","B2","C1","C2"]) {
  const seen={}; const size=productionPool(level).length;
  for(let session=0;session<size/6;session++) {
   const set=session%2 ? starterPractice("grammar",level,session,seen) : starterProduction(level,session,6,seen);
   assert.equal(set.items.length,6);
   for(const item of set.items) { assert.ok(!seen[item.bankId],`${level}: repeated ${item.bankId}`); seen[item.bankId]=session*6+Object.keys(seen).length+1; }
  }
  assert.equal(Object.keys(seen).length,size);
  const oldest=Math.min(...Object.values(seen));
  const repeat=selectGrammarItems(productionPool(level),6,seen,999);
  assert.equal(seen[repeat[0].bankId],oldest);
  assert.equal(new Set(repeat.map(i=>i.bankId)).size,6);
 }
});

test("v36 mixes rules and settings, keeps ABCD answers aligned and shares exposure with mixed practice",()=>{
 const pool=productionPool("C1"),seen={};
 const selected=selectGrammarItems(pool,6,seen,7);
 assert.ok(new Set(selected.map(i=>i.rule)).size>=4);
 assert.ok(new Set(selected.map(i=>i.scenarioId).filter(Boolean)).size>=4);
 for(const item of selected) seen[item.bankId]=Date.now();
 const mixed=starterPractice("mixed","C1",8,seen);
 for(const item of mixed.items.filter(i=>i.category==="grammar")) {
  assert.ok(!seen[item.bankId]);
  const original=pool.find(p=>p.bankId===item.bankId);
  assert.equal(item.options[item.answer],original.answer);
  assert.equal(new Set(item.options).size,4);
 }
 const marked=markGrammarSeen(seed(),selected[0],123);
 assert.equal(marked.grammarSeen[grammarTaskId(selected[0])],123);
});

import { grammarSelectionSeen } from "../lib/grammar-bank.ts";
test("v36 paused sessions reserve unshown tasks across modes without falsely marking them viewed",()=>{
 let state=seed();
 const first=starterProduction('B1',0,6,{});
 state.production={id:'paused',set:first,source:'starter',index:0,answers:Array(6).fill(''),results:Array(6).fill(null)};
 state=markGrammarSeen(state,first.items[0],100);
 const reserved=grammarSelectionSeen(state);
 const next=starterPractice('grammar','B1',1,reserved);
 assert.ok(next.items.every(i=>!first.items.some(p=>p.bankId===i.bankId)));
 assert.equal(Object.keys(state.grammarSeen).length,1);
 state.production=null;
 assert.equal(Object.keys(grammarSelectionSeen(state)).length,1,'abandoned unseen items become eligible again');
});


test("vocabulary uses saved alternatives, ignores Polish diacritics but rejects arbitrary variants", () => {
 const w=seed().words.find(w=>w.en==="lend"),m=w.meanings[0];
 const meaning={...m,translation:"pożyczyć komuś; użyczyć",acceptedAnswers:["lend someone","lend somebody"]};
 for(const answer of ["pozyczyc komus","POŻYCZYĆ  KOMUŚ!","uzyczyc"])
   assert.equal(localGrade(answer,w,meaning,3).verdict,"correct",answer);
 for(const answer of ["pozyczy","pożyczyć od kogoś","pozyczyc komus cos"])
   assert.equal(localGrade(answer,w,meaning,3).verdict,"incorrect",answer);
 assert.equal(localGrade("lend somebody",w,meaning,1).verdict,"correct");
 assert.equal(localGrade("lending somebody",w,meaning,1).verdict,"incorrect");
 assert.equal(localGrade("lent",{...w,en:"lent"},meaning,2).verdict,"correct");
 assert.equal(localGrade("lend",{...w,en:"lent"},meaning,2).verdict,"incorrect");
 assert.equal(localGrade("",w,meaning,1).verdict,"incorrect");
});

import { exerciseAudioText,vocabularyAudioText,SPEECH_GAP } from "../lib/exercise-audio.ts";
import { saveExerciseReport,readExerciseReports,reportStorageKey } from "../lib/exercise-reports.ts";
test("audio leaves silent gaps before checking and fills the answer key after checking", () => {
 const question="If I had time, I ________ (podróżować) more.";
 assert.equal(exerciseAudioText(question,false,"would travel"),`If I had time, I ${SPEECH_GAP} more.`);
 assert.equal(exerciseAudioText(question,true,"would travel"),"If I had time, I would travel more.");
 assert.equal(exerciseAudioText("She broke the ice.",false,"przełamała lody"),"She broke the ice.");
 assert.equal(vocabularyAudioText("Can you lend me a pen?","lend",true),`Can you ${SPEECH_GAP} me a pen?`);
 assert.equal(vocabularyAudioText("Can you lend me a pen?","lend",false),"Can you lend me a pen?");
 assert.equal(vocabularyAudioText("She borrowed a pen.","borrowed",true),`She ${SPEECH_GAP} a pen.`);
 assert.equal(vocabularyAudioText("She borrowed a pen.","lend",true),"");
 assert.equal(vocabularyAudioText("She borrowed a pen.","borrow",true),"");
 assert.equal(vocabularyAudioText("Lend, please lend!","lend",true),`${SPEECH_GAP}, please ${SPEECH_GAP}!`);
});
test("reports persist locally by account and preserve question, variants and user's answer", () => {
 const data=new Map();const storage={getItem:k=>data.get(k)||null,setItem:(k,v)=>data.set(k,v)};
 const snapshot={mode:"Słowa w parach",question:"Can you lend me a pen?",answer:"borrow",expected:["lend","lend someone"],wordId:"word",meaningId:"meaning"};
 const report=saveExerciseReport(storage,"account-A",snapshot,"  My note  ",123);
 assert.equal(report.comment,"My note");assert.equal(report.status,"local");
 assert.deepEqual(readExerciseReports(storage,"account-A"),[report]);
 assert.deepEqual(readExerciseReports(storage,"account-B"),[]);
 assert.deepEqual(report.expected,snapshot.expected);
 assert.throws(()=>saveExerciseReport({...storage,setItem:()=>{throw Error("QuotaExceeded");}},"account-A",snapshot,""),/QuotaExceeded/);
 assert.equal(readExerciseReports(storage,"account-A").length,1);
 data.set(reportStorageKey("broken"),"invalid json");
 assert.throws(()=>saveExerciseReport(storage,"broken",snapshot,""));
 assert.equal(data.get(reportStorageKey("broken")),"invalid json");
});


import {readingBank,selectBankReading} from "../lib/reading-bank.ts";
import {readingTokens} from "../lib/reading-vocabulary.ts";
test("v39 authored readings grow by level, have supported distinct answers and do not repeat early",()=>{
 const ranges={A1:[90,120,3],A2:[130,170,4],B1:[190,240,4],B2:[250,300,5],C1:[310,360,5],C2:[380,450,6]};
 assert.equal(readingBank.length,30);assert.equal(new Set(readingBank.map(r=>r.title)).size,30);
 for(const [level,[min,max,questions]] of Object.entries(ranges)) {
  const pool=readingBank.filter(r=>r.level===level);assert.equal(pool.length,5);const history=[];
  for(const r of pool){const words=r.paragraphs.join(" ").split(/\s+/).length;assert.ok(words>=min && words<=max,`${r.title}: ${words}`);assert.equal(r.questions.length,questions);assert.ok(readingSchema.safeParse(r).success,r.title);}
  for(let i=0;i<pool.length;i++){const r=selectBankReading(level,history);assert.ok(!history.some(x=>x.id===r.id));history.push({id:r.id,at:i+1});}
  assert.equal(selectBankReading(level,history).id,history[0].id);
 }
 assert.match(selectBankReading("B1",[],"lotnisko").title,/connection/);
});
test("reading highlights whole saved phrases and forms, never substrings or archived words",()=>{
 const template=seed().words[0];
 const words=[{...template,id:"bank",en:"bank",meanings:[{...template.meanings[0],id:"sense-bank",translation:"bank",exampleFocusEn:["banks"]}]},{...template,id:"pass",en:"boarding pass"},{...template,id:"hidden",en:"passport",archived:true}];
 const text="My boarding pass is in the bank; banking apps and banks work. Passport.";
 const tokens=readingTokens(text,words);assert.equal(tokens.map(t=>t.text).join(""),text);
 assert.deepEqual(tokens.filter(t=>t.word).map(t=>t.text),["boarding pass","bank","banks"]);
});
test("mixed sets contain two keyed written questions at every level",()=>{
 for(const level of ["A1","A2","B1","B2","C1","C2"]){const set=starterPractice("mixed",level,2);const input=set.items.filter(i=>i.format==="input");assert.equal(input.length,2);assert.equal(set.items.length-input.length,4);assert.ok(input.every(i=>i.inputHint && /_{2,}/.test(i.context) && i.options[i.answer]));}
});


import {checkPracticeInput} from "../lib/practice-input.ts";
test("written mixed grading uses the key and listed alternatives without guessing",()=>{
 const item=starterPractice("mixed","B1",0).items[0];
 assert.equal(checkPracticeInput(item,item.options[item.answer]).choice,item.answer);
 assert.equal(checkPracticeInput(item,"definitely not the answer").correct,false);
 assert.equal(checkPracticeInput({...item,acceptedAnswers:["another saved form"]},"ANOTHER SAVED FORM").correct,true);
 assert.equal(checkPracticeInput(item,"").correct,false);
});

import {polishAnswers,withoutDialectLabel} from '../lib/answer-variants.ts';
test('v41: reviewed Polish equivalents preserve meaning, direction and negation across domains',()=>{
 const cases=[
  ['borrow','pożyczyć od kogoś',['pożyczać','pozyczac','wypożyczyć',' POŻYCZYĆ. '],['pożyczyć komuś','oddać','nie pożyczać']],
  ['lend','pożyczyć komuś',['pożyczać','pozyczyc komus','udzielić pożyczki'],['pożyczyć od kogoś','zabrać']],
  ['bank','brzeg rzeki',['brzeg','brzeg rzeczny'],['bank finansowy','instytucja finansowa']],
  ['bank','bank',['instytucja finansowa','bank finansowy'],['brzeg','brzeg rzeki']],
  ['recommend','polecać',['polecić','rekomendowac','zalecać'],['odradzać','nie polecać']],
  ['boarding pass','karta pokładowa',['bilet pokładowy','KARTA POKLADOWA!'],['paszport','bilet lotniczy']],
  ['deadline','termin wykonania',['ostateczny termin','termin'],['rezerwacja','termin rozpoczęcia']],
  ['check','rachunek (AmE)',['rachunek','rachunek do zaplaty'],['sprawdzić','paragon']],
  ['check','sprawdzić',['sprawdzać','skontrolować'],['rachunek','rachunek do zapłaty']],
  ['receipt','paragon',['pokwitowanie','potwierdzenie zaplaty'],['rachunek','menu']],
  ['appointment','umówiona wizyta',['wizyta','termin wizyty'],['umówione spotkanie','rezerwacja']],
  ['turn down','odrzucić',['odmówić','odrzucać'],['ściszyć','zmniejszyć głośność']],
  ['turn down','ściszyć',['zmniejszyć głośność','ściszać'],['odmówić','odrzucić']],
  ['look after','opiekować się',['dbać o','zaopiekowac sie'],['szukać','patrzeć za']],
  ['take your time','nie spiesz się',['nie śpiesz się','bez pospiechu'],['spiesz się','spokojnie idź']],
  ['get the hang of','załapać, jak to działa',['nabrać wprawy','opanować'],['bardzo rzadko','odpuścić']],
  ['do','czasownik pomocniczy w pytaniach',['czasownik pomocniczy w pytaniach'],['zrobić','wystarczyć']],
 ];
 for(const [en,translation,yes,no] of cases){
  const w={en,pos:'czasownik'},m={translation,acceptedAnswers:[],pos:'czasownik'};
  for(const a of yes)assert.equal(localGrade(a,w,m,3).verdict,'correct',`${en}/${translation}: ${a}`);
  for(const a of no)assert.equal(localGrade(a,w,m,3).verdict,'incorrect',`${en}/${translation}: ${a}`);
 }
 const custom={translation:'niezwykle staranny',acceptedTranslations:['skrupulatny','bardzo dokładny'],acceptedAnswers:['meticulous']};
 assert.equal(localGrade('SKRUPULATNY.',{en:'meticulous'},custom,3).verdict,'correct');
 assert.equal(localGrade('meticulous',{en:'meticulous'},custom,3).verdict,'incorrect');
 assert.equal(withoutDialectLabel('rachunek (AmE)'),'rachunek');
 assert.equal(withoutDialectLabel('brać na wynos (BrE)'),'brać na wynos');
 assert.equal(withoutDialectLabel('zamek (w drzwiach)'),'zamek (w drzwiach)');
});

test('v41: all CEFR grammar bank canonical forms and contractions pass, saved distractors fail',()=>{
 let checked=0;
 for(const level of ['A1','A2','B1','B2','C1','C2'])for(const item of productionPool(level)){
  const q={category:'grammar',options:[item.answer,...item.distractors.map(d=>d.form)],answer:0,acceptedAnswers:item.acceptedAnswers};
  assert.equal(checkPracticeInput(q,item.answer+'!').correct,true,`${level}: ${item.answer}`);
  for(const accepted of item.acceptedAnswers)assert.equal(checkPracticeInput(q,accepted).correct,true);
  for(const wrong of item.distractors)assert.equal(checkPracticeInput(q,wrong.form).correct,false,`${level}: ${item.answer} vs ${wrong.form}`);
  checked++;
 }
 assert.ok(checked>=1800);
 for(const [full,short] of [['do not know',"don't know"],['will not go',"won't go"],['cannot swim',"can't swim"],['are reading',"'re reading"]]){
  const q={category:'grammar',options:[full],answer:0};
  assert.equal(checkPracticeInput(q,short).correct,true);
  assert.equal(checkPracticeInput(q,full.replace('not ','')).correct,!full.includes('not '));
 }
});

test('v41: legacy Polish verbs accept both aspects without guessing suffixes or deleting negation',()=>{
 for(const [en,base,variant] of [['buy','kupić','kupować'],['sell','sprzedawać','sprzedać'],['pay','zapłacić','płacić'],['forget','zapomnieć','zapominać'],['learn','uczyć się','nauczyć się'],['leave','wyjść','wychodzić'],['clean','posprzątać','sprzątać'],['bake','upiec','piec'],['refuse','odmówić','odmawiać'],['agree','zgodzić się','zgadzać się']]){
  assert.equal(localGrade(variant,{en},{translation:base},3).verdict,'correct');
  assert.equal(localGrade('nie '+variant,{en},{translation:base},3).verdict,'incorrect');
 }
 assert.equal(localGrade('pamiętać',{en:'forget'},{translation:'zapomnieć'},3).verdict,'incorrect');
 assert.equal(localGrade('uczyć',{en:'learn'},{translation:'uczyć się'},3).verdict,'incorrect');
});
