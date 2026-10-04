import test from "node:test";
import assert from "node:assert/strict";
import { readFileSync } from "node:fs";
import { starterProduction, gradeProduction } from "../lib/production.ts";
import {
  applyReadingResults,
  allowedTaskTypes,
  interleaveTasks,
  clozeText,
  exercisePromptAudioAllowed,
  makeSession,
  mastery,
  masterySkills,
  masteryFromInterval,
  meaningOptions,
  migrateState,
  recordAnswer,
  schedule,
  seed,
  status,
  taskSeconds,
} from "../lib/learning.ts";
import { stateSchema } from "../lib/state-schema.ts";
import {
  estimatedLevel,
  localGrade,
  selectReadingMeanings,
  starterReading,
  starterPractice,
} from "../lib/tutor-local.ts";
import { nearbyLevel } from "../lib/tutor-server.ts";
import { compactReviews, mergeStates } from "../lib/state-sync.ts";

test("C: v31 export migrates additively and production answers survive export and sync", () => {
  const previous = JSON.parse(readFileSync("tests/fixtures/state-v31.json", "utf8"));
  const migrated = migrateState(structuredClone(previous));
  assert.equal(stateSchema.safeParse(migrated).success, true);
  assert.deepEqual(JSON.parse(JSON.stringify(migrated.words)), previous.words);
  assert.deepEqual(migrated.reviews, previous.reviews.map((r) => ({...r, weight:r.weight ?? 1, source:r.source ?? "exercise"})));
  assert.equal(migrated.production, null);
  assert.ok(migrated.reviews.every((r) => r.masteryVersion === undefined));
  assert.deepEqual(migrated.productionHistory, []);
  const set = starterProduction("B2");
  migrated.production = { id:"production-test", set, source:"starter", index:0,
    answers:set.items.map((item,i)=>i===0?item.answer:""),
    results:set.items.map((item,i)=>i===0?gradeProduction(item.answer,item):null) };
  const restored = migrateState(stateSchema.parse(JSON.parse(JSON.stringify(migrated))));
  assert.deepEqual(restored.production, migrated.production);
  assert.deepEqual(mergeStates(restored, previous).production, migrated.production);
});

function emptyState() {
  const state = seed();
  return {
    ...state,
    words: [],
    reviews: [],
    collections: [],
    session: null,
    demo: false,
  };
}

function freshWord(id, en, translation, example = `I use ${en} every day.`) {
  return {
    id,
    en,
    ipa: "",
    pos: "czasownik",
    level: "A2",
    collection: "Własne",
    tags: [],
    source: "test",
    note: "",
    forms: "",
    collocations: "",
    synonyms: "",
    antonyms: "",
    important: false,
    hard: false,
    archived: false,
    created: 1,
    meanings: [
      {
        id: `m-${id}`,
        translation,
        definition: translation,
        examples: [example],
        context: "",
        register: "neutralny",
        natural: "",
        scores: {},
      },
    ],
  };
}

test("hidden recall answers are never prepared as exercise prompt audio", () => {
  assert.equal(exercisePromptAudioAllowed(0), true);
  assert.equal(exercisePromptAudioAllowed(1), false);
  assert.equal(exercisePromptAudioAllowed(2), false);
  assert.equal(exercisePromptAudioAllowed(3), true);
  assert.equal(exercisePromptAudioAllowed(4), true);
});

test("B1: new meanings start with recognition regardless of list position", () => {
  const state = emptyState();
  state.words = Array.from({ length: 8 }, (_, index) =>
    freshWord(`w-${index}`, `verb${index}`, `znaczenie ${index}`),
  );
  const session = makeSession(state, 10, "mixed", undefined, () => 0.5);
  assert.ok(session.tasks.length >= 2);
  assert.deepEqual(
    new Set(session.tasks.map((task) => task.type)),
    new Set([0]),
  );
});

