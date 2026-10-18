# Raport: ui-tweaks

Sześć poprawek zgłoszonych przez właściciela po testach na symulatorze (iPhone 17 Pro, iOS 26.2). Kod napisałem na Windows **bez kompilatora**. Każdą użytą sygnaturę sprawdziłem grepem. Skrypt kontrolny ze scratchpadu (`check.mjs`: nawiasy z interpolacją, BOM, CR, `try!`/`as!`/`fatalError`) przechodzi dla wszystkich 29 zmienionych i nowych plików. Nie uruchamiałem gita i nie dotykałem plików treści JSON.

## 1. Co zrobiono

### Zadanie 1 — segment „Polecane” w Słowniku
- `App/AppTab.swift`:
  - nowy przypadek `LibrarySection.recommended` (surowa wartość `"recommended"`, tytuł „Polecane”);
  - `browsable = [.words, .collections, .recommended]`;
  - istniejące wartości surowe bez zmian (zgodność wsteczna); `.topics` nadal przekierowuje do wyszukiwania tematu.
- `App/DeepLink.swift`: `fluentnow://recommended` (alias `fluentnow://useful`) → `.library(.recommended, nil)`; tabela w komentarzu uzupełniona.
- `App/AppRouter.swift`: `openLibrary(.recommended)` zawsze cofa stos Słownika do korzenia (inaczej segment zmieniłby się pod otwartymi szczegółami słowa).
- `Features/Words/WordsRootScreen.swift`: przypadek `.recommended` → `UsefulWordsScreen(embedded: true)`. To ten sam widok, nie kopia: zaznaczanie, „Dodaj do nauki: N słów”, „+”, uzasadnienia, wyszarzone „Masz już”.
- `Features/Stats/UsefulWordsScreen.swift`:
  - nowy parametr `var embedded: Bool = false`;
  - `UsefulWordsNavigationTitle` ustawia tytuł „Polecane słówka” tylko dla samodzielnego ekranu (w Słowniku zostaje „Słownik”);
  - drugi `#Preview`.
- Skróty:
  - `Features/Today/TodayRecommendedWordsSection.swift`: „Zobacz więcej polecanych słówek” → `router.openLibrary(.recommended)`. Właściciel pobrał kod przed tą zmianą, stąd brak segmentu w jego teście;
  - `Features/Stats/StatsAnalysisSection.swift`: „Zobacz propozycje” → to samo.
- `FluentNOWTests/Shell/ShellTests.swift`:
  - deep linki `recommended`/`useful`;
  - `testLibrarySectionsStayBackwardCompatible` (surowe wartości, `browsable`);
  - `testOpenRecommendedSegmentFromRoot` (karta, segment, pusty stos, zamknięty arkusz, URL).

### Zadanie 2 — przegląd po czytance
- `Features/Reading/ReadingReview.swift` (nowy):
  - `ReadingOutcomeCard`: „Czytanka ukończona”, pierścień, „3/4 poprawnie”, krótki komentarz; przycisk główny „Sprawdź odpowiedzi” i drugorzędny „Przejdź dalej” (Enter);
  - `ReadingReviewView`: nagłówek z wynikiem, potem tekst z wyróżnionymi fragmentami-dowodami (`ReadingEvidenceSection` → `ReadingPassageCard`, z podświetleniami słów i arkuszem); niżej każde pytanie (`ReadingReviewQuestionCard`), a na końcu przycisk „Dalej”;
  - karta pytania pokazuje:
    - ABCD z zaznaczeniem (`StudyChoiceList`, poprawna na zielono, błędny wybór na czerwono);
    - tekstem „Twoja odpowiedź: B. …” i przy błędzie „Poprawna odpowiedź: A. …”, więc nie tylko kolorem;
    - wyjaśnienie zawsze rozwinięte i cytat-dowód (`ReadingEvidenceQuote`);
  - `ReadingDoneView`: podsumowanie samodzielnej czytanki (`PracticeResultCard` z „Następny tekst”) i dalej dostępne „Sprawdź odpowiedzi”;
  - `ReadingReviewRow.rows` z bezpiecznym indeksowaniem, `ReadingRecapItem.items(from: ReadingSession)` (−1 = brak odpowiedzi), `ReadingReviewText`.
