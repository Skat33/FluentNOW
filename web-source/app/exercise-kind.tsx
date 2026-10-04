import {BookOpen,Languages,PenLine,Headphones} from 'lucide-react';
export function ExerciseKind({kind,detail}:{kind:'Słownictwo'|'Gramatyka'|'Idiomy'|'Czytanie'|'Słuchanie';detail?:string}){
 const Icon=kind==='Gramatyka'?PenLine:kind==='Czytanie'?BookOpen:kind==='Słuchanie'?Headphones:Languages;
 return <div className="exercise-kind-banner"><Icon size={20} aria-hidden="true"/><div><span>Rodzaj ćwiczenia</span><strong>{kind}{detail && <small> · {detail}</small>}</strong></div></div>;
}
