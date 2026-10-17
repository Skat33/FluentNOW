# Poprawki i nowe funkcje — runda 2 (od właściciela aplikacji)

Wymagania produktowe od właściciela — mają pierwszeństwo przed wcześniejszymi decyzjami. Runda 1: `FEEDBACK-1.md` (już wdrożona).

## G1. Czytanie: najpierw tekst, potem pytania z pamięci (agent: reading-redesign)

- Etap 1 — **czytanie**: sam tekst, bez limitu czasu, bez pytań. Na dole przycisk „Jestem gotowy na pytania”.
- Etap 2 — **pytania bez tekstu**: tekst znika (nie da się do niego wrócić w trakcie pytań), pytania ABCD odpowiadane z pamięci. Po zakończeniu: wyniki, a dopiero wtedy tekst z fragmentami-dowodami jest znowu widoczny.
- Dotyczy samodzielnego ćwiczenia czytania **i** czytanki w sesji mieszanej (blok pytań z FEEDBACK-1 F4: najpierw ekran czytania, potem pytania bez tekstu).
- **Podświetlenia w tekście**: (a) słowa z mojego słownika, (b) słowa przydatne do nauki. Dotknięcie → arkusz z **tłumaczeniem w kontekście tego tekstu** (nie ogólnym), formą bazową, wymową, przyciskiem odsłuchu i „Dodaj do nauki” (dla przydatnych, których nie mam).
- Tłumaczenia kontekstowe muszą być **dokładne i offline** → dodaj do każdej czytanki w `readings.json` słowniczek kontekstowy (`glossary`: forma w tekście, lemat, tłumaczenie w tym kontekście, opcjonalnie odwołanie do wpisu bazy), ok. 8–20 pozycji na tekst, napisany i sprawdzony redakcyjnie (zmiana schematu: `CONTENT-SCHEMA.md` §5 + walidator + dekoder FluentKit; pole opcjonalne, wstecznie zgodne). Dla słów ze słownika użytkownika bez pozycji w słowniczku — wybierz znaczenie, którego przykład/scena najlepiej pasuje do zdania, albo pokaż wszystkie znaczenia z zaznaczeniem niepewności.

## G2. Nowe ćwiczenie: słówko + 4 zdjęcia (agent: practice-modes)

- Pokazane angielskie słowo (z odsłuchem), 4 zdjęcia, wskaż właściwe. Tylko dla rzeczowników konkretnych (dających się sfotografować) — filtr po `pos` + heurystyka/lista wykluczeń dla abstrakcji.
- **Źródło: wyłącznie zdjęcia z internetu** (decyzja właściciela). Darmowe, legalne źródło bez klucza API — zweryfikuj aktualne API (WebFetch): Openverse (`api.openverse.org`) lub Wikimedia Commons. Filtry: licencje pozwalające na użycie (CC0 / CC BY / CC BY-SA), formaty JPG/PNG, rozsądny rozmiar. Pod zdjęciem wymagane przy CC BY drobne przypisanie autora/licencji (np. w arkuszu „Info o zdjęciu”).
- Cache na dysku (Caches/), stałe przypisanie słowo → zdjęcie (ten sam obrazek przy kolejnych powtórkach), pobieranie w tle przed zadaniem (zero czekania w trakcie sesji). **Bez internetu ćwiczenie się nie pojawia** (sesja dobiera inne typy), bez błędów.
- Dystraktory: inne konkretne rzeczowniki (z mojego słownika lub tego samego tematu), wyraźnie różne.
- **Zgłoś zdjęcie**: po odpowiedzi (dobrej i złej) przycisk „Zdjęcie nie pasuje”. Zgłoszenie zapisuje się do **osobnego pliku** (`image-reports.json` w Application Support: słowo, znaczenie, URL zdjęcia, źródło, data, opcjonalny komentarz), zgłoszone zdjęcie nie jest już używane dla tego słowa (bierzemy następne). Eksport pliku w Ustawieniach (obok eksportu zgłoszeń ćwiczeń). Opisz w `docs/FUTURE.md` jako „do rozbudowy” (np. wysyłka zgłoszeń, własna baza zatwierdzonych zdjęć).
- Wynik liczy się do umiejętności rozpoznawania (`recognition`).

## G3. Fiszki jako osobna forma ćwiczenia (agent: practice-modes)

