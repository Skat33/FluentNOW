# study-layout — raport (FEEDBACK-6 K1, K2, K3)

Kod Swift pisany na Windows **bez kompilatora**. Każdą użytą sygnaturę sprawdziłem grepem. Nawiasy sprawdziłem skryptem Node (wszystkie zmienione pliki: ok). Poleceń git nie uruchamiałem.

## 1. Co zrobiono

### K1 — ekran Nauka
Nowy układ od góry: **Fiszki** → **Ćwiczenia** (kafelki typów z J1) → **Test** (`StudyTestCard()` od test-mode) → „Czytanie i gramatyka” → (zdjęcia, tylko po odblokowaniu) → historia.
- Sekcja „Ile masz czasu?” jest usunięta razem z wyborem wielu trybów i losową kolejnością. Usunięte pliki: `Home/StudySetupCard.swift`, `Home/StudyModeCard.swift`, `Home/StudyCombinedDraftSheet.swift`.
- Karty „Kontynuuj” są usunięte (`Home/StudyResumeCard.swift`). `StudyResumeItem` przeniosłem bez zmian do `Support/StudyResume.swift`. Korzysta z niego „Wznów sesję” na Dzisiaj, link `fluentnow://study/resume` i test code-qa.
- **Okno wyboru.** Dotknięcie kafelka z przerwaną sesją otwiera systemowy `confirmationDialog`: „Kontynuuj, gdzie skończyłem” / „Zacznij od nowa” / „Anuluj”. Okno pokazuje postęp i informację, że odpowiedzi są już zapisane. Kafelki z przerwaną sesją mają znacznik „Przerwane” (chip, nie pasek).
- **„Zacznij od nowa”** tworzy nową sesję z **innymi zdaniami**. Przerwana sesja jest zastępowana, a udzielone odpowiedzi są już w historii i FSRS. Działa tak:
  - ćwiczenie jednego typu: `FreshStart.singleTypeSession` pomija przykłady wszystkich zadań przerwanej sesji, jeśli znaczenie ma inne zdanie, które pasuje do danego typu;
  - fiszki: porzucona talia zapisuje swoje przykłady, a następna talia je pomija;
  - czytanie / gramatyka / idiomy / miks / produkcja: inny tekst lub zestaw (`FreshStart.restart*`).
- **Fiszki można wznowić.** Wcześniej talia żyła tylko w pamięci. Teraz `FlashcardPauseStore` zapisuje ją po każdej decyzji w `UserDefaults` urządzenia: kolejność, pozycja, liczniki, czas. „Kontynuuj” otwiera talię od miejsca przerwy.
- **Czytanie i gramatyka** (`Home/StudyMoreActivitiesCard.swift`) to nowa karta pod Testem. Bez niej po usunięciu „Ile masz czasu?” nie byłoby wejścia do czytania, gramatyki, idiomów, miksu i produkcji. Każdy kafelek uruchamia jeden tryb, bez łączenia. Obowiązuje to samo okno wyboru.
- **„Zaczynam naukę” na Dzisiaj** dalej uruchamia codzienną mieszankę (`.daily` → `StudyStarter.startMode(.mixed)`), z długością z profilu (domyślnie 10 min). Pliku `Features/Today/` nie zmieniałem.
- Prośby z wieloma trybami (stare deep linki) uruchamiają pierwszy znany tryb, bez sesji łączonej. Fiszki, czytanie i gramatyka z linku idą przez to samo okno wyboru. Przerwana sesja łączona dalej wznawia się z Dzisiaj, bo kod `Combined/` zostaje.

