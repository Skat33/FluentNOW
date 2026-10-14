# Raport: recommendations (FEEDBACK-1, F5)

Analiza poziomu w tle + „Polecane słówka”. Kod napisany na Windows **bez kompilatora**. Sygnatury sprawdzone grepem w kodzie. Skrypt kontrolny (nawiasy z interpolacją, BOM, CR, `try!`/`as!`/`fatalError`/force-unwrap) przechodzi dla wszystkich plików obszaru.

## 1. Co zrobiono (pliki)

**FluentKit (nowe)**
- `Sources/FluentKit/Analysis/LearnerAnalysis.swift`: `LearnerAnalyzer` (czyste funkcje), `LearnerAnalysis`, `LevelAssessment` (poziom z zakresem i pewnością), `AnalysisConfidence`, `SkillInsight`, `LearningPace`, `StudyRegularity`, `TopicArea`, `AnalysisText` (polska odmiana, wewnętrzne).
- `Sources/FluentKit/Analysis/UsefulWordRecommender.swift`: `UsefulWordRecommender`, `UsefulWordCandidate`, `UsefulWordSuggestion`, `UsefulWordReason`, `UsefulWordProfile`, `UsefulWordOptions`.
- `Tests/FluentKitTests/LearnerAnalysisTests.swift`: 10 testów.
- `Tests/FluentKitTests/UsefulWordRecommenderTests.swift`: 12 testów, w tym 3 na prawdziwej treści (`#filePath`, `XCTSkip` gdy brak plików).

**Aplikacja (nowe)**
- `Features/Today/UsefulWordsCatalog.swift`:
  - aktor `UsefulWordsCatalog.shared`: kandydaci z `dictionary-index.json` + `topics/index.json`, szczegóły wpisów (rejestr, część mowy, IPA, przykład), wielo-przebiegowy ranking, cache;
  - `UsefulWordsLoader`: profil przez `store.compute`;
  - `UsefulWordsAdder`: dodawanie przez `store.update(.bulk)` + `VocabularyMerger`;
  - `UsefulWordsResult`, `UsefulWordDetail`, `UsefulWordsAddOutcome`.
- `Features/Today/TodayRecommendedWordsSection.swift`:
  - sekcja „Polecane słówka” na Dzisiaj: 5 słów, „+” dodaje jednym dotknięciem, link „Zobacz więcej polecanych słówek”;
  - wspólne widoki: `UsefulWordRow`, `UsefulWordText`, `UsefulWordAddButton`, `UsefulWordsMoreLabel`.
- `Features/Today/TodayAnalysisCard.swift`:
  - zwięzła karta: poziom/zakres + pewność, tempo, mocna/słaba strona, „Pełna analiza w Postępach” (`router.select(.progress)`);
  - `AnalysisDisplayText`.
- `Features/Stats/StatsAnalysisSection.swift`: pełna analiza w Postępach. Zawiera:
  - poziom z opisem pewności i zakresem tego, co mierzy;
  - mocne i słabe strony z paskami oraz umiejętności jeszcze nie ćwiczone;
  - tempo: słupki 4 tygodni, regularność 14 dni, opanowane w 4 tygodniach;
  - obszary tematyczne (najmocniejszy i najsłabszy);
  - wejście do „Polecanych słówek”.
- `Features/Stats/UsefulWordsScreen.swift`: ekran „Polecane słówka” z 30 propozycjami:
  - zaznaczanie pojedyncze lub „Zaznacz wszystkie”;
  - dolny przycisk „Dodaj do nauki: N słów” oraz „+” przy każdym wierszu;
  - przykład, wymowa, komunikat o wyniku i haptyka.

**Minimalne wpięcia we wspólnych plikach**
- `Features/Today/TodayRootScreen.swift`: tylko `TodayContent`. W gałęzi z treścią doszły 2 linie po `TodayWeekCard`: `TodayAnalysisCard(analysis: snapshot.analysis)` i `TodayRecommendedWordsSection()`. `body` korzenia bez zmian.
- `Features/Today/TodaySnapshot.swift`: pole `analysis: LearnerAnalysis`, liczone w `make` przez `LearnerAnalyzer.analyze(state, topics: nil, now:)`. Sygnatura `make` bez zmian.
- `Features/Stats/StatsSnapshot.swift`: pole `analysis` oraz `make(state:now:topics: TopicIndex? = nil)`.
- `Features/Stats/StatsRootScreen.swift`:
  - `@Environment(AppEnvironment.self) env`;
  - `.task(id: store.revision) { await refreshSnapshot() }`, czyli metoda z jawnymi typami domknięć; wczytuje `env.content.topicIndex()` tylko dla nazw obszarów;
  - `StatsLevelEstimateCard` zastąpiony przez `StatsAnalysisSection` i usunięty.
  - `StatsText.confidence` zostało, nieużywane.

