# FluentNOW — plan testów ręcznych (Mac + urządzenia)

Format: **krok → oczekiwany wynik**. Sekcje 0–5 przygotował code-qa-A (ogólne, iCloud, offline, dane), sekcję 6 (ekrany) uzupełnia code-qa-B.
Przy każdym błędzie zapisz: urządzenie, wersję iOS, krok, zrzut ekranu i — jeśli to crash — log z Xcode (Window → Devices and Simulators → View Device Logs).

## 0. Przygotowanie i kompilacja

| # | Krok | Oczekiwany wynik |
|---|---|---|
| 0.1 | `cd ios && xcodegen` (XcodeGen ≥ 2.38) | Powstaje `FluentNOW.xcodeproj` bez ostrzeżeń o brakujących ścieżkach. |
| 0.2 | `cd ios/Packages/FluentKit && swift test` | Wszystkie testy FluentKit przechodzą (testy na treści robią `skip` tylko, gdy brak plików). |
| 0.3 | `node ios/tools/build-index.mjs --check` | Kod 0. Jeśli „NIEAKTUALNY” → uruchom bez `--check` i zbuduj ponownie (indeks tematów musi obejmować wszystkie pliki `topics/*.json`). |
| 0.4 | Xcode: ustaw Team w Signing (target FluentNOW), ⌘B na symulatorze iOS 17 i iOS 26 | Kompilacja bez błędów. Ostrzeżenia o `deinit`/`Sendable` w trybie Swift 5 są dopuszczalne (lista w raporcie code-qa-A). |
| 0.5 | ⌘U (schemat FluentNOW) | Przechodzą `FluentNOWTests` i `FluentKitTests`. |
| 0.6 | Jeśli kompilacja pada w `AppleOnDeviceAssistant.swift` (API Foundation Models innej wersji SDK) | Dodaj `FLUENT_DISABLE_FOUNDATION_MODELS` do `SWIFT_ACTIVE_COMPILATION_CONDITIONS` (project.yml → settings) — aplikacja buduje się bez modelu Apple, reszta działa. |

## 1. Pierwsze uruchomienie i ogólne

| # | Krok | Oczekiwany wynik |
|---|---|---|
| 1.1 | Usuń aplikację, zainstaluj, uruchom | Ekran Dzisiaj < 1 s, bez białego błysku (tło `LaunchBackground`), onboarding/pusty stan, brak crasha. |
| 1.2 | Odczekaj 2–3 s, wejdź w szybkie dodawanie (+) i wpisz „boarding” | Wyniki z wbudowanego słownika (indeks budowany w tle po starcie). |
| 1.3 | Dodaj 1 temat (np. Lotnisko) | Słowa pojawiają się w Słowniku, kolekcja „Lotnisko” istnieje. |
| 1.4 | Zabij aplikację (przełącznik aplikacji, przesuń w górę) i uruchom ponownie | Słowa są zachowane; kolejność: najnowsze najpierw. |
| 1.5 | Rozpocznij sesję słówek, odpowiedz na 3 zadania, zabij aplikację w trakcie 4. | Po ponownym uruchomieniu Nauka pokazuje „Twoja sesja czeka”, wznowienie od 4. zadania; 3 odpowiedzi są w historii (Postępy → dziś 3). |
| 1.6 | To samo dla sesji łączonej i czytanki | Wznowienie od miejsca przerwania, odpowiedzi nie giną. |
| 1.7 | Przejdź w tło (Home) zaraz po odpowiedzi i od razu zabij aplikację | Odpowiedź zapisana (zapis `.answer` natychmiast + `beginBackgroundTask`). |
| 1.8 | Ustawienia → Motyw: Jasny / Ciemny / Jak w systemie | Zmiana natychmiast w całej aplikacji, także w arkuszach. |
| 1.9 | Ustawienia → wyłącz wibracje (haptykę); wybierz pewność odpowiedzi, chip filtra, odpowiedz poprawnie | Brak jakichkolwiek wibracji (ConfidencePicker, TagChip, FeedbackPanel i ekrany). Włącz ponownie → wibracje wracają. |
| 1.10 | Link `fluentnow://study/start?mode=mixed&minutes=5` (Safari lub `xcrun simctl openurl booted …`) | Otwiera się Nauka i startuje 5-minutowa mieszanka. Też przy zimnym starcie. |
| 1.11 | `fluentnow://words/<id nieistniejący>` i `fluentnow://cokolwiek` | Brak crasha; nieznany link ignorowany. |
| 1.12 | iPad (symulator): obrót, pasek boczny (iOS 18+) | Karty jako pasek boczny/karty; układ czytelny. |