- `ReadingPracticeStages.swift`:
  - `ReadingResultsStage` ma teraz etapy `ReadingResultsPhase` (`outcome` → `review` / `done`), trzymane w `@State`, bez zapisu;
  - nowy parametr `onPhaseChange` przewija do początku wyników;
  - przycisk wysyłki odpowiedzi to teraz „Zobacz wynik” (wcześniej „Sprawdź odpowiedzi”, co dublowało się z przeglądem).
- `ReadingPracticeView.swift`: nowe wywołanie `ReadingResultsStage`; `scrollToResults(proxy:)` wspólne dla wysłania odpowiedzi i zmiany etapu. **Zapis (`PracticeFlow.submitReading`) bez zmian.**
- `ReadingStageViews.swift`:
  - usunięte `ReadingRecapView`/`ReadingRecapRow` (zastąpione kartą wyniku i przeglądem);
  - teksty etapów 1 i 2 mówią teraz, że do tekstu *można* wrócić.
- Sesja łączona:
  - `Study/Combined/CombinedQuestionModel.swift`: `isShowingReadingReview` (stan UI), `showReadingReview()`, `ownsReadingAdvance`;
  - `Study/Combined/CombinedQuestionView.swift`: nowy parametr `var onAdvance: () -> Void = {}`. Po ostatnim pytaniu bloku pod panelem wyniku pytania pojawia się `ReadingOutcomeCard`: „Przejdź dalej” → następne zadanie, „Sprawdź odpowiedzi” → `ReadingReviewView` zamiast pytania, z „Dalej” → następne zadanie;
  - `Study/Combined/CombinedSessionView.swift`:
    - ogólny „Następne zadanie” ukryty, gdy `ownsReadingAdvance`;
    - przekazuje `onAdvance: { advance() }`;
    - przewija na górę po otwarciu przeglądu.
  - Zapis odpowiedzi jak wcześniej: `advance()` → `saveAnswer` + `advance`.

### Zadanie 3 — podświetlenia (wynik w §3)
- `ReadingHighlighting.swift` → `ReadingHighlightStyle.piece`: pewniejszy wariant (opis w §3).
- `ReadingPassageCard.swift`: legenda opisuje cechy inne niż kolor, komentarze zaktualizowane.

### Zadanie 4 — nakładający się nagłówek arkusza „+”
- `Features/AddWord/AddWordRootScreen.swift`:
  - przełącznik „Dodaj słowo / Szukaj tematu” przeniesiony z `ToolbarItem(.principal)` do `.safeAreaInset(edge: .top)` treści: pełna szerokość pod paskiem nawigacji, tło `Palette.background`, kolumna ≤ `readableWidth`;
  - w pasku zostają „Anuluj”/„Gotowe” i „Dodaj” (tryb słowa) albo „Zamknij” (tryb tematu), a tytuł inline trybu jest już ustawiany przez `AddWordQuickForm` („Dodaj słowo”) i `TopicSearchView` („Szukaj tematu”);
  - segmenty mają `dynamicTypeSize(...xxxLarge)`, bo przy rozmiarach dostępności `UISegmentedControl` ucina etykiety; reszta arkusza skaluje się dalej;
  - `RootView.swift` nie wymagał zmian (host wywołuje tylko `AddWordRootScreen(...)`).

