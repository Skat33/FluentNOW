# Raport: topic-search (F1 — wyszukiwanie tematu zamiast katalogu)

Napisane na Windows **bez kompilatora**. Każda sygnatura sprawdzona grepem w kodzie; składnia (nawiasy, łańcuchy z interpolacją, CR/BOM, `try!`/`as!`/`fatalError`/force-unwrap) sprawdzona skryptem Node: wszystkie zmienione pliki OK. Algorytm wyszukiwania dostroiłem na **prototypie JS 1:1 z kodem Swift**, uruchomionym na prawdziwych 136 plikach tematów. Walidator wpisów ma replikę w JS: 10 203 wpisy bazy przechodzą go bez błędów.

## 1. Co zrobiono (pliki)

**FluentKit `Sources/FluentKit/Content/` (nowe)**
- `TopicSearch.swift`
  - `TopicSearchDocument`: lekki widok tematu, dekodowany wprost z `topics/*.json` bez przykładów.
  - `TopicSearchCatalog`: tokeny ASCII w kubełkach po pierwszej literze, zapamiętane zapytania.
  - `TopicSearch`:
    - normalizacja PL (bez diakrytyków, tylko `a-z0-9`), stopwords PL/EN;
    - stemming: wspólny prefiks ≥ 4 + końcówka fleksyjna z listy (eliminuje np. „pogoda”≠„pogodzić”);
    - prefiks wpisywany, literówki (OSA ≤1/≤2);
    - ranking z pewnością `low/medium/high` i progiem; kategorie fokusowe;
    - `sections` (kategoria → reszta tematu → powiązane tematy, w sekcji `frequency` potem CEFR, deduplikacja), `relatedMatches`, `usefulnessOrder`.
  - `TopicMatch`, `TopicSuggestion`, `TopicResultSection`, `TopicFocus`, `ContentDecoder.topicSearchDocument`.
- `TopicGeneration.swift`
  - Typy odpowiedzi AI (lenient): `TopicDraft*`, `TopicHydrationItem/Response`, `TopicHydrationRequestItem`.
  - `TopicGeneration`:
    - `buildTopic`: walidacja listy, odrzuca **wpisy** (zły poziom/pos/częstość, duplikat, puste), nie temat; id `ai-<slug>` unikalne;
    - `hydrationRequests`, `applyHydration` (dopasowanie po haśle), `hydratedEntry` (2 przykłady z focus ⊂ zdanie, definicja ≤140, naprawy drobnych błędów);
    - grupy, części mowy, rejestry.
  - `TopicEntryValidator`: reguły „error” `validate-content.mjs` bez heurystyk EN.
- `TopicMemory.swift`: `TopicQueryAlias`, `TopicAliasBook` (limit 500, trim), `GeneratedTopicRecord` (`TopicFile` + zapytanie, dostawca, daty; `completeEntries`, `dictionaryEntries`).

**FluentKit testy (nowe)**
- `Tests/FluentKitTests/TopicSearchTests.swift`: 15 testów na prawdziwych plikach przez `#filePath`.
- `Tests/FluentKitTests/TopicGenerationTests.swift`: 13 testów.

**Services**
- `Services/Content/LocalTopicStore.swift` (nowy):
  - `Application Support/FluentNOW/GeneratedTopics/{topics/<id>.json, aliases.json}`;
  - zapis `.atomic`; uszkodzony plik → `*.corrupt` i pominięcie.
- `Services/Content/ContentLibrary.swift`:
  - init z opcjonalnym `localTopics`;
  - katalog tematów budowany w tle ze **wszystkich plików `topics/*.json`** (nie z `index.json`, który bywał nieaktualny);
  - `topic(id:)`, `entry(reference:)`, `search`, `lookup` obejmują tematy AI: indeks szybkiego dodawania = słownik + kompletne wpisy AI, przebudowa po zapisie;
  - nowe metody: patrz §2; `warmUp` buduje też katalog.
- `Services/Assistant/`:
  - `AssistantTypes.swift`: protokół + domyślne implementacje rzucające „Włącz AI…”, `AssistantError.timeoutAfter(seconds:)`.
  - `AssistantValidation.swift`: prompty `topicList` (TOPIC_PROMPT v6 + scena/grupa), `topicListCompact` (Apple), `topicDetails` (TOPIC_HYDRATE_PROMPT v3 + reguły schematu), payloady.
  - `GeminiAssistant.swift`: `topicDraft`/`topicDetails`, schematy JSON (enumy poziomu/częstości/pos/rejestru/grupy). `generate` ma parametry `maxOutputTokens`/`requestTimeout`, domyślne = jak dotąd.
  - `AppleOnDeviceAssistant.swift`: `@Generable` dla listy (30–45 haseł — mały kontekst modelu) i szczegółów.
  - `AssistantService.swift`: `canGenerateTopics`, `generateTopicDraft`, `generateTopicDetails`, limity 150 s / 100 s, anulowanie.

