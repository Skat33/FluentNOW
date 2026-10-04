import { env } from "cloudflare:workers";
import { database } from "@/db/store";
import { openKey, sealKey } from "./key-vault";
import {
  GEMINI_FALLBACKS,
  GeminiProviderError,
  SPEECH_FALLBACKS,
  compatibleGeminiModels,
  listGeminiModels,
  withModelFallback,
} from "./gemini";
type Stored = {
  encrypted_key: string;
  model: string;
  speech_model: string | null;
};
const resolvedModels = new Map<string, string>();

async function connectionFingerprint(key: string, kind: "text" | "speech") {
  const digest = await crypto.subtle.digest(
    "SHA-256",
    new TextEncoder().encode(key),
  );
  return `${kind}:${[...new Uint8Array(digest)]
    .slice(0, 12)
    .map((byte) => byte.toString(16).padStart(2, "0"))
    .join("")}`;
}

function rememberModel(fingerprint: string, model: string) {
  if (resolvedModels.size >= 64 && !resolvedModels.has(fingerprint))
    resolvedModels.delete(resolvedModels.keys().next().value as string);
  resolvedModels.set(fingerprint, model);
}

async function generateWithDiscovery<T>(
  key: string,
  kind: "text" | "speech",
  preferred: string | null | undefined,
  call: (key: string, model: string) => Promise<T>,
) {
  const fingerprint = await connectionFingerprint(key, kind);
  const configured = kind === "text" ? GEMINI_FALLBACKS : SPEECH_FALLBACKS;
  const initial = [
    resolvedModels.get(fingerprint),
    preferred,
    ...configured,
  ].filter((model): model is string => !!model);
  try {
    const result = await withModelFallback(initial, (model) => call(key, model));
    rememberModel(fingerprint, result.model);
    return result;
  } catch (error) {
    const modelsMissing =
      (error instanceof Error && error.message === "MODEL") ||
      (error instanceof GeminiProviderError && error.httpStatus === 404);
    if (!modelsMissing) throw error;
    let discovered: string[];
    try {
      const available = await listGeminiModels(key);
      const attempted = new Set(initial);
      discovered = compatibleGeminiModels(available, kind).filter(
        (model) => !attempted.has(model),
      );
    } catch (discoveryError) {
      if (
        discoveryError instanceof GeminiProviderError &&
        [401, 403].includes(discoveryError.httpStatus)
      )
        throw discoveryError;
      throw error;
    }
    if (!discovered.length) throw error;
    const result = await withModelFallback(discovered, (model) =>
      call(key, model),
    );
    rememberModel(fingerprint, result.model);
    return result;
  }
}
export async function savedConnection(owner: string) {
  return database()
    .prepare(
      "SELECT encrypted_key,model,speech_model FROM gemini_connections WHERE owner=?",
    )
    .bind(owner)
    .first<Stored>();
}
export async function connectionStatus(owner?: string | null) {
  const row = owner ? await savedConnection(owner) : null;
  const shared = env.GEMINI_API_KEY?.trim();
  const rememberedText = shared
    ? resolvedModels.get(await connectionFingerprint(shared, "text"))
    : null;
  const rememberedSpeech = shared
    ? resolvedModels.get(await connectionFingerprint(shared, "speech"))
    : null;
  return {
    connected: !!row || !!shared,
    model:
      row?.model || rememberedText || (shared ? GEMINI_FALLBACKS[0] : null),
    speechModel:
      row?.speech_model ||
      rememberedSpeech ||
      (shared ? SPEECH_FALLBACKS[0] : null),
    source: row
      ? ("account" as const)
      : shared
        ? ("shared" as const)
        : ("none" as const),
  };
}
export async function saveConnection(
  owner: string,
  key: string,
  model: string,
  speechModel: string | null,
) {
  const encrypted = await sealKey(
    key,
    owner,
    env.GEMINI_KEY_ENCRYPTION_SECRET || "",
  );
  await database()
    .prepare(
      "INSERT INTO gemini_connections (owner,encrypted_key,model,speech_model) VALUES (?,?,?,?) ON CONFLICT(owner) DO UPDATE SET encrypted_key=excluded.encrypted_key,model=excluded.model,speech_model=excluded.speech_model",
    )
    .bind(owner, encrypted, model, speechModel)
    .run();
}
export async function disconnect(owner: string) {
  await database()
    .prepare("DELETE FROM gemini_connections WHERE owner=?")
    .bind(owner)
    .run();
}

export async function refreshModels(owner: string) {
  const row = await savedConnection(owner);
  const key = row
    ? await openKey(
        row.encrypted_key,
        owner,
        env.GEMINI_KEY_ENCRYPTION_SECRET || "",
      )
    : env.GEMINI_API_KEY?.trim();
  if (!key) throw new Error("NOT_CONFIGURED");
  const available = await listGeminiModels(key);
  const model = compatibleGeminiModels(available, "text")[0];
  if (!model) throw new Error("MODEL");
  const speechModel = compatibleGeminiModels(available, "speech")[0] || null;
  if (!row) {
    rememberModel(await connectionFingerprint(key, "text"), model);
    if (speechModel)
      rememberModel(await connectionFingerprint(key, "speech"), speechModel);
  }
  if (row)
    await database()
      .prepare(
        "UPDATE gemini_connections SET model=?,speech_model=? WHERE owner=? AND encrypted_key=?",
      )
      .bind(model, speechModel, owner, row.encrypted_key)
      .run();
  return {
    connected: true,
    model,
    speechModel,
    source: row ? ("account" as const) : ("shared" as const),
  };
}
export async function accountGenerate<T>(
  owner: string | null,
  kind: "text" | "speech",
  call: (key: string, model: string) => Promise<T>,
) {
  const row = owner ? await savedConnection(owner) : null;
  const sharedKey = env.GEMINI_API_KEY?.trim();
  const accountKey = row
    ? await openKey(
        row.encrypted_key,
        owner!,
        env.GEMINI_KEY_ENCRYPTION_SECRET || "",
      )
    : undefined;
  const key = accountKey || sharedKey;
  if (!key) throw new Error("NOT_CONFIGURED");
  const preferred = row
    ? kind === "text"
      ? row.model
      : row.speech_model
    : kind === "text"
      ? GEMINI_FALLBACKS[0]
      : SPEECH_FALLBACKS[0];
  let result: { value: T; model: string };
  let usedSharedFallback = false;
  try {
    result = await generateWithDiscovery(key, kind, preferred, call);
  } catch (error) {
    const accountUnavailable =
      row &&
      sharedKey &&
      sharedKey !== accountKey &&
      ((error instanceof Error && error.message === "MODEL") ||
        (error instanceof GeminiProviderError &&
          [401, 403, 404].includes(error.httpStatus)));
    if (!accountUnavailable) throw error;
    usedSharedFallback = true;
    result = await generateWithDiscovery(
      sharedKey,
      kind,
      kind === "text" ? GEMINI_FALLBACKS[0] : SPEECH_FALLBACKS[0],
      call,
    );
  }
  if (row && !usedSharedFallback && result.model !== preferred) {
    const field = kind === "text" ? "model" : "speech_model";
    await database()
      .prepare(
        `UPDATE gemini_connections SET ${field}=? WHERE owner=? AND encrypted_key=?`,
      )
      .bind(result.model, owner!, row.encrypted_key)
      .run();
  }
  return result.value;
}
