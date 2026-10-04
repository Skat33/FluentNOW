"use client";
import {ExerciseKind} from "./exercise-kind";
import {practiceTarget,productionTarget,vocabularyTarget,readingTarget} from "@/lib/report-corrections";
import {useEffect,useRef,useState} from 'react';
import {ArrowRight,CheckCircle2,Pause,Volume2} from 'lucide-react';
import {Progress} from '@/components/ui/progress';
import {advanceCombined,saveCombinedAnswer,studyLabels,type CombinedTask} from '@/lib/combined-session';
import {examplePair,localGrade,vocabularyAnswers} from '@/lib/tutor-local';
import {clozeSpan,clozeText,type State} from '@/lib/learning';
import {markGrammarSeen} from '@/lib/grammar-bank';
import {checkPracticeInput} from '@/lib/practice-input';
import {gradeProduction} from '@/lib/production';
import {exerciseAudioText,vocabularyAudioText} from '@/lib/exercise-audio';
import {ExerciseAudio,type ExerciseVoice} from './exercise-audio';
import {HintDisclosure} from './hint-disclosure';
import {ReadingVocabulary} from './reading-vocabulary';
import {AnswerExplanation} from './answer-explanation';
import {ReportExercise} from './exercise-reports';
import {Highlight,SentenceTranslation} from './tutor-ui';
import {useAnswerScroll} from './use-answer-scroll';

