export type ExamplePair = {
  en: string;
  pl: string;
  focusEn: string;
  focusPl: string;
};
export type SenseSuggestion = {
  needsDetails?: boolean;
  topic?: string;
  scene?: string;
  translation: string;
  definition: string;
  pos: string;
  level: string;
  levelConfidence?: "high" | "medium" | "low";
  levelReason?: string;
  spokenFrequency?: "very_common" | "common" | "less_common" | "rare";
  context: string;
  register: string;
  natural: string;
  collection: string;
  examples: ExamplePair[];
  acceptedTranslations?: string[];
  acceptedAnswers: string[];
};
export type Lookup = {
  exists: boolean;
  term: string;
  ipa: string;
  forms: string;
  collocations: string;
  synonyms: string;
  antonyms: string;
  note: string;
  alternatives: string[];
  meanings: SenseSuggestion[];
  source: "ai" | "starter";
};
export type Grade = {
  verdict: "correct" | "incorrect" | "uncertain";
  explanation: string;
  spellingCorrect: boolean;
  source: "ai" | "local";
};
export type Reading = {
  id: string;
  title: string;
  level: string;
  paragraphs: string[];
  questions: {
    question: string;
    options: string[];
    answer: number;
    explanation: string;
    evidence: string;
    meaningId?: string;
  }[];
  source: "ai" | "starter";
};
export type ReadingSession = {
  reading: Reading;
  answers: number[];
  submitted: boolean;
  completedAt?: number;
};
export type Recommendation = {
  known: string;
  term: string;
  level: string;
  translation: string;
  difference: string;
  example: string;
  examplePl: string;
};
export type TopicListItem = {
  term: string;
  pl: string;
  pos: string;
  level: "A1" | "A2" | "B1" | "B2" | "C1" | "C2";
  spokenFrequency: "very_common" | "common" | "less_common" | "rare";
};
export type TopicSuggestion = {
  topic: string;
  categories: {
    name: string;
    items: TopicListItem[];
  }[];
  cached?: boolean;
  matchSource?: "exact" | "alias" | "fuzzy" | "model" | "miss";
  focusCategory?: string;
  matchedQuery?: string;
};
export type TopicHydration = {
  items: Lookup[];
};
export type ExampleRefresh = {
  examples: ExamplePair[];
};
export type PracticeKind = "grammar" | "idioms" | "mixed";
export type ProductionDiagnosis = "wrong_tense" | "wrong_aspect" | "wrong_voice" | "wrong_agreement" | "wrong_word";
export type ProductionItem = {
  bankId?: string;
  scenarioId?: string;
  context: string;
  hintPl: string;
  answer: string;
  acceptedAnswers: string[];
  distractors: { form: string; diagnosis: ProductionDiagnosis; explanation: string }[];
  rule: string;
  explanation: string;
  translation: string;
};
export type ProductionSet = { title: string; level: string; items: ProductionItem[] };
export type ProductionResult = { correct: boolean; spellingCorrect: boolean; diagnosis: ProductionDiagnosis | "spelling" | "general" | null; explanation: string };
export type ProductionSession = {
  id: string; set: ProductionSet; source: "ai" | "starter";
  index: number; answers: string[]; results: (ProductionResult | null)[]; completedAt?: number;
};
export type PracticeQuestion = {
  format?: "choice" | "input";
  inputHint?: string;
  acceptedAnswers?: string[];
  bankId?: string;
  scenarioId?: string;
  category: "grammar" | "idiom";
  prompt: string;
  context: string;
  options: string[];
  answer: number;
  explanation: string;
  translation: string;
};
export type PracticeSet = {
  id: string;
  title: string;
  level: string;
  kind: PracticeKind;
  items: PracticeQuestion[];
  source: "ai" | "starter";
};
export type PracticeSession = {
  set: PracticeSet;
  writtenAnswers?: string[];
  answers: number[];
  index: number;
  completedAt?: number;
};
