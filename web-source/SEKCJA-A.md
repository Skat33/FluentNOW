# Sekcja A — zmiany do weryfikacji

Zakres: wyłącznie A1–A7. Pozostałe sekcje nie zostały rozpoczęte.

## Wynik
- A1: HTTP 400 → REQUEST, 401/403 → KEY; limity Fluent i Google mają osobne komunikaty.
- A2: odczyt treści błędu Google, diagnostyka HTTP + error.status w produkcji, dodatkowo zredagowane error.message w trybie development. Logi zachowują odpowiedź dostawcy po usunięciu klucza (limit 8 KB).
- A3: przy łączeniu aplikacja wykonuje GET models z paginacją i filtrem supportedGenerationMethods=generateContent, a następnie rzeczywisty test generowania. Bieżąca dokumentacja REST potwierdza store, responseJsonSchema i enum LOW, więc zachowano te pola. thinkingLevel jest pomijany przy modelach 2.5. Nie ma dowodu, że store powodował zgłoszony problem.
- A4: lista modeli zapasowych dla tekstu i TTS; automatyczna zmiana wyłącznie po 404. Wybrany model jest zapisany na koncie i widoczny w Ustawieniach. Katalog modeli nie gwarantuje dostępu do generowania ani darmowego limitu.
- A5: błędy origin i rozmiaru wejścia zwracają JSON. Klient radzi sobie z pustym JSON, HTML i awarią bramy, bez pokazywania SyntaxError. Logi niezgodnego origin zawierają origin oraz oczekiwany host.
- A6: PUT i DELETE danych oraz wszystkie mutacje Gemini wymagają ścisłego, zgodnego Origin. Nie dodano wyjątków opartych na niezaufanych nagłówkach forwarded lub hoście iframe.
- A7: wybrano szyfrowany klucz własny na koncie, bez zależności od wspólnego klucza i jego rozliczeń. AES-256-GCM, osobny klucz wyprowadzany przez HKDF z identyfikatora konta, dodatkowe uwierzytelnienie właściciela. Szyfrogram jest w oddzielnej tabeli D1; sekret główny w konfiguracji serwera. Odświeżenie odczytuje stan połączenia, a dalsze żądania nie wysyłają klucza z przeglądarki. Rozłączenie i usunięcie danych usuwają klucz. Eksport pozostaje bez sekretów.

## Co ustalono z logów
Ostatnie zgłoszone POST /api/gemini zwracały lokalne HTTP 400 po 1–2 ms. To wcześniejszy etap niż wywołanie dostawcy; oryginalny kod odrzucał format klucza. Origin był zgodny. Klucze są w logach zredagowane, więc nie można z nich ustalić konkretnego problemu z wpisaną wartością. Nowy formularz przesyła klucz w JSON, waliduje dane osobno i rozróżnia błąd lokalny od odpowiedzi Google.

## Weryfikacja
21 testów przeszło, w tym testy tras na rzeczywistym SQLite z migracjami, szyfrowanie, izolacja kont, usuwanie, fallback 404, diagnostyka i odpowiedzi nie-JSON. TypeScript przeszedł.
Brak klucza Gemini dostępnego w tym środowisku: nie wykonano tu rzeczywistego żądania z kluczem użytkownika. Nie deklarujemy, że model lub rozliczenia na tym kluczu zostały zweryfikowane. Dokona tego formularz po ponownym połączeniu; nie wklejaj klucza do rozmowy.

Do sprawdzenia na stronie:
1. Ustawienia → Połączenie z Gemini → Połącz i zapisz.
2. Sprawdź pokazany model, dodaj słowo, następnie odśwież stronę i sprawdź, czy połączenie pozostało.
3. Jeśli Google odmówi, komunikat zawiera HTTP i status Google — przekaż komunikat bez klucza.
4. Usuń połączenie, odśwież: status powinien być niepołączony.

Źródła: https://ai.google.dev/api/generate-content oraz https://ai.google.dev/api/models (sprawdzone 2026-09-09).

## Zmienione i dodane pliki
- `README.md`
- `SEKCJA-A.md`
- `app/api/gemini/route.ts`
- `app/api/speech/route.ts`
- `app/api/state/route.ts`
- `app/api/tutor/route.ts`
- `app/fluent.tsx`
- `app/gemini-settings.tsx`
- `app/tutor-ui.tsx`
- `app/use-voice.ts`
- `db/schema.ts`
- `drizzle/0002_massive_iron_fist.sql`
- `drizzle/meta/0002_snapshot.json`
- `drizzle/meta/_journal.json`
- `lib/gemini-account.ts`
- `lib/gemini-client.ts`
- `lib/gemini.ts`
- `lib/key-vault.ts`
- `lib/request-origin.ts`
- `lib/tutor-server.ts`
- `public/plan-produktu.md`
- `scripts/test-learning.mjs`
- `tests/fixtures/gemini-runtime.mjs`
- `tests/gemini-routes.test.mjs`
- `tests/gemini.test.mjs`
- `types/cloudflare.d.ts`