### Zadanie 5 — gwiazdka i priorytet
- UI (`Word.important`):
  - `Features/Words/WordRowView.swift`:
    - `WordRowView(row:onToggleStar:)` — z akcją: dotykalna gwiazdka na końcu wiersza (`WordStarButton`, `.borderless`, 44×44, etykieta VoiceOver, haptyka);
    - bez akcji (Dzisiaj, Postępy, Kolekcja) jak dawniej: mała gwiazdka tylko przy słowach z gwiazdką;
  - `Features/Words/WordListView.swift`: przesunięcie w prawo „Gwiazdka”/„Bez gwiazdki”, menu kontekstowe „Dodaj/Usuń gwiazdkę”, `toggleStar` przez `WordMutations.setImportant`;
  - `WordDetailScreen.swift`: przycisk gwiazdki w pasku obok menu; w menu „Dodaj/Usuń gwiazdkę”;
  - `WordDetailSections.swift`: chip „Z gwiazdką”;
  - `WordListModel.swift`: filtr `important` ma tytuł **„Z gwiazdką”** i ikonę `star.fill`.
- FluentKit:
  - `Sessions/StudyPriority.swift` (nowy): `starredFirst(_:_:)` i Fisher–Yates `shuffled(_:using:)`;
  - `Sessions/SessionBuilder.swift`: gwiazdka jako **rozstrzygnięcie remisu** w sortowaniu po terminie (i po liczbie błędów w trybie pomyłek). Kolejność zaległych powtórek się nie zmienia; nowe znaczenia mają wszystkie termin 0, więc te z gwiazdką idą pierwsze i mieszczą się w budżecie czasu. Sesja łączona korzysta z `SessionBuilder`, więc dostaje to samo;
  - `Sessions/FlashcardDeck.swift` (`grouped`): to samo dla puli powtórek i trudnych (remis), w puli nowych gwiazdka pierwsza.
- `Tests/FluentKitTests/StarPriorityTests.swift` (nowy), opis w §6.

### Zadanie 6 — kolejność fiszek
- FluentKit `FlashcardDeckBuilder.makeDeck`:
  - nowe przeciążenia `makeDeck(..., now:, shuffled:)` (systemowy generator) i generyczne `makeDeck(..., now:, shuffled:, using:)`;
  - stare `makeDeck(..., now:)` = bez tasowania, wynik identyczny jak przed zmianą.
  - Tasowanie:
    - karty dalej losowane z pul powtórki → nowe → trudne;
    - w puli nowych najpierw karty z gwiazdką, reszta w losowej kolejności (za każdym razem inny wybór nowych);
    - na końcu cała talia potasowana.
- `Features/Study/Flashcards/FlashcardDeckModel.swift`:
  - `shuffled` (domyślnie `true`, UserDefaults `flashcards.shuffle`, per urządzenie) i `setShuffled(_:)`;
  - `start()` przekazuje `shuffled:`;
  - „Jeszcze raz te, których nie pamiętasz” też tasuje, gdy włączone.
  - Generator systemowy, **bez stałego ziarna**.
- `FlashcardDeckScreen.swift`:
  - `FlashcardShuffleToggle` (ikona `shuffle`, „Tasuj karty”, opis stanu) w karcie wyboru talii, poza widokiem z `rotation3DEffect`;
  - zaktualizowany opis talii.

## 2. Publiczne API / kontrakty

```swift
enum LibrarySection { …, case recommended }            // "recommended", title "Polecane"
// deep link: fluentnow://recommended | fluentnow://useful → .library(.recommended, nil)
struct UsefulWordsScreen: View { var embedded: Bool = false }
struct WordRowView: View { let row: WordListRow; var onToggleStar: (() -> Void)? = nil }
struct WordStarButton: View { let isStarred: Bool; let term: String; let action: () -> Void }
struct ReadingOutcomeCard: View { correct, total: Int; continueTitle: String; onReview, onContinue: () -> Void }
struct ReadingReviewView: View { reading: Reading; items: [ReadingRecapItem]; doneTitle: String; onDone: () -> Void }
struct ReadingResultsStage: View { session; isStarting; onNext; onPhaseChange: () -> Void }
extension ReadingRecapItem { static func items(from: ReadingSession) -> [ReadingRecapItem] }
struct CombinedQuestionView { var onAdvance: () -> Void = {} }
CombinedQuestionModel: isShowingReadingReview, showReadingReview(), ownsReadingAdvance
// FluentKit
public enum StudyPriority {
    static func starredFirst(_ lhs: Word, _ rhs: Word) -> Bool
    static func shuffled<T, G: RandomNumberGenerator>(_ items: [T], using: inout G) -> [T] }
FlashcardDeckBuilder.makeDeck(state:collection:limit:newLimit:now:shuffled:)
FlashcardDeckBuilder.makeDeck(state:collection:limit:newLimit:now:shuffled:using:)
```

