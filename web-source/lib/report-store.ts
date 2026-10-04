import {database} from '@/db/store';
import {env} from 'cloudflare:workers';
import {exerciseNames,type State} from "./learning";
import {vocabularyTarget} from "./report-corrections";
import {exerciseReportSchema,type ExerciseReport} from './exercise-reports';
import {correctionKey,validateCorrection,type CorrectionPatch,type SavedCorrection} from './report-corrections';
export const REPORT_INTERVAL=60*60*1000;
export async function reportFile(id:string,payload:unknown|null){
 if(!env.AUDIO)throw new Error('Report file storage unavailable');
 const key=`reports/${id}.json`;
 if(payload===null){await env.AUDIO.delete(key);return;}
 await env.AUDIO.put(key,new TextEncoder().encode(JSON.stringify(payload,null,2)).buffer as ArrayBuffer,{httpMetadata:{contentType:'application/json',cacheControl:'private, no-store'},customMetadata:{kind:'exercise-report'}});
}
export async function submitReport(owner:string,value:unknown,now=Date.now()){
 const report=exerciseReportSchema.parse(value),db=database();
 const prior=await db.prepare('SELECT owner,status,payload FROM exercise_reports WHERE id=?').bind(report.id).first<{owner:string;status:string;payload:string}>();
 if(prior){if(prior.owner!==owner)throw new Error('Report conflict');if(prior.status==='pending')await reportFile(report.id,JSON.parse(prior.payload));return;}
 if(!report.target && report.wordId && report.meaningId){
  const learner=await db.prepare('SELECT content FROM learners WHERE owner=?').bind(owner).first<{content:string}>();
  if(learner){const state=JSON.parse(learner.content) as State;const word=state.words.find(w=>w.id===report.wordId);const meaning=word?.meanings.find(m=>m.id===report.meaningId);const type=report.mode==='Słowa w parach'?2:exerciseNames.indexOf(report.mode);
   if(word && meaning && type>=0 && meaning.examples.includes(report.question))report.target=vocabularyTarget(type===2?report.expected[0]:word.en,meaning.translation,type,report.question,report.expected);
  }
 }
 const count=await db.prepare("SELECT COUNT(*) AS n FROM exercise_reports WHERE owner=? AND status IN ('pending','processing','uncertain')").bind(owner).first<{n:number}>();
 if((count?.n||0)>=1000)throw new Error('Too many pending reports');
 await db.prepare('INSERT INTO exercise_reports(id,owner,payload,status,created,updated) VALUES(?,?,?,\'pending\',?,?)').bind(report.id,owner,JSON.stringify(report),now,now).run();
 await reportFile(report.id,report);
}
export async function ownedReports(owner:string){
 const rows=await database().prepare("SELECT id,payload,status,reason,updated FROM exercise_reports WHERE owner=? AND status NOT IN ('dismissed','discarded') ORDER BY created DESC LIMIT 1000").bind(owner).all<{id:string;payload:string;status:string;reason:string;updated:number}>();
 const fixed=await database().prepare('SELECT payload FROM report_corrections WHERE owner=? ORDER BY updated ASC LIMIT 1000').bind(owner).all<{payload:string}>();
 return {reports:rows.results.map(r=>({...JSON.parse(r.payload),status:r.status,reason:r.reason,updated:r.updated})),corrections:fixed.results.map(r=>JSON.parse(r.payload) as SavedCorrection)};
}
export async function reviewStatus(){
 const db=database();const row=await db.prepare('SELECT started,next_run,lease_until FROM report_runs WHERE id=?').bind('hourly').first();
 const pending=await db.prepare("SELECT COUNT(*) AS count FROM exercise_reports WHERE status IN ('pending','processing')").first();
 return {run:row,pending:pending?.count||0};
}
export async function claimReports(now=Date.now()){
 const db=database(),token=crypto.randomUUID();
 const r=await db.prepare(`INSERT INTO report_runs(id,token,started,lease_until,next_run) VALUES('hourly',?,?,?,?) ON CONFLICT(id) DO UPDATE SET token=excluded.token,started=excluded.started,lease_until=excluded.lease_until,next_run=excluded.next_run WHERE report_runs.next_run<=? AND report_runs.lease_until<=?`).bind(token,now,now+15*60*1000,now+REPORT_INTERVAL,now,now).run();
 if(!r.meta.changes)return {claimed:false,reports:[]};
 // Remove only already-dismissed files; a failure keeps a tombstone for another run.
 const cleanup=await db.prepare("SELECT id FROM exercise_reports WHERE status='dismissed' LIMIT 50").all<{id:string}>();
 for(const row of cleanup.results)try{await reportFile(row.id,null);await db.prepare("UPDATE exercise_reports SET status='discarded' WHERE id=? AND status='dismissed'").bind(row.id).run();}catch{console.warn('Report cleanup will retry');}
 const rows=await db.prepare("SELECT id,payload FROM exercise_reports WHERE status IN ('pending','processing') AND retry_at<=? ORDER BY created LIMIT 10").bind(now).all<{id:string;payload:string}>();
 for(const row of rows.results){await db.prepare("UPDATE exercise_reports SET status='processing',run_token=?,updated=? WHERE id=?").bind(token,now,row.id).run();await reportFile(row.id,JSON.parse(row.payload)).catch(()=>console.warn('Report file refresh will retry'));}
 return {claimed:true,token,reports:rows.results.map(r=>JSON.parse(r.payload) as ExerciseReport),nextRun:now+REPORT_INTERVAL};
}
export async function resolveReport(input:{id:string;token:string;verdict:'confirmed'|'dismissed'|'uncertain';reason:string;patch?:CorrectionPatch;verified:boolean},now=Date.now()){
 const db=database();const row=await db.prepare("SELECT owner,payload FROM exercise_reports WHERE id=? AND run_token=? AND status='processing'").bind(input.id,input.token).first<{owner:string;payload:string}>();
 const lease=await db.prepare("SELECT token,lease_until FROM report_runs WHERE id='hourly'").first<{token:string;lease_until:number}>();
 if(!row || !lease || lease.token!==input.token || lease.lease_until<now)throw new Error('Stale review');
 const report=exerciseReportSchema.parse(JSON.parse(row.payload));
 if(input.verdict==='confirmed'){
  if(!input.verified || !report.target || !input.patch)throw new Error('Verified structured correction required');
  const patch=validateCorrection(report.target,input.patch),key=correctionKey(report.target);
  const fixed:SavedCorrection={key,target:report.target,patch,updated:now};
  // Atomic decision + correction. Keep earlier versions in their original report rows for audit.
  await db.batch([
   db.prepare('DELETE FROM report_corrections WHERE owner=? AND target_key=?').bind(row.owner,key),
   db.prepare('INSERT OR REPLACE INTO report_corrections(id,owner,target_key,payload,updated) VALUES(?,?,?,?,?)').bind(input.id,row.owner,key,JSON.stringify(fixed),now),
   db.prepare("UPDATE exercise_reports SET status='corrected',reason=?,updated=?,run_token=NULL WHERE id=?").bind(input.reason,now,input.id),
  ]);
  await reportFile(input.id,{...report,status:'corrected',reason:input.reason,correction:fixed}).catch(()=>console.warn('Correction retained in database; report file refresh failed'));
 }else{
  if(input.verdict==='dismissed' && !input.verified)throw new Error('Verified dismissal required');
  const dismissed=input.verdict==='dismissed';
  await db.prepare('UPDATE exercise_reports SET status=?,payload=?,reason=?,updated=?,run_token=NULL WHERE id=?').bind(dismissed?'dismissed':'uncertain',dismissed?'{}':row.payload,input.reason,now,input.id).run();
  if(dismissed)await reportFile(input.id,null).catch(()=>console.warn('Dismissed report file cleanup deferred'));
  else await reportFile(input.id,{...report,status:'uncertain',reason:input.reason}).catch(()=>undefined);
 }
 return {ok:true,status:input.verdict};
}