test("B2: meaning distractors are contextual, shuffled and never collapse to two choices", () => {
  const state = seed();
  const word = state.words.find((item) => item.en === "borrow");
  const meaning = word.meanings[0];
  const first = meaningOptions(state, word, meaning, {
    wordId: word.id,
    meaningId: meaning.id,
    type: 3,
    example: 0,
  });
  const second = meaningOptions(state, word, meaning, {
    wordId: word.id,
    meaningId: meaning.id,
    type: 3,
    example: 1,
  });
  assert.equal(first.length, 4);
  assert.equal(new Set(first).size, 4);
  assert.ok(first.includes(meaning.translation));
  assert.notDeepEqual(first, second);
  assert.notDeepEqual(
    first,
    [...first].sort((a, b) => a.localeCompare(b)),
  );
});

test("B3: pair mode detects confusable user vocabulary instead of relying on demo IDs", () => {
  const state = emptyState();
  state.words = [
    freshWord("custom-a", "hire", "zatrudnić pracownika"),
    freshWord("custom-b", "employ", "zatrudniać ludzi"),
    freshWord("unrelated", "swim", "pływać"),
  ];
  const session = makeSession(state, 5, "pairs");
  assert.deepEqual(
    new Set(session.tasks.map((task) => task.wordId)),
    new Set(["custom-a", "custom-b"]),
  );
});

test("B4: cloze replaces complete inflected words and refuses substrings", () => {
  assert.equal(
    clozeText("I borrowed your pen.", "borrow"),
    "I ________ your pen.",
  );
  assert.equal(clozeText("This essay is short.", "say"), null);
  const state = emptyState();
  const word = freshWord("essay", "say", "powiedzieć", "This essay is short.");
  word.meanings[0].scores = {
    recognition: schedule(undefined, true, 2, 3, false, 1, 0),
    recall: schedule(undefined, true, 2, 3, false, 2, 1),
  };
  state.words = [word];
  assert.notEqual(makeSession(state, 5, "mixed").tasks[0].type, 2);
});

test("B6: hints are separate from errors and good answers repair difficulty", () => {
  let score = schedule(undefined, false, 4, 2, false, 1, 1);
  score = schedule(score, false, 4, 2, false, 2, 1);
  score = schedule(score, false, 4, 2, false, 3, 1);
  const hinted = schedule(score, true, 4, 2, true, 4, 1);
  assert.equal(hinted.wrong, 3);
  assert.equal(hinted.hinted, 1);
  const recovered = schedule(hinted, true, 4, 3, false, 5, 1);
  assert.equal(recovered.wrong, 2);
  const word = freshWord("hard", "recover", "odzyskać");
  word.meanings[0].scores.recall = recovered;
  assert.notEqual(status(word), "Trudne");
});

test("B: Polish typed meaning accepts variants and typos; revealed options use existing hint scoring", () => {
  const state = emptyState();
  const word = freshWord("gate", "gate", "bramka; wyjście");
  state.words = [word];
  assert.equal(localGrade("wyjście", word, word.meanings[0], 3).verdict, "correct");
  assert.equal(localGrade("bramk", word, word.meanings[0], 3).spellingCorrect, false);
  const task = { wordId:word.id, meaningId:word.meanings[0].id, type:3, example:0 };
  const plain = recordAnswer(state, task, true, 3, 3, false);
  const assisted = recordAnswer(state, task, true, 3, 3, true);
  assert.equal(assisted.reviews.at(-1).hint, true);
  assert.equal(assisted.words[0].meanings[0].scores.recognition.hinted, 1);
  assert.ok(assisted.words[0].meanings[0].scores.recognition.interval < plain.words[0].meanings[0].scores.recognition.interval);
});

test("E: all five skills contribute; missing skills and pronunciation cannot inflate mastery", () => {
  const word = freshWord("mastery", "learn", "uczyć się");
  const meaning = word.meanings[0];
  const score = {...schedule(undefined,true,3,3,false),interval:90,due:Date.now()+86400000};
  assert.equal(status(word), "Nowe");
  meaning.scores.recognition = {...score, interval:0};
  assert.equal(status(word), "Uczę się");
  meaning.scores.recognition = {...score};
  assert.equal(mastery(meaning), 20);
  meaning.scores.pronunciation = {...score};
  assert.equal(mastery(meaning), 20);
  for (const skill of masterySkills) meaning.scores[skill] = {...score};
  delete meaning.scores.spelling;
  assert.equal(mastery(meaning), 80);
  assert.equal(status(word), "Uczę się");
  meaning.scores.spelling = {...score};
  assert.equal(mastery(meaning), 100);
  assert.equal(status(word), "Opanowane");
  meaning.scores.listening.due = 1;
  assert.equal(status(word), "Do odświeżenia");
  const state = {...emptyState(),words:[word]};
  const reviewed = recordAnswer(state,{wordId:word.id,meaningId:meaning.id,type:1,example:0},true,3,3,false);
  assert.equal(reviewed.reviews.at(-1).masteryVersion,2);
  assert.equal(stateSchema.parse(reviewed).reviews.at(-1).masteryVersion,2);
});