## 2. iOS 17 vs iOS 26

| # | Krok | Oczekiwany wynik |
|---|---|---|
| 2.1 | iOS 17: przejdź wszystkie karty | Klasyczny TabView (`tabItem`), przyciski własnego stylu (fiolet), materiał zamiast szkła. |
| 2.2 | iOS 18: karty | Nowe API `Tab`, tło karty sesji to `MeshGradient`. |
| 2.3 | iOS 26: przewiń długą listę w Słowniku | Pasek kart chowa się przy przewijaniu w dół (`tabBarMinimizeBehavior`), przyciski główne w stylu Liquid Glass. |
| 2.4 | iOS 26 z Apple Intelligence: Ustawienia → Asystent → Apple | Dostępne; na urządzeniu bez Apple Intelligence — czytelny powód niedostępności, wybór wraca do „Bez AI”. |

## 3. iCloud i dwa urządzenia

Wymaga płatnego konta deweloperskiego, kontenera `iCloud.pl.fluentnow.app` i tego samego Apple ID na obu urządzeniach. Synchronizacja CloudKit bywa opóźniona (sekundy–minuty); po każdej zmianie odczekaj do 1 min albo przełącz aplikację w tło i z powrotem (wymuszone odświeżenie co ≥ 60 s).

| # | Krok | Oczekiwany wynik |
|---|---|---|
| 3.1 | Urządzenie A: dodaj temat; B: uruchom aplikację | Słowa pojawiają się na B; Ustawienia → stan „Zsynchronizowano z iCloud”. |
| 3.2 | A: odpowiedz na 10 zadań; B: wróć do aplikacji | Historia i postęp z A widoczne na B (Postępy). |
| 3.3 | Offline na obu: A ćwiczy słowo X (rozpoznawanie), B ćwiczy X (przypominanie); włącz sieć | Po synchronizacji oba wyniki zachowane (scalanie per umiejętność). Znane ograniczenie: równoczesna edycja tego samego rekordu słowa → CloudKit „ostatni zapis wygrywa” dla pól słowa, odpowiedzi (`ReviewRecord`) zostają. |
| 3.4 | A: zmień cel dzienny na 30; B (aplikacja otwarta): poczekaj na synchronizację | B pokazuje cel 30 i **nie cofa** go przy własnym zapisie (poprawka code-qa). |
| 3.5 | A i B jednocześnie zmieniają cel (A=30, B=40) offline, potem online | Wygrywa jedna wartość (ostatni zapis); brak crasha i pętli zmian. |
| 3.6 | A: usuń słowo; B: wróć do aplikacji | Słowo znika także na B (nie „zmartwychwstaje”). |
| 3.7 | A: przerwana sesja słówek; B: otwórz Naukę | Sesja słówek jest per urządzenie (B ma własną); brak crasha. Sesja łączona: wygrywa ta z większym postępem. |
| 3.8 | A: usuń kolekcję; B: wróć | Uwaga — znane ryzyko: lista kolekcji jest sumowana przy scalaniu, usunięta kolekcja może wrócić z B. Zgłoś, jeśli przeszkadza. |
| 3.9 | A: Ustawienia → „Usuń wszystkie dane”; B: wróć | Słowa znikają na B. Znane ryzyko: historia odpowiedzi/ustawienia z B mogą zostać ponownie zapisane — sprawdź Postępy na obu. |
| 3.10 | Wyloguj iCloud na urządzeniu (Ustawienia systemu) i uruchom aplikację | Stan „Tylko na tym urządzeniu” z instrukcją; aplikacja działa, dane zapisują się lokalnie. Po zalogowaniu — synchronizacja wraca. |
| 3.11 | Build bez uprawnienia iCloud (darmowe konto, usunięte entitlements wg README) | Brak crasha (`CKContainer` nie jest tworzony), stan „Tylko na tym urządzeniu”. |
| 3.12 | Brak miejsca w iCloud / iCloud chwilowo niedostępny (trudne do wywołania — opcjonalnie) | Komunikat po polsku, dane lokalne bezpieczne. |

