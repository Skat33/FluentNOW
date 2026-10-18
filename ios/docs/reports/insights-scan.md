# Raport: insights-scan (FEEDBACK-4 · I3)

Raport tygodniowy + skanowanie tekstu aparatem. Kod niekompilowany (Windows) — sygnatury sprawdzone grepem, API VisionKit sprawdzone w dokumentacji Apple (JSON dokumentacji przez WebFetch).

## 1. Co zrobiono (pliki)

### Raport tygodniowy
| Plik | Zmiana |
|---|---|
| `Packages/FluentKit/Sources/FluentKit/Statistics/WeeklyReport.swift` | **nowy** — `WeeklyReport`, `WeeklyPeriodStats`, `WeeklySkillTrend`, `WeeklyTrend`, `WeeklyHardWord`, `WeeklyReportBuilder`, `WeeklyReportText` |
| `Packages/FluentKit/Tests/FluentKitTests/WeeklyReportTests.swift` | **nowy** — 9 testów |
| `FluentNOW/Features/Stats/WeeklyReportScreen.swift` | **nowy** — `StatsRoute`, `.statsNavigationDestinations()`, `WeeklyReportScreen(initialOffset:)` (liczenie przez `store.compute`) |
| `FluentNOW/Features/Stats/WeeklyReportSections.swift` | **nowy** — nagłówek z wyborem tygodnia (strzałki, do 12 tygodni), kafelki, umiejętności z trendem, najtrudniejsze słowa + „Powtórz je” (→ `router.startStudy(.mistakes)`), przypis, wejście `StatsWeeklyReportEntry` |
| `FluentNOW/Features/Stats/StatsRootScreen.swift` | 2 wiersze: `.statsNavigationDestinations()` i karta-wejście `StatsWeeklyReportEntry()` pod kafelkami |
| `FluentNOW/Features/Today/TodayWeeklyReportCard.swift` | **nowy** — samodzielna karta (niedziela: bieżący tydzień, poniedziałek: miniony; inne dni nic); „Zobacz raport” → `router.popToRoot(.progress)` + `router.push(StatsRoute.weeklyReport(weekOffset:), on: .progress)` |
| `FluentNOW/Features/Today/TodayRootScreen.swift` | 1 wiersz w `TodayContent`: `TodayWeeklyReportCard()` po `TodayXPCard` (blok ma 9 widoków ≤ 10) |
| `FluentNOW/Services/Reminders/ReminderService.swift` | `scheduleWeeklyReport(enabled:)` (powtarzalny `UNCalendarNotificationTrigger`, niedziela 20:00, deep link `fluentnow://progress`), `weeklyReportComponents()`, stałe; `cancelAll()` usuwa też to powiadomienie |
| `FluentNOW/Features/Settings/SettingsWeeklyReportToggle.swift` | **nowy** — przełącznik opt-in (`@AppStorage("fluent.weeklyReportEnabled")`, prośba o zgodę, alert przy odmowie) |
| `FluentNOW/Features/Settings/SettingsSections.swift` | 1 wiersz w `SettingsLearningSection`: `SettingsWeeklyReportToggle()` (obok wiersza fsrs `SettingsRetentionPicker()`) |

### Skanowanie tekstu
| Plik | Zmiana |
|---|---|
| `FluentNOW/Features/Scan/TextScanAnalysis.swift` | **nowy** — `ScannedWord`, `ScannedWordStatus`, `TextScanAnalyzer` (NLTagger `.lemma`, en), `TextScanClassifier` („Masz już” przez `OwnedVocabulary.containsTerm`, „W bazie” = trafienie `.exact` w `ContentLibrary.search`) |
| `FluentNOW/Features/Scan/PhotoTextRecognizer.swift` | **nowy** — Vision `VNRecognizeTextRequest` (accurate → fallback fast), miniatura ImageIO z orientacją EXIF, `Task.detached` |
| `FluentNOW/Features/Scan/LiveTextScannerView.swift` | **nowy** — `UIViewControllerRepresentable` dla `DataScannerViewController`, `LiveTextScannerCoordinator` (`@MainActor`, delegat), `LiveScanAvailability` (isSupported / zgoda AVFoundation / isAvailable) |
| `FluentNOW/Features/Scan/ScanTextScreen.swift` | **nowy** — ekran „Skanuj tekst” (własny `NavigationStack`): aparat lub komunikat, „Wybierz zdjęcie z tekstem” (`PhotosPicker`), lista słów |
| `FluentNOW/Features/Scan/ScanToolbarButton.swift` | **nowy** — przycisk w pasku Słownika; po wyborze słowa otwiera `router.presentQuickAdd(prefill:)` dopiero w `onDismiss` arkusza skanera |
| `FluentNOW/Features/AddWord/AddWordScanSection.swift` | **nowy** — wiersz „Skanuj tekst” w szybkim dodawaniu; wybrane słowo trafia do pola wyszukiwania |
| `FluentNOW/Features/AddWord/AddWordRootScreen.swift` | 1 wiersz w `form`: `AddWordScanSection { (term: String) in query = term }` |
| `FluentNOW/Features/Words/WordsRootScreen.swift` | 1 `ToolbarItem(placement: .topBarTrailing) { ScanToolbarButton() }` (nie `.secondaryAction` — w menu przepełnienia `.sheet` by nie działał) |
| `ios/project.yml` | `INFOPLIST_KEY_NSCameraUsageDescription` po polsku. `NSPhotoLibraryUsageDescription` **niepotrzebny** — `PhotosPicker` działa poza procesem aplikacji i zwraca tylko wybrane zdjęcie |

