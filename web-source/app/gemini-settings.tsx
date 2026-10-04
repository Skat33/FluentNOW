"use client";
import { useEffect, useRef, useState } from "react";
import { Sparkles, LoaderCircle, Unplug } from "lucide-react";
import { GEMINI_LABEL } from "@/lib/gemini";
import { readApiJson, type GeminiConnection } from "@/lib/gemini-client";
export function GeminiSettings({
  connection,
  onChange,
}: {
  connection: GeminiConnection;
  onChange: (value: GeminiConnection) => void;
}) {
  const [busy, setBusy] = useState(false),
    [error, setError] = useState("");
  const pending = useRef<AbortController | null>(null);
  useEffect(() => {
    const ac = new AbortController();
    pending.current = ac;
    fetch("/api/gemini", { cache: "no-store", signal: ac.signal })
      .then((r) => readApiJson<GeminiConnection>(r))
      .then((d) => {
        if (!ac.signal.aborted) onChange(d);
      })
      .catch((e) => {
        if (!ac.signal.aborted) setError(e.message);
      });
    return () => pending.current?.abort();
  }, [onChange]);
  async function update(method: "PATCH" | "DELETE") {
    if (busy) return;
    pending.current?.abort();
    setBusy(true);
    setError("");
    const ac = new AbortController();
    pending.current = ac;
    try {
      const r = await fetch("/api/gemini", {
        method,
        headers: { "Content-Type": "application/json" },
        signal: ac.signal,
      });
      const d = await readApiJson<GeminiConnection>(r);
      if (ac.signal.aborted) return;
      onChange(d);
    } catch (e) {
      if (!ac.signal.aborted)
        setError(e instanceof Error ? e.message : "Nie udało się połączyć.");
    } finally {
      if (!ac.signal.aborted) setBusy(false);
    }
  }
  return (
    <section className="card padded gemini-settings">
      <div className="section-heading">
        <div>
          <h2>
            <Sparkles size={20} /> Połączenie z Gemini
          </h2>
          <p className="small muted">
            {connection.model || GEMINI_LABEL} · znaczenia, tłumaczenia i
            ćwiczenia
          </p>
        </div>
        <span className={"badge " + (connection.connected ? "green" : "gray")}>
          {connection.source === "account"
            ? "Własny klucz"
            : connection.source === "shared"
              ? "Gemini aktywne"
              : "Niepołączone"}
        </span>
      </div>
      {connection.connected ? (
        <>
          <div className="row between wrap">
            <p className="small">
              {connection.source === "shared"
                ? "Gemini jest gotowe automatycznie — nie musisz podawać klucza ani się logować."
                : "Własne połączenie pozostanie aktywne po odświeżeniu i na innych urządzeniach."}
            </p>
            {connection.source === "account" && (
              <button
                className="btn secondary"
                disabled={busy}
                onClick={() => update("DELETE")}
              >
                {busy ? (
                  <LoaderCircle className="spin" size={16} />
                ) : (
                  <Unplug size={16} />
                )}{" "}
                Użyj klucza domyślnego
              </button>
            )}
          </div>
          <p className="small muted">
            Model tekstowy: {connection.model}. Nagrania słów korzystają także
            z niezależnego słownika. Zapasowy model lektora Gemini:{" "}
            {connection.speechModel || "niedostępny"}.
          </p>
          {connection.limit && (
            <p className="small muted">
              Limit Fluent: pozostało {connection.limit.remaining} z{" "}
              {connection.limit.limit} zapytań na dziś. Łączenie i odświeżanie
              modeli nie zużywa tego limitu.
            </p>
          )}
          <div className="row wrap">
            <button
              className="text-link"
              disabled={busy}
              onClick={() => update("PATCH")}
            >
              Sprawdź modele ponownie w Google
            </button>
          </div>
        </>
      ) : (
        <div className="hint-box">
          Gemini powinno uruchomić się automatycznie. Odśwież stronę; jeśli
          komunikat pozostanie, spróbuj ponownie za chwilę.
        </div>
      )}
      {error && (
        <p className="error-text" role="alert">
          {error}
        </p>
      )}
      <p className="tiny muted">
        Domyślne połączenie działa po stronie serwera również w trybie gościa.
        Nie musisz podawać własnego klucza ani logować się. Obowiązują dzienne
        limity Fluent.
      </p>
    </section>
  );
}
