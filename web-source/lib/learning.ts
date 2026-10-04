import {withoutDialectLabel} from "./answer-variants";
import type {CombinedSession} from "./combined-session";
import { availableExampleCount, nextUnusedExample } from "./example-pool";
import type { PracticeSession, ReadingSession, ProductionSession } from "./tutor-types";
export type Skill =
  | "recognition"
  | "recall"
  | "spelling"
  | "listening"
  | "usage"
  | "pronunciation";
export type Score = {
  value: number;
  interval: number;
  due: number;
  correct: number;
  wrong: number;
  hinted?: number;
  last: number;
  slow: number;
};
export type Meaning = {
  id: string;
  topic?: string;
  scene?: string;
  usedExamples?: number[];
  enrichment?: { round?: number; phase: "details" | "examples" | "ready"; detailsPending?: boolean; groups: ("affirmative" | "negative" | "question")[]; attempts: number; retryAt: number; error?: string };
  exampleTranslations?: string[];
  exampleFocusEn?: string[];
  exampleFocusPl?: string[];
  acceptedAnswers?: string[];
  acceptedTranslations?: string[];
  level?: string;
  levelConfidence?: "high" | "medium" | "low";
  levelReason?: string;
  spokenFrequency?: "very_common" | "common" | "less_common" | "rare";
  pos?: string;
  translation: string;
  definition: string;
  examples: string[];
  context: string;
  register: string;
  natural: string;
  scores: Partial<Record<Skill, Score>>;
};
export type Word = {
  id: string;
  en: string;
  ipa: string;
  pos: string;
  level: string;
  collection: string;
  tags: string[];
  source: string;
  note: string;
  forms: string;
  collocations: string;
  synonyms: string;
  antonyms: string;
  important: boolean;
  hard: boolean;
  archived: boolean;
  created: number;
  updatedAt?: number;
  meanings: Meaning[];
};
export type Review = {
  id: string;
  wordId: string;
  meaningId: string;
  skill: Skill;
  correct: boolean;
  at: number;
  seconds: number;
  confidence: number;
  hint: boolean;
  error: string;
  before: number;
  after: number;
  masteryVersion?: 2;
  weight?: number;
  source?: "exercise" | "reading";
  demo?: boolean;
};
export type Task = {
  wordId: string;
  meaningId: string;
  type: number;
  example: number;
};
export type Session = {
  tasks: Task[];
  index: number;
  correct: number;
  minutes: number;
  mode: string;
};
export type State = {
  combined?: CombinedSession | null;
  grammarSeen?: Record<string,number>;
  words: Word[];
  collections: string[];
  reviews: Review[];
  reviewSummaries?: { day: string; count: number; correct: number }[];
  settings: {
    goal: number;
    reminder: string;
    accent: string;
    slow: boolean;
    voice?: string;
    voiceRevision?: number;
  };
  session: Session | null;
  reading?: ReadingSession | null;
  readingHistory?: {
    id: string;
    at: number;
    level: string;
    correct: number;
    total: number;
    title?: string;
  }[];
  practice?: PracticeSession | null;
  production?: ProductionSession | null;
  productionHistory?: {id:string;at:number;level:string;correct:number;total:number;title:string}[];
  practiceHistory?: {
    id: string;
    at: number;
    kind: "grammar" | "idioms" | "mixed";
    level: string;
    correct: number;
    total: number;
    title: string;
  }[];
  demo: boolean;
};
export const skillNames: Record<Skill, string> = {
  recognition: "Rozpoznawanie",
  recall: "Przypominanie",
  spelling: "Pisownia",
  listening: "Słuchanie",
  usage: "Użycie w zdaniu",
  pronunciation: "Wymowa",
};
export const exerciseNames = [
  "Fiszka w kontekście",
  "Przypomnij sobie słowo",
  "Uzupełnij zdanie",
  "Wybierz znaczenie",
  "Posłuchaj i zapisz",
];
export const taskSkills: Skill[] = [
  "recognition",
  "recall",
  "usage",
  "recognition",
  "listening",
];
export const taskSeconds = [18, 32, 42, 24, 48];
export const slowSeconds = [10, 15, 24, 12, 25];

