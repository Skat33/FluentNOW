# Raport: ui-learning (fala 2)

Obszar: `ios/FluentNOW/Features/Study/`, `Features/Reading/`, `Features/Practice/`. 39 plików Swift, ok. 5 500 linii. Kod napisany na Windows **bez kompilatora** — pierwsza kompilacja na Macu. Wszystkie sygnatury FluentKit, Services (stan po zapisie platform-services) i DesignSystem sprawdzone grepem.

## 1. Co zrobiono (pliki)

```
Features/Study/
  StudyRootScreen.swift            body → StudyHomeView() (+ #Preview). StudyRootPlaceholder.swift USUNIĘTY.
  StudyFlowView.swift              pełny ekran sesji (.fullScreenCover): NavigationStack + „Zrób przerwę” (X)
  Support/StudySupport.swift       Array.studyItem(at:), StudyFormat (czas, %, polska odmiana, data), StudyResources
                                   (AnswerVariants + PolishAnswerIndex + starterWords z ContentLibrary), StudyAnswerOutcome, StudyScrollID
  Support/StudyFlow.swift          enum StudyFlow (vocabulary/combined/reading/practice/production), enum StudyRoute (.history),
                                   rozszerzenia StudyMode (opis, ikona, rodzaj praktyki) i PracticeKind.studyTitle
  Support/StudyStarter.swift       start sesji: jeden tryb / sesja łączona; budowanie przez store.compute, zapis store.update(.session)
  Home/StudyHomeView.swift         „Na co masz dziś ochotę?”: wznowienia, stan pusty, wybór, historia; konsumpcja router.consumeStudyLaunch()
  Home/StudySetupCard.swift        „Ile masz czasu?” 5/10/15, 8 trybów (wielokrotny wybór), „Losuj kolejność”, szacunek, start
  Home/StudyModeCard.swift         kafelek trybu
  Home/StudyResumeCard.swift       StudyResumeItem.items(in:) — sesja łączona, słownictwo, czytanka, zestaw, produkcja
  Home/StudyCombinedDraftSheet.swift  podsumowanie sesji łączonej, gdy część trybów nie ma zadań
  Home/StudyHistoryViews.swift     „Ostatnie ćwiczenia” + StudyHistoryScreen (StudyRoute.history)
  Components/                      StudyExerciseKindBanner („Rodzaj ćwiczenia”), StudyChoiceList (ABCD, skróty 1–4),
                                   StudyAnswerField, StudySessionHeader + StudyElapsedClock, StudyHintBox/StudyHintButton,
                                   StudySentenceAudioButton, StudyExplanationDisclosure, StudyPronunciationButton („Powiedz to”),
                                   StudyReportButton + StudyReportSheet (ExerciseReportStore)
  Session/                         VocabExerciseContent (dane zadania), VocabExerciseModel (@Observable, etapy zadania),
                                   VocabExerciseView (karta, fiszka z gestem), VocabPrompts (5 typów), VocabAnswerArea,
                                   VocabFeedbackView (+ VocabFeedbackSummary), VocabSessionModel, VocabSessionView
  Combined/                        CombinedSessionModel, CombinedSessionView, CombinedQuestionModel, CombinedQuestionView
  Summary/                         StudySummaryData (z Review.before/after), StudySummaryView („Mały krok za Tobą.”)
Features/Practice/
  PracticeComponents.swift         PracticeContentLoader, PracticeContextText, PracticeIntroCard, PracticeResultCard,
                                   StudyHistoryLine + StudyHistoryList
  PracticeSetView.swift            gramatyka / idiomy / miks (ABCD + wpisywanie) przez PracticeFlow
  ProductionPracticeView.swift     produkcja gramatyczna z diagnozą i regułą po odpowiedzi
Features/Reading/
  ReadingPracticeView.swift        poziom (LevelEstimator), czytanka z banku, pytania, wynik, historia
  ReadingPassageCard.swift         tekst (krój szeryfowy, readableWidth), słowa z mojego słownika jako linki, odsłuch całości i akapitów
  ReadingQuestionCard.swift        pytanie ABCD + wynik z fragmentem-dowodem
  ReadingWordSheet.swift           podgląd dotkniętego słowa (znaczenia, wymowa)
```