## 4. Offline / tryb samolotowy

| # | Krok | Oczekiwany wynik |
|---|---|---|
| 4.1 | Tryb samolotowy, zimny start | Aplikacja działa w pełni: tematy, słownik, wszystkie tryby nauki, czytanki, gramatyka, idiomy, statystyki. |
| 4.2 | Offline: dodaj słowo spoza bazy (asystent „Bez AI”) | Komunikat „Nie znaleziono… dodaj ręcznie”; formularz ręczny działa. |
| 4.3 | Offline, asystent Gemini: wyszukaj słowo spoza bazy | Po ≤ 20 s czytelny błąd sieci po polsku, bez blokady UI; ocena odpowiedzi zostaje lokalna. |
| 4.4 | Offline: mowa (głośnik) | Działa (`AVSpeechSynthesizer` lokalnie). |
| 4.5 | Offline: ćwiczenie wymowy | Działa, gdy urządzenie obsługuje rozpoznawanie na urządzeniu; inaczej czytelny komunikat. |
| 4.6 | Po powrocie online z iCloud | Zmiany z trybu offline synchronizują się (sekcja 3). |

## 5. Dane: import, eksport, usuwanie, odporność

| # | Krok | Oczekiwany wynik |
|---|---|---|
| 5.1 | Ustawienia → Eksport JSON → udostępnij do Plików | Plik `FluentNOW-kopia-<data>.json`; otwiera się w edytorze, format `{ "version": 1, "state": … }`. |
| 5.2 | Import tego pliku (scalanie) | Podgląd: 0 nowych, N scalonych; po imporcie nic się nie dubluje. |
| 5.3 | Import eksportu ze strony Fluent (web) | Słowa, historia, ustawienia wczytane; brak crasha. |
| 5.4 | Import „Zastąp” | Ostrzeżenie o zastąpieniu; po imporcie stan = plik. |
| 5.5 | Import pliku nie-JSON / uszkodzonego / 60 MB | Czytelny błąd po polsku, dane bez zmian. Duży plik nie zamraża UI (> 1 s) — jeśli zamraża, ekran powinien używać `importJSONInBackground`. |
| 5.6 | Import CSV/TSV i listy „word - tłumaczenie” | Podgląd liczby nowych; pominięte już posiadane pary. |
| 5.7 | Eksport CSV dla Anki | Plik z BOM, otwiera się w Numbers/Anki z polskimi znakami. |
| 5.8 | Usuń słowo, które jest w przerwanej sesji (słówek i łączonej), wróć do sesji | Zadanie z usuniętym słowem jest pomijane („Słowo nie jest już dostępne”/„Pomiń”), sesja idzie dalej, brak crasha. Po zabiciu aplikacji sesja nadal jest do wznowienia. |
| 5.9 | Usuń słowo, na które już odpowiedziałeś w przerwanej sesji; zabij i uruchom aplikację | Sesja nadal do wznowienia (poprawka code-qa — wcześniej znikała). |
| 5.10 | „Usuń wszystkie dane” | Pusta aplikacja, przypomnienia anulowane, klucz Gemini usunięty, preferencje domyślne; po ponownym uruchomieniu nadal pusto. |
| 5.11 | Duże konto: zaimportuj 3 000+ słów (np. wygenerowany CSV 500 wierszy × kilka razy), przewijaj Słownik, otwórz Postępy | Płynne przewijanie, Postępy liczą się w tle (wskaźnik, potem dane), brak zacięć > 100 ms. |
| 5.12 | Zgłoś błędne zadanie, potem Ustawienia → eksport zgłoszeń | Plik JSON ze zgłoszeniem; zgłoszenia nie trafiają do iCloud. |
| 5.13 | (Symulator) Uszkodzona baza: zamknij aplikację, nadpisz `Library/Application Support/FluentNOW/FluentNOW.store` losowymi bajtami, uruchom | Brak crasha; komunikat o kopii w `Documents/Kopie/<data>/`; w Ustawieniach możliwość udostępnienia kopii. |

