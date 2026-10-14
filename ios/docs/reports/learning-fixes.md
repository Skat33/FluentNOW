# Raport: learning-fixes (FEEDBACK-1: F2, F3, F4)

Obszar: `Features/Study/`, `Features/Practice/`, FluentKit `Grading/` i `Sessions/`, nowe testy FluentKit.
Kod pisany na Windows bez kompilatora; każda sygnatura z innych plików sprawdzona grepem, każdy zmieniony plik przeczytany ponownie.
Gita nie uruchamiałem.

## 1. Co zrobiono (pliki)

### F2. Podpowiedzi nie zdradzają odpowiedzi

**Nowy plik:** `Packages/FluentKit/Sources/FluentKit/Grading/HintBuilder.swift`. Zawiera czyste funkcje, bez UI.

- `HintSet`: poziomy podpowiedzi (`levels[0]` to poziom 1). Ma `count` i `visible(upTo:)`.
- **Poziom 1 (znaczenie).** Składa się z linii:
  - „Część mowy: …”
  - „Liczba słów: N.”
  - „Angielska definicja: …”, z zamaskowanym hasłem i jego formami (`___`)
  - w dyktandzie dodatkowo „Znaczenie: …” (tłumaczenie, też zamaskowane)
  - „Sytuacja: …”: scena kategorii albo kontekst PL. W tłumaczeniu PL→EN pomijam kontekst, bo jest już w treści zadania.
- **Poziom 2 (litery).** Pierwsza litera każdego słowa plus maska długości, np. `b _ _ _ _ _` albo `g _ _   t _ _   h _ _ _   o _`.
  - Pokazuje najwyżej `litery / 3` liter. Przy 1–2 literach nie pokazuje żadnej, a słów jednoliterowych nigdy.
  - Jeśli odsłonięte litery składają się w akceptowany wariant (np. „A/C” dla „air conditioning”), zostaje sama „Długość: _ _ _   …”.
- **Notatki (`Word.note`) nie są używane wcale.** To była główna przyczyna zdradzania hasła.
- **Maskowanie.** Porównuje tokeny po złożeniu: wielkość liter, polskie znaki, apostrofy. Łącznik działa jak spacja, więc „check-in” = „check in”. Maskuje:
  - całe odpowiedzi i ich warianty;
  - słowa treściowe zwrotów wielowyrazowych;
  - formy odmienione: wspólny przedrostek ≥ max(4, długość − 2), np. borrow→borrowed, odprawa→odprawy;
  - dla 3 liter tylko końcówki (bus→buses);
  - złożenia przy ≥ 5 literach (brush→toothbrush, reset→zresetować);
  - formy z `Word.forms` (`checks in – checked in`, `drew; drawn`, `burned/burnt`; etykiety w nawiasach są pomijane);
  - formy ze zdań przykładowych (`exampleFocusEn`).
- **Siatka bezpieczeństwa.** Każda linia, która mimo to zawiera akceptowaną odpowiedź, jest usuwana.
- **API:**
  - `vocabularyHints(word:meaning:type:exampleIndex:variants:)`
  - `vocabularyMaskTerms(...)`
  - `practiceHints(question:production:)`
  - `practiceMaskTerms(...)`
  - `letterMask(_:revealing:)`
  - `mask(_:answers:)`
  - `reveals(_:answers:)`
  - `formVariants(_:)`

**UI.** Wyświetla tylko teksty z FluentKit:

- `Study/Components/StudyExerciseAids.swift`:
  - `StudyHintBox(lines:)` pokazuje kolejne poziomy jeden pod drugim; `init(text:)` zostaje;
  - `StudyHintButton(title:action:)` ma tytuł „Podpowiedź” albo „Więcej podpowiedzi”.
- `Study/Session/VocabExerciseContent.swift`:
  - usunięte `hintText` (2 litery + długość + notatka);
  - nowe `hints: HintSet` i `maskTerms`;
  - `promptContext`: kontekst w pytaniu „Jak powiesz to po angielsku?” jest zamaskowany;
  - `clozeSentence` w trybie par maskuje tłumaczenie, gdy jest równe hasłu (np. „pizza”).
- `Study/Session/VocabExerciseModel.swift`:
  - `hintLevel` (0–2) zamiast `hintShown`; `hintShown` jest teraz wyliczane;
  - `visibleHints`, `canShowMoreHints`;
  - `showHint()` odsłania kolejny poziom;
  - pierwsza błędna odpowiedź odsłania kolejny poziom (zwykle poziom 1, a jeśli poziom 1 już był, to poziom 2).
