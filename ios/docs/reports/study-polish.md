# Raport: study-polish (FEEDBACK-3 H1, H2, H3)

Kod pisany na Windows bez kompilatora. Każdy użyty symbol z innych plików sprawdziłem grepem i przeczytałem każdy nowy lub zmieniony plik. Lekser Node ze scratchpada (`swiftcheck.mjs`: nawiasy z interpolacją, ciągi, komentarze, BOM/CR, `try!`/`as!`/`fatalError`) przeszedł bez błędów: 270/270 plików. Gita nie uruchamiałem.

## 0. Diagnoza H2 — dlaczego nie było żadnego zadania „Słowo i zdjęcie”

**Openverse działa, URL i parametry są poprawne.** Sprawdziłem na żywo 2026-10-17, przez `curl` z dokładnie naszymi nagłówkami (User-Agent i `Accept: application/json, image/jpeg, image/png`) oraz przez WebFetch.

| Zapytanie | Wynik |
|---|---|
| `GET /v1/images/?q=apple&license=cc0,by,by-sa&category=photograph&extension=jpg,png&mature=false&page_size=12` | 200, `result_count` 240, 12 wyników z `thumbnail` |
| to samo dla `cutting board` (WebFetch) | 200, 240 wyników |
| `GET /v1/images/{id}/thumb/` | 200 `image/jpeg`, sygnatura `FF D8 FF` |
| 6 haseł × 3 miniatury | wyszukiwanie trwało 0,04–7,1 s, miniatura 0,05–0,9 s |

Limity z nagłówków bez zmian: `anon_burst 20/min`, `anon_sustained 200/day`, `anon_thumbnail 1000/day`.

**Zdjęcia blokowała logika aplikacji.** Przyczyny w kolejności wagi:

1. **Prefetch prawie nigdy nie startował w dobrym momencie.**
   - Był wołany tylko w dwóch miejscach:
     - raz po starcie, w `AppEnvironment.onAppear`. Przy świeżej instalacji słownik jest wtedy pusty, bo onboarding dodaje słowa dopiero później, więc było 0 kandydatów;
     - w `StudyHomeView.task(id: store.loadPhase)`. To zadanie uruchamia się tylko przy pojawieniu się ekranu, bo `loadPhase` po wczytaniu już się nie zmienia.
   - Prefetch nie startował po dodaniu słów, po sesji ani przed sesją.
2. **Jeden przebieg i koniec.**
   - Przebieg to co najwyżej 12 wyszukiwań co 3,5 s, czyli około 45–60 s, a potem cisza do następnego uruchomienia aplikacji.
   - Sesja uruchomiona od razu po dodaniu tematu widziała 0 zdjęć na dysku.
   - Zadanie zdjęciowe jest losowane tylko z tego, co już jest w cache **w chwili budowania sesji**. Potrzebne są co najmniej 4 konkretne rzeczowniki ze zdjęciami.
3. **Pojedynczy wolny serwer zatrzymywał cały przebieg.**
   - `URLError.timedOut` przy timeoucie 12 s był mapowany na `offline`, a to przerywało cały przebieg.
   - Wyszukiwanie w Openverse potrafi trwać 4–7 s, pod obciążeniem dłużej.
4. **Zadanie znikało po cichu.**
   - `readyMeaningIDs` sprawdzało tylko, czy 3 zdjęcia różnią się od celu, a nie czy różnią się **między sobą**.
   - `StudyPictureLoader` wymagało wzajemnie różnych dystraktorów. Przy losowaniu bez takiego zestawu (np. apple / apple pie / apple tree) zadanie zdjęciowe pokazywało się po cichu jako „Wybierz znaczenie”, więc właściciel go nie rozpoznawał.
