# Raport: design-shell (fala 1)

## 1. Co zrobiono

**Projekt i konfiguracja**
- `ios/project.yml` — XcodeGen: target `FluentNOW` (iOS 17.0, iPhone+iPad, iPhone tylko pionowo), lokalny pakiet `Packages/FluentKit` (produkt `FluentKit`), target `FluentNOWTests` (unit, host app, `optional: true` na źródłach), schemat `FluentNOW` z testami `FluentNOWTests` + `package: FluentKit/FluentKitTests` i pokryciem kodu. `SWIFT_VERSION 5.0`, `SWIFT_STRICT_CONCURRENCY minimal`, `GENERATE_INFOPLIST_FILE YES` + `INFOPLIST_KEY_*` (nazwa, scena, orientacje, opisy prywatności mowy/mikrofonu po polsku, kategoria), `DEVELOPMENT_TEAM ""`, `pl.fluentnow.app`, `MARKETING_VERSION 1.0`, `CURRENT_PROJECT_VERSION 1`, `developmentLanguage: pl`, AppIcon/AccentColor.
- **Treść jako referencja folderowa (dotyczy też prośby data-pipeline — zrobione):** `FluentNOW/Resources/Content` dodane jako `type: folder` + `buildPhase: resources`, a z głównego źródła `FluentNOW` wyłączone (`excludes: "Resources/Content"`, `"Resources/Content/**"`). Pliki JSON nie trafiają do bundla jako płaskie zasoby; w bundlu powstaje `Content/` z zachowanymi podkatalogami (`Content/topics/…`, `Content/grammar/A1.json`…). Dostęp: `Bundle.main.url(forResource:withExtension:subdirectory: "Content/topics")`. Wykluczone są też `**/*.md`, `.gitkeep`, `.DS_Store` (inaczej XcodeGen kopiowałby je jako zasoby).
- `FluentNOW/Info.plist` (generowany też przez XcodeGen z `info.properties`): `CFBundleURLTypes` (schemat `fluentnow`), `UIBackgroundModes: remote-notification`, `UILaunchScreen.UIColorName = LaunchBackground`, `ITSAppUsesNonExemptEncryption = false`, `CFBundleDevelopmentRegion pl`.
- `FluentNOW/FluentNOW.entitlements` (też z `entitlements.properties`): `aps-environment: development`, `icloud-container-identifiers: [iCloud.pl.fluentnow.app]`, `icloud-services: [CloudKit]`.
- `ios/README.md` — instrukcja dla Maca po polsku (Xcode 26, xcodegen, Signing, tworzenie kontenera CloudKit, testy `swift test` i ⌘U/xcodebuild, urządzenie, tryb bez płatnego konta, rozwiązywanie problemów).

**Zasoby**
- `Resources/Assets.xcassets`: `AppIcon` (1024×1024, jeden rozmiar, warianty jasny/ciemny/tinted — format `appearances: luminosity dark/tinted`), `AccentColor` (jasny/ciemny), `LaunchBackground`.
- `ios/design/make-app-icon.mjs` — generator PNG bez zależności (SDF + node:zlib): biały dymek z fioletowym „F” na fioletowym gradiencie; RGB bez alfy (wymóg App Store). Uruchomiony, 3 pliki zapisane i obejrzane.