### 5a. Przypomnienia

| # | Krok | Oczekiwany wynik |
|---|---|---|
| 5a.1 | Włącz przypomnienia → zgoda systemu | Zgoda wymagana tylko po akcji użytkownika. |
| 5a.2 | Ustaw porę za 2 min, przejdź w tło | Powiadomienie „Masz N słówek do powtórki…” (poprawna odmiana). |
| 5a.3 | Osiągnij cel dzienny, przejdź w tło | Dziś brak powiadomienia; jutro jest. |
| 5a.4 | Dotknij powiadomienia (aplikacja zamknięta) | Otwiera się Nauka z mieszanką. |
| 5a.5 | Odmów zgody, potem włącz przełącznik | Czytelna informacja + link do Ustawień systemu, brak crasha. |

### 5b. Dostępność (ogólne)

| # | Krok | Oczekiwany wynik |
|---|---|---|
| 5b.1 | VoiceOver: przejdź Dzisiaj → sesję → odpowiedź | Każdy przycisk-ikona ma polską etykietę (głośnik, +, zamknij komunikat); wynik odpowiedzi jest odczytywany. |
| 5b.2 | Dynamic Type „AX5” (największy) | Teksty się zawijają, ConfidencePicker układa opcje pionowo, nic nie jest ucięte bez możliwości przewinięcia. |
| 5b.3 | „Ogranicz ruch” | Brak animacji skali/odbicia, przejścia zastąpione przenikaniem. |
| 5b.4 | Tryb ciemny + zwiększony kontrast | Tekst czytelny na wszystkich kartach. |

## 6. Ekrany (code-qa-B)

Autor: code-qa B.
Format: **krok → oczekiwany wynik**. Urządzenia: iPhone z iOS 17 (symulator) i iOS 26 (urządzenie). Każdy scenariusz
powtórzyć w trybie ciemnym i z Dynamic Type „Accessibility XXL” (Ustawienia → Dostępność → Ekran i rozmiar tekstu),
chyba że zaznaczono inaczej.

### 6.1. Pierwsze uruchomienie (Dzisiaj → onboarding)

| # | Krok | Oczekiwany wynik |
|---|---|---|
| 1.1 | Zainstaluj czystą aplikację, uruchom. | Karta „Dzisiaj”: najpierw szkielet, potem „Witaj w FluentNOW” z wyborem poziomu (domyślnie A2) i siatką tematów. Brak crasha bez internetu. |
| 1.2 | Nie wybieraj tematu. | Przycisk „Wybierz co najmniej 1 temat” nieaktywny. |
| 1.3 | Wybierz 3 tematy, spróbuj wybrać 4. | Czwarty kafelek wyszarzony, nie da się go zaznaczyć. |
| 1.4 | „Dodaj słowa i zacznij”. | Pasek „Przygotowuję Twoje słowa…” rośnie do 100%; **onboarding nie znika po pierwszej partii słów** (poprawka B); potem otwiera się karta Nauka i od razu sesja codzienna. |
| 1.5 | Wróć na Dzisiaj. | Karta sesji (fioletowa), kafelki statystyk, „Ostatnio dodane” — słowa z wybranych tematów. |
| 1.6 | Usuń aplikację, zainstaluj ponownie, „Pomiń — dodam słowa sam”. | Stan pusty „Pierwsze słowo zaczyna historię” z „Przeglądaj tematy” (otwiera Słownik → Tematy). |
| 1.7 | Tryb samolotowy przy 1.1–1.4. | Wszystko działa (treść wbudowana). |