5. **Zachowanie zgodne z projektem, które zmniejszało szanse:**
   - zdjęcie pojawia się dopiero od drugiego kontaktu ze słowem, z prawdopodobieństwem 1/2 lub 1/3 w danym etapie progresji;
   - w „Codziennej mieszance” z kilkoma trybami słówek jest mało;
   - słowa z tematów nie-konkretnych w ogóle nie dostają zdjęć: negocjacje, spotkania, tematy z AI (ich `contentRef` jest spoza `concreteTopics`), abstrakcje typu „standby”.

## 1. Co zrobiono

### H1 — jeden mechanizm odpowiedzi

- `Features/Study/Session/VocabExerciseModel.swift`:
  - nowy `enum VocabInputStyle { flashcard, picture, choice, typing }` i `inputStyle`: „Wybierz znaczenie” z widocznymi opcjami (co najmniej 2) daje `.choice`, w pozostałych przypadkach `.typing`;
  - nowe `chooseOption(at:)`:
    - ocenia po **tożsamości opcji** (`correctOption` to znormalizowane tłumaczenie), więc dystraktor nigdy nie zostanie uznany za „literówkę”;
    - pierwszy błąd daje drugą próbę z podpowiedzią; błędna opcja zostaje oznaczona i zablokowana;
  - `chosenOption`, `wrongOptions`, `correctOption`;
  - `showVariants()` czyści wpisany tekst i przełącza na wybór;
  - `check()` działa tylko przy `.typing`;
  - stary `choose(_:)` usunięty (nie miał innych wywołań).
- `Session/VocabAnswerArea.swift`:
  - pole tekstowe nie pokazuje już listy opcji obok siebie; „Pokaż warianty” to tylko przycisk przełączający;
  - nowy `VocabMeaningChoiceArea`:
    - lista 1–4 ze skrótami klawiszowymi (już bez kolizji z polem);
    - „Jeszcze nie” w drugiej próbie, podpowiedź i „Pokaż odpowiedź”, bez „Sprawdź”;
    - po odpowiedzi lista zostaje z zaznaczeniem poprawnej i błędnej opcji.
- `Session/VocabExerciseView.swift`:
  - `VocabExerciseInput` robi `switch model.inputStyle`;
  - autofokus i fokus w drugiej próbie tylko przy `.typing`;
  - zmiana stylu chowa klawiaturę.
- Przegląd pozostałych typów:
  - **sesja słówek:** tłumaczenie, luka i dyktando mają tylko pole; zdjęcie tylko dotknięcie (1–4); fiszka tylko przyciski i gest;
  - **sesja łączona** (`CombinedQuestionView`): `isInput` daje tylko pole, inaczej tylko ABCD. Produkcja ma `options` w danych, ale widok pokazuje wyłącznie pole. Bez zmian.

### H2 — zdjęcia

**Serwis (`Services/Images/`)**

- **Nowy** `WordImagePrefetcher.swift` (`@MainActor @Observable`, jeden na serwis zdjęć, `shared(store:images:)`):
  - `request()` zaczyna lub kontynuuje pracę. Startuje 2 s po wywołaniu, czyli po pierwszej klatce i po pracy startowej;
  - kandydatów liczy `store.compute` (poza głównym wątkiem), a pobiera aktor;
  - przebiegi idą seriami: co najwyżej 8 przebiegów na prośbę, każdy do 24 kandydatów i 12 wyszukiwań, z 30 s przerwy między przebiegami. Daje to ≤ 17 wyszukiwań na minutę;
  - pętla zatrzymuje się, gdy nie ma postępu, przy braku sieci, po 429 i po wyczerpaniu limitu dziennego;
  - obserwuje liczbę słów (`withObservationTracking` na `store.state.words.count`) i po dodaniu słów sam woła `request()`;
  - `UIApplication.didEnterBackgroundNotification` anuluje zadanie (anulowane `URLSession` daje `CancellationError`); `willEnterForeground` wznawia;
  - `status` (`idle / working / offline / waiting / disabled`), `statusText`, `cachedCount`, `lastStop`.
