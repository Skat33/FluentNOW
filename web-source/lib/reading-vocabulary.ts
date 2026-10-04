import type {Word} from './learning';
export type ReadingToken={text:string;word?:Word};
const escaped=(s:string)=>s.replace(/[.*+?^${}()|[\]\\]/g,'\\$&');
/** Longest exact saved phrase wins. A word never matches inside another word. */
export function readingTokens(text:string,words:Word[]):ReadingToken[] {
 const terms=new Map<string,Word>();
 for(const word of words.filter(w=>!w.archived)) {
  for(const term of [word.en,...word.meanings.flatMap(m=>m.exampleFocusEn || [])]) {
   const normalized=term.trim().toLowerCase();
   if(normalized && normalized.length<=120 && !terms.has(normalized)) terms.set(normalized,word);
  }
 }
 if(!terms.size) return [{text}];
 const regex=new RegExp(`(?<![\\p{L}\\p{N}])(?:${[...terms.keys()].sort((a,b)=>b.length-a.length).map(escaped).join('|')})(?![\\p{L}\\p{N}])`,'giu');
 const result:ReadingToken[]=[];let start=0;
 for(const match of text.matchAll(regex)) {
  if(match.index!>start) result.push({text:text.slice(start,match.index)});
  result.push({text:match[0],word:terms.get(match[0].toLowerCase())});start=match.index!+match[0].length;
 }
 if(start<text.length) result.push({text:text.slice(start)});
 return result;
}
