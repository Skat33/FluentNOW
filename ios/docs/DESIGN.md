# FluentNOW — zasady projektowe (dla agentów UI)

Kod design systemu: `ios/FluentNOW/DesignSystem/`. Szkielet nawigacji: `ios/FluentNOW/App/`. Galeria wszystkich komponentów: `DesignSystemGallery` (podgląd + Ustawienia w zaślepce). **Nie twórz własnych kolorów, odstępów ani stylów przycisków** — jeśli czegoś brakuje, dopisz prośbę w raporcie (rola design-shell).

## 1. Tożsamość

Przenosimy charakter strony (`globals.css`, plan produktu §7): **chłodne, jasne tło, białe karty, atramentowy tekst, fiolet jako jedyny kolor głównej akcji, zieleń i bursztyn pomocniczo, fioletowa karta sesji z pierścieniem dziennego celu**. Na iOS podnosimy to do poziomu natywnego: Dynamic Type, systemowe gesty i arkusze, haptyka, Liquid Glass na iOS 26 dla warstwy nawigacji.

Ton tekstów: spokojny, zachęcający, konkretny, po polsku, bez wykrzykników w komunikatach systemowych, bez obwiniania („Nie tym razem”, nie „Błąd!”). Nagłówki zdaniem („Twój tydzień”, „Warto do nich wrócić”).

## 2. Kolor — `Palette`

Wszystkie kolory mają warianty jasny/ciemny i spełniają WCAG AA (tekst ≥ 4,5:1, grafika ≥ 3:1) — wartości sprawdzone skryptem. Używaj **ról**, nie hexów.

| Rola | Użycie |
|---|---|
| `background` | tło ekranu (każdy ekran; listy: `.scrollContentBackground(.hidden)` + `.background(Palette.background)`) |
| `surface` | karta treści |
| `surfaceElevated` | element nad kartą (wybrana opcja w segmencie, popover) |
| `surfaceMuted` | tor paska, tło segmentu, karta zagnieżdżona |
| `separator` | obrys karty, linie |
| `ink` / `inkSecondary` | tekst główny / pomocniczy |
| `inkTertiary` | **tylko** placeholdery i dekoracje (nie spełnia AA dla treści) |
| `accent` | fiolet jako tekst/ikona na powierzchni (linki, wybrane, wyróżnione słowo) |
| `accentFill` + `onAccent` | wypełnienie głównego przycisku / fioletowe karty + biały tekst |
| `accentSoft` + `accentSoftInk` | delikatne tło akcentu (wybrany chip, odznaka) + tekst na nim |
| `success`, `warning`, `danger`, `info` (+ `…Soft`) | stany: poprawnie, prawie/ostrzeżenie, błąd/niszczące, informacja |
| `heroStart/heroEnd/heroGlow`, `heroInkSecondary`, `heroRing*` | karta sesji (Dzisiaj, podsumowanie) |
| `chart[0…4]`, `chartColor(i)` | serie Swift Charts (kolejność jak `--chart-1…5` strony) |
| `collectionTone(named:)` | stały kolor kolekcji z nazwy (deterministyczny, nie `hashValue`) |
| `SkillTone.color` | 5 umiejętności (rozpoznawanie, przypominanie, pisownia, słuchanie, użycie) |
| `CEFRTone.tone(for:)` | poziomy: A zieleń, B niebieski, C bursztyn |

Zasady:
- **Jedna fioletowa akcja na ekran** (`PrimaryButton`). Reszta: `SecondaryButton`, przyciski tekstowe, pasek narzędzi.
- Kolor nigdy nie jest jedynym nośnikiem informacji: poprawność = kolor + ikona + tekst (`FeedbackPanel`), wybór = kolor + cecha `.isSelected`.
- Czerwień tylko dla błędów i akcji niszczących. Błędna odpowiedź w ćwiczeniu to `danger`, ale łagodnie (miękkie tło, nie pełne wypełnienie).
- `ToneColors` = para tekst/tło dla odznak i chipów: `.accent`, `.neutral`, `.success`, `.warning`, `.danger`, `.info`.
- `AccentColor` (asset) = `accent`; globalny `.tint(Palette.accent)` ustawia `RootView`. Asset `LaunchBackground` = `background` (ekran startu bez białego błysku w trybie ciemnym).
- Xcode generuje symbole zasobów (`Color.accent`, `Color.launchBackground`) — **nie dodawaj** rozszerzeń `Color` o tych nazwach.

