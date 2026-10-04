"use client";
import {useMemo,useState} from 'react';
import {Popover,PopoverTrigger,PopoverContent} from '@/components/ui/popover';
import {readingTokens} from '@/lib/reading-vocabulary';
import type {Word} from '@/lib/learning';
function KnownWord({text,word}:{text:string;word:Word}) {
 const [open,setOpen]=useState(false);
 return <Popover open={open} onOpenChange={setOpen}><PopoverTrigger asChild><button type="button" className="reading-known-word" aria-label={`${text} — słowo z Twojego słownika`}>{text}</button></PopoverTrigger><PopoverContent className="reading-word-popover" onOpenAutoFocus={e=>e.preventDefault()}>
 <strong>{word.en}</strong><p className="small muted">Masz to słowo w swoim słowniku.</p><ul>{word.meanings.map(m=><li key={m.id}>{m.translation}{m.context && <span className="muted small"> · {m.context}</span>}</li>)}</ul><p className="small muted">Znaczenia zapisane przez Ciebie — wybierz pasujące do tekstu.</p>
 </PopoverContent></Popover>;
}
export function ReadingVocabulary({text,words}:{text:string;words:Word[]}) {
 const parts=useMemo(()=>readingTokens(text,words),[text,words]);
 return <>{parts.map((p,i)=>p.word?<KnownWord key={`${p.word.id}:${i}`} text={p.text} word={p.word}/>:p.text)}</>;
}
