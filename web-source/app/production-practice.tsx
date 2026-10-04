"use client";
import {ExerciseKind} from "./exercise-kind";
import {productionTarget} from "@/lib/report-corrections";
import { ReportExercise } from "./exercise-reports";
import { ExerciseAudio, type ExerciseVoice } from "./exercise-audio";
import { exerciseAudioText } from "@/lib/exercise-audio";
import { AnswerExplanation } from "./answer-explanation";
import { useEffect, useRef, useState } from "react";
import { ArrowRight, CheckCircle2, LoaderCircle, Pause, PenLine } from "lucide-react";
import { Progress } from "@/components/ui/progress";
import { markGrammarSeen, grammarSelectionSeen } from "@/lib/grammar-bank";
import { productionSetSchema } from "@/lib/tutor-schema";
import { estimatedLevel } from "@/lib/tutor-local";
import { gradeProduction, starterProduction } from "@/lib/production";
import type { State } from "@/lib/learning";
import type { ProductionSet } from "@/lib/tutor-types";

export function ProductionPractice({state,onSave,ai,onExit,speak,prefetch,stop}: {state:State;onSave:(s:State)=>boolean;ai:boolean;onExit:()=>void} & ExerciseVoice) {
  const level = estimatedLevel(state).targetLevel;
  const current = state.production;
  const [answer,setAnswer] = useState("");
  const [busy,setBusy] = useState(false);
  const [error,setError] = useState("");
  const request = useRef<AbortController | null>(null);
  const latest = useRef(state);
  latest.current = state;
  useEffect(() => () => request.current?.abort(), []);
  useEffect(() => setAnswer(current?.answers[current.index] || ""), [current?.id,current?.index]);
  async function generate(offline = !ai) {
    if (busy) return;
    setBusy(true); setError("");
    const controller = new AbortController(); request.current = controller;
    try {
      const variant = state.productionHistory?.length || 0;
      const set=starterProduction(level,variant,6,grammarSelectionSeen(state));
      if (controller.signal.aborted) return;
      onSave({...latest.current,production:{id:crypto.randomUUID(),set,source:"starter",index:0,answers:set.items.map(()=>""),results:set.items.map(()=>null)}});
    } catch (e) { if (!controller.signal.aborted) setError((e as Error).message); }
    finally { if (!controller.signal.aborted) setBusy(false); }
  }
  const correct = current?.results.filter((r) => r?.correct).length || 0;
  const item = current?.set.items[current.index];
  const result = current?.results[current.index];
  const displayed=useRef("");
  useEffect(()=>{
    if (!current || current.completedAt || !item?.bankId) return;
    const key=`${current.id}:${current.index}`;
    if (displayed.current===key) return;
    displayed.current=key;
    onSave(markGrammarSeen(latest.current,item));
  },[current?.id,current?.index,current?.completedAt,item?.bankId]);
  function check() {
    if (!current || !item || !answer.trim() || result) return;
    const answers = [...current.answers]; answers[current.index] = answer;
    const results = [...current.results]; results[current.index] = gradeProduction(answer,item);
    onSave({...state,production:{...current,answers,results}});
  }
  function next() {
    if (!current || !result) return;
    if (current.index + 1 < current.set.items.length)
      onSave({...state,production:{...current,index:current.index+1}});
    else {
      const at = Date.now();
      onSave({...state,production:{...current,completedAt:at},productionHistory:[...(state.productionHistory || []).filter((r)=>r.id!==current.id),{id:current.id,at,level:current.set.level,correct,total:current.set.items.length,title:current.set.title}]});
    }
  }
  return <section className="reading-practice skill-practice">
    <div className="row between wrap">
      <button className="text-link muted" onClick={onExit}><Pause size={17}/> Zrób przerwę</button>
      <span className="badge lavender">Produkcja gramatyczna · {current?.set.level || level}</span>
    </div>
    {!current ? <div className="card practice-intro">
      <div><PenLine size={26}/><h1>Dobierz formę z kontekstu</h1><p>Wpisz angielską formę czasownika. Wskazówek szukaj w zdaniu — w nawiasie znajdziesz tylko polski bezokolicznik.</p><p>{`Ponad 300 zdań na poziomie ${level}. Najpierw zadania, których jeszcze nie widziałeś — bez czekania na AI.`}</p></div>
      <button className="btn primary" disabled={busy} onClick={()=>void generate()}>{busy && <LoaderCircle className="spin" size={17}/>} {busy?"Przygotowuję zadania…":"Rozpocznij"}</button>
    </div> : current.completedAt ? <div className="card reading-result">
      <CheckCircle2 size={32}/><h2>{correct} / {current.set.items.length} poprawnych odpowiedzi</h2><p>Zestaw zapisany w historii. Literówki są zaliczone z zaznaczeniem pisowni.</p>
      <button className="btn primary" disabled={busy} onClick={()=>void generate()}>{busy && <LoaderCircle className="spin" size={17}/>} Następny zestaw</button>
    </div> : item && <section className="card practice-card">
      <div className="row between wrap"><span className="badge gray">{current.source === "ai" ? "AI" : "Bank gramatyki"}</span><b>{current.index+1} / {current.set.items.length}</b></div>
      <Progress value={current.index/current.set.items.length*100} aria-label="Postęp zestawu"/>
      <ExerciseKind kind="Gramatyka" detail="Wpisywanie formy czasownika"/>
      <p className="question-label">Uzupełnij zdanie właściwą formą czasownika · {item.rule}</p>
      <h2 className="practice-context" lang="en">{item.context}</h2>
      <ExerciseAudio text={exerciseAudioText(item.context,!!result,item.answer)} solved={!!result} speak={speak} prefetch={prefetch} stop={stop}/>
      <form className={`answer-form production-answer-form ${result ? result.correct ? "answer-success" : "answer-error" : ""}`} onSubmit={(e)=>{e.preventDefault();check();}}>
        <label className="sr-only" htmlFor="production-answer">Angielska forma czasownika</label>
        <input id="production-answer" key={`${current.id}:${current.index}`} autoFocus value={answer} onChange={(e)=>setAnswer(e.target.value)} disabled={!!result} autoComplete="off" spellCheck={false} maxLength={500} placeholder="Wpisz formę czasownika…"/>
        {!result && <button className="btn primary" disabled={!answer.trim()} type="submit">Sprawdź</button>}
      </form>
      {result && <>
        <ReportExercise snapshot={{mode:"Produkcja gramatyczna",question:item.context,answer:current.answers[current.index],expected:[item.answer,...item.acceptedAnswers],target:productionTarget(item)}}/>
        <div className={`feedback ${result.correct ? "correct" : "wrong"}`} role="status"><div>
          <h3>{result.correct ? result.spellingCorrect ? "Poprawnie" : "Zaliczone — popraw pisownię" : "Niepoprawna odpowiedź"}</h3>
          <AnswerExplanation key={`${current.id}:${current.index}`} correct={result.correct}><p>Poprawna forma: <b lang="en">{item.answer}</b></p><p>Konstrukcja: <b>{item.rule}</b></p>
          <p>{result.explanation}</p><p>{item.translation}</p></AnswerExplanation>
        </div></div>
        <button className="btn primary practice-next" onClick={next}>{current.index+1<current.set.items.length?"Następne zadanie":"Zakończ zestaw"}<ArrowRight size={17}/></button>
      </>}
    </section>}
    {error && <div className="error-banner" role="alert"><span>{error}</span><button className="btn secondary" disabled={busy} onClick={()=>void generate(true)}>Użyj zestawu startowego</button></div>}
  </section>;
}
