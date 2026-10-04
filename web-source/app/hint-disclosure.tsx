"use client";
import {Lightbulb,ChevronDown} from 'lucide-react';
export function HintDisclosure({text,onReveal}:{text:string;onReveal?:()=>void}) {
 return <details className="exercise-hint" onToggle={e=>{if(e.currentTarget.open)onReveal?.();}}>
  <summary><Lightbulb size={19}/><span>Podpowiedź</span><ChevronDown size={17}/></summary>
  <p>{text}</p>
 </details>;
}
