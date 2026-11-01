# learning-ux — raport (FEEDBACK-9 N1, N2)

Kod napisany na Windows **bez kompilatora**. Każdą użytą sygnaturę sprawdziłem grepem. Nie uruchamiałem git ani `build-index.mjs`, a treści JSON w `Resources/Content` nie zmieniałem (czytałem ją tylko skryptem w Node).

Kontrola zmienionych plików:
- brak BOM i CR;
- nawiasy zbilansowane;
- brak `try!`, `as!` i `fatalError`.

Reguły dystraktorów przeniosłem 1:1 do JS (skrypt w scratchpadzie). Port przeszedł wszystkie oczekiwania z nowych testów: formy czasowników, przyimki, przedimki i 5 zdań testowych.

## 1. Zmiany

### N1 — „Ułóż zdanie” z polskim zdaniem i dystraktorami

**FluentKit `Sessions/ScrambleDecoys.swift` (nowy).** Czysta logika dystraktorów.
- `ScrambleDecoyKind`: `verbForm`, `preposition`, `article`, `sameEntry`, `otherWord`. Kolejność przypadków to priorytet wyboru.
- `ScrambleDecoy(text:kind:)`.
- Formy czasowników pochodzą z tabeli 78 czasowników nieregularnych (AmE). Dystraktor powstaje **tylko w miejscu, gdzie inna forma jest gramatycznie niemożliwa**:
  - Czasowniki z trzema różnymi formami (go / went / gone):
    - forma podstawowa i forma z -s → imiesłów (*to go → gone*, *she goes → gone*);
    - czas przeszły → imiesłów (*went → gone*);
    - imiesłów → czas przeszły (*has gone → went*);
    - forma -ing → czas przeszły (*is going → went*).
  - Czasowniki, w których czas przeszły i imiesłów są takie same (buy / bought), tylko w kontekście:
    - po „to” albo czasowniku modalnym forma podstawowa → czas przeszły (*to buy → bought*);
    - po „have/be/get” imiesłów → forma podstawowa (*have made → make*);
    - po „be” forma -ing → forma podstawowa (*is meeting → meet*).
  - Pominąłem celowo:
    - be, have, do, get;
    - czasowniki z wariantami form (learned/learnt, show, dive, wake, prove, shrink, sink, spring, hang, shine);
    - homografy (find → found, grind, lie/lay, fall, ring, saw, bear, wind);
    - „drunk” jako dystraktor dla formy podstawowej (*a drunk* to rzeczownik);
    - „broke” jako przymiotnik (dla *broken* dystraktorem jest *break*).
  - Nie ma dystraktorów typu zmiana czasu (*I buy → I bought*), bo dają poprawny angielski.
- Przyimki tylko w stałych połączeniach z typowym błędem polskiego ucznia:
  - *depend/rely on → from*, *insist on → for*, *keen on → in*, *interested in → on*;
  - *afraid/proud/consist of → from*, *capable of → to*, *fond of → for*;
  - *different from → of*, *responsible for → of*, *similar to → with*, *listen to → of*;
  - *look forward to → for*, *arrive at/in → to*;
  - określenia czasu: *at night/noon/7 → on*, *on Monday → in*, *in July/2020/winter → on*, *in the morning → at*.

  Nigdy nie dotyczy to miejsc, gdzie kilka przyimków jest poprawnych, np. *in the box* albo *at the station*.
- Przedimki: tylko zamiana „a” ↔ „an”, gdy zdanie ma **jeden** przedimek nieokreślony i **żadnego innego określnika**. Inaczej „an” mogłoby zastąpić „my” i dać poprawne zdanie. **Nigdy nie dodaję zbędnego „the”**.
- Słowa treści z innych przykładów tego hasła, a na końcu z puli zdań innych słów. Filtry:
  - małe litery, co najmniej 4 litery, bez słów funkcyjnych;
  - nowość: bez słów o tym samym rdzeniu co słowo zdania (pierwsze 4 litery, np. *borrowed* przy *borrow*), bo inna forma słowa ze zdania mogłaby być poprawna.
