# feedback-8 — raport (FEEDBACK-8 M1–M3)

Kod napisany na Windows **bez kompilatora**. Każdą użytą sygnaturę sprawdziłem grepem. Skrypt kontrolny przeszedł dla wszystkich zmienionych plików: nawiasy z interpolacją, brak BOM i CR, brak `try!`/`as!`/`fatalError`. Nie uruchamiałem git ani `build-index.mjs`. Treść JSON w `Resources/Content` jest bez zmian, czytałem ją tylko skryptem w Node.

## 1. Co zmieniono

### M1 — wyróżnienia w czytance

**Wyróżnienie słowa to teraz tylko kolor tekstu i grubość kroju.** Nie ma podkreśleń ani tła słowa. Tło ma tylko marker dowodu na etapie wyników.

- `DesignSystem/Tokens/Palette.swift`: nowe role kolorów, każda w wariancie jasnym i ciemnym.
  - `readingGlossaryInk` (przyciemniony akcent): `0x5B3FB8` / `0xC4AEFF`.
  - `readingRecommendedInk` (morski): `0x0B6870` / `0x7DD8D3`.
  - `readingOwnInk` (ciepły pomarańczowy brąz): `0x9A4510` / `0xF5A86A`.
  - Kontrast policzyłem w Node, jasny / ciemny motyw:

    | Kolor | na `surface` | na markerze dowodu (`warningSoft`) |
    |---|---|---|
    | słowniczek | 7,4 / 8,5 | 6,7 / 5,9 |
    | polecane | 6,5 / 9,9 | 5,9 / 6,9 |
    | moje słowa | 6,5 / 8,4 | 5,9 / 5,8 |

    Wszystkie wartości ≥ 4,5, czyli WCAG AA.
- `Features/Reading/ReadingHighlighting.swift`:
  - `ReadingHighlightStyle.Kind` ma teraz 3 przypadki (`CaseIterable`):
    - `.glossary`: słowniczek, czyli dotknij → tłumaczenie. Kolor akcentu, krój średni (medium).
    - `.recommended`: wpis słowniczka z `ref` do wpisu bazy, czyli „Dodaj do nauki” jednym dotknięciem. Pogrubiony, kolor morski.
    - `.own`: słowo z mojego słownika. Półgruby krój (semibold), kolor pomarańczowy.
  - Rodzaj liczy `kind(of:glossary:)`.
  - Grubość ustawia `FontAttribute` ze stałym krojem `Font.system(.body, design: .serif, weight:)`, więc Dynamic Type działa. Obie warstwy (wygląd i linki) dostają ten sam krój, więc wiersze łamią się identycznie.
  - `attributed(…, glossary:)` ma nowy parametr z wartością domyślną.
  - `ReadingPassageLayout.kinds` zastępuje `hasOwnWords` / `hasUsefulWords`.
  - Usunąłem `UnderlineStyleAttribute`.
- `Features/Reading/ReadingPassageCard.swift`: legenda pod tytułem.
  - Kolorowe próbki „słowniczek · polecane · Twoje słowa”, a pod nimi jedna wskazówka „Dotknij wyróżnionego słowa…”.
  - Przy rozmiarach dostępności i w wąskim miejscu (`ViewThatFits`) próbki układają się w kolumnie z opisem.
  - VoiceOver dostaje jedną etykietę z opisem koloru i grubości każdego rodzaju.

### M2 — jedna siatka „Ćwiczenia”, wybór pojedynczy

- `Features/Study/Home/StudyExerciseCatalog.swift` (nowy plik, zastępuje usunięty `StudyMoreActivitiesCard.swift`):
  - `StudyExerciseTile` (`.activity(StudyActivity)` / `.pictures`) z tytułem, opisem i ikoną.
  - `StudyExerciseGroup.all`: 3 grupy w jednej siatce.
    - „Słownictwo — jeden rodzaj zadania”: 7 typów i kafelek „Słowo i zdjęcie” z oznaczeniem „W budowie”.
    - „Powtórki z Twojego słownika”: Codzienna mieszanka, Tryb pomyłek, Słowa w parach.
    - „Czytanie i gramatyka”: Czytanie, Gramatyka, Idiomy, Miks językowy, Produkcja.
  - `StudyExerciseAvailability`: liczba słów dla kafelków słownictwa.
- `Home/StudyExerciseTypesCard.swift` (przepisany): jedna karta „Ćwiczenia” z wyborem 5/10 min. Wybór długości dotyczy ćwiczeń ze słówkami.
  - Komunikat pojawia się nad siatką. Siatka to `LazyVGrid` z nagłówkami sekcji.
  - Kafelek bez słów nie jest już przezroczysty. Ma wyciszone tło i tekst „Brak słów — dotknij, by sprawdzić dlaczego”, a dotknięcie pokazuje wyjaśnienie.
  - Znaczniki „Przerwane” i „W budowie” zostały.
  - Kafelki nie używają szkła.
