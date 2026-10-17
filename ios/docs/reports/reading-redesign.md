# Raport: reading-redesign (FEEDBACK-2 G1)

Zakres: czytanie w dwóch etapach (najpierw tekst, potem pytania z pamięci, na końcu wyniki i tekst z dowodami), w samodzielnym czytaniu i w bloku czytanki w sesji łączonej. Do tego podświetlenia słów z mojego słownika i słów przydatnych, arkusz z tłumaczeniem w kontekście oraz słowniczek kontekstowy dla wszystkich 42 czytanek. Kod Swift napisany na Windows **bez kompilatora**. Sygnatury sprawdzone grepem, nawiasy sprawdzone skryptem.

## 1. Co zrobiono (pliki)

### Treść i narzędzia
- `ios/tools/data/reading-glossary.json` (**nowy, źródło prawdy**): słowniczki 42 czytanek, łącznie 765 pozycji (11–20 na tekst). Każda pozycja ma IPA GA, a 294 mają `ref` do wpisu bazy o tym samym znaczeniu. Odwołania wybierałem ręcznie i odrzucałem kandydatów o innym znaczeniu (np. *rest* = „odpocząć” z tematu o mięsie, *closure* z tematu o związkach, *stay* jako komenda dla psa). W starszych czytankach `ref` wskazuje wpisy `starter/*` (borrow, deadline, figure out, take your time, bank-2 „brzeg”…).
  - Tłumaczenia podają znaczenie z danego tekstu, np. *minutes* → „protokół”, *chair* → „przewodniczący”, *qualification* i *reservation* → „zastrzeżenie”, *bank* → „brzeg (rzeki)”, *share* → „odsetek, udział”.
- `ios/FluentNOW/Resources/Content/readings.json`: każda czytanka ma pole `glossary` (ostatnie pole obiektu). Plik waży ok. 205 KB zamiast ok. 120 KB i nadal ładuje się leniwie.
- `ios/tools/lib/reading-glossary.mjs` (nowy): wczytanie źródła, scalanie (`mergeGlossary`), walidacja (`validateGlossary`) i wykrywanie nieaktualnego scalenia (`staleGlossaries`).
- `ios/tools/apply-reading-glossary.mjs` (nowy): wpisuje słowniczki do `readings.json` bez ponownego eksportu. Jest idempotentny; z `--check` zwraca kod 1, gdy `readings.json` jest nieaktualny.
- `ios/tools/export-web-content.mjs`: przy eksporcie scala słowniczki ze źródła, więc ponowny eksport ich **nie kasuje**. Komunikat UWAGA podaje teraz pełną kolejność kroków.
- `ios/tools/lib/bank-validators.mjs` (`validateReadings`): `glossary` jako klucz opcjonalny, reguły słowniczka i ostrzeżenie `glossary-stale`. Reguły czytanek mieszkają w tym pliku, a nie w `validate-content.mjs`, dlatego rozszerzyłem go tutaj; `validate-content.mjs` wywołuje go bez zmian.
- `ios/tools/fixtures/invalid-readings.json` i `.expected.json`: przypadek ze złym słowniczkiem (forma spoza tekstu, duplikat, zła IPA, zły `ref`, pusty lemat).
- `ios/docs/CONTENT-SCHEMA.md`: typ `GlossaryEntry` w §5, nowy podrozdział §5.4.1 (pola, zasady, źródło, scalanie, reguły walidatora) i rozmiar w §5.9.

**Decyzja o eksporcie.** Słowniczek trzymamy w osobnym pliku źródłowym i scalamy przy eksporcie. Poprawki english-qa zmieniają akapity już po eksporcie (np. *lunch-for-two*: „shares it with”), więc kolejność jest taka: `export-web-content.mjs` → `fixes/english-qa-banks-fix.mjs` (2×) → `apply-reading-glossary.mjs` → `build-index.mjs` → `validate-content.mjs`. Walidator ostrzega (`glossary-stale`), gdy `readings.json` rozjedzie się ze źródłem.

### FluentKit
- `Models/ReadingGlossary.swift` (nowy): `ReadingGlossaryEntry` i `Reading.glossaryEntry(at:)`.
- `Models/Reading.swift`:
  - `Reading.glossary` z domyślnym `[]` i dekodowaniem `lossyArray`;
  - enum `ReadingStage`;
  - `ReadingSession.questionsStartedAt` (opcjonalne), `stage`, `beginQuestions(at:)`, `answer(question:choice:)`, `unansweredCount`.
