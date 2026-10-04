# Aktualizacja funkcjonalna — wrzesień 2026

Ta sekcja zastępuje poniższe ograniczenia pierwotnego MVP dotyczące dodawania słów, oceniania i AI.

- Szybkie dodawanie: wpisz hasło, wybierz znaczenia, zapisz. System proponuje i tworzy kolekcje automatycznie; ponowne dodanie tego samego znaczenia nie kasuje postępu.
- Fiszki i tłumaczenia korzystają z pełnych zdań po polsku, z pogrubieniem wyrażenia, którego się uczysz.
- Wariant „lend someone” jest akceptowany dla znaczenia pożyczania komuś. Niejednoznaczny wariant jest przekazywany do oceny kontekstu; brak pewnej odpowiedzi nie skutkuje automatycznym błędem.
- Pisownia jest oceniana osobno od rozumienia znaczenia. Dyktando nadal sprawdza dokładnie usłyszany tekst.
- Czytanki mają pytania ABCD, wyjaśnienia oraz fragment tekstu uzasadniający odpowiedź. Odpowiedzi i wynik zapisują się na koncie; nie podwyższają automatycznie wyniku słów.
- Poziom czytanek szacujemy ze znaczeń o wyniku co najmniej 40%, ze średnią ważoną opanowaniem. To orientacyjna wskazówka. Bez historii zaczynamy od A1.
- Po opanowaniu znaczenia (80%) można wybrać trudniejszy pokrewny zwrot. Różnice rejestru i użycia są pokazywane zamiast sugerowania pełnej zamienności synonimów.
- Nowy domyślny lektor: amerykańska wymowa. W trybie systemowym wybierane są tylko angielskie głosy; można wskazać konkretny głos. Po połączeniu usługi dostępna jest syntetyczna mowa AI z naturalną intonacją.

## Dostępność AI

Integracja serwerowa obejmuje uzupełnianie dowolnych słów, tłumaczenie przykładów, ocenę wariantów odpowiedzi, nowe czytanki, propozycje rozwoju i lektora. Połącz Gemini w Ustawieniach za pomocą klucza z Google AI Studio. Tekst obsługuje Gemini 3.8 Flash, a mowę Gemini 3.1 Flash TTS (preview). Bez niej aplikacja uczciwie pokazuje bazę startową oraz systemowy lektor i nie twierdzi, że nieznane jej słowo nie istnieje. Treści AI są propozycjami, a poziomy CEFR są przybliżone. Weryfikacja internetowa nie jest deklarowana — AI opiera się na wiedzy modelu.

Dane zadania, odpowiedź lub potrzebne słownictwo mogą być wysyłane do Google. Klucz podany w Ustawieniach jest szyfrowany po stronie serwera i przypisany do konta. Połączenie przetrwa odświeżenie; klucz nie trafia do eksportu ani localStorage. Usunięcie połączenia lub danych Fluent usuwa zapisany klucz. Dostępne modele są sprawdzane przy połączeniu; przy 404 aplikacja przechodzi na starszy Flash i zapisuje rzeczywiście używany model. Dane wcześniejszego MVP pozostają zgodne z nowym formatem.

---

# Fluent — plan produktu i pierwszej wersji

## 1. Produkt

Kompaktowa aplikacja do nauki angielskiego dla osób polskojęzycznych. Użytkownik zapisuje słowa, zwroty i zdania w kontekście. Jednostką nauki jest konkretne znaczenie. Krótkie sesje rozwijają kilka umiejętności, a powtórki wracają w rytmie wynikającym z odpowiedzi.

## 2. Mapa ekranów i ścieżek

- Dzisiaj: cel, propozycja sesji, statystyki tygodnia, kolekcje, ostatnie słowa.
- Mój słownik: wyszukiwanie → filtry → szczegóły wpisu → znaczenia i wyniki → edycja lub archiwizacja.
- Dodawanie: słowo → jedno lub kilka znaczeń → przykłady → kontekst i rejestr → kolekcja i tagi → zapis.
- Kolekcje: tworzenie kolekcji → jej słowa → ćwiczenia kolekcji.
- Ćwiczenia: wybór 5/10/15 minut i trybu → zadania → podpowiedź i druga próba → ocena pewności → zapis → podsumowanie. Wstrzymana sesja pozostaje na koncie.
- Postępy: słowa i znaczenia, umiejętności, historia tygodnia, trudne słowa, kalendarz, CEFR, prognoza powtórek i tygodniowe przekroczenia progu opanowania.
- Ustawienia: cel, pora nauki, motyw, akcent, tempo, konto, eksport, import, usuwanie danych, plan rozwoju.

Główna ścieżka: Dzisiaj → Zaczynam naukę → maksymalnie 10/20/30 zadań → podsumowanie. Sesja może być krótsza, jeśli zbiór jest mniejszy. Czas jest szacunkiem.