Każdy widok ma `#Preview` z `.fluentPreviewEnvironment()` (ekran Nauka także z `.previewEmpty`).

## 2. Publiczne API / kontrakty dla innych

- `StudyRootScreen()` — kontrakt powłoki bez zmian.
- Start nauki z innych ekranów **tylko** przez router: `router.startStudy(.daily)`, `.mistakes`, `.resumeLast`, `StudyLaunchRequest(modes: ["mixed","reading"], minutes: 10, collection: "Lotnisko")`. Ekran Nauka konsumuje prośbę dopiero po `store.loadPhase != .loading`; nieznane tryby pomija, pusta lista = `mixed`; `resume` otwiera pierwszą niedokończoną sesję (łączona → słownictwo → czytanka → zestaw → produkcja). `collection` działa dla trybów słownikowych (jeden tryb).
- `enum StudyRoute: Hashable { case history }` + `.navigationDestination` w `StudyHomeView`.
- Preferencje wyboru per urządzenie w `@AppStorage`: `study.minutes`, `study.modes` (CSV surowych `StudyMode`), `study.random`.
- Zgłoszenia: `ExerciseReport(mode:question:answer:expected:wordId:meaningId:comment:)` przez `ExerciseReportStore.add`.

## 3. Jak to działa (skrót)

- **Zapis**: każda odpowiedź = funkcja FluentKit w `store.update(.answer)`; start/koniec sesji `.session`; „widziane” zadania gramatyki `.edit`. Sesje żyją w `state` → wznowienie po zabiciu aplikacji działa samo.
- **Słownictwo**: `SessionBuilder.makeSession` (przez `store.compute`) → zadanie: `VocabExerciseContent` (przykład `example % count`, `Cloze`, `VocabularyGrader.gradingWord/vocabularyAnswers`) → ocena `VocabularyGrader.localGrade` → „Dalej” = `Scheduler.recordAnswer(… confidence, hint, spellingCorrect …)`. Fiszka: odsłoń → pewność → Pamiętam/Jeszcze nie (przyciski, Enter lub gest przesunięcia) zapisuje od razu. Dystraktory „Wybierz znaczenie”: `MeaningOptions.options` z `PolishAnswerIndex` i pulą startową, cache + liczenie następnego zadania zawczasu.
- **Druga próba**: pierwsza błędna odpowiedź (bez literówki) → „Jeszcze nie”, podpowiedź odsłonięta, pole aktywne; druga próba lub „Pokaż odpowiedź”. Literówka (`Grade.closestAnswer`) → „Prawie — to literówka?” + „Uznaj moją odpowiedź” (`correct: true, spellingCorrect: false`).
- **AI**: tylko dla błędnej odpowiedzi bez literówki w tłumaczeniu PL→EN i znaczeniu, gdy `assistant.activeProvider != .offline`; etap „Asystent sprawdza…” z „Pomiń”; `nil`/timeout → ocena lokalna. Ocena lokalna zawsze natychmiast.
- **Sesja łączona**: `CombinedSessionBuilder.makeSession` (banki z `ContentLibrary.practiceContent(level:)` dla poziomu `LevelEstimator`) → zadania słownikowe (ten sam widok co sesja słownictwa, bez wyboru pewności) i pytania (`ProductionGrader.checkPracticeInput` / `grade`) → „Następne zadanie” = `saveAnswer` + `advance` atomowo. `GrammarSelector.markSeen` przy wyświetleniu zadania z `bankId`.
- **Praktyka/produkcja/czytanie**: wyłącznie `PracticeFlow.*` (start, odpowiedź, przejście, historia), `PracticeFlow.submitReading` (waga czytania jak strona).
- **Czytanie**: `ReadingTokenizer.tokens` liczone przez `store.compute`; słowa ze słownika to linki `fluentnow-word://open/<id>` obsłużone lokalnym `OpenURLAction` → arkusz ze znaczeniami (naturalne zawijanie tekstu, nawigacja VoiceOver po linkach).
- **Klawiatura/dostępność**: Enter = sprawdź/dalej (`onSubmit`, `.keyboardShortcut(.defaultAction)`), 1–4 = opcje ABCD (wyłączone tam, gdzie obok jest pole tekstowe lub wiele list — czytanka), pola EN: `.asciiCapable`, bez autokorekty i wielkich liter, `.submitLabel(.done)`, autofokus, przewinięcie do wyniku po 180 ms (jak `use-answer-scroll`), `scrollDismissesKeyboard`. Licznik czasu ukryty dla VoiceOver w trakcie, po odpowiedzi statyczna etykieta; wynik ogłaszany raz (`AccessibilityNotification.Announcement`). Animacje przez `Motion.resolved`/`contentTransition(reduceMotion:)`; haptyka przez `FeedbackPanel`/`.sensoryFeedback` z warunkiem `preferences.hapticsEnabled`.

