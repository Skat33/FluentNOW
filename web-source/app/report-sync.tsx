"use client";
import {useContext,useEffect} from 'react';
import {toast} from 'sonner';
import {ReportScope} from './exercise-reports';
import {readExerciseReports,reportStorageKey} from '@/lib/exercise-reports';
import {installCorrections,type SavedCorrection} from '@/lib/report-corrections';
export function ReportSync(){
 const scope=useContext(ReportScope);
 useEffect(()=>{
  let gone=false,running=false,queued=false;
  installCorrections([]);
  async function sync(){if(gone)return;if(running){queued=true;return;}running=true;
   try{
    const local=readExerciseReports(localStorage,scope);
    for(const report of local){
     const r=await fetch('/api/reports',{method:'POST',headers:{'Content-Type':'application/json'},body:JSON.stringify(report)});
     if(!r.ok)throw new Error('Zgłoszenie zapisane lokalnie. Spróbujemy wysłać je po ponownym połączeniu.');
     if(gone)return;
     // Remove only this acknowledged report, preserving submissions made during upload.
     localStorage.setItem(reportStorageKey(scope),JSON.stringify(readExerciseReports(localStorage,scope).filter(x=>x.id!==report.id)));
    }
    const r=await fetch('/api/reports');
    if(r.ok && !gone){const d=await r.json() as {corrections:SavedCorrection[]};installCorrections(d.corrections);window.dispatchEvent(new Event('fluent-reports-synced'));}
   }catch(e){if(!gone && readExerciseReports(localStorage,scope).length)toast.error(e instanceof Error?e.message:'Nie udało się wysłać zgłoszenia.');}
   finally{running=false;if(queued && !gone){queued=false;void sync();}}
  }
  void sync();window.addEventListener('fluent-reports-changed',sync);window.addEventListener('online',sync);window.addEventListener('focus',sync);
  return()=>{gone=true;installCorrections([]);window.removeEventListener('fluent-reports-changed',sync);window.removeEventListener('online',sync);window.removeEventListener('focus',sync);};
 },[scope]);return null;
}
