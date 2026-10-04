"use client";
import {useEffect,useRef} from 'react';
import {Volume2} from 'lucide-react';
import type {SpeechMode} from '@/lib/speech-cache';
export type ExerciseVoice={speak:(text:string,slow?:boolean,mode?:SpeechMode)=>void;prefetch?:(text:string,mode?:SpeechMode)=>void;stop?:()=>void};
export function ExerciseAudio({text,solved,speak,prefetch,stop}:ExerciseVoice & {text:string;solved:boolean}) {
 const voice=useRef({prefetch,stop});voice.current={prefetch,stop};
 useEffect(()=>{
   if(text) voice.current.prefetch?.(text,'exercise');
   return ()=>voice.current.stop?.();
 },[text]);
 if(!text) return null;
 return <button type="button" className="text-link exercise-audio" aria-label={solved?'Odsłuchaj zdanie z poprawną odpowiedzią':'Odsłuchaj treść zadania; luka pozostanie pusta'} onClick={()=>speak(text,undefined,'exercise')}><Volume2 size={18}/>{solved?'Posłuchaj poprawnego zdania':'Posłuchaj zadania'}</button>;
}