test("B7: mastery is derived from interval and old exports migrate safely", () => {
  assert.equal(masteryFromInterval(90), 100);
  const old = seed();
  const score = old.words[0].meanings[0].scores.recall;
  score.value = 99;
  score.interval = 1;
  delete score.hinted;
  delete old.reviews[0].weight;
  delete old.reviews[0].source;
  const migrated = migrateState(JSON.parse(JSON.stringify(old)));
  const migratedScore = migrated.words[0].meanings[0].scores.recall;
  assert.equal(migratedScore.value, masteryFromInterval(1));
  assert.equal(migratedScore.hinted, 0);
  assert.equal(migrated.reviews[0].weight, 1);
  assert.equal(stateSchema.safeParse(migrated).success, true);
});

test("old exports without topic context migrate while contextual meanings keep trimmed metadata", () => {
  const oldExport = seed();
  delete oldExport.words[0].meanings[0].topic;
  delete oldExport.words[0].meanings[0].scene;
  const migratedOld = migrateState(JSON.parse(JSON.stringify(oldExport)));
  assert.equal(migratedOld.words[0].meanings[0].topic, undefined);
  assert.equal(migratedOld.words[0].meanings[0].scene, undefined);
  assert.equal(stateSchema.safeParse(migratedOld).success, true);

  const contextual = seed();
  contextual.words[0].meanings[0].topic = "  Lotnisko ";
  contextual.words[0].meanings[0].scene = " pasażer przed lotem ";
  const migratedContextual = migrateState(contextual);
  assert.equal(migratedContextual.words[0].meanings[0].topic, "Lotnisko");
  assert.equal(
    migratedContextual.words[0].meanings[0].scene,
    "pasażer przed lotem",
  );
  assert.equal(stateSchema.safeParse(migratedContextual).success, true);
});

test("B8: slow-answer thresholds depend on exercise type", () => {
  const flashcard = schedule(undefined, true, 14, 3, false, 1, 0);
  const cloze = schedule(undefined, true, 14, 3, false, 1, 2);
  assert.equal(flashcard.slow, 1);
  assert.equal(cloze.slow, 0);
});

test("B9: a failed task returns at session end in another format", () => {
  const state = seed();
  const task = {
    wordId: state.words[0].id,
    meaningId: state.words[0].meanings[0].id,
    type: 1,
    example: 0,
  };
  state.session = {
    tasks: [
      task,
      {
        wordId: state.words[1].id,
        meaningId: state.words[1].meanings[0].id,
        type: 0,
        example: 0,
      },
    ],
    index: 0,
    correct: 0,
    minutes: 5,
    mode: "mixed",
  };
  const next = recordAnswer(state, task, false, 5, 2, false);
  assert.equal(next.session.tasks.length, 3);
  assert.equal(next.session.tasks.at(-1).wordId, task.wordId);
  assert.notEqual(next.session.tasks.at(-1).type, task.type);
});

test("A3: session respects task costs and fills spare review time with fresh meanings", () => {
  const state = emptyState();
  state.words = Array.from({ length: 24 }, (_, index) =>
    freshWord(`w-${index}`, `term${index}`, `tłumaczenie ${index}`),
  );
  for (let index = 0; index < 16; index++)
    state.words[index].meanings[0].scores.recognition = schedule(
      undefined,
      true,
      3,
      3,
      false,
      1,
      0,
    );
  const session = makeSession(state, 10, "mixed", undefined, () => 0.5);
  const fresh = session.tasks.filter(
    (task) =>
      Object.keys(
        state.words.find((word) => word.id === task.wordId).meanings[0].scores,
      ).length === 0,
  );
  assert.equal(fresh.length, 8);
  assert.ok(
    session.tasks.reduce((sum, task) => sum + taskSeconds[task.type], 0) <= 600,
  );
});