`ContentLibrary` i inne pliki Services **nie zostały zmienione**.

## 2. Publiczne API (FluentKit)

```swift
// Analiza
public enum LearnerAnalyzer {
    static let areaLimit = 6, minSkillMeanings = 3, minAccuracyAnswers = 10, minAreaMeanings = 5
    static func analyze(_ state: LearnerState, topics: TopicIndex? = nil, now: Timestamp, calendar: Calendar = .current) -> LearnerAnalysis
    static func assessLevel(_ state: LearnerState) -> LevelAssessment
    static func skillInsights(_ state: LearnerState, now: Timestamp, windowDays: Int = 30) -> [SkillInsight]
    static func splitSkills(_ skills: [SkillInsight]) -> (strong: [SkillInsight], weak: [SkillInsight])
    static func untestedSkills(_ state: LearnerState) -> [Skill]
    static func pace(_ state: LearnerState, now: Timestamp, weeks: Int = 4, calendar: Calendar = .current) -> LearningPace
    static func topicAreas(_ state: LearnerState, topics: TopicIndex?) -> [TopicArea]
}
public struct LearnerAnalysis { level: LevelAssessment; skills, strongSkills, weakSkills: [SkillInsight]; untestedSkills: [Skill];
    pace: LearningPace; topicAreas: [TopicArea]; strongestArea, weakestArea: TopicArea?; var hasData: Bool; var skillsSummaryPl: String? }
public struct LevelAssessment { estimate: LevelEstimate; score: Double; lowerLevel, upperLevel: String; confidence: AnalysisConfidence;
    practicedMeanings, totalAnswers: Int; var level, targetLevel, rangeText, descriptionPl: String; static let scopeNotePl }
public enum AnalysisConfidence: String { case insufficient, low, medium, high; var namePl }
public struct SkillInsight: Identifiable { skill; average; meanings; recentAnswers; recentAccuracy: Int?; strength }
public struct LearningPace { newMeaningsByWeek: [Int]; newMeaningsPerWeek, answersPerWeek: Double; activeDays, windowDays: Int;
    regularity: StudyRegularity; masteredRecently: Int; var roundedNewPerWeek: Int; var summaryPl: String }
public enum StudyRegularity: String { case inactive, occasional, regular, daily; var namePl }
public struct TopicArea: Identifiable { id, name, group: String; meanings, averageMastery, mastered: Int }

// Polecane słówka
public enum UsefulWordRecommender {
    static let everydayGroups: Set<String>   // basics, daily, communication, food, travel, health, money
    static let starterTopicName = "Podstawowe słowa", starterGroup = "basics"
    static func candidates(index: DictionaryIndex, topics: TopicIndex) -> [UsefulWordCandidate]
    static func candidates(entries: [DictionaryIndex.Entry], topics: TopicIndex) -> [UsefulWordCandidate]
    static func isFrequent(_ f: SpokenFrequency) -> Bool
    static func isAllowedRegister(_ register: String, learnedTopic: Bool) -> Bool
    static func recommend(_ candidates: [UsefulWordCandidate], profile: UsefulWordProfile, options: UsefulWordOptions = UsefulWordOptions()) -> [UsefulWordSuggestion]
    static func defaultMaxPerTopic(limit: Int) -> Int
}
public struct UsefulWordCandidate: Identifiable { reference, term, key, translation, level: String; frequency: SpokenFrequency; topicID, topicName, group: String }
public struct UsefulWordSuggestion: Identifiable { candidate; score: Int; reasons: [UsefulWordReason]; var summaryPl: String }
public enum UsefulWordReason { case frequent(SpokenFrequency), fitsLevel(String), nextLevel(String), learnedTopic(String), everyday; var textPl }
public struct UsefulWordProfile { level, targetLevel; ownedKeys, ownedReferences: Set<String>; topicCounts: [String: Int]; collectionKeys: Set<String>
    static func make(_ state: LearnerState, estimate: LevelEstimate? = nil) -> UsefulWordProfile }
public struct UsefulWordOptions { limit = 20; maxPerTopic: Int?; registers: [String: String]; excludedReferences: Set<String>; seed: Int = 0 }
```
Wszystkie typy są `Sendable` i `Hashable` (poza `LearnerAnalyzer`/`UsefulWordRecommender`) z jawnymi `public init`.

