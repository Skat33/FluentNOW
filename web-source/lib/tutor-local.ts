import {correctionFor,vocabularyTarget,correctedPractice,correctedReading} from "./report-corrections";
import {answerKey, polishAnswers, englishAnswerKey, withoutDialectLabel} from "./answer-variants";
import {selectBankReading} from "./reading-bank";
import { selectGrammarItems, type GrammarSeen } from "./grammar-bank";
import { availableExampleCount } from "./example-pool";
import { advancedReadings } from "./data/advanced-readings";
import { productionPool } from "./production";
import { idiomPool } from "./data/idiom-bank";
import { seed, normalize, mastery, due, MASTERED_THRESHOLD } from "./learning";
import type { Word, Meaning, State } from "./learning";
import type {
  Lookup,
  ExamplePair,
  Grade,
  Reading,
  Recommendation,
  PracticeKind,
  PracticeQuestion,
  PracticeSet,
} from "./tutor-types";

const STARTER = seed();

const pairs: Record<string, [string, string][]> = {
  "get the hang of": [
    [
      "Załapiesz, jak to działa, przy odrobinie praktyki.",
      "Załapiesz, jak to działa",
    ],
    [
      "Chcę załapać, jak korzystać z tej nowej aplikacji.",
      "załapać, jak korzystać",
    ],
  ],
  borrow: [
    ["Czy mogę pożyczyć twój długopis?", "pożyczyć"],
    ["Często wypożyczam książki z biblioteki.", "wypożyczam"],
  ],
  lend: [
    ["Czy możesz pożyczyć mi swój parasol?", "pożyczyć mi"],
    ["Mogę pożyczyć ci mój rower.", "pożyczyć ci"],
  ],
  "boarding pass": [
    ["Proszę pokazać mi kartę pokładową.", "kartę pokładową"],
    ["Miej kartę pokładową pod ręką.", "kartę pokładową"],
  ],
  accomplish: [
    ["Razem możemy wiele osiągnąć.", "osiągnąć"],
    ["Co chcesz osiągnąć w tym roku?", "osiągnąć"],
  ],
  "it depends": [
    ["To zależy od pogody.", "To zależy"],
    ["To zależy od tego, ile mamy czasu.", "To zależy"],
  ],
  bank: [
    ["Bank zamyka się o piątej.", "Bank"],
    ["W pobliżu mojego biura jest bank.", "bank"],
  ],
  "bank:river": [
    ["Usiedliśmy na brzegu rzeki.", "brzegu rzeki"],
    ["Wzdłuż brzegu rosną kwiaty.", "brzegu"],
  ],
  reservation: [
    ["Mam rezerwację dla dwóch osób.", "rezerwację"],
    ["Czy mogę zmienić rezerwację?", "rezerwację"],
  ],
  deadline: [
    ["Termin wykonania przypada w następny piątek.", "Termin wykonania"],
    ["Musimy dotrzymać terminu.", "terminu"],
  ],
  say: [
    ["Co powiedziałeś?", "powiedziałeś"],
    ["Proszę, powiedz to jeszcze raz.", "powiedz"],
  ],
  tell: [
    ["Proszę, powiedz mi prawdę.", "powiedz mi"],
    ["Czy możesz opowiedzieć nam historię?", "opowiedzieć nam"],
  ],
  make: [
    ["Zróbmy plan.", "Zróbmy"],
    ["Chcę upiec ciasto.", "upiec"],
  ],
  do: [
    ["Muszę odrobić pracę domową.", "odrobić"],
    ["Czy możesz dziś zrobić zakupy?", "zrobić"],
  ],
  appointment: [
    ["Mam umówioną wizytę u lekarza.", "umówioną wizytę"],
    ["Czy mogę umówić wizytę?", "umówić wizytę"],
  ],
  recommend: [
    ["Jakie danie polecasz?", "polecasz"],
    ["Polecam zupę warzywną.", "Polecam"],
  ],
  strength: [
    ["Moją największą mocną stroną jest cierpliwość.", "mocną stroną"],
    ["Praca zespołowa to moja prawdziwa mocna strona.", "mocna strona"],
  ],
  "take your time": [
    ["Nie spiesz się. Nie ma pośpiechu.", "Nie spiesz się"],
    ["Proszę, nie spiesz się z tym ćwiczeniem.", "nie spiesz się"],
  ],
  "figure out": [
    ["Rozgryźmy, co poszło nie tak.", "Rozgryźmy"],
    ["Muszę zrozumieć, jak to działa.", "zrozumieć"],
  ],
};
const aliases: Record<string, string[]> = {
  lend: [
    "lend someone",
    "lend somebody",
    "lend something to someone",
    "lend something to somebody",
  ],
  borrow: [
    "borrow something",
    "borrow something from someone",
    "borrow from someone",
  ],
  tell: ["tell someone", "tell somebody", "tell someone something"],
  say: ["say something"],
  do: ["to do"],
  make: ["to make"],
};
export function examplePair(
  w: Word,
  m: Meaning,
  index: number,
): ExamplePair | null {
  const en = m.examples[index];
  if (!en) return null;
  if (m.exampleTranslations?.[index])
    return {
      en,
      pl: m.exampleTranslations[index],
      focusEn: m.exampleFocusEn?.[index] || w.en,
      focusPl: m.exampleFocusPl?.[index] || m.translation,
    };
  const original = STARTER.words.find(
    (x) => normalize(x.en) === normalize(w.en),
  );
  const originalMeaning = original?.meanings.find(
    (x) => normalize(x.translation) === normalize(m.translation),
  );
  const at = originalMeaning?.examples.indexOf(en) ?? -1;
  const key =
    w.en === "bank" && m.translation === "brzeg rzeki"
      ? "bank:river"
      : normalize(w.en);
  const pair = at >= 0 ? pairs[key]?.[at] : undefined;
  return pair ? { en, pl: pair[0], focusEn: w.en, focusPl: pair[1] } : null;
}
export function starterLookup(term: string): Lookup | null {
  const w = STARTER.words.find((w) => normalize(w.en) === normalize(term));
  if (!w) {
    const candidates = advancedCandidates;
    const r = candidates.find((r) => normalize(r.term) === normalize(term));
    return r ? recommendationLookup(r) : null;
  }
  const result: Lookup = {
    exists: true,
    term: w.en,
    ipa: w.ipa,
    forms: w.forms,
    collocations: w.collocations,
    synonyms: w.synonyms,
    antonyms: w.antonyms,
    note: w.note,
    alternatives: [],
    source: "starter",
    meanings: w.meanings.map((m) => ({
      translation: withoutDialectLabel(m.translation),
      definition: m.definition,
      pos: w.pos,
      level: w.level,
      context: m.context,
      register: m.register,
      natural: m.natural,
      collection: w.collection,
      examples: m.examples.map((_, i) => examplePair(w, m, i)!),
      acceptedAnswers: aliases[w.en] || [],
    })),
  };
  if (w.en === "do")
    result.meanings.push(
      {
        translation: "czasownik pomocniczy w pytaniach",
        definition:
          "An auxiliary used to form questions in the present simple.",
        pos: "czasownik",
        level: "A1",
        context: "Pytania o zwyczaje i preferencje",
        register: "neutralny",
        natural: "",
        collection: "Pytania i gramatyka",
        examples: [
          {
            en: "Do you like coffee?",
            pl: "Czy lubisz kawę?",
            focusEn: "Do",
            focusPl: "Czy",
          },
          {
            en: "Do you work here?",
            pl: "Czy tu pracujesz?",
            focusEn: "Do",
            focusPl: "Czy",
          },
        ],
        acceptedAnswers: ["do"],
      },
      {
        translation: "wystarczyć, nadawać się",
        definition: "To be enough or suitable for a particular purpose.",
        pos: "czasownik",
        level: "B1",
        context: "Gdy coś jest wystarczająco dobre",
        register: "neutralny",
        natural: "",
        collection: "Codzienne rozmowy",
        examples: [
          {
            en: "This room will do for one night.",
            pl: "Ten pokój wystarczy na jedną noc.",
            focusEn: "do",
            focusPl: "wystarczy",
          },
          {
            en: "A small bag will do.",
            pl: "Mała torba wystarczy.",
            focusEn: "do",
            focusPl: "wystarczy",
          },
        ],
        acceptedAnswers: ["do", "be enough", "be suitable"],
      },
    );
  return result;
}
export function levenshtein(left: string, right: string) {
  const previous = Array.from(
    { length: right.length + 1 },
    (_, index) => index,
  );
  for (let row = 1; row <= left.length; row++) {
    let diagonal = previous[0];
    previous[0] = row;
    for (let column = 1; column <= right.length; column++) {
      const above = previous[column];
      previous[column] = Math.min(
        previous[column] + 1,
        previous[column - 1] + 1,
        diagonal + (left[row - 1] === right[column - 1] ? 0 : 1),
      );
      diagonal = above;
    }
  }
  return previous[right.length];
}

