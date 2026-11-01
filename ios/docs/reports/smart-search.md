# Raport: smart-search (FEEDBACK-9 N3)

Mikrofon w polach wyszukiwania słów, podpowiedzi podczas pisania, literówki („Czy chodziło Ci o…?”).
Kod pisany na Windows bez kompilatora Swift; logika wyszukiwania sprawdzona portem JS na prawdziwym
`dictionary-index.json` (14 677 rekordów, 11 915 haseł).

## 1. Zmiany (plik → zmiana)

### FluentKit
| Plik | Zmiana |
|---|---|
| `Packages/FluentKit/Sources/FluentKit/Content/FuzzyMatcher.swift` (nowy) | `FuzzyMatcher`: progi (`maxDistance(forLength:)` 0 / 1 dla 3–5 / 2 dla 6+; `looseDistance` ≈ 1 edycja na 3 litery, maks. 3, od 4 liter), Damerau–Levenshtein w wariancie OSA (zamiana sąsiednich liter = 1 edycja) w paśmie z wczesnym wyjściem i współdzielonym buforem (bez alokacji na kandydata), filtr wstępny `sharesStart` (pierwsza/druga litera, także przesunięte o 1), `closest(to:in:limit:)` dla małych list (własne słowa). `FuzzyIndex`: unikalne klucze w kubełkach po długości. Porównanie po `TextNormalizer.searchKey` → „zażółć” = „zazolc”. |
| `Packages/FluentKit/Sources/FluentKit/Content/ContentSearch.swift` | Nowa kolejność `SearchMatchKind`: `exact` (0), **`polishExact`** (1, nowy — całe tłumaczenie lub jego wariant po `;`/`,`/`/`, bez nawiasów i `(AmE)`), `prefix` (2), `polish` (3), `wordPrefix` (4), `fuzzy` (5) + `isPolish`. Zakresy prefiksów są rankowane (częstość, długość) przed obcięciem — „c”/„ca” pokazuje częste słowa, nie alfabetycznie pierwsze. Literówki przez `FuzzyIndex` dla kluczy EN **i** polskich tłumaczeń/słów (≥ 3 litery). Nowe API: `suggestions(_:limit:) -> SearchSuggestionResult` (`matches` / `corrections` / `similar`), `SearchSuggestion` (grupa rekordów jednego hasła, tłumaczenia unikalne po `SenseGrouping.translationKey`), `SearchSuggestion.group(_:)`, `ownedTranslationCount(in:)`, `isFullyOwned(in:)`. `search(_:limit:)` zachowuje sygnaturę (nowe progi literówek). |
| `Packages/FluentKit/Tests/FluentKitTests/SmartSearchTests.swift` (nowy) | 20 testów — patrz §6. |