test("A: seeded progression, interleaving and five consecutive fresh-dictionary sessions", () => {
  let state = emptyState();
  state.words = Array.from({ length: 40 }, (_, index) => freshWord(`w${index}`, `term${index}`, `sens ${index}`));
  const rng = () => { let x = 17; return () => ((x = (x * 1664525 + 1013904223) >>> 0) / 4294967296); };
  const random = rng();
  for (let round = 0; round < 5; round++) {
    const session = makeSession(state, 10, "mixed", undefined, random);
    const types = session.tasks.map((task) => task.type);
    const counts = [...new Set(types)].map((type) => types.filter((t) => t === type).length);
    if (!round) {
      assert.equal(types.length, Math.floor(600 / taskSeconds[0]));
      assert.deepEqual(new Set(types), new Set([0]));
    }
    // One-type first contact and a mathematically dominant bucket are the
    // unavoidable exceptions; no tasks may be dropped to hide those cases.
    if (counts.length > 1 && Math.max(...counts) <= Math.ceil(types.length / 2))
      for (let i = 1; i < types.length; i++) assert.notEqual(types[i], types[i - 1]);
    const majority = Math.max(...counts);
    const bestPossibleRun = Math.ceil(majority / (types.length - majority + 1));
    let run = 0, longest = 0, previous = -1;
    for (const type of types) { run = type === previous ? run + 1 : 1; longest = Math.max(longest, run); previous = type; }
    assert.ok(longest <= bestPossibleRun, "dominant types are evenly spread instead of appended in a block");
    assert.ok(session.tasks.reduce((total, task) => total + taskSeconds[task.type], 0) <= 600);
    assert.deepEqual(makeSession(state, 10, "mixed", undefined, rng()).tasks,
      makeSession(state, 10, "mixed", undefined, rng()).tasks);
    state.session = session;
    for (const task of session.tasks) state = recordAnswer(state, task, true, 3, 3, false, true);
  }
  const tasks = [0,0,0,1,1,2].map((type, index) => ({type, wordId: String(index), meaningId: String(index), example: 0}));
  const mixed = interleaveTasks(tasks);
  assert.deepEqual(mixed.map((t) => t.wordId).sort(), tasks.map((t) => t.wordId).sort());
  for (let i = 1; i < mixed.length; i++) assert.notEqual(mixed[i].type, mixed[i - 1].type);
  assert.deepEqual(allowedTaskTypes({scores:{}}), [0]);
  assert.deepEqual(allowedTaskTypes({scores:{recognition:{correct:1}}}), [3,0]);
  assert.deepEqual(allowedTaskTypes({scores:{recognition:{correct:2}}}), [1,3]);
  assert.deepEqual(allowedTaskTypes({scores:{recognition:{correct:2},recall:{}}}), [2,1]);
});

test("targeted answer changes one bank sense and keeps a valid saved session", () => {
  const state = seed();
  const bank = state.words.find((word) => word.en === "bank");
  const untouched = structuredClone(bank.meanings[1]);
  state.session = {
    tasks: [
      { wordId: bank.id, meaningId: bank.meanings[0].id, type: 1, example: 0 },
    ],
    index: 0,
    correct: 0,
    minutes: 5,
    mode: "mixed",
  };
  const next = recordAnswer(state, state.session.tasks[0], true, 6, 3, false);
  assert.deepEqual(
    next.words.find((word) => word.en === "bank").meanings[1],
    untouched,
  );
  assert.equal(next.session.index, 1);
  assert.ok(
    mastery(next.words.find((word) => word.en === "bank").meanings[0]) > 0,
  );
  assert.ok(stateSchema.safeParse(next).success);
});

test("import validator rejects broken sessions and duplicate meaning identities", () => {
  const state = seed();
  state.session = {
    tasks: [{ wordId: "absent", meaningId: "absent", type: 0, example: 0 }],
    index: 0,
    correct: 0,
    minutes: 5,
    mode: "mixed",
  };
  assert.equal(stateSchema.safeParse(state).success, false);
  const duplicate = seed();
  duplicate.words[1].meanings[0].id = duplicate.words[0].meanings[0].id;
  assert.equal(stateSchema.safeParse(duplicate).success, false);
});

