# Rola: design-shell — projekt Xcode, design system, szkielet aplikacji

Fala 1. Obszar: `ios/project.yml`, `ios/README.md`, `ios/FluentNOW/App/`, `ios/FluentNOW/DesignSystem/`, `ios/FluentNOW/Resources/Assets.xcassets`, entitlements/Info.plist, pliki-zaślepki w `Features/*` (tylko `*Placeholder*`/`RootScreen` — patrz niżej). Raport: `ios/docs/reports/design-shell.md`. Dodatkowo `ios/docs/DESIGN.md`.

## Cel

Fundament, na którym fala 2 zbuduje funkcje: projekt, który na Macu wygeneruje się jednym poleceniem i skompiluje bez poprawek, spójny i piękny system wizualny oraz nawigacja aplikacji. Aplikacja ma wyglądać jak dopracowana aplikacja z App Store, lepiej niż strona.

## Zadania

1. **`ios/project.yml` (XcodeGen)**:
   - target aplikacji `FluentNOW` (iOS 17.0, iPhone + iPad, orientacja portrait na iPhone), sources `FluentNOW/` (z wykluczeniem niczego — `Resources/Content/**` jako zasoby folderowe, tak by struktura `topics/` zachowała się w bundle: użyj `type: folder` lub `buildPhase: resources` z referencją folderową — **sprawdź poprawną składnię XcodeGen**), lokalny pakiet `Packages/FluentKit` jako zależność;
   - target testów `FluentNOWTests` (unit, host app);
   - ustawienia: `SWIFT_VERSION: 5.0`, `SWIFT_STRICT_CONCURRENCY: minimal`, `GENERATE_INFOPLIST_FILE: YES` + `INFOPLIST_KEY_*` (CFBundleDisplayName FluentNOW, UILaunchScreen, opisy prywatności: `NSSpeechRecognitionUsageDescription`, `NSMicrophoneUsageDescription` po polsku), `DEVELOPMENT_TEAM: ""`, `PRODUCT_BUNDLE_IDENTIFIER: pl.fluentnow.app`, `MARKETING_VERSION: 1.0`, `CURRENT_PROJECT_VERSION: 1`, `developmentLanguage: pl`;
   - entitlements: iCloud (CloudKit, kontener `iCloud.pl.fluentnow.app`), `aps-environment: development` (wymagane przez CloudKit), Background Modes: remote-notification;
   - schemat `FluentNOW` z testami (`FluentNOWTests` + testy pakietu `FluentKitTests`).
