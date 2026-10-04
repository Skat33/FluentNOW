# Fluent v33 — szybki start i odporność na awarie

## Działanie

- Czytanie, gramatyka, idiomy, miks oraz produkcja gramatyczna zaczynają się od gotowego materiału. Najpierw używamy wcześniej przygotowanego zestawu AI, a gdy go nie ma — lokalnego banku. Nie czekamy na Gemini przed pierwszym zadaniem.
- Następny zestaw AI przygotowuje się w tle. Nie zmienia pytania, na które użytkownik już odpowiada. Nieudane przygotowanie ma limit 20 sekund, jedną próbę i 90 sekund przerwy przed kolejnym przygotowaniem.
- Bank zawiera 72 różne konteksty gramatyczne (12 na każdy poziom A1–C2), 36 zwrotów/idiomów (6 na poziom) i czytanki z pytaniami ABCD, w tym dwa odrębne teksty C2. Zestawy rotują; po wyczerpaniu banku materiały wracają. A1/A2 obejmują też podstawowe stałe zwroty, a nie wyłącznie idiomy.
- Poziomy materiałów autorskich są szacunkami dydaktycznymi, nie certyfikowaną oceną CEFR. Ogólny bank jest wyraźnie oznaczony i nie udaje ćwiczeń dopasowanych do dowolnego tematu użytkownika. Tematyczne przykłady zapisane wcześniej w znaczeniach nadal służą zwykłym ćwiczeniom słownikowym.
- Pliki banku: `lib/data/exercise-bank.ts`, `lib/data/idiom-bank.ts`, `lib/data/advanced-readings.ts`; wcześniejsze teksty pozostają w `lib/tutor-local.ts`. Aktualna sesja i wyniki są zapisywane dotychczasowym mechanizmem stanu. Nie zmieniamy formatu eksportu ani bazy danych.

## Audio niezależne od Gemini

1. Najpierw pamięć nagrań na urządzeniu i serwerze.
2. Dla pojedynczych słów: Free Dictionary API. Akceptujemy tylko nagrania z jednoznacznym oznaczeniem wybranej odmiany US/UK i z dozwolonych hostów. Interfejs udostępnia odnośnik do źródła/licencji nagrania. API nie zapewnia nagrania każdego słowa ani każdej odmiany.
3. Jeśli skonfigurowano Azure Speech: dedykowana synteza słów, zwrotów i zdań. Domyślny głos amerykański: `en-US-JennyNeural`; brytyjski: `en-GB-SoniaNeural`.
4. Zapasowo istniejący Gemini TTS. Głos urządzenia uruchamia się dopiero po świadomym wyborze użytkownika — bez cichej zamiany lektora.

Każda niezależna usługa ma krótki timeout i przerwę po awarii. Dotychczasowe limity serwera i kolejka pobierania audio nadal obowiązują. Awarie niezależnych dostawców też są możliwe; brak wszystkich usług nie usuwa zapisanych nagrań ani ćwiczeń.

### Włączenie Azure

Utwórz zasób Azure AI Speech i ustaw **po stronie hostingu**:

```dotenv
AZURE_SPEECH_KEY=
AZURE_SPEECH_REGION=
```

Region to identyfikator zasobu (np. `westeurope`), a nie adres URL. Wartości nie mogą mieć prefiksu `NEXT_PUBLIC_`. Klucz pozostaje na serwerze. Usługa wymaga osobnego konta/rozliczeń Microsoft; klucz Gemini jej nie zastępuje. Adapter jest wdrożony, ale Azure nie jest aktywny bez tych dwóch zmiennych. Żadnego nowego płatnego zasobu nie utworzono.

Dokumentacja: https://dictionaryapi.dev/ oraz https://learn.microsoft.com/en-us/azure/ai-services/speech-service/rest-text-to-speech

## Tematy i pamięć podręczna

- Dokładnie to samo znormalizowane zapytanie może wrócić z pamięci urządzenia. Nie przypisujemy lokalnie innego, podobnie brzmiącego tematu.
- Popularne tematy są wstępnie pobierane z istniejącego cache serwera, bez uruchamiania Gemini, zużywania limitu generowania lub sztucznego zwiększania popularności.
- Interaktywny szybki tryb pomija dodatkowe semantyczne wywołanie LLM do rozpoznania tematu; istniejące dopasowania dokładne, aliasy i pozostałe reguły resolvera pozostają.
- Identyczne generowania tematu w jednym procesie serwera współdzielą trwające wywołanie. To nie jest blokada rozproszona między wszystkimi instancjami.
- Nowy, nieznany temat nadal wymaga AI. Interaktywne oczekiwanie ograniczono do 45 sekund i jednej próby. Nie obiecujemy natychmiastowego wyniku ani kompletności całej dziedziny.
- Cache gotowych materiałów na urządzeniu: maksymalnie 24 wpisy, 7 dni, sprawdzanie schematu przed użyciem. Istniejący globalny cache tematów pozostaje w bazie.

## Sprawdzenie

- 94 testy automatyczne: poprawność banku i odpowiedzi, rotacja, wszystkie poziomy, obsługa awarii 503, brak lawiny ponowień, walidacja cache, brak wywołania Gemini/zużycia limitu przy wstępnym pobieraniu tematu, nagranie US z niezależnego API, adapter Azure i escapowanie SSML.
- TypeScript i kompilacja produkcyjna zakończone powodzeniem.
- Wywołania dostawców w testach są zamockowane. Pobrania rzeczywistego nagrania z niezależnego API nie udało się potwierdzić z tego środowiska. Azure nie był testowany z prawdziwym kluczem, ponieważ nie został skonfigurowany.
- Podgląd przeglądarkowy w środowisku roboczym był niedostępny (`sites-previewd mailbox is unavailable`). Nie deklarujemy wykonania wizualnego testu przeglądarkowego tej wersji.

Po wdrożeniu warto sprawdzić: pierwszą i następną sesję; powrót do wcześniej odkrytego tematu; odsłuch pojedynczego słowa i pełnego zdania; ćwiczenia przy wyłączonym połączeniu AI; odtworzenie już zapisanego nagrania bez sieci.
