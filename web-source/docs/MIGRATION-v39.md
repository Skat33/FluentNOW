# Migracja v38 → v39

Migracja jest addytywna i działa w `migrateState`:

- Starsze sesje ABCD nie mają `practice.writtenAnswers`. Otrzymują tablicę pustych napisów o długości zestawu. Zapisane indeksy odpowiedzi, numer zadania i ukończenie pozostają bez zmian.
- Pola `format`, `inputHint` oraz `acceptedAnswers` przy zadaniu są opcjonalne. Brak `format` oznacza dotychczasowe ABCD. Nowe miksy otrzymują dwa zadania `input`; wpisany tekst zapisuje się w sesji i eksporcie JSON.
- Czytanki mają trwałe identyfikatory banku. Starsze zapisane teksty i historia pozostają czytelne; nowy selektor wybiera nieprzeczytane teksty z banku v39.
- Nie trzeba zmieniać tabel D1: stan konta nadal jest walidowanym JSON, a opcjonalne personalizowane czytanki korzystają z istniejącej tabeli `shared_content` z kluczem ograniczonym do konta.

Test migracji sprawdza eksport starszego formatu sesji ABCD, zachowanie odpowiedzi i ponowny eksport/import sesji z odpowiedzią pisaną. Odrzucana jest niezgodna długość tablicy odpowiedzi pisanych.