Pliki:
- `FluentNOW/Features/Study/Home/StudyHomeView.swift` — przepisany.
- `FluentNOW/Features/Study/Home/StudyMoreActivitiesCard.swift` — nowy.
- `FluentNOW/Features/Study/Home/StudyExerciseTypesCard.swift` — tytuł „Ćwiczenia”, `pausedType`, znacznik „Przerwane”.
- `FluentNOW/Features/Study/Support/StudyResume.swift` — nowy: `StudyResumeItem`, `StudyResumePrompt`.
- `FluentNOW/Features/Study/Support/StudyFlow.swift` — `StudyFlow.resumedFlashcards`, `enum StudyActivity`.
- `FluentNOW/Features/Study/Support/StudyStarter.swift` — bez sesji łączonej. Doszły `startMode`, `startSingleType(fresh:)`, `restartBank`.
- `FluentNOW/Features/Study/StudyFlowView.swift` — obsługa `.resumedFlashcards`.
- `FluentNOW/Features/Study/Flashcards/FlashcardPauseStore.swift` — nowy.
- `FluentNOW/Features/Study/Flashcards/FlashcardDeckModel.swift` — `init(resume:)`, zapis przerwy, pomijanie przykładów.
- `FluentNOW/Features/Study/Flashcards/FlashcardDeckScreen.swift` — `resume`.
- `FluentNOW/Features/Study/Flashcards/FlashcardSummaryView.swift` — `StudyFlashcardsCard.pausedText`.
- FluentKit `Sessions/FreshStart.swift` — nowy.
- FluentKit `Sessions/SingleTypeSession.swift` — `avoidingExamples`.
- FluentKit `Sessions/FlashcardDeck.swift` — `FlashcardRun: Codable`, `avoidingExamples`.

### K2 — Słownik → Polecane
- Ekran nie ma `ScrollView`. Ma nagłówek, elastyczny obszar strony i dolny pasek o stałej wysokości.
- `UsefulWordsPageArea` mierzy wysokość przez `GeometryReader`. Liczba słów na stronie to `UsefulWordsPaging.pageSize(forHeight:rowHeight:)`, czyli 3–6. Wysokość wiersza to `@ScaledMetric` 78 pt, więc skaluje się z Dynamic Type. Po zmianie rozmiaru strony pierwsze widoczne słowo zostaje widoczne. Gdy nie mieszczą się nawet 3 słowa (bardzo duża czcionka), strona po 3 słowa przewija się awaryjnie.
- Wiersz jest zwięzły (`UsefulWordCompactText`): hasło + poziom, tłumaczenie i uzasadnienie, każde w jednej linii. Pod „i” jest popover z pełnym opisem, IPA, przykładem i wymową. Zostały „+” i „Masz już”.
- **„Odśwież propozycje”** jest w nagłówku na górze. Gdy brakuje miejsca, napis skraca się do „Odśwież”. Opis „skąd te słowa” przeniosłem pod „i” w nagłówku.
- Dolny pasek ma stałą wysokość: „Dodaj do nauki: N słów”, komunikat po dodaniu albo wskazówka. Dzięki temu zaznaczanie nie zmienia podziału stron.
- Stronę zmienia się tylko przesunięciem w bok, strzałkami albo kropkami (VoiceOver: akcja „dostosuj”). Przewijania pionowego nie ma, więc nie ma konfliktu gestów.

Pliki: `FluentNOW/Features/Stats/UsefulWordsScreen.swift` (przepisany układ, logika zestawów bez zmian), `UsefulWordsPaging.swift` (`minPageSize`, `pageSize(forHeight:rowHeight:)`, `pages(_:size:)`, `page(containing:size:)`), `UsefulWordsComponents.swift` (`UsefulWordCompactText`).

### K3 — czytanie: wyraźniejsze polecane słowa
- Słowa z mojego słownika: fiolet (`accentSoftInk`) na fioletowym tle, ciągłe podkreślenie, zwykła grubość.
- Słowa polecane: **pogrubiony teal** na jasnym morskim tle (`ReadingHighlightColors.usefulInk/usefulFill`).
- Rozróżnienie nie opiera się tylko na kolorze: pogrubienie kontra podkreślenie.
- Kontrast (Node, WCAG) — wszystko ≥ 4,5:1:

  | Para | Jasny | Ciemny |
  |---|---|---|
  | mój słownik na swoim tle | 5,84 | 6,39 |
  | polecane na swoim tle | 5,59 | 7,30 |
  | mój słownik na markerze dowodu | 6,26 | 5,66 |
  | polecane na markerze dowodu | 5,93 | 6,89 |