- `Study/Session/VocabAnswerArea.swift`: „Podpowiedź” → „Więcej podpowiedzi”. W drugiej próbie obok jest „Pokaż odpowiedź”, a przy wąskim ekranie przyciski układają się w kolumnie.
- `Study/Session/VocabPrompts.swift`: kontekst pytania pochodzi z `content.promptContext`.
- `Study/Combined/CombinedQuestionModel.swift` i `CombinedQuestionView.swift`:
  - `hintText` (surowe `inputHint`) zastąpione przez `hints` / `hintLevel` / `visibleHints` / `canShowMoreHints`;
  - w czytance baner pokazuje „Pytanie 2 z 4 do tekstu”.
- `Practice/PracticeSetView.swift`: wpisywanie w miksie używa `HintBuilder.practiceHints` ze stopniowaniem; poziom podpowiedzi to `@State hintLevel`.
- `Practice/ProductionPracticeView.swift`: nowy mały podwidok `ProductionHintRow` ze stopniowanymi podpowiedziami. Wcześniej samodzielna produkcja nie miała podpowiedzi, a w sesji łączonej ten sam rodzaj zadania je miał.
- Czytanie: pytania ABCD nie mają podpowiedzi. Przejrzane, bez zmian.

### F3. Fiszka od razu przechodzi dalej

- `Study/Combined/CombinedSessionView.swift`:
  - `VocabExerciseView(model:onFlashcardDecision:)`: decyzja wywołuje `saveAnswer` + `advance`, czyli to samo co „Następne zadanie”, z animacją przejścia;
  - nie ma panelu „Wrócimy do tego słowa” ani przewijania do wyniku (strażnik w `onChange(canAdvance)`);
  - haptyka `FluentHaptic.swipeCommit` przez `fluentSensoryFeedback`, która respektuje ustawienie „Wibracje”.
- `Study/Session/VocabSessionView.swift`: ta sama haptyka i strażnik przewijania. Zapis i przejście (`commit()`, czyli `Scheduler.recordAnswer` + przesunięcie indeksu) działały już wcześniej; panel pojawiał się tylko w sesji łączonej.
- `Study/Session/VocabExerciseView.swift`:
  - haptyka gestu przesunięcia przeniesiona na ekran sesji, bo karta znika od razu po decyzji;
  - bez komunikatu VoiceOver o wyniku fiszki, która od razu przechodzi dalej.
- Semantyka zapisu bez zmian: `correct` = „Pamiętam”, `spellingCorrect` = „Pamiętam”, `hinted: false`. Sesja łączona zapisuje z pewnością 2.
- Odsłonięcie tyłu fiszki (tłumaczenie, przykład, definicja) przed wyborem zostaje.

### F4. Czytanki: co najmniej 3 pytania, razem, budżet blokiem

`Packages/FluentKit/Sources/FluentKit/Sessions/CombinedSessionBuilder.swift`:

- **`readingTasks(budget:level:history:bank:now:)`**:
  - pierwsza czytanka wchodzi zawsze w całości: wszystkie pytania, najwyżej `maxReadingQuestions` = 6, nigdy nie są przycinane do budżetu;
  - kolejna czytanka wchodzi tylko, gdy z budżetu zostały ≥ `minReadingQuestions` (3) zadania;
  - ta sama czytanka nigdy nie występuje dwa razy w jednej sesji.
- **`makeSession`**: budżet trybów liczę jak dotąd, a potem czytanka liczy się jako blok.
  - Nadwyżka bloku jest odejmowana od pozostałych trybów: od największego budżetu, nigdy poniżej 1.
  - Niewykorzystany budżet trafia do pozostałych trybów, więc długość sesji się nie zmienia.
  - Pusty bank czytanek działa jak dawniej: budżet przepada.
- **`orderTasks` (losowa kolejność)** przeplata **bloki**: pytania jednej czytanki to jeden blok, a każde inne zadanie to osobny blok. Pytania czytanki idą bezpośrednio po sobie i w kolejności. Zasada „ten sam tryb nie występuje dwa razy z rzędu” obowiązuje na poziomie bloków.
- Nowe publiczne stałe: `minReadingQuestions`, `maxReadingQuestions`.
- Samodzielne czytanie (`ReadingPracticeView` + `PracticeFlow.startReading`) pokazywało już wszystkie pytania tekstu. Sprawdzone, bez zmian. Bank `readings.json`: 42 teksty, każdy ma 3–6 pytań.

## 2. Publiczne API (nowe)

