export type SpeechMode = "word" | "sentence" | "exercise";

export const SPEECH_PROMPT_VERSION = 3;
export const MAX_SPEECH_TEXT_LENGTH = 8000;

export function normalizeSpeechText(text: string) {
  return text.trim().replace(/\s+/g, " ");
}

export async function speechCacheHash(
  text: string,
  mode: SpeechMode,
  model: string,
) {
  const input = JSON.stringify({
    text: normalizeSpeechText(text),
    mode,
    model,
    promptVersion: SPEECH_PROMPT_VERSION,
  });
  const digest = await crypto.subtle.digest(
    "SHA-256",
    new TextEncoder().encode(input),
  );
  return [...new Uint8Array(digest)]
    .map((byte) => byte.toString(16).padStart(2, "0"))
    .join("")
    .slice(0, 32);
}

// Fast, evictable edge layer. Durable R2 audio files live in speech-files.ts.
export async function sharedSpeechCache() {
  const storage = globalThis.caches as unknown as
    | { open?: (name: string) => Promise<Cache>; default?: Cache }
    | undefined;
  if (!storage) return undefined;
  // Sites workers cannot access caches.default, but can use a named Cache.
  // Keep the fallback only for local/unit runtimes that implement default.
  return storage.open
    ? storage.open("fluent-speech-v3")
    : storage.default;
}

export function speechEdgeCacheKey(requestUrl: string, hash: string) {
  const url = new URL(requestUrl);
  // Private Sites requests carry authorization/signature headers that the
  // Cloudflare Cache API correctly refuses to store. The verified hash already
  // contains text, mode, model and prompt version, so use a header-free key.
  return new Request(`${url.origin}/_fluent/speech-cache/${hash}`, {
    method: "GET",
  });
}