test("D1: reading target is one CEFR step above the estimated learner level", () => {
  const state = emptyState();
  const word = freshWord("known", "manage", "zarządzać");
  word.level = "B1";
  word.meanings[0].scores.recognition = {
    ...schedule(undefined, true, 3, 3, false, 1, 0),
    interval: 14,
  };
  state.words = [word];
  const level = estimatedLevel(state);
  assert.equal(level.level, "B1");
  assert.equal(level.targetLevel, "B2");
  assert.equal(level.confidence, "low", "one practiced skill cannot establish broad confidence");
  for (const skill of masterySkills) word.meanings[0].scores[skill] = {...word.meanings[0].scores.recognition};
  assert.equal(estimatedLevel(state).confidence, "high");
});

test("D2: fresh declared vocabulary gives a low-confidence estimate instead of forced A1", () => {
  const state = emptyState();
  const word = freshWord("fresh-c1", "scrutinize", "dokładnie badać");
  word.level = "C1";
  state.words = [word];
  assert.deepEqual(estimatedLevel(state), {
    level: "C1",
    targetLevel: "C2",
    count: 1,
    confidence: "low",
  });
});

test("D3: meanings with unknown CEFR do not silently count as A2", () => {
  const state = emptyState();
  const word = freshWord("unknown", "unrated", "bez poziomu");
  word.level = "";
  state.words = [word];
  assert.equal(estimatedLevel(state).count, 0);
});

test("D4: reading vocabulary selects concrete due and difficult senses, including second meanings", () => {
  const state = seed();
  const bank = state.words.find((word) => word.en === "bank");
  bank.hard = true;
  bank.meanings[1].level = "A2";
  const selected = selectReadingMeanings(state, "A2", 20);
  assert.ok(
    selected.some(
      (item) =>
        item.meaningId === bank.meanings[1].id &&
        item.translation === "brzeg rzeki",
    ),
  );
  assert.ok(
    selected.every((item) => item.meaningId && item.translation && item.level),
  );
});

test("D5: reading history accepts old entries and stores titles", () => {
  const state = seed();
  state.readingHistory = [
    { id: "old", at: 1, level: "A1", correct: 2, total: 3 },
    {
      id: "new",
      at: 2,
      level: "A2",
      correct: 3,
      total: 3,
      title: "A title",
    },
  ];
  assert.equal(stateSchema.safeParse(state).success, true);
  assert.deepEqual(
    state.readingHistory.map((item) => item.title).filter(Boolean),
    ["A title"],
  );
});

test("D6: generated reading accepts one-level deviation but rejects larger gaps", () => {
  assert.equal(nearbyLevel("B2", "B1"), true);
  assert.equal(nearbyLevel("B2", "C1"), true);
  assert.equal(nearbyLevel("B2", "A2"), false);
});

test("D7: starter passages vary before cycling instead of blocking study during an outage", () => {
  const first = starterReading("A1", []);
  const second = starterReading("A1", [{ id: first.id }]);
  const exhausted = starterReading("A1", [{ id: first.id }, { id: second.id }]);
  assert.notEqual(first.id, second.id);
  assert.notEqual(exhausted.id, first.id);
});

test("D8: word-in-context answers update recognition with lower weight and marked history", () => {
  const state = seed();
  const word = state.words.find((item) => item.en === "bank");
  const meaning = word.meanings[1];
  const reading = starterReading("A2", []);
  reading.questions[0].meaningId = meaning.id;
  const readingSession = {
    reading,
    answers: [
      reading.questions[0].answer,
      ...reading.questions.slice(1).map(() => 0),
    ],
    submitted: true,
  };
  const before = meaning.scores.recognition?.interval || 0;
  const next = applyReadingResults(state, readingSession);
  const review = next.reviews.at(-1);
  assert.equal(review.source, "reading");
  assert.equal(review.weight, 0.35);
  assert.ok(
    next.words.find((item) => item.id === word.id).meanings[1].scores
      .recognition.interval >= before,
  );
});