- `WordImageService.swift`:
  - `prefetch` zwraca `WordImagePrefetchReport` (z `@discardableResult`) z liczbą wyszukiwań i pobrań oraz `stop`: `finished / busy / disabled / offline / rateLimited / dailyLimit / runLimit / cancelled`;
  - dzienne limity trwałe w pliku przypisań:
    - `maxSearchesPerDay = 150` (Openverse pozwala na 200);
    - `maxDownloadsPerDay = 600` (pozwala na 1000);
  - `lastError` i `lastRunAt`;
  - `diagnostics()`;
  - `searchInterval` wstrzykiwany (testy używają 0);
  - po osiągnięciu limitu wyszukiwań przebieg dalej pobiera zdjęcia dla haseł wyszukanych wcześniej;
  - `reject` zapisuje stan po pobraniu następnego kandydata.
- `WordImageModels.swift`:
  - `WordImageStoreFile` dostał nowe pola `counterDay`, `searchesToday`, `downloadsToday`, `lastRunAt`, `lastError`; stary plik dekoduje się z zerami;
  - nowe `WordImagePrefetchReport` i `WordImageDiagnostics`.
- `OpenverseClient.swift`:
  - `.cancelled` daje `CancellationError`;
  - `.timedOut` daje nowy `WordImageError.timedOut` (pomija słowo, nie przerywa przebiegu);
  - timeouty: 20 s na zapytanie, 40 s na zasób;
  - adnotacja o weryfikacji z 2026-10-17.

**Wpięcie**

- `App/AppEnvironment.swift`: zmieniona **tylko treść** `prefetchWordImages()` (zgoda koordynatora) — teraz woła `WordImagePrefetcher.shared(...).request()`. Sygnatura i reszta pliku bez zmian.
- `Features/Study/Support/StudyStarter.swift`:
  - `request()` przy każdym starcie sesji (`start`, `startVocabulary`, także „Jeszcze 5 minut”);
  - nowy komunikat dla pustego trybu „Słowa i obrazki”, zależnie od sytuacji:
    - brak słów do pokazania na zdjęciu;
    - brak internetu;
    - przerwa serwisu;
    - zdjęcia jeszcze się pobierają (X gotowych).

**Tryb „Słowa i obrazki”**

- FluentKit `Models/Enums.swift`: `StudyMode.pictures = "pictures"`:
  - `isVocabulary == true`, `isCombinable == false`;
  - nie trafia do siatki trybów ani do sesji łączonej.
- FluentKit `Sessions/SessionBuilder.swift`:
  - nowe publiczne `makePictureSession(state:minutes:collection:pictureMeaningIDs:using:)`:
    - tylko zadania `.picture` dla gotowych znaczeń (także nowych, bo tryb wybrany świadomie);
    - najpierw ćwiczone według terminu, potem nowe;
    - limit `minutes × 60 / 20 s`, kolejność losowa;
    - `mode = "pictures"`;
  - `makeSession(mode: .pictures)` deleguje do `makePictureSession`.
- FluentKit `Sessions/PictureExercise.swift`:
  - `readyMeaningIDs` liczy przez nowe `greedyDistractors` (dystraktory wzajemnie różne), więc zadanie uznane za gotowe zawsze da się pokazać;
  - nowe `pendingCount(state:excluding:)` liczy kolejkę.
- `Features/Study/Picture/StudyPictureSupport.swift`: gdy losowanie dystraktorów zawiedzie, zapasowo bierze `greedyDistractors`.
- **Nowy** `Features/Study/Picture/StudyPicturesCard.swift`:
  - karta na ekranie Nauka: „Zdjęcia: X z N słów” z paskiem, status (pobieranie w tle / brak internetu / przerwa serwisu), „Ćwicz ze zdjęciami”;
  - przycisk jest wyłączony, dopóki nie ma gotowych zestawów, a podtytuł mówi wtedy dlaczego;
  - `StudyPicturesSnapshot` liczy się poza głównym wątkiem.