## 2. Publiczne API (FluentKit)

```swift
public enum WeeklyTrend: String, Sendable, Hashable { case up, down, steady, new, none }
public struct WeeklySkillTrend { skill, answers, accuracy: Int?, previousAnswers, previousAccuracy: Int?, trend; var change: Int? }
public struct WeeklyHardWord { wordId, term, translation, mistakes, answers, mastery }
public struct WeeklyPeriodStats { answers, correct, studySeconds, newMeanings, addedWords, masteredMeanings, activeDays, readings, practiceSets, xp
                                  var accuracy: Int?; var studyMinutes: Int; var hasActivity: Bool }
public struct WeeklyReport { weekOffset, start, end, isCurrentWeek, elapsedDays, current, previous, days: [DayActivity], streak,
                             levelStart: XPLevel, levelEnd: XPLevel, skills, hardestWords, summaryPl
                             var levelsGained, lastDay, strongestSkill, weakestSkill }
public enum WeeklyReportBuilder {
    static let maxWeeksBack = 12, hardWordLimit = 5, trendThreshold = 5, minimumSkillAnswers = 5 …
    static func weekStart(containing: Date, calendar: Calendar) -> Date
    static func todayCardWeekOffset(now: Timestamp, calendar: Calendar = .current) -> Int?   // nd → 0, pn → 1
    static func availableWeeks(_ state: LearnerState, now: Timestamp, calendar: Calendar = .current) -> Int
    static func report(_ state: LearnerState, weekOffset: Int = 0, now: Timestamp, calendar: Calendar = .current) -> WeeklyReport
}
public enum WeeklyReportText { plural, answers, days, meanings, minutes, summary(_:) }
```
Aplikacja: `StatsRoute.weeklyReport(weekOffset:)`, `ReminderService.scheduleWeeklyReport(enabled:)`, `ScanTextScreen(text: Binding<String>, onPick: (String) -> Void)`.

## 3. Decyzje i odstępstwa

