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

Darmowe konto (Personal Team) nie obsługuje iCloud/CloudKit, Push Notifications ani „Sign in with Apple”, więc podpisywanie z entitlementami się nie powiedzie. Aplikacja działa wtedy w pełni lokalnie (SwiftData bez CloudKit — automatyczny fallback). Dwie drogi:

- **Szybko (do następnego `xcodegen`):** w *Signing & Capabilities* usuń sekcje **iCloud**, **Push Notifications** i **Sign in with Apple** (ikona kosza przy nazwie sekcji).
- **Trwale:** w `project.yml` zakomentuj cały blok `entitlements:` targetu `FluentNOW` (od `entitlements:` do linii `- Default` pod `com.apple.developer.applesignin` włącznie), usuń plik `FluentNOW/FluentNOW.entitlements` i uruchom ponownie `xcodegen`.

Wszystkie funkcje poza synchronizacją między urządzeniami i logowaniem przez Apple działają bez zmian (przycisk Apple wyjaśnia wtedy, czego brakuje; działa logowanie e-mailem i tryb bez konta).

## Logowanie (Apple, Google, e-mail)

Przy pierwszym uruchomieniu aplikacja pokazuje ekran logowania (przed wywiadem): **Zaloguj przez Apple**, **Zaloguj przez Google**, **E-mail i hasło** oraz **Kontynuuj bez konta**. Użytkownicy wersji sprzed logowania (ukończony wywiad) przechodzą od razu w tryb bez konta — zalogować się mogą w Profilu (awatar w lewym górnym rogu ekranu Dzisiaj).

Do czasu podpięcia serwera konta są **lokalne** (tylko na tym urządzeniu), a dane nauki synchronizują się jak dotąd przez iCloud, niezależnie od konta. Sesja i tokeny są w pęku kluczy (`AfterFirstUnlockThisDeviceOnly`), hasła kont e-mail tylko jako sól + PBKDF2-HMAC-SHA256 (600 000 iteracji). Architektura: `FluentNOW/Services/Auth/` (`AuthService` — protokół pod przyszły backend, `LocalAuthService`, `AuthController`); miejsca do podmiany oznaczone w kodzie komentarzem `BACKEND:`.

### Zaloguj przez Apple

1. Wymaga **płatnego** konta Apple Developer. Uprawnienie `com.apple.developer.applesignin` jest już w `project.yml` — po `xcodegen` w *Signing & Capabilities* pojawi się sekcja **Sign in with Apple**; automatyczne podpisywanie włączy ją dla identyfikatora `pl.fluentnow.app`.
2. Na urządzeniu/symulatorze musisz być zalogowany do Apple ID (*Ustawienia* → Twoje imię).
3. Bez uprawnienia (konto darmowe) przycisk Apple pokazuje komunikat zamiast błędu systemu.
4. Przed wydaniem z backendem: serwer musi weryfikować `identityToken` i przy usuwaniu konta unieważniać tokeny (`appleid.apple.com/auth/revoke`, wymaga klucza *Sign in with Apple* i sekretu klienta — tylko po stronie serwera).

### Zaloguj przez Google (bez SDK)

Logowanie działa przez OAuth 2.0 z PKCE w przeglądarce systemowej (`ASWebAuthenticationSession`). Bez konfiguracji przycisk pokazuje „Logowanie Google będzie dostępne po konfiguracji”.

1. [Google Cloud Console](https://console.cloud.google.com) → utwórz projekt → *APIs & Services* → *OAuth consent screen*: typ **External**, nazwa aplikacji, e-mail kontaktowy, zakresy `openid`, `email`, `profile`. W trybie *Testing* dodaj swoje konto do *Test users*.
2. *Credentials* → *Create credentials* → *OAuth client ID* → typ **iOS**, *Bundle ID* `pl.fluentnow.app`. Skopiuj *Client ID* (kończy się na `.apps.googleusercontent.com`). Sekret klienta nie jest potrzebny.
3. W `project.yml` → target `FluentNOW` → `settings.base.FLUENT_GOOGLE_CLIENT_ID` wpisz ten identyfikator i uruchom `xcodegen` (albo ustaw `FLUENT_GOOGLE_CLIENT_ID` w *Build Settings* targetu — *User-Defined*).
4. Gotowe: adres powrotu `com.googleusercontent.apps.<część-przed-.apps.googleusercontent.com>:/oauth2redirect` jest wyliczany z identyfikatora i przechwytywany przez `ASWebAuthenticationSession` — nie trzeba go dodawać do *URL Types*.

### E-mail i hasło

Działają od razu, lokalnie: rejestracja, logowanie, „Nie pamiętam hasła” (bez serwera hasła nie da się przypomnieć mailem — aplikacja proponuje ustawienie nowego hasła, co zakłada konto lokalne od nowa; słówka i postęp zostają). W buildach **Debug** istnieje konto testowe `admin@admin.pl` / `admin` (podpowiedź na ekranie logowania); w buildach Release ten kod nie istnieje.

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
| *Provisioning profile doesn't include the iCloud / aps-environment / com.apple.developer.applesignin entitlement* | Konto darmowe → [Bez płatnego konta](#bez-płatnego-konta-tylko-lokalnie). Konto płatne → w *Signing & Capabilities* odznacz i zaznacz ponownie kontener, poczekaj na odświeżenie profilu. |
| *Multiple commands produce …/index.json* | Treść została dodana jako grupa zamiast referencji folderowej. Nie dodawaj plików z `Resources/Content` ręcznie w Xcode; uruchom `xcodegen`. |
| `No such module 'FluentKit'` | *File → Packages → Reset Package Caches*, potem ⇧⌘K i ⌘B. |
| Błędy dot. `glassEffect`, `Tab`, `tabBarMinimizeBehavior` | Używasz Xcode starszego niż 26. Zaktualizuj Xcode (kod obsługuje iOS 17 w czasie działania, ale wymaga SDK iOS 26 do kompilacji). |
| Przycisk Google: „dostępne po konfiguracji” | Pusty `FLUENT_GOOGLE_CLIENT_ID` — patrz [Zaloguj przez Google](#zaloguj-przez-google-bez-sdk). Błąd `redirect_uri_mismatch`/`invalid_client`: klient musi być typu **iOS** z bundle ID `pl.fluentnow.app`. |
| Apple: „Nie udało się zalogować… zalogowany do Apple ID” | Zaloguj się do Apple ID w Ustawieniach urządzenia/symulatora. |
| Podgląd (`#Preview`) nie działa | *Editor → Canvas*, wybierz symulator iOS 17+ jako cel podglądu; ⌥⌘P odświeża. W razie błędu: *Product → Clean Build Folder*. |
| Brak synchronizacji między urządzeniami | Oba urządzenia: ten sam Apple ID, iCloud Drive włączony, aplikacja zbudowana z tym samym kontenerem i środowiskiem (Debug = Development). Status widać w Ustawieniach aplikacji. Synchronizacja CloudKit bywa opóźniona o kilkadziesiąt sekund. |
| Symulator: „iCloud niedostępny” | Normalne bez zalogowanego konta — zaloguj się w *Ustawieniach* symulatora albo testuj lokalnie. |
| Ikona się nie odświeża | Usuń aplikację z symulatora/urządzenia i zainstaluj ponownie (system buforuje ikony). Ikonę generuje `node design/make-app-icon.mjs`. |