### 6.2. Dzisiaj

| # | Krok | Oczekiwany wynik |
|---|---|---|
| 2.1 | „Zaczynam naukę”. | Przełączenie na kartę Nauka i pełny ekran sesji słownictwa (mieszanka). |
| 2.2 | W sesji „Zrób przerwę” (X), wróć na Dzisiaj. | Tytuł karty „Twoja sesja czeka”, „Ukończono N z M zadań”, przycisk „Wznów sesję” otwiera tę samą sesję w tym samym miejscu. |
| 2.3 | Osiągnij cel dzienny w sesji, wróć na Dzisiaj. | Pierścień zamknięty, tytuł „Cel osiągnięty”; jednorazowa haptyka (nie przy każdym uruchomieniu aplikacji — poprawka B); brak haptyki, gdy „Wibracje” wyłączone w Ustawieniach. |
| 2.4 | „Gotowość na krok dalej?” → „Dodaj do nauki”. | Etykieta „Dodano do kolekcji…”, słowo pojawia się w Słowniku. |
| 2.5 | Dotknij słowa w „Ostatnio dodane”. | Push szczegółów słowa w karcie Dzisiaj; wstecz wraca na Dzisiaj. |
| 2.6 | „Twoje kolekcje” → „Wszystkie”. | Karta Słownik, segment Kolekcje. |

### 6.3. Słownik — słowa

| # | Krok | Oczekiwany wynik |
|---|---|---|
| 3.1 | Wpisz w wyszukiwarce „pozyczyc”. | Wyniki z „pożyczyć” (bez polskich znaków), lista bez przycięć. |
| 3.2 | Chipy statusu (Nowe, Trudne, Archiwum…) i menu Filtry (sortowanie, poziom, kolekcja). | Lista filtruje się; licznik w stopce; przy filtrze kolekcji „Ćwicz kolekcję…” otwiera sesję tej kolekcji. |
| 3.3 | Brak wyników → „Wyczyść filtry”. | Pełna lista wraca. |
| 3.4 | Przesuń wiersz w prawo / w lewo. | Wymowa / „Trudne”; „Archiwizuj” — wiersz znika z „Wszystkie”, widoczny w „Archiwum”. |
| 3.5 | Szczegóły słowa: wymowa normalna i wolna, „Pokaż wszystkie” przykłady. | Mowa en-US; umiejętności niećwiczone „—”. |
| 3.6 | Menu → Edytuj, zmień tłumaczenie, usuń jedyny przykład. | Sekcja „Do poprawienia”, „Zapisz” nieaktywne; „Anuluj” pyta o porzucenie; gest zamknięcia zablokowany. |
| 3.7 | Dodaj znaczenie i przykład z wyróżnieniem spoza zdania. | Komunikat „fragment … nie występuje”. Po poprawie „Zapisz” → zmiany widoczne. |
| 3.8 | Menu → Usuń słowo → „Usuń słowo”. | Powrót do listy, słowa nie ma; historia odpowiedzi w Postępach bez zmian. |

### 6.4. Usunięte słowo w przerwanej sesji (backlog — ważne)

