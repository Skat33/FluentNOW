import a1 from './data/readings/A1.json';
import a2 from './data/readings/A2.json';
import b1 from './data/readings/B1.json';
import b2 from './data/readings/B2.json';
import c1 from './data/readings/C1.json';
import c2 from './data/readings/C2.json';
import type {Reading} from './tutor-types';
export const readingBank=[...a1,...a2,...b1,...b2,...c1,...c2] as (Reading & {topic:string})[];
const normalize=(s:string)=>s.toLowerCase().normalize('NFD').replace(/[\u0300-\u036f]/g,'').replace(/ł/g,'l');
export function selectBankReading(level:string,history:number | {id:string;title?:string;at?:number}[]=[],topic=''):Reading {
 const pool=readingBank.filter(r=>r.level===level);
 if(!pool.length) return selectBankReading('A2',history,topic);
 const used=new Map(Array.isArray(history)?history.map((r,i)=>[r.id,r.at || i+1]):[]);
 const titleUsed=new Set(Array.isArray(history)?history.map(r=>r.title).filter(Boolean):[]);
 const keywords=normalize(topic).split(/[^a-z]+/).filter(t=>t.length>3).map(t=>t.replace(/^(restauracj|lotnisk|podroz|lekar|prac).*$/, "$1"));
 const topicScore=(r:typeof pool[number])=>keywords.reduce((n,t)=>n+Number(normalize(r.topic).includes(t)),0);
 const ordered=[...pool].sort((a,b)=>{
   const sa=used.get(a.id) || (titleUsed.has(a.title)?1:0),sb=used.get(b.id) || (titleUsed.has(b.title)?1:0);
   return Number(!!sa)-Number(!!sb) || (sa && sb ? sa-sb : topicScore(b)-topicScore(a));
 });
 const selected=structuredClone(ordered[typeof history==='number'?history%ordered.length:0]);
 // The answer positions also change when a completed bank is revisited.
 const offset=(Array.isArray(history)?history.length:history)%4;
 for(const q of selected.questions) {
  q.options=[...q.options.slice(offset),...q.options.slice(0,offset)];q.answer=(q.answer-offset+4)%4;
 }
 const {topic:_topic,...reading}=selected;return reading;
}