- `Models/CombinedReadingBlock.swift` (nowy): położenie pytania w bloku czytanki w sesji łączonej.
- `Grading/ExerciseAudio.swift`: `ReadingToken.glossaryIndex` (domyślnie `nil`) i `isHighlighted`.
- `Grading/ReadingHighlights.swift` (nowy):
  - `ReadingTokenizer.tokens(text:words:glossary:)`;
  - `ReadingText` (`sentence(in:at:)`, `offset(ofToken:in:)`, `evidenceRanges(in:evidence:)`);
  - `ReadingMeaningMatcher.choose(...)` i `ReadingMeaningChoice`.
- `Tests/FluentKitTests/ReadingGlossaryTests.swift` (nowy), opis w §6.

### Aplikacja (`Features/Reading/`, plus fragmenty o czytance w `Study/Combined/`)
- `ReadingPassageCard.swift` (przepisany):
  - dwa rodzaje podświetleń: słowo z mojego słownika ma tło i ciągłe podkreślenie, słowo przydatne ma podkreślenie kropkowane; jest legenda;
  - wyróżnienie dowodów markerem (`evidence:`);
  - linki `fluentnow-reading://term/<akapit>/<token>` zastępują `fluentnow-word://open/<id>`;
  - zapisane sesje bez słowniczka dostają go z banku po `id`.
  - Parametr `collapsible` usunięty. `ReadingWordLink.url/wordID` zostały, bo korzysta z nich test code-qa.
- `ReadingHighlighting.swift` (nowy): `ReadingPassageTokens` (wynik `Sendable`, liczony w `store.compute`), `ReadingPassageLayout` (AttributedString budowany na głównym wątku), `ReadingTermSelection`, `ReadingTermLink`, `ReadingHighlightStyle`.
- `ReadingWordSheet.swift` (przepisany, nowy `init(selection:)`). Arkusz pokazuje:
  - tłumaczenie „W tym tekście”, formę z tekstu i formę bazową;
  - IPA i odsłuch zwykły oraz wolny;
  - zdanie z tekstu z odsłuchem;
  - moje znaczenia: pasujące oznaczone „Pasuje do tekstu” albo „Prawdopodobnie”; gdy nie wiadomo, wszystkie z komunikatem o niepewności;
  - „Dodaj do nauki”: przy `ref` pełny wpis bazy od razu, bez `ref` — `AddWordRootScreen(prefill: lemat)`; jest też wariant „Dodaj to znaczenie”, gdy mam słowo, ale bez znaczenia z tego tekstu.
- `ReadingGlossaryAdder.swift` (nowy): dodawanie przez `VocabularyMerger.addTopicEntries` albo `mergeSuggestions`. Znane znaczenia zachowują postęp.
- `ReadingStageViews.swift` (nowy): `ReadingFirstStage` (tekst i „Jestem gotowy na pytania”), `ReadingMemoryNotice`, `ReadingStageNotice`, `ReadingEvidenceSection`, `ReadingRecapItem`, `ReadingRecapView`.
- `ReadingPracticeStages.swift` (nowy): `ReadingQuestionsStage` (pytania bez tekstu, „Sprawdź odpowiedzi”) i `ReadingResultsStage` (wynik, pytania z wyjaśnieniem i dowodem, tekst z dowodami).
- `ReadingPracticeView.swift`: `switch current.stage` dla trzech etapów. „Jestem gotowy” zapisuje `questionsStartedAt`, więc po powrocie tekst pozostaje ukryty.
- `Study/Combined/CombinedQuestionModel.swift` (tylko czytanka):
  - `startedAt` jest teraz `var`: czas liczy się od „Jestem gotowy”, a nie od początku czytania;
  - nowe `readingBlock`, `readingEarlier`, `isReadingPassage`, `beginReadingQuestions()`, `readingRecap`;
  - nowe parametry `init` mają wartości domyślne.
- `Study/Combined/CombinedSessionModel.swift`: w `sync` przekazuje blok i wcześniejsze odpowiedzi (jedno miejsce wywołania).
- `Study/Combined/CombinedQuestionView.swift`:
  - przed pierwszym pytaniem bloku pokazuje `ReadingFirstStage`;
  - w trakcie pytań tekstu nie ma (zamiast niego krótka informacja przy pierwszym pytaniu);
  - po ostatnim pytaniu bloku: `ReadingRecapView` z wynikiem i tekstem z dowodami.