2. **`ios/README.md`** — instrukcja dla Maca krok po kroku (po polsku): Xcode 26+, `brew install xcodegen`, `cd ios && xcodegen`, otwórz `FluentNOW.xcodeproj`, ustaw Team w Signing, włącz iCloud → CloudKit z kontenerem (jak utworzyć kontener), uruchom testy `swift test` w `Packages/FluentKit` oraz ⌘U, uruchomienie na urządzeniu; co zrobić, gdy nie masz płatnego konta (aplikacja działa lokalnie — jak tymczasowo wyłączyć entitlement iCloud). Sekcja „Rozwiązywanie problemów”.
3. **Design system (`DesignSystem/`)** — przenieś tożsamość strony (`web-source/app/globals.css`, `plan-produktu.md` §7: fiolet jako główna akcja, atramentowy tekst, chłodne tło, zieleń/bursztyn pomocniczo, pierścień dziennego celu) i podnieś ją na poziom natywny:
   - `Theme`/`Palette` — kolory jako `Color` z wariantami jasny/ciemny (asset catalog colorsets **albo** `Color(uiColor: UIColor { trait in … })`), role semantyczne (`accent`, `surface`, `surfaceElevated`, `ink`, `inkSecondary`, `success`, `warning`, `danger`, `skill.*` dla 5 umiejętności), kontrast AA w obu trybach;
   - typografia na `Font.TextStyle` (Dynamic Type), zaokrąglony wariant `.rounded` dla liczb;
   - komponenty: `PrimaryButton`, `SecondaryButton`, `Card`, `StatTile`, `ProgressRing` (animowany pierścień celu), `SkillBar`, `LevelBadge` (CEFR), `TagChip`, `EmptyStateView`, `ErrorBanner` (z akcją ponów), `SectionHeader`, `SpeakButton` (ikona głośnika, tylko UI — akcja wstrzykiwana), `ConfidencePicker` (pewność 1–3), `FeedbackPanel` (poprawnie/błędnie + wyjaśnienie), `HighlightedText` (pogrubienie `focus` w zdaniu — używane w fiszkach, wymaga dopasowania podciągu bez rozróżniania wielkości liter, bezpieczne gdy brak dopasowania);
   - modyfikatory adaptacyjne: `.fluentGlass()` / `.fluentCardBackground()` → na iOS 26 `glassEffect`, na iOS 17–25 `Material`/kolor; `.fluentButtonStyle()` → na iOS 26 `.glass`/`.glassProminent`, wcześniej własny styl; haptyka przez `.sensoryFeedback` (iOS 17);
   - wszystkie API nowsze niż iOS 17 za `if #available` — **sprawdź dokładne nazwy i sygnatury API iOS 26 (Liquid Glass)**; jeśli nie masz pewności co do sygnatury — nie używaj jej i opisz w raporcie zamiast zgadywać.
4. **Ikona aplikacji i akcent** — `AppIcon` (pojedynczy 1024×1024; wygeneruj PNG skryptem Node bez zależności — prosty, elegancki znak, np. litera „F” / dymek na fioletowym gradiencie; zapisz też wariant dark/tinted jeśli potrafisz poprawnie opisać `Contents.json`), `AccentColor`.
5. **Szkielet aplikacji (`App/`)** — `FluentNOWApp` (`@main`), `RootView` z `TabView` (Dzisiaj, Słownik, Nauka, Postępy, Ustawienia; „Kolekcje/Tematy” jako sekcja Słownika lub osobna karta — zaproponuj najlepszą architekturę informacji dla iPhone'a i opisz w DESIGN.md), na iOS 18+ nowe `Tab` API, na iOS 26 `tabBarMinimizeBehavior(.onScrollDown)`. Router: `AppRouter` (`@Observable`) z wybraną kartą i ścieżkami `NavigationPath` per karta, deep link do sesji nauki. Nie twórz `AppEnvironment` ani serwisów — to obszar platform-services (fala 2); `FluentNOWApp` niech ma tylko miejsce (komentarz `// AppEnvironment wstrzykuje platform-services`) na wstrzyknięcie. Ekrany kart jako zaślepki `TodayRootPlaceholder` itd. w `Features/<X>/` (fala 2 je zastąpi).
6. **`ios/docs/DESIGN.md`** — zasady wizualne i interakcyjne dla agentów UI: siatka odstępów (4/8/12/16/24), promienie, cienie, użycie koloru, ruch (czasy, sprężyny, reduce motion), wzorce ekranów (lista → szczegół, arkusze `.sheet` z `presentationDetents`, potwierdzenia destrukcyjne), haptyka (kiedy jaka), stany puste/błędu/ładowania, dostępność, mapowanie ekranów strony → ekrany iOS. Z przykładami kodu użycia komponentów.
7. **Podgląd** — każdy komponent ma `#Preview`.

## Jakość

Brak kompilatora na Windows (brief §5) — szczególnie ostrożnie z `project.yml` (sprawdź w dokumentacji XcodeGen klucze: `packages`, `dependencies: - package:`, `entitlements`, `settings.base`, `info`, `resources`/`type: folder`). Jeśli masz dostęp do WebFetch/WebSearch, zweryfikuj składnię XcodeGen i API Liquid Glass w oficjalnej dokumentacji.