**Design system (`FluentNOW/DesignSystem/`)**
- Tokens: `Palette.swift` (role semantyczne, `ToneColors`, kolory wykresów i kolekcji), `LearningTones.swift` (`SkillTone`, `CEFRTone`), `Metrics.swift` (`Spacing`, `Radius`, `HitTarget`, `Elevation` + `.fluentShadow`), `Typography.swift` (`FluentFont`, `Text.fluentEyebrow()`), `Motion.swift` (`Motion`, `.fluentAnimation`), `AppAppearance.swift`.
- Modifiers: `GlassModifiers.swift` (`.fluentGlass`, `.fluentCardBackground`, `CardStyle`, `FluentGlassContainer`), `ButtonStyles.swift` (`FluentButtonKind`, `FluentPrimaryButtonStyle`, `FluentSecondaryButtonStyle`, `.fluentButtonStyle`), `Haptics.swift` (`FluentHaptic`, `FeedbackKind`).
- Components: `Buttons.swift` (`PrimaryButton`, `SecondaryButton`), `Card.swift`, `StatTile.swift`, `ProgressRing.swift` (`ProgressRing`, `LinearProgressBar`, `ProgressMath`), `SkillBar.swift`, `Badges.swift` (`LevelBadge`, `TagChip`), `StateViews.swift` (`EmptyStateView`, `LoadingStateView`, `ErrorBanner`), `SectionHeader.swift`, `SpeakButton.swift`, `ConfidencePicker.swift` (`ConfidenceLevel`), `FeedbackPanel.swift`, `HighlightedText.swift`, `HeroBackground.swift`.
- `Gallery/DesignSystemGallery.swift` — wszystkie komponenty na jednym ekranie (podgląd jasny + ciemny/duży tekst, wejście z zaślepki Ustawień).
- Każdy komponent ma `#Preview`.

**Szkielet (`FluentNOW/App/`)**
- `FluentNOWApp.swift` (`@main`, router w `@State`, `.onOpenURL`, miejsce na AppEnvironment), `RootView.swift` (iOS 18+: `Tab(value:content:label:)` + `.sidebarAdaptable`; iOS 17: `.tabItem/.tag`; iOS 26: `tabBarMinimizeBehavior(.onScrollDown)`; `NavigationStack(path:)` per karta; globalny `.sheet(item:)`), `AppRouter.swift`, `AppTab.swift` (`AppTab`, `LibrarySection`), `DeepLink.swift` (`DeepLink`, `StudyLaunchRequest`, `LibraryDestination`), `QuickAddButton.swift`.

**Zaślepki ekranów (`Features/`)** — dla każdej karty para plików: `XRootScreen.swift` (stały kontrakt, fala 2 podmienia `body`) + `XRootPlaceholder.swift` (do usunięcia): Today, Words, Collections, Topics, Study, Stats, Settings, AddWord.

**Testy** — `ios/FluentNOWTests/Shell/ShellTests.swift` (patrz §6).

**Dokumentacja** — `ios/docs/DESIGN.md`.

## 2. Publiczne API / kontrakty

