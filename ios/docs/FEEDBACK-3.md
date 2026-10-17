# Runda 3 — uwagi z testów na symulatorze (iPhone 17 Pro, iOS 26.2)

Wymagania właściciela — pierwszeństwo przed wcześniejszymi decyzjami.

## H0. Zrobione przez koordynatora
- Zadanie gramatyczne w sesji łączonej nie pokazywało polskiego bezokolicznika: „we ________ the terms” zamiast „we ________ (wynegocjować) the terms”. Przyczyna: `PracticeBuilder.practiceQuestion(from:)` wycinał „(hintPl)” (port ze strony, gdzie było tylko ABCD). Usunięte — bezokolicznik zostaje zawsze.
- Logi `CHHapticPattern … hapticpatternlibrary.plist` i `RTIInputSystemClient …` to szum symulatora (brak silnika haptyki, klawiatura systemowa), nie błędy aplikacji.

## H1. „Co oznacza wyróżnione słowo?” — pole tekstowe i opcje naraz (agent: study-polish)
Zrzut: zadanie „Rozpoznawanie znaczenia” (standby) pokazuje jednocześnie pole tekstowe (użytkownik wpisał „kontrola osobista”) i 4 opcje — wpisanie tekstu podświetla/zaznacza pasującą opcję. Myli. **Ma być**: gdy opcje są widoczne → tylko wybór dotknięciem (1–4 na klawiaturze), bez pola tekstowego. Sprawdź wszystkie typy zadań w sesji słówek i łączonej pod kątem podobnych podwójnych mechanizmów odpowiedzi.

## H2. Zadań ze zdjęciami nie widać (agent: study-polish)
Właściciel nie zobaczył ani jednego zadania „Słowo i zdjęcie”. Zdiagnozuj przyczynę (prawdopodobnie: tylko po pierwszym kontakcie ze słowem + wymóg, że 4 zdjęcia są już w cache, a prefetch nie startuje wystarczająco wcześnie / w ogóle; ewentualnie limity lub błąd zapytań Openverse — zweryfikuj żądanie na żywo przez WebFetch). **Ma być**:
- prefetch zdjęć startuje po uruchomieniu aplikacji (w tle, po pierwszej klatce), po dodaniu słów i przed sesją; zadanie zdjęciowe może pojawić się już przy drugim kontakcie ze słowem;
- osobny tryb „Słowa i obrazki” na ekranie Nauka (ćwiczy tylko zadania zdjęciowe dla słów z gotowymi zdjęciami; jeśli zdjęć jeszcze nie ma — pokaż postęp pobierania i komunikat, a bez internetu jasny komunikat);
- w Ustawieniach (np. „O aplikacji” lub „Dane”) diagnostyka: liczba słów ze zdjęciami / w kolejce / błędy ostatniego pobrania.

## H3. Fiszki jak w Quizlecie (agent: study-polish)
- Przód karty: **losowo** słowo po polsku albo po angielsku (sam wyraz/zwrot, duża czcionka, nic więcej — bez kontekstu, poziomu, IPA). Dotknięcie → obrót karty z animacją → druga strona: odpowiednik w drugim języku (dla angielskiego dodatkowo przycisk odsłuchu).
- Opcjonalny przycisk „Pokaż przykład” (dopiero na życzenie) — przykładowe zdanie z tłumaczeniem.
- Przesunięcie / przyciski: „Pamiętam” / „Jeszcze nie” → zapis i natychmiast następna karta (jak dotychczas).

## H4. Polecane: rodzina wyrazów (agent: word-family)
Gdy użytkownik ma dane słowo, a w bazie są wyrazy pokrewne z tej samej rodziny (rzeczownik/przymiotnik/przysłówek/czasownik: decide → decision, decisive, decisively; comfort → comfortable, comfortably), polecaj je w „Polecanych słówkach” z uzasadnieniem „Z rodziny słowa *decide*, które znasz”. Tylko przydatne (częstotliwość `very_common`/`common`/`less_common` dla rodziny), poziom ≤ docelowy+1. Wykrywanie rodzin: heurystyka morfologiczna na haśle (wspólny rdzeń + znane sufiksy angielskie: -tion/-sion, -ment, -ness, -ity, -er/-or, -ful, -less, -ous, -ive, -able/-ible, -al, -ly, -ize, -en, zmiany typu y→i, e-drop, podwojenie spółgłoski) z odsiewem fałszywych par (lista wyjątków), plus — jeśli tanio — pole `forms` wpisu. Czysta funkcja FluentKit + testy na prawdziwym `dictionary-index.json`; w raporcie przykładowe wykryte rodziny i odsetek fałszywych trafień z próbki.
