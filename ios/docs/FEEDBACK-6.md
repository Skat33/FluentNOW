# Runda 6 — układ Nauki, polecane, czytanie, test poziomujący

Wymagania właściciela — pierwszeństwo przed wcześniejszymi decyzjami.

H0 (zrobione przez koordynatora): crash przy przełączaniu kart (`SDFStyle.distanceRange`, EXC_BREAKPOINT) — `SpeakButton` używał interaktywnego Liquid Glass w treści list; teraz pełne kółko. **Zasada dla wszystkich agentów: żadnego `glassEffect`/`fluentGlass` w wierszach list, kartach treści, stronach przewijanych ani w widokach z transformacjami** — szkło tylko w pasku nawigacji/narzędzi i systemowych stylach przycisków.

## K1. Ekran Nauka — nowy układ (agent: study-layout)
1. Kolejność od góry: **Fiszki** (karta talii), potem **Ćwiczenia** (kafelki pojedynczych typów z FEEDBACK-5 J1 — zostają), potem **Test** (karta z K4; widok dostarcza agent test-mode jako `StudyTestCard`, wstawiasz go w układ).
2. **Usuń całkowicie** sekcję „Ile masz czasu?” z wyborem wielu trybów i losową kolejnością (sesja łączona z wieloma trybami znika z UI; kod FluentKit może zostać, jeśli używają go inne miejsca — np. „Zaczynam naukę” na Dzisiaj; zachowaj działanie przycisku na Dzisiaj, kierując go do sensownej sesji codziennej).
3. **Usuń paski/karty „Kontynuuj …”** z ekranu Nauka. Postęp przerwanego ćwiczenia nadal zapisuje się w tle. Gdy użytkownik dotknie kafelka ćwiczenia (albo fiszek), dla którego istnieje zapisana przerwana sesja → okno wyboru: **„Kontynuuj, gdzie skończyłem”** albo **„Zacznij od nowa”** (nowa sesja z **nowymi zdaniami/przykładami**, nie tymi samymi co w przerwanej; przerwana sesja zostaje porzucona — odpowiedzi już udzielone są zapisane w historii).

## K2. Słownik → Polecane (agent: study-layout)
- Strona polecanych mieści się na ekranie **bez przewijania w pionie**: liczba słów na stronie dobrana do dostępnej wysokości (np. `GeometryReader`/`ViewThatFits`, min. 3, maks. 6), wiersze zwięzłe (hasło, tłumaczenie, poziom, krótkie uzasadnienie w 1 linii, przykład opcjonalnie pod „i”), zmiana strony tylko przesunięciem w bok (lub kropki/strzałki).
- **„Odśwież propozycje” na górze** (np. przycisk w nagłówku segmentu), nie pod listą.
- Sprawdź, że przesuwanie stron nie koliduje z przewijaniem — tu nie ma już przewijania pionowego na stronie.

## K3. Czytanie — wyraźniejsze polecane słowa (agent: study-layout)
W tekście czytanki słowa przydatne (słowniczek) mają być **pogrubione i w innym kolorze** niż zwykły tekst i niż słowa z mojego słownika (np. słowa z mojego słownika: fiolet + tło; polecane: pogrubione + wyraźny drugi kolor, np. teal/niebieski, z delikatnym tłem); legenda zgodna. Kontrast AA w jasnym i ciemnym motywie.

## K4. Test (agent: test-mode)
Zamiast wielotrybowej sesji z losowaniem — **Test** (ok. 15–20 min), przez który użytkownik przechodzi przez **każdy typ zadania**, **dopasowany do jego poziomu**, **bez możliwości cofnięcia** do poprzednich pytań.

Projekt (koordynator, do wdrożenia):
- **Struktura (~30 pytań, ok. 18 min):** bloki w stałej kolejności, w bloku pytania mieszane: Wybierz znaczenie (4), Przypomnij sobie PL→EN (4), Uzupełnij lukę (4), Ułóż zdanie (3), Dopasuj pary (1 plansza = 5 par), Zrozum ze słuchu (4), Dyktando (3), Gramatyka z banku na poziomie (4), Krótka czytanka na poziomie (1 tekst, 3 pytania, czytanie → pytania z pamięci jak w czytaniu). „Słowo i zdjęcie” pominięte (w budowie).
- **Dopasowanie do poziomu:** poziom bazowy = szacowany poziom (`LevelEstimator` / analiza; bez historii — poziom z wywiadu `ProfileLevel`). Słowa tylko z pasma **[poziom−1, poziom]** (np. B1 → A2–B1, z małą domieszką poziomu wyżej, maks. 15%, tylko po dobrej passie). Źródła słów: najpierw **moje słowa** z tego pasma (już ćwiczone), uzupełnienie słowami z bazy z pasma i z moich tematów (frequency `very_common`/`common`). Gramatyka i czytanka z banku na poziomie bazowym.
- **Lekka adaptacja w trakcie:** 3 poprawne z rzędu → kolejne pytanie z górnej części pasma; 2 błędy z rzędu → z dolnej. Nigdy poza pasmo ±1.
- **Zasady testu:** brak podpowiedzi, brak „Pokaż warianty”, brak informacji poprawne/błędne po każdym pytaniu (tylko „Dalej”); **nie można wrócić**; widoczny pasek postępu i licznik czasu (orientacyjny, bez twardego limitu); wyjście w trakcie → test zapisany, przy ponownym wejściu „Kontynuuj test” (od bieżącego pytania, bez cofania) albo „Porzuć”.
- **Wynik:** wynik %, wynik per typ zadania i per umiejętność, szacowany poziom z testu (z uczciwym opisem), lista błędów z poprawnymi odpowiedziami, przycisk „Dodaj błędne słowa do powtórek” / „Dodaj nowe słowa do nauki” (dla słów z bazy). Historia testów w Postępach (data, wynik, poziom).
- **Wpływ na naukę:** odpowiedzi na moje słowa zapisują się przez `Scheduler.recordAnswer` (FSRS) jak zwykłe powtórki; słowa z bazy, których nie mam, nie są zapisywane do nauki, dopóki ich nie dodam.
- Logika (wybór pytań, pasmo, adaptacja, punktacja) w FluentKit jako czyste funkcje z testami (deterministyczne z wstrzykniętym RNG); stan testu w `LearnerState` (opcjonalne pole, wsteczna zgodność, synchronizacja jak inne sesje).