### Aplikacja
| Plik | Zmiana |
|---|---|
| `FluentNOW/Services/Speech/VoiceSearchController.swift` (nowy) | `@MainActor @Observable` kontroler dyktowania na pole: `SFSpeechRecognizer` en-US / pl-PL (osobny na język, leniwie), `requiresOnDeviceRecognition` gdy `supportsOnDeviceRecognition`, `taskHint = .search`, `addsPunctuation = false`, wynik częściowy na żywo (`onPartial`), auto-stop po 1,5 s ciszy od ostatniego wyniku, 4,5 s ciszy od startu albo 8 s; po zatrzymaniu mikrofonu do 1 s na wynik końcowy (`onFinish`). Zgody (Speech + `AVAudioApplication`), `VoiceSearchIssue` (brak zgody → „Otwórz Ustawienia”, język niedostępny, błąd audio), poziom dźwięku 0…1 do animacji, obsługa przerwań (`AVAudioSession.interruptionNotification`), licznik `generation` odrzuca spóźnione wyniki. Sesja `.playAndRecord/.measurement` aktywna tylko na czas nagrania, potem `setActive(false, .notifyOthersOnDeactivation)`; `cancel()` zwalnia silnik, tap, zadanie i obserwatora. `cleaned(_:)` — bez końcowej interpunkcji, małe litery. |
| `FluentNOW/Features/Search/VoiceSearchControls.swift` (nowy) | `VoiceSearchField` (domyślny język: Dodaj słowo/Słownik EN, Szukaj tematu PL; wybór zapamiętany per pole w `@AppStorage`), `VoiceSearchAction` (start/stop; przed startem `speech.stop()`; brak wyniku → przywraca poprzedni tekst), `VoiceSearchControls` (przełącznik „EN/PL” + mikrofon w wierszu pola), `VoiceSearchToolbarButton`, `VoiceSearchBanner` (pasek nagrywania w Słowniku: stan, zmiana języka = nagranie od nowa, „Gotowe”; jednolite tło, bez szkła), `VoiceSearchFooter`/`VoiceSearchStatus`, modyfikator `.voiceSearchLifecycle(_:)` (alert + `cancel()` w `onDisappear`). Animacja: kółko skalowane poziomem dźwięku + `symbolEffect(.variableColor.iterative)`, oba wyłączone przy „Ogranicz ruch”. Haptyka `selection` przy starcie/stopie i zmianie języka (przez `fluentSensoryFeedback`). |
| `FluentNOW/Features/Search/WordSuggestionViews.swift` (nowy) | `WordSuggestionRow` (hasło, tłumaczenia, `LevelBadge`, „Masz już” + wyszarzenie, „Masz już N z M znaczeń”), `WordSuggestionSections` („Czy chodziło Ci o…?” / „Propozycje” / „Podobne słowa”), `WordSuggestionRows`. |
| `FluentNOW/Features/AddWord/AddWordRootScreen.swift` | `candidates` → `suggestions: SearchSuggestionResult` z `env.content.suggestions(text, limit: 8)` (debounce 120 ms, na aktorze — bez retry 500 ms, bo `suggestions` czeka na indeks), `owned` z `store.compute` przy każdej `revision`, `@State voice`, `.voiceSearchLifecycle(voice)`, `select(term:)`, Enter = pierwsza propozycja albo pierwsza poprawka. |
| `FluentNOW/Features/AddWord/AddWordSections.swift` | `AddWordSearchField(…, voice:, …)` z `VoiceSearchControls` (EN domyślnie) i stopką stanu; `AddWordResultsSection(result:owned:…)` używa `WordSuggestionSections`; sekcja AI/ręcznie bez zmian w działaniu („Brak w bazie”, gdy brak propozycji). Usunięty prywatny `AddWordCandidateRow`. |
| `FluentNOW/Features/AddWord/AddWordModel.swift` | `isPolishMatch: first.match.isPolish` (uwzględnia `polishExact`); komentarz, że `AddWordCandidate` zostaje dla testów. |
| `FluentNOW/Features/Topics/TopicSearchView.swift` | `@State voice` w `TopicSearchScreen`, mikrofon + „PL/EN” w `TopicSearchFieldSection` (PL domyślnie), stopka stanu, `.voiceSearchLifecycle`. Logika `TopicSearchModel` bez zmian (wynik częściowy wpada do `query`, debounce 300 ms jak dotąd). |
| `FluentNOW/Features/Words/WordListView.swift` | Mikrofon w `ToolbarItem(.topBarLeading)` (pole `.searchable` jest systemowe), `VoiceSearchBanner` w `safeAreaInset(.bottom)`, placeholder „Słucham…”, sekcje `WordSearchExtrasSections` przy wpisanym tekście, `reloadExtras` po przeliczeniu listy. |
| `FluentNOW/Features/Words/WordSearchExtras.swift` (nowy) | „Czy chodziło Ci o…?” wśród własnych haseł i tłumaczeń (bez archiwum; tylko gdy lista jest pusta) → dotknięcie podmienia wyszukiwanie; „Dodaj ze słownika” — hasła z bazy, których użytkownik nie ma w całości (3 przy trafieniach, 5 bez; bez propozycji — poprawki literówek) → `router.presentQuickAdd(prefill:)`. |
| `FluentNOW/Services/Content/ContentLibrary.swift` | `func suggestions(_ query: String, limit: Int = 8) async -> SearchSuggestionResult` (czeka na indeks, liczy na aktorze). |
| `project.yml` | `NSSpeechRecognitionUsageDescription` i `NSMicrophoneUsageDescription` (były tylko dla wymowy) — teraz też wyszukiwanie głosem, uczciwie: na urządzeniu, jeśli to możliwe, inaczej usługa Apple; nagrania nie są zapisywane. |
| `FluentNOWTests/Services/SmartSearchAppTests.swift` (nowy) | 6 testów — patrz §6. |
| `docs/CONTRACTS.md` §4 | dopisana linia `ContentLibrary.suggestions`. |