## 3. Decyzje (i odstępstwa od strony)

**Poziom.** `level`/`targetLevel` to dokładnie `LevelEstimator.estimatedLevel`, więc wynik jest spójny z doborem treści ćwiczeń. Do tego doszła własna, drobniejsza pewność:
- `insufficient`: brak słów z poziomem;
- `low`: mniej niż 10 znaczeń z opanowaniem ≥ 40 albo mniej niż 40 odpowiedzi;
- `medium`: mniej niż 30 takich znaczeń albo mniej niż 150 odpowiedzi;
- `high`: pozostałe przypadki.

Przy niskiej i średniej pewności pokazujemy **zakres** (np. „A2–B1”). Szerokość to ±0,75 lub ±0,4 poziomu wokół średniej ważonej. Opisy są uczciwe:
- przy braku wyników użytkownika: „jeszcze bez Twoich wyników… To nie jest wynik egzaminu”;
- zawsze dopisek „Ocena dotyczy słownictwa, które ćwiczysz — nie gramatyki ani mówienia”.

Odpowiedzi demo się nie liczą.

**Umiejętności.** Porównywane jest 5 umiejętności opanowania, każda wymaga co najmniej 3 ćwiczonych znaczeń. Siła to średni wynik. Gdy w ostatnich 30 dniach jest co najmniej 10 odpowiedzi, siła to średnia z wyniku i skuteczności. Mocna strona: co najmniej 5 pkt powyżej średniej i co najmniej 40. Słaba: co najmniej 5 pkt poniżej. Najwyżej po 2. Gdy różnicy nie ma, wyświetlamy komunikat zamiast sztucznego „słabego punktu”.

**Tempo.** Nowe znaczenie to takie, którego najwcześniejsza zachowana odpowiedź ma `before == 0`. Dzięki temu znaczenia ze skompaktowaną historią (`before > 0`) nie liczą się jako nowe. Pozostałe wskaźniki:
- 4 okna 7-dniowe;
- odpowiedzi na tydzień;
- aktywne dni z ostatnich 14: 0 → brak nauki, 1–4 → od czasu do czasu, 5–10 → regularnie, 11+ → prawie codziennie;
- opanowane w 4 tygodniach (`ProgressStatistics.masteryGains`).

**Obszary tematyczne.** Grupowane według `contentRef` → temat z indeksu, a w pozostałych przypadkach według kolekcji. Archiwum jest pomijane.

**Polecane słówka (F5).**
- Kandydaci:
  - tylko `very_common`/`common` z poprawnym poziomem;
  - temat musi być w `topics/index.json`; dwa tematy spoza indeksu (`shopping-mall`, `volunteering-charity`) są do czasu przebudowy indeksu pomijane;
  - wpisy startowe dostają nazwę „Podstawowe słowa” i grupę `basics`.
- Wykluczenia:
  - poziom powyżej docelowego (szacowany + 1);
  - hasło już posiadane, porównane po kluczu `searchKey`, **także w archiwum**, czyli innych znaczeń posiadanego hasła nie polecamy;
  - posiadany `contentRef`;
  - rejestr `slangowy` zawsze;
  - `specjalistyczny`, chyba że użytkownik uczy się danego tematu.
- Punktacja:
  - temat, którego się uczę: +18 + min(12, liczba/2); za taki temat uznajemy też kolekcję nazwaną jak temat;
  - częstotliwość: bardzo częste +40, częste +26;
  - poziom: równy szacowanemu +20, o jeden wyżej (cel) +14, o jeden niżej +10, niższe +2;
  - grupa codzienna +12.
