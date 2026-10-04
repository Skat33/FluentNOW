# Rola: ui-learning — nauka: sesje, ćwiczenia, czytanie, gramatyka

Fala 2. Obszar: `ios/FluentNOW/Features/Study/`, `Features/Reading/`, `Features/Practice/`. Raport: `ios/docs/reports/ui-learning.md`.

Przed startem przeczytaj: brief, `ios/docs/CONTRACTS.md`, `ios/docs/DESIGN.md`, raport core-engine. Referencja zachowania: `web-source/app/fluent.tsx` (część Ćwiczenia/sesja), `app/tutor-ui.tsx` (czytanie, praktyka), `app/combined-practice.tsx`, `app/production-practice.tsx`, `app/exercise-*.tsx`, `app/hint-disclosure.tsx`, `app/use-answer-scroll.ts`, testy `tests/ui-components.test.mjs`.

## Cel

Najlepsza część aplikacji: sesja nauki ma być płynna jak w najlepszych aplikacjach do nauki języków — bez opóźnień między zadaniami, z natychmiastową informacją zwrotną, przyjemną haptyką i zero frustracji (np. klawiatura nie zasłania pola, autokorekta nie psuje odpowiedzi).

## Zakres

1. **Ekran „Nauka” (start)** — „Na co masz dziś ochotę?”: tryby (`StudyMode`: codzienna mieszanka, tryb pomyłek, słowa w parach, czytanie, gramatyka, idiomy, produkcja gramatyczna, miks językowy) — wielokrotny wybór jak na stronie, „Ile masz czasu?” 5/10/15 min, losowa kolejność; kafelek wznowienia przerwanej sesji; stan pusty, gdy brak słów (CTA → dodaj słowa/temat).
2. **Silnik sesji (`SessionView` + `SessionModel`)** — prowadzi `CombinedSession`/`VocabSession` przez `LearningStore`; pasek postępu, licznik czasu (od 00:00, stop po odpowiedzi, bez ciągłego odczytu przez VoiceOver — jak RAPORT D), nagłówek „Rodzaj ćwiczenia”, przycisk zamknij (sesja zostaje zapisana do wznowienia), zgłoś błąd w zadaniu (zapis lokalny przez store). Przejścia między zadaniami bez migotania, preładowanie następnego zadania.
3. **Pięć typów zadań słownikowych**: fiszka w kontekście (odsłoń → oceń pewność; gest przesunięcia), polski → angielski (pole tekstowe), uzupełnij zdanie (luka z FluentKit `clozeText`), wybierz znaczenie (4 opcje z `meaningOptions`), posłuchaj i zapisz (dyktando, przycisk odtwórz/wolniej). Dla każdego: podpowiedź i druga próba, „Pokaż warianty”, wyjaśnienie odpowiedzi, wybór pewności, `HighlightedText` z pogrubionym wyrażeniem, odtwarzanie audio tylko tam, gdzie `exercisePromptAudioAllowed`. Pola tekstowe: `.autocorrectionDisabled()`, `.textInputAutocapitalization(.never)`, klawiatura angielska tam, gdzie się da (`.keyboardType(.asciiCapable)` dla odpowiedzi po angielsku — ale pozwól na apostrof typograficzny), `submitLabel(.done)`, focus automatyczny, przewinięcie do odpowiedzi (jak `use-answer-scroll`).
4. **Gramatyka/idiomy (`Practice/`)** — pytania ABCD i pytania z wpisywaniem (`format: input`), wyjaśnienie + tłumaczenie po odpowiedzi; produkcja gramatyczna: luka + polski bezokolicznik, ocena `gradeProduction` z diagnozą (zły czas/aspekt/strona/zgodność/słowo/pisownia), reguła ujawniana po odpowiedzi; podsumowania i historia.
5. **Czytanie (`Reading/`)** — tekst z czytelną typografią (Dynamic Type, wygodna szerokość), podświetlanie słów z mojego słownika (`readingTokens`) z podglądem tłumaczenia po dotknięciu, pytania ABCD, wyniki z fragmentem-dowodem, zapis wyniku (`applyReadingResults` — nie podnosi automatycznie wyniku słów, jak strona), odsłuch akapitu.
6. **Wymowa (nowość)** — opcjonalny przycisk „Powiedz to” w fiszce/po odpowiedzi: `PronunciationService`, wynik orientacyjny z uczciwym opisem; nie wpływa na opanowanie.
7. **Podsumowanie sesji** — „Mały krok za Tobą.”: poprawne/wszystkie, czas, umiejętności, które wzrosły, słowa do powtórki, CTA „Jeszcze 5 minut”, delikatna animacja (respektuje reduce motion), haptyka sukcesu.
8. **Klawiatura i dostępność** — działa z klawiaturą sprzętową na iPadzie (Enter = sprawdź, 1–4 = wybór opcji), VoiceOver czyta zadanie, opcje i wynik, Dynamic Type nie łamie układu (ScrollView), kontrast.

## Jakość

- Model sesji (`@Observable @MainActor`) oddzielony od widoków; logika oceny wyłącznie z FluentKit/`LanguageAssistant` (żadnej własnej logiki oceniania w UI).
- Żadnych opóźnień: ocena lokalna natychmiast; ocena AI (gdy niejednoznaczna) asynchroniczna z możliwością pominięcia, timeout, bez blokowania.
- Każdy widok ma `#Preview` na `AppEnvironment.preview`.
- Małe widoki (brief §5: duże `body` = problemy kompilatora).