export function exercisePromptAudioAllowed(type: number) {
  // Recall and cloze hide the English target. Flashcards and recognition show
  // it on screen, while dictation uses audio as the question itself.
  return type === 0 || type === 3 || type === 4;
}

export function masteryFromInterval(interval: number) {
  return Math.round(
    Math.min(
      100,
      Math.max(0, (Math.log1p(Math.max(0, interval)) / Math.log(91)) * 100),
    ),
  );
}
export const masterySkills = ["recognition", "recall", "usage", "listening", "spelling"] as const;
export const MASTERED_THRESHOLD = 85;
export function mastery(m: Meaning) {
  return Math.round(masterySkills.reduce((sum, skill) =>
    sum + masteryFromInterval(m.scores[skill]?.interval || 0), 0) / masterySkills.length);
}
export function wordMastery(w: Word) {
  return Math.round(
    w.meanings.reduce((sum, m) => sum + mastery(m), 0) / w.meanings.length,
  );
}
export function due(m: Meaning) {
  const scores = Object.values(m.scores);
  return scores.length ? Math.min(...scores.map((score) => score.due)) : 0;
}
export function status(w: Word) {
  if (w.archived) return "Archiwum";
  if (
    w.hard ||
    w.meanings.some((m) =>
      Object.values(m.scores).some(
        (score) => score.wrong >= 3 && masteryFromInterval(score.interval) < 65,
      ),
    )
  )
    return "Trudne";
  const value = wordMastery(w);
  return !w.meanings.some((m) => Object.keys(m.scores).length > 0)
    ? "Nowe"
    : value >= MASTERED_THRESHOLD
      ? w.meanings.some((m) => due(m) < Date.now())
        ? "Do odświeżenia"
        : "Opanowane"
      : "Uczę się";
}
export function normalize(value: string) {
  return value
    .toLowerCase()
    .trim()
    .replace(/[.,!?;:]/g, "")
    .replace(/\s+/g, " ");
}
export function schedule(
  old: Score | undefined,
  correct: boolean,
  seconds: number,
  confidence: number,
  hint: boolean,
  now = Date.now(),
  type = 1,
  weight = 1,
): Score {
  const score = old ?? {
    value: 0,
    interval: 0,
    due: 0,
    correct: 0,
    wrong: 0,
    hinted: 0,
    last: 0,
    slow: 0,
  };
  const slow = seconds > slowSeconds[type];
  const independent = correct && !hint;
  const factor = Math.max(
    1.15,
    2.5 -
      (confidence === 1 ? 0.65 : confidence === 2 ? 0.25 : 0) -
      (slow ? 0.65 : 0) -
      Math.min(0.45, score.wrong * 0.04),
  );
  const elapsed = score.last ? Math.max(0, (now - score.last) / 86400000) : 0;
  let interval = independent
    ? Math.min(
        90,
        Math.max(
          1,
          (score.interval || 0.5) * factor + Math.min(elapsed * 0.08, 2),
        ),
      )
    : correct
      ? 0.5
      : 10 / 1440;
  if (weight < 1 && correct)
    interval = Math.max(
      score.interval,
      score.interval + (interval - score.interval) * weight,
    );
  const wrong = correct
    ? Math.max(0, score.wrong - (independent ? 1 : 0))
    : score.wrong + 1;
  const hinted = (score.hinted || 0) + (hint ? 1 : 0);
  return {
    value: masteryFromInterval(interval),
    interval,
    due: now + interval * 86400000,
    correct: score.correct + (correct ? 1 : 0),
    wrong,
    hinted,
    last: now,
    slow: score.slow + (slow ? 1 : 0),
  };
}
export function nextExerciseType(type: number) {
  return [3, 2, 1, 4, 0][type] ?? 0;
}
export function recordAnswer(
  st: State,
  task: Task,
  correct: boolean,
  seconds: number,
  confidence: number,
  hint: boolean,
  spellingCorrect = correct,
  weight = 1,
  source: "exercise" | "reading" = "exercise",
): State {
  const state = structuredClone(st);
  const word = state.words.find((item) => item.id === task.wordId)!;
  const meaning = word.meanings.find((item) => item.id === task.meaningId)!;
  if (source === "exercise" && task.example >= 0 && task.example < availableExampleCount(meaning))
    meaning.usedExamples = [...new Set([...(meaning.usedExamples || []),task.example])];
  word.updatedAt = Date.now();
  const skill = taskSkills[task.type];
  const before = mastery(meaning);
  meaning.scores[skill] = schedule(
    meaning.scores[skill],
    correct,
    seconds,
    confidence,
    hint,
    Date.now(),
    task.type,
    weight,
  );
  if (task.type === 1 || task.type === 4)
    meaning.scores.spelling = schedule(
      meaning.scores.spelling,
      spellingCorrect,
      seconds,
      confidence,
      hint,
      Date.now(),
      task.type,
      weight,
    );
  state.reviews.push({
    id: crypto.randomUUID(),
    wordId: word.id,
    meaningId: meaning.id,
    skill,
    correct,
    at: Date.now(),
    seconds,
    confidence,
    hint,
    error:
      correct && !spellingCorrect
        ? "Pisownia"
        : !correct
          ? task.type === 4
            ? "Słuchanie i pisownia"
            : task.type === 3
              ? "Znaczenie w kontekście"
              : "Przypominanie lub pisownia"
          : hint
            ? "Odpowiedź po podpowiedzi"
            : seconds > slowSeconds[task.type]
              ? "Wolne przypominanie"
              : "",
    before,
    after: mastery(meaning),
    masteryVersion: 2,
    weight,
    source,
  });
  if (state.session) {
    state.session.index++;
    state.session.correct += correct && !hint ? 1 : 0;
    if (!correct && state.session.tasks.length < 100)
      state.session.tasks.push({
        ...task,
        type: state.session.mode==="pairs" ? 2 : nextExerciseType(task.type),
        example: nextUnusedExample(meaning, task.example + 1),
      });
  }
  return state;
}
export function applyReadingResults(st: State, reading: ReadingSession): State {
  let next = structuredClone(st);
  const activeSession = next.session;
  next.session = null;
  reading.reading.questions.forEach((question, index) => {
    if (!question.meaningId) return;
    const word = next.words.find((item) =>
      item.meanings.some((meaning) => meaning.id === question.meaningId),
    );
    const meaning = word?.meanings.find(
      (item) => item.id === question.meaningId,
    );
    if (!word || !meaning) return;
    const correct = reading.answers[index] === question.answer;
    next = recordAnswer(
      next,
      { wordId: word.id, meaningId: meaning.id, type: 3, example: 0 },
      correct,
      15,
      2,
      false,
      correct,
      0.35,
      "reading",
    );
  });
  next.session = activeSession;
  return next;
}
const polishStem = (value: string) =>
  normalize(value)
    .split(" ")
    .map((word) =>
      word.replace(
        /(ować|ywać|ić|yć|ać|emu|ami|ach|ego|enie|anie|enie|ą|ę|y|i|a|u|e)$/,
        "",
      ),
    )
    .filter((word) => word.length >= 4);