function collectionCore(value: string) {
  return normalize(value)
    .normalize("NFD")
    .replace(/[\u0300-\u036f]/g, "")
    .replace(/^(?:w|we|na|do|o|u|z|ze|dla)\s+/, "")
    .replace(/[^a-z0-9 ]/g, "")
    .trim();
}

function sameCollectionSubject(left: string, right: string) {
  const a = collectionCore(left);
  const b = collectionCore(right);
  if (!a || !b) return false;
  if (a === b) return true;
  const longest = Math.max(a.length, b.length);
  if (Math.min(a.length, b.length) < 5) return false;
  return levenshtein(a, b) <= Math.max(1, Math.floor(longest * 0.18));
}

export function resolveExistingCollection(
  collections: string[],
  suggested: string,
  topic?: string,
) {
  const targets = [suggested, topic].filter(
    (value): value is string => !!value?.trim(),
  );
  return (
    collections.find((collection) =>
      targets.some((target) => sameCollectionSubject(collection, target)),
    ) || null
  );
}
export function normalizeVocabularyAnswer(value:string) {
  return answerKey(value);
}
export function vocabularyAnswers(w:Word,m:Meaning,type:number,context=""):string[] {
  const patch=correctionFor(vocabularyTarget(w.en,m.translation,type,context,[w.en]));
  if(patch)return patch.expected;
  if(type===3) return polishAnswers(w.en,m.translation,m.acceptedTranslations);
  if(type!==1) return [w.en]; // Cloze uses the exact saved inflection; dictation the recorded word.
  const original=STARTER.words.find(x=>normalize(x.en)===normalize(w.en));
  const knownSense=original?.meanings.some(x=>normalize(x.translation)===normalize(m.translation));
  const variants=[w.en,...(m.acceptedAnswers || []),...(knownSense ? aliases[normalize(w.en)] || [] : [])];
  const verb=/czasownik|verb/i.test(m.pos || w.pos);
  return [...new Set([...variants,...(verb ? variants.filter(x=>!/^to /i.test(x)).map(x=>`to ${x}`) : [])])];
}
export function localGrade(answer:string,w:Word,m:Meaning,type:number,context=""):Grade {
  const key=type===3?answerKey:englishAnswerKey;
  const actual=key(answer);
  const accepted=vocabularyAnswers(w,m,type,context).map(key);
  if(actual && accepted.includes(actual)) return {verdict:"correct",explanation:"To poprawny wariant dla tego znaczenia. Wielkość liter, końcowa interpunkcja i polskie znaki nie wpływają na ocenę.",spellingCorrect:true,source:"local"};
  const swapped=["borrow","lend"].includes(w.en) && actual.startsWith(w.en==="lend"?"borrow":"lend");
  return {verdict:"incorrect",explanation:swapped ? "Lend oznacza pożyczyć coś komuś, a borrow — pożyczyć coś od kogoś." : "Odpowiedź nie pasuje do zapisanych poprawnych wariantów tego zadania. Jeśli brakuje prawidłowego wariantu, zgłoś błąd.",spellingCorrect:false,source:"local"};
}
export function mergeSuggestions(
  s: State,
  lookup: Lookup,
  indices: number[],
  collectionOverride?: string,
): State {
  const next = structuredClone(s);
  const chosen = indices.map((i) => lookup.meanings[i]).filter(Boolean).map(m=>({...m,translation:withoutDialectLabel(m.translation)}));
  for (const m of chosen) {
    if (
      next.words.some(
        (w) =>
          !w.archived &&
          normalize(w.en) === normalize(lookup.term) &&
          w.meanings.some(
            (x) => normalize(x.translation) === normalize(m.translation),
          ),
      )
    )
      continue;
    let collection =
      (collectionOverride?.trim()
        ? next.collections.find(
            (item) => normalize(item) === normalize(collectionOverride),
          ) || collectionOverride.trim()
        : resolveExistingCollection(
            next.collections,
            m.collection,
            m.topic,
          )) || m.collection;
    if (!collection.trim()) collection = "Codzienne rozmowy";
    if (!next.collections.includes(collection))
      next.collections.push(collection);
    let w = next.words.find(
      (w) =>
        !w.archived &&
        normalize(w.en) === normalize(lookup.term) &&
        w.collection === collection,
    );
    if (!w) {
      w = {
        id: crypto.randomUUID(),
        en: lookup.term,
        ipa: lookup.ipa,
        pos: m.pos,
        level: m.level,
        collection,
        tags: [],
        source:
          lookup.source === "ai"
            ? "Asystent AI — propozycje do weryfikacji"
            : "Opracowany zestaw startowy",
        note: lookup.note,
        forms: lookup.forms,
        collocations: lookup.collocations,
        synonyms: lookup.synonyms,
        antonyms: lookup.antonyms,
        important: false,
        hard: false,
        archived: false,
        created: Date.now(),
        meanings: [],
      };
      next.words.unshift(w);
    }
    if (
      w.meanings.some(
        (x) => normalize(x.translation) === normalize(m.translation),
      )
    )
      continue;
    w.meanings.push({
      id: crypto.randomUUID(),
      enrichment: {phase:"examples",detailsPending:!!m.needsDetails,groups:[],attempts:0,retryAt:0},
      topic: m.topic,
      scene: m.scene,
      translation: withoutDialectLabel(m.translation),
      definition: m.definition,
      examples: m.examples.map((x) => x.en),
      exampleTranslations: m.examples.map((x) => x.pl),
      exampleFocusEn: m.examples.map((x) => x.focusEn),
      exampleFocusPl: m.examples.map((x) => x.focusPl),
      acceptedAnswers: m.acceptedAnswers,
      acceptedTranslations: m.acceptedTranslations,
      level: m.level,
      levelConfidence: m.levelConfidence,
      levelReason: m.levelReason,
      spokenFrequency: m.spokenFrequency,
      pos: m.pos,
      context: m.context,
      register: m.register,
      natural: m.natural,
      scores: {},
    });
  }
  return next;
}
const levels = ["A1", "A2", "B1", "B2", "C1", "C2"];
export function estimatedLevel(s: State) {
  const available = s.words
    .filter((w) => !w.archived)
    .flatMap((w) =>
      w.meanings.map((m) => ({ level: m.level || w.level, score: mastery(m) })),
    )
    .filter((m) => levels.includes(m.level));
  const practiced = available.filter((meaning) => meaning.score >= 40);
  const sample = practiced.length
    ? practiced
    : available.map((meaning) => ({
        ...meaning,
        score: Math.max(10, meaning.score),
      }));
  if (!sample.length)
    return {
      level: "A1",
      targetLevel: "A2",
      count: 0,
      confidence: "low" as const,
    };
  const avg =
    sample.reduce((a, m) => a + levels.indexOf(m.level) * m.score, 0) /
    sample.reduce((a, m) => a + m.score, 0);
  const index = Math.round(avg);
  return {
    level: levels[index],
    targetLevel: levels[Math.min(levels.length - 1, index + 1)],
    count: sample.length,
    confidence: practiced.length ? ("high" as const) : ("low" as const),
  };
}
export function selectReadingMeanings(
  s: State,
  targetLevel: string,
  limit = 20,
) {
  const target = Math.max(0, levels.indexOf(targetLevel));
  return s.words
    .filter((word) => !word.archived)
    .flatMap((word) =>
      word.meanings.filter(meaning=>availableExampleCount(meaning)>0).map((meaning) => ({
        en: word.en,
        meaningId: meaning.id,
        translation: meaning.translation,
        level: meaning.level || word.level,
        topic: meaning.topic,
        scene: meaning.scene,
        priority:
          (due(meaning) <= Date.now() ? -1000 : 0) +
          (word.hard ? -500 : 0) +
          mastery(meaning) * 4 +
          Math.abs(levels.indexOf(meaning.level || word.level) - target) * 60,
      })),
    )
    .filter((item) => levels.includes(item.level))
    .sort((left, right) => left.priority - right.priority)
    .slice(0, limit)
    .map(({ priority: _priority, ...item }) => item);
}
const advancedCandidates: Recommendation[] = [
  {
    known: "figure out",
    term: "ascertain",
    level: "C1",
    translation: "ustalić, dowiedzieć się",
    difference:
      "Bardziej formalne: ustalić fakt z pewnością. Nie zastępuje figure out w każdej sytuacji.",
    example: "We need to ascertain the cause of the problem.",
    examplePl: "Musimy ustalić przyczynę problemu.",
  },
  {
    known: "do",
    term: "carry out",
    level: "B2",
    translation: "wykonać, przeprowadzić",
    difference:
      "Dotyczy zadań, planów i badań. Nie używaj jako czasownika pomocniczego do.",
    example: "We will carry out the plan tomorrow.",
    examplePl: "Jutro zrealizujemy plan.",
  },
  {
    known: "make",
    term: "create",
    level: "B1",
    translation: "tworzyć",
    difference:
      "Pasuje do tworzenia czegoś nowego, ale nie do wszystkich kolokacji z make.",
    example: "We can create a new design.",
    examplePl: "Możemy stworzyć nowy projekt.",
  },
  {
    known: "recommend",
    term: "advocate",
    level: "C1",
    translation: "opowiadać się za, zalecać",
    difference:
      "Silniejsze i bardziej formalne poparcie dla rozwiązania; nie zamieniaj automatycznie w rekomendacji dania.",
    example: "They advocate a more flexible approach.",
    examplePl: "Opowiadają się za bardziej elastycznym podejściem.",
  },
  {
    known: "accomplish",
    term: "attain",
    level: "C1",
    translation: "osiągnąć",
    difference:
      "Zwykle o poziomie lub celu. Accomplish częściej dotyczy wykonania zadania.",
    example: "She hopes to attain a higher level of fluency.",
    examplePl: "Ma nadzieję osiągnąć wyższy poziom płynności.",
  },
];
export function recommendations(s: State): Recommendation[] {
  const known = s.words.filter(
    (w) => !w.archived && w.meanings.some((m) => mastery(m) >= MASTERED_THRESHOLD),
  );
  return advancedCandidates
    .filter(
      (r) =>
        known.some(
          (w) =>
            w.en === r.known &&
            levels.indexOf(w.level) < levels.indexOf(r.level),
        ) &&
        !s.words.some(
          (w) => !w.archived && normalize(w.en) === normalize(r.term),
        ),
    )
    .slice(0, 3);
}
export function recommendationLookup(r: Recommendation): Lookup {
  return {
    exists: true,
    term: r.term,
    ipa:
      (
        {
          ascertain: "/ˌæsɚˈteɪn/",
          "carry out": "/ˈkæri aʊt/",
          create: "/kriˈeɪt/",
          advocate: "/ˈædvəkeɪt/",
          attain: "/əˈteɪn/",
        } as Record<string, string>
      )[r.term] || "",
    forms: "",
    collocations: "",
    synonyms: r.known,
    antonyms: "",
    note: r.difference,
    alternatives: [],
    source: "starter",
    meanings: [
      {
        translation: r.translation,
        definition: r.difference,
        level: r.level,
        pos: "czasownik",
        context: "Rozwijanie słownictwa",
        register: ["create", "carry out"].includes(r.term)
          ? "neutralny"
          : "formalny",
        natural: r.known,
        collection: "Krok dalej",
        examples: [
          {
            en: r.example,
            pl: r.examplePl,
            focusEn: r.term,
            focusPl:
              (
                {
                  ascertain: "ustalić",
                  "carry out": "zrealizujemy",
                  create: "stworzyć",
                  advocate: "Opowiadają się za",
                  attain: "osiągnąć",
                } as Record<string, string>
              )[r.term] || r.translation.split(",")[0],
          },
        ],
        acceptedAnswers: [],
      },
    ],
  };
}
const readings: Record<string, Omit<Reading, "id" | "source">> = {
  A1: {
    title: "A small favor",
    level: "A1",
    paragraphs: [
      "Mia has a new job. Her office is near a bank. Today she has no pen. She asks Tom, “Can I borrow your pen?” Tom says yes. Mia uses the pen and gives it back. After work, they have coffee.",
    ],
    questions: [
      {
        question: "What does Mia need?",
        options: ["A pen", "A new office", "A ticket", "Some coffee"],
        answer: 0,
        explanation: "Mia nie ma długopisu, więc prosi Toma o pożyczenie.",
        evidence: "Today she has no pen.",
      },
      {
        question: "Who lends the pen?",
        options: ["Mia", "Tom", "A customer", "A doctor"],
        answer: 1,
        explanation: "Tom zgadza się pożyczyć Mii swój długopis.",
        evidence: "She asks Tom, “Can I borrow your pen?” Tom says yes.",
      },
      {
        question: "What does Mia do with the pen after using it?",
        options: [
          "She loses it",
          "She buys it",
          "She returns it",
          "She takes it home",
        ],
        answer: 2,
        explanation: "Mia oddaje długopis po użyciu.",
        evidence: "Mia uses the pen and gives it back.",
      },
    ],
  },
  A2: {
    title: "A change of plans",
    level: "A2",
    paragraphs: [
      "Alex and his sister are going on a short trip. At the airport, Alex cannot find his boarding pass. His sister tells him to take his time and check his phone. The boarding pass is in his email. They get on the plane before the doors close. When they arrive, they call the hotel to confirm their reservation. The hotel is next to the river, so they decide to walk along the bank before dinner.",
    ],
    questions: [
      {
        question: "Why does Alex check his phone?",
        options: [
          "To book a hotel",
          "To find his boarding pass",
          "To call his sister",
          "To order dinner",
        ],
        answer: 1,
        explanation:
          "Siostra radzi mu sprawdzić telefon, bo nie może znaleźć karty pokładowej.",
        evidence: "The boarding pass is in his email.",
      },
      {
        question: "What does “bank” mean here?",
        options: [
          "A place to keep money",
          "A seat at the airport",
          "The land beside a river",
          "A hotel office",
        ],
        answer: 2,
        explanation: "Kontekst spaceru nad rzeką wskazuje na brzeg.",
        evidence:
          "The hotel is next to the river, so they decide to walk along the bank before dinner.",
      },
      {
        question: "Which statement is true?",
        options: [
          "They miss their flight",
          "They cancel their reservation",
          "They travel with their parents",
          "They board the plane in time",
        ],
        answer: 3,
        explanation: "Wsiadają przed zamknięciem drzwi samolotu.",
        evidence: "They get on the plane before the doors close.",
      },
    ],
  },
  B1: {
    title: "The deadline",
    level: "B1",
    paragraphs: [
      "Nora is preparing a presentation with her colleague Sam. Their deadline is Friday, but the report contains several mistakes. Instead of working faster, they decide to figure out why the mistakes happened. Sam recommends checking the original notes. Nora agrees and borrows a notebook from him. The notes help them understand the problem. They finish on Thursday and have time to practice. Nora realizes that asking for help was more useful than trying to do everything alone.",
    ],
    questions: [
      {
        question: "Why do they check the original notes?",
        options: [
          "To change the deadline",
          "To understand the mistakes",
          "To borrow a laptop",
          "To cancel the presentation",
        ],
        answer: 1,
        explanation:
          "Szukają przyczyny błędów; notatki pomagają zrozumieć problem.",
        evidence: "The notes help them understand the problem.",
      },
      {
        question: "Who lends the notebook?",
        options: ["Nora", "Their manager", "Sam", "A client"],
        answer: 2,
        explanation: "Nora pożycza notes od Sama, czyli to Sam go udostępnia.",
        evidence: "Nora agrees and borrows a notebook from him.",
      },
      {
        question: "What is the main lesson of the text?",
        options: [
          "Working alone is always faster",
          "Deadlines should be ignored",
          "Presentations need no practice",
          "Asking for help can improve the result",
        ],
        answer: 3,
        explanation:
          "Nora uznaje współpracę za bardziej skuteczną niż samodzielne wykonanie wszystkiego.",
        evidence:
          "Nora realizes that asking for help was more useful than trying to do everything alone.",
      },
    ],
  },
  B2: {
    title: "A better way to work",
    level: "B2",
    paragraphs: [
      "When a small design team missed an important deadline, its manager initially blamed a lack of effort. However, the team’s records told a different story. Several tasks had been assigned twice, while others had no clear owner. The manager decided to carry out a review before introducing longer working hours. Team members were encouraged to explain what had prevented them from making progress. Their feedback revealed that unclear instructions, rather than laziness, were the main obstacle. After responsibilities were clarified, the team completed its next project ahead of schedule. The manager learned that improving a process can be more effective than simply demanding more effort.",
    ],
    questions: [
      {
        question: "What did the manager initially misunderstand?",
        options: [
          "The project’s price",
          "The reason for the delay",
          "The team’s location",
          "The client’s language",
        ],
        answer: 1,
        explanation:
          "Początkowo obwiniał brak wysiłku, a problemem była organizacja pracy.",
        evidence: "its manager initially blamed a lack of effort.",
      },
      {
        question: "What did the review reveal?",
        options: [
          "Everyone needed a new computer",
          "The deadline was impossible",
          "Responsibilities were unclear",
          "The client cancelled the project",
        ],
        answer: 2,
        explanation:
          "Zadania się dublowały lub nie miały właściciela, a instrukcje były niejasne.",
        evidence:
          "Several tasks had been assigned twice, while others had no clear owner.",
      },
      {
        question: "What can be inferred from the outcome?",
        options: [
          "Clearer organization helped the team",
          "Longer hours solved the problem",
          "The manager dismissed the team",
          "Less feedback was needed",
        ],
        answer: 0,
        explanation:
          "Po wyjaśnieniu odpowiedzialności zespół skończył kolejny projekt wcześniej.",
        evidence:
          "After responsibilities were clarified, the team completed its next project ahead of schedule.",
      },
    ],
  },
};
const extraReadings: Record<string, Omit<Reading, "id" | "source">[]> = {
  A1: [
    {
      title: "Lunch for two",
      level: "A1",
      paragraphs: [
        "Ben goes to a small restaurant with Ana. Ana has soup, but Ben wants a sandwich. The waiter recommends the cheese sandwich. Ben orders it and gives Ana some of his salad. They like the food and walk home together.",
      ],
      questions: [
        {
          question: "Where do Ben and Ana go?",
          options: [
            "To a restaurant",
            "To a bank",
            "To school",
            "To an airport",
          ],
          answer: 0,
          explanation: "Idą do małej restauracji.",
          evidence: "Ben goes to a small restaurant with Ana.",
        },
        {
          question: "What does the waiter recommend?",
          options: ["Soup", "The cheese sandwich", "Coffee", "A salad"],
          answer: 1,
          explanation: "Kelner poleca kanapkę z serem.",
          evidence: "The waiter recommends the cheese sandwich.",
        },
        {
          question: "How do they go home?",
          options: ["By bus", "By car", "They walk", "By train"],
          answer: 2,
          explanation: "Po posiłku wracają pieszo.",
          evidence: "They like the food and walk home together.",
        },
      ],
    },
  ],
  A2: [
    {
      title: "The doctor’s appointment",
      level: "A2",
      paragraphs: [
        "Leo has an appointment with his doctor on Monday morning. He arrives early because the clinic is new to him. A receptionist tells him where to wait. The doctor asks about his cough and recommends rest and warm drinks. Leo writes the advice on his phone so he will remember it.",
      ],
      questions: [
        {
          question: "When is Leo’s appointment?",
          options: [
            "Monday morning",
            "Monday evening",
            "Friday morning",
            "Sunday",
          ],
          answer: 0,
          explanation: "Wizyta jest w poniedziałek rano.",
          evidence: "Leo has an appointment with his doctor on Monday morning.",
        },
        {
          question: "Why does Leo arrive early?",
          options: [
            "He feels worse",
            "The clinic is new to him",
            "The doctor called",
            "He needs coffee",
          ],
          answer: 1,
          explanation: "Nie zna jeszcze tej przychodni.",
          evidence: "He arrives early because the clinic is new to him.",
        },
        {
          question: "Where does he save the advice?",
          options: ["In a book", "On paper", "On his phone", "In an email"],
          answer: 2,
          explanation: "Zapisuje radę w telefonie.",
          evidence:
            "Leo writes the advice on his phone so he will remember it.",
        },
      ],
    },
  ],
  B1: [
    {
      title: "A useful interview lesson",
      level: "B1",
      paragraphs: [
        "Marta prepared carefully for a job interview. She wrote down her main strengths and practised giving short examples. During the interview, she did not understand one question, so she asked the manager to repeat it. The manager appreciated her calm response. Marta did not get that job, but the feedback helped her perform much better at her next interview.",
      ],
      questions: [
        {
          question: "How did Marta prepare?",
          options: [
            "She practised examples",
            "She bought a suit",
            "She called the manager",
            "She changed careers",
          ],
          answer: 0,
          explanation: "Ćwiczyła krótkie przykłady swoich mocnych stron.",
          evidence:
            "She wrote down her main strengths and practised giving short examples.",
        },
        {
          question: "What did she do after a difficult question?",
          options: [
            "She left",
            "She asked for repetition",
            "She guessed",
            "She changed the subject",
          ],
          answer: 1,
          explanation: "Poprosiła o powtórzenie pytania.",
          evidence: "she asked the manager to repeat it.",
        },
        {
          question: "What was the long-term result?",
          options: [
            "She stopped applying",
            "She got the first job",
            "She improved at the next interview",
            "She became a manager",
          ],
          answer: 2,
          explanation: "Informacja zwrotna pomogła jej w kolejnym spotkaniu.",
          evidence:
            "the feedback helped her perform much better at her next interview.",
        },
      ],
    },
  ],
  B2: [
    {
      title: "The quiet experiment",
      level: "B2",
      paragraphs: [
        "A busy office introduced two hours of quiet work every morning. At first, several employees worried that communication would suffer. The team agreed to try the idea for one month and measure the results. People completed complex tasks faster, while urgent questions were collected for a short meeting at noon. The experiment did not eliminate collaboration; it gave collaboration a clearer place in the day. After the trial, the team voted to keep the new routine.",
      ],
      questions: [
        {
          question: "What did the office introduce?",
          options: [
            "Quiet work time",
            "A longer lunch",
            "Remote Fridays",
            "New software",
          ],
          answer: 0,
          explanation: "Wprowadzono dwie godziny cichej pracy.",
          evidence:
            "A busy office introduced two hours of quiet work every morning.",
        },
        {
          question: "How were urgent questions handled?",
          options: [
            "They were ignored",
            "They were collected for noon",
            "They were emailed outside work",
            "They stopped the experiment",
          ],
          answer: 1,
          explanation: "Zbierano je na krótkie spotkanie w południe.",
          evidence:
            "urgent questions were collected for a short meeting at noon.",
        },
        {
          question: "What did the team decide?",
          options: [
            "To shorten the trial",
            "To remove meetings",
            "To keep the routine",
            "To work at night",
          ],
          answer: 2,
          explanation: "Zespół zagłosował za zachowaniem rozwiązania.",
          evidence: "After the trial, the team voted to keep the new routine.",
        },
      ],
    },
  ],
  C1: [
    {
      title: "When efficiency becomes a habit",
      level: "C1",
      paragraphs: [
        "A logistics company replaced informal problem-solving with a detailed reporting system. The change initially improved accountability, because recurring failures became easier to trace. Over time, however, employees began documenting minor issues instead of resolving them immediately. Management eventually recognised that the procedure had become an end in itself. The company retained reports for serious incidents but restored individual discretion for routine decisions. This balance preserved useful evidence without discouraging initiative.",
      ],
      questions: [
        {
          question: "What was the initial benefit of the system?",
          options: [
            "Greater accountability",
            "Lower salaries",
            "Fewer employees",
            "Faster deliveries",
          ],
          answer: 0,
          explanation:
            "System ułatwił ustalanie odpowiedzialności i śledzenie awarii.",
          evidence:
            "The change initially improved accountability, because recurring failures became easier to trace.",
        },
        {
          question: "What unintended behaviour appeared?",
          options: [
            "Managers resigned",
            "Staff documented trivial issues",
            "Customers wrote reports",
            "Serious incidents were hidden",
          ],
          answer: 1,
          explanation:
            "Pracownicy zaczęli opisywać drobiazgi zamiast je od razu rozwiązywać.",
          evidence:
            "employees began documenting minor issues instead of resolving them immediately.",
        },
        {
          question: "What solution was adopted?",
          options: [
            "All reports were removed",
            "Every choice required approval",
            "Routine discretion was restored",
            "The company outsourced logistics",
          ],
          answer: 2,
          explanation: "Przy rutynowych decyzjach przywrócono samodzielność.",
          evidence:
            "The company retained reports for serious incidents but restored individual discretion for routine decisions.",
        },
      ],
    },
    {
      title: "The value of an unfinished answer",
      level: "C1",
      paragraphs: [
        "During a public debate, a researcher was asked to predict how a new technology would affect employment. Rather than offering a confident figure, she explained which evidence was still missing. Some listeners interpreted her caution as weakness, yet her answer changed the tone of the discussion. Other speakers began distinguishing established facts from assumptions. By the end, the audience had fewer simple predictions but a clearer understanding of the uncertainty involved. Intellectual honesty had made the debate more useful, not less decisive.",
      ],
      questions: [
        {
          question: "What did the researcher refuse to provide?",
          options: [
            "A confident prediction",
            "A definition",
            "A source",
            "A question",
          ],
          answer: 0,
          explanation: "Nie podała pewnej liczby bez wystarczających danych.",
          evidence:
            "Rather than offering a confident figure, she explained which evidence was still missing.",
        },
        {
          question: "How did other speakers react?",
          options: [
            "They left",
            "They separated facts from assumptions",
            "They criticised the audience",
            "They changed the topic",
          ],
          answer: 1,
          explanation: "Zaczęli odróżniać fakty od założeń.",
          evidence:
            "Other speakers began distinguishing established facts from assumptions.",
        },
        {
          question: "What did the audience gain?",
          options: [
            "More exact figures",
            "A unanimous opinion",
            "A clearer view of uncertainty",
            "A shorter debate",
          ],
          answer: 2,
          explanation: "Publiczność lepiej zrozumiała zakres niepewności.",
          evidence:
            "the audience had fewer simple predictions but a clearer understanding of the uncertainty involved.",
        },
      ],
    },
  ],
};

