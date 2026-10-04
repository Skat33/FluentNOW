import { postTutorJson } from "./gemini-client";

type Entry = {key:string;at:number;data:unknown};
const STORE = "fluent-prepared-v1";
const TTL = 7 * 86400000;
const memory = new Map<string,Entry>();
const pending = new Set<string>();
let retryAfter = 0;
function keyOf(data: unknown) { return JSON.stringify(data); }
function entries(): Entry[] {
  try {
    const saved = JSON.parse(localStorage.getItem(STORE) || "[]");
    if (Array.isArray(saved)) for (const item of saved)
      if (typeof item?.key === "string" && typeof item.at === "number" && Date.now()-item.at < TTL) memory.set(item.key,item);
  } catch { /* Private mode or full storage: in-memory cache remains usable. */ }
  return [...memory.values()].filter(item=>Date.now()-item.at<TTL).sort((a,b)=>b.at-a.at).slice(0,24);
}
export function rememberPrepared(request: unknown, data: unknown) {
  entries();
  memory.set(keyOf(request),{key:keyOf(request),at:Date.now(),data});
  const saved = [...memory.values()].sort((a,b)=>b.at-a.at).slice(0,24);
  memory.clear(); saved.forEach(item=>memory.set(item.key,item));
  try { localStorage.setItem(STORE,JSON.stringify(saved)); } catch { /* optional device cache */ }
}
export function readPrepared<T>(request: unknown, validate:(data:unknown)=>T): T | null {
  entries();
  const entry = memory.get(keyOf(request));
  if (!entry || Date.now()-entry.at>=TTL) return null;
  try { return validate(structuredClone(entry.data)); } catch { return null; }
}
export function warmPrepared<T>(request:unknown,validate:(data:unknown)=>T) {
  const key=keyOf(request);
  if (readPrepared(request,validate) || pending.has(key) || Date.now()<retryAfter || (typeof navigator!=="undefined" && navigator.onLine === false)) return;
  pending.add(key);
  // Preparing the next set never changes the session being answered.
  void postTutorJson(request,AbortSignal.timeout(20_000),{attempts:1})
    .then(data=>rememberPrepared(request,validate(data)))
    .catch(()=>{retryAfter=Date.now()+90_000;})
    .finally(()=>pending.delete(key));
}