```swift
public struct HintSet: Sendable, Hashable {
    public var levels: [String]; public init(levels: [String]); public static let empty
    public var count: Int; public func visible(upTo level: Int) -> [String]
}
public enum HintBuilder {
    public static let maskToken: String   // "___"
    public static func vocabularyHints(word: Word, meaning: Meaning, type: ExerciseType, exampleIndex: Int, variants: AnswerVariants = .builtIn) -> HintSet
    public static func vocabularyMaskTerms(word: Word, meaning: Meaning, type: ExerciseType, exampleIndex: Int, variants: AnswerVariants = .builtIn) -> [String]
    public static func practiceHints(question: PracticeQuestion, production: ProductionItem? = nil) -> HintSet
    public static func practiceMaskTerms(question: PracticeQuestion, production: ProductionItem? = nil) -> [String]
    public static func formVariants(_ forms: String) -> [String]
    public static func letterMask(_ answer: String, revealing limit: Int? = nil) -> String
    public static func mask(_ text: String, answers: [String]) -> String
    public static func reveals(_ text: String, answers: [String]) -> Bool
}
// CombinedSessionBuilder
public static let minReadingQuestions = 3
public static let maxReadingQuestions = 6
```

Zmiany w UI (wewnętrzne w module):
- `StudyHintBox(lines:)` (zostaje `init(text:)`);
- `StudyHintButton(title:action:)` (tytuł ma wartość domyślną);
- usunięte `VocabExerciseContent.hintText` i `CombinedQuestionModel.hintText`.

`StudyFormat.characters` jest teraz nieużywane, ale zostawione.

## 3. Odstępstwa od strony

1. Podpowiedź na stronie to definicja albo „początek słowa + długość + notatka”. Tutaj jest stopniowana, maskowana i nigdy nie używa notatki.
2. W sesji łączonej strona przycinała pytania czytanki do budżetu trybu (`prefix(remaining)`). Tutaj czytanka zawsze ma 3–6 pytań, a budżet liczony jest blokiem.
3. Losowa kolejność na stronie mogła rozdzielić pytania jednej czytanki. Tutaj zostają razem.
4. Fiszka w sesji łączonej: na stronie był panel wyniku i „Następne zadanie”. Tutaj zapis i przejście następują od razu, tak samo jak w sesji słownictwa.
5. Samodzielna produkcja ma stopniowane podpowiedzi; na stronie nie miała żadnych.

## 4. Ryzyka kompilacji i działania (gdzie patrzeć na Macu)

Wszystkie zmienione pliki przeszły mój lekser Node: nawiasy z interpolacją `\(`, ciągi, komentarze, brak BOM/CR i brak `try!`/`as!`/`fatalError`. Wynik: 20/20 OK.

- `HintBuilder.swift`:
  - `if let limit {` / `if let production {` to skrót z Swift 5.7;
  - `text.contains(answer)` (String w String, z Foundation) w `tokenMatches`;
  - `while let a = …next(), let b = …next(), a == b`.
  Wszystkie trzy to standardowe konstrukcje.
- `PracticeSetView.inputArea` i `ProductionHintRow.body`: lokalne `let hints: HintSet = …` wewnątrz `@ViewBuilder`. Deklaracje są dozwolone w result builderach, a typ podałem jawnie.
- `StudyHintBox`: `ForEach(lines.indices, id: \.self) { (index: Int) in … }`.
- `StudyHintButton`: `var title: String = "Podpowiedź"` przed `let action`. Memberwise init to `init(title:action:)`, więc dotychczasowe wywołania `StudyHintButton { … }` i `StudyHintButton(action:)` dalej działają.
- `CombinedSessionView` i `VocabSessionView`: w `onChange` porównuję jawnie `!= ExerciseType.flashcard`, żeby skrócić wnioskowanie typów (lekcja z `TodayRootScreen`). Każde nowe wyrażenie w `body` to jedna krótka instrukcja; nowe widoki są małymi podwidokami.
- **Wydajność testu w Debug.** `testNoHintRevealsTheAnswerForAnyBuiltInEntry` liczy ok. 51 tys. zestawów podpowiedzi; spodziewam się kilkudziesięciu sekund w Debug. Port w Node zajmuje ok. 9 s. Jeśli to za długo, można sprawdzać lukę tylko dla przykładu 0.
- **Działanie (do sprawdzenia na urządzeniu):**
  - haptyka przy fiszce: wyzwalacz siedzi na ekranie sesji;
  - przejście `.id(key)` + `Motion.contentTransition` po decyzji;
  - `StudyHintButton` ma podpowiedź VoiceOver „zapisana jako udzielona z podpowiedzią”. W zestawach i produkcji `PracticeFlow` tego nie zapisuje, tak jak dotąd w zestawach.
- **Treść.** Słowo „rzeczownik” (część mowy) zawiera „rzecz” (tłumaczenie „thing”/„item”). Część mowy nie jest maskowana, bo to nie zdradza odpowiedzi. Moje sprawdzenie przez Node zgłasza to jako informację.

## 5. Prośby do innych ról