## 3. Weryfikacja podświetleń w tekście czytanki

**Gdzie się pokazują (sprawdzone w kodzie):**
- *Etap czytania, samodzielnie:* `ReadingPracticeView` → `.reading` → `ReadingFirstStage` → `ReadingPassageCard(reading:)`.
- *Etap czytania, sesja łączona:* `CombinedQuestionView` (`isReadingPassage`) → ten sam `ReadingFirstStage`.
- *Przegląd (oba tryby):* `ReadingReviewView` → `ReadingEvidenceSection` → `ReadingPassageCard(reading:evidence:)`. Te same podświetlenia plus marker dowodów.
- Na etapie pytań tekstu celowo nie ma (G1).

**Jak działają:**
- Tokeny słowniczka i słów użytkownika liczy `store.compute` poza głównym wątkiem.
- Linki `fluentnow-reading://term/<akapit>/<token>` obsługuje lokalne `.environment(\.openURL)` na karcie.
- Dotknięcie → `ReadingWordSheet` z tłumaczeniem w kontekście.
- Starsze zapisy sesji bez słowniczka dociągają go z banku po `id`.

**Ryzyko:** dawny wariant opierał się na `ForegroundColorAttribute` i kropkowanym `UnderlineStyleAttribute` na odcinkach-linkach. SwiftUI `Text` rysuje linki kolorem `tint`, a kropkowany wzór na linku nie jest pewny. Słowa przydatne mogły więc wyglądać prawie jak zwykły fioletowy tekst, nieodróżnialny od moich słów bez tła. **Zastosowałem pewniejszy wariant:**

| Rodzaj | Tło (`BackgroundColorAttribute`) | Grubość | Linia (dodatkowo) |
|---|---|---|---|
| Słowo z mojego słownika | `accentSoft` (fiolet) | **pogrubione** (`inlinePresentationIntent = .stronglyEmphasized`) | ciągła |
| Słowo przydatne | `infoSoft` (jasny niebieski) | zwykłe | kropkowana |
| Dowód (przegląd) | `warningSoft` (marker) zastępuje tło słowa | bez zmian | bez zmian |

Tło i pogrubienie `Text` rysuje zawsze. Oba rodzaje różnią się więc odcieniem tła **i** grubością (nie tylko kolorem), także wewnątrz dowodu. Legenda pokazuje próbki i opisuje je słowami: „pogrubione, fioletowe tło — z Twojego słownika”, „zwykłe, jasnoniebieskie tło — warte nauki”. Kontrast tekstu linku (`accent`) na `infoSoft` i `accentSoft` ≥ 4,5:1 w obu trybach (wartości z `Palette`).

## 4. Ryzyka kompilacji / niesprawdzone

1. `ReadingHighlighting.piece`: `piece.inlinePresentationIntent = .stronglyEmphasized` (Foundation, iOS 15). Ten sam wzorzec jest już w `UsefulWordSummaryText`.
2. `UsefulWordsScreen`: `UsefulWordsNavigationTitle` to `ViewModifier` z `@ViewBuilder func body` i `if/else`. Typowy wzorzec, jak `StudyOptionalShortcut`.
3. **Gwiazdka w wierszu `List` z `NavigationLink`** (`WordListView` → `WordRowView(onToggleStar:)`): przycisk `.borderless` powinien łapać dotknięcie bez otwierania szczegółów. **Do sprawdzenia na symulatorze.** Gdyby otwierał szczegóły: przenieść `WordStarButton` poza etykietę `NavigationLink` (np. `HStack { NavigationLink…; WordStarButton }`). Przesunięcie i menu kontekstowe działają niezależnie.
4. `WordDetailScreen`: dwa `ToolbarItem(placement: .primaryAction)`, czyli gwiazdka i menu obok siebie. Na iOS 26 mogą zostać zgrupowane w jednej kapsule szkła; to tylko wygląd.
5. `AddWordRootScreen`:
   - `.safeAreaInset(edge: .top, spacing: 0)` na treści w `NavigationStack` (iOS 15);
   - `.dynamicTypeSize(...DynamicTypeSize.xxxLarge)` (iOS 15, `PartialRangeThrough`).
   - **Nie oglądane na urządzeniu:** pozycja pod paskiem przy efekcie krawędzi przewijania iOS 26 i oba tryby przy dużym tekście.
