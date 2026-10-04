# FluentNOW — aplikacja iOS

Natywna aplikacja do nauki angielskiego dla osób polskojęzycznych (SwiftUI, iOS 17+, ulepszenia dla iOS 18 i iOS 26 / Liquid Glass). Działa w pełni offline; dane synchronizują się przez iCloud bez logowania.

Projekt Xcode **nie jest trzymany w repozytorium** — generuje go [XcodeGen](https://github.com/yonaskolb/XcodeGen) z pliku `project.yml`.

## Wymagania

| Narzędzie | Wersja |
|---|---|
| macOS | 15 (Sequoia) lub nowszy |
| Xcode | **26** lub nowszy (SDK iOS 26 — wymagany przez API Liquid Glass) |
| XcodeGen | 2.38 lub nowszy |
| Homebrew | dowolna aktualna |
| Konto Apple Developer | płatne — dla iCloud/CloudKit; bez niego patrz [Bez płatnego konta](#bez-płatnego-konta-tylko-lokalnie) |

## Pierwsze uruchomienie krok po kroku

1. **Zainstaluj Xcode 26+** z App Store i uruchom go raz (zaakceptuj licencję, doinstaluj komponenty i platformę iOS).
2. **Zainstaluj XcodeGen:**
   ```bash
   brew install xcodegen
   ```
3. **Wygeneruj projekt:**
   ```bash
   cd ios
   xcodegen
   ```
   Powstanie `FluentNOW.xcodeproj` (oraz odświeżone `FluentNOW/Info.plist` i `FluentNOW/FluentNOW.entitlements`). Polecenie uruchamiaj ponownie po każdej zmianie `project.yml` **oraz po dodaniu/usunięciu plików** (`.swift`, zasobów) — XcodeGen buduje listę plików z dysku.
4. **Otwórz projekt:** `open FluentNOW.xcodeproj`.
5. **Podpisywanie:** wybierz target **FluentNOW** → zakładka **Signing & Capabilities** → zaznacz *Automatically manage signing* → w polu **Team** wybierz swój zespół. (W `project.yml` `DEVELOPMENT_TEAM` jest puste celowo. Aby nie ustawiać go po każdym `xcodegen`, wpisz identyfikator zespołu w `project.yml` → `settings.base.DEVELOPMENT_TEAM`.)
   - Jeśli identyfikator `pl.fluentnow.app` jest zajęty na Twoim koncie, zmień `PRODUCT_BUNDLE_IDENTIFIER` w `project.yml` (i odpowiednio kontener iCloud — patrz niżej).
6. **iCloud / CloudKit:** na tej samej zakładce powinna być widoczna sekcja **iCloud** z zaznaczonym **CloudKit**.
   - W sekcji *Containers* zaznacz `iCloud.pl.fluentnow.app`. Jeśli kontenera nie ma na liście, kliknij **+** i wpisz `iCloud.pl.fluentnow.app` — Xcode utworzy go na Twoim koncie (może to potrwać minutę; czerwony komunikat zniknie po odświeżeniu ↻).
   - Kontener możesz też utworzyć ręcznie: [developer.apple.com](https://developer.apple.com/account) → *Certificates, Identifiers & Profiles* → *Identifiers* → przełącz filtr na **iCloud Containers** → **+** → `iCloud.pl.fluentnow.app`. Następnie w identyfikatorze aplikacji `pl.fluentnow.app` włącz iCloud (CloudKit) i przypisz kontener.
   - Sekcja **Push Notifications** pojawi się automatycznie (`aps-environment`) — CloudKit potrzebuje jej do cichych powiadomień o zmianach. Sekcja **Background Modes → Remote notifications** jest włączona przez `Info.plist`.
   - Schemat SwiftData jest wysyłany do środowiska *Development* CloudKit automatycznie przy pierwszym uruchomieniu w trybie Debug. Przed wydaniem w App Store wdroż schemat na *Production* w [CloudKit Console](https://icloud.developer.apple.com) (*Deploy Schema Changes*).
7. **Uruchom w symulatorze:** wybierz schemat **FluentNOW** i dowolny symulator iPhone → **⌘R**. W symulatorze bez zalogowanego konta iCloud aplikacja automatycznie przechodzi na zapis lokalny (informacja w Ustawieniach) — to zamierzone zachowanie.
8. **Testy:**
   - Wszystkie testy aplikacji i pakietu: **⌘U** (schemat FluentNOW uruchamia `FluentNOWTests` oraz `FluentKitTests`).
   - Sam pakiet logiki, bez symulatora (szybko, na Macu):
     ```bash
     cd ios/Packages/FluentKit
     swift test
     ```
   - Z wiersza poleceń (całość):
     ```bash
     cd ios
     xcodebuild test -project FluentNOW.xcodeproj -scheme FluentNOW \
       -destination 'platform=iOS Simulator,name=iPhone 17'
     ```
     (nazwę symulatora sprawdzisz: `xcrun simctl list devices available`).
9. **Uruchomienie na iPhonie:** podłącz telefon kablem (lub w tej samej sieci Wi‑Fi po sparowaniu), wybierz go jako cel i **⌘R**. Za pierwszym razem:
   - na iPhonie włącz **Tryb dewelopera**: *Ustawienia → Prywatność i ochrona → Tryb dewelopera* (wymaga restartu);
   - przy koncie darmowym zaufaj certyfikatowi: *Ustawienia → Ogólne → VPN i urządzenia zarządzane*.
   - Synchronizacja iCloud wymaga zalogowania na iPhonie do iCloud z włączonym iCloud Drive.

## Bez płatnego konta (tylko lokalnie)

Darmowe konto (Personal Team) nie obsługuje iCloud/CloudKit ani Push Notifications, więc podpisywanie z entitlementami się nie powiedzie. Aplikacja działa wtedy w pełni lokalnie (SwiftData bez CloudKit — automatyczny fallback). Dwie drogi:

- **Szybko (do następnego `xcodegen`):** w *Signing & Capabilities* usuń sekcje **iCloud** i **Push Notifications** (ikona kosza przy nazwie sekcji).
- **Trwale:** w `project.yml` zakomentuj cały blok `entitlements:` targetu `FluentNOW` (od `entitlements:` do linii `- CloudKit` włącznie), usuń plik `FluentNOW/FluentNOW.entitlements` i uruchom ponownie `xcodegen`.

Wszystkie funkcje poza synchronizacją między urządzeniami działają bez zmian.

## Struktura

```
ios/
  project.yml                 specyfikacja XcodeGen (źródło prawdy dla projektu)
  design/make-app-icon.mjs    generator ikony (node design/make-app-icon.mjs)
  Packages/FluentKit/         logika domenowa (Swift Package, testy XCTest)
  FluentNOW/
    App/                      @main, RootView (karty), AppRouter, deep linki
    DesignSystem/             kolory, typografia, komponenty, modyfikatory iOS 26
    Features/                 ekrany (Dzisiaj, Słownik, Nauka, Postępy, Ustawienia…)
    Services/                 trwałość, iCloud, mowa, przypomnienia, AI, treść
    Resources/Assets.xcassets ikona, AccentColor, LaunchBackground
    Resources/Content/        wbudowana treść JSON (referencja folderowa → Content/ w bundlu)
  FluentNOWTests/             testy aplikacji
  tools/                      skrypty Node (walidacja treści)
  docs/                       DESIGN.md, CONTENT-SCHEMA.md, raporty
```

Treść z `Resources/Content/` trafia do bundla **z zachowaniem katalogów** (niebieski folder w Xcode), np. `Bundle.main.url(forResource: "index", withExtension: "json", subdirectory: "Content/topics")`. Po dodaniu nowych plików JSON nie trzeba uruchamiać `xcodegen` — folder jest kopiowany w całości (ale Xcode nie zawsze wykrywa zmiany w referencji folderowej przy budowaniu przyrostowym: w razie wątpliwości **Product → Clean Build Folder**, ⇧⌘K).

Deep linki: `fluentnow://today`, `fluentnow://study/start?mode=mixed&minutes=10`, `fluentnow://add?text=borrow` — pełna lista w `FluentNOW/App/DeepLink.swift`. Test w symulatorze:
```bash
xcrun simctl openurl booted "fluentnow://study/start?mode=mixed&minutes=5"
```

## Rozwiązywanie problemów

| Objaw | Przyczyna i rozwiązanie |
|---|---|
| `xcodegen: command not found` | `brew install xcodegen`; sprawdź `which xcodegen`. |
| `Spec validation error … Packages/FluentKit` | Brak `Packages/FluentKit/Package.swift` — sprawdź, czy repozytorium jest kompletne. |
| Nowy plik `.swift` „nie istnieje” dla kompilatora | Uruchom ponownie `xcodegen` (projekt nie widzi plików dodanych po generowaniu, jeśli dodałeś je poza Xcode). |
| *Signing for "FluentNOW" requires a development team* | Ustaw Team w *Signing & Capabilities* (krok 5). |
| *Provisioning profile doesn't include the iCloud / aps-environment entitlement* | Konto darmowe → [Bez płatnego konta](#bez-płatnego-konta-tylko-lokalnie). Konto płatne → w *Signing & Capabilities* odznacz i zaznacz ponownie kontener, poczekaj na odświeżenie profilu. |
| *Multiple commands produce …/index.json* | Treść została dodana jako grupa zamiast referencji folderowej. Nie dodawaj plików z `Resources/Content` ręcznie w Xcode; uruchom `xcodegen`. |
| `No such module 'FluentKit'` | *File → Packages → Reset Package Caches*, potem ⇧⌘K i ⌘B. |
| Błędy dot. `glassEffect`, `Tab`, `tabBarMinimizeBehavior` | Używasz Xcode starszego niż 26. Zaktualizuj Xcode (kod obsługuje iOS 17 w czasie działania, ale wymaga SDK iOS 26 do kompilacji). |
| Podgląd (`#Preview`) nie działa | *Editor → Canvas*, wybierz symulator iOS 17+ jako cel podglądu; ⌥⌘P odświeża. W razie błędu: *Product → Clean Build Folder*. |
| Brak synchronizacji między urządzeniami | Oba urządzenia: ten sam Apple ID, iCloud Drive włączony, aplikacja zbudowana z tym samym kontenerem i środowiskiem (Debug = Development). Status widać w Ustawieniach aplikacji. Synchronizacja CloudKit bywa opóźniona o kilkadziesiąt sekund. |
| Symulator: „iCloud niedostępny” | Normalne bez zalogowanego konta — zaloguj się w *Ustawieniach* symulatora albo testuj lokalnie. |
| Ikona się nie odświeża | Usuń aplikację z symulatora/urządzenia i zainstaluj ponownie (system buforuje ikony). Ikonę generuje `node design/make-app-icon.mjs`. |