- Jedno znaczenie na hasło (deduplikacja po kluczu).
- Różnorodność, zachłannie:
  - limit na temat: max(2, ⌈limit/5⌉), czyli 4 przy 20;
  - limit na grupę: 40% listy;
  - kary −6 za każde słowo z tego samego tematu i −3 z tej samej grupy;
  - gdy limity się wyczerpią, lista jest krótsza, ale nigdy nie ma 20 słów z jednego tematu.
- Kolejność przy remisie: wynik, częstotliwość, poziom, potem **hash FNV-1a z (seed + klucz)**. Bez tego lista była alfabetyczna („absolutely, air conditioning…”). Aplikacja podaje numer tygodnia jako `seed`, więc lista zmienia się co tydzień, a w obrębie tygodnia jest stabilna.
- Ranking jest deterministyczny i niezależny od kolejności wejścia (test).
- Uzasadnienia, dwa najważniejsze, np. „Z tematu Restauracja, którego się uczysz · często używane”, „Często używane · pasuje do Twojego poziomu B1”.

**Rejestr.** `dictionary-index.json` nie ma rejestru, a wczytywanie wszystkich 136 tematów (15 MB) byłoby za drogie. Dlatego ranking idzie w maksymalnie 4 przebiegach:
1. ranking;
2. wczytanie szczegółów tylko wyników (pliki tematów czytane bezpośrednio w `Task.detached`, w cache zostaje tylko mały słownik szczegółów, nie całe tematy);
3. ponowny ranking ze znanymi rejestrami.

Na prawdziwej treści (profil B1, restauracja) wystarczają 2 przebiegi. Słabo udokumentowane miejsca: niedostępny wpis trafia do `excludedReferences`.

**Dodawanie.**
- Wpisy tematów: `VocabularyMerger.addTopicEntries(state, topic:, entryIDs:)`, kolekcja = nazwa tematu, jak przy dodawaniu tematu.
- Wpisy startowe: `suggestion` → `lookup` → `mergeSuggestions` (kolekcja „Codzienne rozmowy”).
- Wszystko w jednym `store.update(.bulk)`. Pliki tematów pobiera `env.content.topic(id:)`.

**Odświeżanie.**
- Dzisiaj: analiza w `TodaySnapshot`, w `store.compute`, na każdą zmianę `revision`. Polecane słówka mają własne `.task(id: store.revision)` z 300 ms zwłoki przy kolejnych zmianach.
- Postępy: analiza w `StatsSnapshot`, czyli w tle po sesji i przy starcie.
- Wynik rankingu jest cache'owany w aktorze per `limit`, klucz to profil + tydzień, więc odpowiedzi w sesji, które nie zmieniają profilu, nie przeliczają listy.

## 4. Ryzyka kompilacji / niesprawdzone

- **Brak kompilacji.** Krótkie `body` wszędzie. Ekrany są dzielone na podwidoki, `switch` po `UsefulWordsPhase`, haptyka w `ViewModifier`, domknięcia z jawnymi typami (`store.compute { (state: LearnerState) -> StatsSnapshot in … }`). Teksty z interpolacją domknięć przeniesione do funkcji zwracających `String`.
- `NavigationLink(destination:label:)` (bez trasy) w stosie z `path` — w `TodayRecommendedWordsSection.swift` i `StatsAnalysisSection.swift`. Działa od iOS 16. Gdyby nie działało, trzeba dodać `enum UsefulWordsRoute` + `.navigationDestination` w korzeniach.
- `TodayRecommendedWordsSection` zawsze wstawia `VStack`, potrzebny do `.task`. Gdy lista jest pusta, w stosie Dzisiaj zostaje dodatkowy odstęp `Spacing.l`. To kosmetyka i rzadki przypadek.
- `StatsContent.body` ma nadal 10 widoków: `StatsAnalysisSection` zastąpił kartę poziomu.
- Aktor `UsefulWordsCatalog`:
  - `static let shared`; korzeń treści z `Bundle.main.url(forResource: "Content")`, tak samo jak `ContentLibrary.init(bundle:)`;
  - `private static func readDetails` wołana z `Task.detached` (statyczne metody aktora są nonisolated);
  - `ContentLibrary.isSafeFileName` (static) wołane synchronicznie.
- FluentKit:
  - zagnieżdżona funkcja `learnedCount` modyfikuje lokalny cache;
  - `splitSkills` zwraca publiczną krotkę z etykietami;
  - wewnętrzny `struct Ranked` w publicznym enumie;
  - `first.uppercased() + String(...)`.
