# Raport: practice-modes (FEEDBACK-2 G2 + G3)

Kod pisany na Windows bez kompilatora. Każdy symbol z innych plików sprawdzony grepem. Każdy nowy i zmieniony plik przeczytany ponownie. Lekser Node (nawiasy z interpolacją `\(`, ciągi, komentarze, BOM/CR, `try!`/`as!`/`fatalError`) przeszedł bez błędów: 263 pliki Swift, 0 problemów. Gita nie uruchamiałem.

## 1. Co zrobiono

### G3 — fiszki znikają z sesji, nowy tryb „Fiszki”

**FluentKit**

- `Models/Enums.swift`
  - Nowy przypadek `StudyMode.flashcards = "flashcards"` („Fiszki”).
  - Nowe `isCombinable`: `false` dla fiszek.
  - Nowe `StudyMode.combinableModes`.
  - `ExerciseType.retryType`: dyktando wraca jako `.meaning`, a nie fiszka.
  - Nowe `ExerciseType.sessionTypes`: wszystkie typy oprócz fiszki.
- `Sessions/SessionBuilder.swift`
  - `allowedTaskTypes`: pierwszy kontakt to `[.meaning]` (wcześniej `[.flashcard]`); przy mniej niż 2 poprawnych rozpoznaniach też `[.meaning]`. Dalsza progresja bez zmian.
  - `chooseType`: w etapie „wszystko dozwolone” losuje z `sessionTypes`, więc fiszka nigdy nie trafia do sesji.
  - Nowe publiczne:
    - `isFirstContact(_:)`;
    - `retryType(after:meaning:)`: nowe słowo, które nie wyszło przy pierwszym kontakcie, wraca jako `.meaning` z innym zdaniem, a nie jako dyktando;
    - parametr `pictureMeaningIDs` w `makeSession`.
- `Scheduling/Scheduler.swift`
  - Typ powtórki liczy `SessionBuilder.retryType(after:meaning:)`.
  - Etykieta błędu dla zdjęcia.
- `Sessions/CombinedSessionBuilder.swift`
  - `makeSession` odfiltrowuje tryby z `isCombinable == false`.
  - Nowy parametr `pictureMeaningIDs` (domyślnie pusty).
- **Nowy** `Sessions/FlashcardDeck.swift`:
  - `FlashcardGroup` (due / new / hard), `FlashcardCard`, `FlashcardDeckCounts`;
  - `FlashcardRun`: pozycja w talii; zapomniana karta wraca raz na koniec; `dropMissing` usuwa karty skasowanych słów;
  - `FlashcardDeckBuilder`:
    - `counts`;
    - `makeDeck`: kolejność do powtórki → nowe (≤ 10) → trudne, limit, filtr kolekcji;
    - `record`: `Scheduler.recordAnswer` z typem `.flashcard`, umiejętność recognition, pewność 2; przerwana sesja słownictwa zostaje nietknięta.

**UI (`Features/Study/`)**

- **Nowe** `Flashcards/FlashcardDeckModel.swift`, `FlashcardDeckScreen.swift`, `FlashcardCardView.swift`, `FlashcardSummaryView.swift`. Ekran działa tak:
  - wybór talii: liczniki grup, kolekcja, 10/20/30 kart;
  - karta: dotknięcie odwraca;
  - przesunięcie w prawo = pamiętam, w lewo = nie pamiętam; są też przyciski, Enter / ←, akcje VoiceOver;
  - po decyzji zapis i od razu następna karta (jak F3), z haptyką `swipeCommit`;
  - licznik „Karta N z M”, pasek postępu, etykieta grupy;
  - krótkie podsumowanie: „Pamiętasz” / „Do powtórki”, lista słów do powrotu, „Jeszcze raz te, których nie pamiętasz”, „Nowa talia”.
- `Home/StudyHomeView.swift`:
  - karta `StudyFlashcardsCard` z licznikami (liczone w `store.compute`);
  - `router.startStudy` z `modes: ["flashcards"]` otwiera talię;
  - wybór trybów filtruje `isCombinable`;
  - start sesji przekazuje `env.images`;
  - prefetch zdjęć przy wczytaniu.