- **Dwie warstwy.** SwiftUI `Text` maluje linki kolorem `tint` i pomija ich kolor tekstu (wniosek ui-tweaks). Tym samym kolorem nie dałoby się odróżnić dwóch rodzajów słów. Dlatego `ReadingHighlightedText` rysuje akapit w dwóch warstwach:
  - spód: te same znaki z linkami, przezroczyste (`.clear`, `tint(.clear)`, `contentShape`); obsługuje dotknięcia i VoiceOver;
  - wierzch: wygląd bez linków; `allowsHitTesting(false)`, ukryty dla VoiceOver.

  Obie warstwy mają tę samą czcionkę i grubość, więc wiersze łamią się identycznie.
- Legenda korzysta z `ReadingHighlightStyle.legendText`.

Pliki: `FluentNOW/Features/Reading/ReadingHighlighting.swift`. W `ReadingPassageCard.swift` zmiana jest minimalna: `ReadingParagraphView` dostaje warstwę `links`, a legenda bierze teksty ze stylu. Sygnatura `ReadingPassageCard` się nie zmieniła.

## 2. API / kontrakty
```swift
// FluentKit
public enum FreshStart {
  static func examples(in session: VocabSession?) -> [String: Set<Int>]
  static func examples(in cards: [FlashcardCard]) -> [String: Set<Int>]
  static func preferredExample(_ meaning: Meaning, fallback: Int, avoiding: Set<Int>) -> Int
  static func singleTypeSession(state:type:minutes:collection:now:) -> VocabSession
  static func restartPractice(_:kind:level:content:now:id:) -> LearnerState
  static func restartProduction(_:level:content:now:id:) -> LearnerState
  static func restartReading(_:bank:now:) -> LearnerState
}
SingleTypeSession.makeSession(state:type:minutes:collection:now:avoidingExamples: = [:])
FlashcardDeckBuilder.makeDeck(..., shuffled:, avoidingExamples: = [:]) // i wariant z using:
public struct FlashcardRun: Codable, Sendable, Hashable
// Aplikacja
enum StudyActivity { case singleType(ExerciseType), flashcards, reading, practice(PracticeKind), production }
StudyResumePrompt.make(for:state:pausedDeck:) -> StudyResumePrompt?
StudyFlow.resumedFlashcards(FlashcardPausedDeck)
FlashcardPauseStore.load/save/clear/abandon/takeAvoidedExamples (klucze "flashcards.pausedRun", "flashcards.avoidExamples")
StudyStarter.startMode(_:minutes:collection:store:images:), startSingleType(_:minutes:collection:store:fresh: = false), restartBank(_:store:content:)
FlashcardDeckScreen(collection:resume: = nil), FlashcardDeckModel(store:collection:resume: = nil, defaults:)
StudyHomeView.activity(for: StudyMode) -> StudyActivity?
```
`StudyStarter.Outcome` nie ma już `.combinedDraft`. `VocabSessionModel.extend` używa `default:`, więc kompiluje się bez zmian.

## 3. Odstępstwa i decyzje
- Karta „Czytanie i gramatyka” to dodatek ponad K1. Bez niej po usunięciu sekcji wyboru trybów te zajęcia byłyby nieosiągalne.
- Przerwana talia fiszek jest zapisana **na urządzeniu** (`UserDefaults`), bez synchronizacji iCloud. Pole w `LearnerState` wymagałoby zmiany modeli core-engine, a każda odpowiedź i tak jest już zsynchronizowana.
- Przerwana sesja *innego* typu albo codzienna mieszanka nie blokuje kafelka: nowa sesja ją zastępuje, a odpowiedzi są zapisane. Okno pojawia się tylko dla tego samego typu, bo tak opisuje to K1.
- „Zacznij od nowa” zmienia **zdania**. Słowa zostają te same, bo kolejność wyznaczają terminy powtórek. „Dopasuj pary” nie pokazuje zdań, więc plansze mogą się powtórzyć.
- Zestaw po „Zacznij od nowa” ma własne `id` (`…-<uuid>`). Historia jest kluczowana po id, więc późniejszy zwykły zestaw nie nadpisze wpisu.