- `choose(...)` wybiera dystraktory:
  - najpierw formy wyrażenia ćwiczonego (`focusEn`);
  - potem kolejne rodzaje po jednym na kolejkę (round-robin), więc dwa dystraktory są różnego rodzaju, gdy to możliwe;
  - żaden dystraktor nie jest słowem zdania ani duplikatem.

**FluentKit `Sessions/SentenceScramble.swift`:**
- `maxDecoys = 3`.
- `decoyCount(word:meaning:wordCount:)` (nowa sygnatura):
  - liczba bazowa według poziomu: A → 1, B → 2, C → 3;
  - +1 po 3 poprawnych odpowiedziach w umiejętności „użycie”;
  - limit według długości zdania: do 6 słów → 1, 7–9 słów → 2, dłuższe → 3;
  - zawsze co najmniej 1.
- `sessionSeed(tasks:mode:)`: ziarno sesji słownictwa z jej pierwszego zadania. Jest stałe przy wznowieniu i przy dopisanych powtórkach.
- `poolSentences(state:excludingWordID:seed:limit:)`: deterministycznie wybrane zdania innych słów jako ostateczne źródło dystraktorów.
- `board(word:meaning:exampleIndex:seed:pool: = [])` korzysta z `decoys(...)` → `ScrambleDecoys.choose`.
- Usunąłem `decoyWords`.
- Sprawdzanie (`isCorrect`, `correctPrefixCount`) bez zmian: dokładnie słowa zdania, bez znaczenia wielkości liter i interpunkcji.

**Aplikacja:**
- `Session/VocabExerciseContent.swift`:
  - nowe pole `sessionSeed` i parametr `init?(…, sessionSeed: String = "")`;
  - ziarno planszy to `"\(sessionSeed)|wordId:meaningId:index"`, a pula to `poolSentences`;
  - `displayFallback` i `asMeaningTask` przekazują ziarno dalej.
- `Session/VocabSessionModel.swift:73`: `SentenceScramble.sessionSeed(tasks: session.tasks, mode: session.mode)`.
- `Combined/CombinedSessionModel.swift:67`: `sessionSeed: session.id`.
- `Test/TestSessionModel.swift:119`: `sessionSeed: session.id`.
- `Session/VocabExerciseModel.swift`:
  - polskie zdanie nie jest już podpowiedzią;
  - usunąłem `scrambleHintShown`, `showScrambleHint()` i odsłanianie tłumaczenia przy drugiej próbie;
  - `usedHelp` dla rozsypanki liczy tylko drugą próbę;
  - nowe `scrambleDecoyCount`.
- `Session/VocabScrambleViews.swift`:
  - `VocabScrambleSource` pokazuje **zawsze** (sesja, ćwiczenie jednego typu, test) polskie zdanie nad kafelkami:
    - etykieta „PO POLSKU”, zdanie fontem `FluentFont.sentence`, wyróżniony `focusPl`, karta `.tinted(.accent)`;
    - VoiceOver czyta „Zdanie po polsku: …”;
    - bez tłumaczenia pokazuje „Znaczenie słowa”.
  - Instrukcja „Jedno słowo jest zbędne / N słowa są zbędne — zostaw je w puli”. VoiceOver puli czyta „Słowa do ułożenia, w tym 2 zbędne”.
  - Przycisk „Wyczyść” (ikona) jest zawsze w tym samym miejscu, a przy pustym zdaniu jest nieaktywny.
  - Usunąłem przycisk „Podpowiedź”.
  - Komunikat drugiej próby: „… Zbędne słowa zostaw w puli.”
  - Dystraktor dotknięty w zdaniu wraca do puli jak każde słowo.
  - Nowy `enum VocabScrambleText` z tekstami i odmianą liczebników.
- Feedback (`VocabFeedbackView`, bez zmian): zarówno poprawna, jak i błędna odpowiedź pokazuje „**zdanie** — tłumaczenie”.
- `Support/StudyExerciseTypeText.swift`: opis kafelka to teraz „Przełóż polskie zdanie, układając angielskie słowa.”

