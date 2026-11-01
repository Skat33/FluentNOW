# Runda 9 — uwagi właściciela

## N1. „Ułóż zdanie” z polskim zdaniem i dystraktorami (agent: learning-ux)
- Nad kafelkami zawsze polskie zdanie (tłumaczenie przykładu), które trzeba ułożyć po angielsku — tak w sesji, ćwiczeniu jednego typu, jak i w teście.
- Do puli kafelków dodać **1–3 słowa-dystraktory** (zależnie od poziomu/długości zdania): wiarygodne, ale błędne — inna forma tego samego słowa (go/went/gone), mylony przyimek (in/on/at), przedimek (a/the), słowo z innego przykładu tego samego hasła. Dystraktor nie może tworzyć drugiego poprawnego zdania (np. nie dodawać „the”, jeśli zdanie z „the” też byłoby poprawne w tym miejscu… ostrożnie: tylko formy jednoznacznie błędne).
- Zdanie jest poprawne, gdy użyto dokładnie słów zdania (dystraktory zostają niewykorzystane). Feedback pokazuje poprawne zdanie i polskie tłumaczenie.
- Czysta logika w FluentKit (`SentenceScramble`) + testy.

## N2. Przełącznik grup ćwiczeń — przeprojektować (agent: learning-ux)
Obecny własny przełącznik „Słówka / Powtórki / Czytanie i gramatyka” wygląda brzydko. Zaprojektować ładniej, spójnie z DESIGN.md, np. poziomo przewijane „pigułki” z ikoną i krótką nazwą (Słówka · Powtórki · Czytanie · Gramatyka), animowane podświetlenie (`matchedGeometryEffect`), albo karty-zakładki z ikoną i liczbą dostępnych ćwiczeń. Krótkie nazwy, bez ucinania, dobrze przy Dynamic Type, natywne odczucie (haptyka zgodnie z ustawieniem). Na iOS 26 można użyć Liquid Glass dla samego przełącznika (nie dla treści).

## N3. Wyszukiwanie słów: mikrofon, podpowiedzi, literówki (agent: smart-search)
- **Mikrofon** w polach wyszukiwania słów („Dodaj słowo”, Słownik, „Szukaj tematu”): rozpoznawanie mowy (Speech framework, `SFSpeechRecognizer`, on-device gdy dostępne), język EN lub PL (przełącznik albo automatycznie: najpierw en-US, PL gdy pole ustawione na PL), uprawnienia z czytelnym opisem w Info.plist (XcodeGen `project.yml`), stan nagrywania z animacją, auto-stop po ciszy.
- **Podpowiedzi podczas pisania**: po 1–2 literach lista pasujących haseł (prefiks EN, prefiks PL tłumaczenia, potem dopasowania wewnątrz frazy), z tłumaczeniem i poziomem, posiadane wyszarzone. Szybko (indeks w pamięci, bez blokowania UI; debounce).
- **Literówki / brak słowa**: „Czy chodziło Ci o…?” — dopasowanie przybliżone (Damerau-Levenshtein z progiem zależnym od długości, + podobieństwo fonetyczne/klawiaturowe opcjonalnie), także dla polskich znaków (zażółć → zazolc). Gdy słowa nie ma w bazie: podobne słowa + opcja AI (jak dziś) jeśli włączone.
- Czysta logika w FluentKit (`FuzzyMatcher`/`ContentSearch`) + testy (wydajność na 14,7 tys. rekordów: < 30 ms na zapytanie na symulatorze).

## N4. Weryfikacja słów (agent: content-audit)
Audyt całej bazy (`topics/`, `core/`, `starter-words.json`, idiomy, gramatyka, czytanki): automatyczne kontrole spójności (to samo hasło = to samo IPA i część mowy, duplikaty zdań, tłumaczenia sprzeczne między wpisami tego samego znaczenia, `acceptedTranslations` kolidujące między różnymi znaczeniami, `focusEn` nieobecny w zdaniu, BrE), próbkowanie ręczne, sondy brakujących częstych słów (kolejne 100 częstych słów ogólnych/akademickich/frazowych — dopisać brakujące do odpowiedniego shardu core), poprawki.

## N5. Przegląd błędów aplikacji + propozycje (agent: code-qa, po N1–N3)
Pełny przegląd kodu pod kątem błędów (poprawność, crashe, wycieki, współbieżność, dostępność, wydajność), naprawa, testy; lista propozycji ulepszeń.