- `Home/StudyHomeView.swift`:
  - Karta „Ćwiczenia” jest widoczna zawsze, także bez słów. Karta Fiszki zostaje na górze, Test zaraz pod siatką.
  - `.vocabulary(mode)` przechodzi przez `open` / `resume` / `restart` / `startNew`, czyli przez to samo okno „Kontynuuj / Zacznij od nowa”.
  - `startMode(_:minutes:noticeInline:fresh:)`.
  - `activity(for:)`: mieszanka, pomyłki i pary zwracają `.vocabulary(mode)`.
  - Prośba z routera bez przerwanej sesji startuje od razu, z długością z prośby.
  - Nowe stany i pomocnicze: `startingMode`, `startingTile`, `isBusy`.
- `Support/StudyFlow.swift`: `StudyActivity.vocabulary(StudyMode)`.
- `Support/StudyResume.swift`: okno wznowienia dla mieszanki, pomyłek i par. Sesja jednego typu (`exercise-…`) się nie liczy.
- `Support/StudyStarter.swift`:
  - `startVocabulary(…, fresh:)` używa `FreshStart.vocabularySession`.
  - Jaśniejsze komunikaty dla pustego trybu pomyłek i par.
- `Session/VocabSessionView.swift:113`, `Combined/CombinedSessionView.swift:115`: zamiast „Wybierz rodzaj/rodzaje ćwiczeń” jest teraz „Wróć do ekranu Nauka i dotknij kafelka ćwiczenia, aby zacząć.”. Grep nie znajduje już tekstów „Zaznacz jeden lub kilka”, „Wybierz ćwiczenie” ani „Wybierz rodzaj ćwiczeń”.
- `App/DeepLink.swift`: zaktualizowałem tylko dokumentację: `exercise-<typ>` i brak łączenia trybów. `AppRouter` jest bez zmian, bo kafelki używają istniejących ścieżek.
- FluentKit:
  - `Sessions/VocabularyModeAvailability.swift` (nowy): `candidates`, `count` i `counts` dla trybu.
  - `SessionBuilder.makeSession` korzysta teraz z `candidates`. To wydzielenie tych samych filtrów, zachowanie się nie zmienia.
  - `Sessions/FreshStart.swift`: `vocabularySession(state:mode:minutes:collection:pictureMeaningIDs:[using:])`. Zdania przerwanej sesji traktuje jako użyte, ale tylko w kopii stanu.

### M3 — „Dodaj słowo” bez duplikatów

- FluentKit `Content/SenseGrouping.swift` (nowy): `SenseGroup`, `SenseGrouping.groups(_:)`, `grouped(_ lookup:)`, `sameMeaning`, `definitionSimilarity`.
  - Grupuje po znormalizowanym tłumaczeniu (`OwnedVocabulary.translationKey`).
  - Ostrożnie grupuje też różne tłumaczenia, ale tylko gdy spełnione są wszystkie trzy warunki:
    - każde tłumaczenie jest na liście `acceptedTranslations` drugiego;
    - część mowy jest ta sama;
    - definicje EN pokrywają się w ≥ 0,5 (Jaccard słów treściowych).

    Na treści: reguła łączy np. *weigh* „ważyć” / „zważyć”, a nie łączy *mouse* „mysz” / „myszka”. Daje 45 takich połączeń w bazie, wszystkie przejrzałem i są tym samym znaczeniem.
  - Kolejność wyboru wpisu głównego: core, potem częstość, potem kompletność (definicja + poziom), potem kolejność.
  - Scalone znaczenie:
    - pola wpisu głównego;
    - przykłady ze wszystkich wpisów, bez powtórzonych zdań (po normalizacji);
    - suma `acceptedAnswers` i `acceptedTranslations`;
    - pozostałe odwołania w `mergedContentRefs`.
- FluentKit `Models/TutorTypes.swift` (`SenseSuggestion`) i `Models/Meaning.swift`: nowe pole opcjonalne `mergedContentRefs: [String]?`.
  - Dekodowanie jest łagodne, a koder syntetyczny pomija pole, gdy jest `nil`. Stare dane dekodują się bez zmian, a sync (`mergeWord` przenosi całe `Meaning`) i eksport JSON zachowują pole.
  - Dodałem pomocnicze `Meaning.allContentRefs`.