## 3. Typografia — `FluentFont`

Wyłącznie style oparte o `Font.TextStyle` (Dynamic Type). Liczby: krój `.rounded` + cyfry stałej szerokości.

| Token | Styl | Użycie |
|---|---|---|
| `display` | largeTitle bold | „Mały krok za Tobą.”, powitanie |
| `heroTitle` | title bold | tytuł karty sesji |
| `title` | title3 semibold | nagłówek sekcji/karty (`SectionHeader`) |
| `headline` | headline semibold | tytuł wiersza, nagłówek panelu |
| `body` / `bodyEmphasized` | body | treść / hasło na liście |
| `callout`, `subheadline`, `footnote`, `caption` | — | opisy, metadane |
| `eyebrow` + `Text.fluentEyebrow()` | caption semibold, wersaliki, tracking | „SESJA NA DZIŚ” |
| `flashcardTerm` | largeTitle semibold | słowo w fiszce |
| `sentence` | title3 | zdanie w ćwiczeniu (`HighlightedText`) |
| `ipa` | callout | wymowa `/ˈbɔːrdɪŋ ˌpæs/` |
| `reading` | body serif | tekst czytanki (kolumna ≤ `Spacing.readableWidth`) |
| `numberLarge/Medium/Small` | rounded, monospacedDigit | pierścień, kafelki, procenty, licznik czasu |

Zasady: nie ustawiaj stałych rozmiarów punktowych dla tekstu; nie ograniczaj `lineLimit` w treści do nauki; przy rozmiarach dostępności układy poziome przechodzą w pionowe (`dynamicTypeSize.isAccessibilitySize` → `VStackLayout`, wzór w `ConfidencePicker`) lub `ViewThatFits`. Każdy ekran w `ScrollView`/`List`.

## 4. Siatka, promienie, cienie

- **Odstępy (`Spacing`)**: `xxs 4`, `xs 8`, `s 12`, `m 16`, `l 24`, `xl 32`, `xxl 48`. Margines ekranu `screen = 16`. Wewnątrz karty `m`, między wierszami karty `s`, między sekcjami ekranu `l`.
- **Promienie (`Radius`, zawsze `.continuous`)**: `badge 6`, `small 10`, `medium 14` (przyciski iOS 17–25, kafelki w kartach), `card 20`, `hero 28`.
- **Obszar dotyku**: min. `HitTarget.minimum = 44`; główny przycisk `buttonHeight = 50`.
- **Cienie (`.fluentShadow`)**: `.card` (bardzo delikatny, fioletowawy jak na stronie), `.raised` (przeciągana fiszka, karta hero), `.flat`. W trybie ciemnym separację daje kolor powierzchni + obrys.
- **iPad / poziomo**: treść czytana w kolumnie `frame(maxWidth: Spacing.readableWidth)`; siatki `LazyVGrid(.adaptive(minimum: 150))`.

## 5. Komponenty (sygnatury i przykłady)