| # | Krok | Oczekiwany wynik |
|---|---|---|
| 4.1 | Rozpocznij sesję słownictwa, odpowiedz na 1 zadanie, „Zrób przerwę”. Usuń w Słowniku słowo z **następnego** zadania (podejrzyj je w szczegółach sesji lub usuń kilka słów kolekcji). Wznów sesję. | Karta „To słowo nie jest już dostępne” + „Pomiń zadanie”; po pominięciu sesja idzie dalej; brak crasha. |
| 4.2 | Szybko dotknij dwukrotnie „Pomiń zadanie”. | Pomijane jest tylko zadanie z usuniętym słowem (kolejne, poprawne zostaje) — poprawka B. |
| 4.3 | Usuń wszystkie słowa sesji (lub całą kolekcję słów) i wznów. | Kolejne karty „Pomiń zadanie”, na końcu podsumowanie; nic się nie blokuje. |
| 4.4 | Na drugim urządzeniu (iCloud) usuń słowo, które jest **właśnie wyświetlane** w sesji na pierwszym. | Po synchronizacji zadanie zmienia się na „To słowo nie jest już dostępne”; jeśli użytkownik zdążył odpowiedzieć — „Dalej” przechodzi dalej (nie zawiesza się — poprawka B). |
| 4.5 | To samo w sesji łączonej. | Karta „Pomiń zadanie” albo „Następne zadanie”; podsumowanie liczy zadanie jako niezaliczone. |

### 6.5. Szybkie dodawanie (+)

| # | Krok | Oczekiwany wynik |
|---|---|---|
| 5.1 | + → wpisz „borrow”. | Propozycje od razu (także offline), arkusz rośnie do `.large`. |
| 5.2 | Wybierz hasło. | Lista znaczeń; **żadne nie jest zaznaczone**; znane oznaczone „już w słowniku” i zablokowane. |
| 5.3 | Zaznacz 2 znaczenia → Dodaj. | „Dodano 2 znaczenia słowa „borrow” do kolekcji …”; pole puste, fokus wraca; haptyka (o ile włączona). |
| 5.4 | Wpisz słowo spoza bazy (np. „qwertyx”). | „Brak w bazie”, „Dodaj ręcznie” (formularz wymaga tłumaczenia i zdania); „Zapytaj asystenta AI” tylko przy włączonym AI. |
| 5.5 | Zaznacz znaczenie i przeciągnij arkusz w dół. | Arkusz nie zamyka się; „Anuluj” pyta „Porzucić wybrane znaczenia?”. |
| 5.6 | Deep link `fluentnow://add?text=lend`. | Arkusz z wpisanym „lend”. |

### 6.6. Tematy i kolekcje

| # | Krok | Oczekiwany wynik |
|---|---|---|
| 6.1 | Słownik → Tematy, wyszukaj „lotnisko”. | Kafelek tematu z rozkładem CEFR; VoiceOver czyta „Poziomy: A1: …”. |
| 6.2 | Otwórz temat, filtr poziomów (zostaw tylko B1), „Zaznacz widoczne”, „Dodaj N słów do nauki”. | Pasek postępu „Dodawanie słów… %”, potem podsumowanie i „Ćwicz teraz” (sesja kolekcji tematu). Wpisy oznaczone „już w słowniku”. |
| 6.3 | W trakcie dodawania wróć wstecz. | Dodawanie kończy się w tle; licznik „Dodano N” na kafelku tematu. |
| 6.4 | Podgląd wpisu (ikona i) → „Zaznacz”. | Arkusz zamyka się, wpis zaznaczony. |
| 6.5 | Kolekcje → „Nowa kolekcja” z nazwą istniejącej. | Komunikat „Masz już kolekcję o tej nazwie”, przycisk nieaktywny. |
| 6.6 | Kolekcja → Zmień nazwę → Zapisz. | Ekran wraca i otwiera kolekcję pod nową nazwą; słowa przeniesione. |
| 6.7 | Kolekcja → Usuń. | Słowa trafiają do „Codzienne rozmowy” (lub „Inne”); postęp zachowany. |
| 6.8 | Baner „Podobne słowa, inna historia” → „Poćwicz różnice”. | Sesja par (luka z polską podpowiedzią w nawiasie) albo spokojny komunikat o braku par. |

### 6.7. Nauka — wybór i sesje

