# Fluent v36 — większy bank gramatyki i historia widzianych zdań

## Wielkość i użycie banku
- 300 nowych zdań na każdy poziom A1, A2, B1, B2, C1, C2 (1800 nowych).
- Zachowano również po 12 wcześniejszych zadań: dostępne **312 zdań na poziom, 1872 łącznie**.
- Każde nowe zadanie zawiera stabilny identyfikator, zdanie z luką, polską podpowiedź, pełne tłumaczenie, konstrukcję, poprawną odpowiedź, dopuszczalne alternatywy, trzy dystraktory i wyjaśnienia.
- Gramatyka ABCD i produkcja gramatyczna korzystają z tych samych zdań; nie liczymy ich dwukrotnie jako dodatkowej treści. Miks językowy pobiera trzy zadania gramatyczne i trzy idiomy.
- Zestawy gramatyczne są gotowe natychmiast, lokalnie, bez wywoływania Gemini ani oczekiwania na generowanie.

## Organizacja dydaktyczna
Nowa część banku zawiera po 15 wzorców na poziom, każdy w 20 kontekstach. Nie jest to 1800 niezależnie napisanych opowiadań: kontrolowane wzorce łączą się z dwujęzycznymi opisami sytuacji i ręcznie podanymi formami czasowników. Dzięki temu odmiana nie jest zgadywana przez dopisywanie końcówek.

- A1: zdania i pytania w Present Simple/Continuous, przeczenia, can, polecenia, want/like, be.
- A2: przeszłość, plany, obowiązek, rada, cel, dobór bezokolicznika i formy -ing.
- B1: Present Perfect, okresy warunkowe, mowa zależna, used to/be used to, konstrukcje let/make.
- B2: czasy perfect i continuous, nierealna przeszłość, modalne odniesienia do przeszłości, gerund i bezokolicznik dokonany.
- C1: inwersja, subjunctive, okresy mieszane, zdania rozszczepione, reporting passive, skrócone zdania imiesłowowe.
- C2: złożone zastosowania inwersji, formalny rejestr, przeczący subjunctive, dystansowanie się od twierdzeń i złożone relacje czasowe.

Poziomy są przypisaniem dydaktycznym do konstrukcji i kontekstu, nie wynikiem zewnętrznej certyfikacji psychometrycznej. Wybrane konstrukcje pojawiają się również na sąsiednich poziomach w bardziej złożonej formie.

## Powtórzenia i zapis
- Najpierw wybierane są niewidziane zadania na aktualnym poziomie użytkownika, określanym dotychczasowym mechanizmem aplikacji.
- W obrębie sesji dobór miesza konstrukcje i sceny, zamiast pokazywać sześć odmian tego samego zdania obok siebie.
- Zadania czekające w przerwanej sesji są tymczasowo zarezerwowane, więc inny tryb nie wybiera ich do nowego zestawu. Rezerwacja nie jest zapisem obejrzenia.
- Wyświetlenie zadania jest zapisywane; opuszczenie sesji nie usuwa tej informacji. Historia jest wspólna dla gramatyki ABCD, wpisywania i miksu.
- Po wyczerpaniu puli wracają najdawniej widziane zdania. Skończony bank nie może obiecywać braku powtórek w nieskończoność.
- Pole `grammarSeen` jest opcjonalne i przechowywane w dotychczasowym zapisie konta/offline oraz pełnym eksporcie JSON. Synchronizacja łączy identyfikatory i zachowuje najnowszą datę obejrzenia.
- Migracja jest addytywna: starsze eksporty wczytują się z pustą historią, ponieważ nie da się odtworzyć zdań oglądanych przed wprowadzeniem tej funkcji. Aktywna sesja z identyfikatorami banku jest zachowywana.

## Pliki treści i odtwarzanie
- `lib/data/grammar-bank.json` — komplet 1800 nowych, rozwiniętych rekordów; aplikacja nie generuje ich podczas nauki.
- `scripts/content/grammar-frames.mjs` — dwujęzyczne sytuacje i formy.
- `scripts/content/grammar-patterns.mjs` — wzorce z odpowiedziami i wyjaśnieniami.
- `node scripts/build-grammar-bank.mjs` — deterministyczne odtworzenie JSON.
- Dotychczasowe zadania pozostają w `lib/data/exercise-bank.ts` i `lib/production.ts`.

## Weryfikacja
Testy: 300 nowych rekordów na poziom; 1872 różne pełne zdania i identyfikatory; walidacja każdego rekordu; zgodność odpowiedzi ABCD po przestawieniu opcji; poprawne i błędne odpowiedzi; pełny cykl bez powtórzeń przy przełączaniu trybów; powrót do najdawniej widzianych; różnorodność sesji; import starszego eksportu; synchronizacja między urządzeniami.
Przejrzano próbkę obejmującą każdy wzorzec, w tym polskie tłumaczenia i składnię zdań przeczących. Testy automatyczne nie zastępują niezależnej recenzji językowej całego banku.
