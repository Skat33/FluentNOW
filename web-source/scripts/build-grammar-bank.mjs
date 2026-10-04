import {writeFileSync} from 'node:fs';
import {frames} from './content/grammar-frames.mjs';
import {patterns} from './content/grammar-patterns.mjs';
const levels=['A1','A2','B1','B2','C1','C2'];
const bank={};
for (const level of levels) {
 const events=frames[['B2','C1','C2'].includes(level)?'advanced':'simple'];
 bank[level]=[];
 for(let pattern=0;pattern<15;pattern++) for(let i=0;i<20;i++) {
  const f=events[i], r=patterns(level,f)[pattern];
  // Higher levels require the complete operator/tense construction, not only
  // a participle following a visible auxiliary. Inversion includes the subject.
  if(['B1','B2','C1','C2'].includes(level)) {
   const prefixes=['are understood to have been','are alleged to have','are believed to have','must have been','would now be','would have','would be','will have','will be','had been','have been','had already','have already','had we','did we','would rather','had better','ought to have'];
   for(const prefix of prefixes) {
    const before=prefix+' ________';
    if(!r.context.includes(before)) continue;
    r.context=r.context.replace(before,'________');
    r.answer=prefix+' '+r.answer;
    if(prefix==='did we') r.wrong=[`we did ${f.base}`,`have we ${f.pp}`,`we are ${f.ing}`];
    else if(prefix==='had we') r.wrong=[`we had ${f.pp}`,`have we ${f.pp}`,`were we ${f.ing}`];
    else if(prefix.includes('believed') || prefix.includes('alleged')) r.wrong=[`are ${prefix.includes('believed')?'believed':'alleged'} have ${f.pp}`,`are ${prefix.includes('believed')?'believed':'alleged'} to having ${f.pp}`,`are ${prefix.includes('believed')?'believed':'alleged'} to had ${f.pp}`];
    else if(prefix==='are understood to have been') r.wrong=[`are understood to be ${f.ing}`,`were understanding ${f.obj ? 'how to ' : ''}${f.base}`,`are understood to have being ${f.ing}`];
    else if(prefix==='ought to have') r.wrong=[`ought have ${f.pp}`,`ought to had ${f.pp}`,`ought to having ${f.pp}`];
    else r.wrong=[`${prefix} to ${f.base}`,`${prefix} ${f.s}`,`${prefix} be ${f.base}`];
    break;
   }
  }
  const acceptedAnswers=[];
  if(r.rule==='like gerund' || r.rule==='emphatic structures' || r.rule==='emphatic structures restriction') acceptedAnswers.push(`to ${f.base}`);
  if(r.rule==='subjunctive' || r.rule==='lest subjunctive') acceptedAnswers.push(`should ${f.base}`);
  if(r.rule==='gerund vs infinitive' || r.rule==='gerund after deny') acceptedAnswers.push(`having ${f.pp}`);
  const options=[r.answer,...r.wrong];
  if(new Set(options.map(s=>s.toLowerCase())).size!==4) throw Error(`duplicate options ${level} ${pattern} ${i}`);
  bank[level].push({bankId:`grammar-36-${level}-${String(pattern).padStart(2,'0')}-${String(i).padStart(2,'0')}`,scenarioId:`${level}-${i}`,context:r.context,hintPl:r.hint,answer:r.answer,rule:r.rule,translation:r.translation,explanation:r.explanation,acceptedAnswers,
   distractors:r.wrong.map(form=>({form,diagnosis:'wrong_word',explanation:`„${form}” nie spełnia wskazanej konstrukcji (${r.rule}). ${r.explanation}`}))});
 }
 const contexts=new Set(bank[level].map(i=>i.context));
 if(bank[level].length!==300 || contexts.size!==300) throw Error(`Invalid count: ${level}`);
}
writeFileSync('lib/data/grammar-bank.json',JSON.stringify(bank,null,2)+'\n');
console.log(Object.fromEntries(levels.map(level=>[level,bank[level].length])));
