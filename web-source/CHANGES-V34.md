# Fluent v34

## Interfejs ćwiczeń

- Produkcja gramatyczna: pole odpowiedzi i przycisk „Sprawdź” w jednym wyrównanym rzędzie na większym ekranie; na telefonie pełna szerokość i odstęp między kontrolkami.
- Poprawne odpowiedzi: krótka animacja potwierdzenia, wyjaśnienie domyślnie zwinięte i rozwijane przez użytkownika.
- Niepoprawne odpowiedzi: delikatna animacja i od razu rozwinięte wyjaśnienie. Obsługujemy ustawienie ograniczonego ruchu i klawiaturę.
- Zmiana obejmuje produkcję gramatyczną, ćwiczenia słownikowe, idiomy, miks i pytania do czytanek.

## Dodawanie bez oczekiwania na generowanie

Logi poprzedniej wersji potwierdziły `HTTP 503 / UNAVAILABLE` z Gemini oraz kumulowanie ponowień (m.in. żądanie trwające około 53 sekund). Zapis znaczeń nie zależy już od zakończenia hydratacji.

1. Propozycje w temacie są zawsze odznaczone, również przy trafieniu z cache lub dopasowanej podkategorii.
2. „Dodaj N znaczeń” pokazuje krótki przegląd przypisania do kolekcji. „Zapisz słowa” zapisuje od razu wybrane znaczenia i kolejkę. Można anulować i wrócić do zaznaczeń albo wybrać kolekcję osobno dla każdego słowa.
3. Kolejka w tle tworzy po 15 zdań **na konkretne znaczenie**: 5 twierdzących, 5 przeczących, 5 pytań. Każda partia pięciu zdań jest osobno walidowana i zapisywana. Zdania mają pełne tłumaczenie i dokładne podświetlenia; temat/scena trafiają do promptu.
4. Najpierw powstają przykłady, aby słowa mogły wejść do sesji; dodatkowe opisy i wymowa IPA uzupełniają się później. Nie podstawiamy wymyślonych zdań ani samego hasła w miejsce przykładu.
5. Nowe pojedyncze słowa, znaczenia z tematów i nowe ręcznie dodane znaczenia automatycznie trafiają do kolejki. Dawne słowa nie są masowo zmieniane ani nie wywołują niezamówionych zapytań.
6. Licznik pokazuje faktycznie zapisane partie, nie sztuczny procent oczekiwania. Przykłady pozostają w stanie aplikacji po odświeżeniu i w eksporcie. Działa wstrzymanie/wznowienie oraz ręczne ponowienie.
7. Pojedyncza próba w tle ma limit 26 s po stronie klienta i budżet 22 s generowania po stronie serwera. Awaria oznacza przerwę 60 s; dzienny limit aplikacji wstrzymuje automatyczne próby do następnej doby UTC. Przy wyłączonej aplikacji praca nie trwa: wznowi się po otwarciu.
8. Puste znaczenie oczekujące na pierwsze zdania nie jest używane w ćwiczeniu. Kolejka pomija znaczenia używane w aktywnej/niedokończonej sesji, by nie podmieniać jej przykładu. Odpowiedź spóźniona po zmianie znaczenia, archiwizacji lub usunięciu słowa nie nadpisuje edycji.

Nie da się zagwarantować wygenerowania 15 zdań podczas całkowitej awarii dostawcy. W takiej sytuacji słowa są już zapisane, gotowe materiały pozostają dostępne, a brakujące przykłady czekają na wznowienie. Zdania AI wymagają zwykłej ostrożności dydaktycznej; walidacja techniczna nie jest dowodem bezbłędnej semantyki.

## Różnorodność

Bank zwrotów/idiomów rozszerzono z 36 do 108 kontekstów, po 18 na poziom. Trzy kolejne lokalne zestawy po sześć pytań nie powtarzają kontekstów na danym poziomie. Alternatywy ABCD też zmieniają się między wariantami. Na A1/A2 są to głównie stałe zwroty konwersacyjne.

Identyfikatory przygotowywanych zestawów AI nie zawijają się już po czterech sesjach. Gramatyka i idiomy przekazują poprzednie konteksty do pominięcia; walidacja odrzuca ich dosłowne powtórzenie. Skończony bank offline z czasem wraca do wcześniejszych materiałów — nie obiecujemy nieskończonej liczby unikatowych zadań. Poziom ćwiczenia jest szacunkiem dydaktycznym, a nie certyfikatem CEFR każdego idiomu w izolacji.

## Azure Speech

Klucz przechowywany wyłącznie jako sekret hostingu; region `germanywestcentral`. Azure jest pierwszym wyborem lektora dla słów i zdań (`en-US-JennyNeural`, opcjonalnie `en-GB-SoniaNeural`). Następnie nagranie słownikowe, jeśli istnieje dla danej odmiany, oraz Gemini jako zapas. Głos urządzenia tylko po wyborze użytkownika.

Nowa wersja identyfikatora audio omija poprzednie nagrania Gemini, żeby konfiguracja Azure była słyszalna od razu. Test prawdziwej usługi: `HTTP 200`, `audio/mpeg`, 17 568 bajtów dla krótkiego zdania. Test nie stanowi gwarancji dostępności usługi w każdym momencie.

Dokumentacja REST: https://learn.microsoft.com/en-us/azure/ai-services/speech-service/rest-text-to-speech

## Dane i sprawdzenie

Migracja jest addytywna w `migrateState`: opcjonalny obiekt `Meaning.enrichment`; starsze eksporty bez niego wczytują się bez zmian treści i bez automatycznego uruchamiania kolejki. Nie jest potrzebna migracja SQL — stan użytkownika jest już przechowywany jako JSON. Przykłady zapisują się w istniejących tablicach `examples` i odpowiadających im tłumaczeniach/podświetleniach.

100 testów automatycznych obejmuje m.in. import starego eksportu v31, zapis/wznowienie kolejki, 15 unikalnych przykładów, zachowanie ocen, ochronę przed spóźnioną odpowiedzią, API nowych przykładów i cache, trzy odrębne sesje idiomów oraz zwinięcie poprawnej odpowiedzi. Sprawdzono TypeScript i kompilację produkcyjną.

Podgląd przeglądarkowy środowiska był niedostępny. Nie wykonano wizualnego testu mobilnego w przeglądarce; responsywność sprawdzono na poziomie struktury i reguł układu. Nowe wywołania Gemini sprawdzono z mockami; nie deklarujemy pomyślnej generacji wszystkich przykładów w czasie rzeczywistej awarii dostawcy.
