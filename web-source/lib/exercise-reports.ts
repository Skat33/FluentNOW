import {z} from 'zod';
import {reportTargetSchema} from './report-corrections';
const text=z.string().max(5000);
export const exerciseReportSchema=z.object({
 id:z.string().uuid(),created:z.number(),status:z.literal('local'),
 mode:z.string().max(80),question:text,answer:text,expected:z.array(text).max(100),
 target:reportTargetSchema.optional(),
 comment:z.string().max(2000),wordId:z.string().max(500).optional(),meaningId:z.string().max(500).optional(),
});
export type ExerciseReport=z.infer<typeof exerciseReportSchema>;
export type ReportSnapshot=Pick<ExerciseReport,'mode'|'question'|'answer'|'expected'|'wordId'|'meaningId'|'target'>;
export const reportStorageKey=(scope:string)=>`fluent-exercise-reports-v1:${encodeURIComponent(scope)}`;
export function readExerciseReports(storage:Pick<Storage,'getItem'>,scope:string):ExerciseReport[] {
 const raw=storage.getItem(reportStorageKey(scope));
 if(!raw) return [];
 return z.array(exerciseReportSchema).max(1000).parse(JSON.parse(raw));
}
export function saveExerciseReport(storage:Pick<Storage,'getItem'|'setItem'>,scope:string,snapshot:ReportSnapshot,comment:string,now=Date.now()) {
 const records=readExerciseReports(storage,scope);
 if(records.length>=1000) throw new Error('Lista zawiera 1000 zgłoszeń. Wyeksportuj je i usuń niepotrzebne wpisy przed zapisaniem kolejnego.');
 const report=exerciseReportSchema.parse({...snapshot,comment:comment.trim(),id:crypto.randomUUID(),created:now,status:'local'});
 storage.setItem(reportStorageKey(scope),JSON.stringify([...records,report]));
 return report;
}