### N2 — przełącznik grup ćwiczeń

Wybrałem **zakładki „ikona nad krótką nazwą” na wspólnym torze z przesuwanym podświetleniem**. Pigułki są układem zapasowym. Powody:
- cztery jednowyrazowe nazwy mieszczą się w jednym rzędzie bez przewijania, więc wszystkie grupy są widoczne od razu;
- ikona przyspiesza rozpoznanie;
- przewijane pigułki zostają na duże czcionki, żeby nic się nie ucinało.

- `Home/StudyExerciseCatalog.swift`:
  - 4 grupy:
    - **Słówka** (`textformat.abc`);
    - **Powtórki** (`arrow.triangle.2.circlepath`);
    - **Czytanie** (`book`): czytanie, idiomy;
    - **Gramatyka** (`pencil.line`): gramatyka, produkcja, miks językowy.
  - Dawny zapis `"bank"` otwiera grupę „Czytanie” (`legacyIDs`).
  - Nowe: `systemImage`, `hasPaused(in:)`, `countText` („8 ćwiczeń”, „3 ćwiczenia”).
  - Usunąłem `StudyExerciseGroup.bank` i dodałem `.reading` i `.grammar`.
- `Home/StudyExerciseTypesCard.swift`: nowy `StudyExerciseGroupPicker`.
  - Układ główny `StudyExerciseGroupTabs`:
    - tor `surfaceMuted`;
    - wybrana zakładka ma tło `surfaceElevated` z cieniem `.card`, a podświetlenie przesuwa się przez `matchedGeometryEffect`;
    - ikona wybranej zakładki w kolorze akcentu;
    - etykiety `footnote` semibold z `fixedSize`, więc się nie ucinają.
  - Gdy zakładki się nie mieszczą (`ViewThatFits`, np. duża czcionka albo wąski ekran), przełącznik zamienia się w **poziomo przewijane pigułki** (`Capsule`):
    - wybrana pigułka ma tło `accentSoft` z obrysem akcentu;
    - `ScrollViewReader` przewija wybraną na środek.
  - Każdy układ ma własny `@Namespace`, bo `ViewThatFits` trzyma oba w drzewie widoków.
  - Przerwane ćwiczenie: znaczek `pause.circle.fill` w rogu ikony.
  - VoiceOver czyta np. „Powtórki, wybrane, 3 ćwiczenia, jest przerwane ćwiczenie”, z podpowiedzią „Pokazuje ćwiczenia z tej grupy”. Kontener ma etykietę „Grupy ćwiczeń”.
  - Haptyka `FluentHaptic.selection` przez `fluentSensoryFeedback`, czyli respektuje `AppPreferences.hapticsEnabled` przez `\.fluentHapticsEnabled`. Włącza się **tylko po dotknięciu** (licznik `taps`), a nie przy przełączeniu z prośby routera.
  - Animacja `Motion.standard`, a przy „Ogranicz ruch” `Motion.reducedFade`.
- Bez zmian zostały:
  - `@AppStorage("study.exerciseGroup")`;
  - znaczniki „Przerwane” na kafelkach;
  - automatyczne przełączenie grupy w `StudyHomeView.open(_:)` (używa `group(containing:)`, a ten zwraca nowe identyfikatory).
- **Bez Liquid Glass.** Przełącznik leży w jednolitej karcie treści, a szkło na nieprzezroczystym torze nie daje efektu i łamie DESIGN §6. Przełącznik wygląda tak samo na iOS 17–26. Kafelki i treść też nie używają szkła ani transformacji 3D.

## 2. Publiczne API (FluentKit)

