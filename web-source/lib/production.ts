import {correctedProduction} from "./report-corrections";
import { authoredGrammar, selectGrammarItems, grammarTaskId, type GrammarSeen } from "./grammar-bank";
import { levenshtein } from "./tutor-local";
import { additionalProduction } from "./data/exercise-bank";
import type { ProductionItem, ProductionResult, ProductionSet } from "./tutor-types";

export const productionRules: Record<string, string[]> = {
  A1: ["present simple", "present continuous", "past simple", "to be", "there is/are", "imperative"],
  A2: ["present simple", "present continuous", "past simple", "to be", "there is/are", "imperative"],
  B1: ["present perfect vs past simple", "past continuous", "will vs going to", "first conditional", "second conditional", "simple passive", "reported speech"],
  B2: ["past perfect", "past perfect continuous", "present perfect continuous", "third conditional", "past modals", "gerund vs infinitive"],
  C1: ["mixed conditionals", "inversion", "emphatic structures", "subjunctive", "advanced passive"],
  C2: ["mixed conditionals", "inversion", "emphatic structures", "subjunctive", "advanced passive"],
};

for (const level of Object.keys(productionRules))
  productionRules[level]=[...new Set([...productionRules[level],...authoredGrammar(level).map(item=>item.rule)])];

export function normalizeProduction(value: string, item: ProductionItem) {
  const target = item.answer.toLowerCase();
  const perfect = /perfect/.test(item.rule) || /\b(?:has|have|had)\b/.test(target);
  let text = value.toLowerCase().trim().replace(/[’‘]/g, "'").replace(/[.!?,;:]+$/g, "")
    .replace(/\bwon't\b/g, "will not").replace(/\bcan't\b/g, "cannot").replace(/\bcan not\b/g, "cannot")
    .replace(/\bshan't\b/g, "shall not").replace(/n't\b/g, " not")
    .replace(/'re\b/g, " are").replace(/'ve\b/g, " have").replace(/'ll\b/g, " will")
    .replace(/'m\b/g, " am").replace(/'d\b/g, /\bwould\b/.test(target) ? " would" : /\bhad\b/.test(target) ? " had" : /conditional/.test(item.rule) ? " would" : " had")
    .replace(/'s\b/g, perfect ? " has" : " is").replace(/\s+/g, " ");
  // Answers fill the gap. Accept a repeated subject only when it is the
  // actual subject immediately before that gap (they'd -> had, not she had).
  const subject = item.context.split("________")[0].trim().match(/\b(i|you|he|she|it|we|they)$/i)?.[1].toLowerCase();
  if (subject && text.startsWith(subject + " ")) text = text.slice(subject.length + 1);
  return text;
}

export function gradeProduction(answer: string, item: ProductionItem): ProductionResult {
  const value = normalizeProduction(answer, item);
  const targets = [item.answer, ...item.acceptedAnswers].map((a) => normalizeProduction(a, item));
  if (targets.includes(value)) return {correct:true,spellingCorrect:true,diagnosis:null,explanation:item.explanation};
  // A known grammar error must never be accepted merely because its edit
  // distance is small: is/was and has/had are not interchangeable spellings.
  const wrong = item.distractors.find((d) => normalizeProduction(d.form, item) === value);
  if (wrong) return {correct:false,spellingCorrect:true,diagnosis:wrong.diagnosis,explanation:wrong.explanation};
  const auxiliaries = new Set(["am", "is", "are", "was", "were", "be", "been", "being", "has", "have", "had", "do", "does", "did", "will", "would", "can", "could", "may", "might", "must", "shall", "should"]);
  const grammarTokens = (text: string) => text.split(" ").filter(token => auxiliaries.has(token) || token === "not");
  const grammarChanged = (target: string) => {
    const actual = grammarTokens(value), expected = grammarTokens(target);
    // A different real auxiliary (or changed negation) is grammar, not a typo.
    return actual.some(token => !expected.includes(token)) || expected.includes("not") !== actual.includes("not");
  };
  if (value && targets.some((target) => !grammarChanged(target) && levenshtein(value, target) <= Math.min(2, Math.floor(target.length / 3))))
    return {correct:true,spellingCorrect:false,diagnosis:"spelling",explanation:`Popraw pisownię: „${item.answer}”. ${item.explanation}`};
  return {correct:false,spellingCorrect:true,diagnosis:"general",explanation:item.explanation};
}

const item = (context:string,hintPl:string,answer:string,rule:string,explanation:string,translation:string,wrong:[string,string,string,string]): ProductionItem => ({
  context,hintPl,answer,rule,explanation,translation,acceptedAnswers:[],
  distractors:[{form:wrong[0],diagnosis:"wrong_tense",explanation:wrong[1]},{form:wrong[2],diagnosis:"wrong_aspect",explanation:wrong[3]}],
});
const starters: Record<string, ProductionItem[]> = {
  A2: [
    item("Look! The children ________ (biegać) around the garden right now.","biegać","are running","present continuous","Look i right now wskazują czynność trwającą teraz. Present simple opisywałby zwyczaj.","Spójrz! Dzieci właśnie biegają po ogrodzie.",["ran","Ran opisuje zakończoną przeszłość, a right now oznacza teraz.","run","Run opisuje zwyczaj; tutaj dzieci biegają w chwili mówienia."]),
    item("Last Saturday, we ________ (odwiedzić) our grandparents.","odwiedzić","visited","past simple","Last Saturday wyznacza zakończony moment w przeszłości. Present perfect nie łączy się tu z konkretną zakończoną datą.","W zeszłą sobotę odwiedziliśmy dziadków.",["visit","Visit jest formą teraźniejszą, a last Saturday wskazuje przeszłość.","have visited","Present perfect nie pasuje do zakończonego czasu last Saturday."]),
    item("On school days, she usually ________ (jechać) to school by bus.","jechać","goes","present simple","Usually opisuje zwyczaj. W trzeciej osobie liczby pojedynczej dodajemy -es do go.","W dni szkolne ona zwykle jeździ do szkoły autobusem.",["went","Went dotyczy przeszłości, a zdanie opisuje obecny zwyczaj.","is going","Is going opisuje bieżącą lub tymczasową czynność, nie wskazany tutaj zwyczaj."]),
    item("________ (zamknąć) the door, please.","zamknąć","Close","imperative","Prośbę kierujemy bezpośrednio do rozmówcy, używając podstawowej formy czasownika bez podmiotu.","Zamknij drzwi, proszę.",["Closed","Closed jest formą przeszłą, nie poleceniem.","Closing","Closing nie tworzy tutaj pełnego polecenia; potrzebna jest forma podstawowa."]),
  ],
  B1: [
    item("I ________ (znać) Maya since we were children, and we are still friends.","znać","have known","present perfect vs past simple","Since wyznacza początek stanu trwającego do teraz. Knew sugerowałoby zamkniętą przeszłość.","Znam Mayę od dzieciństwa i nadal jesteśmy przyjaciółmi.",["knew","Knew nie wyraża stanu trwającego od dzieciństwa aż do teraz.","have been knowing","Know w znaczeniu znać to czasownik stanu; nie używamy tu formy ciągłej."]),
    item("At eight yesterday, I ________ (gotować) dinner when the lights suddenly went out.","gotować","was cooking","past continuous","Gotowanie trwało, gdy przerwało je nagłe zdarzenie. Past simple przedstawiałby czynność jako całość.","Wczoraj o ósmej gotowałem kolację, gdy nagle zgasło światło.",["am cooking","Am cooking dotyczy teraźniejszości, a yesterday umieszcza scenę w przeszłości.","cooked","Cooked nie pokazuje tła czynności trwającej w chwili zgaśnięcia światła."]),
    item("If I had more free time now, I ________ (podróżować) more.","podróżować","would travel","second conditional","Had i now opisują nierealną sytuację obecną. W jej skutku stosujemy would i bezokolicznik.","Gdybym miał teraz więcej wolnego czasu, więcej bym podróżował.",["will travel","Will pasuje do realnego przyszłego warunku, a tutaj warunek jest hipotetyczny.","would have travelled","Would have travelled opisuje niezrealizowany skutek w przeszłości, nie teraz."]),
    item("These rooms ________ (sprzątać) every morning by the hotel staff.","sprzątać","are cleaned","simple passive","Pokoje są odbiorcą czynności. Every morning wskazuje regularność, więc stosujemy are i imiesłów cleaned.","Te pokoje są sprzątane każdego ranka przez personel hotelu.",["were cleaned","Were cleaned dotyczy przeszłości; zdanie opisuje obecną rutynę.","are cleaning","Are cleaning jest stroną czynną: sugeruje, że pokoje same sprzątają."]),
  ],
  B2: [
    item("They ________ (latać) continuously for three hours when the storm hit.","latać","had been flying","past perfect continuous","Lot trwał przez trzy godziny przed innym zdarzeniem przeszłym. Had flown podkreślałoby wynik, a tu continuously eksponuje trwanie.","Lecieli nieprzerwanie od trzech godzin, gdy rozpętała się burza.",["have been flying","Have been flying odnosi trwanie do teraz, a punktem odniesienia jest przeszłe hit.","flew","Flew nie pokazuje trwania lotu przed następnym zdarzeniem w przeszłości."]),
    item("By the time we arrived, all the guests ________ (wyjść), so the house was already empty.","wyjść","had left","past perfect","Goście wyszli przed naszym przybyciem. Past perfect jasno ustala kolejność dwóch zdarzeń przeszłych.","Zanim przyjechaliśmy, wszyscy goście już wyszli, więc dom był pusty.",["have left","Have left wiąże wynik z teraz, a przyjazd jest punktem odniesienia w przeszłości.","were leaving","Were leaving sugeruje trwające wychodzenie; dom był już pusty."]),
    item("She ________ (uczyć się) English for two hours now and is still working.","uczyć się","has been studying","present perfect continuous","For two hours now i still working wskazują trwanie od przeszłości do chwili obecnej. Past perfect wymagałby przeszłego punktu odniesienia.","Uczy się angielskiego już od dwóch godzin i nadal pracuje.",["had been studying","Had been studying odnosi trwanie do przeszłości; tutaj punktem końcowym jest teraz.","studies","Studies opisuje zwyczaj, nie czas trwania bieżącej nauki."]),
    item("If you had called me yesterday, I ________ (pomóc) you then.","pomóc","would have helped","third conditional","Had called opisuje niespełniony warunek przeszły. Skutek wyrażamy would have i imiesłowem helped.","Gdybyś zadzwonił do mnie wczoraj, wtedy bym ci pomógł.",["would help","Would help dotyczy hipotetycznego skutku obecnego lub przyszłego, a then wskazuje przeszłość.","will have helped","Will have helped oznacza przyszły dokonany skutek, nie nierealną przeszłość."]),
  ],
};
starters.A2[2].distractors.push({form:"go",diagnosis:"wrong_agreement",explanation:"Podmiot she wymaga końcówki -es: goes. Go pasuje do I, you, we lub they."});
starters.B1[3].distractors[1].diagnosis = "wrong_voice";
export function productionPool(level: string): ProductionItem[] {
  const actual = productionRules[level] ? level : "A2";
  const pool = [...(starters[actual] || []), ...additionalProduction(actual)];
  return structuredClone([...pool.map(item=>({...item,bankId:grammarTaskId(item)})),...authoredGrammar(actual)].map(correctedProduction));
}
export function starterProduction(level: string, variant = 0, count = 4, seen?:GrammarSeen): ProductionSet {
  const actual = productionRules[level] ? level : "A2";
  const pool = productionPool(actual);
  const start = (Math.max(0,variant) * count) % pool.length;
  return {title:`Dobierz formę z kontekstu · ${actual} · zestaw ${Math.floor(start/count)+1}`,level:actual,
    items:seen ? selectGrammarItems(pool,count,seen,variant) : Array.from({length:Math.min(count,pool.length)},(_,i)=>pool[(start+i)%pool.length])};
}
