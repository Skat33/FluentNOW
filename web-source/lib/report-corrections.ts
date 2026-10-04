import {z} from 'zod';
import {productionItemSchema,practiceQuestionSchema,productionDiagnosisSchema} from './tutor-schema';
import type {PracticeQuestion,ProductionItem,Reading} from './tutor-types';
const short=z.string().max(500),text=z.string().max(10000);
export const reportTargetSchema=z.object({
 production:productionItemSchema.optional(),practice:practiceQuestionSchema.optional(),
 kind:z.enum(['vocabulary','practice','production','reading']),context:text,prompt:text,
 expected:z.array(short.min(1)).min(1).max(100),options:z.array(text).max(4).optional(),
 term:short.optional(),meaning:short.optional(),taskType:z.number().int().min(0).max(4).optional(),
 translation:text.optional(),explanation:text.optional(),passage:z.string().max(20000).optional(),bankId:short.optional(),
});
export type ReportTarget=z.infer<typeof reportTargetSchema>;
export const correctionPatchSchema=z.object({options:z.array(text.min(1)).length(4).optional(),distractors:z.array(z.object({form:z.string().min(1).max(160),diagnosis:productionDiagnosisSchema,explanation:z.string().min(1).max(400)})).min(2).max(4).optional(),context:text,prompt:text,expected:z.array(short.min(1)).min(1).max(30),translation:text,explanation:text.min(1)});
export type CorrectionPatch=z.infer<typeof correctionPatchSchema>;
export type SavedCorrection={key:string;target:ReportTarget;patch:CorrectionPatch;updated:number};
// Full structured identity avoids hash collisions and keeps senses/task directions separate.
export function correctionKey(t:ReportTarget){return JSON.stringify([t.kind,t.bankId||'',t.context,t.prompt,t.term||'',t.meaning||'',t.taskType??null]);}
let corrections=new Map<string,SavedCorrection>();
export function installCorrections(items:SavedCorrection[]){corrections=new Map(items.map(c=>[c.key,c]));}
export function correctionFor(t:ReportTarget){return corrections.get(correctionKey(t))?.patch;}
export const practiceTarget=(q:PracticeQuestion):ReportTarget=>({kind:'practice',practice:q,context:q.context,prompt:q.prompt,expected:[q.options[q.answer],...(q.acceptedAnswers||[])],options:q.options,translation:q.translation,explanation:q.explanation,bankId:q.bankId});
export const productionTarget=(q:ProductionItem):ReportTarget=>({kind:'production',production:q,context:q.context,prompt:q.rule,expected:[q.answer,...q.acceptedAnswers],translation:q.translation,explanation:q.explanation,bankId:q.bankId});
export const vocabularyTarget=(term:string,meaning:string,taskType:number,context:string,expected:string[]):ReportTarget=>({kind:'vocabulary',context,prompt:'',term,meaning,taskType,expected});
export const readingTarget=(q:Reading['questions'][number],r:Reading):ReportTarget=>({kind:'reading',context:q.question,prompt:'',expected:[q.options[q.answer]],options:q.options,explanation:q.explanation,passage:r.paragraphs.join('\n')});
function choices(options:string[],answer:number,correct:string){const found=options.indexOf(correct);return found<0?{options:options.map((s,i)=>i===answer?correct:s),answer}:{options,answer:found};}
function applyChain<T>(item:T,target:(q:T)=>ReportTarget,apply:(q:T,p:CorrectionPatch)=>T):T {
 const seen=new Set<string>();let next=item;
 for(let i=0;i<5;i++){const t=target(next),key=correctionKey(t);if(seen.has(key))break;seen.add(key);const p=correctionFor(t);if(!p)break;next=apply(next,p);}
 return next;
}
export function correctedPractice(q:PracticeQuestion):PracticeQuestion {return applyChain(q,practiceTarget,(q,p)=>({...q,...choices(p.options || q.options,q.answer,p.expected[0]),context:p.context,prompt:p.prompt,acceptedAnswers:p.expected,translation:p.translation,explanation:p.explanation}));}
export function correctedProduction(q:ProductionItem):ProductionItem {return applyChain(q,productionTarget,(q,p)=>({...q,context:p.context,answer:p.expected[0],acceptedAnswers:p.expected,translation:p.translation,explanation:p.explanation,distractors:p.distractors || q.distractors.filter(d=>!p.expected.includes(d.form))}));}
export function correctedReading(r:Reading):Reading {return {...r,questions:r.questions.map(q=>applyChain(q,q=>readingTarget(q,r),(q,p)=>({...q,...choices(p.options || q.options,q.answer,p.expected[0]),question:p.context,explanation:p.explanation})))};}
// Automated changes are data-only; never evaluate scripts, SQL, URLs or instructions in reports.
export function validateCorrection(target:ReportTarget,patch:CorrectionPatch){
 const p=correctionPatchSchema.parse(patch);
 if(new Set(p.expected.map(s=>s.trim().toLowerCase())).size!==p.expected.length)throw new Error('Duplicate answers');
 if(target.kind==='vocabulary' && p.context!==target.context)throw new Error('Vocabulary sentence edits require editorial review; accept variants only');
 if(target.kind==='production'){
  if(!target.production)throw new Error('Missing original grammar item');
  productionItemSchema.parse({...target.production,context:p.context,answer:p.expected[0],acceptedAnswers:p.expected,translation:p.translation,explanation:p.explanation,distractors:p.distractors || target.production.distractors.filter(d=>!p.expected.includes(d.form))});
 }
 if(target.kind==='practice'){
  if(!target.practice)throw new Error('Missing original practice item');
  const selected=choices(p.options || target.practice.options,target.practice.answer,p.expected[0]);
  practiceQuestionSchema.parse({...target.practice,...selected,context:p.context,prompt:p.prompt,acceptedAnswers:p.expected,translation:p.translation,explanation:p.explanation});
  if(new Set(selected.options).size!==4 || selected.options.filter(o=>p.expected.includes(o)).length!==1)throw new Error('Ambiguous multiple-choice correction');
 }
 if(target.kind==='practice' && /_{2,}/.test(target.context) && !/_{2,}/.test(p.context))throw new Error('Missing gap');
 if(target.kind==='reading' && !target.options?.includes(p.expected[0]))throw new Error('Reading correction must choose an existing option');
 return p;
}
