# FluentNOW — do rozbudowy

Pomysły i świadomie odłożone elementy. Każdy punkt: stan obecny → kierunek rozbudowy.

## Zdjęcia w ćwiczeniu „Słowo i zdjęcie” (FEEDBACK-2 G2)

Stan: zdjęcia wyłącznie z internetu (Openverse, anonimowo, licencje CC0 / CC BY / CC BY-SA), cache na dysku (`Caches/WordImages`), trwałe przypisanie znaczenie → zdjęcie (`Application Support/WordImages/word-images.json`, tylko na tym urządzeniu), zgłoszenia „Zdjęcie nie pasuje” w `Application Support/image-reports.json` z eksportem w Ustawieniach → Eksport.

Do rozbudowy:
- **Wysyłka zgłoszeń** — dziś tylko eksport pliku JSON. Docelowo: przycisk „Wyślij zgłoszenia” (własny endpoint lub formularz), z podglądem treści i zgodą użytkownika; zgłoszenia zbiorcze od wielu osób → lista zdjęć do zablokowania.
- **Własna baza zatwierdzonych zdjęć** — plik `approved-images.json` (słowo / `contentRef` → identyfikator Openverse + przypisanie autora) przygotowany i sprawdzony redakcyjnie dla ok. 2 800 rzeczowników konkretnych z wbudowanych tematów; aplikacja brałaby najpierw zdjęcie zatwierdzone, a wyszukiwanie tylko dla słów spoza bazy. Usuwa problem wieloznaczności (np. „apple” → komputer) i limitów API.
- **Synchronizacja przypisań przez iCloud** — dziś każde urządzenie wybiera (zwykle to samo, pierwsze trafne) zdjęcie osobno i ma własną listę odrzuconych.
- **Lepsze zapytania** — zapytanie to samo hasło; można dodać kontekst tematu („apple fruit”), ograniczyć źródła (`source=wikimedia,flickr`) albo porównywać tagi z angielską definicją znaczenia.
- **Drugie źródło** — Wikimedia Commons (API bez klucza, wymagany User-Agent) jako zapas, gdy Openverse jest niedostępny lub limit dzienny (200 wyszukiwań anonimowo) się wyczerpie.
- **Ustawienie „Zdjęcia z internetu”** (włącz/wyłącz, tylko Wi-Fi) i podgląd zajętego miejsca + „Wyczyść zdjęcia”.
- **Lista wykluczeń abstrakcji** — `PictureExercise.abstractNouns` / `concreteTopics` są heurystyką; zgłoszenia pokażą, które hasła wyłączyć na stałe (najlepiej polem `picturable: false` we wpisach tematów, zmiana schematu treści).
- **Dostępność** — z VoiceOver zadanie jest pokazywane jako „Wybierz znaczenie”; można dodać opisy zdjęć (alt) z bazy zatwierdzonej.

## Fiszki jako osobny tryb (FEEDBACK-2 G3)

Stan: talia w pamięci (do powtórki → nowe ≤ 10 → trudne; filtr kolekcji; 10/20/30 kart), każda decyzja zapisywana od razu, zapomniane karty wracają raz na końcu talii.

Do rozbudowy:
- Wznawianie przerwanej talii (dziś przerwa = nowa talia; odpowiedzi i tak są zapisane).
- Odwrócony kierunek (polski → angielski) jako opcja talii (umiejętność `recall` bez wpisywania — do decyzji, jak liczyć).
- Własne talie (zaznaczone słowa ze Słownika) i fiszki z obrazkiem z bazy zdjęć.