test("E2/E7: old real reviews aggregate by day while demo records stay out of summaries", () => {
  const state = seed();
  const old = Date.now() - 100 * 86400000;
  state.reviews = [
    {
      ...state.reviews[0],
      id: "real-old",
      at: old,
      demo: false,
      correct: true,
    },
    { ...state.reviews[0], id: "demo-old", at: old, demo: true, correct: true },
  ];
  const compacted = compactReviews(state);
  assert.equal(compacted.reviews.length, 0);
  assert.equal(compacted.reviewSummaries[0].count, 1);
  assert.ok(seed().reviews.every((review) => review.demo));
});

test("E4: synchronization merges reviews and keeps the latest word edit", () => {
  const local = seed();
  const remote = seed();
  local.words[0] = { ...local.words[0], en: "local-new", updatedAt: 20 };
  remote.words[0] = { ...remote.words[0], en: "remote-old", updatedAt: 10 };
  local.reviews = [{ ...local.reviews[0], id: "local-review" }];
  remote.reviews = [{ ...remote.reviews[0], id: "remote-review" }];
  const merged = mergeStates(local, remote);
  assert.equal(
    merged.words.find((word) => word.id === local.words[0].id).en,
    "local-new",
  );
  assert.deepEqual(
    new Set(merged.reviews.map((review) => review.id)),
    new Set(["local-review", "remote-review"]),
  );
});

test("v34 pending examples survive export and sync; old exports do not create unexpected jobs",()=>{
  const old=JSON.parse(readFileSync("tests/fixtures/state-v31.json","utf8"));
  const migrated=migrateState(stateSchema.parse(old));
  assert.ok(migrated.words.every(w=>w.meanings.every(m=>!m.enrichment)));
  const s=seed();s.words=[s.words[0]];s.words[0].meanings=[{...s.words[0].meanings[0],examples:[],enrichment:{phase:"examples",detailsPending:true,groups:[],attempts:1,retryAt:12345}}];
  const restored=migrateState(stateSchema.parse(JSON.parse(JSON.stringify(s))));
  assert.deepEqual(restored.words[0].meanings[0].enrichment,s.words[0].meanings[0].enrichment);
  assert.equal(makeSession(restored,5,"mixed").tasks.length,0,"do not show invented or empty examples while the bank is pending");
  assert.deepEqual(mergeStates(restored,s).words[0].meanings[0].enrichment,s.words[0].meanings[0].enrichment);
});

import { availableExampleCount, needsExampleExpansion, beginExampleExpansion } from "../lib/example-pool.ts";
import { appendExampleGroup } from "../lib/meaning-enrichment.ts";
test("v35 publishes complete batches only, refills at three remaining and stops at 90",()=>{
 const s=seed(); s.words=[s.words[0]];
 let m={...s.words[0].meanings[0],examples:[],exampleTranslations:[],exampleFocusEn:[],exampleFocusPl:[],usedExamples:[],enrichment:{phase:"examples",groups:[],attempts:0,retryAt:0}};
 for (let round=0;round<6;round++) {
  for (const [i,kind] of ["affirmative","negative","question"].entries()) {
   m=appendExampleGroup(m,kind,Array.from({length:5},(_,j)=>({en:`${round} ${kind} example ${j}`,pl:`${round} ${kind} przykład ${j}`,focusEn:"example",focusPl:"przykład"})));
   assert.equal(availableExampleCount(m),round*15+(i===2 ? 15 : 0));
   s.words[0].meanings=[m];
   assert.equal(makeSession(s,5,"mixed").tasks.length,round===0 && i<2 ? 0 : 1);
  }
  m.usedExamples=Array.from({length:m.examples.length-4},(_,i)=>i);
  assert.equal(needsExampleExpansion(m),false);
  m.usedExamples.push(m.examples.length-4);
  assert.equal(needsExampleExpansion(m),round<5);
  const previous=m;m=beginExampleExpansion(m);
  assert.equal(availableExampleCount(m),(round+1)*15);
  assert.equal(needsExampleExpansion(m),false,"queueing a round is idempotent");
  if (round===5) assert.equal(m,previous);
 }
 assert.equal(m.examples.length,90);
 assert.equal(new Set(m.examples).size,90);
 for(const kind of ["affirmative","negative","question"]) assert.equal(m.examples.filter(e=>e.includes(kind)).length,30);
 s.words[0].meanings=[m];
 assert.ok(stateSchema.safeParse(JSON.parse(JSON.stringify(s))).success);
 assert.deepEqual(migrateState(s).words[0].meanings[0].usedExamples,m.usedExamples);
});