## 4. Odstępstwa od strony i dlaczego

1. **Druga próba z podpowiedzią** po pierwszym błędzie (wymóg roli) — druga poprawna odpowiedź zapisuje się jako poprawna z podpowiedzią (`hint: true`, scheduler traktuje łagodniej niż samodzielną).
2. **„Uznaj moją odpowiedź”** przy literówce (decyzja core-engine §2) — strona nie miała tej opcji.
3. **Sesja łączona**: odpowiedź zapisywana przy „Następne zadanie” (zapis + przejście w jednym `update`), a nie przy sprawdzeniu — inaczej „Uznaj moją odpowiedź” nie mogłoby trafić do zapisu (`saveAnswer` przyjmuje odpowiedź raz). Słownictwo jak na stronie zapisuje przy „Dalej” (po wyborze pewności). W obu przypadkach zamknięcie aplikacji między sprawdzeniem a „Dalej” gubi tylko to jedno niezapisane zadanie.
4. **Start trybów praktyki/czytania/produkcji z ekranu Nauka od razu przygotowuje zestaw** (bez dodatkowego ekranu wstępu); wstęp zostaje, gdy brak zadań lub przy błędzie.
5. **Losowa kolejność** jako przełącznik na ekranie wyboru (widoczny przy ≥ 2 trybach); arkusz podsumowania sesji łączonej pokazuje się tylko, gdy część trybów nie ma zadań („Brak gotowych zadań — pominięte”).
6. **Kafelki wznowienia** także dla czytanki, zestawu i produkcji (strona: tylko sesja i sesja łączona).
7. **Podsumowanie** rozbudowane: zadania, samodzielnie poprawne, skuteczność, czas, ćwiczone umiejętności, „Te słowa urosły” (z `Review.before/after`), „Warto do nich wrócić”, wyniki per tryb w sesji łączonej; CTA „Jeszcze 5 minut” (sesja słownictwa w tym samym trybie).
8. **Dyktando odtwarza słowo automatycznie** po pojawieniu się (poza VoiceOver, żeby nie nakładać mowy).
9. **Gest przesunięcia fiszki**, „Powiedz to” (wymowa orientacyjna, bez wpływu na opanowanie), haptyka.
10. **Popover słowa w czytance → arkusz** (na iPhonie popover na fragmencie tekstu jest niewygodny).
11. Wpisywana odpowiedź w zestawie miksu nie jest zapisywana do `writtenAnswers` przy każdym naciśnięciu klawisza (strona tak robiła) — zapis przy sprawdzeniu (mniej zapisów, zero przycięć).
12. Brak opcji „Zmień na tłumaczenie” dla dyktanda bez syntezy mowy — `AVSpeechSynthesizer` jest zawsze dostępny na iOS.
13. Zadanie wskazujące usunięte słowo: karta „To słowo nie jest już dostępne” + „Pomiń zadanie” (strona blokowała sesję komunikatem).

## 5. Znane ryzyka / niesprawdzone (kompilacja)