```swift
public enum ScrambleDecoyKind: Int { case verbForm, preposition, article, sameEntry, otherWord }
public struct ScrambleDecoy { var text: String; var kind: ScrambleDecoyKind }
SentenceScramble.maxDecoys = 3
SentenceScramble.decoyCount(word:meaning:wordCount:) -> Int          // było: decoyCount(word:meaning:)
SentenceScramble.sessionSeed(tasks:mode:) -> String
SentenceScramble.poolSentences(state:excludingWordID:seed:limit: = 6) -> [String]
SentenceScramble.board(word:meaning:exampleIndex:seed:pool: = []) -> ScrambleBoard?
// internal (testy): ScrambleDecoys.verbFormDecoy(for:previous:), prepositionDecoy(keys:at:), articleDecoy(keys:), choose(...)
```

## 3. Testy

- FluentKit `ScrambleDecoysTests.swift` (nowy):
  - formy czasowników: poprawne zamiany oraz brak dystraktora tam, gdzie powstałoby inne poprawne zdanie (*I buy*, *we bought*, *turn left*, *a meeting*, *they came*, *a drink*, *got*);
  - tabela: formy ścisłe są różne, brak duplikatów, brak be/have/do/get;
  - przyimki w stałych połączeniach i brak dystraktora w *in the box* i *at the station*;
  - „a/an” tylko bez innych określników, nigdy dodatkowe „the”;
  - 5 zdań:
    - oczekiwany dystraktor jest na planszy;
    - liczba dystraktorów 1–3;
    - pula = słowa zdania + dystraktory;
    - dystraktor nie jest słowem zdania;
    - podmiana dowolnego słowa na dystraktor nie jest zaliczona;
    - samo zdanie bez dystraktorów jest poprawne;
  - determinizm: to samo ziarno daje tę samą planszę, ziarno sesji jest stałe po dopisaniu zadania, a inne sesje tasują inaczej;
  - pula zdań innych słów: deterministyczna, bez własnego zdania; daje dystraktor, gdy zdanie i hasło nie dają żadnego;
  - priorytet: forma wyrażenia ćwiczonego jest pierwsza, potem inny rodzaj.
- FluentKit `NewExercisesTests.swift`: dostosowane do nowej liczby dystraktorów (poziom, długość, ćwiczone użycie) i do filtra wspólnego rdzenia.
- Aplikacja `StudyLayoutTests.swift`:
  - `testExerciseGroupsAreSwitchable`: 4 krótkie nazwy, ikony, zapis „bank”, `hasPaused`, `countText`;
  - nowy `testScrambleTexts`: odmiana „zbędne”.
- Na Windows nie da się uruchomić testów Swift. Uruchomiłem port reguł w Node:
  - wszystkie oczekiwania testów są spełnione;
  - na bazie (34 943 zdań 4–14 słów) gramatyczny dystraktor dostaje 10 226 zdań: 8 381 form czasowników, 873 przyimki, 2 395 zamian a/an;
  - przejrzałem próbkę 90 przypadków i każda podmiana jest błędna.

## 4. Ryzyka kompilacji (do sprawdzenia w Xcode)

1. `ScrambleDecoys.swift:89–91`: `makeIndex(\IrregularVerb.base)`, czyli ścieżka klucza do typu zagnieżdżonego w inicjalizatorze `static let`.
2. `ScrambleDecoys.swift:83`: `static let irregularVerbs` z `compactMap` po `private static let rawVerbs`.
3. `SentenceScramble.swift:190`: `let decoys = self.decoys(...)` w metodzie statycznej. Nazwa lokalna jest taka sama jak nazwa metody, więc wywołanie jest jawnie przez `self.`.
4. `SentenceScramble.swift:198–199`: `map` do krotek z etykietami `(text:isDecoy:)` z jawnymi typami.
5. `VocabScrambleViews.swift:34` i `:43`: `case ..<1:` w `switch` po `Int`.
6. `VocabScrambleViews.swift:169`: `ForEach(Array(…enumerated()), id: \.element.id) { (entry: (offset: Int, element: ScrambleTile)) in`.
7. `StudyExerciseTypesCard.swift:99`: `ViewThatFits` z dwoma układami, każdy z innym `@Namespace` (`:91–92`) i `matchedGeometryEffect` (`:171`, `:248`). Warto sprawdzić w konsoli, czy nie ma ostrzeżeń „multiple inserted views”.
8. `StudyExerciseTypesCard.swift:191` i `:211`: `ScrollViewReader` oraz `.onChange(of:) { (_: String, newValue: String) in }` (iOS 17).
9. `StudyExerciseTypesCard.swift:287`: `private extension View` z `accessibilityAddTraits(isSelected ? [.isSelected] : [])`.
10. `StudyExerciseTypesCard.swift:100–101`: przekazanie metody `select` jako `(StudyExerciseGroup) -> Void`.