- **topic-search** (tematy z AI): nic nie trzeba robić. Podpowiedzi liczą się w locie z `Word`/`Meaning`, więc tematy z AI dostaną je automatycznie. Warto, żeby generowane wpisy miały `definition` i `forms`, bo wtedy podpowiedzi są lepsze.
- **english-qa** (opcjonalnie): 18 wpisów nie ma użytecznej definicji po zamaskowaniu. Definicja jest wtedy pusta albo składa się prawie wyłącznie z hasła. Listę daje skrypt (`Recall hints without a usable definition`).

## 6. Testy

Nowe pliki (XCTest; stare testy bez zmian, sprawdzone pod kątem zgodności):

- **`Tests/FluentKitTests/HintTests.swift`**:
  - maska liter: ≤ 1/3 liter, słowa jednoliterowe ukryte, łącznik;
  - maskowanie form EN/PL i złożeń, bez ruszania niepowiązanych słów;
  - `reveals`: łącznik = spacja, polskie znaki, typograficzny apostrof;
  - parsowanie `forms` (także „A/B tests” nie daje formy „A”);
  - poziomy w słownictwie: notatka nigdy nie jest użyta; w luce litery pochodzą z formy ze zdania; fiszka nie ma podpowiedzi;
  - kontekst PL maskowany w „Wybierz znaczenie”;
  - zapożyczenie („pizza”) w dyktandzie;
  - litery składające się w wariant („A/C”) → sama długość;
  - produkcja/miks: konstrukcja, czasownik, litery;
  - idiom: tłumaczenie z zamaskowanym znaczeniem;
  - **dane:** `testNoHintRevealsTheAnswerForAnyBuiltInEntry` sprawdza każdy wpis `topics/*.json` i `starter-words.json` × (tłumaczenie, znaczenie, dyktando, luka dla każdego przykładu). Żaden poziom nie zawiera odpowiedzi z niezależnej listy: to, co akceptuje `VocabularyGrader`, plus hasło, forma ze zdania i formy z `forms`. Sprawdza też, że są 2 poziomy i limit liter;
  - **dane:** `testNoHintRevealsTheAnswerForAnyBankItem` sprawdza każde zadanie z `grammar/*` i `exercises` (jako pytanie miksu i jako zadanie produkcji) oraz każdy idiom.
  - Pliki są czytane przez `TestData.contentData` (`#filePath`); gdy ich brak, test robi `XCTSkip`.
- **`Tests/FluentKitTests/CombinedReadingTests.swift`**:
  - budżet 1 (8 trybów, 5 minut) daje całą czytankę (4 pytania), a nie `prefix(1)`;
  - przy 3–6 pytaniach na tekst i 25 ziarnach losowania: każda czytanka ma wszystkie pytania, stanowi ciągły blok w kolejności 0,1,2…, a tryby przeplatają się na poziomie bloków;
  - budżet blokiem: 6 pytań zabiera 2 zadania gramatyce; 3 pytania oddają 1 zadanie; w 15 minutach są 3 czytanki; liczba zadań jest stała;
  - ta sama czytanka nie powtarza się w sesji;
  - `orderTasks` nie rozrywa bloków (30 ziaren);
  - historia po zakończeniu sesji: jeden wpis na czytankę z pełnym `total`;
  - prawdziwy bank: wszystkie teksty mają 3–6 pytań, a blok na każdym poziomie zawiera cały tekst.

**Skrypt Node (port `HintBuilder` 1:1)** w scratchpadzie (`hint-check.mjs`), uruchomiony na danych z `ios/FluentNOW/Resources/Content`:

```
Topic files: 135 (+ starter-words.json), entries: 10224, vocabulary hint sets: 51120
Vocabulary leaks (whole-word, folded): 0
Letter-mask ratio violations: 0
Recall hints without a usable definition: 18
Lines dropped by the safety net: 13
Level 2 reduced to a pure length mask (letters would spell a variant): 4
Informational: answer (>=5 letters) found as a substring inside a longer word: 2   (oba: „rzecz” w „rzeczownik” — część mowy)
Bank items checked: 3852, leaks: 0, ratio violations: 0
```

Pierwsze przebiegi skryptu wykryły i pozwoliły naprawić:
- złożenia („toothbrush” zdradzało „brush”, „zresetować” zdradzało „reset”, „stomatologicznego” zdradzało „stomatolog”);
- litery maski składające się w akceptowany skrót („A/C”);
- fałszywą formę „A” z `A/B tests`.

Lekser Swift (Node): 20/20 zmienionych plików OK.
Testy Swift: nieuruchomione, bo na Windows nie ma kompilatora. Do uruchomienia: `cd ios/Packages/FluentKit && swift test`.
