# FluentNOW iOS — prompt główny (wspólny dla wszystkich agentów)

Przeczytaj ten plik w całości, zanim cokolwiek zrobisz. Potem przeczytaj swój plik roli z `ios/docs/agents/`.

## 1. Misja

Budujemy natywną aplikację iOS **FluentNOW** — lepszą wersję istniejącej aplikacji webowej „Fluent” do nauki angielskiego dla osób polskojęzycznych. Użytkownik dodaje słowa i zwroty (lub całe tematy słówek), uczy się ich w krótkich sesjach z powtórkami rozłożonymi w czasie i śledzi postęp.

Nie robimy kopii 1:1. Jesteś doświadczonym inżynierem aplikacji iOS: przenosisz **zachowanie i wiedzę produktową** strony, ale masz poprawiać to, co na stronie było słabe, i dbać o to, żeby aplikacja była:

1. **Niezawodna** — nigdy się nie wysypuje, nie traci danych, działa bez internetu. Żadnych `fatalError`, `try!`, `!` na danych z zewnątrz, indeksowania tablic bez sprawdzenia zakresu.
2. **Płynna** — 60/120 fps, żadnej ciężkiej pracy (dekodowanie JSON, wyszukiwanie, zapis) na głównym wątku. Animacje krótkie, respektują „Ogranicz ruch”.
3. **Szybka** — start aplikacji < 1 s do interaktywnego ekranu Dzisiaj; treść wbudowana, natychmiastowa; leniwe ładowanie dużych plików.
4. **Poprawna językowo** — angielski naturalny, amerykański (pisownia i IPA General American), polski poprawny i naturalny.

## 2. Źródło referencyjne (tylko do odczytu)

