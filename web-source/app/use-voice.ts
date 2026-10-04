"use client";
import { SPEECH_GAP } from "@/lib/exercise-audio";

import {
  normalizeSpeechText,
  MAX_SPEECH_TEXT_LENGTH,
  speechCacheHash,
  type SpeechMode,
} from "@/lib/speech-cache";
import { createElement, useEffect, useRef, useState } from "react";
import { toast } from "sonner";

const AUDIO_DB = "fluent-audio-v1";
const AUDIO_STORE = "clips";
const MAX_AUDIO_BYTES = 50 * 1024 * 1024;

type ClipRecord = {
  hash: string;
  blob: Blob;
  size: number;
  used: number;
  provider?: string;
  credit?: string;
};

type PrefetchItem = { text: string; mode?: SpeechMode };

class SpeechHttpError extends Error {
  constructor(
    public status: number,
    public code: string,
  ) {
    super(code || `HTTP_${status}`);
  }
}

function modeFor(text: string): SpeechMode {
  return text.trim().split(/\s+/).length <= 4 && text.trim().length <= 60
    ? "word"
    : "sentence";
}

function requestResult<T>(request: IDBRequest<T>) {
  return new Promise<T>((resolve, reject) => {
    request.onsuccess = () => resolve(request.result);
    request.onerror = () => reject(request.error);
  });
}

let databasePromise: Promise<IDBDatabase> | undefined;
function audioDatabase() {
  if (!databasePromise) {
    databasePromise = new Promise((resolve, reject) => {
      const request = indexedDB.open(AUDIO_DB, 1);
      request.onupgradeneeded = () => {
        const database = request.result;
        if (!database.objectStoreNames.contains(AUDIO_STORE))
          database.createObjectStore(AUDIO_STORE, { keyPath: "hash" });
      };
      request.onsuccess = () => resolve(request.result);
      request.onerror = () => reject(request.error);
    });
  }
  return databasePromise;
}

async function readClip(hash: string) {
  if (!("indexedDB" in window)) return undefined;
  const database = await audioDatabase();
  const tx = database.transaction(AUDIO_STORE, "readwrite");
  const store = tx.objectStore(AUDIO_STORE);
  const record = await requestResult(store.get(hash)) as ClipRecord | undefined;
  if (record) store.put({ ...record, used: Date.now() });
  return record;
}

async function storeClip(hash: string, blob: Blob, provider: string, credit: string) {
  if (!("indexedDB" in window)) return;
  const database = await audioDatabase();
  const tx = database.transaction(AUDIO_STORE, "readwrite");
  const store = tx.objectStore(AUDIO_STORE);
  store.put({ hash, blob, size: blob.size, used: Date.now(), provider, credit } satisfies ClipRecord);
  const committed=new Promise<void>((resolve,reject)=>{tx.oncomplete=()=>resolve();tx.onerror=()=>reject(tx.error);tx.onabort=()=>reject(tx.error);});
  void committed.catch(() => undefined);
  const all = await requestResult(store.getAll()) as ClipRecord[];
  let total = all.reduce((sum, item) => sum + item.size, 0);
  for (const item of all.sort((left, right) => left.used - right.used)) {
    if (total <= MAX_AUDIO_BYTES) break;
    store.delete(item.hash);
    total -= item.size;
  }
  await committed;
}

function englishVoice(voice: SpeechSynthesisVoice) {
  return /^en(?:[-_]|$)/i.test(voice.lang.trim());
}