- **Tydzień = poniedziałek–niedziela w kalendarzu użytkownika** (wstrzykiwany `Calendar`, strefa czasowa urządzenia), liczony ręcznie z `weekday` — niezależnie od `firstWeekday` (test z kalendarzem „od niedzieli”). „Ostatnie 7 dni vs poprzednie 7” zrealizowane jako bieżący tydzień kalendarzowy vs poprzedni; dla tygodnia w toku podsumowanie nie ogłasza spadku („Tydzień jeszcze trwa — do wyniku z poprzedniego brakuje …”).
- **XP tygodnia** = XP całej historii przed końcem tygodnia − przed początkiem (`Progression.totalXP` na przyciętym stanie). `Progression` liczy dni w UTC, więc premia dnia z okolic północy może trafić do sąsiedniego tygodnia — świadome przybliżenie (bez zmiany `Progression`, którego nie jestem właścicielem).
- **Czas nauki — szacunek**: odpowiedź ćwiczenia = zmierzone sekundy, maks. 90 s (8 s gdy brak); czytanka 120 s + 30 s/pytanie (pytania z czytania nie liczone podwójnie); zestaw gramatyki/produkcji 25 s/zadanie. Ekran mówi „szacunek”.
- **Nowe znaczenia** = pierwsza odpowiedź w tygodniu; znaczenia, których liczniki `Score.correct+wrong` przekraczają liczbę zapisanych odpowiedzi (stara historia skompaktowana po 90 dniach), nie są liczone jako nowe.
- **Opanowane w tygodniu** = `ProgressStatistics.masteryGains` (przejście < 85% → ≥ 85%).
- **Trend umiejętności** ze skuteczności odpowiedzi (nie z bieżących wyników, których nie da się odtworzyć wstecz); `.up/.down` przy zmianie ≥ 5 pkt i ≥ 5 odpowiedziach w obu tygodniach, inaczej `.steady`.
- **Najtrudniejsze słowa**: najwięcej błędnych odpowiedzi lub odpowiedzi z podpowiedzią w tygodniu (bez archiwalnych). „Powtórz je” uruchamia istniejący tryb pomyłek — `StudyLaunchRequest` nie ma listy słów, więc sesja nie jest zawężona dokładnie do tych słów (patrz prośby).
- **Podsumowanie po polsku**: czas teraźniejszy i rzeczowniki (bez form rodzajowych „uczyłeś/aś”), 2–4 zdania, bez superlatyw.
- **Powiadomienie**: jeden powtarzalny wyzwalacz (nd 20:00), osobny identyfikator `fluent.weekly-report` — `reschedule` codziennych go nie rusza; „Usuń wszystkie dane” → `cancelAll()` usuwa, a `resetToDefaults()` czyści klucz `fluent.weeklyReportEnabled` (prefiks `fluent.`).
- **Karta na Dzisiaj** jest samodzielna (własne `store.compute`), `TodaySnapshot` bez zmian. Sprawdzenie dnia jest synchroniczne; widok-ładowacz zawsze coś rysuje (szkielet), żeby `.task` wystartował.
- **Skaner**: dotknięcie elementu w podglądzie daje linię/blok tekstu (taka jest granulacja VisionKit) — jedno słowo → od razu szybkie dodawanie; linia → jej słowa trafiają na listę. „Użyj całego kadru” bierze wszystkie widoczne teksty. Pomijane są słowa funkcyjne (the, a, is, of…), liczby i symbole; maks. 300 słów. Lista: „W bazie” → „Spoza bazy” → „Masz już” (wyszarzone, `OwnedVocabularyBadge`). Rozpoznany tekst zostaje w pamięci przycisku, więc po dodaniu słowa można wrócić do listy (w szybkim dodawaniu: „Wróć do zeskanowanego tekstu”).
- Logika skanowania jest w aplikacji (`Features/Scan/`), nie w FluentKit — mój obszar FluentKit to tylko `Statistics/`; dlatego bez testów jednostkowych (patrz ryzyka).

## 4. Ryzyka kompilacji (miejsca do sprawdzenia w Xcode)

1. `LiveTextScannerView.swift` — `static func dismantleUIViewController(_:coordinator:)` dotyka `@MainActor` koordynatora; przy minimalnej kontroli współbieżności OK, przy ostrzejszej może wymagać `@MainActor` przy funkcji.
2. `LiveTextScannerCoordinator` — metody delegata napisane z etykietami z dokumentacji (`didTapOn`, `didAdd:allItems:`, `didUpdate:allItems:`, `didRemove:allItems:`, `becameUnavailableWithError: DataScannerViewController.ScanningUnavailable`). Literówka w etykiecie nie da błędu (domyślne implementacje), tylko metoda nie zostanie wywołana — sprawdź na iPhonie, że dotknięcie działa.
3. `ScanTextScreen.swift` — `ScanMessageCard<Action: View>` ma właściwość `@ViewBuilder let action: () -> Action` (inicjalizator memberwise z builderem).
4. `PhotoTextRecognizer.swift` — `request.results` typu `[VNRecognizedTextObservation]?` (iOS 15+); `CGImageSourceCreateThumbnailAtIndex` z `[CFString: Any] as CFDictionary`.
5. `TextScanAnalysis.swift` — domknięcie `enumerateTags` z jawnymi typami `(NLTag?, Range<String.Index>) -> Bool`; `await content.isSearchReady` (właściwość aktora).
6. `WeeklyReport.swift` — wewnętrzne użycie `ProgressionText.plural` i `Array.stableSorted` (internal w FluentKit). `Context.init` przypisuje wszystkie `let` przed końcem.
7. `WeeklyReportTests.swift` — `Review(... hint:, before:, after:, source:, demo:)` z pominięciem domyślnych `error/masteryVersion/weight`; `Score(value:interval:due:correct:wrong:last:)` (nowe pola FSRS fsrs mają wartości domyślne).
8. `SettingsWeeklyReportToggle` — `@AppStorage` w widoku w `Form`; alert przypięty do `Toggle`.

