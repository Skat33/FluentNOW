"use client";
import { useEffect, useRef } from "react";
import { toast } from "sonner";
import { availableExampleCount, beginExampleExpansion, needsExampleExpansion } from "@/lib/example-pool";
import { postTutorJson } from "@/lib/gemini-client";
import { exampleBatchSchema, topicHydrateSchema } from "@/lib/tutor-schema";
import { EXAMPLE_GROUPS, appendExampleGroup, applyEnrichment, hydrateMeaning, meaningSignature } from "@/lib/meaning-enrichment";
import type { State } from "@/lib/learning";
import type { Lookup } from "@/lib/tutor-types";

export function VocabularyPreparation({state,onSave,enabled}:{state:State;onSave:(s:State)=>boolean;enabled:boolean}) {
  const latest=useRef({state,onSave,enabled}); latest.current={state,onSave,enabled};
  const notified=useRef(false);
  const globalRetry=useRef(0);
  const inFlight=useRef(false);
  useEffect(()=>{
    const controller=new AbortController();
    let timer:ReturnType<typeof setTimeout>;
    const run=async()=>{
      if (controller.signal.aborted) return;
      const {state:s,enabled:online}=latest.current;
      const candidate=s.words.filter(w=>!w.archived).flatMap(w=>w.meanings.map(m=>({w,m})))
        .filter(({m})=>m.enrichment && (m.enrichment.phase !== "ready" || needsExampleExpansion(m)) && m.enrichment.retryAt <= Date.now() && (availableExampleCount(m)>0 || !s.session?.tasks.slice(s.session.index).some(t=>t.meaningId===m.id)))
        .sort((a,b)=>(availableExampleCount(a.m)-availableExampleCount(b.m) || b.m.enrichment!.groups.length-a.m.enrichment!.groups.length))[0];
      if (online && !inFlight.current && navigator.onLine !== false && globalRetry.current <= Date.now() && candidate) {
        const {w}=candidate;
        const m=beginExampleExpansion(candidate.m), signature=meaningSignature(w.en,m);
        if (m !== candidate.m && !latest.current.onSave(applyEnrichment(latest.current.state,w.id,m.id,signature,()=>m))) {
          timer=setTimeout(run,1200); return;
        }
        inFlight.current=true;
        try {
          let patch;
          let metadata:Lookup | undefined;
          if (m.enrichment!.phase === "details") {
            const raw=await postTutorJson({action:"topicHydrate",fast:true,topic:m.topic || w.collection,scene:m.scene || m.context || `Everyday use of ${w.en}`,terms:[{term:w.en,pl:m.translation}]},controller.signal,{attempts:1,timeoutMs:26000});
            const result=topicHydrateSchema.parse(raw).items[0];
            if (result.term !== w.en) throw new Error("TERM");
            metadata=result as Lookup;
            patch=(current:typeof m)=>hydrateMeaning(current,result as Lookup);
          } else {
            const kind=EXAMPLE_GROUPS.find(group=>!m.enrichment!.groups.includes(group))!;
            const raw=await postTutorJson({action:"meaningExamples",term:w.en,translation:m.translation,level:m.level || w.level,topic:m.topic,scene:m.scene,kind,round:m.enrichment!.round || 0,avoid:(m.enrichment!.round || m.enrichment!.groups.length) ? m.examples : []},controller.signal,{attempts:1,timeoutMs:26000});
            if ((raw as {pending?:boolean})?.pending) {
              globalRetry.current=Date.now()+5000;
              return; // Another tab/user holds the generation lease. No failure notification.
            }
            const result=exampleBatchSchema.parse(raw);
            patch=(current:typeof m)=>(current.enrichment?.round || 0)===(m.enrichment!.round || 0) ? appendExampleGroup(current,kind,result.examples) : current;
          }
          if (!controller.signal.aborted) {
            const live=latest.current;
            let applied=false;
            let next=applyEnrichment(live.state,w.id,m.id,signature,meaning=>{applied=true;return patch(meaning);});
            if (metadata && applied) next={...next,words:next.words.map(word=>word.id === w.id && word.en === w.en && word.meanings.some(meaning=>meaning.id===m.id) ? {...word,ipa:word.ipa || metadata!.ipa,forms:word.forms || metadata!.forms,collocations:word.collocations || metadata!.collocations,synonyms:word.synonyms || metadata!.synonyms,antonyms:word.antonyms || metadata!.antonyms} : word)};
            if (live.onSave(next)) { notified.current=false; toast.dismiss("example-preparation-failure"); }
          }
        } catch (error) {
          if (!controller.signal.aborted) {
            const live=latest.current;
            // One bounded attempt, then an explicit break; partial work is already saved.
            const dailyLimit=error instanceof Error && /dzienn.*limit|limit.*dziś|limit 200/i.test(error.message);
            const retryAt=dailyLimit ? new Date().setUTCHours(24,1,0,0) : Date.now()+60000;
            globalRetry.current=retryAt;
            if (!notified.current) {
              notified.current=true;
              toast.error("Nie udało się zaktualizować zadań. Słowa i gotowe ćwiczenia są zapisane.", {
                id:"example-preparation-failure",duration:12000,
                action:{label:"Ponów",onClick:()=>{
                  const live=latest.current;
                  globalRetry.current=0; notified.current=false;
                  live.onSave({...live.state,words:live.state.words.map(word=>({...word,meanings:word.meanings.map(meaning=>meaning.enrichment ? {...meaning,enrichment:{...meaning.enrichment,retryAt:0,error:undefined}} : meaning)}))});
                }}
              });
            }
            live.onSave(applyEnrichment(live.state,w.id,m.id,signature,current=>({...current,enrichment:{...current.enrichment!,attempts:Math.min(1000,(current.enrichment?.attempts || 0)+1),retryAt,error:"Przygotowanie chwilowo niedostępne. Słowo jest zapisane; spróbujemy ponownie."}})));
          }
        } finally {inFlight.current=false; if (!controller.signal.aborted) timer=setTimeout(run,1200);}
        return;
      }
      if (!controller.signal.aborted) timer=setTimeout(run,1200);
    };
    void run();
    return ()=>{controller.abort();clearTimeout(timer);};
  },[enabled]);
  return null;
}
