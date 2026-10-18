# FluentNOW — do rozbudowy

Pomysły i świadomie odłożone elementy. Każdy punkt: stan obecny → kierunek rozbudowy.

## Zdjęcia w ćwiczeniu „Słowo i zdjęcie” (FEEDBACK-2 G2)

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