export function starterReading(level:string,history:number | {id:string;title?:string;at?:number}[]=[],topic=""):Reading {
  return correctedReading(selectBankReading(level,history,topic));
}

const grammarQuestions: (PracticeQuestion & { level: string })[] = [
  {
    level: "A1",
    category: "grammar",
    prompt: "Wybierz poprawną formę czasownika.",
    context: "My sister ___ in London.",
    options: ["live", "lives", "living", "is live"],
    answer: 1,
    explanation:
      "W Present Simple po he, she lub it dodajemy do czasownika -s. „Live” pasuje do I, you, we i they.",
    translation: "Moja siostra mieszka w Londynie.",
  },
  {
    level: "A2",
    category: "grammar",
    prompt: "Uzupełnij zdanie opisujące zakończoną czynność.",
    context: "We ___ the museum yesterday.",
    options: ["visit", "visited", "have visit", "are visiting"],
    answer: 1,
    explanation:
      "„Yesterday” wskazuje na Past Simple, dlatego używamy regularnej formy „visited”.",
    translation: "Wczoraj odwiedziliśmy muzeum.",
  },
  {
    level: "A2",
    category: "grammar",
    prompt: "Wybierz właściwy przyimek czasu.",
    context: "The meeting starts ___ nine o'clock.",
    options: ["in", "on", "at", "for"],
    answer: 2,
    explanation:
      "Przy konkretnej godzinie używamy „at”. „On” łączy się zwykle z dniami, a „in” z miesiącami lub latami.",
    translation: "Spotkanie zaczyna się o dziewiątej.",
  },
  {
    level: "B1",
    category: "grammar",
    prompt: "Wybierz formę pasującą do doświadczenia życiowego.",
    context: "I ___ sushi several times.",
    options: ["ate", "have eaten", "had eat", "am eating"],
    answer: 1,
    explanation:
      "Present Perfect opisuje doświadczenie bez podawania zakończonego momentu. Past Simple wymagałby określonego czasu.",
    translation: "Jadłem sushi kilka razy.",
  },
  {
    level: "B1",
    category: "grammar",
    prompt: "Uzupełnij pierwszy okres warunkowy.",
    context: "If it rains, we ___ at home.",
    options: ["stay", "stayed", "will stay", "would stay"],
    answer: 2,
    explanation:
      "W pierwszym okresie warunkowym po „if” używamy Present Simple, a w zdaniu głównym „will”.",
    translation: "Jeśli będzie padać, zostaniemy w domu.",
  },
  {
    level: "B2",
    category: "grammar",
    prompt: "Wybierz poprawną stronę bierną.",
    context: "The final decision ___ tomorrow.",
    options: [
      "will announce",
      "will be announced",
      "is announce",
      "has announcing",
    ],
    answer: 1,
    explanation:
      "Decyzja jest przedmiotem czynności, dlatego potrzebna jest strona bierna: „will be” + imiesłów.",
    translation: "Ostateczna decyzja zostanie ogłoszona jutro.",
  },
  {
    level: "B2",
    category: "grammar",
    prompt: "Wybierz formę po czasowniku „suggest”.",
    context: "She suggested ___ an earlier train.",
    options: ["take", "to take", "taking", "took"],
    answer: 2,
    explanation:
      "Po „suggest” często używamy formy z -ing. Konstrukcja „suggest to take” jest niepoprawna.",
    translation: "Zaproponowała, żeby pojechać wcześniejszym pociągiem.",
  },
  {
    level: "C1",
    category: "grammar",
    prompt: "Wybierz naturalną konstrukcję inwersyjną.",
    context: "Rarely ___ such a convincing argument.",
    options: [
      "I have heard",
      "have I heard",
      "I heard have",
      "did I have heard",
    ],
    answer: 1,
    explanation:
      "Po ograniczającym przysłówku „rarely” na początku zdania stosujemy inwersję: operator przed podmiotem.",
    translation: "Rzadko słyszałem tak przekonujący argument.",
  },
];