- `Home/StudySetupCard.swift`: siatka trybów pokazuje `StudyMode.combinableModes`.
- `Support/StudyFlow.swift`: nowe `StudyFlow.flashcards(collection:)`, opis i ikona trybu.
- `StudyFlowView.swift`: nowy przypadek fiszek.
- `Support/StudyStarter.swift`: tryb `.flashcards` otwiera talię; `images` w `start` / `startVocabulary`; `pictureMeaningIDs` przy budowie sesji.
- `Session/VocabExerciseContent.swift`: `isFirstContact`, `showsMeaningOptionsAtOnce`, `asMeaningTask(...)`.
- `Session/VocabExerciseModel.swift`:
  - przy pierwszym kontakcie cztery opcje są widoczne od razu i **nie** liczą się jako podpowiedź;
  - `replaceOptions` może podmienić opcje, póki nic nie wybrano.

Stare przerwane sesje z fiszkami nadal działają, bo widok fiszki w sesji został.

### G2 — „Słowo i zdjęcie”

**FluentKit**

- Nowy `ExerciseType.picture = 5`: „Słowo i zdjęcie”, umiejętność recognition, 20 s, powtórka jako `.meaning`, bez podpowiedzi. Zaktualizowane wszystkie `switch`:
  - `Enums`;
  - `VocabularyGrader.vocabularyAnswers`;
  - `HintBuilder` (strażnik i `primaryVocabularyAnswer`);
  - `Scheduler.errorLabel`.
- **Nowy** `Sessions/PictureExercise.swift`:
  - `isPicturable`:
    - część mowy „rzeczownik” / noun, najwyżej 3 słowa;
    - lista abstrakcji, sufiksy angielskie (z wyjątkami), sufiksy polskie `-ość` / `-izm`;
    - wpisy wbudowane tylko z `concreteTopics` (66 tematów).
    - Na treści: 2 810 z 5 939 rzeczowników przechodzi.
  - `searchQuery`.
  - `prefetchCandidates`: najpierw ćwiczone, wg terminu; potem nowe.
  - `cachedItems`, `readyMeaningIDs`: zdjęcie w cache plus 3 wyraźnie różne dystraktory w cache.
  - `isClearlyDifferent`: inne słowo, hasła nie zawierają się nawzajem, inny rdzeń 4 liter, inne tłumaczenie, nie synonim.
  - `distractors`: do 2 z tego samego tematu lub kolekcji, reszta z innych.
  - `optionOrder`: kolejność stała dla danego klucza zadania.
- Zadanie zdjęciowe jest losowane tylko dla znaczeń z `pictureMeaningIDs`, nigdy przy pierwszym kontakcie, i tam, gdzie progresja dopuszcza `.meaning` (oraz w etapie „wszystko dozwolone”).

**Serwis zdjęć (nowy `Services/Images/`)**

- `OpenverseClient.swift`
  - API zweryfikowane 2026-10-15 (schemat OpenAPI i zapytanie na żywo).
  - Zapytanie: `GET https://api.openverse.org/v1/images/?q=…&license=cc0,by,by-sa&category=photograph&extension=jpg,png&mature=false&page_size=12`.
  - Pobierana jest miniatura `thumbnail` (`/v1/images/{id}/thumb/`, JPEG ok. 600 px, ok. 80 KB).
  - Limity anonimowe z nagłówków: wyszukiwanie 20/min i **200/dzień**, miniatury 1000/dzień.
  - Sesja `ephemeral`: timeout 12 s / 25 s, `waitsForConnectivity = false`, bez cookies, User-Agent `FluentNOW/1.0 (iOS; …; https://github.com/Skat33/FluentNOW)`.
  - Filtry: licencja, mature, typ pliku, krótszy bok ≥ 160 px, proporcje ≤ 2,4. Wyniki z hasłem w tytule lub tagach idą pierwsze.
  - Sprawdzana sygnatura JPEG/PNG i limit 2,5 MB.
  - Błędy typowane: `offline`, `rateLimited` (z `Retry-After`), `http`, `notAnImage`.