- FluentKit `VocabularyMerger.mergeSuggestions` zapisuje `mergedContentRefs`, a `addedContentReferences` uwzględnia wszystkie odwołania. Dzięki temu zgrupowane wpisy są „dodane” także w czytance (`ReadingGlossaryAdder.isAdded`). `OwnedVocabulary` i `UsefulWordRecommender` też biorą pod uwagę wszystkie odwołania.
- FluentKit `TopicSearch.duplicateKey`: ten sam klucz co `OwnedVocabulary`, więc tłumaczenia z etykietą dialektu też uznaje za duplikat. „Szukaj tematu” już wcześniej pokazywał hasło + tłumaczenie raz, a posiadane wyszarzał.
- `Features/AddWord/AddWordRootScreen.swift` `show(_:source:)`: lookup przechodzi przez `SenseGrouping.grouped`, więc lista pokazuje jeden wiersz na znaczenie. Dodanie odbywa się istniejącą ścieżką `mergeSuggestions`.
- `AddWordModel.swift`:
  - `AddWordCandidate.group` usuwa powtórzone tłumaczenia po kluczu.
  - `knownSenseIndices` widzi wiersz jako „Masz już”, gdy użytkownik ma którykolwiek ze zgrupowanych wpisów.
- `AddWordSections.swift`: wiersz pokazuje „4 przykłady” z poprawną odmianą liczebnika, a stopka wyjaśnia grupowanie.
- Skanowanie (`Scan/`) przekazuje hasło do tego samego arkusza „Dodaj słowo” (z formularza i z paska Słownika przez `presentQuickAdd`), więc grupuje tak samo bez zmian w kodzie.

## 2. Publiczne API (nowe)

```swift
// FluentKit
public enum VocabularyModeAvailability {
    static func candidates(state:mode:collection:) -> [WordMeaning]
    static func count(state:mode:collection:) -> Int
    static func counts(state:modes:collection:) -> [StudyMode: Int]
}
FreshStart.vocabularySession(state:mode:minutes:collection:pictureMeaningIDs:using:) -> VocabSession   // + wariant bez RNG
public struct SenseGroup { var sense: SenseSuggestion; var memberIndices: [Int]; var exampleCount: Int }
public enum SenseGrouping { groups(_:) ; grouped(_ lookup:) -> (lookup: Lookup, groups: [SenseGroup]); translationKey; sameMeaning; definitionSimilarity; definitionThreshold }
SenseSuggestion.mergedContentRefs: [String]?     Meaning.mergedContentRefs: [String]?     Meaning.allContentRefs: [String]
// Aplikacja
enum StudyActivity { …; case vocabulary(StudyMode) }
enum StudyExerciseTile; struct StudyExerciseGroup; struct StudyExerciseAvailability; PracticeKind.studyMode
Palette.readingGlossaryInk / readingRecommendedInk / readingOwnInk
```

## 3. Odstępstwa i decyzje

- **Podział na „słowniczek” i „polecane” w czytance.** Polecane to wpis słowniczka, który ma `ref`, czyli pełny wpis bazy do dodania jednym dotknięciem z przykładami. Takich wpisów jest 294 z 765. Wpis bez `ref` daje tylko tłumaczenie.
- **Słowa z mojego słownika nie mają kropki-znacznika.** Znacznik wymagałby wstawienia znaku do tekstu, który VoiceOver odczytuje jako „punktor”. Zamiast tego rozróżnienie niesie półgruby krój, osobny kolor (pomarańczowy, wyraźnie inny od fioletu i morskiego) i legenda.
- **Pojedyncze znaczenie nie jest zaznaczane automatycznie w „Dodaj słowo”.** Zostawiłem wcześniejszą decyzję „nic nie jest zaznaczone automatycznie”, bo inaczej „Anuluj” od razu pytałby o porzucenie wyboru.
- **Długość 5/10 min z siatki dotyczy też mieszanki, pomyłek i par**, gdy startują z kafelka. Prośba z Dzisiaj lub z deep linku nadal używa swojej długości albo długości z profilu.
- **Zgrupowanie dotyczy tylko „Dodaj słowo” i skanowania.** Dodawanie całego tematu (`addTopicEntries`) nie dokleja przykładów do znaczenia, które użytkownik już ma z innego tematu. Pomija je jak dotąd, a postęp jest zachowany.

## 4. Ryzyka kompilacji (do sprawdzenia w Xcode)

1. `SenseGrouping.swift:38`: funkcje lokalne `root` / `join` modyfikują przechwyconą tablicę `parent` (union-find). To dozwolone, ale warto potwierdzić.
2. `SenseGrouping.swift:164–170`: `switch` po `SpokenFrequency?` z wzorcami `.veryCommon` … `case nil`.
3. `SenseGrouping.swift:200`: warunek `where` z mutującym `translationKeys.insert(...).inserted`.
4. `ReadingHighlighting.swift:252`, `:269`: `piece[AttributeScopes.SwiftUIAttributes.FontAttribute.self] = Font`.
5. `StudyExerciseTypesCard.swift:104`: `Section { } header: { }` wewnątrz `LazyVGrid` w `ForEach`.
6. `StudyExerciseTypesCard.swift:167`: `private let shape` w widoku z inicjalizatorem memberwise. Stała z wartością nie wchodzi do memberwise init.
7. `StudyExerciseTypesCard.swift:199`: wzorce `.activity(.singleType)` bez wiązania wartości powiązanej.
8. `StudyExerciseCatalog.swift:81`: `SingleTypeSession.types.map { … } + [.pictures]` w `static let`.
9. `StudyHomeView.swift:391`: `if case .vocabulary = activity, … == nil`.
10. Testy: `StudyLayoutTests.swift:190` używa subskryptu `run[AttributeScopes.SwiftUIAttributes.FontAttribute.self]` na `AttributedString.Runs.Run`.

