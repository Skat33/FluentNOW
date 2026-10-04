import {z} from 'zod';
import {practiceQuestionSchema,productionItemSchema,readingSchema} from './tutor-schema';
const mode=z.enum(['mixed','mistakes','pairs','reading','grammar','idioms','production','language-mix']);
const task=z.discriminatedUnion('kind',[
 z.object({kind:z.literal('vocabulary'),mode,task:z.object({wordId:z.string().max(500),meaningId:z.string().max(500),type:z.number().int().min(0).max(4),example:z.number().int().min(0).max(89)})}),
 z.object({kind:z.literal('question'),mode,question:practiceQuestionSchema.extend({context:z.string().max(10000),translation:z.string().max(10000),options:z.array(z.string().max(10000)).min(1).max(4)}),level:z.string().max(10),reading:readingSchema.and(z.object({id:z.string().max(500),source:z.enum(['starter','ai'])})).optional(),readingIndex:z.number().int().min(0).max(5).optional(),production:productionItemSchema.optional()}),
]);
export const combinedSessionSchema=z.object({id:z.string().max(500),modes:z.array(mode).min(1).max(8),random:z.boolean(),minutes:z.number().int().min(5).max(15),tasks:z.array(task).min(1).max(100),answers:z.array(z.object({value:z.string().max(500),correct:z.boolean(),seconds:z.number().min(0),hinted:z.boolean(),spellingCorrect:z.boolean(),explanation:z.string().max(10000)}).nullable()).max(100),index:z.number().int().min(0),updatedAt:z.number(),completedAt:z.number().optional()}).superRefine((s,c)=>{
 if(s.answers.length!==s.tasks.length || s.index>s.tasks.length || (!!s.completedAt !== (s.index===s.tasks.length)) || s.answers.slice(0,s.index).some(a=>!a))c.addIssue({code:'custom',message:'Invalid combined session progress'});
 if(new Set(s.modes).size!==s.modes.length || s.tasks.some(t=>!s.modes.includes(t.mode)))c.addIssue({code:'custom',message:'Invalid combined session modes'});
 for(const t of s.tasks)if(t.kind==='question' && !t.production && t.question.options.length!==4)c.addIssue({code:'custom',message:'Four options required'});
 for(const t of s.tasks)if(t.kind==='question' && t.mode==='reading' && (!t.reading || t.readingIndex===undefined || t.readingIndex>=t.reading.questions.length))c.addIssue({code:'custom',message:'Missing reading context'});
});