- Testy na prawdziwej treści zależą od `topics/restaurant.json` i indeksów. Sprawdziłem je portem algorytmu w Node: 20 propozycji, 18 tematów, 7 grup, wszystkie codzienne; dla A1 bez słów wszystkie są A1 lub codzienne.

## 5. Prośby do innych ról

- **platform-services:** `ContentLibrary.dictionaryEntries() async -> [DictionaryIndex.Entry]` lub `dictionaryIndex()`. Dziś katalog czyta `dictionary-index.json` sam, więc indeks jest dekodowany dwa razy: raz dla wyszukiwania, raz tutaj, raz na uruchomienie.
- **data-pipeline:** pole rejestru w `dictionary-index.json` (np. `g`, tylko gdy różne od `neutralny`) pozwoliłoby liczyć ranking w jednym przebiegu. To zmiana schematu §3, więc tylko jako propozycja. Trzeba też przebudować `topics/index.json` (`node ios/tools/build-index.mjs`), żeby objął `shopping-mall` i `volunteering-charity`.
- **topic-search:** w `StatsRootScreen` (stan pusty) zostało „Przeglądaj tematy” → `router.openLibrary(.topics)`. Nie ruszałem tego, to wasz zakres (F1). Wysłałem informację o moich zmianach we wspólnych plikach.
- **code-qa:** testy aplikacji dla `UsefulWordsAdder` (wpis tematu + startowy, `.bulk`, brak duplikatów) i `UsefulWordsCatalog` na `Bundle` testowym.

## 6. Testy

Nieuruchomione, bo na Windows nie ma Swifta.

**LearnerAnalysisTests**
- pusty stan;
- historia demo daje tylko niską pewność, a poziom = `LevelEstimator`;
- same zadeklarowane poziomy dają uczciwy opis i zakres;
- pewność średnia i wysoka (40 znaczeń, 160 odpowiedzi → „B1”);
- mocne/słabe strony: rozpoznawanie i przypominanie (skuteczność 100%) kontra pisownia; tekst podsumowania;
- za mało danych i lista niećwiczonych;
- tempo: tylko pierwsze odpowiedzi nowych znaczeń, bez demo i bez okna 28 dni, kubełki `[0,0,1,1]`, regularność, tekst;
- tempo regularnego ucznia;
- obszary: temat z indeksu, kolekcja, archiwum, najmocniejszy i najsłabszy;
- polska odmiana.

**UsefulWordRecommenderTests**
- filtry: częstotliwość, poziom, posiadane hasła i referencje, limit 0;
- rejestr: slang nigdy; specjalistyczny tylko dla uczonego tematu; formalny i potoczny dozwolone; wykluczone referencje;
- preferencje (temat użytkownika > codzienny > techniczny) i dokładne teksty uzasadnień;
- preferencja poziomu i tekst „krok w stronę poziomu B2”;
- jedno znaczenie na hasło, z wygraną tematu użytkownika;
- różnorodność: 30 słów z jednego tematu daje najwyżej 4 z tematu i 16 wyników;
- determinizm przy przetasowaniu i odwróceniu wejścia;
- budowa kandydatów z indeksu: rzadkie, nieznany temat, brak poziomu, błędna referencja, starter;
- profil ze stanu: archiwum posiadane, `contentRef`, kolekcja jako temat;
- **prawdziwy słownik:**
  - profil B1 ze słowami z restauracji, ranking dwuprzebiegowy z rejestrami z prawdziwych plików tematów;
  - wynik: 20 słów, tylko częste, poziom ≤ B2, bez posiadanych, unikalne hasła, bez slangu i bez specjalistycznych spoza restauracji;
  - ≤ 4 na temat, ≥ 5 tematów, ≥ 3 grupy, ≥ 12 z grup codziennych, jest uzasadnienie „z tematu Restauracja”, wynik deterministyczny;
- **nowicjusz:** A1/A2 i tylko grupy codzienne;
- wydajność rankingu: limit 60, margines debug 2 s.

Uruchomione skrypty (Node, w scratchpadzie):
- kontrola składni wszystkich plików obszaru: 0 problemów;
- port rankingu na prawdziwych danych: 8 566 kandydatów, 6 799 po filtrach dla B1; wyniki opisane w §4.
