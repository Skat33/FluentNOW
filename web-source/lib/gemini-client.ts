"use client";
export type GeminiConnection = {
  connected: boolean;
  model: string | null;
  speechModel: string | null;
  source?: "account" | "shared" | "none";
  checkedAt?: number;
  limit?: { limit: number; used: number; remaining: number } | null;
};
export const disconnected: GeminiConnection = {
  connected: false,
  model: null,
  speechModel: null,
  source: "none",
  limit: null,
};
export async function readApiJson<T>(response: Response): Promise<T> {
  let data: any;
  try {
    data = await response.json();
  } catch {
    throw new Error(
      response.status === 401
        ? "Zaloguj się ponownie."
        : response.status === 403
          ? "Serwer odrzucił źródło żądania. Otwórz aplikację pod jej własnym adresem."
          : `Serwer zwrócił nieczytelną odpowiedź (HTTP ${response.status}). Spróbuj ponownie.`,
    );
  }
  if (!response.ok) {
    const detail = data?.diagnostic;
    const suffix = data?.code !== "MODEL" && detail?.providerStatus
      ? ` Google: ${detail.providerStatus}${detail.httpStatus ? ` (HTTP ${detail.httpStatus})` : ""}.`
      : "";
    throw new Error(
      (data?.error || `Błąd serwera (HTTP ${response.status}).`) +
        suffix +
        (detail?.providerMessage ? " " + detail.providerMessage : ""),
    );
  }
  return data as T;
}

export async function retryableGeminiResponse(response: Response) {
  if (response.ok || ![429, 502, 503, 504].includes(response.status))
    return false;
  try {
    const data = await response.clone().json();
    return data?.code === "PROVIDER";
  } catch {
    return false;
  }
}

function retryPause(attempt: number, signal?: AbortSignal) {
  const delay = Math.min(12_000, 1_500 * 2 ** Math.min(attempt, 3));
  return new Promise<void>((resolve, reject) => {
    const abort = () => {
      clearTimeout(timer);
      reject(new DOMException("Aborted", "AbortError"));
    };
    const timer = setTimeout(() => {
      signal?.removeEventListener("abort", abort);
      resolve();
    }, delay);
    if (signal?.aborted) abort();
    else signal?.addEventListener("abort", abort, { once: true });
  });
}

export async function postTutorJson<T>(data: unknown, signal?: AbortSignal, options: {attempts?:number;timeoutMs?:number} = {}) {
  const attempts = Math.max(1, Math.min(3, options.attempts ?? 3));
  const deadline = AbortSignal.timeout(options.timeoutMs ?? 120_000);
  const combined = signal ? AbortSignal.any([signal, deadline]) : deadline;
  try {
  for (let attempt = 0; attempt < attempts; attempt++) {
    const response = await fetch("/api/tutor", {
      method: "POST",
      headers: { "Content-Type": "application/json" },
      body: JSON.stringify(data),
      signal: combined,
    });
    if (attempt === attempts-1 || !(await retryableGeminiResponse(response)))
      return readApiJson<T>(response);
    await retryPause(attempt, combined);
  }
  } catch (error) {
    if (signal?.aborted) throw error;
    if (deadline.aborted)
      throw new Error("Przygotowanie trwa zbyt długo. Ponów próbę — gotowe słowa i zaznaczenia zostały zachowane.");
    throw error;
  }
  throw new Error("Nie udało się zakończyć przygotowania. Spróbuj ponownie.");
}
