# v40 — sesje łączone

Nowe opcjonalne pole `combined` zawiera zapisaną kolejkę zadań, wybrane rodzaje, ustawienie losowania, indeks oraz ocenione odpowiedzi. Migracja ustawia brakujące pole na `null`. Nie zmienia wcześniejszych sesji słownikowych, czytania, gramatyki ani odpowiedzi.

Kolejność ustala się raz przed sesją; eksport, synchronizacja i wznowienie jej nie losują. Sprawdzone odpowiedzi zapisują się od razu. Zadania słownikowe aktualizują istniejący system powtórek, bez modyfikowania innej wstrzymanej sesji. Zadania gramatyczne są oznaczane w banku jako wyświetlone. Ukończona sesja uzupełnia historię czytania i zestawów. Pytania pisemne produkcji gramatycznej w sesji łączonej zaliczają się do historii gramatyki.

Nowy schemat waliduje indeks, odpowiedzi, typy i kontekst czytanki. Stare eksporty pozostają obsługiwane. Test migracji odczytuje istniejący eksport `tests/fixtures/state-v31.json`, zapisuje sesję łączoną, serializuje i odtwarza jej postęp.
