# Fluent v35 — cichy bank zdań i jednoznaczna informacja o błędzie

## Zmiany
- Błędna odpowiedź i wyjaśnienie: czerwony tekst, tło i obramowanie w obu motywach; jawny nagłówek „Niepoprawna odpowiedź”. Poprawne odpowiedzi nadal mają zwinięte wyjaśnienie.
- Przygotowanie zdań nie renderuje panelu postępu. Niepowodzenie pokazuje powiadomienie z przyciskiem „Ponów”; gotowe słowa i partie pozostają zapisane. Próby mają ograniczony czas i przerwę po błędzie.
- Pierwsza pełna partia: 15 zdań (5 twierdzących, 5 przeczących, 5 pytań). Do tego czasu znaczenie nie trafia do sesji ani spersonalizowanych zadań. Przy pierwszych oczekujących słowach kafelki ćwiczeń słownikowych pokazują klepsydrę. Niezależny bank gramatyki/idiomów/czytania pozostaje dostępny.
- Gdy do wykorzystania pozostają 3 różne zdania, kolejka przygotowuje kolejne 15. Licznik zapisuje unikalne zdania, na które udzielono odpowiedzi; powtórzenie tego samego zadania nie zużywa dodatkowej pozycji. Częściowo przygotowana kolejna partia nie zmienia bieżących ćwiczeń.
- Limit wynosi **90 zdań na znaczenie: 30 twierdzących, 30 przeczących i 30 pytań**. Po osiągnięciu limitu nie powstają kolejne partie.
- Trwała tabela `example_pools`: brak TTL; wspólny bank standardowych znaczeń i scen, izolacja własnych scen według konta. Klucz obejmuje hasło, konkretne tłumaczenie, temat i scenę. Zmiana oszacowania CEFR nie unieważnia banku. Krótkie dzierżawy w bazie blokują równoległe generowanie tych samych partii.
- Odczyt gotowej partii nie wymaga dostępnego Gemini i nie zużywa limitu generowania.
- Ustawienia → **Bank zdań JSON** pobiera wszystkie zdania zapisane w słowniku tego użytkownika, wraz z kontekstem i postępem kolejki. Pełna kopia JSON nadal zawiera cały stan nauki.

## Migracja i zgodność
- `drizzle/0005_nebulous_tyger_tiger.sql` dodaje tabelę banku. Istniejące dane nie są usuwane.
- Pola `usedExamples` i `enrichment.round` są opcjonalne; schemat dopuszcza 90 pozycji we wszystkich równoległych tablicach zdań.
- Eksporty v31 i starsze zachowują istniejące przykłady. Kolejki v34 zaczynają od rundy 0 bez utraty gotowych grup. Niepełne zadania są usuwane tylko z niewykonanej części wznawianej sesji.
- Synchronizacja łączy ekspozycje i zachowuje dłuższą zgodną pulę z drugiego urządzenia. Zmieniony kontekst zaczyna od nowej puli.

## Granice i przechowywanie
- „W tle” oznacza kolejkę działającą przy otwartej aplikacji. Po zamknięciu zapisane zlecenia zostają i są wznawiane po ponownym otwarciu. Nie jest to osobny całodobowy proces generujący treść.
- Kanoniczny bank jest zapisany trwale w bazie hostingu, a nie w nietrwałym systemie plików procesu. Pobierany JSON jest przenośną kopią puli danego użytkownika; archiwum kodu nie zawiera prywatnych danych z produkcyjnej bazy ani sekretów.
- Starsze, już gotowe przykłady bez metadanych banku pozostają używalne i nie są automatycznie masowo regenerowane. Rozbudowa dotyczy znaczeń obsługiwanych przez kolejkę, w tym dodawanych od v34.
- Walidacja sprawdza liczbę zdań, duplikaty, podświetlenia i postać twierdzącą/przeczącą/pytającą. Pełnej poprawności językowej treści modelu nie da się zagwarantować automatyczną walidacją struktury.

## Weryfikacja
Testy obejmują kompletność partii, próg 3 zdań, limit 90, podział 30/30/30, ponowne użycie między kontami bez dostępnego AI, brak opłat za cache, współbieżność i zwolnienie blokady po błędzie, izolację znaczeń/scen, import starszego JSON, synchronizację oraz brak panelu generowania.
Podgląd przeglądarkowy w środowisku roboczym jest niedostępny (brak usługi podglądu); nie potwierdzono wizualnego renderowania zmian w prawdziwej przeglądarce.