export function confusable(
  a: { w: Word; m: Meaning },
  b: { w: Word; m: Meaning },
) {
  if (a.w.id === b.w.id) return false;
  const left = new Set(polishStem(a.m.translation));
  return (
    polishStem(b.m.translation).some((stem) =>
      [...left].some(
        (candidate) =>
          candidate === stem ||
          (Math.min(candidate.length, stem.length) >= 6 &&
            (candidate.startsWith(stem) || stem.startsWith(candidate))),
      ),
    ) ||
    normalize(a.w.note).includes(normalize(b.w.en)) ||
    normalize(b.w.note).includes(normalize(a.w.en))
  );
}
export function clozeSpan(text: string, focus: string) {
  const escaped = focus.trim().replace(/[.*+?^${}()|[\]\\]/g, "\\$&");
  if (!escaped) return null;
  const exact = new RegExp(
    `(^|[^A-Za-z])(${escaped})(?=$|[^A-Za-z])`,
    "i",
  ).exec(text);
  if (exact)
    return {
      start: exact.index + exact[1].length,
      length: exact[2].length,
      match: exact[2],
    };
  if (!focus.includes(" ")) {
    const inflected = new RegExp(
      `(^|[^A-Za-z])(${escaped}(?:s|es|ed|ing|d))(?=$|[^A-Za-z])`,
      "i",
    ).exec(text);
    if (inflected)
      return {
        start: inflected.index + inflected[1].length,
        length: inflected[2].length,
        match: inflected[2],
      };
  }
  return null;
}
export function clozeText(text: string, focus: string) {
  const span = clozeSpan(text, focus);
  return span
    ? text.slice(0, span.start) +
        "________" +
        text.slice(span.start + span.length)
    : null;
}
function canCloze(w: Word, m: Meaning, index: number) {
  return !!clozeText(m.examples[index], m.exampleFocusEn?.[index] || w.en);
}
export function allowedTaskTypes(m: Meaning): number[] | null {
  const practiced = new Set(Object.keys(m.scores));
  if (!practiced.has("recognition")) return [0];
  if ((m.scores.recognition?.correct || 0) < 2) return [3, 0];
  if (!practiced.has("recall")) return [1, 3];
  if (!practiced.has("usage")) return [2, 1];
  if (!practiced.has("listening")) return [4, 3];
  return null;
}
function chooseType(w: Word, m: Meaning, index: number, random: () => number) {
  const progression = allowedTaskTypes(m);
  let type =
    progression ? progression[Math.min(progression.length - 1, Math.floor(random() * progression.length))] :
    [0, 1, 2, 3, 4].sort((a, b) => {
      const difference =
        (m.scores[taskSkills[a]]?.due ?? 0) -
        (m.scores[taskSkills[b]]?.due ?? 0);
      return difference || random() - 0.5;
    })[0];
  if (type === 2 && !canCloze(w, m, index)) type = 1;
  return type;
}
export function interleaveTasks(tasks: Task[]): Task[] {
  const buckets = new Map<number, { task: Task; position: number }[]>();
  tasks.forEach((task, position) => {
    const bucket = buckets.get(task.type) || [];
    bucket.push({ task, position });
    buckets.set(task.type, bucket);
  });
  const dominant = [...buckets.values()].find((bucket) => bucket.length > Math.ceil(tasks.length / 2));
  if (dominant) {
    // Avoid a long tail when alternation is mathematically impossible.
    // Spread the surplus evenly across the gaps between all other tasks.
    const others = [...buckets.values()].filter((bucket) => bucket !== dominant)
      .flat().sort((a,b) => a.position - b.position);
    const gaps = others.length + 1;
    const size = Math.floor(dominant.length / gaps);
    const extra = dominant.length % gaps;
    const balanced: Task[] = [];
    let at = 0;
    for (let gap = 0; gap < gaps; gap++) {
      for (let i = 0; i < size + Number(gap < extra); i++) balanced.push(dominant[at++].task);
      if (others[gap]) balanced.push(others[gap].task);
    }
    return balanced;
  }
  const result: Task[] = [];
  while (result.length < tasks.length) {
    const remaining = [...buckets.values()].filter((bucket) => bucket.length);
    const last = result.at(-1)?.type;
    const different = remaining.filter((bucket) => bucket[0].task.type !== last);
    const candidates = different.length ? different : remaining;
    const canFinish = (candidate: typeof candidates[number]) => {
      const count = tasks.length - result.length - 1;
      return remaining.every((bucket) => bucket.length - Number(bucket === candidate) <=
        (bucket === candidate ? Math.floor(count / 2) : Math.ceil(count / 2)));
    };
    const safe = candidates.filter(canFinish);
    // Prefer the earliest due item; only move a larger bucket ahead when
    // necessary to avoid exhausting every alternative too early.
    const pool = safe.length ? safe : candidates;
    pool.sort((a, b) => (safe.length ? 0 : b.length - a.length) || a[0].position - b[0].position);
    result.push(pool[0].shift()!.task);
  }
  return result;
}
export function makeSession(
  s: State,
  minutes: number,
  mode: string,
  collection?: string,
  random = Math.random,
): Session {
  let choices = s.words
    .filter((w) => !w.archived && (!collection || w.collection === collection))
    .flatMap((w) => w.meanings.filter(m => availableExampleCount(m) > 0).map((m) => ({ w, m })));
  if (mode === "mistakes")
    choices = choices.filter(
      ({ w, m }) =>
        w.hard ||
        Object.values(m.scores).some(
          (score) => score.wrong > 0 || score.slow > 0,
        ),
    );
  if (mode === "pairs")
    choices = choices.filter((item) =>
      choices.some((other) => confusable(item, other)),
    );
  choices.sort((a, b) =>
    mode === "mistakes"
      ? Object.values(b.m.scores).reduce(
          (v, score) => v + score.wrong + score.slow,
          0,
        ) -
        Object.values(a.m.scores).reduce(
          (v, score) => v + score.wrong + score.slow,
          0,
        )
      : due(a.m) - due(b.m),
  );
  const reviewed = choices.filter(({ m }) => Object.keys(m.scores).length > 0);
  const fresh = choices.filter(({ m }) => Object.keys(m.scores).length === 0);
  const estimatedCount = Math.max(1, Math.floor((minutes * 60) / 32));
  const newLimit = Math.max(1, Math.floor(estimatedCount * 0.3));
  const ordered =
    mode === "pairs" ? choices : [...reviewed, ...fresh.slice(0, newLimit), ...fresh.slice(newLimit)];
  const tasks: Task[] = [];
  let budget = minutes * 60;
  for (const { w, m } of ordered) {
    const seen = s.reviews.filter((review) => review.meaningId === m.id).length;
    const example = nextUnusedExample(m, seen);
    let type = mode === "pairs" ? 2 : chooseType(w, m, example, random);
    if (type === 2 && !canCloze(w, m, example)) {
      if(mode==="pairs") continue;
      type = 1;
    }
    if (tasks.length && budget - taskSeconds[type] < 0) continue;
    tasks.push({ wordId: w.id, meaningId: m.id, type, example });
    budget -= taskSeconds[type];
  }
  return { tasks: interleaveTasks(tasks), index: 0, correct: 0, minutes, mode };
}
function seededRandom(seed: string) {
  let value = 2166136261;
  for (const char of seed)
    value = ((value ^ char.charCodeAt(0)) * 16777619) >>> 0;
  return () => (value = (value * 1664525 + 1013904223) >>> 0) / 4294967296;
}
export function meaningOptions(
  state: State,
  word: Word,
  meaning: Meaning,
  task: Task,
) {
  const candidates = state.words
    .flatMap((w) => w.meanings.map((m) => ({ w, m })))
    .filter(
      (item) =>
        item.m.id !== meaning.id &&
        normalize(item.m.translation) !== normalize(meaning.translation),
    );
  const starter = seed()
    .words.flatMap((w) => w.meanings.map((m) => ({ w, m })))
    .filter(
      (item) =>
        normalize(item.m.translation) !== normalize(meaning.translation),
    );
  const pool = [...candidates, ...starter].filter(
    (item, index, all) =>
      all.findIndex(
        (other) =>
          normalize(other.m.translation) === normalize(item.m.translation),
      ) === index,
  );
  pool.sort(
    (a, b) =>
      Number(b.w.collection === word.collection) -
        Number(a.w.collection === word.collection) ||
      Number((b.m.pos || b.w.pos) === (meaning.pos || word.pos)) -
        Number((a.m.pos || a.w.pos) === (meaning.pos || word.pos)) ||
      Math.abs(
        ["A1", "A2", "B1", "B2", "C1", "C2"].indexOf(a.m.level || a.w.level) -
          ["A1", "A2", "B1", "B2", "C1", "C2"].indexOf(
            meaning.level || word.level,
          ),
      ) -
        Math.abs(
          ["A1", "A2", "B1", "B2", "C1", "C2"].indexOf(b.m.level || b.w.level) -
            ["A1", "A2", "B1", "B2", "C1", "C2"].indexOf(
              meaning.level || word.level,
            ),
        ),
  );
  const random = seededRandom(
    task.wordId +
      task.meaningId +
      task.type +
      task.example +
      state.session?.index,
  );
  const selected = [
    meaning.translation,
    ...pool
      .slice(0, Math.min(3, pool.length))
      .map((item) => item.m.translation),
  ];
  for (let index = selected.length - 1; index > 0; index--) {
    const target = Math.floor(random() * (index + 1));
    [selected[index], selected[target]] = [selected[target], selected[index]];
  }
  return selected;
}
export function migrateState(input: State): State {
  const state = structuredClone(input);
  for (const word of state.words)
    for (const meaning of word.meanings) {
      meaning.translation=withoutDialectLabel(meaning.translation);
      // v34: old exports keep their examples and are not silently queued for generation.
      if (meaning.enrichment) {
        if (meaning.enrichment.round !== undefined) meaning.enrichment.round = Math.max(0, Math.min(5, meaning.enrichment.round));
        meaning.enrichment.groups = [...new Set(meaning.enrichment.groups)];
        meaning.enrichment.retryAt = Math.max(0, meaning.enrichment.retryAt || 0);
      }
      meaning.topic = meaning.topic?.trim() || undefined;
      meaning.scene = meaning.scene?.trim() || undefined;
      for (const score of Object.values(meaning.scores)) {
        score.hinted ??= 0;
        score.value = masteryFromInterval(score.interval);
      }
    }
  for (const review of state.reviews) {
    // Missing masteryVersion identifies the historic practiced-skills scale.
    // Never relabel or rewrite those measurements as five-skill mastery.
    review.weight ??= 1;
    review.source ??= "exercise";
  }
  // Discard only unfinished tasks whose sentences are no longer published.
  // Keep the completed prefix/index, so an old export cannot expose a pending bank.
  if (state.session) {
    const {index,tasks}=state.session;
    state.session.tasks=[...tasks.slice(0,index),...tasks.slice(index).filter(t=>{
      const m=state.words.find(w=>w.id===t.wordId && !w.archived)?.meanings.find(m=>m.id===t.meaningId);
      return m && t.example < availableExampleCount(m);
    })];
  }
  state.combined ??= null; // v40: additive, existing sessions remain unchanged.
  state.reviewSummaries ??= [];
  state.practice ??= null;
  state.practiceHistory ??= [];
  // v39: old multiple-choice sessions retain their answers unchanged.
  if(state.practice) state.practice.writtenAnswers ??= state.practice.set.items.map(()=>"");
  // Additive migration: exports from v31 and earlier contain neither field.
  state.production ??= null;
  state.productionHistory ??= [];
  state.grammarSeen ??= {};
  // Recover currently visible legacy session entries without inventing past exposures.
  for (const item of state.production?.set.items.slice(0,(state.production?.index || 0)+1) || [])
    if (item.bankId) state.grammarSeen[item.bankId] ??= 1;
  for (const item of state.practice?.set.items.slice(0,(state.practice?.index || 0)+1) || [])
    if (item.category === "grammar" && item.bankId) state.grammarSeen[item.bankId] ??= 1;
  return state;
}
export function seed(): State {
  const now = Date.now();
  const rows = [
    [
      "get the hang of",
      "załapać, jak coś działa",
      "To learn how to do something through practice.",
      "You will get the hang of it with a little practice.|I want to get the hang of this new app.",
      "Codzienne rozmowy",
      "B2",
      "/ɡet ðə hæŋ əv/",
      "zwrot",
      "potoczny",
      64,
    ],
    [
      "borrow",
      "pożyczyć od kogoś",
      "To take something temporarily and return it.",
      "Can I borrow your pen?|I often borrow books from the library.",
      "Codzienne rozmowy",
      "A2",
      "/ˈbɒrəʊ/",
      "czasownik",
      "neutralny",
      38,
    ],
    [
      "lend",
      "pożyczyć komuś",
      "To give something temporarily to someone.",
      "Could you lend me your umbrella?|I can lend you my bike.",
      "Codzienne rozmowy",
      "A2",
      "/lend/",
      "czasownik",
      "neutralny",
      45,
    ],
    [
      "boarding pass",
      "karta pokładowa",
      "A document that lets you board a plane.",
      "Please show me your boarding pass.|Keep your boarding pass ready.",
      "W podróży",
      "A2",
      "/ˈbɔːdɪŋ pɑːs/",
      "rzeczownik",
      "neutralny",
      88,
    ],
    [
      "accomplish",
      "osiągnąć, zrealizować",
      "To successfully complete a task or goal.",
      "We can accomplish a lot together.|What do you want to accomplish this year?",
      "W pracy",
      "B2",
      "/əˈkʌmplɪʃ/",
      "czasownik",
      "formalny",
      72,
    ],
    [
      "it depends",
      "to zależy",
      "Used when an answer changes with the situation.",
      "It depends on the weather.|It depends on how much time we have.",
      "Codzienne rozmowy",
      "A2",
      "/ɪt dɪˈpendz/",
      "zwrot",
      "neutralny",
      0,
    ],
    [
      "bank",
      "bank — instytucja finansowa",
      "An institution where people keep or borrow money.",
      "The bank closes at five.|There is a bank near my office.",
      "Codzienne rozmowy",
      "A1",
      "/bæŋk/",
      "rzeczownik",
      "neutralny",
      55,
    ],
    [
      "reservation",
      "rezerwacja",
      "An arrangement to keep a room or table for someone.",
      "I have a reservation for two.|Can I change my reservation?",
      "W podróży",
      "A2",
      "/ˌrezəˈveɪʃən/",
      "rzeczownik",
      "neutralny",
      83,
    ],
    [
      "deadline",
      "termin wykonania",
      "The latest time by which something must be finished.",
      "The deadline is next Friday.|We need to meet the deadline.",
      "W pracy",
      "B1",
      "/ˈdedlaɪn/",
      "rzeczownik",
      "zawodowy",
      65,
    ],
    [
      "say",
      "powiedzieć coś",
      "To express something using words.",
      "What did you say?|Please say that again.",
      "Codzienne rozmowy",
      "A1",
      "/seɪ/",
      "czasownik",
      "neutralny",
      36,
    ],
    [
      "tell",
      "powiedzieć komuś",
      "To give information to a person.",
      "Please tell me the truth.|Can you tell us a story?",
      "Codzienne rozmowy",
      "A1",
      "/tel/",
      "czasownik",
      "neutralny",
      40,
    ],
    [
      "make",
      "zrobić, stworzyć",
      "To create or produce something.",
      "Let’s make a plan.|I want to make a cake.",
      "Codzienne rozmowy",
      "A1",
      "/meɪk/",
      "czasownik",
      "neutralny",
      62,
    ],
    [
      "do",
      "wykonywać czynność",
      "To perform an activity or task.",
      "I need to do my homework.|Can you do the shopping today?",
      "Codzienne rozmowy",
      "A1",
      "/duː/",
      "czasownik",
      "neutralny",
      48,
    ],
    [
      "appointment",
      "umówiona wizyta",
      "An arrangement to meet someone at a particular time.",
      "I have an appointment with the doctor.|Can I book an appointment?",
      "U lekarza",
      "A2",
      "/əˈpɔɪntmənt/",
      "rzeczownik",
      "neutralny",
      74,
    ],
    [
      "recommend",
      "polecać",
      "To suggest that someone or something is a good choice.",
      "What dish do you recommend?|I recommend the vegetable soup.",
      "W restauracji",
      "B1",
      "/ˌrekəˈmend/",
      "czasownik",
      "neutralny",
      80,
    ],
    [
      "strength",
      "mocna strona",
      "A positive quality or ability.",
      "My greatest strength is patience.|Teamwork is a real strength of mine.",
      "Rozmowa o pracę",
      "B1",
      "/streŋθ/",
      "rzeczownik",
      "neutralny",
      60,
    ],
    [
      "take your time",
      "nie spiesz się",
      "Used to say that someone does not need to hurry.",
      "Take your time. There is no rush.|Please take your time with the exercise.",
      "Codzienne rozmowy",
      "B1",
      "/teɪk jɔː taɪm/",
      "zwrot",
      "neutralny",
      90,
    ],
    [
      "figure out",
      "rozgryźć, zrozumieć",
      "To understand or solve something by thinking.",
      "Let’s figure out what went wrong.|I need to figure out how this works.",
      "W pracy",
      "B1",
      "/ˈfɪɡər aʊt/",
      "czasownik frazowy",
      "potoczny",
      0,
    ],
  ];
  const words: Word[] = rows.map((r, i) => {
    const [en, tr, def, ex, collection, level, ipa, pos, reg, value] = r;
    const scores: Meaning["scores"] = {};
    if (value)
      for (const [j, k] of (
        ["recognition", "recall", "spelling", "listening"] as Skill[]
      ).entries()) {
        const interval = Number(value) > 80 ? 14 : 3;
        scores[k] = {
          value: masteryFromInterval(interval),
          interval,
          due: now + (i % 3 === 0 ? 3 : -1) * 86400000,
          correct: Math.round(Number(value) / 10),
          wrong: i === 1 || i === 2 ? 4 : i === 9 || i === 10 ? 2 : 0,
          hinted: 0,
          last: now - (1 + (i % 4)) * 86400000,
          slow: 0,
        };
      }
    return {
      id: "w" + i,
      en: String(en),
      ipa: String(ipa),
      pos: String(pos),
      level: String(level),
      collection: String(collection),
      tags: i < 3 ? ["przydatne"] : [],
      source: "Zestaw startowy",
      note:
        i === 1
          ? "Borrow = biorę, lend = daję. Po borrow użyj from, po lend — to."
          : i === 9
            ? "Say something, ale tell someone something."
            : "",
      forms:
        en === "borrow"
          ? "borrowed · borrowed"
          : en === "lend"
            ? "lent · lent"
            : en === "say"
              ? "said · said"
              : en === "tell"
                ? "told · told"
                : en === "make"
                  ? "made · made"
                  : en === "do"
                    ? "did · done"
                    : "",
      collocations:
        en === "make"
          ? "make a decision · make a mistake"
          : en === "do"
            ? "do homework · do your best"
            : en === "deadline"
              ? "meet a deadline · miss a deadline"
              : "",
      synonyms: en === "accomplish" ? "achieve · complete" : "",
      antonyms: "",
      important: i === 0,
      hard: i === 1 || i === 2,
      archived: false,
      created: now - i * 3600000,
      meanings: [
        {
          id: "m" + i,
          translation: String(tr),
          definition: String(def),
          examples: String(ex).split("|"),
          context: String(collection),
          register: String(reg),
          natural: en === "accomplish" ? "get something done" : "",
          scores,
        },
      ],
    };
  });
  words[6].meanings.push({
    id: "m6b",
    translation: "brzeg rzeki",
    definition: "The land along the side of a river.",
    examples: ["We sat on the river bank.", "Flowers grow along the bank."],
    context: "Natura i krajobraz",
    register: "neutralny",
    natural: "",
    scores: {},
  });
  const reviews: Review[] = [];
  for (let day = 6; day >= 0; day--) {
    const n = [8, 12, 0, 15, 10, 18, 6][6 - day];
    for (let j = 0; j < n; j++) {
      const w = words[j % words.length];
      reviews.push({
        id: `demo-${day}-${j}`,
        wordId: w.id,
        meaningId: w.meanings[0].id,
        skill: "recall",
        correct: j % 9 !== 0,
        at: now - day * 86400000 - j * 30000,
        seconds: 7,
        confidence: 2,
        hint: false,
        error: j % 9 === 0 ? "Przypominanie" : "",
        before: 30,
        after: 40,
        demo: true,
      });
    }
  }
  return {
    words,
    collections: [
      "Codzienne rozmowy",
      "W podróży",
      "W pracy",
      "Rozmowa o pracę",
      "U lekarza",
      "W restauracji",
    ],
    reviews,
    settings: {
      goal: 20,
      reminder: "19:00",
      accent: "en-US",
      slow: false,
      voiceRevision: 2,
    },
    session: null,
    demo: true,
  };
}