- `WordImageService.swift` (aktor):
  - trwałe przypisania znaczenie → zdjęcie: lista kandydatów, wybrane, odrzucone; zapis w `Application Support/WordImages/word-images.json`, tolerancyjne dekodowanie;
  - pliki w `Caches/WordImages/<id>.jpg`; po wyczyszczeniu cache to samo zdjęcie pobiera się z tego samego adresu;
  - `prefetch`:
    - sekwencyjnie, ≥ 3,5 s między wyszukiwaniami, ≤ 12 wyszukiwań i ≤ 30 pobrań na przebieg;
    - przy braku sieci przerywa;
    - po HTTP 429 blokada do `Retry-After`;
    - wyszukiwanie bez wyników ponawia po 14 dniach;
    - uszkodzone zdjęcie odrzuca i bierze następne;
  - `reject`: zgłoszone zdjęcie nigdy nie wraca dla tego znaczenia; w tle pobiera się następny kandydat;
  - pozostałe: `cachedMeaningIDs`, `settledMeaningIDs`, `image(for:)`, `images(for:)`, `removeAll`.
- `WordImageModels.swift`: `WordImageRecord` (`licenseLabel`, `attributionLine`), `WordImageAssignment`, `WordImageStoreFile`, `WordImage`, `ImageReport`.
- `ImageReportStore.swift` (`@MainActor @Observable`):
  - plik `Application Support/image-reports.json`: słowo, znaczenie, id/URL zdjęcia, oryginał, strona źródła, `openverse/<provider>`, licencja, data, komentarz;
  - `exportFile()` → `tmp/Export/FluentNOW-zdjecia-zgloszenia-*.json`.
- `App/AppEnvironment.swift`:
  - nowe pola `images: WordImageService` i `imageReports: ImageReportStore`; parametry `init` opcjonalne, na końcu, z wartościami domyślnymi, więc istniejące wywołania się kompilują;
  - `live()` tworzy prawdziwe; podgląd: bez sieci i w pamięci;
  - nowe `prefetchWordImages()`: kandydaci liczeni w `store.compute`, pobieranie w aktorze; wołane po `onAppear` i na ekranie Nauka;
  - „Usuń wszystkie dane” czyści też zdjęcia i zgłoszenia zdjęć.

**UI**

- **Nowe** `Picture/StudyPictureSupport.swift`:
  - `StudyPictureOption`;
  - `StudyPictureLoader`: dystraktory deterministyczne wg klucza zadania, więc wznowienie pokazuje ten sam zestaw;
  - `StudyPictureAccessibility`: przy VoiceOver zadanie idzie jako „Wybierz znaczenie”.
- **Nowe** `Picture/VocabPictureViews.swift`:
  - prompt: słowo, IPA, odsłuch, siatka 2×2, skróty klawiszowe 1–4;
  - kafelek: plik dekodowany w `Task.detached` przez `preparingForDisplay`; po odpowiedzi ramka i ikona poprawny/zły oraz podpis „term — tłumaczenie”;
  - „Info o zdjęciu”: tytuł, autor, licencja, linki „Źródło” i „Licencja”, nota „korzysta z Openverse, nie jest przez nie wspierana” (wymóg regulaminu Openverse);
  - „Zdjęcie nie pasuje” po każdej odpowiedzi, dobrej i złej: wybór, które zdjęcie, opcjonalny komentarz.
- **Nowe** `Picture/StudyImageReportsExportRow.swift`: samodzielny wiersz eksportu.
- `Session/VocabExerciseModel.swift`: `pictures`, `selectedPicture`, `correctPicture`, `setPictures`, `choosePicture(at:)`. Dotknięcie zdjęcia to jedna próba bez podpowiedzi; przy błędzie wyjaśnienie „Wybrane zdjęcie to …”.
- `Session/VocabExerciseView.swift`: nowy podwidok `VocabExerciseInput` ze `switch` po typie; przy zdjęciu bez przycisku odsłuchu zdania i bez autofokusu.
- `Session/VocabPrompts.swift`: `case .picture`.
- `Session/VocabFeedbackView.swift`: akcje zdjęć.
- `Session/VocabSessionModel.swift`, `VocabSessionView.swift`:
  - `images:` w `init`;
  - wczytanie zdjęć z dysku, bez sieci w trakcie sesji;
  - przy braku zdjęć (np. wyczyszczony cache) to samo zadanie jako „Wybierz znaczenie”;
  - „Jeszcze 5 minut” też dostaje zdjęcia.