6. `FlashcardDeckBuilder`: trzy przeciążenia `makeDeck`. Wywołanie bez `shuffled:` trafia tylko w pierwsze, `shuffled:` bez `using:` tylko w drugie, więc nie ma niejednoznaczności. Wewnętrzna funkcja `add` nie przechwytuje parametru `inout rng`.
7. Zamknięcia sortujące z jawnymi typami krotek `(item: WordMeaning, due: Timestamp)` muszą się zgadzać z typem elementów `keyed`. W `SessionBuilder` krotka `errors` jest typu `Int` (`Score.wrong`/`slow: Int`), więc się zgadzają.
8. `FlashcardDeckModel`: zamiast `didSet` na właściwości `@Observable` jest jawne `setShuffled(_:)` (pewniejsze); przełącznik używa `Binding(get:set:)`.
9. Sesja łączona: ogólny przycisk dalej jest ukryty przy `ownsReadingAdvance`. Gdyby `readingRecap` było `nil` mimo odpowiedzi, ogólny przycisk zostaje, więc sesja się nie zablokuje.
10. Priorytet gwiazdki w sesji łączonej jest słabszy niż w zwykłej sesji. `CombinedSessionBuilder` bierze `prefix(count)` z już przeplecionych zadań `SessionBuilder`, więc gwiazdka zwiększa szansę na wybór, ale nie gwarantuje miejsca w krótkim bloku słówek.

## 5. Prośby do innych ról
- **code-qa:** po buildzie na Macu:
  - uruchomić `StarPriorityTests`, `PracticeModesTests` (talia bez tasowania ma identyczny wynik) i `ShellTests`;
  - na symulatorze sprawdzić punkty 3 i 5 z §4 oraz wygląd podświetleń (tło + pogrubienie) w czytance.
- **design-shell:** `Palette.infoSoft` jest teraz także tłem słów przydatnych w czytance. Jeśli wolicie osobną rolę (np. `usefulWordFill`), dopiszcie ją; zmiana to jedna linia w `ReadingHighlightStyle.piece`.

## 6. Testy
- `FluentNOWTests/Shell/ShellTests.swift`: deep linki „Polecane” i aliasu, zgodność surowych wartości `LibrarySection`, router (segment od korzenia, zamknięcie arkusza, URL).
- `Packages/FluentKit/Tests/FluentKitTests/StarPriorityTests.swift` (7 testów):
  - predykat `starredFirst` (ścisły);
  - sesja: nowe słowo z gwiazdką mieści się w budżecie 5 min (bez gwiazdki ostatnie z 60 się nie mieści); powtórki wyprzedzają nowe z gwiazdką;
  - talia: gwiazdka rozstrzyga tylko remis terminu, kolejność terminów zostaje, nowe z gwiazdką pierwsze;
  - talia bez tasowania = dotychczasowy wynik;
  - tasowanie:
    - powtórki i nowe z gwiazdką zawsze w talii, limit nowych zachowany, bez duplikatów;
    - różne ziarna dają różną talię, to samo ziarno tę samą;
    - `shuffled` to permutacja.
- Istniejące testy nie powinny się zmienić: żaden test sesji ani talii nie ustawia `important`. Fixture `state-v31.json` z `important: true` używają tylko testy synchronizacji.
- Testów nie uruchamiałem (brak Swifta na Windows). Uruchomiony był tylko `check.mjs` na 29 plikach: 0 problemów.
