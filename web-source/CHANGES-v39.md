# Fluent v39

- Azure Speech: normalizacja konfiguracji, druga próba na przejściowe błędy, alternatywny głos, współdzielenie równoległych żądań i zwrot limitu po nieudanym odczycie. Bez generatywnego odczytu ćwiczeń z lukami. Diagnostyka nie ujawnia klucza.
- Ćwiczenie par: angielskie zdanie z luką i polskim hasłem w nawiasie; pełne tłumaczenie dopiero po odpowiedzi. Ocena lokalna uwzględnia formę słowa z przykładu.
- 30 zapisanych czytanek (5 na poziom A1–C2), od około 100 do 420 słów, 3–6 pytań. Wybór bez powtarzania przed wyczerpaniem poziomu; wyższe poziomy obejmują wnioskowanie i ocenę stanowiska autora. Poziomy są oceną redakcyjną, nie certyfikacją.
- Słowa i zapisane formy ze słownika wyróżnione w czytance; dymek dostępny myszką, dotykiem i klawiaturą zawiera zapisane tłumaczenia.
- Miks: 4 pytania ABCD i 2 zadania pisemne z podpowiedzią. Dokładne lokalne sprawdzanie zapisanych wariantów, trwały zapis wpisanych odpowiedzi.
- Zwykłe czytanie, gramatyka i idiomy korzystają z banku bez oczekiwania na AI. Osobny przycisk generuje czytankę z własnych słów; wynik zapisuje się w trwałej pamięci podręcznej przypisanej do konta.
- Poprawiony układ tekstu, odtwarzania i odpowiedzi w ćwiczeniach.

## Sprawdzenie

- TypeScript: bez błędów.
- Testy obejmują Azure, cache, migrację starych sesji, bank czytanek, lokalne ocenianie i renderowanie komponentów.
- Test w rzeczywistym silniku workerd wykrył przyczynę awarii: redirect:error jest nieobsługiwane. Połączenia Azure i słownikowe używają teraz redirect:manual i odrzucają przekierowania bez przesyłania klucza dalej.
- Azure otrzymuje także wymagany nagłówek User-Agent z nazwą aplikacji (hosting nie dodaje go automatycznie).
- Bezpośredni test usługi Azure w skonfigurowanym regionie: HTTP 200, audio/mpeg.
- Podgląd zarządzany nie wystartował w tym środowisku; interakcje wizualne wymagają oceny w aplikacji. Testy renderowania nie zastępują sprawdzenia na fizycznym telefonie.

Zmiana formatu zapisanych sesji jest opisana w docs/MIGRATION-v39.md. Klucze usług są ustawieniami hostingu i nie należą do archiwum źródłowego.