- Fiszki znikają z mieszanych zadań sesji (typ „Fiszka w kontekście” nie jest losowany do sesji słówek / codziennej mieszanki).
- Nowy, osobny tryb **„Fiszki”** na ekranie Nauka: talia (do powtórki → nowe → trudne; filtr kolekcji), odwracanie karty, przesunięcie w prawo/lewo = pamiętam/nie pamiętam, natychmiastowe przejście dalej (jak FEEDBACK-1 F3), licznik talii, krótkie podsumowanie. Zapis jak dotychczas (umiejętność `recognition`).
- Uwaga na progresję: dotąd nowe słowo zaczynało od fiszki. Ustal nowy pierwszy kontakt w sesji (np. „Wybierz znaczenie”) tak, by sesje dla nowych słów nadal działały i budżet był wypełniony — testy w FluentKit, aktualizacja istniejących testów progresji.

## G4. Pierwsze uruchomienie: krótki wywiad (agent: onboarding-progress)

Zastąp obecne powitanie krótkim, przyjemnym kreatorem (pomijalnym, 5–8 kroków, postęp na górze). Proponowane pytania — wszystkie mają realnie wpływać na działanie aplikacji:
1. **Po co się uczysz?** (wielokrotny wybór): praca, podróże, przeprowadzka za granicę, egzamin/szkoła, filmy/seriale/gry, rozmowy z ludźmi, rozwój osobisty → wagi tematów, polecane słówka, rejestr (np. praca → słownictwo biurowe).
2. **Twój poziom**: samoocena opisowa („rozumiem proste zdania…”) + opcjonalny **szybki test** (8–12 pytań: rozpoznanie słów z różnych poziomów + 2–3 zdania gramatyczne z banku) → startowy poziom CEFR (używany, dopóki nie ma historii odpowiedzi).
3. **Zainteresowania** (siatka 10–14 kafelków: sport, jedzenie, technologia, podróże, zdrowie, muzyka, filmy, biznes, natura, nauka…) → tematy na start i do poleceń.
4. **Jak lubisz się uczyć?** (wielokrotny wybór): pisanie, słuchanie, obrazki, czytanie tekstów, fiszki, gramatyka → domyślne tryby na ekranie Nauka i proporcje w codziennej mieszance.
5. **Ile czasu dziennie?** 5 / 10 / 15 / 20 min → cel dzienny i długość sesji.
6. **Przypomnienie** — pora (opcjonalnie, prośba o zgodę dopiero tu).
7. **Akcent** (amerykański domyślnie / brytyjski) i odsłuch próbki.
8. Podsumowanie: „Na start proponujemy N słów z tematów …” → dodaj → pierwsza sesja.
- Profil zapisany w stanie użytkownika (synchronizowany przez iCloud; pole opcjonalne, wstecznie zgodne), edytowalny później w Ustawieniach („Twój profil nauki”). Wykorzystany w: polecanych słówkach (F5), doborze trybów, onboardingowym zestawie startowym.

## G5. Doświadczenie (XP) i poziomy (agent: onboarding-progress)

- XP za rozwiązane zadania, **zbalansowane**: zależne od trudności typu zadania i umiejętności, mniej z podpowiedzią, 0 za błędną, malejące za wielokrotne powtarzanie tego samego słowa tego samego dnia (brak „farmienia”), premia za osiągnięty cel dzienny i serię (umiarkowana), za ukończoną czytankę/zestaw gramatyczny.
- Poziomy z rosnącym progiem (np. krzywa ~ n^1.5–n^2), tak by poziom coś znaczył: przy regularnej nauce 10–15 min/dzień ok. 1 poziom na kilka dni na początku, wolniej później. Nazwy rang (np. co 5 poziomów) i krótki opis „co oznacza ten poziom” (np. łączna liczba opanowanych znaczeń, dni nauki).
- **XP liczone deterministycznie z historii odpowiedzi** (`reviews` + `reviewSummaries` + historie czytania/praktyki) — bez osobnego licznika, więc iCloud nie ma konfliktów i nic nie da się „zgubić”. Czysta funkcja FluentKit + testy (balans: symulacja 30/90 dni typowego użytkownika w teście, wynik w raporcie).
- Widoczność: pasek XP i poziom na ekranie Dzisiaj, „+XP” w podsumowaniu sesji (krótka animacja, respektuje ograniczenie ruchu), szczegóły w Postępach.

## G6. Wyszukiwanie tematu: słowa już dodane na szaro (agent: onboarding-progress)

- W wynikach „Szukaj tematu” wpisy, które użytkownik już ma, są **wyszarzone i oznaczone jako zaznaczone** (ikona ✓, etykieta „Masz już”), nie da się ich ponownie dodać, licznik „Dodaj N słów” ich nie liczy. To samo w „Polecanych słówkach” i szybkim dodawaniu. Dopasowanie po odwołaniu do wpisu (`contentRef`) i po haśle+tłumaczeniu.
