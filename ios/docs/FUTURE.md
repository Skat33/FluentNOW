# FluentNOW — do rozbudowy

Pomysły i świadomie odłożone elementy. Każdy punkt: stan obecny → kierunek rozbudowy.

## „Słowo i zdjęcie” — W BUDOWIE (FEEDBACK-4 I2): ilustracje AI per słowo w bazie

**Stan (2026-10-18):** tryb wyłączony jedną flagą `PictureExercise.isEnabled = false` (FluentKit `Sessions/PictureExercise.swift`). Skutki: zadanie zdjęciowe nigdy nie jest losowane do sesji (`SessionBuilder.chooseType`), `makeSession(mode: .pictures)` zwraca pustą sesję, karta „Słowa i obrazki” na ekranie Nauka jest wyszarzona z etykietą „W budowie” (dotknięcie → krótka informacja), preferencja „Obrazki” z profilu nie przesuwa karty ani nie uruchamia trybu, `WordImagePrefetcher.request()` nic nie pobiera (status „wyłączone”), a stare przerwane zadania zdjęciowe są pokazywane jako „Wybierz znaczenie”. Cały kod zdjęć (Openverse, weryfikacja Vision, zgłoszenia) zostaje — powrót = `isEnabled = true`.

**Plan: ilustracja generowana przez AI dla każdego znaczenia, zapisana w bazie treści.**
1. **Model danych:** opcjonalne pole we wpisie tematu (`CONTENT-SCHEMA.md`): `image: { file: "<id>.webp", prompt: "...", style: "flat-v1", reviewed: true, alt: "…po polsku" }`; `Meaning.contentRef` już wskazuje wpis, więc znaczenie znajdzie obrazek bez nowych pól w `LearnerState` (iCloud bez zmian). Dla słów spoza bazy (AI, własne) — brak obrazka, zadanie nie jest losowane.
2. **Generowanie (offline, w `ios/tools/`):** skrypt Node buduje prompt z hasła, definicji EN, sceny kategorii i części mowy (rozróżnia sensy: „bat” zwierzę vs kij — każdy `entry id` ma własny obrazek), jeden spójny styl (płaska ilustracja, jasne tło, bez tekstu i liter na obrazku), 512×512. Wynik + prompt + wersja stylu w manifeście; ponowne generowanie tylko dla zmienionych wpisów.
3. **Kontrola jakości:** przegląd redakcyjny partiami (galeria HTML z hasłem, tłumaczeniem i obrazkiem; „odrzuć / wygeneruj ponownie”), automatycznie: brak tekstu na obrazku (OCR), podobieństwo do innych obrazków tego samego zestawu (żeby dystraktory były wyraźnie różne). Do aplikacji trafiają tylko `reviewed: true`.
4. **Dostarczanie:** obrazki nie w bundlu (≈ 1 400–2 800 × ~30 KB WebP/HEIC ≈ 40–80 MB) — On-Demand Resources per grupa tematów albo pobieranie z CDN z cache w `Caches/` i weryfikacją sumy SHA-256 z manifestu; offline działają obrazki już pobrane. `WordImageService` dostaje drugie źródło („baza”) przed Openverse; Openverse zostaje tylko jako zapas albo znika.
5. **Ćwiczenie:** bez zmian w FluentKit poza źródłem gotowości (`readyMeaningIDs` z manifestu zamiast z cache Openverse); dystraktory nadal `PictureExercise.distractors`. Dostępność: `alt` z bazy zamiast zamiany na „Wybierz znaczenie” przy VoiceOver.
6. **Licencje:** obrazki własne (wygenerowane na nasze zlecenie) — bez atrybucji Openverse; w Ustawieniach informacja „Ilustracje wygenerowane przez AI i sprawdzone przez redakcję”.

## Zdjęcia w ćwiczeniu „Słowo i zdjęcie” (FEEDBACK-2 G2) — kod zachowany, obecnie wyłączony

Stan: zdjęcia wyłącznie z internetu (Openverse, anonimowo, licencje CC0 / CC BY / CC BY-SA), cache na dysku (`Caches/WordImages`), trwałe przypisanie znaczenie → zdjęcie (`Application Support/WordImages/word-images.json`, tylko na tym urządzeniu), zgłoszenia „Zdjęcie nie pasuje” w `Application Support/image-reports.json` z eksportem w Ustawieniach → Eksport.

Weryfikacja (image-verify, 2026-10-18): zdjęcie trafia do ćwiczenia dopiero po trzech warstwach — `WordImageEligibility` (słowo w ogóle da się pokazać), dopasowanie tytułu/tagów z zapytaniem zależnym od znaczenia (`WordImageSenses`, najpierw źródła stockowe `stocksnap,rawpixel,wikimedia`) i klasyfikator Vision na urządzeniu (`WordImageVerifier`, etykiety `VNClassifyImageRequest`). Po 3 wyszukiwaniach bez zweryfikowanego zdjęcia znaczenie jest trwale „bez zdjęcia”. Stare przypisania są ponownie sprawdzane w tle, a niezweryfikowane zdjęcia usuwane. Zgłoszenia zawierają etykiety Vision i powód akceptacji. Szczegóły: `docs/reports/image-verify.md`.