- `Home/StudyHomeView.swift`:
  - karta jest nad wyborem trybów, gdy profil ma styl „Obrazki”, w przeciwnym razie pod nim;
  - snapshot odświeża się po `revision`, `cachedCount` i `loadPhase`;
  - router z `modes: ["pictures"]` uruchamia tryb bez zmiany zapamiętanego wyboru.
- `Support/StudyFlow.swift`: opis i ikona `.pictures` (`photo.on.rectangle`).

**Diagnostyka**

- **Nowy** `Features/Study/Picture/StudyImageDiagnosticsRow.swift` pokazuje:
  - liczbę słów ze zdjęciem, w kolejce i bez pasującego zdjęcia;
  - dzisiejsze wyszukiwania (X z 150) i pobrania;
  - status pobierania;
  - ostatnie pobieranie i ostatni błąd (albo „brak”);
  - przerwę serwisu do godziny (po 429).
- `Features/Settings/SettingsSections.swift`: **jeden wiersz** `StudyImageDiagnosticsRow()` w `SettingsDataSection` („Twoje dane należą do Ciebie”), pod „Eksportuj dane”.

### H3 — fiszki jak w Quizlecie

- `Flashcards/FlashcardCardView.swift` (przepisany):
  - przód pokazuje tylko wyraz (`flashcardTerm`, wyśrodkowany) — **losowo PL albo EN**, bez IPA, poziomu i zdania;
  - dotknięcie obraca kartę w 3D: `FlashcardFlip: View, Animatable`, strona zmienia się dokładnie przy 90°, tył jest odbity. Przy „Ogranicz ruch” zamiast obrotu jest przenikanie;
  - tył pokazuje odpowiednik w drugim języku; gdy jest angielski, dochodzi `SpeakButton`;
  - niewidoczna strona ma `allowsHitTesting(false)`;
  - przesunięcie w prawo i w lewo działa jak dotąd;
  - VoiceOver: etykieta z obu stron po odwróceniu, akcje „Pamiętam” / „Jeszcze nie” / „Odtwórz wymowę”;
  - nowe `FlashcardFace`, `FlashcardFaces` i `FlashcardExampleView` („Pokaż przykład” / „Ukryj przykład”: zdanie, odsłuch, tłumaczenie — tylko po odwróceniu, na życzenie).
- `FlashcardDeckModel.swift`:
  - nowe `frontIsPolish` (losowane `Bool.random()` dla każdej karty, także powracającej) i `exampleShown`, `toggleExample()`;
  - `showNextCard()` resetuje stronę i przykład;
  - zakrycie karty chowa przykład.
- `FlashcardDeckScreen.swift`:
  - przekazuje `frontIsPolish`; pod odwróconą kartą `FlashcardExampleView`;
  - obrót z `easeInOut(0.4)`, bo sprężyna kręciła kartę za 180°;
  - przyciski „Jeszcze nie” (←) i „Pamiętam” (Enter): zapis i od razu następna karta, jak dotąd;
  - nowy opis talii.

## 2. Publiczne API / kontrakty

```swift
// FluentKit
enum StudyMode { …; case pictures }   // isVocabulary: true, isCombinable: false, namePl „Słowa i obrazki”
SessionBuilder.makePictureSession(state:minutes:collection: String? = nil, pictureMeaningIDs: Set<String>, using:) -> VocabSession
PictureExercise.greedyDistractors(for:pool:count:) -> [WordMeaning]
PictureExercise.pendingCount(state:excluding:) -> Int
// Aplikacja
WordImagePrefetcher.shared(store:images:) / .request() / .stop() / .status / .statusText / .cachedCount / .lastStop
WordImageService.prefetch(_:) -> WordImagePrefetchReport (@discardableResult), .diagnostics() -> WordImageDiagnostics
WordImageService.init(networkEnabled:storeURL:cacheDirectory:session:searchInterval:)   // nowy parametr z wartością domyślną
StudyLaunchRequest(modes: ["pictures"])  // uruchamia tryb „Słowa i obrazki”
```

**Zgodność wstecz:**

