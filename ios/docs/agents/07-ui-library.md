# Rola: ui-library — Dzisiaj, Słownik, Dodawanie, Tematy, Kolekcje, Postępy, Ustawienia

Fala 2. Obszar: `ios/FluentNOW/Features/{Today,Words,AddWord,Topics,Collections,Stats,Settings}/`. Raport: `ios/docs/reports/ui-library.md`.

Przed startem przeczytaj: brief, `ios/docs/CONTRACTS.md`, `ios/docs/DESIGN.md`, raport core-engine. Referencja: `web-source/app/fluent.tsx` (Dzisiaj, Słownik, Kolekcje, Postępy, Ustawienia), `app/tutor-ui.tsx` (szybkie dodawanie, tematy), `app/vocabulary-preparation.tsx`, `app/gemini-settings.tsx`, `public/plan-produktu.md` §2.

## Cel

Ekrany, które sprawiają, że dodawanie słówek i śledzenie postępu jest szybsze i przyjemniejsze niż na stronie. Kluczowa przewaga: **dodanie słowa lub całego tematu w kilka sekund, offline**.

## Zakres

1. **Dzisiaj** — pierścień dziennego celu, karta sesji (fioletowa, „Zaczynam naukę” → start codziennej mieszanki jednym dotknięciem), liczba powtórek na dziś, seria dni, „Twój tydzień” (mini-histogram), kolekcje/tematy w toku, ostatnio dodane, rekomendacje „Gotowość na krok dalej?” (trudniejsze pokrewne słowa po opanowaniu), stan pierwszego uruchomienia (onboarding: wybierz poziom i 1–3 tematy na start → słowa dodane → pierwsza sesja).
2. **Słownik** — lista słów z wyszukiwaniem (`.searchable`, PL i EN), filtry (status, poziom, kolekcja, trudne, archiwum), sortowanie, sekcje, akcje przesunięcia (archiwizuj, oznacz trudne), szybkie odtworzenie wymowy. Szczegóły słowa: znaczenia z wynikami 5 umiejętności (`—` dla niećwiczonych), przykłady z tłumaczeniami i pogrubieniem, IPA, formy, kolokacje, synonimy/antonimy, notatka, następny termin powtórki, historia odpowiedzi; edycja (wiele znaczeń, przykłady, rejestr, tagi, kolekcja) z walidacją; archiwizacja/przywrócenie; usunięcie z potwierdzeniem.
3. **Szybkie dodawanie** — pole: wpisz słowo (EN lub PL) → natychmiastowe propozycje z `ContentSearch` (wbudowany słownik ~kilka tysięcy wpisów) → wybierz jedno lub kilka znaczeń (żadne nie jest zaznaczone automatycznie, jak strona) → zapisz (automatyczna kolekcja). Brak w bazie → (a) `LanguageAssistant` jeśli skonfigurowany (z oznaczeniem „propozycja AI”, walidacją, możliwością edycji), (b) ręczny formularz. Ponowne dodanie tego samego znaczenia nie kasuje postępu. Pole na podsumowanie „Dodano 3 znaczenia do kolekcji Lotnisko”.
4. **Tematy** — przeglądarka tematów z `topics/index.json`: grupy, wyszukiwanie (również po `aliases`), karta tematu (ikona SF Symbol, liczba słów, rozkład CEFR). Ekran tematu: kategorie, lista wpisów z tłumaczeniem/poziomem, zaznacz wszystkie / kategorię / filtruj poziomem („tylko A2–B1”), podgląd wpisu (przykłady, wymowa), „Dodaj N słów do nauki” — dodanie w tle, z postępem i bez blokowania UI; oznaczenie wpisów już dodanych.
5. **Kolekcje** — „Twoje kolekcje”: postęp kolekcji, słowa kolekcji, „Ćwicz tę kolekcję”, tworzenie/zmiana nazwy/usuwanie (słowa zostają), „Podobne słowa, inna historia” (pary mylone).
6. **Postępy** — Swift Charts: tydzień (słupki), kalendarz aktywności (heatmapa), umiejętności, postęp wg poziomu CEFR, tygodniowy przyrost opanowanych, prognoza powtórek (7 dni), „Warto do nich wrócić” (trudne słowa → sesja pomyłek), wyniki czytania i gramatyki, szacowany poziom CEFR z uczciwym opisem pewności. Wykresy dostępne (`accessibilityLabel`/audio graphs domyślne Charts), dane liczone w FluentKit/store, nie w `body`.
7. **Ustawienia** — cel dzienny, pora przypomnienia + włącz/wyłącz (ReminderService, prośba o zgodę), akcent/głos (lista głosów z odsłuchem), wolne tempo, motyw (system/jasny/ciemny), iCloud: status synchronizacji, AI: wybór dostawcy (offline / Apple on-device gdy dostępne / Gemini z polem klucza → Keychain, przycisk „Połącz” z testem połączenia i czytelnym błędem), import (JSON ze strony/aplikacji, CSV/TSV z podglądem), eksport (JSON, CSV Anki) przez `ShareLink`, eksport zgłoszonych błędów, usuń wszystkie dane (podwójne potwierdzenie), „O aplikacji” (wersja, licencje treści, prywatność: co trafia do Google przy Gemini).

## Jakość

- Listy: `List` z stabilnymi `id`, bez ciężkich obliczeń w wierszu; wyszukiwanie z debounce, wyniki liczone poza głównym wątkiem.
- Każdy ekran: stan pusty, ładowania, błędu (DESIGN.md).
- Formularze: walidacja na bieżąco, przycisk zapisu nieaktywny przy błędach, brak utraty wpisanych danych przy przypadkowym zamknięciu arkusza (`interactiveDismissDisabled` gdy są zmiany).
- Każdy widok ma `#Preview` na `AppEnvironment.preview`. Małe widoki.