**App**
- `AppRouter.swift`:
  - `AppSheet.topicSearch(query:topicID:)`, `presentTopicSearch`;
  - `openLibrary(.topics)` i cel `.topic(id:)` przekierowują do wyszukiwania (zgodność starych wywołań).
- `DeepLink.swift`: `fluentnow://topics[/<id>][?q=…]` → `.topicSearch`.
- `AppTab.swift`: `LibrarySection.browsable = [.words, .collections]`. Przypadek `.topics` zostaje tylko dla zgodności.
- `RootView.swift`: obsługa nowego arkusza.
- `QuickAddButton.swift`: etykieta „Dodaj słowo lub temat” i menu kontekstowe z obiema opcjami; ⌘N bez zmian.
- `AppEnvironment.swift`: `LocalTopicStore` w `live()`; „Usuń wszystkie dane” czyści też pamięć tematów.

**Features**
- `AddWord/AddWordRootScreen.swift`: wspólny arkusz „+” z przełącznikiem `Dodaj słowo | Szukaj tematu` w pasku (principal).
  - `init(prefill:mode:topicID:)` — stary `init(prefill:)` działa.
  - Dotychczasowy formularz to teraz `AddWordQuickForm`, bez zmian w logice.
- `Topics/`:
  - nowe:
    - `TopicSearchModel.swift`: `@Observable`, etapy enum, generowanie, nawadnianie partiami po 5 z postępem i „Przerwij”, zapis po każdej partii, dodawanie przez `TopicAdder`, aliasy;
    - `TopicSearchView.swift`;
    - `TopicSearchSections.swift`: przykłady, wyniki, filtr poziomu, „Zaznacz widoczne”, „Nie o to chodziło?”, brak dopasowania, generowanie, błąd, `CEFRDistributionBar`;
    - `TopicEntryRow.swift`.
  - zmienione: `TopicAddBar.swift` (etykieta postępu + „Przerwij”), `TopicEntryPreviewSheet.swift` (`isDraft`).
  - **usunięte**: `TopicsRootScreen`, `TopicDetailScreen`, `TopicEntriesList`, `TopicCard`.
- `Words/`:
  - `WordsRootScreen.swift`: bez segmentu Tematy;
  - `LibraryRoutes.swift`: bez `TopicRoute`;
  - `WordListView.swift`: CTA „Szukaj tematu”.
- `Today/`:
  - `TodayOnboardingView.swift`: 12 skrótów sytuacji zamiast listy tematów. Dodawanie: zapytanie → najlepszy temat → wpisy w kolejności wyników (poziom ≤ wybrany+1, maks. 30) → alias.
  - `TodayRootScreen.swift`: tylko przycisk w `TodayContent` (→ „Szukaj tematu”).
- `Stats/StatsRootScreen.swift`: stan pusty → „Szukaj tematu” (na prośbę koordynatora).

**Inne**
- `FluentNOWTests/Shell/ShellTests.swift`: dostosowane 2 testy deep linku/routera do nowego zachowania tematów (`.topicSearch`). Bez tego test by nie przeszedł.
- `docs/CONTRACTS.md` §8 (nowe API), `docs/DESIGN.md` §12/§13 (bez segmentu Tematy).

## 2. Nowe publiczne API

```swift
// FluentKit
TopicSearch.rank(_ query: String, in: TopicSearchCatalog, limit: Int = 8) -> [TopicMatch]
TopicSearch.bestMatch(_:in:) -> TopicMatch?           // tylko confidence ≥ .medium
TopicSearch.sections(primary:topic:related:relatedEntryLimit:) -> [TopicResultSection]
TopicSearch.relatedMatches(_:primary:limit:) / usefulnessOrder(_:) / normalize / keywords / queryKey
TopicSearchCatalog(documents:savedQueries:), .suggestions(for:), .document(id:)
TopicMatch { topicID, score, confidence (.low/.medium/.high, isGood), focus: [TopicFocus], isExactName, reason, isGenerated }
TopicGeneration.buildTopic(from:query:existingTopicIDs:) -> TopicBuildResult?
TopicGeneration.hydrationRequests(topic:entryIDs:) / applyHydration(topic:requests:items:) / hydratedEntry(draft:item:) / isDraft
TopicEntryValidator.issues(_:) / exampleIssues(_:)
TopicAliasBook.record(query:topicID:categoryID:now:) / remove(query:) / alias(for:)
GeneratedTopicRecord(topic:query:provider:createdAt:updatedAt:)

// Aplikacja: ContentLibrary / AssistantService / AppRouter — patrz docs/CONTRACTS.md §8
```