## 2. Publiczne API

```swift
// FluentKit
public enum FuzzyMatcher {
    static func maxDistance(forLength: Int) -> Int; static func looseDistance(forLength: Int) -> Int
    static func distance(_ a: String, _ b: String, limit: Int) -> Int?      // po searchKey
    static func distance(_ a: [UInt8], _ b: [UInt8], limit: Int) -> Int?
    static func sharesStart(_ q: [UInt8], _ c: [UInt8]) -> Bool
    static func closest(to: String, in: [String], limit: Int = 3) -> [String]
}
public struct FuzzyIndex: Sendable { init(keys: [(key: String, payload: Int)]); var count: Int
    func matches(_ q: [UInt8], maxDistance: Int, requireSharedStart: Bool = true, limit: Int = 40) -> [Match] }
public enum SearchMatchKind { case exact, polishExact, prefix, polish, wordPrefix, fuzzy; var isPolish: Bool }
extension ContentSearch { func suggestions(_ query: String, limit: Int = 8) -> SearchSuggestionResult }
public struct SearchSuggestion: Identifiable { term, key, translations, level, match, distance, entries
    static func group(_ hits: [SearchHit]) -> [SearchSuggestion]
    func ownedTranslationCount(in: OwnedVocabulary) -> Int; func isFullyOwned(in: OwnedVocabulary) -> Bool }
public struct SearchSuggestionResult { query, matches, corrections, similar; static let empty; var isEmpty }

// Aplikacja
actor ContentLibrary { func suggestions(_ query: String, limit: Int = 8) async -> SearchSuggestionResult }
@MainActor @Observable final class VoiceSearchController {
    state: VoiceSearchState, transcript, level, language, notice, issue
    func start(language:onPartial:onFinish:) async; func stop(); func cancel()
    nonisolated static func cleaned(_:) -> String }
VoiceSearchControls(voice:text:field:onStart:), VoiceSearchToolbarButton, VoiceSearchBanner, VoiceSearchFooter,
View.voiceSearchLifecycle(_:), WordSuggestionRow/Sections/Rows, WordSearchExtras(+Sections)
```

## 3. Decyzje / odstępstwa

- **Kolejność**: dokładne EN → **dokładne całe tłumaczenie PL** → prefiks EN → PL → słowo wewnątrz frazy EN → literówki. Dokładne PL przed prefiksem EN, bo inaczej „dom” pokazywał 8 haseł „domain/domestic/…”, a „home/house” wypadały poza limit 8.
- „Czy chodziło Ci o…?” liczone, gdy nie ma trafienia dokładnego ani prefiksowego (EN/PL); same trafienia „wewnątrz frazy” nie blokują poprawek. „Podobne słowa” (luźniejszy próg, bez filtra pierwszych liter) tylko przy całkowitym braku; dla zapytań < 4 liter nie ma ich wcale (za dużo szumu).
- Literówki także po polsku (tłumaczenia i ich słowa ≥ 3 litery): „smochód” → car, „zakwaterownie” → accommodation.
- Fonetyka / sąsiedztwo klawiszy — nie wdrożone (opcjonalne w N3); OSA + częstość daje dobre wyniki w próbkach (recieve, beleive, neccessary, pronounciation, acomodation, hpuse, brake down).
- Język mikrofonu: przełącznik „EN/PL” przy polu (zapamiętany per pole), w Słowniku zmiana języka w pasku nagrywania. Nie zgadujemy języka automatycznie.
- Słownik: mikrofon w pasku narzędzi lewym (prawy ma już 2 ikony — DESIGN §9). `.searchSuggestions` celowo nieużyte (zasłoniłoby listę własnych słów podczas pisania).

