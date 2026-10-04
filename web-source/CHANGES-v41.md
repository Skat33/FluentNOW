# Fluent v41

- Więcej poprawnych polskich odpowiedników rozpoznawania znaczenia: m.in. borrow → pożyczyć/pożyczać/wypożyczyć; zachowane rozróżnienia kierunku pożyczania oraz odrębnych znaczeń bank/check/turn down.
- Opracowane warianty dla 42 znaczeń i 62 jawne pary aspektowe dla starszych słów. Nowe słowa otrzymują oddzielne listy polskich i angielskich wariantów; obie można edytować. Brak wywołań AI przy ocenianiu.
- Normalizacja polskich znaków, wielkości liter, odstępów, końcowej interpunkcji i jednoznacznych angielskich skrótów. Nie usuwamy negacji, nie zgadujemy końcówek i nie łączymy wszystkich znaczeń jednego słowa.
- Wielokrotny wybór ćwiczeń jest dostępny domyślnie. Jeden rodzaj uruchamia zwykły tryb, kilka — sesję łączoną z konfiguracją kolejności przed startem.
- Oznaczenia aktualnego zadania: słownictwo/fiszka/dyktando/uzupełnianie, gramatyka, idiomy, czytanie.
- Usunięte oznaczenia AmE/BrE z tłumaczeń i legendy propozycji. Prompty preferują słownictwo i pisownię amerykańską; zapisane słowa nie są zamieniane na inne hasła.
- Nowe nagrania zapisywane trwale jako pliki audio w R2, oprócz pamięci podręcznej serwera i przeglądarki. Powtórny odczyt gotowego pliku omija dostawcę mowy i limit generowania.

Weryfikacja obejmuje wszystkie 1872 zadania banku gramatycznego (klucz i zapisane błędne warianty), kilkadziesiąt pozytywnych/negatywnych przykładów słownikowych, renderowanie oznaczeń zadań, starszy eksport oraz rzeczywisty workerd/R2 z restartem. Nie wykonano testu na fizycznym telefonie ani językowej oceny każdego możliwego synonimu. Odrzucony niezapisany odpowiednik nadal można zgłosić albo dopisać w edycji słowa.

Propozycje kolejnych ulepszeń, bez implementacji w tej wersji:
1. Po zgłoszeniu błędu: przegląd i zatwierdzanie dodatkowych wariantów dla konkretnego znaczenia, z testem kontrprzykładów.
2. Zapis własnego zestawu ćwiczeń (rodzaje, czas, kolejność) jako skrótu do następnych sesji.
3. Krótkie zadania sytuacyjne z wyborem reakcji w dialogu, korzystające z istniejącej puli zdań i nagrań.