export function useVoice(
  ai: boolean,
  settings: { accent: string; slow: boolean; voice?: string },
  model?: string | null,
) {
  const [voices, setVoices] = useState<SpeechSynthesisVoice[]>([]);
  const [provider, setProvider] = useState("");
  const credits = useRef(new Map<string, {provider:string;credit:string}>());
  const [loading, setLoading] = useState(false);
  const [playbackBlocked, setPlaybackBlocked] = useState(false);
  const serial = useRef(0);
  const audio = useRef<HTMLAudioElement | null>(null);
  const cache = useRef(new Map<string, string>());
  const inflight = useRef(new Map<string, Promise<string>>());
  const notified = useRef(new Set<string>());
  const queue = useRef<PrefetchItem[]>([]);
  const queued = useRef(new Set<string>());
  const queueActive = useRef(0);
  const loadingToast = useRef<string | number | undefined>(undefined);

  useEffect(() => {
    const hasDeviceSpeech = "speechSynthesis" in window;
    const objectUrls = cache.current;
    const activeRequests = inflight.current;
    const refresh = () =>
      setVoices(window.speechSynthesis.getVoices().filter(englishVoice));
    if (hasDeviceSpeech) {
      refresh();
      window.speechSynthesis.addEventListener("voiceschanged", refresh);
    }
    return () => {
      if (hasDeviceSpeech) {
        window.speechSynthesis.removeEventListener("voiceschanged", refresh);
        window.speechSynthesis.cancel();
      }
      audio.current?.pause();
      objectUrls.forEach((url) => URL.revokeObjectURL(url));
      objectUrls.clear();
      activeRequests.clear();
      credits.current.clear();
    };
  }, []);

  const language = settings.accent || "en-US";
  const score = (voice: SpeechSynthesisVoice) => {
    const name = voice.name.toLowerCase();
    return (
      (voice.lang.toLowerCase().replace("_", "-") === language.toLowerCase()
        ? 100
        : 0) +
      (/natural|neural|enhanced|premium/.test(name) ? 30 : 0) +
      (/google us english|jenny|aria|samantha|ava|guy/.test(name) ? 20 : 0)
    );
  };
  const ranked = [...voices].sort((left, right) => score(right) - score(left));
  const chosen =
    voices.find((voice) => voice.voiceURI === settings.voice) || ranked[0];
  const isNaturalVoice =
    (!!provider && provider !== "device") || (!!chosen && /natural|neural|enhanced|premium/i.test(chosen.name));

  function notifyOnce(code: string, message: string) {
    if (notified.current.has(code)) return;
    notified.current.add(code);
    toast(message);
  }

  function rememberClip(hash:string,url:string,provider:string,credit:string) {
    if (cache.current.size >= 50) {
      const oldest=cache.current.keys().next().value;
      if(oldest) {
        const previous=cache.current.get(oldest)!;
        URL.revokeObjectURL(previous);credits.current.delete(previous);cache.current.delete(oldest);
      }
    }
    cache.current.set(hash,url);credits.current.set(url,{provider,credit});
  }

  async function load(text: string, mode = modeFor(text)) {
    const providerModel = language === "en-GB" ? "auto-gb-v2" : "auto-us-v2";
    const normalized = normalizeSpeechText(text);
    const hash = await speechCacheHash(normalized, mode, providerModel);
    const cached = cache.current.get(hash);
    if (cached) return cached;
    const active = inflight.current.get(hash);
    if (active) return active;
    const request = (async () => {
      const stored = await readClip(hash).catch(() => undefined);
      if (stored) {
        const url = URL.createObjectURL(stored.blob);
        rememberClip(hash,url,stored.provider || "",stored.credit || "");
        return url;
      }
      const query = new URLSearchParams({
        h: hash,
        t: normalized,
        mode,
        model: providerModel,
      });
      const response = await fetch(`/api/speech?${query}`, {
        signal: AbortSignal.timeout(25_000),
      });
      if (!response.ok) {
        const body = await response.json().catch(() => ({}));
        throw new SpeechHttpError(response.status, String(body.providerCode || body.code || ""));
      }
      const blob = await response.blob();
      const source = response.headers.get("X-Speech-Provider") || "gemini";
      const credit = response.headers.get("X-Speech-Credit") || "";
      await storeClip(hash, blob, source, credit).catch(() => undefined);
      const url = URL.createObjectURL(blob);
      rememberClip(hash,url,source,credit);
      return url;
    })().finally(() => inflight.current.delete(hash));
    inflight.current.set(hash, request);
    return request;
  }

  function pumpQueue() {
    while (queueActive.current < 1 && queue.current.length) {
      const item = queue.current.shift()!;
      const key = `${item.mode || modeFor(item.text)}|${item.text}`;
      queueActive.current++;
      void load(item.text, item.mode)
        .catch((error) => {
          // Background warming must not flood an exhausted or overloaded provider.
          if (error instanceof SpeechHttpError && [429, 502, 503, 504].includes(error.status)) {
            queue.current = [];
            queued.current.clear();
          }
        })
        .finally(() => {
          queueActive.current--;
          queued.current.delete(key);
          pumpQueue();
        });
    }
  }

  function prefetchMany(items: PrefetchItem[]) {
    for (const item of items) {
      if (!item.text.trim()) continue;
      const key = `${item.mode || modeFor(item.text)}|${item.text}`;
      if (queued.current.has(key)) continue;
      queued.current.add(key);
      queue.current.push(item);
    }
    const idle = window.requestIdleCallback || ((callback) => window.setTimeout(callback, 1));
    idle(() => pumpQueue());
  }

  async function prefetch(text: string, mode = modeFor(text)) {
    prefetchMany([{ text, mode }]);
  }

  async function waitForVoices() {
    const current = window.speechSynthesis.getVoices();
    if (current.length) return current;
    return new Promise<SpeechSynthesisVoice[]>((resolve) => {
      let complete = false;
      const finish = () => {
        if (complete) return;
        complete = true;
        window.speechSynthesis.removeEventListener("voiceschanged", finish);
        resolve(window.speechSynthesis.getVoices());
      };
      window.speechSynthesis.addEventListener("voiceschanged", finish);
      window.setTimeout(finish, 1500);
    });
  }

  async function speakOnDevice(text: string, slow: boolean) {
    if (!("speechSynthesis" in window)) return false;
    const generation=serial.current;
    setProvider("device");
    const available = await waitForVoices();
    const english = available.filter(englishVoice).sort((a, b) => score(b) - score(a));
    const voice =
      available.find((item) => item.voiceURI === settings.voice) ||
      english[0] ||
      available.find((item) => item.default) ||
      available[0];
    const parts=text.split(SPEECH_GAP);
    for(let i=0;i<parts.length;i++) {
      if(generation!==serial.current) return false;
      if(i) await new Promise(resolve=>window.setTimeout(resolve,900));
      if(generation!==serial.current) return false;
      if(!parts[i].trim()) continue;
      const utterance=new SpeechSynthesisUtterance(parts[i]);
      utterance.lang=voice?.lang || language;utterance.voice=voice || null;
      utterance.rate=slow ? 0.75 : 1;utterance.pitch=1;
      const ok=await new Promise<boolean>(resolve=>{
        utterance.onend=()=>resolve(true);utterance.onerror=()=>resolve(false);
        window.speechSynthesis.resume();window.speechSynthesis.speak(utterance);
      });
      if(!ok) return false;
    }
    return true;
  }
  function stop() {
    ++serial.current;
    audio.current?.pause();
    if ("speechSynthesis" in window) window.speechSynthesis.cancel();
    setLoading(false);setPlaybackBlocked(false);
    if(loadingToast.current!==undefined) toast.dismiss(loadingToast.current);
    loadingToast.current=undefined;
  }

  async function resumeBlockedPlayback() {
    if (!audio.current) return;
    try {
      await audio.current.play();
      setPlaybackBlocked(false);
    } catch {
      notifyOnce("AUTOPLAY", "Dotknij ponownie, aby uruchomić dźwięk.");
    }
  }

  async function speak(
    text: string,
    slow = settings.slow,
    mode = modeFor(text),
  ) {
    const id = ++serial.current;
    if (loadingToast.current !== undefined) toast.dismiss(loadingToast.current);
    audio.current?.pause();
    if ("speechSynthesis" in window) window.speechSynthesis.cancel();
    const normalized = normalizeSpeechText(text);
    if (!normalized) return;
    if(normalized.length>MAX_SPEECH_TEXT_LENGTH) { toast.error("Tekst jest zbyt długi do jednego nagrania. Odtwórz krótszy fragment.");return; }

    {
      const toastTimer=window.setTimeout(()=>{
        if(id===serial.current) loadingToast.current=toast.loading(`Przygotowuję nagranie: „${normalized.replaceAll(SPEECH_GAP,"…").slice(0,60)}”`);
      },250);
      try {
        setLoading(true);
        const url = await load(normalized, mode);
        if (id !== serial.current) return;
        const info = credits.current.get(url);
        setProvider(info?.provider || "");
        if (info?.credit) {
          const href = decodeURIComponent(info.credit);
          if (href.startsWith("https://")) toast.message("Nagranie słownikowe", {
            description: createElement("a", {href,target:"_blank",rel:"noopener noreferrer"}, "Źródło nagrania i licencja"),
          });
        }
        const element = new Audio(url) as HTMLAudioElement & {
          webkitPreservesPitch?: boolean;
        };
        element.playbackRate = slow ? 0.75 : 1;
        element.preservesPitch = true;
        element.webkitPreservesPitch = true;
        audio.current = element;
        try {
          await element.play();
          setPlaybackBlocked(false);
        } catch (error) {
          if (error instanceof DOMException && error.name === "NotAllowedError") {
            setPlaybackBlocked(true);
            return;
          }
          throw error;
        }
        return;
      } catch (error) {
        if (id !== serial.current) return;
        const code =
          error instanceof SpeechHttpError
            ? error.code || `HTTP_${error.status}`
            : error instanceof DOMException && error.name === "TimeoutError"
              ? "TIMEOUT"
              : "SPEECH";
        toast.error(
          ["SPEECH_LIMIT", "LIMIT"].includes(code)
            ? "Limit nowych nagrań został wykorzystany. Zapisane nagrania nadal działają."
            : /^AZURE_HTTP_(401|403)$/.test(code) ? "Azure odrzucił dostęp do nagrania. Konfiguracja klucza i regionu wymaga sprawdzenia."
            : code==="AZURE_CONFIG" ? "Lektor Azure nie ma poprawnej konfiguracji. Możesz skorzystać z głosu urządzenia."
            : "Nagranie jest chwilowo niedostępne. Spróbuj ponownie lub wybierz głos urządzenia.",
          { action: { label: "Głos urządzenia", onClick: () => { if(id===serial.current) void speakOnDevice(normalized, slow); } } },
        );
        // Never silently switch the requested AI narrator to a different voice.
        return;
      } finally {
        window.clearTimeout(toastTimer);
        if (id === serial.current) {
          setLoading(false);
          if (loadingToast.current !== undefined) toast.dismiss(loadingToast.current);
          loadingToast.current = undefined;
        }
      }
    }


  }

  return {
    speak,
    stop,
    prefetch,
    prefetchMany,
    loading,
    playbackBlocked,
    resumeBlockedPlayback,
    voices: ranked,
    isNaturalVoice,
    voiceLabel: provider === "dictionary" ? "Nagranie słownikowe · wybrana odmiana angielskiego"
      : provider === "azure" ? "Azure Speech · lektor"
      : provider === "gemini" ? "Gemini · lektor zapasowy"
      : provider === "device" ? "Głos urządzenia · tryb zapasowy"
      : "Nagrania słownikowe i lektor · audio zapamiętywane",

  };
}
