import {headers} from 'next/headers';
import {checkOrigin} from '@/lib/request-origin';
import {ownedReports,submitReport} from '@/lib/report-store';
export async function GET(req:Request){const owner=(await headers()).get('oai-authenticated-user-id');if(!owner)return Response.json({error:'Zaloguj się, aby odczytać zgłoszenia.'},{status:401});
 try{const result=await ownedReports(owner);return Response.json(new URL(req.url).searchParams.has('download')?{reports:result.reports}:result,{headers:{'Cache-Control':'no-store',...(new URL(req.url).searchParams.has('download')?{'Content-Disposition':'attachment; filename="fluent-zgloszenia.json"'}:{})}});}catch{return Response.json({error:'Nie udało się odczytać zgłoszeń.'},{status:503});}}
export async function POST(req:Request){const owner=(await headers()).get('oai-authenticated-user-id');if(!owner)return Response.json({error:'Zgłoszenie pozostaje na urządzeniu do czasu połączenia z kontem.'},{status:401});const blocked=checkOrigin(req);if(blocked)return blocked;
 try{const raw=await req.text();if(raw.length>50000)return Response.json({error:'Zbyt duże zgłoszenie.'},{status:413});await submitReport(owner,JSON.parse(raw));return Response.json({ok:true});}catch(e){console.warn('Report save unavailable');return Response.json({error:'Nie udało się wysłać zgłoszenia. Lokalna kopia pozostaje do ponowienia.'},{status:503});}}
