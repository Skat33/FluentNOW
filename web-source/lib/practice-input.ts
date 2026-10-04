import {englishAnswerKey, answerKey, polishAnswers} from './answer-variants';
import type {PracticeQuestion} from './tutor-types';
export function checkPracticeInput(item:PracticeQuestion,value:string) {
 const key=item.category==='grammar'?englishAnswerKey:answerKey;
 const answer=key(value);
 const targets=[item.options[item.answer],...(item.acceptedAnswers || [])];
 // Only use an idiom's reviewed equivalents when its actual wording appears in context.
 const idioms=['get the hang of','break the ice','once in a blue moon','under the weather','a piece of cake'];
 if(item.category==='idiom') for(const term of idioms) if(answerKey(item.context).includes(term)) targets.push(...polishAnswers(term,targets[0]));
 const correct=!!answer && targets.some(a=>key(a)===answer);
 return {correct,choice:correct?item.answer:(item.answer+1)%4};
}