## 3. Zakres zbudowanego MVP

- Konto przez ChatGPT; niezależne dane każdego zalogowanego właściciela.
- Gościnny demonstrator bez trwałego zapisu.
- Ręczne dodawanie i edytowanie wielu znaczeń, przykładów, rejestru, IPA, form, kolokacji, synonimów, antonimów, źródła, notatki, tagów i kolekcji.
- Przykładowe rozróżnienie banku finansowego i brzegu rzeki; brak automatycznego wybierania pierwszego znaczenia.
- Pięć typów zadań: fiszka w kontekście, polski → angielski, luka w zdaniu, wybór znaczenia, dyktando słowa.
- Synteza mowy dla słów i przykładów. UK/US i wolne tempo wykorzystują dostępne głosy urządzenia.
- Powtórki adaptacyjne; osobne wyniki rozpoznawania, przypominania, pisowni, słuchania i użycia w zdaniu. Wymowa pozostaje nieoceniona.
- Tryb pomyłek uwzględnia błędy, wolne przypominanie i ręczne oznaczenie trudności; pary borrow/lend, say/tell, make/do.
- Podpowiedź i druga próba, wyjaśnienie odpowiedzi na podstawie zapisanego kontekstu, zmiana przykładu pomiędzy powtórkami.
- Import listy, CSV/TSV; eksport CSV do mapowania pól Anki; pełna kopia JSON.
- Archiwizacja z zachowaniem historii, wyszukiwanie i filtry, postępy.
- Responsywność, motyw jasny/ciemny, nawigacja klawiaturą, skupienie.
- Manifest PWA i ekran braku połączenia. Pełna nauka offline nie jest częścią tego wydania.

## 4. Technologie i konto

React, TypeScript, Vinext oraz Cloudflare Worker i D1 (SQLite). Komponenty dialogów, paneli i wyborów pochodzą z dostępnego zestawu Radix/Shadcn. Synteza mowy: Web Speech API. PWA: manifest, ikony, service worker i bezpieczny ekran offline bez buforowania dokumentów zawierających dane konta.

Logowanie i hasła obsługuje ChatGPT. Fluent nie prowadzi własnej rejestracji hasłem ani nie przechowuje haseł. Profil Fluent powstaje przy pierwszym zalogowanym wejściu. Usuwanie danych Fluent nie usuwa konta ChatGPT.

Trwały zapis do D1 następuje po każdym zakończonym zadaniu i każdej zmianie danych. Na innym urządzeniu odświeżenie pobiera aktualny stan. Optymistyczna kontrola wersji odrzuca konflikt zamiast cicho nadpisywać zmiany. Po nieudanym zapisie interfejs pokazuje błąd i umożliwia eksport lokalnego stanu. Niezapisane zmiany nie przetrwają zamknięcia strony; pełny dziennik offline jest następnym etapem.

## 5. Model danych

### Model logiczny

- Profil: dzienny cel, akcent, tempo, preferowana pora.
- Kolekcja: nazwa, powiązanie wpisów.
- Wpis: stabilny ID, angielski tekst, IPA, część mowy, CEFR, kolekcja, tagi, źródło, notatka, formy, kolokacje, synonimy, antonimy, ważność, trudność, archiwum.
- Znaczenie: stabilny ID, polski przekład, definicja, przykłady, kontekst, rejestr i naturalny odpowiednik.
- Umiejętność znaczenia: wynik 0–100, odstęp, następny termin, poprzedni termin, poprawne odpowiedzi, błędy i wolne odpowiedzi.
- Historia odpowiedzi: ID, wpis, znaczenie, umiejętność, czas, wynik, podpowiedź, pewność, typ błędu, wynik przed i po.
- Sesja: lista zadań, bieżący indeks, liczba poprawnych odpowiedzi, tryb i planowany czas.

### Fizyczny model MVP

Tabela `learners`: `owner TEXT PRIMARY KEY`, `content TEXT NOT NULL`, `revision INTEGER NOT NULL`, `updated_at INTEGER NOT NULL`.

`content` to walidowany dokument powyższego modelu, odrębny dla każdego właściciela. Taki agregat umożliwia atomowy zapis sesji i postępu z kontrolą wersji. Zapytania zawsze ograniczają dostęp do identyfikatora z uwierzytelnionego nagłówka serwera. Parametry SQL są wiązane. Przy większej skali planowana normalizacja do users, collections, entries, meanings, examples, skill_states, review_events i sessions, z indeksami po właścicielu i terminie powtórki.

## 6. Algorytm powtórek

Przejrzysty heurystyczny algorytm MVP; nie jest implementacją ani klinicznie zweryfikowaną kalibracją FSRS.