```swift
// Przyciski (iOS 26: .glassProminent / .glass; iOS 17–25: własne style)
PrimaryButton("Zaczynam naukę", systemImage: "play.fill") { router.startStudy() }
PrimaryButton("Zapisz", isLoading: isSaving, fillsWidth: false) { save() }
SecondaryButton("Pokaż podpowiedź", systemImage: "lightbulb") { showHint() }
SecondaryButton("Usuń kolekcję", systemImage: "trash", role: .destructive) { confirmDelete = true }
Button("Sprawdź") { check() }.fluentButtonStyle(.primary)   // dla własnych etykiet

// Karta i nagłówek
Card { SectionHeader("Twój tydzień"); WeekChart(data) }
Card(style: .tinted(.accent)) { … }            // .solid (domyślnie) / .muted / .tinted(ToneColors) / .glass
SectionHeader("Twoje kolekcje", subtitle: "3 w toku", actionTitle: "Wszystkie") { router.openLibrary(.collections) }

// Statystyki i postęp
StatTile(title: "Powtórki na dziś", value: "\(due)", systemImage: "arrow.clockwise", caption: nil, tone: .accent)
ProgressRing(progress: ProgressMath.fraction(done, of: goal), lineWidth: 12, accessibilityLabel: "Dzienny cel") {
    VStack { Text("\(done)").font(FluentFont.numberLarge); Text("z \(goal) zadań").font(FluentFont.caption) }
}
LinearProgressBar(progress: Double(index) / Double(total))          // pasek sesji
SkillBar(skill: .recall, score: score)                              // score: Double? (0–100), nil → „—”
LevelBadge(level: word.level)                                       // "A1"…"C2"; puste → nic
TagChip("rzeczownik")                                               // etykieta
TagChip("Trudne", systemImage: "flame", isSelected: f.hard) { f.hard.toggle() }   // filtr

// Ćwiczenia
HighlightedText(example.en, focus: example.focusEn).font(FluentFont.sentence)
SpeakButton(isSpeaking: speech.isSpeaking) { speech.speak(word.en) }
SpeakButton(style: .slow, size: .small) { speech.speak(word.en, slow: true) }
ConfidencePicker(selection: $confidence)                            // ConfidenceLevel: .unsure(1) .fair(2) .sure(3)
FeedbackPanel(kind: .incorrect, message: "Poprawnie: **lend**", explanation: "…") { /* np. „Pokaż warianty” */ }

// Stany
EmptyStateView(systemImage: "text.book.closed", title: "Twój słownik jest pusty",
               message: "Dodaj pierwsze słowo lub cały temat.", actionTitle: "Przeglądaj tematy") { … }
LoadingStateView("Wczytywanie tematów…")
ErrorBanner(message: "Nie udało się zapisać zmian. Dane są bezpieczne na urządzeniu.",
            onRetry: { store.retry() }, onDismiss: { store.clearError() })

// Szkło i tła
view.fluentGlass(in: Capsule(), tint: Palette.accentFill, interactive: true)
FluentGlassContainer(spacing: 12) { HStack { … elementy ze szkłem … } }
view.fluentCardBackground(.solid)
HeroBackground()                                                     // MeshGradient (iOS 18+) / gradient (17)
```

Mapowanie z FluentKit (design system nie importuje FluentKit):
- `SkillTone(rawValue: skill.rawValue)` — te same klucze co `FluentKit.Skill`.
- `LevelBadge(level:)` przyjmuje `String` (jak `CEFR.levels`).
- `ConfidenceLevel.rawValue` → `confidence: Int` w algorytmie; `ConfidenceLevel(clamping:)` z danych.
- `FeedbackKind`: `.correct` / `.almost` (literówka, odpowiedź z podpowiedzią, „uncertain”) / `.incorrect` / `.info`.
- Tryby sesji w `StudyLaunchRequest.modes` to surowe wartości `FluentKit.StudyMode` (`"mixed"`, `"language-mix"`…).

## 6. Liquid Glass i nowsze systemy

Zweryfikowane w dokumentacji Apple (SDK iOS 26): `glassEffect(_:in:)`, `Glass.regular.tint(_:).interactive(_:)`, `GlassEffectContainer(spacing:)`, `.buttonStyle(.glass / .glassProminent)`, `tabBarMinimizeBehavior(.onScrollDown)`; iOS 18: `Tab(value:content:label:)`, `.tabViewStyle(.sidebarAdaptable)`, `MeshGradient(width:height:points:colors:)`, `navigationTransition(.zoom(sourceID:in:))` + `matchedTransitionSource(id:in:)`.

Zasady:
- **Szkło = warstwa nawigacji i kontrolek unoszących się nad treścią** (pasek kart i paski narzędzi dostajemy od systemu za darmo; własne: pływający przycisk, odtwarzacz audio, kontrolki nad obrazem/gradientem). **Karty treści pozostają jednolite** (`.solid`) — tak zaleca HIG i tak jest czytelniej. Dlatego `fluentCardBackground()` domyślnie nie jest szkłem, a `.glass` jest opcją.
- Każde API nowsze niż iOS 17 wyłącznie przez gotowe modyfikatory design systemu albo za `if #available(iOS 18/26, *)` z równoważnym zachowaniem na iOS 17.
- Nie nakładaj szkła na szkło; grupuj sąsiednie elementy w `FluentGlassContainer`.
- Na iOS 26 nie dodawaj własnych teł pod paskami nawigacji/kart (system robi efekt krawędzi przewijania).
- Przejście lista → szczegół (iOS 18+): `.matchedTransitionSource(id:in:)` na komórce + `.navigationTransition(.zoom(sourceID:in:))` na celu, za `if #available(iOS 18, *)`.

