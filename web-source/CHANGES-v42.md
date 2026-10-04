# Fluent v42

- Zgłoszenia zapisują się na serwerze w kolejce D1 oraz plikach R2 `reports/<id>.json`. Lokalna kolejka ponawia wysłanie po odzyskaniu połączenia; identyczne zgłoszenia nie są dublowane.
- Procesor przeglądu rezerwuje do 10 zgłoszeń na godzinę. Poprawki odpowiedzi, pytań i wyjaśnień są walidowane i przypisane do konta zgłaszającego. Nie nadpisuje wyników historycznych.
- Niepotwierdzone zgłoszenia są usuwane po weryfikacji; minimalny identyfikator zapobiega odtworzeniu usuniętego zgłoszenia ze starej kopii. Niejednoznaczne zgłoszenia pozostają z wyjaśnieniem.
- Uruchomienie procesu wymaga osobnego zadania chmurowego. Protokół i zakres automatycznych korekt: `docs/REPORT-REVIEW.md`. Procesor nie modyfikuje kodu ani nagrań.
- Widoczny nagłówek „Rodzaj ćwiczenia” identyfikuje słownictwo, gramatykę, idiomy, czytanie i słuchanie również w sesjach mieszanych.
- Eksport zgłoszeń pozostaje dostępny w ustawieniach. Usunięcie danych konta usuwa także jego zgłoszenia i poprawki.

Walidacja: TypeScript oraz 140 testów, w tym izolacja kont, pliki zgłoszeń, usuwanie, ponowienia, godzinna blokada, walidacja korekt i oznaczenia ćwiczeń. Migracja SQL dodaje trzy tabele bez zmiany istniejących danych.