```swift
// Nawigacja
enum AppTab: String, CaseIterable, Identifiable, Hashable, Sendable { case today, words, study, progress, settings; var title: String; var systemImage: String }
enum LibrarySection: String, CaseIterable, Identifiable, Hashable, Sendable { case words, collections, topics; var title: String }
enum AppSheet: Identifiable, Hashable { case quickAdd(prefill: String?) }
struct StudyLaunchRequest: Hashable, Sendable {
    var modes: [String]; var minutes: Int?; var resume: Bool; var collection: String?
    init(modes: [String] = [], minutes: Int? = nil, resume: Bool = false, collection: String? = nil)
    static let daily, mistakes, resumeLast: StudyLaunchRequest; static let allowedMinutes: Set<Int>
}
enum LibraryDestination: Hashable, Sendable { case word(id: String), collection(name: String), topic(id: String) }
enum DeepLink: Hashable, Sendable { case tab(AppTab), library(LibrarySection, LibraryDestination?), study(StudyLaunchRequest), quickAdd(prefill: String?); init?(url: URL) }

@MainActor @Observable final class AppRouter {
    var selectedTab: AppTab; var librarySection: LibrarySection
    var todayPath, wordsPath, studyPath, progressPath, settingsPath: NavigationPath
    var activeSheet: AppSheet?
    private(set) var pendingStudyLaunch: StudyLaunchRequest?
    private(set) var pendingLibraryDestination: LibraryDestination?
    init(selectedTab: AppTab = .today)
    func select(_ tab: AppTab); func path(for: AppTab) -> NavigationPath; func setPath(_: NavigationPath, for: AppTab)
    func push<Route: Hashable>(_ route: Route, on tab: AppTab); func popToRoot(_ tab: AppTab); func pop(on tab: AppTab)
    func startStudy(_ request: StudyLaunchRequest = .daily); func consumeStudyLaunch() -> StudyLaunchRequest?
    func openLibrary(_ section: LibrarySection, destination: LibraryDestination? = nil); func consumeLibraryDestination() -> LibraryDestination?
    func presentQuickAdd(prefill: String? = nil); func dismissSheet()
    @discardableResult func handle(url: URL) -> Bool; func open(_ link: DeepLink)
}
struct QuickAddButton: View { init(prefill: String? = nil) }

// Korzenie ekranów (fala 2 podmienia body; bez własnego NavigationStack poza AddWord)
TodayRootScreen(), WordsRootScreen(), CollectionsRootScreen(), TopicsRootScreen(),
StudyRootScreen(), StatsRootScreen(), SettingsRootScreen(), AddWordRootScreen(prefill: String?)

// Design system
enum Palette { background, surface, surfaceElevated, surfaceMuted, separator, ink, inkSecondary, inkTertiary,
  accent, accentFill, onAccent, accentSoft, accentSoftInk, success(+Soft), warning(+Soft), danger(+Soft), info(+Soft),
  heroStart, heroEnd, heroGlow, heroInkSecondary, heroRingTrack, heroRingProgress, chart: [Color];
  static func chartColor(_: Int) -> Color; static let collectionTones: [ToneColors]
  static func collectionTone(_: Int) -> ToneColors; static func collectionTone(named: String) -> ToneColors
  static func safeIndex(_: Int, count: Int) -> Int; static func dynamic(light: UInt32, dark: UInt32) -> Color }
struct ToneColors: Hashable { let foreground, background: Color; static accent, neutral, success, warning, danger, info }
enum SkillTone: String, CaseIterable { recognition, recall, spelling, listening, usage; title, systemImage, color }
enum CEFRTone { static let levels; static func normalized(_: String) -> String?; static func tone(for: String) -> ToneColors }
enum Spacing { xxs 4, xs 8, s 12, m 16, l 24, xl 32, xxl 48, screen 16, readableWidth 640 }
enum Radius { badge 6, small 10, medium 14, card 20, hero 28 }; enum HitTarget { minimum 44, buttonHeight 50 }
enum Elevation { flat, card, raised }; View.fluentShadow(_:)
enum FluentFont { display, heroTitle, title, headline, body, bodyEmphasized, callout, subheadline, footnote, caption,
  eyebrow, button, flashcardTerm, sentence, ipa, reading, numberLarge, numberMedium, numberSmall }; Text.fluentEyebrow()
enum Motion { tap, standard, emphasized, progress, reducedFade; resolved(_:reduceMotion:fallback:) -> Animation?; contentTransition(reduceMotion:) -> AnyTransition }
View.fluentAnimation(_ animation: Animation = Motion.standard, fallback: Animation? = nil, value:)
enum AppAppearance: String { system, light, dark; title, systemImage, colorScheme: ColorScheme? }
View.fluentGlass(tint: Color? = nil, interactive: Bool = false); View.fluentGlass(in: some Shape, tint:, interactive:)
enum CardStyle: Hashable { solid, muted, tinted(ToneColors), glass }; View.fluentCardBackground(_ style: CardStyle = .solid, cornerRadius: CGFloat = Radius.card)
struct FluentGlassContainer<Content: View> { init(spacing: CGFloat? = nil, @ViewBuilder content:) }
enum FluentButtonKind { primary, secondary, destructive }; View.fluentButtonStyle(_ kind: FluentButtonKind = .primary)
struct FluentPrimaryButtonStyle: ButtonStyle { var tint: Color }; struct FluentSecondaryButtonStyle: ButtonStyle { var tone: ToneColors }
enum FluentHaptic { answerCorrect, answerIncorrect, answerAlmost, selection, swipeCommit, goalReached, destructive: SensoryFeedback }
enum FeedbackKind: String { correct, almost, incorrect, info; haptic: SensoryFeedback?, tone, systemImage, defaultTitle }
PrimaryButton(_ title: String, systemImage: String? = nil, isLoading: Bool = false, fillsWidth: Bool = true, action:)
SecondaryButton(_ title: String, systemImage: String? = nil, role: ButtonRole? = nil, isLoading: Bool = false, fillsWidth: Bool = true, action:)
Card(style: CardStyle = .solid, padding: CGFloat = Spacing.m, spacing: CGFloat = Spacing.s, @ViewBuilder content:)
StatTile(title: String, value: String, systemImage: String, caption: String? = nil, tone: ToneColors = .accent)
ProgressRing(progress: Double, lineWidth: CGFloat = 10, tint: Color = Palette.accent, track: Color = Palette.surfaceMuted, accessibilityLabel: String = "Postęp", @ViewBuilder center:)  // + wariant bez center
LinearProgressBar(progress: Double, tint: Color = Palette.accent, track: Color = Palette.surfaceMuted, height: CGFloat = 8)
enum ProgressMath { static func clamped(_: Double) -> Double; static func fraction(_ done: Int, of total: Int) -> Double }
SkillBar(skill: SkillTone, score: Double?) / SkillBar(title:score:tint:systemImage:); static func scoreText(_: Double?) -> String
LevelBadge(level: String); TagChip(_ title:, systemImage:, tone: ToneColors = .neutral); TagChip(_ title:, systemImage:, isSelected:, action:)
EmptyStateView(systemImage:title:message:actionTitle:action:); LoadingStateView(_ message: String = "Wczytywanie…")
ErrorBanner(title: = "Coś poszło nie tak", message:, retryTitle: = "Spróbuj ponownie", onRetry: (() -> Void)? = nil, onDismiss: (() -> Void)? = nil)
SectionHeader(_ title:, subtitle: String? = nil, actionTitle: String? = nil, action: (() -> Void)? = nil)
SpeakButton(style: .normal|.slow = .normal, size: .small|.regular|.large = .regular, isSpeaking: Bool = false, accessibilityLabel: String? = nil, action:)
enum ConfidenceLevel: Int { unsure = 1, fair = 2, sure = 3; title, systemImage; init(clamping: Int) }
ConfidencePicker(selection: Binding<ConfidenceLevel>, title: String? = "Na ile czujesz się pewnie?")
FeedbackPanel(kind: FeedbackKind, title: String? = nil, message: String? = nil, explanation: String? = nil, playsHaptic: Bool = true, @ViewBuilder accessory:)  // + wariant bez accessory; message/explanation = inline Markdown
HighlightedText(_ text: String, focus: String?, highlight: Color? = Palette.accent)
  static func split(_:focus:) -> (before: String, match: String, after: String)?; static func attributed(_:focus:highlight:) -> AttributedString
HeroBackground(); DesignSystemGallery()
```