- `Study/Combined/CombinedSessionView.swift`: jeden `onChange` przewija na górę po „Jestem gotowy”.

## 2. Publiczne API (FluentKit)

```swift
public struct ReadingGlossaryEntry: Codable, Sendable, Hashable {
    public var form, lemma, translation: String; public var ipa, ref: String?
    public init(form: String, lemma: String, translation: String, ipa: String? = nil, ref: String? = nil)
    public var contentReference: ContentReference? }
public extension Reading { func glossaryEntry(at index: Int) -> ReadingGlossaryEntry? }
// Reading: + public var glossary: [ReadingGlossaryEntry];  init(..., topic: String? = nil, glossary: [ReadingGlossaryEntry] = [])
public enum ReadingStage: String, Sendable, Hashable { case reading, questions, results }
// ReadingSession: + public var questionsStartedAt: Timestamp?; init(..., questionsStartedAt: Timestamp? = nil)
//   public var stage: ReadingStage; public mutating func beginQuestions(at: Timestamp)
//   public mutating func answer(question: Int, choice: Int); public var unansweredCount: Int
// ReadingToken: + public var glossaryIndex: Int?; init(text:wordId:glossaryIndex: = nil); public var isHighlighted: Bool
extension ReadingTokenizer { public static func tokens(text: String, words: [Word], glossary: [ReadingGlossaryEntry]) -> [ReadingToken] }
public enum ReadingText {
    public static func offset(ofToken: Int, in: [ReadingToken]) -> Int
    public static func sentence(in paragraph: String, at offset: Int) -> String
    public static func evidenceRanges(in paragraph: String, evidence: [String]) -> [Range<Int>] }
public struct ReadingMeaningChoice: Sendable, Hashable { public var meaningId: String?; public var isConfident: Bool; public init(meaningId:isConfident:) }
public enum ReadingMeaningMatcher { public static func choose(word: Word, sentence: String, entry: ReadingGlossaryEntry?) -> ReadingMeaningChoice }
public struct CombinedReadingBlock: Sendable, Hashable {
    public var readingID: String; public var taskIndices: [Int]; public var position: Int
    public init(readingID:taskIndices:position:); public var opensBlock: Bool; public var closesBlock: Bool
    public static func block(in: CombinedSession, at: Int) -> CombinedReadingBlock? }
```

Jak `ReadingMeaningMatcher` wybiera moje znaczenie, gdy brak pozycji słowniczka: liczy wspólne słowa treściowe zdania z tekstu i przykładów znaczenia. Wygrywa jednoznaczny zwycięzca; 2 lub więcej wspólnych słów oznacza pewność. Remis albo brak wspólnych słów daje `nil` i UI pokazuje wszystkie znaczenia z informacją o niepewności. Gdy pozycja słowniczka jest, znaczenie wybiera się po `contentRef == ref` albo po wspólnym członie tłumaczenia.

## 3. Odstępstwa od strony
- Strona pokazuje tekst i pytania razem. Tu tekst jest ukryty w trakcie pytań, zgodnie z wymaganiem właściciela.
- Słowniczek kontekstowy jest nową treścią, której na stronie nie ma.
- W sesji łączonej odpowiedź na pytanie z czytanki nadal pokazuje panel wyniku z wyjaśnieniem i dowodem, który zawiera już `CombinedSessionBuilder`. Cały tekst wraca dopiero po ostatnim pytaniu bloku.

## 4. Ryzyka kompilacji i rzeczy niesprawdzone
1. `ReadingHighlighting.swift` → `ReadingHighlightStyle.piece`:
   - `Text.LineStyle(pattern: .dot, color:)` (iOS 16+);
   - `AttributeScopes.SwiftUIAttributes.BackgroundColorAttribute` i `UnderlineStyleAttribute` ustawiane przez subscript.
   - Gdyby się nie kompilowały: `piece.swiftUI.underlineStyle = …` / `piece.swiftUI.backgroundColor = …`.
