export const SPEECH_GAP = '[[gap]]';
const gaps = /_{2,}|\[\[gap\]\]/g;
/** Render from the answer key, never from the learner's selected/written answer. */
export function exerciseAudioText(context:string, solved:boolean, correctAnswer:string) {
 const clean=context.replace(/_{2,}\s*\([^)]*\)/g,'________');
 return clean.replace(gaps,()=>solved ? correctAnswer : SPEECH_GAP).replace(/\s+/g,' ').trim();
}
export function vocabularyAudioText(example:string,focus:string,hidden:boolean) {
 if(!hidden) return example;
 if(!focus.trim()) return '';
 const escaped=focus.trim().replace(/[.*+?^${}()|[\]\\]/g,"\\$&");
 const pattern=new RegExp(`(^|[^A-Za-z])(${escaped})(?=$|[^A-Za-z])`,"gi");
 // If the exact saved focus cannot be located, stay silent rather than leak it.
 if(!pattern.test(example)) return '';
 pattern.lastIndex=0;
 return example.replace(pattern,(_match,prefix)=>prefix+SPEECH_GAP);
}