test("v35 tracks distinct answered sentences and preserves published bank and exposure across devices",()=>{
 const s=seed(); s.words=[s.words[0]];
 const m=s.words[0].meanings[0];
 m.examples=Array.from({length:15},(_,i)=>`Sentence ${i}`);
 m.enrichment={phase:"ready",groups:["affirmative","negative","question"],attempts:0,retryAt:0};
 const task={wordId:s.words[0].id,meaningId:m.id,type:1,example:0};
 let answered=recordAnswer(s,task,true,4,3,false);
 answered=recordAnswer(answered,task,true,4,3,false);
 assert.deepEqual(answered.words[0].meanings[0].usedExamples,[0]);
 assert.equal(makeSession(answered,5,"mixed").tasks[0].example,1);
 const reading=recordAnswer(answered,{...task,example:3},true,4,3,false,true,1,"reading");
 assert.deepEqual(reading.words[0].meanings[0].usedExamples,[0]);
 const remote=structuredClone(answered);remote.words[0].updatedAt=1;
 const rm=remote.words[0].meanings[0];rm.examples.push(...Array.from({length:15},(_,i)=>`New sentence ${i}`));rm.enrichment.round=1;rm.usedExamples=[1,2];
 const merged=mergeStates(answered,remote).words[0].meanings[0];
 assert.equal(availableExampleCount(merged),30);
 assert.deepEqual(new Set(merged.usedExamples),new Set([0,1,2]));
 const pending=structuredClone(s);pending.words[0].meanings[0].enrichment.groups=["affirmative"];
 pending.session={tasks:[task],index:0,correct:0,minutes:5,mode:"mixed"};
 assert.equal(migrateState(pending).session.tasks.length,0);
});

test("v36 grammar exposure survives old-export migration, JSON round trip and device merge",()=>{
 const old=JSON.parse(readFileSync('tests/fixtures/state-v31.json','utf8'));
 const input=old.state || old;
 assert.ok(stateSchema.safeParse(input).success);
 const migrated=migrateState(input);
 assert.deepEqual(migrated.grammarSeen,{});
 const a=seed(),b=structuredClone(a);
 a.grammarSeen={'grammar-36-A1-00-00':100,'grammar-36-B1-04-02':150};
 b.grammarSeen={'grammar-36-A1-00-00':300,'grammar-36-C2-03-12':200};
 const merged=mergeStates(a,b);
 assert.deepEqual(merged.grammarSeen,{'grammar-36-A1-00-00':300,'grammar-36-B1-04-02':150,'grammar-36-C2-03-12':200});
 const parsed=stateSchema.parse(JSON.parse(JSON.stringify(merged)));
 assert.deepEqual(migrateState(parsed).grammarSeen,merged.grammarSeen);
});


test("v39 migration preserves old multiple-choice sessions and new written answers",()=>{
 const original=seed();const set=starterPractice("mixed","B1",0);
 for(const item of set.items){delete item.format;delete item.inputHint;delete item.acceptedAnswers;}
 original.practice={set,index:1,answers:[set.items[0].answer,-1,-1,-1,-1,-1]};
 const oldExport=JSON.parse(JSON.stringify(original));const migrated=migrateState(stateSchema.parse(oldExport));
 assert.deepEqual(migrated.practice.answers,original.practice.answers);
 assert.deepEqual(migrated.practice.writtenAnswers,["","","","","",""]);
 migrated.practice.set=starterPractice("mixed","B1",1);migrated.practice.writtenAnswers[0]="have known";
 assert.equal(stateSchema.parse(JSON.parse(JSON.stringify(migrated))).practice.writtenAnswers[0],"have known");
 const malformed=structuredClone(migrated);malformed.practice.writtenAnswers=[];
 assert.equal(stateSchema.safeParse(malformed).success,false);
});