**Pliki innych obszarów (tylko mój fragment)**

- `Features/Study/Combined/CombinedSessionModel.swift` (część słownikowa, nie czytanka):
  - `images:` w `init` z wartością domyślną;
  - `loadPictures(for:)` z fallbackiem do znaczenia;
  - `CombinedSessionView.swift`: przekazuje `env.images`.
- `Features/Settings/SettingsExportScreen.swift`: jedna linia `StudyImageReportsExportRow()` w sekcji „Zgłoszenia”.

**Dokumentacja:** nowy `docs/FUTURE.md` (wysyłka zgłoszeń, własna baza zatwierdzonych zdjęć, sync przypisań, Wikimedia jako zapas, ustawienie „Zdjęcia z internetu”, fiszki do rozbudowy).

`project.yml`: bez zmian. HTTPS spełnia domyślne ATS, a pliki trafiają do targetów przez istniejące ścieżki.

## 2. Nowe / zmienione API

```swift
// FluentKit
enum ExerciseType { …; case picture = 5; static let sessionTypes: [ExerciseType] }
enum StudyMode { …; case flashcards; var isCombinable: Bool; static let combinableModes: [StudyMode] }
SessionBuilder.isFirstContact(_ meaning: Meaning) -> Bool
SessionBuilder.retryType(after: ExerciseType, meaning: Meaning) -> ExerciseType
SessionBuilder.makeSession(state:minutes:mode:collection:pictureMeaningIDs: Set<String> = [], using:)   // + wariant bez RNG
CombinedSessionBuilder.makeSession(state:modes:minutes:random:content:now:id:pictureMeaningIDs: Set<String> = [], using:)
FlashcardGroup, FlashcardCard(wordId:meaningId:example:group:attempt:), FlashcardDeckCounts, FlashcardRun(cards:)
FlashcardDeckBuilder.counts(state:collection:now:) / makeDeck(state:collection:limit:newLimit:now:) / record(_:card:remembered:seconds:now:reviewID:)
PictureCandidate; PictureExercise.isPicturable / searchQuery / prefetchCandidates / cachedItems / readyMeaningIDs / isClearlyDifferent / distractors / optionOrder
// Aplikacja
AppEnvironment.images: WordImageService (actor), .imageReports: ImageReportStore, func prefetchWordImages()
StudyStarter.start(…, images: WordImageService? = nil), startVocabulary(…, images:)
StudyFlow.flashcards(collection: String?)
router.startStudy(StudyLaunchRequest(modes: ["flashcards"], collection: …))   // otwiera talię
```

**Zgodność wstecz:**

- Stary JSON nie zawiera nowych wartości, więc dekoduje się bez zmian.
- `CombinedSession.modes` pomija nieznane tryby (było tak już wcześniej).
- `VocabSession.mode` to tekst; nieznany tryb daje `.mixed`.
- Nieznany typ zadania lub tryb w zadaniu odrzuca tylko przerwaną sesję przejściową, nigdy cały import (polityka core-engine). Test: `testNewEnumCasesRoundTripAndUnknownValuesDoNotBreakImport`.

## 3. Odstępstwa od strony i decyzje