- Osobny stan dla każdej pary znaczenie × umiejętność.
- Poprawna samodzielna odpowiedź zwiększa wynik o 9, o 14 przy wysokiej pewności; wolna odpowiedź (>12 s) tylko o 4.
- Odpowiedź z podpowiedzią zwiększa wynik o 2 i rejestruje brak samodzielności.
- Niepoprawna odpowiedź obniża wynik o 18, z minimum 0.
- Wynik mieści się w przedziale 0–100. Średnia ćwiczonych umiejętności daje wskaźnik znaczenia, nie pełną biegłość. Niećwiczone umiejętności wyświetlają „—”.
- Czynnik odstępu: max(1,15; 2,5 − kara za niepewność − 0,65 za powolną odpowiedź − min(0,45; 0,04 × poprzednie błędy)).
- Samodzielna poprawna odpowiedź: nowy odstęp od 1 do 90 dni, zależny od poprzedniego odstępu, czynnika i małego dodatku za rzeczywisty upływ czasu.
- Z podpowiedzią: 12 godzin. Błąd: 10 minut. Sesja nie przerywa się z powodu błędu.
- Maksimum 90 dni zapewnia powtórki kontrolne.
- Kolejka rozpoczyna od najwcześniej wymagalnych znaczeń, potem dobiera pozostałe. Powtórki pomyłek priorytetyzują liczbę błędów i wolnych odpowiedzi.
- Pisownia jest dodatkowo oceniana w tłumaczeniu i dyktandzie. Luka ćwiczy użycie konkretnego słowa w zapisanym zdaniu. Nie oceniamy swobodnego tekstu ani wymowy w MVP.
- Czas mierzony lokalnie służy orientacyjnie; próg 12 s wymaga przyszłej personalizacji pod dostępność i długość odpowiedzi.

## 7. Projekt i komponenty

Kompaktowy pulpit z fioletową kartą sesji i pierścieniem dziennego celu. Białe powierzchnie na chłodnym tle, atramentowy tekst, fiolet jako główna akcja. Statystyki używają zieleni i bursztynu pomocniczo. Ciemny wariant stosuje te same role kolorów.

Komponenty: stała nawigacja boczna / dolna mobilna; karty kolekcji; tabela słownika; panel znaczeń; edytor wielu znaczeń; karta ćwiczenia; podpowiedź i informacja zwrotna; wybór pewności; wskaźniki postępu; histogram tygodnia; kalendarz aktywności; formularze importu i eksportu; ustawienia; komunikaty zapisu.

Dostępność: etykiety pól i ikon, semantyczne przyciski, dialogi z pułapką fokusu i Escape, widoczny fokus, link do treści, obsługa klawiaturą, ograniczenie animacji przy prefers-reduced-motion. Tabela na wąskich ekranach może przewijać się we własnym kontenerze.

## 8. Wdrożenie etapami

1. Obecna wersja: interaktywny MVP, przykładowy zestaw, trwałe konto, testowalne procesy.
2. Rozwój jakości: audyt na urządzeniach i czytnikach ekranu, scenariusze wielu urządzeń, kalibracja powtórek, rozbudowa poprawnych przykładów i walidacja importów.
3. Offline i wygoda: IndexedDB z kolejką zdarzeń, idempotentne API, łączenie konfliktów per znaczenie, powiadomienia za zgodą użytkownika, raporty tygodniowe z rzeczywistym utrzymaniem opanowania.
4. Wsparcie językowe: propozycje wszystkich istotnych znaczeń z wyborem użytkownika, tematyczne zestawy słów, czytanki, gramatyka, idiomy, warianty odpowiedzi i podpowiedzi różnic znaczeniowych. Wydobywanie kandydatów z dłuższego tekstu pozostaje kolejnym etapem.
5. Mowa i AI: mikrofon wyłącznie po działaniu użytkownika, lokalne nagranie do odsłuchu, orientacyjna transkrypcja i ocena z jasnym poziomem niepewności, krótkie dialogi i personalizacja przykładów.
6. Dalej: rozsypanki, dopasowania, rozróżnianie rejestru, naturalność wypowiedzi, wykrywanie błędów, łagodna grywalizacja, współdzielenie kolekcji i import szerszych formatów.

## Ograniczenia pierwszej wersji

Treści AI są walidowane przed zapisem, lecz mogą wymagać korekty użytkownika. Import bez przykładu wymaga ręcznego uzupełnienia kontekstu. Ocenianie wykorzystuje warianty odpowiedzi, tolerancję drobnych literówek i — przy niejednoznaczności — Gemini. Synteza mowy korzysta z Gemini TTS lub głosu urządzenia. Powiadomienia push, ocena wymowy, generowane dialogi i automatyczne wydobywanie słów są zaplanowane, nie udawane jako działające.
