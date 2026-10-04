"use client";
import {createContext,useContext,useEffect,useState} from 'react';
import {Flag,Download} from 'lucide-react';
import {toast} from 'sonner';
import {Dialog,DialogContent,DialogHeader,DialogTitle,DialogDescription} from '@/components/ui/dialog';
import {readExerciseReports,saveExerciseReport,reportStorageKey,type ReportSnapshot,type ExerciseReport} from '@/lib/exercise-reports';
export const ReportScope=createContext('guest');
export function ReportExercise({snapshot}:{snapshot:ReportSnapshot}) {
 const scope=useContext(ReportScope);
 const [open,setOpen]=useState(false),[comment,setComment]=useState(''),[saved,setSaved]=useState(false);
 useEffect(()=>{setSaved(false);setComment('');setOpen(false);},[snapshot.question]);
 function save() {
  try {
   saveExerciseReport(localStorage,scope,snapshot,comment);
   window.dispatchEvent(new Event('fluent-reports-changed'));
   setSaved(true);setOpen(false);toast.success('Zgłoszenie zapisane. Wysyłamy je do kolejki analizy.');
  } catch(e) {toast.error(e instanceof Error ? e.message : 'Nie udało się zapisać zgłoszenia. Spróbuj ponownie.');}
 }
 return <><button type="button" className="text-link report-exercise" disabled={saved} onClick={()=>setOpen(true)}><Flag size={16}/>{saved?'Zgłoszenie zapisane':'Zgłoś błąd w zadaniu'}</button>
 <Dialog open={open} onOpenChange={setOpen}><DialogContent className="report-dialog"><DialogHeader><DialogTitle>Zgłoś błąd w zadaniu</DialogTitle><DialogDescription>Zgłoszenie trafi do kolejki na serwerze. AI sprawdza kolejkę raz na godzinę. Potwierdzone błędy w odpowiedziach są poprawiane, a niejednoznaczne zgłoszenia pozostają do sprawdzenia.</DialogDescription></DialogHeader>
 <p className="small">Twoja odpowiedź: <b>{snapshot.answer || '—'}</b></p>
 <label htmlFor="exercise-report-comment">Co wymaga poprawy?</label><textarea id="exercise-report-comment" rows={4} maxLength={2000} value={comment} onChange={e=>setComment(e.target.value)} placeholder="Np. moja odpowiedź też jest poprawna albo lektor czyta niewłaściwy tekst…"/>
 <div className="row wrap"><button className="btn secondary" onClick={()=>setOpen(false)}>Anuluj</button><button className="btn primary" onClick={save}>Zapisz zgłoszenie</button></div>
 </DialogContent></Dialog></>;
}
export function ExerciseReports() {
 const scope=useContext(ReportScope);
 const [items,setItems]=useState<(Omit<ExerciseReport,'status'> & {status:string;reason?:string})[]>([]),[error,setError]=useState(''),[limit,setLimit]=useState(20);
 useEffect(()=>{
  const read=async()=>{try{const local=readExerciseReports(localStorage,scope);const response=await fetch('/api/reports');if(!response.ok){setItems(local);setError('Nie udało się odczytać kolejki serwera. Lokalne zgłoszenia pozostają zapisane.');return;}const data=await response.json();const ids=new Set(data.reports.map((r:ExerciseReport)=>r.id));setItems([...local.filter(r=>!ids.has(r.id)),...data.reports].sort((a,b)=>a.created-b.created));setError('');}catch{setError('Nie można odczytać zgłoszeń. Spróbuj ponownie.');}};
  void read();window.addEventListener('fluent-reports-changed',read);window.addEventListener('fluent-reports-synced',read);window.addEventListener('storage',read);
  return()=>{window.removeEventListener('fluent-reports-changed',read);window.removeEventListener('fluent-reports-synced',read);window.removeEventListener('storage',read);};
 },[scope]);
 function exportReports() {
  const url=URL.createObjectURL(new Blob([JSON.stringify({version:1,reports:items},null,2)],{type:'application/json'}));
  const a=document.createElement('a');a.href=url;a.download='fluent-zgloszenia.json';a.click();setTimeout(()=>URL.revokeObjectURL(url),1000);
 }
 function remove(id:string) {
  try {const next=readExerciseReports(localStorage,scope).filter(r=>r.id!==id);localStorage.setItem(reportStorageKey(scope),JSON.stringify(next));setItems(prev=>prev.filter(r=>r.id!==id));}catch{toast.error('Nie udało się usunąć zgłoszenia.');}
 }
 return <section className="card padded exercise-reports" id="zgloszenia"><div className="row between wrap"><h2>Zgłoszenia ({items.length})</h2><button className="btn secondary" disabled={!items.length} onClick={exportReports}><Download size={16}/>Eksport JSON</button></div><p className="muted small">Kolejka jest sprawdzana raz na godzinę. Poprawki obowiązują w nowych zadaniach po ponownym otwarciu aplikacji. Odrzucone zgłoszenia znikają z listy.</p>
 {error && <p role="alert" className="error-banner">{error}</p>}{!items.length && !error && <p>Nie masz jeszcze zgłoszeń. Przycisk „Zgłoś błąd” znajdziesz przy wyniku zadania.</p>}
 {[...items].reverse().slice(0,limit).map(r=><details key={r.id}><summary>{new Date(r.created).toLocaleString('pl-PL')} · {r.mode} · {({local:"czeka na wysłanie",pending:"czeka na analizę",processing:"w analizie",corrected:"poprawione",uncertain:"wymaga sprawdzenia"} as Record<string,string>)[r.status] || r.status}</summary><p>{r.question}</p><p>Twoja odpowiedź: <b>{r.answer || '—'}</b></p><p>Zapisane warianty: {r.expected.join(' / ')}</p><p>{r.comment || 'Bez dodatkowego opisu.'}</p>{r.reason && <p>{r.reason}</p>}{r.status==='local' && <button className="text-link" onClick={()=>remove(r.id)}>Usuń zgłoszenie</button>}</details>)}
 {items.length>limit && <button className="text-link" onClick={()=>setLimit(limit+20)}>Pokaż kolejne zgłoszenia</button>}</section>;
}
