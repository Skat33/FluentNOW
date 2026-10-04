import {readSpeechFile,saveSpeechFile} from "@/lib/speech-files";
import { headers } from "next/headers";
import { after } from "next/server";
import { z } from "zod";
import { independentSpeech, speechFailure } from "@/lib/speech-providers";
import { accountGenerate } from "@/lib/gemini-account";
import { checkOrigin } from "@/lib/request-origin";
import { quotaOwner, speechQuota, refundQuota } from "@/lib/tutor-server";
import {
  SPEECH_FALLBACKS,
  geminiError,
  geminiSpeech,
  pcmWave,
} from "@/lib/gemini";
import {
  MAX_SPEECH_TEXT_LENGTH,
  normalizeSpeechText,
  sharedSpeechCache,
  speechEdgeCacheKey,
  speechCacheHash,
} from "@/lib/speech-cache";

function cacheLater(task: Promise<unknown>) {
  try {
    after(async () => {
      await task;
    });
  } catch {
    void task.catch(() => undefined);
  }
}

const querySchema = z.object({
  h: z.string().regex(/^[a-f0-9]{32}$/),
  t: z.string().min(1).max(MAX_SPEECH_TEXT_LENGTH),
  mode: z.enum(["word", "sentence", "exercise"]),
  model: z.string().refine((model) => SPEECH_FALLBACKS.includes(model) || ["auto-us-v1","auto-gb-v1","auto-us-v2","auto-gb-v2"].includes(model)),
});

export async function GET(req: Request) {
  const id = (await headers()).get("oai-authenticated-user-id");
  let chargedOwner:string | null=null;
  try {
    const url = new URL(req.url);
    if ((url.searchParams.get("t") || "").length > MAX_SPEECH_TEXT_LENGTH)
      return Response.json({ error: "Zbyt długi tekst." }, { status: 413 });
    const parsed = querySchema.safeParse({
      h: url.searchParams.get("h"),
      t: url.searchParams.get("t"),
      mode: url.searchParams.get("mode"),
      model: url.searchParams.get("model"),
    });
    if (!parsed.success)
      return Response.json(
        { error: "Niepoprawny tekst do odczytania." },
        { status: 400 },
      );

    const d = parsed.data;
    const text = normalizeSpeechText(d.t);
    if ((await speechCacheHash(text, d.mode, d.model)) !== d.h)
      return Response.json(
        { error: "Nieprawidłowy identyfikator nagrania." },
        { status: 400 },
      );

    const cacheKey = speechEdgeCacheKey(req.url, d.h);
    let cache: Cache | undefined;
    let cached: Response | undefined;
    try {
      cache = await sharedSpeechCache();
      cached = await cache?.match(cacheKey);
    } catch (error) {
      console.warn("Speech edge cache read unavailable", error);
    }
    if (cached) {
      // Cache API responses have immutable headers. Vinext appends its Vary
      // header while finalizing a route response, so return a mutable wrapper.
      return new Response(cached.body, {
        status: cached.status,
        statusText: cached.statusText,
        headers: new Headers(cached.headers),
      });

    }
    const file=await readSpeechFile(d.h);
    if(file) {
      if(cache)cacheLater(cache.put(cacheKey,file.clone()));
      return file; // No provider request or generation quota charge on a stored file.
    }
    const owner=await quotaOwner(id,req);
    await speechQuota(owner);chargedOwner=`speech:${owner}`;
    if (d.model.startsWith("auto-")) {
      const external = await independentSpeech(text, d.mode, d.model.startsWith("auto-gb-") ? "en-GB" : "en-US");
      if (external) {
        external.headers.set("Cache-Control", "public, max-age=31536000, immutable");
        external.headers.set("ETag", `"${d.h}"`);
        cacheLater(saveSpeechFile(d.h,external.clone()));
        if (cache) cacheLater(cache.put(cacheKey,external.clone()));
        return external;
      }
    }
    // Exercise text must never be completed or rewritten by a generative voice.
    if (d.mode === "exercise" || text.includes("[[gap]]")) {
      await refundQuota(chargedOwner);chargedOwner=null;
      return Response.json({code:"EXERCISE_SPEECH",providerCode:speechFailure()?.code,providerStatus:speechFailure()?.status,error:"Nagranie ćwiczenia jest chwilowo niedostępne. Spróbuj ponownie lub wybierz głos urządzenia."},{status:503});
    }
    const accent = d.model.startsWith("auto-gb-") ? "British English" : "General American English";
    const audio = await accountGenerate(id, "speech", (key, model) =>
      geminiSpeech(
        key,
        model,
        d.mode === "word"
          ? `Say the English word or short phrase below once, clearly and naturally, in ${accent}. Output only the supplied text; no labels, introduction, spelling or commentary.\nTEXT:\n${text}`
          : `Read only the English text below, exactly as written; no introduction or commentary. Use natural ${accent}, warm conversational intonation, natural rhythm and stress.\nTEXT TO READ:\n${text}`,
      ),
    );
    const wav = pcmWave(audio.data, audio.mimeType);
    const result = new Response(wav.buffer, {
      headers: {
        "Content-Type": "audio/wav",
        "X-Speech-Provider": "gemini",
        "Cache-Control": "public, max-age=31536000, immutable",
        ETag: `"${d.h}"`,
        "Content-Length": String(wav.byteLength),
      },
    });
    cacheLater(saveSpeechFile(d.h,result.clone()));
    if (cache)
      try {
        cacheLater(cache.put(cacheKey, result.clone()));
      } catch (error) {
        console.warn("Speech edge cache write unavailable", error);
      }
    return result;
  } catch (error) {
    if(chargedOwner) await refundQuota(chargedOwner).catch(()=>undefined);
    console.error("Speech generation failed", error);
    return geminiError(error);
  }
}

export async function POST(req: Request) {
  const blocked = checkOrigin(req);
  if (blocked) return blocked;
  return Response.json(
    { error: "Ten punkt API korzysta teraz z metody GET." },
    { status: 405, headers: { Allow: "GET" } },
  );
}