## 7. Ruch — `Motion`

| Token | Czas | Kiedy |
|---|---|---|
| `Motion.tap` | snappy 0,18 s | naciśnięcie, zaznaczenie |
| `Motion.standard` | spring 0,3 s, bounce 0,12 | zmiana stanu w ekranie (rozwinięcie, feedback) |
| `Motion.emphasized` | spring 0,45 s, bounce 0,18 | przejście między zadaniami, pojawienie się karty |
| `Motion.progress` | smooth 0,8 s | pierścień, paski |
| `Motion.reducedFade` | easeInOut 0,2 s | zamiennik przy „Ogranicz ruch” |

- Zawsze respektuj „Ogranicz ruch”: `.fluentAnimation(Motion.standard, value: x)` (zamiast `.animation`), `withAnimation(Motion.resolved(Motion.emphasized, reduceMotion: reduceMotion)) { … }`, przejścia `Motion.contentTransition(reduceMotion:)` (przesunięcie → samo przenikanie).
- Liczby: `.contentTransition(.numericText())`. Ikony: `symbolEffect` tylko gdy `!reduceMotion`.
- Animacje nie blokują interakcji i nie opóźniają przejścia do następnego zadania (ui-learning: następne zadanie preładowane).
- Bez konfetti i animacji trwających > 1 s. Podsumowanie sesji: delikatne pojawienie się + haptyka sukcesu.

## 8. Haptyka — `FluentHaptic` (`.sensoryFeedback`, iOS 17)

| Zdarzenie | Haptyka |
|---|---|
| poprawna odpowiedź, zapis słowa/tematu, koniec sesji | `answerCorrect` (`.success`) |
| błędna odpowiedź | `answerIncorrect` (`.error`) |
| „prawie”, odpowiedź z podpowiedzią | `answerAlmost` (`.warning`) |
| wybór opcji, chip, segment, pewność | `selection` |
| przesunięcie fiszki poza próg | `swipeCommit` (impact medium 0,7) |
| dzienny cel osiągnięty | `goalReached` |
| potwierdzone usunięcie | `destructive` |

Deklaratywnie: `.sensoryFeedback(FluentHaptic.answerCorrect, trigger: answeredCount)`. `FeedbackPanel` sam wywołuje haptykę wyniku przy pojawieniu się (`playsHaptic: false`, jeśli ekran robi to sam). Nie wywołuj haptyki przy przewijaniu ani przy każdym naciśnięciu klawisza.

## 9. Wzorce ekranów

- **Lista → szczegół**: `List` (długie listy, akcje przesunięcia) lub `ScrollView` + `LazyVStack` (karty). Stabilne `id`. Wiersz: hasło (`bodyEmphasized`), tłumaczenie (`inkSecondary`), `LevelBadge`, opcjonalnie `SpeakButton(size: .small)`. Nawigacja przez trasy `Hashable` (`router.push(WordRoute.detail(id), on: .words)` lub `NavigationLink(value:)`) i `.navigationDestination(for:)` w korzeniu karty.
- **Tytuły**: korzeń karty — `.navigationTitle` duży (domyślny); szczegół — `.navigationBarTitleDisplayMode(.inline)`.
- **Arkusze (`.sheet`)**: formularze i krótkie zadania (szybkie dodawanie, edycja, filtry, import). Własny `NavigationStack`, „Anuluj” (`.cancellationAction`) i „Zapisz/Dodaj” (`.confirmationAction`, nieaktywne przy błędach). `presentationDetents([.medium, .large])` dla krótkich, `.large` dla edytorów. Przy niezapisanych zmianach `.interactiveDismissDisabled(hasChanges)` + pytanie przy „Anuluj”.
- **Sesja nauki**: `.fullScreenCover` (tryb skupienia, bez paska kart), zamknięcie = zapis do wznowienia.
- **Potwierdzenia destrukcyjne**: `.confirmationDialog` z przyciskiem `role: .destructive` i jasnym skutkiem („Słowa zostaną w słowniku”). „Usuń wszystkie dane” — dwa kroki (dialog + wpisanie/drugie potwierdzenie). Archiwizacja zamiast usuwania, gdzie się da, z możliwością przywrócenia.
- **Wyszukiwanie**: `.searchable` na korzeniu Słownika i Tematów (PL i EN), wyniki liczone poza głównym wątkiem, debounce.
- **Pasek narzędzi**: `QuickAddButton()` (`+`, ⌘N) w Dzisiaj i Słowniku; maksymalnie 2 ikony po prawej.