## 3. Odstępstwa od strony

- **Dopasowanie lokalne zamiast serwerowego korpusu i modelu-rozjemcy.**
  - Strona: `resolve` w `shared-corpus.ts` dopasowuje exact → alias → fuzzy, a potem rozstrzyga model (`TOPIC_RESOLVE_PROMPT`).
  - iOS: ranking offline po nazwach, aliasach, kategoriach, scenach i treści wpisów, z progiem pewności. AI nie rozstrzyga wyboru tematu; generuje temat tylko przy braku dobrego dopasowania (lub na żądanie: „Utwórz nowy temat z AI”).
  - Kategoria fokusowa działa podobnie jak `inferFocusCategory` strony: słowa zapytania niewyjaśnione nazwą tematu wskazują kategorię.
- **Szczegóły AI przed dodaniem.** Strona dodawała szkice z `needsDetails` i uzupełniała je w tle. iOS nie ma takiego potoku, więc zaznaczone szkice są nawadniane partiami po 5 przed dodaniem (z postępem i przerwaniem). Ukończone partie są zapisane, a szkic, którego AI nie poprawiło, zostaje zaznaczony do ponowienia. Do nauki nie trafia słowo bez przykładów.
- **Alias.** Zapisywany po dodaniu słów z wyniku, przy generowaniu i w onboardingu, a nie przy każdym wpisanym znaku. Dzięki temu częściowe frazy nie zaśmiecają pamięci. Przycisk „To nie ten temat” go usuwa.
- **Synchronizacja iCloud pamięci tematów:** pominięta. Pliki leżą w Application Support, objętej kopią zapasową urządzenia. Dodane słowa i tak synchronizują się, bo mają pełne dane w `Word`. Tracimy tylko szybkie wyszukanie tego samego tematu na drugim urządzeniu.

## 4. Ryzyka kompilacji — gdzie patrzeć na Macu

1. **`AppleOnDeviceAssistant.swift`**: nowe `@Generable` z zagnieżdżonymi tablicami. Wzorzec jest ten sam co w istniejącym `GeneratedLookup`. W razie problemów działa awaryjna flaga `FLUENT_DISABLE_FOUNDATION_MODELS`.
2. **`GeminiAssistant.swift`**: schematy rozbite na zmienne z jawnym `[String: Any]`, żeby uniknąć „unable to type-check”. Domyślny argument `requestTimeout: TimeInterval = GeminiAssistant.timeout`.
3. **`TopicSearch.swift`**: `TopicSearch.sections` używa funkcji zagnieżdżonej `unique`, która mutuje przechwycony `var seen` w `filter`. Jeśli kompilator zaprotestuje, rozwinąć do pętli `for`.
4. **`TopicSearchModel.swift`**:
   - domknięcie postępu w `TopicAdder.add` z `[weak self]` (nie-ucieczkowe);
   - `Task { [weak self] in await self?.runAdd() }`;
   - `defer` z warunkiem w funkcji `async`.
5. **`TopicSearchView.swift`**: `@Bindable var model` w prywatnym widoku (`$model.query`).
6. **`TopicSearchSections.swift`**:
   - `private var retry: (() -> Void)? { model.canGenerate ? { model.generate() } : nil }`. Jeśli inferencja zawiedzie, zamienić na `if/else`.
   - Wiele sekcji `List` z jednego `body` (TupleView).
7. **`AddWordRootScreen.swift`**: `presentationDetents`/`interactiveDismissDisabled` ustawiane wewnątrz `NavigationStack` (widoki trybu). `ToolbarItem(.principal)` z segmentowym `Picker` i `.fixedSize()`.
8. Testy XCTest używają `private static var cache` (tryb Swift 5 — OK).

**Do zrobienia na Macu:**
- `xcodegen`: nowe i usunięte pliki w `Features/Topics`, `Services/Content`.
- Potem `swift test` w `Packages/FluentKit` i ⌘U.