| # | Krok | Oczekiwany wynik |
|---|---|---|
| 7.1 | Nauka: wybierz 5/10/15 min, zaznacz 1 tryb. | Szacunek „Około N min · X ćwiczeń”; wybór pamiętany po ponownym uruchomieniu. |
| 7.2 | Bez słów (świeża instalacja + „Pomiń”). | Tryby słownikowe wyłączone z opisem „Najpierw dodaj…”; czytanie/gramatyka/idiomy/produkcja działają. |
| 7.3 | Fiszka: „Odsłoń znaczenie” → pewność → „Pamiętam”. | Zapis od razu, następne zadanie; licznik czasu zatrzymany przy odsłonięciu. |
| 7.4 | Fiszka: przesuń w prawo / w lewo poza próg. | Pamiętam / Jeszcze nie; przewijanie w pionie nadal działa; z „Ogranicz ruch” bez obrotu karty. |
| 7.5 | Tłumaczenie PL→EN: błędna odpowiedź. | „Jeszcze nie”, podpowiedź odsłonięta, pole aktywne; druga poprawna = „Udało się z podpowiedzią”. „Pokaż odpowiedź” kończy zadanie. |
| 7.6 | Literówka (np. „borow”). | „Prawie — to literówka?”, „Uznaj moją odpowiedź” → „Zaliczone — popraw pisownię”. |
| 7.7 | Luka, znaczenie (z „Pokaż warianty”), dyktando. | Luka czytana przez VoiceOver jako „luka”; dyktando odtwarza słowo samo (poza VoiceOver); warianty 1–4. |
| 7.8 | Klawiatura sprzętowa (iPad/symulator): Enter. | Enter = Sprawdź / Dalej; w ABCD klawisze 1–4. |
| 7.9 | Szybkie podwójne dotknięcie „Dalej”, „Pamiętam”, „Następne zadanie”. | Zapisuje się jedna odpowiedź, żadne zadanie nie jest pomijane. |
| 7.10 | Ukończ sesję. | „Mały krok za Tobą.”, statystyki, „Te słowa urosły”, „Warto do nich wrócić”; „Jeszcze 5 minut” startuje nową krótką sesję albo pokazuje komunikat. |
| 7.11 | Sesja łączona (np. Mieszanka + Czytanie + Gramatyka, „Losuj kolejność”). | Zadania przeplatane; przy braku zadań dla trybu — arkusz „Twoja sesja” z „Brak gotowych zadań — pominięte”. Podsumowanie z wynikami per tryb. |
| 7.12 | Zabij aplikację w środku sesji (słownictwo, łączona, czytanie, zestaw, produkcja) i uruchom ponownie. | Na ekranie Nauka kafelki „… czeka” dla każdej przerwanej; „Kontynuuj” wraca do tego samego zadania. Utracone może być tylko zadanie sprawdzone, ale niezatwierdzone „Dalej”. |
| 7.13 | Asystent AI włączony (Gemini), błędna odpowiedź w tłumaczeniu. | „Asystent sprawdza…” z „Pomiń”; bez sieci → ocena lokalna, bez blokady. Zamknięcie sesji (X) w trakcie sprawdzania przerywa zapytanie (poprawka B). |
| 7.14 | „Powiedz to” (po odsłonięciu fiszki / w wyniku). | Prośba o zgodę dopiero po dotknięciu; po odmowie — komunikat, przycisk „Brak zgody na mikrofon”; wynik orientacyjny nie zmienia postępu. |
| 7.15 | „Zgłoś błąd w zadaniu” → komentarz → Zapisz. | Zgłoszenie widoczne w Ustawienia → Eksport → „Zgłoszone błędy (N)”. |

### 6.8. Czytanie, gramatyka, idiomy, produkcja