const idiomQuestions: (PracticeQuestion & { level: string })[] = [
  {
    level: "A2",
    category: "idiom",
    prompt: "Co oznacza ten codzienny zwrot?",
    context: "Don't worry. Take your time.",
    options: ["Spóźnij się", "Nie spiesz się", "Zmierz czas", "Zrób przerwę"],
    answer: 1,
    explanation:
      "„Take your time” znaczy „nie spiesz się”. Nie jest dosłownym poleceniem zabrania czasu.",
    translation: "Nie martw się. Nie spiesz się.",
  },
  {
    level: "A2",
    category: "idiom",
    prompt: "Wybierz zwrot pasujący do sytuacji.",
    context: "I am very tired, so I am going to ___.",
    options: ["hit the books", "hit the road", "hit the sack", "hit the roof"],
    answer: 2,
    explanation:
      "„Hit the sack” to potoczne „iść spać”. Pozostałe zwroty dotyczą nauki, wyjazdu lub złości.",
    translation: "Jestem bardzo zmęczony, więc idę spać.",
  },
  {
    level: "B1",
    category: "idiom",
    prompt: "Co rozmówca chce powiedzieć?",
    context: "The exam was a piece of cake.",
    options: [
      "Był smaczny",
      "Był bardzo łatwy",
      "Był niesprawiedliwy",
      "Trwał długo",
    ],
    answer: 1,
    explanation:
      "„A piece of cake” oznacza coś bardzo łatwego. To zwrot potoczny, nie opis jedzenia.",
    translation: "Egzamin był bułką z masłem.",
  },
  {
    level: "B1",
    category: "idiom",
    prompt: "Wybierz naturalne dokończenie dialogu.",
    context: "— Should I tell Anna the surprise? — No, don't let the cat ___.",
    options: ["go home", "out of the bag", "cross the road", "sleep"],
    answer: 1,
    explanation:
      "„Let the cat out of the bag” znaczy przypadkowo zdradzić sekret.",
    translation:
      "— Mam powiedzieć Annie o niespodziance? — Nie, nie zdradzaj sekretu.",
  },
  {
    level: "B2",
    category: "idiom",
    prompt: "Wybierz znaczenie zwrotu w kontekście pracy.",
    context: "Let's get the ball rolling before the client arrives.",
    options: [
      "Zagrajmy",
      "Zacznijmy działać",
      "Odwołajmy spotkanie",
      "Zwolnijmy tempo",
    ],
    answer: 1,
    explanation:
      "„Get the ball rolling” oznacza rozpocząć proces lub działanie. Jest neutralne i częste także w biznesie.",
    translation: "Zacznijmy działać, zanim przyjedzie klient.",
  },
  {
    level: "B2",
    category: "idiom",
    prompt: "Który zwrot oznacza podjęcie trudnego zadania?",
    context: "The report is difficult, but we need to bite the ___.",
    options: ["apple", "bullet", "dust", "word"],
    answer: 1,
    explanation:
      "„Bite the bullet” znaczy zmierzyć się z czymś trudnym lub nieprzyjemnym, czego nie da się uniknąć.",
    translation:
      "Raport jest trudny, ale musimy zacisnąć zęby i się z nim zmierzyć.",
  },
  {
    level: "C1",
    category: "idiom",
    prompt: "Co oznacza wyróżniony zwrot?",
    context: "His apology added fuel to the fire.",
    options: [
      "Rozwiązała problem",
      "Pogorszyła konflikt",
      "Była nieszczera",
      "Zakończyła rozmowę",
    ],
    answer: 1,
    explanation:
      "„Add fuel to the fire” oznacza pogorszyć już napiętą sytuację. Nie mówi dosłownie o ogniu.",
    translation: "Jego przeprosiny tylko pogorszyły konflikt.",
  },
  {
    level: "C1",
    category: "idiom",
    prompt: "Wybierz najlepszą interpretację.",
    context: "The committee moved the goalposts halfway through the review.",
    options: [
      "Zmienił zasady w trakcie",
      "Przyspieszył decyzję",
      "Osiągnął kompromis",
      "Odłożył spotkanie",
    ],
    answer: 0,
    explanation:
      "„Move the goalposts” to niesprawiedliwie zmienić kryteria lub zasady w trakcie działania.",
    translation: "Komisja zmieniła zasady w połowie oceny.",
  },
];