- **Brak kompilatora.** Skrypt Node (lexer Swift: nawiasy z interpolacjami, ciągi, komentarze) — 39/39 plików OK; brak BOM/CR, brak `try!`/`as!`/`fatalError`; brak zduplikowanych nazw typów najwyższego poziomu w całym module aplikacji (stan na chwilę sprawdzenia — ui-library pracuje równolegle).
- Miejsca o mniejszej pewności:
  - Wywołania metod `@MainActor` modeli z domknięć gestów/pomocniczych właściwości widoków — zakładają Xcode 16+/26 SDK, gdzie `View`/`ViewModifier` są `@MainActor` (brief: Xcode 26).
  - `ReadingWordLink.attributed`: `piece[AttributeScopes.SwiftUIAttributes.UnderlineStyleAttribute.self] = Text.LineStyle.single` i `ForegroundColorAttribute` — jawne klucze jak w `HighlightedText` design-shell. W razie błędu: `piece.swiftUI.underlineStyle = .single`.
  - `VocabFeedbackSummary.init` oznaczony `@MainActor` (czyta model) — wołany z `body` i z `onChange`.
  - `@FocusState private var` bez wartości początkowej w widokach tworzonych z innych plików (wzorzec powszechny; memberwise init pomija opakowanie z `init()`).
  - `accessibilityAddTraits(isSelected ? [.isButton, .isSelected] : .isButton)` — w razie błędu typu zamienić na `AccessibilityTraits` jawnie.
  - `.simultaneousGesture(drag, including: isActive ? .all : .subviews)` na karcie fiszki w `ScrollView` — przewijanie pionowe powinno działać (gest reaguje tylko na ruch poziomy); sprawdzić na urządzeniu.
  - Teksty z Markdown: `Text("**\(x)**")` (LocalizedStringKey) i `FeedbackPanel(message:)` (AttributedString(markdown:)) — w tym drugim treść użytkownika jest escapowana (`VocabFeedbackSummary.escaped`).
- Nie sprawdzone w działaniu: płynność przejść (`.id(key)` + `Motion.contentTransition`), zachowanie klawiatury sprzętowej (skróty bez modyfikatorów obok pól tekstowych są celowo wyłączone).

## 6. Prośby do innych ról

- **ui-library**: „Zaczynam naukę” na Dzisiaj → `router.startStudy(.daily)`; kafelek przerwanej sesji → `router.startStudy(.resumeLast)`; „Ćwicz tę kolekcję” → `router.startStudy(StudyLaunchRequest(modes: ["mixed"], collection: nazwa))`; „Warto do nich wrócić” → `.mistakes`. Liczniki sesji można brać z `StudyResumeItem.items(in: store.state)` (typ internal w module).
- **design-shell**: (a) `ConfidencePicker`, `TagChip(isSelected:)` i `FeedbackPanel` (domyślnie) grają haptykę niezależnie od `AppPreferences.hapticsEnabled` — proszę o parametr lub odczyt preferencji w komponentach (u mnie `FeedbackPanel(playsHaptic: preferences.hapticsEnabled)`, ale picker/chip zawsze wibrują); (b) przydałby się wspólny komponent „przycisk tekstowy z ikoną” (mam kilka lokalnych `Button { Label(...) }.buttonStyle(.plain)` z akcentem).
- **platform-services**: przy „Usuń wszystkie dane” można wyczyścić klucze `UserDefaults` `study.minutes`, `study.modes`, `study.random` (nieszkodliwe, czysto UI). `ContentLibrary.answerVariants/polishAnswerIndex/starterWords` są wołane na start każdej sesji — zakładam cache w aktorze.
- **core-engine**: (a) `VocabularyGrader.gradingWord` używa surowego `task.example`, a wyświetlanie (strona i iOS) `example % liczba przykładów` — w UI normalizuję indeks przed `gradingWord`; warto znormalizować w FluentKit; (b) `subscript(safe:)` jest wewnętrzny — gdyby był `public`, UI nie potrzebowałoby `studyItem(at:)`.

## 7. Testy

Brak testów jednostkowych UI w tej fali (logika oceny i przejść stanu jest w FluentKit i tam przetestowana; modele UI są cienką warstwą). Kandydaci dla code-qa: `StudyFormat.plural/clock/duration`, `StudyHomeView.decodeModes`, `StudyResumeItem.items(in:)`, `StudySummaryData.make`, `VocabExerciseModel` (przepływ: pierwsza błędna → retry → poprawna z podpowiedzią; literówka → akceptacja), `ReadingWordLink.url/wordID`.

Uruchomione skrypty: lexer/bracket-check Swift (39 plików, 0 problemów), skan BOM/CR/zakazanych konstrukcji (czysto), skan duplikatów nazw typów w module (brak).
