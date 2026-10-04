import type { Meaning, State } from "./learning";
import type { ExamplePair, Lookup } from "./tutor-types";
export const EXAMPLE_GROUPS = ["affirmative", "negative", "question"] as const;
export type ExampleGroup = typeof EXAMPLE_GROUPS[number];
export function meaningSignature(term:string, meaning:Meaning) {
  return JSON.stringify([term,meaning.translation,meaning.topic || "",meaning.scene || "",meaning.level || ""]);
}
export function appendExampleGroup(meaning:Meaning, group:ExampleGroup, examples:ExamplePair[]):Meaning {
  if (meaning.enrichment?.groups.includes(group)) return meaning;
  const groups = [...(meaning.enrichment?.groups || []),group];
  // Initial two dictionary examples are replaced only when the first bank batch is ready.
  const keep = (meaning.enrichment?.round || 0) > 0 || (meaning.enrichment?.groups.length || 0) > 0;
  const old = keep ? meaning.examples : [];
  const normalized = new Set([...old,...examples.map(e=>e.en)].map(s=>s.trim().toLowerCase()));
  if (examples.length !== 5 || normalized.size !== old.length+5) throw new Error("DUPLICATE_EXAMPLES");
  return {...meaning,examples:[...old,...examples.map(e=>e.en)],
    exampleTranslations:[...(keep ? meaning.exampleTranslations || [] : []),...examples.map(e=>e.pl)],
    exampleFocusEn:[...(keep ? meaning.exampleFocusEn || [] : []),...examples.map(e=>e.focusEn)],
    exampleFocusPl:[...(keep ? meaning.exampleFocusPl || [] : []),...examples.map(e=>e.focusPl)],
    enrichment:{...meaning.enrichment,phase:groups.length === 3 ? meaning.enrichment?.detailsPending ? "details" : "ready" : "examples",detailsPending:meaning.enrichment?.detailsPending,groups,attempts:0,retryAt:0}};
}
export function applyEnrichment(state:State, wordId:string, meaningId:string, signature:string, patch:(m:Meaning)=>Meaning):State {
  return {...state,words:state.words.map(w=>{
    if (w.id !== wordId || w.archived) return w;
    const at=w.meanings.findIndex(m=>m.id===meaningId && meaningSignature(w.en,m)===signature);
    if (at<0) return w;
    const updated=patch(w.meanings[at]);
    if (updated===w.meanings[at]) return w;
    return {...w,updatedAt:Date.now(),meanings:w.meanings.map((m,i)=>i===at ? updated : m)};
  })};
}
export function hydrateMeaning(original:Meaning, lookup:Lookup):Meaning {
  const m=lookup.meanings[0];
  if (!m) throw new Error("EMPTY");
  const complete=original.enrichment?.groups.length === 3;
  return {...original,definition:m.definition,context:m.context,register:m.register,natural:m.natural,
    acceptedAnswers:m.acceptedAnswers,acceptedTranslations:m.acceptedTranslations,level:m.level,levelConfidence:m.levelConfidence,levelReason:m.levelReason,spokenFrequency:m.spokenFrequency,
    examples:complete ? original.examples : m.examples.map(e=>e.en),exampleTranslations:complete ? original.exampleTranslations : m.examples.map(e=>e.pl),exampleFocusEn:complete ? original.exampleFocusEn : m.examples.map(e=>e.focusEn),exampleFocusPl:complete ? original.exampleFocusPl : m.examples.map(e=>e.focusPl),
    enrichment:{...original.enrichment,phase:complete ? "ready" : "examples",detailsPending:false,groups:complete ? original.enrichment!.groups : [],attempts:0,retryAt:0}};
}