## 10. Stany: puste, ładowanie, błąd

Każdy ekran ma wszystkie trzy:
- **Pusty** — `EmptyStateView` z jednym konkretnym CTA (np. „Przeglądaj tematy”), nigdy pusty biały ekran.
- **Ładowanie** — szkielet (`.redacted(reason: .placeholder)`) dla list i kart; `LoadingStateView` dopiero po ~300 ms; nigdy blokujący spinner na całym ekranie dla danych lokalnych.
- **Błąd** — `ErrorBanner` nad treścią z „Spróbuj ponownie”; treść, która się wczytała, zostaje widoczna. Komunikat mówi, co się stało i że dane są bezpieczne. Błędy AI/sieci nie blokują nauki (fallback offline).

## 11. Dostępność (obowiązkowo)

- Każdy przycisk-ikona ma `accessibilityLabel` po polsku (komponenty mają domyślne).
- Komponenty łączą elementy w sensowne całości (`StatTile`, `SkillBar`, `ProgressRing` — etykieta + wartość). Nagłówki: `.accessibilityAddTraits(.isHeader)` (robi to `SectionHeader`).
- Dynamic Type do `accessibility5`: sprawdzaj podglądem z `.dynamicTypeSize(.accessibility2)`; nic nie może się uciąć — tekst zawija się (`fixedSize(horizontal: false, vertical: true)`).
- Kontrast AA w obu trybach — tylko kolory z `Palette`.
- „Ogranicz ruch” — patrz §7. „Zmniejsz przezroczystość” — systemowe szkło obsługuje to samo.
- VoiceOver w ćwiczeniach: licznik czasu nie jest odczytywany na bieżąco (`.accessibilityHidden` lub statyczna wartość), wynik ogłaszany raz (`AccessibilityNotification.Announcement`).
- Klawiatura sprzętowa (iPad): Enter = sprawdź, 1–4 = opcje (`.keyboardShortcut`), ⌘N = dodaj słowo.
- Pola odpowiedzi po angielsku: `.autocorrectionDisabled()`, `.textInputAutocapitalization(.never)`.

## 12. Architektura informacji i nawigacja

Pięć kart (`AppTab`): **Dzisiaj · Słownik · Nauka · Postępy · Ustawienia**.

Dlaczego tak (zamiast 6 pozycji strony: Dzisiaj, Mój słownik, Kolekcje, Ćwiczenia, Postępy + Ustawienia):
- iPhone mieści wygodnie 5 kart; Kolekcje i Tematy to **sposoby przeglądania tego samego zasobu słów**, więc trafiają do karty **Słownik** jako segmenty `Słowa / Kolekcje` (`AppRouter.librarySection`). **F1:** tematy nie są katalogiem — szuka się ich opisem sytuacji w arkuszu „+” → „Szukaj tematu”. Użytkownik ma jedno miejsce „moje słowa i skąd je biorę”.
- **Nauka** (strona: „Ćwiczenia”) — wybór trybów i czasu, wznowienie sesji; sama sesja jako pełny ekran.
- **Szybkie dodawanie** to akcja, nie miejsce: `+` w pasku Dzisiaj/Słownika i deep link `fluentnow://add` → arkusz globalny (`AppSheet.quickAdd`).
- **Ustawienia** jako karta (na stronie stopka paska bocznego) — na iPhonie nie ma paska bocznego, a ustawienia (cel, przypomnienia, głos, iCloud, AI) są często odwiedzane na początku.
- iPad (iOS 18+): `.sidebarAdaptable` — te same karty jako pasek boczny.