Deep linki: `fluentnow://today | words[/<id>] | collections[/<nazwa>] | topics[/<id>] | study | study/start?mode=…&minutes=5|10|15&collection=… | study/resume | add?text=… | progress | settings`.

## 3. Odstępstwa od strony i dlaczego

- **Architektura informacji:** 5 kart zamiast 6 pozycji nawigacji strony. Kolekcje i Tematy jako segmenty karty „Słownik” (jeden zasób słów, różne widoki), „Ćwiczenia” → „Nauka”, Ustawienia jako karta, szybkie dodawanie jako globalny arkusz (`+`, ⌘N, deep link). Uzasadnienie w DESIGN.md §12.
- **Kolory doprecyzowane pod WCAG AA:** `inkSecondary` #767786 → #6B6C7D (4,16 → 4,87 na tle), ciemny wariant przycisku #A68AEE z ciemnym tekstem → #7C5CE0 z białym tekstem (spójny z Liquid Glass `.glassProminent`), zieleń/bursztyn statusów przyciemnione (#418C6D → #2C7A58, #B57B37 → #94601F), gradient karty sesji przyciemniony, tak by biały tekst miał ≥ 4,5:1 na całej powierzchni. Wszystkie pary sprawdzone skryptem (wyniki w §6).
- **Karty treści nie są szkłem** na iOS 26 (rola sugerowała `.fluentCardBackground()` → `glassEffect`): HIG ogranicza Liquid Glass do warstwy nawigacji i kontrolek; szkło na kartach listy pogarsza czytelność i wydajność. `fluentCardBackground(.glass)` istnieje jako opcja, `fluentGlass()` jest szkłem zawsze.
- Niećwiczona umiejętność zawsze „—”, nigdy 0% (jak strona); `HighlightedText` dopasowuje także bez polskich znaków (`diacriticInsensitive`), np. wpisane „pozyczyc” → „pożyczyć”.
- Deep linki i powiadomienia → sesja (na stronie brak).