## 4. Ryzyka / do sprawdzenia na symulatorze
1. **`StudyTestCard()`** wstawiłem w `StudyHomeView.loadedContent` z komentarzem. Kontrakt z test-mode (SendMessage): `struct StudyTestCard: View`, `init()` bez argumentów. Na koniec sprawdziłem grepem: plik `Features/Study/Test/StudyTestCard.swift` istnieje i ma `init() {}`.
2. **Dwie warstwy w czytance:** sprawdzić, że dotknięcie słowa otwiera arkusz, czyli że przezroczysty `Text` z `contentShape` łapie linki. Sprawdzić też, że warstwy się nie rozjeżdżają, także przy Pogrubionym tekście w ustawieniach.
3. `confirmationDialog` → od razu `fullScreenCover` („Kontynuuj”, fiszki od nowa). SwiftUI zwykle prezentuje po zamknięciu okna, ale sprawdzić, że ekran się otwiera.
4. Polecane: wysokość wiersza 78 pt to szacunek dla 3 linii (headline, subheadline, footnote). Jeśli strona jest za ciasna lub ucina się dół karty, trzeba podnieść `rowHeight` w `UsefulWordsPageArea`.
5. `FlashcardDeckModel.init` z `@Observable` przypisuje obserwowane właściwości (`run`, `phase`) i wywołuje `showNextCard()` po inicjalizacji wszystkich pól. To powinno być poprawne, ale nie było kompilowane.
6. `StudyLayoutTests` jest `@MainActor`, jak `FeaturePureFunctionTests`, bo woła statyczne metody widoku.

## 5. Prośby do innych ról
- **test-mode:** `StudyTestCard()` jest wstawiony pod „Ćwiczeniami”. Nie dotykałem `Study/Session/*`, `Components/*` ani `Study/Test/*`.
- **reading-redesign / ui-learning:** w `ReadingPassageCard.swift` zmieniłem tylko `ReadingParagraphView` (warstwa linków) i teksty legendy.
- **design-shell:** kolory słów polecanych są lokalnie w `ReadingHighlightColors` (z `Palette.dynamic`). Można je przenieść do `Palette` jako rolę `usefulWord`.
- **code-qa:** stare klucze `study.minutes`, `study.modes`, `study.random` i `study.profileApplied` w `UserDefaults` nie są już czytane (są nieszkodliwe).

## 6. Testy
- `Packages/FluentKit/Tests/FluentKitTests/FreshStartTests.swift`, nowy, 11 testów:
  - wybór przykładu bez pomijania jest identyczny jak dotąd;
  - nowa sesja jednego typu ma inne zdania (meaning / recall / dictation / cloze);
  - znaczenie z jednym zdaniem zostaje w sesji;
  - talia fiszek pomija zdania porzuconej talii;
  - `FlashcardRun` przechodzi przez JSON;
  - gramatyka, idiomy i miks mają inne zadania i nowe id, bez wpisu w historii;
  - produkcja i czytanka są inne;
  - pusty bank nie zmienia stanu.
- `FluentNOWTests/StudyLayout/StudyLayoutTests.swift`, nowy:
  - okno tylko dla tego samego typu;
  - fiszki wymagają przerwanej talii;
  - mapowanie trybów;
  - zapis, porzucenie i jednorazowy odczyt talii; uszkodzony zapis jest ignorowany;
  - rozmiar strony z wysokości i podział na strony;
  - warstwa wyglądu bez linków, warstwa linków z tymi samymi znakami, pogrubienie w obu warstwach;
  - legenda.
- Istniejących testów nie zmieniałem. `StudyHomeView.decodeModes` i `StudyResumeItem.items` zostały, więc `FeaturePureFunctionTests` przechodzi bez zmian.
- Uruchomione skrypty:
  - kontrast kolorów w Node (wyniki w K3);
  - sprawdzenie nawiasów w 25 plikach: ok.

  `swift test` / Xcode — niedostępne na Windows.