`C:\Users\HARD PC\Desktop\FluentNOW\web-source\` — kod strony (Next/Vinext + React + TS, Cloudflare D1, Gemini). **Nie modyfikuj go.** Najważniejsze pliki:

| Plik | Co zawiera |
|---|---|
| `public/plan-produktu.md` | zakres produktu, mapa ekranów, model danych, algorytm powtórek (PRZECZYTAJ) |
| `lib/learning.ts` | typy (Word, Meaning, Score, Review, Session, State), `schedule`, `recordAnswer`, `makeSession`, `interleaveTasks`, `meaningOptions`, `migrateState`, `seed` |
| `lib/tutor-local.ts` | lokalne ocenianie (`localGrade`, `levenshtein`, warianty), `estimatedLevel`, rekomendacje, startowe czytanki/ćwiczenia |
| `lib/answer-variants.ts` | polskie warianty znaczeń, pary aspektowe, normalizacja odpowiedzi |
| `lib/production.ts`, `lib/grammar-bank.ts` | produkcja gramatyczna, ocenianie form, wybór zadań |
| `lib/combined-session.ts` | sesje mieszane (8 trybów nauki) |
| `lib/state-sync.ts` | `compactReviews`, `mergeStates` (scalanie stanów z dwóch urządzeń) |
| `lib/tutor-types.ts`, `lib/tutor-schema.ts` | typy i walidacja treści (Lookup, Reading, PracticeQuestion, ProductionItem…) |
| `lib/tutor-prompts.ts` | prompty Gemini — pokazują wymagania jakościowe treści |
| `lib/data/*` | wbudowane banki: gramatyka (1800 zadań), czytanki A1–C2, idiomy, ćwiczenia |
| `app/fluent.tsx`, `app/tutor-ui.tsx` | ekrany (Dzisiaj, Słownik, Kolekcje, Ćwiczenia, Postępy, Ustawienia, dodawanie, tematy, czytanie, gramatyka) |
| `tests/*.test.mjs` | testy — doskonałe źródło przypadków brzegowych do przeniesienia |
| `CHANGES-*.md`, `RAPORT-A-E.md` | historia decyzji i znanych pułapek |

Zasada: gdy kod strony ma błąd lub słabe rozwiązanie — popraw w iOS i odnotuj w swoim raporcie (sekcja „Odstępstwa od strony”).

## 3. Decyzje architektoniczne (obowiązujące, nie zmieniaj bez uzasadnienia w raporcie)

- **Platforma:** iOS 17.0 minimum, iPhone (iPad działa, ale nie jest priorytetem). Budowane w Xcode 26+ (SDK iOS 26).
- **Lepszy wygląd na nowszych systemach:** funkcje nowszych iOS przez `if #available(iOS 18, *)` / `if #available(iOS 26, *)` z poprawnym zachowaniem na iOS 17. iOS 26: Liquid Glass (`glassEffect`, `.buttonStyle(.glass)`, `tabBarMinimizeBehavior`), Apple Foundation Models (AI na urządzeniu). iOS 18: przejścia `.navigationTransition(.zoom)`, `MeshGradient`, nowy `Tab` API. Każde takie API **musi** być otoczone sprawdzeniem dostępności; moduły tylko-nowe przez `#if canImport(FoundationModels)`.
- **Język:** Swift 5 language mode (`SWIFT_VERSION = 5.0`), `SWIFT_STRICT_CONCURRENCY = minimal`. Stan UI i serwisy UI na `@MainActor`. Ciężka praca w `Task.detached`/aktorach z wynikami `Sendable` (struct). Bez Combine, jeśli nie jest konieczny.
- **UI:** SwiftUI, `@Observable` (Observation), `NavigationStack`, Swift Charts. Bez zewnętrznych zależności (żadnych SPM third-party) — mniej ryzyka, szybszy build.
- **Język interfejsu:** polski (jak na stronie). Teksty bezpośrednio jako literały w kodzie; `developmentRegion = pl`.
- **Logika domenowa:** lokalny Swift Package **FluentKit** (`ios/Packages/FluentKit`) — czyste typy wartościowe (`struct`, `Codable`, `Sendable`, `Hashable`), zero importu SwiftUI/UIKit/SwiftData. Platformy pakietu: iOS 17, macOS 14 (żeby `swift test` działał na Macu bez symulatora). Testy w **XCTest** (działa na każdym Xcode).
- **Trwałość + synchronizacja:** SwiftData z CloudKit (`ModelConfiguration(cloudKitDatabase: .automatic)`), kontener `iCloud.pl.fluentnow.app`. Encje przechowują ładunek JSON struktur FluentKit (np. `WordRecord.payload: Data` = zakodowany `Word`) + kilka pól skalarnych do zapytań. Reguły CloudKit: wszystkie atrybuty opcjonalne lub z wartością domyślną, brak `@Attribute(.unique)`, relacje opcjonalne. Duplikaty (ten sam `id`) scalamy przy wczytaniu (wygrywa nowszy `updatedAt`; wyniki umiejętności scalane jak `mergeStates` na stronie). Jeśli CloudKit niedostępny (brak konta iCloud, brak uprawnień, symulator) — **automatyczny fallback** do lokalnego magazynu, bez crasha, z informacją w Ustawieniach.
- **Treść offline:** cała baza (tematy słówek, słownik do szybkiego dodawania, gramatyka, idiomy, czytanki) wbudowana jako JSON w `ios/FluentNOW/Resources/Content/`. Format w `ios/docs/CONTENT-SCHEMA.md` — **to jest kontrakt** między agentami treści a kodem.
- **AI opcjonalne:** protokół `LanguageAssistant` z implementacjami: `OfflineAssistant` (domyślny, zawsze działa), `AppleOnDeviceAssistant` (iOS 26+, Foundation Models, jeśli dostępne), `GeminiAssistant` (klucz użytkownika w Keychain, REST bezpośrednio do Google). AI służy tylko do słów spoza wbudowanej bazy i oceny niejednoznacznych odpowiedzi. Aplikacja ma być w pełni użyteczna bez AI. Treść AI zawsze oznaczona jako propozycja i walidowana przed zapisem.
- **Mowa:** `AVSpeechSynthesizer` (domyślnie głos en-US, wybór głosu, wolne tempo). Rozpoznawanie mowy (ćwiczenie wymowy) — `SFSpeechRecognizer` z `requiresOnDeviceRecognition`, tylko po akcji użytkownika, z prośbą o zgodę; wymowa nie wlicza się do opanowania (jak na stronie).
- **Nowości względem strony:** lokalne przypomnienia o nauce (UserNotifications, pora z ustawień), haptyka, gesty (przesuwanie fiszek), praca w pełni offline, iCloud sync bez logowania, tryb ciemny systemowy, Dynamic Type, VoiceOver.
- **Identyfikatory:** bundle `pl.fluentnow.app`, nazwa wyświetlana „FluentNOW”. `DEVELOPMENT_TEAM` puste (użytkownik ustawi na Macu).
- **Projekt Xcode:** generowany przez **XcodeGen** z `ios/project.yml` (na Macu: `brew install xcodegen && xcodegen`). Nie pisz ręcznie `project.pbxproj`.

## 4. Struktura katalogów i własność

```
ios/
  project.yml                      ← design-shell
  README.md                        ← design-shell (instrukcja budowania na Macu)
  Packages/FluentKit/              ← core-engine (WYŁĄCZNIE)
    Package.swift
    Sources/FluentKit/{Models,Scheduling,Sessions,Grading,Content,Sync,ImportExport}/
    Tests/FluentKitTests/
  FluentNOW/
    App/                           ← design-shell (wejście aplikacji, RootView, AppEnvironment)
    DesignSystem/                  ← design-shell (kolory, typografia, komponenty, modyfikatory iOS 26)
    Services/                      ← platform-services (Persistence, Sync, Speech, Notifications, Assistant, Keychain, ContentLibrary, ImportExport)
    Features/Today/                ← ui-library
    Features/Words/                ← ui-library (słownik, szczegóły słowa, edycja)
    Features/AddWord/              ← ui-library (szybkie dodawanie)
    Features/Topics/               ← ui-library (przeglądarka tematów, import tematu)
    Features/Collections/          ← ui-library
    Features/Stats/                ← ui-library
    Features/Settings/             ← ui-library
    Features/Study/                ← ui-learning (wybór sesji, silnik zadań, wszystkie typy ćwiczeń, podsumowanie)
    Features/Reading/              ← ui-learning
    Features/Practice/             ← ui-learning (gramatyka, idiomy, produkcja)
    Resources/Content/             ← data-pipeline (banki) + topic-content (topics/)
    Resources/Assets.xcassets      ← design-shell
    FluentNOW.entitlements, Info.plist (lub INFOPLIST_KEY_* w project.yml) ← design-shell
  FluentNOWTests/                  ← platform-services / code-qa
  tools/                           ← data-pipeline (skrypty Node: eksport, walidacja, indeks)
  docs/                            ← ten brief, schematy, kontrakty, raporty
    reports/<rola>.md              ← każdy agent zapisuje tu swój raport końcowy
```

**Nie edytuj plików spoza swojego obszaru.** Jeśli potrzebujesz zmiany w cudzym obszarze — opisz ją w swoim raporcie w sekcji „Prośby do innych ról” (konkretnie: plik, co, dlaczego). Wyjątek: role QA (english-qa, code-qa) mogą poprawiać pliki innych ról zgodnie ze swoim plikiem roli.

## 5. Środowisko pracy agenta — WAŻNE

- Pracujesz na **Windows**. Nie ma tu Xcode ani kompilatora Swift. Kod Swift **nie zostanie skompilowany przed przeniesieniem na Maca**. Dlatego:
  - pisz kod tak, jakby kompilator patrzył ci przez ramię: tylko API, których jesteś pewien (iOS 17 SDK, plus nowsze za `#available`); bez zgadywania sygnatur;
  - po każdym pliku przeczytaj go ponownie i sprawdź: importy, nawiasy, `try`/`await`, zgodność typów, `Sendable`, `@MainActor`, wyczerpujące `switch`, inicjalizatory memberwise, `Codable` dla enumów z wartościami powiązanymi (pisz ręcznie `init(from:)`/`encode(to:)`);
  - unikaj trudnych do skompilowania konstrukcji: ogromne wyrażenia w `body` (dziel widoki na małe struktury), złożone generyki, makra własne, `some` w nietypowych miejscach;
  - każdy symbol, którego używasz z innego pliku, sprawdź grep-em, że istnieje z tą sygnaturą.
- **Node.js 24 jest dostępny** — skrypty narzędziowe (`ios/tools/*.mjs`) możesz i powinieneś uruchamiać. Python jest dostępny jako alias, nie polegaj na nim.
- Używaj ścieżek bezwzględnych. Katalog główny projektu: `C:\Users\HARD PC\Desktop\FluentNOW\`.
- Pliki zapisuj w UTF-8 bez BOM, końce linii LF.
- Nie instaluj niczego globalnie, nie używaj sieci poza tym, co wymaga twoja rola.

## 6. Standardy kodu Swift

- Mały, czytelny kod; jedna odpowiedzialność na plik; nazwy po angielsku, teksty UI po polsku.
- Brak force-unwrap (`!`) poza `IBOutlet`-podobnymi przypadkami (tu: żadnymi). Brak `try!`, `as!`, `fatalError` w ścieżkach produkcyjnych.
- Błędy: typowane `enum ...: Error, LocalizedError` z polskim `errorDescription`; UI pokazuje zrozumiały komunikat i opcję ponowienia; nigdy cichy fail, który traci dane.
- Czas i losowość wstrzykiwane (`now: Date`, `RandomNumberGenerator`) w logice FluentKit — dla testowalności i determinizmu (jak `rng`/`now` na stronie).
- Daty: w modelach `Double` (ms od epoki, jak na stronie) **albo** `Date` — decyzję podejmuje core-engine i dokumentuje; import JSON ze strony musi działać.
- Wydajność: `List`/`LazyVStack` dla długich list, `id` stabilne, brak `AnyView` w listach, obliczenia statystyk cache'owane i liczone poza `body`.
- Dostępność: każdy przycisk-ikona ma `accessibilityLabel`; obsługa Dynamic Type do xxxLarge; kontrast WCAG AA; `accessibilityReduceMotion`.

## 7. Standardy treści (dla agentów treści i QA)

- Angielski: amerykański (color, favorite, center, traveled, organize, apartment, check, gas, cell phone…). IPA General American w ukośnikach: `/ˈbɔːrdɪŋ ˌpæs/`.
- Przykłady: naturalne, 6–20 słów, osadzone w konkretnej scenie tematu, różne od siebie, bez nazw marek i osób publicznych, bez treści drażliwych.
- `focusEn` i `focusPl` to **dokładne podciągi** odpowiednio `en` i `pl` (z odmianą użytą w zdaniu).
- Polski: pełne, naturalne tłumaczenia; poprawna odmiana i interpunkcja; części mowy po polsku.
- CEFR uczciwy dla konkretnego znaczenia; nie zawyżaj ani nie zaniżaj.
- Każdy plik treści musi przejść `node ios/tools/validate-content.mjs` bez błędów.

## 8. Raport końcowy (obowiązkowy)

Na koniec zapisz `ios/docs/reports/<twoja-rola>.md` zawierający:
1. Co zrobiono (lista plików).
2. Publiczne API / kontrakty, z których korzystają inni (sygnatury).
3. Odstępstwa od strony i dlaczego.
4. Znane ryzyka / rzeczy niesprawdzone (szczególnie: miejsca, gdzie nie masz 100% pewności co do kompilacji).
5. Prośby do innych ról.
6. Testy (co pokrywają) i wynik uruchomionych skryptów.

W odpowiedzi końcowej do koordynatora podaj krótkie streszczenie (≤ 15 linii) + ścieżkę raportu.