## 4. Ryzyka kompilacji (do sprawdzenia na Macu)

- `VoiceSearchController.swift:271` — `request.addsPunctuation = false` (iOS 16+, `SFSpeechRecognitionRequest`). Jeśli kompilator zgłosi brak — usunąć linię (domyślnie i tak `false`).
- `VoiceSearchController.swift:270` — `request.taskHint = .search` (`SFSpeechRecognitionTaskHint.search`).
- `VoiceSearchController.swift:282–296` — domknięcia `@Sendable` z `[weak self]` i `Task { @MainActor in … }` (wzór jak w `PronunciationService`); `:287` `installTap(… block: Self.tapBlock(…))`, `:314` typ `AVAudioNodeTapBlock` z jawnymi parametrami `(buffer: AVAudioPCMBuffer, _: AVAudioTime)`; `:323` `floatChannelData`.
- `VoiceSearchController.swift:228–232` — `AVAudioApplication.shared.recordPermission` / `requestRecordPermission()` (iOS 17, jak w `PronunciationService`).
- `VoiceSearchController.swift:445` — `addObserver(forName:object:queue:)` z blokiem `(_: Notification)`.
- `VoiceSearchControls.swift:320` — `alert(_:isPresented:presenting:actions:message:)` z tytułem `String`; `:76/111/141` — `AppStorage(wrappedValue:_:)` z dynamicznym kluczem; `:242` `.animation(Animation?, value:)`; `:154/267` `symbolEffect(.variableColor.iterative, isActive:)` (jak w `SpeakButton`).
- `WordListView.swift:29` — `ToolbarItem(placement: .topBarLeading)` dodany z widoku-dziecka (obok pozycji z `WordsRootScreen`).
- `FuzzyMatcher.swift:99` — `if let q1, let c1, …` (skrócony zapis Swift 5.7); `:155` init z tablicą krotek z etykietami (wywołania przekazują `[(key: String, payload: Int)]`).
- `ContentSearch.swift:113` — porównanie krotek przez jawny typ domknięcia; `:204` prywatny `HitCollector` z własnym `init(excluding:)`; `:294` `ArraySlice` krotek.
- `SearchMatchKind` zmienił wartości `rawValue` (nowy przypadek). Nigdzie nie są zapisywane; jedyne `switch` po typie jest w FluentKit. `TextScanAnalysis` porównuje tylko `.exact` — znaczenie bez zmian.

## 5. Co sprawdzić w symulatorze (mikrofon działa z mikrofonem Maca)

1. „+” → Dodaj słowo: wpisz „c”, „ca”, „car” — do 8 propozycji z tłumaczeniem i poziomem, częste na górze; posiadane wyszarzone z „Masz już”.
2. „samochod”, „zazolc”, „dom” — trafienia po polsku bez polskich znaków; „home”/„house” przed „domain”.
3. „recieve”, „beleive”, „acomodation”, „smochód” — sekcja „Czy chodziło Ci o…?”; dotknięcie otwiera znaczenia. „acomodasion” → „Podobne słowa”. „qqqq” → „Brak w bazie” + AI (gdy włączone) + „Dodaj ręcznie”.
4. Mikrofon w „Dodaj słowo”: pierwszy raz — systemowe prośby o zgodę (rozpoznawanie mowy, mikrofon); powiedz „boarding pass” — tekst pojawia się na żywo, nagranie kończy się samo po ~1,5 s ciszy; „EN” → „PL” i powiedz „lotnisko”. Odmów zgody (Ustawienia → Prywatność) → alert z „Otwórz Ustawienia”.
5. Po nagraniu wybierz hasło i dotknij głośnika — wymowa musi zagrać (sesja audio zwolniona). Muzyka w tle: ścisza się na czas nagrania i wraca.
6. „Szukaj tematu”: mikrofon domyślnie „PL”, powiedz „zamawianie w restauracji”.
7. Słownik: mikrofon po lewej w pasku → pasek „Słucham po angielsku…” na dole, przycisk „PL” zaczyna od nowa po polsku, „Gotowe” kończy. Wpisz literówkę własnego słowa — „Czy chodziło Ci o…?”; wpisz nowe słowo — „Dodaj ze słownika” otwiera arkusz z wypełnionym polem.
8. VoiceOver: etykiety „Szukaj głosem”, „Język dyktowania: angielski”; „Ogranicz ruch” — brak pulsowania.
9. Wydajność: pisanie szybko w „Dodaj słowo” bez zacięć; pierwsze wyszukiwanie po starcie czeka na indeks (spinner nie jest potrzebny — lista pojawia się po zbudowaniu).