## 4. Znane ryzyka / niesprawdzone (brak kompilatora)

API Liquid Glass/iOS 18 sprawdzone w oficjalnej dokumentacji Apple (JSON developer.apple.com): `glassEffect(_:in:)`, `Glass.regular/.tint(Color?)/.interactive(Bool)`, `GlassEffectContainer(spacing:content:)`, `PrimitiveButtonStyle.glass/.glassProminent`, `tabBarMinimizeBehavior(_:)` + `.onScrollDown`, `Tab(value:content:label:)`, `TabView(selection:content:)`, `.sidebarAdaptable`, `MeshGradient(width:height:points:colors:…)`, `sensoryFeedback(_:trigger:condition:)`. Składnia XcodeGen sprawdzona w `Docs/ProjectSpec.md` i źródłach (`FileType.swift`: `.entitlements` bez fazy budowania; plik `info.path` nie jest kopiowany jako zasób). Ryzyka:
1. `HighlightedText`: `emphasized[AttributeScopes.SwiftUIAttributes.ForegroundColorAttribute.self] = highlight` — jawny klucz, by uniknąć niejednoznaczności `foregroundColor` (SwiftUI vs UIKit). Jeśli kompilator zaprotestuje: `emphasized.swiftUI.foregroundColor = highlight`.
2. Prywatne typy (`FluentGlassModifier`, `FluentFilledButtonBody`) ukryte za `some View` w funkcjach `internal` — dozwolone dla typów nieprzezroczystych; w razie błędu zmienić `private` → `fileprivate`/`internal`.
3. `@Bindable var router = router` w `body` (RootView, WordsRootPlaceholder) — wzorzec Apple dla iOS 17.
4. Schemat: `- package: FluentKit/FluentKitTests` w `schemes.test.targets` wymaga XcodeGen ≥ 2.35 (ustawione `minimumXcodeGenVersion: 2.38.0`). Jeśli wersja XcodeGen go nie obsługuje — usunąć linię, testy pakietu przez `swift test`.
5. `TEST_HOST` ustawiony jawnie (forma z szablonu Xcode), XcodeGen ustawia go i tak.
6. Info.plist: scalenie pliku z `info.properties` z kluczami `INFOPLIST_KEY_*` (GENERATE_INFOPLIST_FILE=YES + INFOPLIST_FILE) — standardowe zachowanie Xcode, niezweryfikowane na tym projekcie.
7. Ikona tinted/dark w formacie Xcode 16 (`appearances: luminosity`). Ikony warstwowej Icon Composer (`.icon`, iOS 26) nie robiłem — systemowy efekt szkła na ikonie zostanie nałożony automatycznie na zwykłą ikonę.
8. `TabBarMinimizeOnScroll` nakładany na `Group` zawierający `TabView` — powinien trafić do `TabView`; w razie braku efektu przenieść modyfikator bezpośrednio na `TabView` w `ModernTabView`.
9. Dotknięcie aktywnej karty: wracanie do korzenia zostawiam systemowi (`NavigationStack` w `TabView`). `router.select(_:)` robi to programowo.