test('v40 combined sessions retain order, grade once and preserve old exports and paused vocabulary', async()=>{
 const {makeCombinedSession,saveCombinedAnswer,advanceCombined}=await import('../lib/combined-session.ts');
 const previous=JSON.parse(readFileSync('tests/fixtures/state-v31.json','utf8'));
 const state=migrateState(previous);
 assert.equal(state.combined,null);
 const oldSession=structuredClone(state.session);
 state.combined=makeCombinedSession(state,['mixed','reading','grammar','idioms','production','language-mix'],15,true,()=>.25);
 assert.ok(state.combined.tasks.length>=20);
 assert.equal(stateSchema.safeParse(state).success,true,JSON.stringify(stateSchema.safeParse(state).error));
 const order=JSON.parse(JSON.stringify(state.combined.tasks));
 let restored=migrateState(stateSchema.parse(JSON.parse(JSON.stringify(state))));
 assert.deepEqual(JSON.parse(JSON.stringify(restored.combined.tasks)),order);
 const first=restored.combined.tasks[0];
 const before=restored.reviews.length;
 const answer={value:'test',correct:true,seconds:3,hinted:false,spellingCorrect:true,explanation:'Test'};
 restored=saveCombinedAnswer(restored,answer);
 assert.deepEqual(restored.session,oldSession);
 assert.equal(restored.reviews.length,before+Number(first.kind==='vocabulary'));
 assert.deepEqual(saveCombinedAnswer(restored,answer),restored,'double click cannot grade twice');
 restored=advanceCombined(restored);
 assert.equal(restored.combined.index,1);
 assert.equal(stateSchema.safeParse(restored).success,true);
 assert.deepEqual(JSON.parse(JSON.stringify(restored.combined.tasks)),order);
 while(!restored.combined.completedAt){restored=advanceCombined(saveCombinedAnswer(restored,answer));}
 assert.equal(restored.combined.index,restored.combined.tasks.length);
 assert.equal(stateSchema.safeParse(restored).success,true,JSON.stringify(stateSchema.safeParse(restored).error));
 assert.deepEqual(advanceCombined(restored),restored);
 assert.ok(restored.practiceHistory.length);
 assert.ok(restored.readingHistory.length);
 assert.equal(mergeStates(state,restored).combined.completedAt,restored.combined.completedAt);
});

test('v40 randomization interleaves tasks and ordered sessions keep chosen groups',async()=>{
 const {makeCombinedSession,orderCombinedTasks}=await import('../lib/combined-session.ts');
 const state=seed();
 const ordered=makeCombinedSession(state,['grammar','idioms'],10,false);
 assert.deepEqual(ordered.tasks.slice(0,8).map(t=>t.mode),Array(8).fill('grammar'));
 const random=orderCombinedTasks(ordered.tasks,true,()=>0);
 assert.equal(random.length,ordered.tasks.length);
 assert.ok(random.every((t,i)=>!i||t.mode!==random[i-1].mode));
 assert.equal(new Set(random).size,ordered.tasks.length);
 const empty={...state,words:[],reviews:[]};
 const available=makeCombinedSession(empty,['pairs','grammar'],5,true);
 assert.ok(available.tasks.length>0);
 assert.ok(available.tasks.every(t=>t.mode==='grammar'));
 assert.equal(stateSchema.safeParse({...empty,combined:available}).success,true);
 for(const level of ['A1','A2','B1','B2','C1','C2']) {
  const leveled={...state,words:state.words.map(w=>({...w,level,meanings:w.meanings.map(m=>({...m,level}))}))};
  const combined=makeCombinedSession(leveled,['production','reading','language-mix'],15,true);
  assert.equal(stateSchema.safeParse({...leveled,combined}).success,true,level);
 }
});

test('v41: older exports migrate without losing progress and new Polish variants round-trip',()=>{
 const old=JSON.parse(readFileSync('tests/fixtures/state-v31.json','utf8'));
 const restored=migrateState(stateSchema.parse(old));
 assert.deepEqual(JSON.parse(JSON.stringify(restored.words)),old.words);
 const originalReviews=structuredClone(restored.reviews);
 restored.words[0].meanings[0].translation='rachunek (AmE)';
 restored.words[0].meanings[0].acceptedTranslations=['rachunek','rachunek do zapłaty'];
 const next=migrateState(stateSchema.parse(JSON.parse(JSON.stringify(restored))));
 assert.equal(next.words[0].meanings[0].translation,'rachunek');
 assert.deepEqual(next.words[0].meanings[0].acceptedTranslations,['rachunek','rachunek do zapłaty']);
 assert.deepEqual(next.reviews,originalReviews);
});