- Starsza wersja aplikacji odczyta `VocabSession.mode = "pictures"` jako `.mixed`.
- `CombinedSession.modes` pomija nieznane tryby.
- Stary `word-images.json` dekoduje się z zerowymi licznikami.

## 3. Odstępstwa i decyzje

1. **W trybie „Słowa i obrazki” zdjęcie pojawia się też przy pierwszym kontakcie.** Użytkownik wybrał ten tryb świadomie. W sesjach mieszanych zostaje „od drugiego kontaktu”, jak wymaga H2.
2. **Błąd w zadaniu zdjęciowym wraca w tej samej sesji jako „Wybierz znaczenie”** (`Scheduler`, bez zmian). Moim zdaniem to dobra powtórka, ale da się to zmienić — patrz §5.
3. **Wybór opcji w „Wybierz znaczenie” zachowuje drugą próbę** (jak przy wpisywaniu): błędna opcja jest zablokowana, podpowiedź się odsłania, a odpowiedź liczy się jako „z pomocą”.
4. **Limit dzienny 150 wyszukiwań** (zamiast 200) zostawia zapas na „Zdjęcie nie pasuje” i na ponowne próby.

## 4. Ryzyka kompilacji — gdzie patrzeć najpierw na Macu

1. **`WordImagePrefetcher.swift`:**
   - `withObservationTracking { _ = store.state.words.count } onChange: { [weak self] in Task { @MainActor [weak self] in … } }`. `onChange` to `@autoclosure @Sendable`; trailing closure to typowy wzorzec;
   - `private static var registry: [ObjectIdentifier: WordImagePrefetcher]` w klasie `@MainActor`, `ObjectIdentifier(images)` na aktorze;
   - bloki `NotificationCenter.addObserver(forName:object:queue:)` z `Task { @MainActor … }`.
2. **`FlashcardCardView.swift`:**
   - `private struct FlashcardFlip: View, Animatable` z `animatableData`. Interpolacja kąta zależy od tego, czy SwiftUI animuje `Animatable` na zwykłym `View` — robi to, ale sprawdzić wizualnie;
   - `rotation3DEffect(_:axis:perspective:)` z pominiętym `anchor`;
   - `.accessibilityAction { … }` (akcja domyślna).
3. **`WordImageService.prefetch`:**
   - etykieta `loop:` z `break loop` / `continue loop` wewnątrz `do/catch`;
   - `catch WordImageError.rateLimited(let retryAfter)`;
   - `if (try? await ensureDownloaded(...)) == true` w `reject`.
4. **`VocabExerciseModel.inputStyle`:** ternary `variantsShown && options.count >= 2 ? .choice : .typing` (priorytet operatorów jest poprawny; w razie ostrzeżenia dodać nawiasy).
5. **`StudyHomeView`:** właściwość `picturesCard` (zwykła computed `some View` z `let` + `return`); klucz `.task(id: picturesKey)`.
6. **`StudyPicturesCard`:** `switch status` wewnątrz `HStack` (ViewBuilder) i `.controlSize(.small)`.
7. **`StudyPolishAppTests`:**
   - `OpenverseStubProtocol` ze `static var handler`. W trybie Swift 5 / minimal to OK; przy Swift 6 trzeba by dodać `nonisolated(unsafe)`;
   - testy `async` na aktorze.

## 5. Prośby do innych ról

- **onboarding-progress:**
  - `LearnerProfile.preferredStudyModes()` mapuje styl `.pictures` na `StudyMode.mixed` (FluentKit `Profile/`, poza moim obszarem). Można mapować na `.pictures`. Ekran Nauka już przesuwa kartę „Słowa i obrazki” nad wybór trybów dla tego stylu;
  - `dailyMixModes` i tak odfiltrowuje tryby nie-łączone.
- **core-engine (opcjonalnie):** `Scheduler.recordAnswer` w sesji `mode == "pictures"` mógłby powtarzać błąd jako `.picture`, a nie `.meaning`. Obecnie to „Wybierz znaczenie”.
- **code-qa:** sprawdzić punkty z §4. Do `MANUAL-TEST-PLAN.md` dopisać scenariusze z §6.