## 5. Co sprawdzić

**Symulator (iPhone 17 Pro / iOS 26.2)**
- `swift test` w `Packages/FluentKit` (nowe `WeeklyReportTests`).
- Postępy → „Raport tygodniowy”: strzałki tygodni (lewa nieaktywna, gdy brak starszej historii; prawa na bieżącym), liczby vs poprzedni tydzień, wykres dni od poniedziałku, „Powtórz je” przełącza na Naukę w trybie pomyłek, dotknięcie słowa → szczegóły.
- Dzisiaj w niedzielę/poniedziałek (zmień datę symulatora): karta raportu, „Zobacz raport” → karta Postępy z otwartym raportem; we wtorek karty brak.
- Ustawienia → „Raport tygodniowy”: zgoda, alert przy odmowie; w Xcode Debug → sprawdź oczekujące powiadomienie (lub tymczasowo zmień godzinę).
- „+” → „Skanuj tekst”: na symulatorze komunikat „nie obsługuje skanowania na żywo” + „Wybierz zdjęcie z tekstem” (zrób zrzut ekranu tekstu po angielsku i wybierz go). Lista: formy bazowe („went” → „go”), „Masz już” wyszarzone, „W bazie”; dotknięcie → pole szybkiego dodawania wypełnione. Słownik → ikona skanera w pasku → słowo otwiera szybkie dodawanie po zamknięciu skanera.
- Dynamic Type xxxLarge na ekranie raportu i liście skanu; tryb ciemny.

**iPhone (fizyczny)**
- Pierwsze uruchomienie skanera: przycisk „Włącz aparat” → systemowe pytanie z polskim opisem; odmowa → komunikat + „Otwórz Ustawienia systemu”.
- Podgląd z wyróżnianiem tekstu, dotknięcie pojedynczego słowa → od razu szybkie dodawanie; dotknięcie linii → słowa na liście; „Użyj całego kadru (n)”.
- Wyjście z arkusza zatrzymuje aparat (zielona kropka znika).
- Powiadomienie w niedzielę 20:00 → dotknięcie otwiera Postępy.

## 6. Prośby do innych ról

- **design-shell / App** (`App/DeepLink.swift`): link `fluentnow://progress/weekly` otwierający od razu raport (dziś powiadomienie otwiera kartę Postępy, z której raport jest pierwszą kartą pod kafelkami).
- **ui-learning / App** (`StudyLaunchRequest`, `StudyStarter`): opcjonalne `wordIDs: [String]?`, żeby „Powtórz je” w raporcie zawęziło sesję pomyłek dokładnie do najtrudniejszych słów tygodnia.
- **onboarding-progress** (`Progression`): po przejściu na dni lokalne XP tygodnia w raporcie będzie dokładne co do północy (formuła w `WeeklyReportBuilder.xpTotal` się nie zmienia).
- **code-qa**: testy jednostkowe `TextScanAnalyzer.tokens` / `normalizedLemma` w `FluentNOWTests` (np. „The children went to school.” → child, go, school).

## 7. Testy

`WeeklyReportTests` (XCTest, kalendarz Europe/Warsaw z `firstWeekday = 1`):
- tydzień od poniedziałku w czasie lokalnym, `elapsedDays`;
- dwie odpowiedzi tego samego dnia UTC trafiają do różnych tygodni lokalnych (dowód: nie UTC);
- liczby: odpowiedzi bez demo, podpowiedź ≠ poprawna, skuteczność, czas nauki (limit 90 s, czytanka, zestaw), aktywne dni;
- nowe znaczenia z regułą historii skompaktowanej, dodane słowa, opanowane;
- najtrudniejsze słowa (bez archiwalnych), trend umiejętności up/new/none, najlepsza umiejętność, podsumowanie wspomina słowo;
- progi trendu; seria na koniec minionego tygodnia, XP tygodnia i poprzedniego, `availableWeeks`, przycięcie offsetu;
- karta Dzisiaj (nd/pn/wt); teksty i odmiana („1 odpowiedź”, „22 odpowiedzi”, „5 dni”).

Nie uruchomiono (brak Swift na Windows). Nie uruchamiano poleceń git.
