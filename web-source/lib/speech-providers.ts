import { SPEECH_GAP } from "./exercise-audio";
import { env } from "cloudflare:workers";
import type { SpeechMode } from "./speech-cache";

const unavailable = new Map<string, number>();
function defer(key: string, ms = 60_000) {
  if (unavailable.size >= 300) unavailable.delete(unavailable.keys().next().value!);
  unavailable.set(key, Date.now() + ms);
}
function ready(key: string) { return (unavailable.get(key) || 0) < Date.now(); }
function xml(text: string) {
  return text.replace(/[<>&"']/g, (c) => ({"<":"&lt;",">":"&gt;","&":"&amp;",'"':"&quot;","'":"&apos;"})[c]!);
}
export function speechSsmlText(text:string) {
  return text.split(SPEECH_GAP).map(xml).join('<break time="900ms"/>');
}
export function safeDictionaryAudio(raw: string, accent: string) {
  try {
    const url = new URL(raw.startsWith("//") ? `https:${raw}` : raw);
    if (url.protocol !== "https:" || url.username || url.password || url.port) return null;
    if (!((url.hostname === "api.dictionaryapi.dev" && url.pathname.startsWith("/media/")) ||
      (url.hostname === "ssl.gstatic.com" && url.pathname.startsWith("/dictionary/")))) return null;
    const dialect = accent === "en-GB" ? /(?:[-_]uk|[-_]gb)(?:[-_.\/]|$)/i : /[-_]us(?:[-_.\/]|$)/i;
    return dialect.test(url.pathname) ? url.toString() : null;
  } catch { return null; }
}
async function audioResponse(response: Response, provider: string, credit = "") {
  if (!response.ok || !/^audio\//i.test(response.headers.get("Content-Type") || "")) throw new Error("AUDIO_PROVIDER");
  if (Number(response.headers.get("Content-Length")) > 4_000_000) throw new Error("AUDIO_SIZE");
  const bytes = await response.arrayBuffer();
  if (!bytes.byteLength || bytes.byteLength > 4_000_000) throw new Error("AUDIO_SIZE");
  return new Response(bytes, {headers:{"Content-Type":response.headers.get("Content-Type")!,"X-Speech-Provider":provider,"X-Speech-Credit":credit}});
}
type SpeechFailure={code:string;status:number;region:string;retryAfter:number};
let azureFailure:SpeechFailure | null=null;
export function speechFailure(){return azureFailure;}
const azurePending=new Map<string,Promise<Response | null>>();
async function azureSpeech(text:string,accent:string):Promise<Response | null> {
  const key=env.AZURE_SPEECH_KEY?.trim(),region=env.AZURE_SPEECH_REGION?.trim().toLowerCase() || "";
  if(!key || !/^[a-z0-9-]+$/.test(region)) {
    azureFailure={code:"AZURE_CONFIG",status:0,region,retryAfter:0};return null;
  }
  if(azureFailure && azureFailure.region===region && azureFailure.retryAfter>Date.now()) return null;
  const voices=accent==="en-GB" ? ["en-GB-SoniaNeural","en-GB-RyanNeural"] : ["en-US-JennyNeural","en-US-AriaNeural"];
  for(let attempt=0;attempt<voices.length;attempt++) {
    try {
      const response=await fetch(`https://${region}.tts.speech.microsoft.com/cognitiveservices/v1`,{
        // workerd rejects redirect:"error" before sending the request.
        // Manual mode plus the status check below rejects redirects without
        // ever forwarding the subscription key to a different destination.
        method:"POST",redirect:"manual",signal:AbortSignal.timeout(10000),
        headers:{"Ocp-Apim-Subscription-Key":key,"Content-Type":"application/ssml+xml","X-Microsoft-OutputFormat":"audio-24khz-48kbitrate-mono-mp3","User-Agent":"Fluent"},
        body:`<speak version="1.0" xmlns="http://www.w3.org/2001/10/synthesis" xml:lang="${accent}"><voice name="${voices[attempt]}">${speechSsmlText(text)}</voice></speak>`,
      });
      if(!response.ok) {
        const status=response.status;
        // Never log request headers, text or raw provider body (can contain secrets).
        console.warn("Azure Speech failure",{status,region,voice:voices[attempt],requestId:response.headers.get("x-requestid") || undefined});
        const retryable=status===429 || status>=500;
        azureFailure={code:`AZURE_HTTP_${status}`,status,region,retryAfter:0};
        await response.body?.cancel();
        if(retryable && attempt===0) continue;
        azureFailure.retryAfter=Date.now()+([401,403].includes(status)?30000:retryable?2000:0);
        return null;
      }
      const result=await audioResponse(response,"azure");azureFailure=null;return result;
    } catch(error) {
      const timeout=error instanceof Error && (error.name==="TimeoutError" || error.name==="AbortError");
      azureFailure={code:timeout?"AZURE_TIMEOUT":"AZURE_NETWORK",status:0,region,retryAfter:0};
      const detail=error instanceof Error ? error.message.split(key).join("[redacted]").split(text).join("[text]").slice(0,300) : "Unknown error";
      console.warn("Azure Speech failure",{code:azureFailure.code,region,name:error instanceof Error ? error.name : "unknown",detail});
      if(attempt===0) continue;
      azureFailure.retryAfter=Date.now()+2000;
    }
  }
  return null;
}
export async function independentSpeech(text: string, mode: SpeechMode, accent = "en-US"): Promise<Response | null> {
  const requestKey=`${env.AZURE_SPEECH_REGION}|${accent}|${text}`;
  let pending=azurePending.get(requestKey);
  if(!pending) {
    pending=azureSpeech(text,accent).finally(()=>azurePending.delete(requestKey));
    azurePending.set(requestKey,pending);
  }
  const azure=await pending;
  if(azure) return azure.clone();
  const key = `dictionary:${accent}:${text.toLowerCase()}`;
  if (mode === "word" && /^[a-z]+(?:[-'][a-z]+)*$/i.test(text) && ready(key) && ready("dictionary")) {
    try {
      const response = await fetch(`https://api.dictionaryapi.dev/api/v2/entries/en/${encodeURIComponent(text.toLowerCase())}`, {signal:AbortSignal.timeout(3000),redirect:"manual"});
      if (response.status === 404) defer(key, 600_000);
      else {
        if (!response.ok) throw new Error("DICTIONARY");
        const entries = await response.json() as {phonetics?:{audio?:string;sourceUrl?:string;license?:{url?:string}}[]}[];
        if (!Array.isArray(entries)) throw new Error("DICTIONARY");
        for (const phonetic of entries.flatMap((entry) => entry.phonetics || [])) {
          const url = safeDictionaryAudio(phonetic.audio || "", accent);
          if (!url) continue;
          const source = phonetic.sourceUrl || phonetic.license?.url || "https://dictionaryapi.dev/";
          const credit = /^https:\/\//.test(source) ? encodeURIComponent(source.slice(0,1500)) : "";
          return await audioResponse(await fetch(url,{signal:AbortSignal.timeout(3000),redirect:"manual"}),"dictionary",credit);
        }
        defer(key,600_000);
      }
    } catch { defer("dictionary"); }
  }
  return null;
}