| # | Krok | Oczekiwany wynik |
|---|---|---|
| 8.1 | Czytanie: start. | „Twój poziom … · tekst …”, tekst szeryfowy; podkreślone słowa ze słownika → arkusz ze znaczeniami. |
| 8.2 | „Sprawdź odpowiedzi” przy brakach. | Przycisk nieaktywny, „zostało: N”. |
| 8.3 | Sprawdź → „Następny tekst”. | Wyniki z fragmentem-dowodem; nowy tekst; historia „Ostatnie czytanki”. Gdy brak tekstu — spokojny komunikat. |
| 8.4 | Gramatyka/Idiomy/Miks: ABCD i wpisywanie. | Natychmiastowa ocena, wyjaśnienie rozwinięte przy błędzie; podwójne dotknięcie „Następne pytanie” nie pomija pytania (poprawka B). |
| 8.5 | Produkcja: wpisz formę z literówką. | „Zaliczone — popraw pisownię”, diagnoza, „Konstrukcja: …”; koniec zestawu → wynik i historia. |

### 6.9. Postępy

| # | Krok | Oczekiwany wynik |
|---|---|---|
| 9.1 | Otwórz Postępy po kilku sesjach. | Kafelki, poziom z uczciwym opisem pewności, tydzień (linia celu), heatmapa 12 tyg., przyrost, prognoza; ekran nie przycina przy przewijaniu. |
| 9.2 | VoiceOver na wykresach. | Słupki czytane jako dzień + liczba; heatmapa jako jeden opis. |
| 9.3 | „Przećwicz pomyłki”. | Sesja trybu pomyłek albo komunikat „Nie masz jeszcze słów wymagających…”. |

### 6.10. Ustawienia

| # | Krok | Oczekiwany wynik |
|---|---|---|
| 10.1 | Cel dzienny. | Opcje „5 zadań … 50 zadań” (poprawna odmiana); zmiana widoczna na Dzisiaj. |
| 10.2 | Włącz przypomnienie → odmów zgody. | Alert z „Otwórz Ustawienia systemu”, przełącznik wraca na wyłączony. Po zgodzie — wybór pory. |
| 10.3 | Głos i akcent → dotknij głosu. | Próbka, znacznik wyboru; „Automatycznie” przywraca domyślny. |
| 10.4 | Motyw Jasny/Ciemny/System; „Wibracje” wył. | Natychmiastowa zmiana; po wyłączeniu wibracji brak haptyki w całej aplikacji (chipy, ABCD, wynik, dodawanie). |
| 10.5 | iCloud → „Sprawdź ponownie”. | Status (Zsynchronizowano / Tylko lokalnie z instrukcją). |
| 10.6 | Asystent AI → Gemini, zły klucz → Połącz. | Czytelny błąd po polsku; dobry klucz → „Połączono · model”; „Odłącz” usuwa klucz. |
| 10.7 | Import: plik JSON ze strony Fluent → podgląd → Scal. | „Nowe: N · scalone: M”, słowa w Słowniku, postęp zachowany. „Zastąp” pyta o potwierdzenie. |
| 10.8 | Import: wklejony tekst „word - słowo”. | Podgląd i import listy; powtórzone wiersze pominięte. |
| 10.9 | Eksport (duży słownik). | Ekran otwiera się od razu, pliki przygotowywane w tle (poprawka B), „Udostępnij” JSON/CSV. |
| 10.10 | Usuń wszystkie dane → wpisz „usuń”. | Przycisk aktywny dopiero po „USUŃ” (wielkość liter bez znaczenia); po usunięciu karta Dzisiaj z onboardingiem. |

### 6.11. Dostępność i różne systemy

| # | Krok | Oczekiwany wynik |
|---|---|---|
| 11.1 | VoiceOver: przejdź całą sesję słownictwa. | Każdy przycisk-ikona ma etykietę; licznik czasu nie gada w trakcie; wynik ogłaszany raz. |
| 11.2 | Dynamic Type AX5. | Karta sesji na Dzisiaj układa się pionowo; przyciski par fiszki pionowo; brak uciętych tekstów. |
| 11.3 | iOS 17 vs iOS 26. | iOS 17: klasyczny pasek kart; iOS 18+: `Tab` API; iOS 26: pasek chowa się przy przewijaniu. Ekrany Features identyczne funkcjonalnie. |
| 11.4 | iPad (opcjonalnie). | Siatki kafelków wielokolumnowe, kolumna tekstu ≤ 640 pt. |