## 5. Testy

- FluentKit `SenseGroupingTests` (nowy):
  - *catch up*: 4 wpisy dają 2 wiersze, wpis główny to core, przykłady bez powtórzeń, `mergedContentRefs`.
  - *weigh* (wzajemne `acceptedTranslations`) jest łączone.
  - *mouse*, jednostronna akceptacja i inna część mowy nie są łączone.
  - `definitionSimilarity`.
  - Dodanie grupy daje 1 znaczenie z 4 przykładami, a wszystkie odwołania są „dodane” i posiadane.
  - Kodowanie i dekodowanie `mergedContentRefs`, stare dane bez pola.
- FluentKit `FreshStartTests`:
  - świeża codzienna mieszanka nie powtarza zdań przerwanej sesji i nie zmienia zapisanych słów;
  - bez przerwanej sesji wynik jest taki sam jak `makeSession`;
  - `VocabularyModeAvailability`: archiwum, kolekcja, trudne słowa, pary.
- Aplikacja `StudyLayoutTests`:
  - dwie warstwy czytanki: te same znaki i kroje, brak podkreśleń, tło tylko na dowodzie;
  - 3 rodzaje wyróżnień i legenda;
  - `activity(for:)`;
  - każde zajęcie występuje w siatce dokładnie raz, a kafelek „W budowie” zostaje;
  - okno wznowienia dla trybu pomyłek;
  - dostępność liczona tylko dla kafelków słownictwa.
- Aplikacja `FeaturePureFunctionTests`: „Masz już” po zgrupowanym odwołaniu, unikalne tłumaczenia kandydatów.
- Nie uruchomiłem żadnego testu Swift, bo na Windows nie ma kompilatora. Uruchomiłem tylko kontrolę struktury plików, skan treści dla reguły grupowania i obliczenia kontrastu w Node.

## 6. Do sprawdzenia w symulatorze

1. **Czytanka**, jasny i ciemny motyw:
   - trzy rodzaje słów są czytelne i odróżnialne, bez podkreśleń i teł;
   - legenda jest pod tytułem;
   - dotknięcie słowa otwiera arkusz;
   - obie warstwy łamią się identycznie, także przy Dynamic Type xxxLarge i AX3;
   - marker dowodu jest widoczny na etapie wyników.
2. **Nauka**:
   - jedna karta „Ćwiczenia” z 3 nagłówkami grup;
   - dotknięcie kafelka mieszanki, pomyłek albo par startuje sesję;
   - przerwanie, a potem dotknięcie tego samego kafelka pokazuje okno „Kontynuuj / Zacznij od nowa”, a „Zacznij od nowa” daje inne zdania;
   - kafelek bez słów (np. Tryb pomyłek na świeżym koncie) pokazuje „Brak słów…” i wyjaśnienie nad siatką;
   - „W budowie” i „Przerwane” są na miejscu;
   - Fiszki są na górze, Test pod siatką.
3. **Dzisiaj → „Zaczynam naukę”**: startuje codzienna mieszanka, a gdy jakaś jest przerwana, pojawia się okno wyboru.
4. **„Dodaj słowo” → *catch up***:
   - widać 2 wiersze („nadrobić zaległości” z liczbą przykładów oraz „dogonić”);
   - po dodaniu słowo ma wszystkie przykłady;
   - w „Szukaj tematu” wpisy *catch up* z innych tematów są wyszarzone jako „Masz już”.
5. To samo przez skanowanie tekstu (z arkusza i z paska Słownika).
6. Synchronizacja i eksport JSON: znaczenie z `mergedContentRefs` przechodzi przez eksport, import i drugie urządzenie.

## 7. Prośby do innych ról

- **design-shell:** nowe role `readingGlossaryInk`, `readingRecommendedInk` i `readingOwnInk` dopisałem do `Palette`. Warto dodać je do `DesignSystemGallery` i do tabeli w `DESIGN.md` §2.
- **core-engine / dokumentacja:** `CONTRACTS.md` / `CONTENT-SCHEMA.md` mogą wspomnieć `Meaning.mergedContentRefs` (dodatek iOS, ignorowany przez stronę).