2. **Wygląd linków.** SwiftUI może rysować tekst linków w kolorze `tint` i ignorować `ForegroundColorAttribute`. Rozróżnienie rodzajów słów nie opiera się więc na kolorze, tylko na tle (słowa z mojego słownika) i rodzaju linii (ciągła lub kropkowana). Do sprawdzenia na urządzeniu: czy kropkowane podkreślenie rysuje się na linkach.
3. `ReadingHighlightStyle.piece` używa `switch kind` po `Kind?` z `case nil` / `.own` / `.useful`. Wyczerpujący, ale warto rzucić okiem.
4. `ReadingHighlights.swift` (FluentKit): prywatny typ na poziomie pliku `ReadingHighlightTarget` jest użyty w `private static func scan` w rozszerzeniu `ReadingTokenizer`. Dostęp jest zgodny (private w rozszerzeniu ≤ fileprivate).
5. `ReadingPracticeStages.swift`: `PracticeResultCard(…, onNext: onNext)` wołany z etykietą zamiast domknięcia końcowego. To memberwise init; jeśli zgłosi problem, wystarczy domknięcie końcowe.
6. `ReadingWordSheet` pokazuje `AddWordRootScreen(prefill:)` w zagnieżdżonym arkuszu. Środowisko dziedziczy się z arkusza; nie sprawdzone na urządzeniu.
7. **Granica sesji łączonej.** Etap „tylko tekst” trzyma `CombinedQuestionModel` (stan UI, bez zapisu). Odpowiedź w sesji łączonej zapisuje się dopiero przy „Następne zadanie”. Jeśli ktoś odpowie na pierwsze pytanie i wyjdzie przed przejściem dalej, po wznowieniu zobaczy tekst ponownie. W samodzielnym czytaniu etap jest zapisany (`questionsStartedAt`).
8. **Ścieżka niesprawdzona na urządzeniu:** zapisana sesja łączona sprzed tej zmiany nie ma `glossary` w osadzonym `Reading`. `ReadingPassageCard` dociąga wtedy słowniczek z `ContentLibrary.readingBank()` po `id`.
9. **Ponowne tokenizowanie.** `ReadingPassageCard` przelicza tokeny przy każdej zmianie `store.revision` (np. każda odpowiedź). Dzieje się to poza głównym wątkiem i jest tanie: kilka akapitów i ok. 20 pozycji.

## 5. Prośby do innych ról
- **data-pipeline / code-qa:** `tools/verify-export.mjs` porównuje czytanki banku ze stroną. Linia „readings banku zmienione przez poprawki eksportu” (tylko INFO) wymieni teraz wszystkie 30, bo doszło `glossary`. Warto pomijać `glossary` w `same()`. Plik jest poza moim obszarem.
- **english-qa:** przegląd redakcyjny słowniczków w `ios/tools/data/reading-glossary.json` (tłumaczenia kontekstowe, IPA wpisane ręcznie dla ok. 380 lematów spoza bazy). Po zmianie: `node ios/tools/apply-reading-glossary.mjs`.
- **code-qa:** test `ReadingTermLink(url:)` / `.url` w `FluentNOWTests` (analogiczny do `testReadingWordLinkRoundTrip`) oraz `ReadingHighlightStyle.segments`.

## 6. Testy i wyniki skryptów
- `ReadingGlossaryTests` (XCTest):
  - dekodowanie: brak pola, pozycje uszkodzone pomijane, zastępczy lemat, zapis i odczyt bez zmian;
  - **bank**: każda z 42 czytanek ma 8–20 pozycji, bez duplikatów, każda forma jest w tekście i jest podświetlana;
  - tokenizator: słownik razem ze słowniczkiem; lemat → moje słowo; bez dopasowania wewnątrz słowa; zarchiwizowane słowa pominięte;
  - `ReadingText.sentence/offset/evidenceRanges` (z „…”, scalanie nakładających się zakresów);
  - `ReadingMeaningMatcher` (`ref`, tłumaczenie, przykłady, niepewność, remis);
  - etapy `ReadingSession` i zapis/odczyt `questionsStartedAt`;
  - `CombinedReadingBlock`.
- Testów nie uruchamiałem — na Windows nie ma kompilatora Swift.
- Wyniki skryptów:
  - `node ios/tools/validate-content.mjs` → **OK: plików 156, wpisów 10711, błędów 0, ostrzeżeń 0**.
  - `node ios/tools/validate-content.mjs --self-test` → **SELF-TEST OK** (`invalid-readings.json` zgłasza nowe reguły słowniczka).
  - `node ios/tools/apply-reading-glossary.mjs --check` → **OK: readings.json zgodny ze źródłem słowniczków**.
  - Symulacja podświetlania w Node: każda z 765 pozycji jest podświetlana w swoim tekście.