export function CombinedPractice({state,onSave,onExit,...voice}:{state:State;onSave:(s:State)=>boolean;onExit:()=>void}&ExerciseVoice) {
 const s=state.combined;if(!s)return null;
 const answered=s.answers.filter(Boolean),correct=answered.filter(a=>a?.correct).length;
 return <section className="reading-practice combined-practice">
  <div className="row between wrap"><button className="text-link muted" onClick={onExit}><Pause size={17}/>Wyjdź z ćwiczeń</button><span className="badge lavender">Sesja łączona · {s.random?'Kolejność losowa':'Według rodzaju'}</span></div>
  {s.completedAt ? <div className="card reading-result"><CheckCircle2 size={32}/><h1>Sesja ukończona</h1><p>{correct} / {s.tasks.length} poprawnych odpowiedzi</p><p>Odpowiedzi i postęp zostały zapisane.</p><button className="btn primary" onClick={onExit}>Wróć do wyboru ćwiczeń</button></div> : <>
   <div className="session-progress"><span>{studyLabels[s.tasks[s.index].mode]}</span><b>{s.index+1} / {s.tasks.length}</b><Progress value={s.index/s.tasks.length*100} aria-label="Postęp sesji łączonej"/></div>
   <CombinedQuestion key={`${s.id}:${s.index}`} state={state} onSave={onSave} task={s.tasks[s.index]} {...voice}/>
  </>}
 </section>;
}
function CombinedQuestion({state,onSave,task,speak,prefetch,stop}:{state:State;onSave:(s:State)=>boolean;task:CombinedTask}&ExerciseVoice) {
 const s=state.combined!,result=s.answers[s.index];
 const [value,setValue]=useState(result?.value||''),[revealed,setRevealed]=useState(false),[hinted,setHinted]=useState(false);
 const started=useRef(Date.now()),marked=useRef(false);
 const reviewRef=useAnswerScroll(!!result);
 const latest=useRef({state,onSave});latest.current={state,onSave};
 useEffect(()=>{
  if(!marked.current && task.kind==='question' && task.question.bankId){marked.current=true;latest.current.onSave(markGrammarSeen(latest.current.state,task.question));}
 },[task]);
 const word=task.kind==='vocabulary'?state.words.find(w=>w.id===task.task.wordId):undefined;
 const meaning=task.kind==='vocabulary'?word?.meanings.find(m=>m.id===task.task.meaningId):undefined;
 const vocab=task.kind==='vocabulary'?task.task:null;
 const question=task.kind==='question'?task.question:null;
 const example=meaning && vocab?meaning.examples[vocab.example]||'':'';
 const pair=word && meaning && vocab?examplePair(word,meaning,vocab.example):null;
 const focus=word?(clozeSpan(example,pair?.focusEn||word.en)?.match || word.en):'';
 const targetWord=word && vocab?.type===2?{...word,en:focus}:word;
 const expected=question?[question.options[question.answer],...(question.acceptedAnswers||[])]:word && meaning && vocab?vocabularyAnswers(targetWord!,meaning,vocab.type,example):[];
 const text=question?exerciseAudioText(question.context,!!result,expected[0]):word?vocabularyAudioText(example,focus,!result && !revealed && [1,2,4].includes(vocab!.type)):'';
 const prompt=question?.prompt || (vocab?.type===0?'Fiszka w kontekście':vocab?.type===1?'Jak powiesz to po angielsku?':vocab?.type===2?'Uzupełnij zdanie właściwym słowem.':vocab?.type===3?'Co oznacza wyróżnione słowo?':'Posłuchaj i zapisz słowo.');
 function submit(answer=value,flashCorrect?:boolean) {
  if(result || (!answer.trim() && flashCorrect===undefined))return;
  let correct=false,spellingCorrect=true,explanation='';
  if(question) {
   if(task.kind==='question' && task.production){const g=gradeProduction(answer,task.production);correct=g.correct;spellingCorrect=g.spellingCorrect;explanation=g.explanation;}
   else {correct=question.format==='input'?checkPracticeInput(question,answer).correct:answer===String(question.answer);explanation=question.explanation;}
  } else if(word && meaning && vocab) {
   const g=localGrade(answer,targetWord!,meaning,vocab.type,example);correct=flashCorrect??(g.verdict==='correct');spellingCorrect=flashCorrect??g.spellingCorrect;explanation=g.explanation;
  }
  onSave(saveCombinedAnswer(latest.current.state,{value:answer,correct,seconds:Math.max(.1,(Date.now()-started.current)/1000),hinted,spellingCorrect,explanation}));
 }
 if(task.kind==='vocabulary' && (!word||!meaning))return <div className="card padded"><p>To słowo nie jest już dostępne. Wróć do wyboru ćwiczeń i rozpocznij nową sesję.</p></div>;
 return <>
  {task.kind==='question' && task.reading && <article className="card reading-text"><span className="badge gray">{task.level} · Czytanie</span><h2>{task.reading.title}</h2>{task.reading.paragraphs.map((p,i)=><p lang="en" key={i}><ReadingVocabulary text={p} words={state.words}/></p>)}<ExerciseAudio text={task.reading.paragraphs.join('\n')} solved={false} speak={speak} prefetch={prefetch} stop={stop}/></article>}
  <section className="card practice-card">
   <ExerciseKind kind={task.kind==='vocabulary'?(task.task.type===4?'Słuchanie':'Słownictwo'):task.reading?'Czytanie':task.question.category==='idiom'?'Idiomy':'Gramatyka'} detail={task.kind==='vocabulary'?['Fiszka','Tłumaczenie na angielski','Uzupełnianie zdania','Rozpoznawanie znaczenia','Dyktando'][task.task.type]:task.question.format==='input'?'Wpisz odpowiedź':'Wybierz odpowiedź'}/>
   <h2>{prompt}</h2>
   {question?.context && <div className="practice-context"><p lang="en">{question.context}</p></div>}
   {word && meaning && vocab && <>
    {vocab.type===0 && <><h2 lang="en">{word.en}</h2><p className="example" lang="en"><Highlight text={example} focus={focus}/></p>{revealed||result?<div className="revealed"><SentenceTranslation pair={pair}/><p><b>{word.en}</b> — {meaning.translation}</p></div>:<button className="btn secondary" onClick={()=>setRevealed(true)}>Odsłoń znaczenie</button>}</>}
    {vocab.type===1 && <><h2>{meaning.translation}</h2><SentenceTranslation pair={pair}/></>}
    {vocab.type===2 && <><p className="practice-context" lang="en">{clozeText(example,focus)?.replace('________',task.mode==='pairs'?`________ (${meaning.translation})`:'________')}</p>{task.mode!=='pairs'&&<SentenceTranslation pair={pair}/>}</>}
    {vocab.type===3 && <p className="example" lang="en"><Highlight text={example} focus={focus}/></p>}
    {vocab.type===4 && !result && <button className="btn secondary" onClick={()=>speak(word.en,undefined,'exercise')}><Volume2 size={18}/>Posłuchaj słowa</button>}
   </>}
   {text && <ExerciseAudio text={text} solved={!!result||revealed} speak={speak} prefetch={prefetch} stop={stop}/>}
   {question && question.format!=='input' ? <div className="answer-options">{question.options.map((o,i)=><button key={i} disabled={!!result} className={result?(i===question.answer?'answer-correct':result.value===String(i)?'answer-wrong':''):''} onClick={()=>submit(String(i))}><span>{'ABCD'[i]}</span>{o}</button>)}</div>
    : vocab?.type===0 ? (!result && revealed && <div className="exercise-actions"><button className="btn secondary" onClick={()=>submit('Jeszcze nie pamiętam',false)}>Jeszcze nie pamiętam</button><button className="btn primary" onClick={()=>submit('Pamiętam',true)}>Pamiętam</button></div>)
    : <form className="answer-form production-answer-form" onSubmit={e=>{e.preventDefault();submit();}}>
      <HintDisclosure text={question?.inputHint || (word?`Zaczyna się od „${(vocab?.type===3?meaning?.translation:focus)?.slice(0,2)}…”.`:'Dobierz formę do kontekstu.')} onReveal={()=>setHinted(true)}/>
      <label className="sr-only" htmlFor="combined-answer">Twoja odpowiedź</label><input id="combined-answer" value={value} disabled={!!result} onChange={e=>setValue(e.target.value)} maxLength={500} autoComplete="off" spellCheck={false} placeholder="Wpisz odpowiedź…"/>{!result&&<button className="btn primary" disabled={!value.trim()} type="submit">Sprawdź</button>}
     </form>}
   {result && <>
    <div ref={reviewRef} className={'feedback '+(result.correct?'correct':'wrong')} role="status"><div><h3>{result.correct?'Poprawna odpowiedź':'Niepoprawna odpowiedź'}</h3><p>Poprawna odpowiedź: <b>{expected[0]}</b></p><AnswerExplanation correct={result.correct}><p>{result.explanation}</p>{question?<p>{question.translation}</p>:<SentenceTranslation pair={pair}/>}</AnswerExplanation></div></div>
    <ReportExercise snapshot={{mode:studyLabels[task.mode],question:question?question.prompt+'\n'+question.context:example,answer:question?.format!=='input' && question?question.options[Number(result.value)]:result.value,expected,wordId:word?.id,meaningId:meaning?.id,target:task.kind==='question'?(task.production?productionTarget(task.production):task.reading?readingTarget(task.reading.questions[task.readingIndex!],task.reading):practiceTarget(task.question)):vocabularyTarget(targetWord!.en,meaning!.translation,vocab!.type,example,expected)}}/>
    <button className="btn primary practice-next" onClick={()=>{stop?.();if(onSave(advanceCombined(latest.current.state)))window.scrollTo({top:0,behavior:'auto'});}}>{s.index+1<s.tasks.length?'Następne zadanie':'Zakończ sesję'}<ArrowRight size={18}/></button>
   </>}
  </section>
 </>;
}