export function starterPractice(kind: PracticeKind, level: string, variant = 0, seen?:GrammarSeen): PracticeSet {
  const selectedGrammar=seen ? selectGrammarItems(productionPool(level),kind==="mixed"?3:6,seen,variant) : productionPool(level);
  const grammar = selectedGrammar.map((item, i): PracticeQuestion => {
    const extra = ({"are running":"is running",visited:"visits",Close:"to close","have known":"has known","was cooking":"were cooking","would travel":"would travels","are cleaned":"is cleaned","had been flying":"has been flying","had left":"has left","has been studying":"have been studying","would have helped":"would helped"} as Record<string,string>)[item.answer];
    const wrong = [...item.distractors.map((d)=>d.form)];
    if (wrong.length < 3) wrong.push(extra || `to ${item.answer}`);
    return {category:"grammar",bankId:item.bankId,scenarioId:item.scenarioId,acceptedAnswers:item.acceptedAnswers,inputHint:item.context.match(/_{2,}\s*\(([^)]*)\)/)?.[1] || item.rule,prompt:`Wybierz formę pasującą do kontekstu. Konstrukcja: ${item.rule}.`,context:item.context.replace(` (${item.hintPl})`, ""),
      options:[item.answer,...wrong.slice(0,3)],answer:0,explanation:item.explanation,translation:item.translation};
  });
  const idioms = idiomPool(level,variant);
  const pick = (pool:PracticeQuestion[], count:number) => Array.from({length:count},(_,i)=> {
    const step = count === pool.length ? Math.max(1,count-1) : count;
    const item = structuredClone(pool[((seen && pool===grammar ? 0 : variant*step)+i)%pool.length]);
    const shift = (variant+i)%4;
    item.options = [...item.options.slice(shift),...item.options.slice(0,shift)];
    item.answer = (4-shift)%4;
    return item;
  });
  const items = kind === "grammar" ? pick(grammar,6) : kind === "idioms" ? pick(idioms,6)
    : pick(grammar,3).flatMap((item,i)=>[item,pick(idioms,3)[i]]);
  if(kind==="mixed") {
    // Two grammar items require retrieval instead of recognizing one of four choices.
    for(const index of [0,4]) {
      items[index].format="input";
      items[index].prompt="Uzupełnij lukę odpowiednią angielską formą. Zwróć uwagę na czas i kontekst.";
    }
  }
  return {id:`bank-v2-${kind}-${level}-${variant}`,title:kind === "grammar" ? "Gramatyka w kontekście" : kind === "idioms" ? "Zwroty i idiomy w kontekście" : "Miks językowy",level,kind,items:items.map(correctedPractice),source:"starter"};
}