## 5. Co sprawdzić ręcznie na Macu

- „+” → przełącznik → „Szukaj tematu”. Wpisać „zamawianie w restauracji”: pierwsza sekcja „Najlepiej pasuje: Zamawianie”, potem reszta Restauracji.
- Zapytania „na lotnisku”, „u dentysty”, „lotnsko”, „job interview”: wynik od razu, offline.
- „jazda konna” bez AI → najbliższe tematy + „Włącz AI w Ustawieniach…” + przycisk do ustawień AI.
- To samo z Gemini:
  - Enter → generowanie (do ok. 1–2 min) → lista szkiców „propozycja AI”;
  - zaznacz 12 → „Dodaj” → postęp „AI przygotowuje szczegóły… 5/12” → „Przerwij” w połowie: zapisane partie zostają;
  - ponowne wyszukanie „jazda konna” → natychmiast i offline, oznaczenie „AI”.
- Apple Intelligence (iOS 26): krótsza lista; sprawdzić jakość polskich tłumaczeń — walidacja odrzuca wpisy z błędnymi przykładami.
- Szybkie dodawanie słowa z tematu AI: wpisz hasło z wygenerowanego tematu → propozycja z bazy.
- Deep link `fluentnow://topics/airport` i `fluentnow://topics?q=w%20hotelu`.
- Onboarding: chipsy sytuacji, dodanie 3 sytuacji, start sesji.
- „Usuń wszystkie dane” czyści tematy AI.
- Wydajność: pierwsze wyszukanie tuż po starcie. Katalog budowany jest w `warmUp`: ~136 plików, łącznie ok. 15 MB JSON, dekodowanych lekko w tle. Do zmierzenia w Instruments.

## 6. Prośby do innych ról

- **ui-library (Collections):** `CollectionsRootScreen.swift:22–24` — przycisk „Przeglądaj tematy” → `router.openLibrary(.topics)`. Działa dzięki przekierowaniu, ale lepiej zmienić etykietę na „Szukaj tematu” i wołać `router.presentTopicSearch()`.
- **ui-learning (Study):** `StudyHomeView.swift:84` (`onBrowseTopics`) i `:306` („Przeglądaj tematy”) — jak wyżej.
- **design-shell:** `DesignSystem/Components/StateViews.swift:12` — przykład w komentarzu używa `openLibrary(.topics)`.
- **data-pipeline:** `topics/index.json` przestał być potrzebny wyszukiwaniu (katalog czyta wszystkie pliki). Jeśli nikt inny go nie używa, można go zostawić tylko dla `validateAll`.

## 7. Testy i uruchomione skrypty

Swift nieuruchomiony (brak kompilatora).

**`TopicSearchTests` (15):**
- normalizacja i słowa kluczowe;
- podobieństwo: stemy, prefiks, literówki, fałszywy stem „pogoda/pogodzić”, OSA;
- 13 polskich zapytań sytuacyjnych → właściwy temat z pewnością `high`;
- zapytania angielskie;
- literówki;
- kategorie fokusowe (Zamawianie, Rachunek i napiwek, Odprawa, Kontrola bezpieczeństwa, Zameldowanie; EN przez wpisy);
- brak dobrego dopasowania („jazda konna”);
- wydajność;
- zapamiętane zapytanie wygrywa i niesie kategorię;
- temat AI jest wyszukiwalny;
- kolejność sekcji i sortowanie frequency → CEFR, każdy wpis raz;
- powiązane tematy;
- stabilność sortowania;
- skróty onboardingu zawsze trafiają w bazę.

**`TopicGenerationTests` (13):**
- budowa tematu z odrzuceniem 5 złych pozycji i mapowaniem EN części mowy / „less common” / (AmE);
- za mało wpisów → `nil`;
- id i slugi;
- normalizatory;
- nawadnianie: poprawne uzupełnione, zły focus → zostaje szkicem, naprawy drobnych błędów, odrzucenia;
- lenient decoding;
- **każdy wpis bazy przechodzi `TopicEntryValidator`**;
- walidator wykrywa błędy;
- `TopicAliasBook`;
- round-trip `GeneratedTopicRecord`;
- dodanie tematu AI do słownika z `contentRef`.

**Uruchomione skrypty (Node):**
- prototyp rankingu na 136 tematach: wszystkie oczekiwania testów spełnione, ok. 3 ms na zapytanie;
- replika walidatora: 10 203 / 10 203 wpisów OK;
- lexer składni: 0 problemów we wszystkich zmienionych plikach.