## 5. Prośby do innych ról

- **platform-services:** w `FluentNOWApp.swift` dodać `AppEnvironment` (miejsce oznaczone komentarzem) i `.preferredColorScheme(settings.appearance.colorScheme)` (`AppAppearance` z design systemu, surowe wartości `system/light/dark` jak `theme` strony). `ContentLibrary`: treść jest w bundlu pod `Content/` (referencja folderowa). Powiadomienie o nauce po dotknięciu → `router.open(.study(.daily))` lub URL `fluentnow://study/start?mode=mixed`. Testy w `FluentNOWTests/Shell/` są moje — proszę ich nie usuwać (mogą zostać przeniesione).
- **ui-library / ui-learning:** podmieniać tylko `body` plików `*RootScreen.swift` (zachowując nazwy i inicjalizatory) i usunąć `*Placeholder.swift`. Ekran Nauka konsumuje `router.consumeStudyLaunch()`, Słownik — `consumeLibraryDestination()` (wzorce w zaślepkach). Sesję prezentować jako `.fullScreenCover`. Nie definiować `Color.accent`/`Color.launchBackground` (kolizja z symbolami zasobów).
- **data-pipeline:** prośba o referencję folderową dla `Resources/Content` — **zrobione** (patrz §1). Nie umieszczajcie plików `.md` w `Resources/Content`, jeśli mają trafić do aplikacji (folder jest kopiowany w całości, łącznie z nimi — lepiej trzymać dokumentację w `docs/`).
- **koordynator:** `ios/design/` to nowy katalog design-shell (generator ikony) — poza strukturą z briefu, poza targetem aplikacji.

## 6. Testy i uruchomione skrypty

- `FluentNOWTests/Shell/ShellTests.swift` (XCTest, uruchomią się na Macu ⌘U):
  - `DeepLinkTests` — karty, Słownik z identyfikatorami i %-kodowaniem, start sesji (deduplikacja trybów, odrzucanie niepoprawnych trybów i czasów, kolekcja), wznowienie, szybkie dodawanie (puste i za długie parametry), obce schematy/nieznane hosty.
  - `AppRouterTests` (`@MainActor`) — start sesji zamyka arkusz i jest konsumowany raz, obsługa URL, push/pop (w tym pop na pustym stosie), powrót do korzenia.
  - `DesignSystemLogicTests` — `HighlightedText.split/attributed` (wielkość liter, diakrytyki, brak dopasowania, pusty focus), `SkillBar.scoreText` (nil/NaN/przycinanie), `ProgressMath`, bezpieczne indeksy tonów, `CEFRTone.normalized`, `ConfidenceLevel(clamping:)`.
- `node ios/design/make-app-icon.mjs` — OK, 3 PNG 1024×1024 RGB (obejrzane: jasny i ciemny).
- Wszystkie `Contents.json` w `Assets.xcassets` sparsowane jako poprawny JSON (`node`).
- Kontrast WCAG (skrypt node): ink/tło 14,2; inkSecondary 4,6–5,2 (jasny), 5,7–6,6 (ciemny); biały na `accentFill` 5,37 / 4,70; `accent` na tle 5,1 / 7,7; status na tłach „soft” 4,5–5,2 (jasny), 6,0–9,3 (ciemny); tony kolekcji 4,5–4,9 / 5,8–7,0; biały na gradiencie hero ≥ 4,77 (90% bieli ≥ 4,64).
- Pliki: UTF-8 bez BOM, LF (sprawdzone).