## 5a. Prośby do innych ról

- **content-audit (N4)**: w `dictionary-index.json` nie ma hasła **„airport” / „lotnisko”** (ani żadnego tłumaczenia z „lotnisk…”), mimo że to rdzeń tematu podróży — warto dopisać (wykryte przy testach literówek „lotnsko”).
- **code-qa (N5)**: test UI/ręczny konfliktu sesji audio przy szybkim przełączaniu nagrywanie → odsłuch → nagrywanie na urządzeniu (symulator nie odwzorowuje dokładnie `AVAudioSession`).

## 6. Testy

FluentKit `SmartSearchTests` (20): progi długości; OSA (recieve/receive, teh/the, hpuse, acomodation, kitten/sitting z limitem, puste napisy, ujemny limit); polskie znaki (zażółć/zazolc, Łódź/lodz); zgodność z Levenshteinem (OSA ≤ L ≤ 2·OSA); filtr pierwszych liter; `closest` wśród własnych słów; `FuzzyIndex` (scalanie kluczy, kolejność, bez trafienia dokładnego); ranking „car” (dokładne → prefiks → wewnątrz frazy, częstsze pierwsze); PL z i bez znaków, wielkie litery, warianty po przecinku, `(AmE)`; „dom” — dokładne PL przed prefiksem EN; grupowanie duplikatów jak `SenseGrouping` (catch up: 4 rekordy → 2 tłumaczenia, core pierwszy); „Masz już” (częściowo/całość, po odwołaniu i po parze hasło|tłumaczenie); literówki EN i PL; brak poprawek przy trafieniu prefiksowym; „Podobne słowa” tylko przy całkowitym braku; limit i ranking dla 1 litery; `search()` z nowymi progami; wydajność na 15 000 syntetycznych rekordów i na prawdziwym słowniku (pomijany bez treści) — próg w teście 150 ms/zapytanie (Debug), cel < 30 ms.

Aplikacja `SmartSearchAppTests` (6): czyszczenie transkrypcji; języki i domyślne języki pól; kontroler bez mikrofonu (stop/cancel bezpieczne, komunikaty); poprawki własnych słów (archiwum pominięte, PL bez znaków to nie literówka); „Dodaj ze słownika” pomija posiadane; `ContentLibrary.suggestions` na treści repozytorium.

Istniejące testy, które dotyczą zmienionego kodu i powinny przejść bez zmian: `ContentTests.testContentSearchKinds`, `testContentSearchPerformanceOn20000Records`, `ContentLibraryTests.testSearchAndLookupAfterWarmUp`, `FeaturePureFunctionTests.testAddWordCandidates*`.

**Uruchomione tutaj**: port JS logiki (`ContentSearch` + `FuzzyMatcher`) na prawdziwym `dictionary-index.json`: budowa indeksu ~90 ms, zapytania 0,01–12 ms (najdroższe: „podobne słowa” bez filtra, ~8–10 ms w JS). Wyniki zgodne z oczekiwaniami testów (m.in. c/ca/car, samochod → car, dom → home/house, recieve → receive, neccessary → necessary, pronounciation → pronunciation, brake down → break down, smochod → car, acomodasion → podobne: accommodation). Testów Swift nie dało się uruchomić (Windows, brak kompilatora) — `swift test` w `Packages/FluentKit` i testy aplikacji do uruchomienia na Macu. Nie uruchamiano git ani `build-index.mjs`; JSON treści bez zmian.