## 5. Do sprawdzenia w symulatorze

1. **Nauka → Słówka → „Ułóż zdanie”**:
   - nad kafelkami jest polskie zdanie z wyróżnionym odpowiednikiem;
   - instrukcja podaje liczbę zbędnych słów;
   - dystraktor da się położyć i odłożyć;
   - „Wyczyść” działa i jest nieaktywny przy pustym zdaniu;
   - „Sprawdź” jest aktywne dopiero przy liczbie słów zdania;
   - błąd daje drugą próbę z zachowanym poprawnym początkiem;
   - feedback pokazuje zdanie i tłumaczenie.
2. Przerwij sesję z rozsypanką i ją wznów: te same kafelki w tej samej kolejności. Nowa sesja tasuje inaczej.
3. **Test**: w zadaniu „Ułóż zdanie” widać polskie zdanie i są dystraktory. Działa bez „Sprawdź”, przez „Dalej”.
4. **Sesja mieszana i codzienna mieszanka** z rozsypanką: jak wyżej.
5. **VoiceOver**: polskie zdanie, pula („w tym N zbędne”), słowa w zdaniu („słowo 2 w zdaniu”) i przycisk „Wyczyść”.
6. **Przełącznik grup**:
   - 4 zakładki w jednym rzędzie na iPhonie (rozmiar domyślny, także na iPhonie SE);
   - podświetlenie przesuwa się płynnie, a przy „Ogranicz ruch” tylko przenika;
   - haptyka działa tylko gdy jest włączona w Ustawieniach;
   - przy dużych rozmiarach i AX3 przełącznik zamienia się w przewijane pigułki bez ucinania, a wybrana jest widoczna;
   - znaczek pauzy jest przy grupie z przerwanym ćwiczeniem;
   - zapamiętany wybór zostaje po restarcie, a stary zapis „bank” otwiera „Czytanie”;
   - prośba z routera (np. czytanie) przełącza grupę bez haptyki;
   - wygląda dobrze w trybie ciemnym.

## 6. Odstępstwa i decyzje

- **„Czytanie i gramatyka” rozdzielone** na „Czytanie” (czytanki, idiomy) i „Gramatyka” (gramatyka, produkcja, miks językowy), zgodnie z propozycją w N2. Idiomy trafiły do „Czytania” jako ćwiczenie rozumienia znaczenia w kontekście.
- **Zbędne „the” nie jest dystraktorem.** Owner dopuszczał je tylko wtedy, gdy na pewno daje błąd, a tego nie da się bezpiecznie rozstrzygnąć regułą. Zamiast tego jest zamiana „a/an”.
- **Gdy nic bezpiecznego nie ma** (brak reguły, jedno zdanie w haśle, pusta pula), plansza może mieć 0 dystraktorów. W sesji pula zdań innych słów prawie zawsze daje co najmniej 1.
- Polskie zdanie nie jest już podpowiedzią, więc odpowiedź bez błędu jest samodzielna.

## 7. Prośby do innych ról

- **design-shell:** brak. Użyłem tylko istniejących tokenów (`surfaceElevated`, `accentSoft`, `fluentShadow(.card)`, `Motion`).
- **content-audit:** im więcej przykładów z `pl` i `focusPl`, tym lepiej działa źródło polskiego zdania. Zdania bez tłumaczenia pokazują teraz „Znaczenie słowa”.
