import data from './data/grammar-bank.json';
import type {ProductionItem} from './tutor-types';
import type {State} from './learning';

export type GrammarSeen = Record<string,number>;
export const GRAMMAR_BANK_VERSION=36;
export const grammarLevels=['A1','A2','B1','B2','C1','C2'] as const;
export function authoredGrammar(level:string):ProductionItem[] {
 return (data[level as keyof typeof data] || data.A2) as ProductionItem[];
}
const hash=(value:string)=>{let n=2166136261;for(const c of value)n=Math.imul(n^c.charCodeAt(0),16777619);return n>>>0;};
export function grammarTaskId(item:{bankId?:string;context:string}):string {
 return item.bankId || `legacy-grammar-${hash(item.context)}`;
}
/** Unseen first; distribute structures and settings inside a session. After
 * exhausting a level, repeat least recently displayed tasks, never all at once. */
export function selectGrammarItems(pool:ProductionItem[],count:number,seen:GrammarSeen={},variant=0):ProductionItem[] {
 const candidates=pool.map(item=>({...item,bankId:grammarTaskId(item)}));
 const result:ProductionItem[]=[];
 const recent=Object.entries(seen).sort((a,b)=>b[1]-a[1]).slice(0,12).map(([id])=>id);
 while(result.length<Math.min(count,pool.length)) {
  candidates.sort((a,b)=>{
   const sa=seen[a.bankId!],sb=seen[b.bankId!];
   if(Boolean(sa)!==Boolean(sb)) return sa?1:-1;
   if(sa && sb) return Number(recent.includes(a.bankId!))-Number(recent.includes(b.bankId!)) || sa-sb || hash(a.bankId!+variant)-hash(b.bankId!+variant);
   const penalty=(item:ProductionItem)=>result.filter(x=>x.rule===item.rule).length*2 + result.filter(x=>item.scenarioId && x.scenarioId===item.scenarioId).length*3;
   return penalty(a)-penalty(b) || hash(a.bankId!+variant)-hash(b.bankId!+variant);
  });
  result.push(candidates.shift()!);
 }
 return structuredClone(result);
}
export function markGrammarSeen(state:State,item:{bankId?:string;context:string},at=Date.now()):State {
 return {...state,grammarSeen:{...state.grammarSeen,[grammarTaskId(item)]:at}};
}

/** Reserve the unshown tail of paused sessions across exercise modes. It is
 * not persisted as an exposure: abandoning/replacing that session frees it. */
export function grammarSelectionSeen(state:State):GrammarSeen {
 const seen={...state.grammarSeen};
 const reserved: {bankId?:string;context:string}[]=[];
 if(state.combined && !state.combined.completedAt)
  for(const task of state.combined.tasks.slice(state.combined.index))
   if(task.kind==='question' && task.question.bankId) reserved.push(task.question);
 if(state.production && !state.production.completedAt)
  reserved.push(...state.production.set.items.slice(state.production.index));
 if(state.practice && !state.practice.completedAt)
  reserved.push(...state.practice.set.items.slice(state.practice.index).filter(i=>i.category==='grammar'));
 for(const item of reserved) if(item.bankId) seen[item.bankId]=Math.max(seen[item.bankId] || 0,Date.now());
 return seen;
}