1. **Pierwszy kontakt to „Wybierz znaczenie” z czterema opcjami widocznymi od razu.** Bez nich nowe słowo wymagałoby zgadywania i wpisywania. Wybór opcji przy pierwszym kontakcie nie liczy się jako podpowiedź, więc wynik trafia do progresji normalnie. Budżet sesji: 24 s na zadanie zamiast 18 s, czyli 5/10/15 min daje 12/25/37 nowych słów. Test `testNewWordsStillFillTheBudgetWithTheMeaningExercise`.
2. **Powtórka po błędzie respektuje progresję.** Nowe słowo nie wraca jako dyktando, tylko jako „Wybierz znaczenie” z innym zdaniem.
3. **Talia fiszek nie jest zapisywana w stanie.** Każda decyzja jest zapisana od razu, więc przerwa nic nie gubi, ale wznowienia talii nie ma. Dzięki temu nie ma konfliktu z `state.session` ani z iCloud.
4. **Zdjęcia offline.** Ćwiczenie pojawia się tylko, gdy zdjęcia są już na dysku. Bez internetu i bez cache nie ma zadań zdjęciowych. Zdjęcia pobrane wcześniej działają również offline, bo w trakcie sesji nie ma żadnego zapytania sieciowego.
5. **Przypisanie słowo → zdjęcie jest lokalne dla urządzenia** (nie przez iCloud), zgodnie z wymaganiem Caches + Application Support. Opisane w FUTURE.
6. **Jedno źródło: Openverse.** Agreguje m.in. Flickr i Wikimedia Commons. Wikimedia jako zapas opisana w FUTURE.

## 4. Ryzyka kompilacji — gdzie patrzeć najpierw na Macu

1. `Services/Images/OpenverseClient.swift` `fetch`:
   - `let result: (Data, URLResponse)` przypisane w `do`;
   - `catch let error as URLError` z listą kodów;
   - inne błędy (np. anulowanie) przechodzą dalej.
2. `Services/Images/WordImageService.swift`:
   - `break` / `continue` w `catch` wewnątrz `for`;
   - wzorce `catch WordImageError.rateLimited(let retryAfter)` i `catch WordImageError.http(let code) where …`;
   - `if try await ensureDownloaded(...)`;
   - reentrancja aktora przy `await` może nadpisać przypisanie, ale tylko kosmetycznie.
3. `Features/Study/Picture/VocabPictureViews.swift`:
   - `nonisolated static func load` z `Task.detached` zwracającym `UIImage?`; przy ostrzeżeniu `Sendable` w nowszym trybie można je wyciszyć;
   - `.keyboardShortcut(KeyEquivalent(Character(String(index + 1))), modifiers: [])`;
   - `.foregroundStyle(Palette.onAccent, borderColor)` z `.symbolRenderingMode(.palette)`;
   - symbol `photo.badge.exclamationmark` (SF Symbols 4+; gdyby go brakowało, ikona będzie pusta, aplikacja się nie wysypie).
4. `VocabExerciseModel.init`: przypisanie `variantsShown` (właściwość `@Observable` z wartością domyślną) po polu `let variantsAreFree`.
5. `FlashcardCardView`:
   - `.simultaneousGesture(drag)` razem z `.onTapGesture` w `ScrollView`; sprawdzić na urządzeniu, że pionowe przewijanie działa;
   - `.accessibilityAction(named: Text(...))`.
6. `FlashcardDeckScreen`: `Picker` z `selection: $model.collection` typu `String?` i tagami `String?.none` / `String?.some(name)`.
7. FluentKit `PictureExercise`: duże literały `Set<String>`. Duplikaty sprawdziłem skryptem (wychodzi ich 0) — duplikat w literale `Set` byłby błędem w czasie działania.
8. `FlashcardDeckBuilder.makeDeck`: zagnieżdżona funkcja `add` mutuje przechwyconą zmienną `cards`.

## 5. Co sprawdzić na Macu (ręcznie)

- **Nowy użytkownik:** dodaj temat → „Codzienna mieszanka” → same „Wybierz znaczenie” z widocznymi opcjami; nigdzie fiszek.
- **Nauka → karta „Fiszki”:**
  - liczniki;
  - kolekcja i rozmiar talii;
  - dotknięcie odwraca kartę;
  - przesunięcie w prawo i w lewo, natychmiastowe przejście;
  - zapomniana karta wraca na koniec;
  - podsumowanie i „Jeszcze raz”.
- **Zdjęcia:**
  - po uruchomieniu z internetem i chwili na ekranie Nauka powstaje `Caches/WordImages` (pliki `.jpg`);
  - słowa ćwiczone ≥ 1 raz (rzeczowniki z tematów np. Owoce, Dom) dostają zadanie „Słowo i zdjęcie”;
  - „Info o zdjęciu” i linki;
  - „Zdjęcie nie pasuje” → Ustawienia → Eksport → „Zgłoszone zdjęcia (1)” → udostępnianie;
  - przy następnym razie to słowo ma inne zdjęcie.