### Router (`AppRouter`, `@Observable @MainActor`, w środowisku)

```swift
@Environment(AppRouter.self) private var router
router.startStudy(.daily)                         // → karta Nauka + prośba do konsumpcji
router.startStudy(StudyLaunchRequest(modes: ["mistakes"], minutes: 5))
router.openLibrary(.topics, destination: .topic(id: "airport"))
router.presentQuickAdd(prefill: "borrow")
router.push(WordRoute.detail(id), on: .words)     // własne trasy Hashable ekranu
router.popToRoot(.words)
```
Ekran Nauka konsumuje prośbę: `.onChange(of: router.pendingStudyLaunch, initial: true) { _, r in if r != nil, let req = router.consumeStudyLaunch() { start(req) } }` (wzór w `StudyRootPlaceholder`). Słownik analogicznie `consumeLibraryDestination()`.

Korzenie kart (kontrakt): `TodayRootScreen()`, `WordsRootScreen()`, `StudyRootScreen()`, `StatsRootScreen()`, `SettingsRootScreen()` — bez własnego `NavigationStack` (dostarcza `RootView`); `CollectionsRootScreen()` i `TopicsRootScreen()` osadzane w Słowniku; `AddWordRootScreen(prefill:)` — arkusz z własnym `NavigationStack`. Fala 2 podmienia `body` tych plików i usuwa `*Placeholder.swift`.

## 13. Mapowanie ekranów strony → iOS

| Strona (`fluent.tsx`, `tutor-ui.tsx`) | iOS | Uwagi |
|---|---|---|
| Dzisiaj (karta sesji, pierścień, tydzień, kolekcje, ostatnie) | karta **Dzisiaj** | `HeroBackground` + `ProgressRing`, `StatTile`, mini-histogram (Charts), onboarding przy pierwszym uruchomieniu |
| Mój słownik (tabela, filtry, panel znaczeń) | **Słownik → Słowa**: lista + `.searchable` + chipy filtrów → szczegół (push) | tabela → lista z wierszami; panel znaczeń → ekran szczegółu z sekcjami |
| Edycja wpisu / edytor wielu znaczeń | arkusz `.large` z formularzem | `interactiveDismissDisabled` przy zmianach |
| Szybkie dodawanie, propozycje znaczeń | arkusz **Dodaj słowo** (`+`, ⌘N, deep link) | `.medium` → `.large` po wynikach |
| Kolekcje | **Słownik → Kolekcje** → kolekcja (push) → „Ćwicz tę kolekcję” (`startStudy(… collection:)`) | |
| Tematy / przygotowanie słownictwa | **„+” → Szukaj tematu** (opis sytuacji) → wyniki → „Dodaj N słów” | baza → pamięć tematów AI → generowanie AI; dodawanie w tle z postępem |
| Ćwiczenia (wybór trybów, 5/10/15 min) | karta **Nauka** | kafelek wznowienia |
| Sesja, typy zadań, podpowiedź, pewność, feedback, podsumowanie | `.fullScreenCover` sesji | `HighlightedText`, `ConfidencePicker`, `FeedbackPanel`, `SpeakButton` |
| Czytanie, gramatyka, idiomy, produkcja | z karty Nauka (tryby) lub push z Postępów | czytanka: `FluentFont.reading`, kolumna `readableWidth` |
| Postępy (histogram, kalendarz, umiejętności, CEFR, prognoza, trudne) | karta **Postępy** | Swift Charts, `SkillBar`, `LevelBadge` |
| Ustawienia, Gemini, import/eksport, usuwanie danych | karta **Ustawienia** (`Form`) | `ShareLink`, `fileImporter`, dwustopniowe usuwanie |
| Motyw jasny/ciemny | `AppAppearance` (system/jasny/ciemny) → `.preferredColorScheme` na korzeniu | |
| Tryb skupienia (ukrycie nawigacji) | pełny ekran sesji; iOS 26: pasek kart chowa się przy przewijaniu | |
| Komunikaty zapisu | `ErrorBanner` / dyskretny status w Ustawieniach | zapis lokalny jest natychmiastowy |
