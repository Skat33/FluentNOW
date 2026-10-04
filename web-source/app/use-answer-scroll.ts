"use client";
import {useEffect,useRef} from 'react';
export function useAnswerScroll(answered:boolean) {
 const ref=useRef<HTMLDivElement>(null);
 useEffect(()=>{
  if(!answered)return;
  if(document.activeElement instanceof HTMLInputElement)document.activeElement.blur();
  // Give mobile keyboards time to close before calculating the target position.
  const timer=setTimeout(()=>ref.current?.scrollIntoView({block:'start',behavior:window.matchMedia('(prefers-reduced-motion: reduce)').matches?'auto':'smooth'}),180);
  return()=>clearTimeout(timer);
 },[answered]);
 return ref;
}