- **Tryb samolotowy:** sesja startuje bez błędów; zadania zdjęciowe są tylko dla zdjęć już pobranych. Z VoiceOver w ich miejscu pojawia się „Wybierz znaczenie”.
- **Jakość zdjęć:** zgłoszenia pokażą, które hasła wyłączyć. Heurystyka abstrakcji przepuszcza np. „voucher”, „spreadsheet”.

## 6. Testy

Testów Swift nie uruchamiałem, bo na Windows nie ma kompilatora.

**FluentKit — nowe `Tests/FluentKitTests/PracticeModesTests.swift` (20 testów):**

- **Sesje:** brak fiszek w sesjach dla 15 ziaren i wszystkich etapów progresji; nowe słowa wypełniają budżet; pierwszy kontakt po błędzie wraca jako znaczenie; `retryType` nigdy nie daje fiszki; sesja łączona ignoruje tryb fiszek.
- **Talia:** kolejność do powtórki → nowe → trudne, archiwum pomijane; limit nowych kart i kolekcja; zapis recognition bez ruszania przerwanej sesji, brakujące słowo bez zmian stanu; `FlashcardRun` (powrót raz) i `dropMissing`.
- **Zdjęcia:**
  - kwalifikowanie: rzeczownik, abstrakcje, sufiks angielski i polski, temat abstrakcyjny vs konkretny, wyjątek „apartment”;
  - `searchQuery`;
  - dystraktory: wyraźnie różne, pear/pearl, „apple tree”, 2 z tego samego tematu;
  - `readyMeaningIDs`;
  - zadania zdjęciowe tylko dla gotowych znaczeń po pierwszym kontakcie;
  - kolejność prefetchu;
  - stała kolejność opcji;
  - podstawy typu.
- **Dekodowanie:** nowe przypadki enumów i nieznane wartości.

**FluentKit — zaktualizowane:**

- `SessionTests`: progresja; pierwsza sesja = `.meaning`; budżet z 16 powtórkami i 8 nowymi; 5 kolejnych sesji (runda 0 to 25 × `.meaning`, w żadnej rundzie nie ma fiszek).
- `PracticeTests`: `combinableModes` zamiast `allCases`.

**Aplikacja — nowe `FluentNOWTests/PracticeModes/WordImageServiceTests.swift` (7 testów):** parsowanie Openverse (licencje NC, mature, proporcje, GIF, kolejność trafień), URL z filtrami, sygnatura JPEG/PNG, tolerancyjny plik przypisań, serwis bez sieci nie zgłasza błędów, zgłoszenia zdjęć (zapis i eksport, osobna nazwa pliku), wybór następnego kandydata.

**Skrypty Node (scratchpad):**

| Skrypt | Wynik |
|---|---|
| `swiftcheck.mjs` (lekser) | 263/263 OK |
| `setdups.mjs` (duplikaty w literałach `Set`) | 0 |
| `picturable.mjs` (port heurystyki na treści) | 2 810 / 5 939 rzeczowników |

Openverse sprawdziłem zapytaniem `curl` na żywo: wyszukiwanie i miniatura działają, nagłówki limitów jak w §1.

## 7. Prośby do innych ról

- **onboarding-progress:** `profile.preferredStudyModes()` może zwracać `.flashcards`. Ekran Nauka obsługuje to przez router (`modes: ["flashcards"]`). Siatki trybów nie zmieniałem: kafelki nie są ułożone według profilu. Jeśli trzeba, mogę w kolejnej rundzie ułożyć je według `preferredStudyModes()` / `sessionMinutes` i wpiąć `ProfileLevel.estimate` w `StudyStarter`.
- **reading-redesign:** w `CombinedSessionModel` dodałem tylko `images` w `init` i metodę `loadPictures` (część słownikowa). Przy scalaniu proszę zachować.
- **code-qa:** sprawdzić punkty z §4. Dopisać do `MANUAL-TEST-PLAN.md` scenariusze z §5.
- **Koordynator:** w `CONTRACTS.md` można dopisać `AppEnvironment.images` / `.imageReports` jako stabilne API.