## 6. Testy

**FluentKit — nowe `Tests/FluentKitTests/StudyPolishTests.swift` (8 testów):**

- tryb `.pictures`: wokabularny, nie-łączony, dekodowanie `VocabSession`, sesja łączona go pomija;
- sesja zdjęciowa:
  - tylko `.picture` dla gotowych znaczeń, także nowych;
  - najpierw ćwiczone, budżet 15 zadań na 5 min;
  - pusta bez zdjęć;
  - filtr kolekcji;
- `readyMeaningIDs` wymaga dystraktorów wzajemnie różnych (car + apple / apple pie / apple tree daje brak gotowych);
- `greedyDistractors`;
- `pendingCount`.

**FluentKit — zaktualizowany `PracticeModesTests`:** `combinableModes.count == allCases.count - 2`, `.pictures` nie jest łączony.

**Aplikacja — nowe `FluentNOWTests/StudyPolish/StudyPolishAppTests.swift` (10 testów):**

- **H1:**
  - opcje widoczne oznaczają tylko wybór; wpisanie i „Sprawdź” są ignorowane;
  - błąd daje drugą próbę, a błędna opcja zostaje zablokowana;
  - „Pokaż warianty” przełącza z wpisywania na wybór i czyści tekst; odpowiedź liczy się jako z pomocą;
  - opcja „krzesła” przy poprawnym „krzesło” nigdy nie jest literówką;
  - przy jednej opcji jest wpisywanie;
- **H3:** strony fiszki w obu językach;
- **H2:**
  - stub `URLProtocol`: wyszukiwanie, pobranie, cache i liczniki dzienne; drugi przebieg nie wyszukuje ponownie; URL zawiera filtry licencji;
  - HTTP 429 przerywa przebieg i blokuje kolejne zapytania (zero żądań);
  - serwis offline daje `.disabled`;
  - stary plik dekoduje się z zerowymi licznikami;
  - logika pauz prefetchera: kontynuacja tylko przy postępie i pracy; ≤ 20 wyszukiwań/min, < 200 dziennie.

Testów Swift nie uruchamiałem, bo na Windows nie ma kompilatora. Lekser Node: 270/270 OK.

**Do sprawdzenia ręcznie na Macu:**

1. **Świeża instalacja:** onboarding, potem dodaj temat „Owoce i warzywa” albo „Dom”.
   - W ciągu około 1 minuty karta „Słowa i obrazki” na ekranie Nauka pokazuje rosnące „Zdjęcia: X z N” ze statusem „Pobieram zdjęcia w tle…”.
   - Ustawienia → Dane pokazuje liczby i „Ostatni błąd: brak”.
2. **„Ćwicz ze zdjęciami”:** same zadania „Słowo i zdjęcie”.
3. **Druga „Codzienna mieszanka”** po pierwszej sesji z tymi słowami: pojawiają się zadania zdjęciowe.
4. **Tryb samolotowy:** karta pokazuje „Brak internetu — …”, a komunikat po dotknięciu (gdy zdjęć brak) jest jasny. Zdjęcia pobrane wcześniej dalej działają.
5. **Aplikacja w tle podczas pobierania:** pobieranie staje i wraca po powrocie (licznik w Ustawieniach rośnie dalej).
6. **„Wybierz znaczenie” przy pierwszym kontakcie:** brak pola tekstowego, klawisze 1–4; błąd daje „Jeszcze nie” z zablokowaną opcją.
7. **Kolejny kontakt:** pole tekstowe; „Pokaż warianty” je chowa.
8. **Fiszki:**
   - przód raz PL, raz EN;
   - obrót 3D, a z „Ogranicz ruch” przenikanie;
   - odsłuch tylko na angielskiej stronie;
   - „Pokaż przykład” dopiero po odwróceniu;
   - „Jeszcze nie” / „Pamiętam” i przesunięcia.