Do rozbudowy:
- **Wysyłka zgłoszeń** — dziś tylko eksport pliku JSON. Docelowo: przycisk „Wyślij zgłoszenia” (własny endpoint lub formularz), z podglądem treści i zgodą użytkownika; zgłoszenia zbiorcze od wielu osób → lista zdjęć do zablokowania.
- **Własna baza zatwierdzonych zdjęć** — plik `approved-images.json` (słowo / `contentRef` → identyfikator Openverse + przypisanie autora) przygotowany i sprawdzony redakcyjnie dla ok. 2 800 rzeczowników konkretnych z wbudowanych tematów; aplikacja brałaby najpierw zdjęcie zatwierdzone, a wyszukiwanie tylko dla słów spoza bazy. Usuwa problem wieloznaczności (np. „apple” → komputer) i limitów API.
- **Synchronizacja przypisań przez iCloud** — dziś każde urządzenie wybiera (zwykle to samo, pierwsze trafne) zdjęcie osobno i ma własną listę odrzuconych.
- **Lepsze zapytania** — zrobione częściowo: tabela znaczeń wieloznacznych (`WordImageSenses`: mouse, bat, crane, apple, pen, glasses…), najpierw źródła stockowe, potem wszystkie, na końcu synonim. Dalej: rozszerzać tabelę na podstawie zgłoszeń (kod `vision-conflict` / `metadata-only` w eksporcie pokazuje, gdzie warstwy zawodzą), porównywać tagi z angielską definicją znaczenia.
- **Pole `picturable` / `imageQuery` we wpisach tematów** — dziś lista wykluczeń (`WordImageEligibility`) i tabela znaczeń żyją w aplikacji; docelowo redakcyjne pola w treści (zmiana schematu, `CONTENT-SCHEMA.md`) i przeniesienie filtra do FluentKit `PictureExercise.isPicturable`, żeby liczniki kart „Słowa i obrazki” od razu pomijały wykluczone słowa.
- **Nowsze API Vision** — na iOS 18+ `ClassifyImageRequest` (Swift, async); można też dodać `VNGenerateImageFeaturePrintRequest`, żeby odrzucać zdjęcia zbyt podobne do siebie w jednym zadaniu, albo — na iOS 26 — zapytać Foundation Models z opisem etykiet, czy zdjęcie pasuje do znaczenia.
- **Próg pewności z danych** — progi (`strongMatch` 0,5, `weakMatch` 0,15, konflikty 0,6–0,9) ustawione na podstawie dokumentacji i zdrowego rozsądku; warto je dostroić na eksporcie zgłoszeń (etykiety Vision są w każdym wpisie). Zmiana reguł = podbicie `WordImageVerifier.rulesVersion` (cache sprawdzi się ponownie sam).
- **Drugie źródło** — Wikimedia Commons (API bez klucza, wymagany User-Agent) jako zapas, gdy Openverse jest niedostępny lub limit dzienny (200 wyszukiwań anonimowo) się wyczerpie.
- **Ustawienie „Zdjęcia z internetu”** (włącz/wyłącz, tylko Wi-Fi) i podgląd zajętego miejsca + „Wyczyść zdjęcia”.
- **Lista wykluczeń abstrakcji** — `PictureExercise.abstractNouns` / `concreteTopics` są heurystyką; aplikacja dokłada `WordImageEligibility` (lista haseł + role osób + reguły -ing/-ist/-ian/-ee + nagłówki typu „party”, „sale”); z 2 550 różnych haseł, które przepuszcza `isPicturable`, zostaje 1 354. Zgłoszenia pokażą, co jeszcze wyłączyć.
- **Dostępność** — z VoiceOver zadanie jest pokazywane jako „Wybierz znaczenie”; można dodać opisy zdjęć (alt) z bazy zatwierdzonej.

## Fiszki jako osobny tryb (FEEDBACK-2 G3)

Stan: talia w pamięci (do powtórki → nowe ≤ 10 → trudne; filtr kolekcji; 10/20/30 kart), każda decyzja zapisywana od razu, zapomniane karty wracają raz na końcu talii.

Do rozbudowy:
- Wznawianie przerwanej talii (dziś przerwa = nowa talia; odpowiedzi i tak są zapisane).
- Odwrócony kierunek (polski → angielski) jako opcja talii (umiejętność `recall` bez wpisywania — do decyzji, jak liczyć).
- Własne talie (zaznaczone słowa ze Słownika) i fiszki z obrazkiem z bazy zdjęć.

## Nowe ćwiczenia: rozsypanka, dopasuj pary, rozumienie ze słuchu (FEEDBACK-4 I2)

Stan: opis w `docs/reports/new-exercises.md`.

Do rozbudowy:
- Rozsypanka: akceptowanie poprawnych alternatywnych szyków (np. położenie przysłówka) — dziś liczy się tylko kolejność ze zdania przykładowego; przeciąganie kafelków (dziś dotknięcia).
- Dopasuj pary: wariant z obrazkami (po powrocie ilustracji) i z wymową (lektor czyta słowo, dobierz tłumaczenie).
- Rozumienie ze słuchu: drugi etap „wpisz, co usłyszałeś” dla całego zdania; wybór głosu żeńskiego/męskiego na zmianę.
