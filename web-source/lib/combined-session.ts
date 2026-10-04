import {makeSession,recordAnswer,type State,type Task} from './learning';
import {estimatedLevel,starterPractice,starterReading} from './tutor-local';
import {starterProduction} from './production';
import {grammarSelectionSeen,grammarTaskId} from './grammar-bank';
import type {PracticeQuestion,ProductionItem,Reading} from './tutor-types';
export const studyModes=['mixed','mistakes','pairs','reading','grammar','idioms','production','language-mix'] as const;
export type StudyMode=typeof studyModes[number];
export const studyLabels:Record<StudyMode,string>={mixed:'Codzienna mieszanka',mistakes:'Tryb pomyłek',pairs:'Słowa w parach',reading:'Czytanie',grammar:'Gramatyka',idioms:'Idiomy',production:'Produkcja gramatyczna','language-mix':'Miks językowy'};
export type CombinedTask=
 | {kind:'vocabulary';mode:StudyMode;task:Task}
 | {kind:'question';mode:StudyMode;question:PracticeQuestion;level:string;reading?:Reading;readingIndex?:number;production?:ProductionItem};
export type CombinedAnswer={value:string;correct:boolean;seconds:number;hinted:boolean;spellingCorrect:boolean;explanation:string};
export type CombinedSession={id:string;modes:StudyMode[];random:boolean;minutes:number;tasks:CombinedTask[];answers:(CombinedAnswer|null)[];index:number;updatedAt:number;completedAt?:number};

export function orderCombinedTasks(tasks:CombinedTask[],random:boolean,rng= Math.random) {
 if(!random)return tasks;
 const buckets=new Map<StudyMode,CombinedTask[]>();
 for(const t of tasks)buckets.set(t.mode,[...(buckets.get(t.mode)||[]),t]);
 const result:CombinedTask[]=[];
 while(buckets.size){
  const candidates=[...buckets.keys()].filter(m=>m!==result.at(-1)?.mode);
  const choices=candidates.length?candidates:[...buckets.keys()];
  const mode=choices[Math.min(choices.length-1,Math.floor(rng()*choices.length))];
  result.push(buckets.get(mode)!.shift()!);
  if(!buckets.get(mode)!.length)buckets.delete(mode);
 }
 return result;
}
export function makeCombinedSession(state:State,modes:StudyMode[],minutes:number,random:boolean,rng=Math.random):CombinedSession {
 const selected=[...new Set(modes)].filter(m=>studyModes.includes(m));
 const total=Math.max(selected.length,Math.round(minutes/5)*8),level=estimatedLevel(state).targetLevel;
 const tasks:CombinedTask[]=[];
 const seen={...grammarSelectionSeen(state)};
 const readings=[...(state.readingHistory||[])];
 for(const [mi,mode] of selected.entries()) {
  const count=Math.floor(total/selected.length)+Number(mi<total%selected.length);
  if(['mixed','mistakes','pairs'].includes(mode)) {
   const items=makeSession(state,minutes,mode).tasks.slice(0,count);
   tasks.push(...items.map(task=>({kind:'vocabulary' as const,mode,task})));continue;
  }
  let remaining=count,variant=(state.practiceHistory?.length||0)+(state.productionHistory?.length||0);
  while(remaining>0) {
   if(mode==='reading') {
    const reading=starterReading(level,readings);
    if(!reading)break;
    readings.push({id:reading.id,title:reading.title,level,at:Date.now(),correct:0,total:reading.questions.length});
    for(const [i,q] of reading.questions.slice(0,remaining).entries())tasks.push({kind:'question',mode,level,reading,readingIndex:i,question:{category:'grammar',prompt:q.question,context:'',options:q.options,answer:q.answer,explanation:q.explanation+' '+q.evidence,translation:''}});
    remaining-=Math.min(remaining,reading.questions.length);continue;
   }
   if(mode==='production') {
    const set=starterProduction(level,variant++,6,seen);
    for(const item of set.items.slice(0,remaining)) {
     seen[grammarTaskId(item)]=Date.now();
     tasks.push({kind:'question',mode,level,production:item,question:{format:'input',category:'grammar',bankId:item.bankId,scenarioId:item.scenarioId,prompt:'Uzupełnij zdanie właściwą formą czasownika.',context:item.context,inputHint:item.rule,options:[item.answer,...item.distractors.map(d=>d.form)].slice(0,4),answer:0,acceptedAnswers:item.acceptedAnswers,explanation:item.explanation,translation:item.translation}});
    }
    remaining-=Math.min(remaining,set.items.length);continue;
   }
   const set=starterPractice(mode==='language-mix'?'mixed':mode==='idioms'?'idioms':'grammar',level,variant++,seen);
   for(const question of set.items.slice(0,remaining)){
    if(question.bankId)seen[grammarTaskId(question)]=Date.now();
    tasks.push({kind:'question',mode,level,question});
   }
   remaining-=Math.min(remaining,set.items.length);
  }
 }
 const ordered=orderCombinedTasks(tasks,random,rng);
 return {id:crypto.randomUUID(),modes:selected,minutes,random,tasks:ordered,answers:ordered.map(()=>null),index:0,updatedAt:Date.now()};
}
export function saveCombinedAnswer(state:State,answer:CombinedAnswer):State {
 const session=state.combined;
 if(!session || session.completedAt || session.answers[session.index])return state;
 const answers=[...session.answers];answers[session.index]=answer;
 const item=session.tasks[session.index];
 let next=state;
 if(item.kind==='vocabulary') {
  const word=state.words.find(w=>w.id===item.task.wordId),meaning=word?.meanings.find(m=>m.id===item.task.meaningId);
  if(meaning){next=recordAnswer({...state,session:null},item.task,answer.correct,answer.seconds,2,answer.hinted,answer.spellingCorrect);next.session=state.session;}
 }
 return {...next,combined:{...session,answers,updatedAt:Date.now()}};
}
export function advanceCombined(state:State):State {
 const s=state.combined;if(!s || s.completedAt || !s.answers[s.index])return state;
 const index=s.index+1,at=Date.now();
 if(index<s.tasks.length)return {...state,combined:{...s,index,updatedAt:at}};
 let next:State={...state,combined:{...s,index,completedAt:at,updatedAt:at}};
 // Keep the normal history counters and bank-rotation logic working.
 for(const mode of s.modes) {
  const items=s.tasks.map((t,i)=>({t,a:s.answers[i]})).filter(x=>x.t.mode===mode && x.t.kind==='question');
  if(!items.length)continue;
  if(mode==='reading') {
   for(const id of new Set(items.map(x=>x.t.kind==='question'?x.t.reading?.id:undefined))) {
    const subset=items.filter(x=>x.t.kind==='question' && x.t.reading?.id===id);
    const first=subset[0].t;if(first.kind!=='question'||!first.reading)continue;
    next.readingHistory=[...(next.readingHistory||[]),{id:first.reading.id,title:first.reading.title,level:first.level,at,correct:subset.filter(x=>x.a?.correct).length,total:subset.length}];
   }
  } else {
   const first=items[0].t;
   next.practiceHistory=[...(next.practiceHistory||[]),{id:s.id+':'+mode,at,kind:mode==='idioms'?'idioms':mode==='language-mix'?'mixed':'grammar',level:first.kind==='question'?first.level:'A1',correct:items.filter(x=>x.a?.correct).length,total:items.length,title:'Sesja łączona · '+studyLabels[mode]}];
  }
 }
 return next;
}
