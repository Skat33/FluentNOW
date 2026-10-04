# Fluent v40

- Dyskretne wyróżnienie słów w czytance: jednolity kolor i cienkie podkreślenie. Tłumaczenia otwierają się po kliknięciu, dotknięciu lub aktywacji klawiaturą; najechanie kursorem nie otwiera dymka.
- Odsłuch i zgłoszenie błędu zajmują osobne wiersze. Przyciski zawijają tekst na małych ekranach; wybór pewności odpowiedzi także może się zawijać.
- Codzienna mieszanka przewija do wyniku po sprawdzeniu odpowiedzi lub odsłonięciu fiszki, uwzględniając preferencję ograniczenia ruchu.
- Podpowiedzi w pisemnych zadaniach miksu mają widoczny przycisk z żarówką i pozostają domyślnie zwinięte.
- „Wybierz wiele” łączy kilka rodzajów ćwiczeń. Ekran przed rozpoczęciem podaje rzeczywistą liczbę zadań w każdym rodzaju i pozwala włączyć losowe przeplatanie. Tryby bez gotowych zadań są jawnie oznaczone jako pominięte.
- Kolejność losuje się tylko raz. Ocenione odpowiedzi i postęp zapisują się na bieżąco, są objęte eksportem i synchronizacją. Wznowienie zachowuje kolejkę.
- Wyjście z aktywnego ćwiczenia wymaga potwierdzenia. Ukończone zadania pozostają zapisane. Niezatwierdzony wpis może wymagać ponownego wpisania.
- Nowy tryb korzysta z zapisanych banków oraz istniejących reguł sprawdzania i powtórek, bez nowych wywołań AI.

Walidacja: 128 testów zakończonych powodzeniem. Migrację sprawdzono na starszym eksporcie JSON; opis w `docs/MIGRATION-v40.md`. Podgląd zarządzany jest niedostępny w tym środowisku, dlatego nie wykonano wizualnego testu przeglądarkowego. Testy obejmują renderowanie komponentów i działanie logiki, ale nie zastępują oceny wyglądu na fizycznym telefonie.
