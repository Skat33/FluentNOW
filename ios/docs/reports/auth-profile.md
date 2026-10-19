# Raport: auth-profile (FEEDBACK-5 J3 — logowanie i panel użytkownika)

Kod napisany na Windows **bez kompilatora**. API Apple sprawdziłem w dokumentacji (JSON developer.apple.com): `SignInWithAppleButton(_:onRequest:onCompletion:)` + `signInWithAppleButtonStyle(_:)` (iOS 14), SwiftUI `WebAuthenticationSession` z `\.webAuthenticationSession` (iOS 16.4): `authenticate(using:callbackURLScheme:preferredBrowserSession:)` (przestarzałe, ale dostępne) i `authenticate(using:callback:preferredBrowserSession:additionalHeaderFields:)` + `ASWebAuthenticationSession.Callback.customScheme(_:)` (iOS 17.4), `BrowserSession.ephemeral`. Każdą sygnaturę z innych plików sprawdziłem grepem. Skrypt `scratchpad/auth-check.mjs` (nawiasy z interpolacją, łańcuchy, BOM/CR, `try!`/`as!`/`fatalError`): **34 pliki, 0 problemów**. Kolizje nazw typów (aplikacja + FluentKit + testy): brak. Gita nie uruchamiałem.

## 1. Co zrobiono (pliki)

**FluentKit (nowe, `public` + jawne `public init`)**
- `Profile/LearnerAvatar.swift` — `LearnerAvatar { symbol, color, nickname?, updatedAt }`: tolerancyjne dekodowanie, `normalized()`, `cleanNickname(_:)` (jedna linia, ≤ 40 znaków), `newer(_:_:)`.
- `Profile/AvatarCatalog.swift` — **czysta funkcja „co jest odblokowane na poziomie N”**: 30 ikon SF Symbols (4 od startu, potem nowa co 1–3 poziomy do poziomu 40), 13 kolorów (gradienty od poziomu 15: Zorza 15, Zmierzch 20, Las 25, Galaktyka 30, Złoto 40). `unlocked(atLevel:) -> AvatarUnlocks` (+ `nextSymbol/nextColor/nextUnlockLevel`), `isUnlocked(symbol:atLevel:)`, `isUnlocked(color:atLevel:)`, `newlyUnlocked(fromLevel:toLevel:)`, `resolved(_:level:)` (zablokowany/nieznany wybór → domyślny, zapisany wybór zostaje), `stops(forColor:)`.
- `Profile/ProfileAchievements.swift` — odznaki (tanie, liczone z historii): pierwsze słowo, 100/500 słów, seria 7/30 dni (**najdłuższa**, więc odznaka nie znika), 50/250 opanowanych znaczeń, 10 czytanek, poziom 10. `evaluate(_:)`, `input(from:)`, `longestStreak(days:)`.

**FluentKit (zmiany addytywne, wstecznie zgodne)**
- `Models/LearnerSettings.swift` — `public var avatar: LearnerAvatar?` (ostatni parametr `init` = `nil`, klucz `avatar`, `lenientOptional`). Brak awatara → klucz pominięty w JSON.
- `Sync/StateSync.swift` — `merged.settings.avatar = LearnerAvatar.newer(local, remote)` (osobno od profilu nauki).
- `ImportExport/StateMigration.swift` — `settings.avatar?.normalized()`.
- Testy: `Tests/FluentKitTests/AvatarCatalogTests.swift` (13).

**Aplikacja — `Services/Auth/` (nowe)**
- `AuthModels.swift` — `AuthProviderKind`, `AuthSession` (Codable, `description` bez tokenów i e-maila), `AuthStatus` (`loading/signedOut/guest/signedIn`), `AppleIdentity`, `GoogleIdentity`, `PasswordResetOutcome`, `AuthError` (polskie opisy), `PasswordPolicy` (≥ 8 znaków), `EmailAddress.normalized`.
- `AuthCrypto.swift` — `SecRandomCopyBytes`, base64url, SHA-256 (CryptoKit), **PBKDF2-HMAC-SHA256 przez CommonCrypto** (`CCKeyDerivationPBKDF`, 600 000 iteracji, sól 16 B, klucz 32 B), porównanie w stałym czasie.
- `AuthSecretStore.swift` — protokół `AuthSecretStore`; `KeychainAuthSecretStore` (na `KeychainStore` platform-services, usługa `pl.fluentnow.app.auth`, `AfterFirstUnlockThisDeviceOnly`, bez synchronizacji); `InMemoryAuthSecretStore` (testy/podglądy); `AuthSessionVault` (wpis `session`).
- `AuthService.swift` — **protokół `AuthService`** (kontrakt pod backend) + `LocalAuthService` (konta e-mail: sól + skrót PBKDF2; nazwa wpisu = SHA-256 adresu; zapamiętana tożsamość Apple; konto testowe DEBUG). Miejsca backendu oznaczone `BACKEND:`.
- `GoogleOAuth.swift` — `GoogleOAuthConfiguration` (z Info.plist `FluentGoogleClientID`), PKCE S256, `state`, `nonce`, URL autoryzacji, walidacja powrotu, żądanie tokenu (bez sekretu), odczyt `id_token` (sprawdzane `aud`, `iss`, `exp`, `nonce`), wymiana kodu (URLSession).
- `AppleSignIn.swift` — wykrycie uprawnienia `com.apple.developer.applesignin` (jak `CloudKitAvailability`: profil / sekcja `__entitlements` w symulatorze / App Store), poświadczenie → `AppleIdentity`, mapowanie błędów (anulowanie bez komunikatu), `getCredentialState` przy starcie.
- `AuthController.swift` — `@MainActor @Observable`: stan, start, gość, Apple (nonce SHA-256), Google (`WebAuthenticationSession`, sesja efemeryczna), e-mail, reset, wylogowanie, usunięcie konta.

**Aplikacja — `Features/Auth/` (nowe)**: `AuthWelcomeScreen.swift` (logo, Apple, Google, „E-mail i hasło”, „Kontynuuj bez konta”, komunikaty, podpowiedź DEBUG), `AuthEmailSheet.swift` (logowanie / rejestracja / „Nie pamiętam hasła”).

**Aplikacja — `Features/Profile/` (nowe)**: `ProfileScreen.swift` (arkusz z własnym `NavigationStack`, `ProfileRoute`, `ProfileSnapshot` liczony w `store.compute`), `ProfileSections.swift` (nagłówek z awatarem i edycją nazwy, karta poziomu i rangi z najbliższą nagrodą, 4 kafelki statystyk, odznaki, skróty: profil nauki / Postępy / Ustawienia), `ProfileAccountSection.swift` (gość → „Zaloguj się lub załóż konto”; zalogowany → Wyloguj, Usuń konto), `AvatarPickerScreen.swift` (siatki ikon i kolorów; zablokowane z kłódką i „Poziom N”), `ProfileAvatarView.swift` (`ProfileAvatarView`, `ProfileAvatarButton`, `ProfileAvatarPalette`).

**Aplikacja — `App/`**
- `AuthGate.swift` (nowy) — `loading` → tło; `signedOut` → `AuthWelcomeScreen`; `guest/signedIn` → aplikacja.
- `FluentNOWApp.swift` — `AuthGate { RootView() }` i `.task { await environment.auth.bootstrap(hasExistingInstall: preferences.hasCompletedOnboarding) }`.
- `AppEnvironment.swift` — `let auth: AuthController` (parametr `init` `auth: AuthController? = nil` → gość w pamięci; `live()` → `AuthController.live()`), `.environment(environment.auth)` w `fluentEnvironment`.
- `AppRouter.swift` — `AppSheet.profile` + `presentProfile()`; `RootView.swift` — `case .profile: ProfileScreen()`.

**Inne**
- `Features/Today/TodayRootScreen.swift` — **tylko pasek**: `ToolbarItem(placement: .topBarLeading) { ProfileAvatarButton() }` (zmiana study-access w tym pliku zachowana — sprawdzone).
- `project.yml` — entitlement `com.apple.developer.applesignin: [Default]`, ustawienie `FLUENT_GOOGLE_CLIENT_ID: ""`, klucz Info.plist `FluentGoogleClientID: $(FLUENT_GOOGLE_CLIENT_ID)`; te same zmiany w `FluentNOW/FluentNOW.entitlements` i `FluentNOW/Info.plist`.
- `README.md` — sekcja „Logowanie (Apple, Google, e-mail)” (konfiguracja Apple i Google krok po kroku, konto testowe), poprawiona instrukcja „Bez płatnego konta” (blok entitlements do `- Default`), 2 wiersze w „Rozwiązywaniu problemów”.
- `FluentNOWTests/Auth/AuthTests.swift` (nowy, 27 testów).

## 2. Architektura

```
AuthGate (App)            AuthWelcomeScreen / AuthEmailSheet / ProfileScreen (UI)
      │                                  │
      └──────── AuthController (@MainActor @Observable, env.auth) ────────┐
                 │ status, isWorking, google, isAppleSignInAvailable      │
                 ├─ any AuthService ── LocalAuthService (dziś)            │
                 │                     RemoteAuthService (BACKEND, potem) │
                 ├─ AuthSessionVault ── AuthSecretStore ── Keychain       │
                 ├─ AppleSignIn (AuthenticationServices)                  │
                 └─ GoogleOAuth (PKCE, WebAuthenticationSession/URLSession)
```

- **Kolejność ekranów:** logowanie → (gość lub konto) → aplikacja; ekran Dzisiaj przy pustym słowniku pokazuje wywiad G4 jak dotąd. Użytkownik wersji sprzed logowania (`hasCompletedOnboarding == true`) przy pierwszym starcie po aktualizacji przechodzi od razu w tryb gościa — nie zaskakujemy go ekranem logowania; zalogować się może w Profilu.
- **Sesja** (identyfikator `apple:/google:/email:`, e-mail, nazwa, dostawca, tokeny, `expiresAt`, `isLocalOnly`) wyłącznie w pęku kluczy. W UserDefaults tylko flagi bez danych osobowych: `fluent.auth.guest` (znika z „Usuń wszystkie dane”) i `auth.installMarker` (pęk kluczy przeżywa usunięcie aplikacji — po ponownej instalacji sesja jest czyszczona, żeby nie „wracać zalogowanym”). Nic z logowania nie trafia do eksportu JSON.
- **Hasła:** tylko sól (16 B) + PBKDF2-HMAC-SHA256 (600 000 iteracji, zapisywane przy koncie), porównanie w stałym czasie; logowanie na nieistniejące konto wykonuje tę samą pracę i zwraca ten sam błąd (nie zdradzamy, czy konto istnieje). Haszowanie działa poza głównym wątkiem (`@Sendable` zadanie w `AuthController.perform`).
- **Konto testowe** `admin@admin.pl` / `admin`: kod i dane tylko w `#if DEBUG` (`LocalAuthService.DebugAccount`, podpowiedź `AuthDebugHint`). Konto jest zakładane przy pierwszej próbie logowania na ten adres — też jako sól + skrót w pęku kluczy, z flagą `isDebugSeed`. Build Release, który trafi na wpis z flagą (np. po wcześniejszym buildzie Debug na tym samym telefonie), odrzuca go i usuwa (`#if !DEBUG`).
- **Apple:** `SignInWithAppleButton` (styl czarny/biały wg motywu), zakresy imię + e-mail, nonce = SHA-256 losowego ciągu (surowy zostaje w pamięci dla backendu). Apple podaje e-mail i imię tylko raz — `LocalAuthService` zapamiętuje je w pęku kluczy. Przy starcie `getCredentialState`: cofnięta zgoda → wylogowanie (błąd/offline → bez zmian). Bez uprawnienia przycisk w tym samym stylu pokazuje komunikat (wymaga płatnego konta).
- **Google bez SDK:** OAuth 2.0 dla aplikacji natywnych (RFC 8252) z PKCE S256 (RFC 7636), `state` (CSRF), `nonce`, `prompt=select_account`; przeglądarka systemowa przez SwiftUI `WebAuthenticationSession` (to `ASWebAuthenticationSession` bez ręcznej kotwicy okna), sesja efemeryczna; iOS 17.4+ — `callback: .customScheme`, iOS 17.0–17.3 — `callbackURLScheme:`. Przekierowanie `com.googleusercontent.apps.<id>:/oauth2redirect` (klient typu iOS, bez sekretu). Pusty identyfikator → „Logowanie Google będzie dostępne po konfiguracji”.
- **E-mail:** logowanie, rejestracja (imię opcjonalne, powtórzenie hasła), „Nie pamiętam hasła”: bez serwera hasła nie da się przypomnieć — aplikacja wyjaśnia to i proponuje ustawienie nowego hasła (konto lokalne o tym adresie zakładane od nowa; dane nauki zostają, bo nie są przypisane do konta). BACKEND: `requestPasswordReset` → `.emailSent`.
- **Usunięcie konta (App Store 5.1.1(v))** w Profilu: „Usuń konto i dane nauki” (`store.deleteAllData()` → jak w Ustawieniach, potem konto) albo „Usuń tylko konto”; wylogowanie i powrót do ekranu logowania. Dla Apple dodatkowo informacja o cofnięciu dostępu w Ustawieniach iPhone’a; prawdziwe unieważnienie tokenów (`/auth/revoke`) wymaga serwera — oznaczone `BACKEND:`.
- **Panel użytkownika:** awatar w lewym górnym rogu Dzisiaj (`topBarLeading`) → arkusz `AppSheet.profile` (zostaje 5 kart). Wybór zakładki „Profil” odrzuciłem: szósta karta zepchnęłaby Ustawienia do „Więcej” na iPhonie.
- **Personalizacja:** `settings.avatar` jest synchronizowany jak reszta ustawień (iCloud, eksport JSON), scalany po własnym `updatedAt` — **osobno od `LearnerProfile`**, bo zmiana `profile.updatedAt` ponownie stosuje domyślne tryby/czas na ekranie Nauka (`StudyHomeView.applyProfileDefaults`). Pseudonim (`nickname`) też jest w awatarze (synchronizowany); pusty → nazwa z konta → „Gość”/„Uczeń”.
- **Dane nauki** zostają lokalne/iCloud, przypisane do urządzenia. Punkt zaczepienia pod synchronizację z kontem: `AuthController.didSignIn(_:)` (komentarz `BACKEND:`).

## 3. Co działa bez backendu / co wymaga konfiguracji

| Funkcja | Bez konfiguracji | Wymaga |
|---|---|---|
| Kontynuuj bez konta | ✓ | — |
| E-mail i hasło (lokalne), reset przez nowe hasło | ✓ | — |
| Konto testowe admin@admin.pl / admin | ✓ tylko Debug | — |
| Zaloguj przez Apple | komunikat | płatne konto Apple Developer (uprawnienie już w `project.yml`), Apple ID na urządzeniu |
| Zaloguj przez Google | komunikat „dostępne po konfiguracji” | klient OAuth typu iOS → `FLUENT_GOOGLE_CLIENT_ID` (README) |
| Profil, awatar, odznaki, poziom | ✓ | — |
| Wyloguj / Usuń konto (lokalnie) | ✓ | unieważnienie tokenów Apple/Google i usunięcie danych na serwerze — backend |

## 4. Odstępstwa od strony
Strona nie miała logowania ani profilu — wszystko nowe. Profil jako arkusz zamiast karty (uzasadnienie wyżej).

## 5. Ryzyka kompilacji / niesprawdzone (gdzie patrzeć na Macu)

1. `AuthCrypto.pbkdf2`: `CCKeyDerivationPBKDF(CCPBKDFAlgorithm(kCCPBKDF2), …, CCPseudoRandomAlgorithm(kCCPRFHmacAlgSHA256), UInt32(iterations), …)` i `status == Int32(kCCSuccess)`; wskaźnik hasła przez `UnsafeRawPointer(...)?.assumingMemoryBound(to: CChar.self)`. Gdyby typy stałych się nie zgadzały — rzutowania są w jednym miejscu. Wektory testowe (RFC 6070-podobne dla SHA-256) w `AuthCryptoTests`.
2. `AuthController.authenticate`: przestarzałe `authenticate(using:callbackURLScheme:preferredBrowserSession:)` w gałęzi < 17.4 — ostrzeżenie, nie błąd. `ASWebAuthenticationSessionError` / `ASAuthorizationError` jako typy błędów Swift (`.code == .canceledLogin` / `.canceled`).
3. `AuthWelcomeScreen`: `SignInWithAppleButton(.signIn) { request in } onCompletion: { result in }` z jawnymi typami domknięć; `Task { @MainActor in … }` w `onCompletion`. `#if DEBUG` wewnątrz `VStack` (ViewBuilder — dozwolone).
4. `AuthEmailSheet`: `Picker` `.segmented` w `Form`, `@FocusState` z enumem, `.textContentType(UITextContentType?)` w trójargumentowym operatorze z jawnymi typami.
5. `AuthController`: domknięcia `@Sendable` z listą przechwytywania `[service]` (praca poza głównym wątkiem); `@ObservationIgnored` na `let` (jak w `AppPreferences`).
6. `AppleSignIn`: kopia odczytu `__TEXT,__entitlements` z `CloudKitAvailability` (tamta funkcja jest `private`); `CloudKitAvailability.provisioningPlist(from:)` używane bezpośrednio.
7. `AuthControllerTests` jest `@MainActor` i **nie** nadpisuje `setUp`/`tearDown` (izolacja) — domeny UserDefaults sprzątane przez `addTeardownBlock`.
8. **Nie oglądane na urządzeniu:** awatar w pasku na iOS 26 (system może otoczyć go kapsułą szkła — tylko wygląd), wysokość/zaokrąglenie przycisku Apple, przejście bramki (`.transition(.opacity)` w `ZStack`).
9. Eksport JSON zawiera `settings.avatar`, gdy ustawiony (jak `profile`). Strona tylko do odczytu — przy ścisłej walidacji ustawień na stronie import mógłby odrzucić klucz (niesprawdzone, to samo ryzyko co dla `profile`).
10. **Podpisywanie:** nowy entitlement Sign in with Apple — konto darmowe musi zakomentować cały blok `entitlements:` (README zaktualizowane); bez tego podpis się nie powiedzie (tak samo jak dla iCloud).
11. Po `xcodegen` potrzebne regenerowanie projektu (nowe katalogi `Services/Auth`, `Features/Auth`, `Features/Profile`, `FluentNOWTests/Auth`).

## 6. Prośby do innych ról
- **platform-services:** (opcjonalnie) wydzielić odczyt uprawnień z `CloudKitAvailability` do wspólnej funkcji `Entitlements.current()` — wtedy `AppleSignIn.computeEntitlement` przestanie duplikować kod sekcji `__entitlements`.
- **ui-library (Ustawienia):** (opcjonalnie) wiersz „Konto” na górze Ustawień otwierający `router.presentProfile()`. „Usuń wszystkie dane” nie wylogowuje (konto ≠ dane) — zamierzone.
- **study-polish / ui-learning:** po awansie można pokazać „Nowa ikona awatara!” przez `AvatarCatalog.newlyUnlocked(fromLevel: gain.levelBefore, toLevel: gain.levelAfter)` w podsumowaniu sesji (`StudySummaryXP`).
- **koordynator / backend:** zastąpić `LocalAuthService` implementacją `RemoteAuthService` (te same metody `AuthService`); weryfikacja podpisu `identityToken` Apple i `id_token` Google, unieważnianie tokenów przy usuwaniu konta, synchronizacja danych w `AuthController.didSignIn`.

## 7. Testy
Nieuruchomione (brak Swifta na Windows).
- **FluentKit `AvatarCatalogTests` (13):** kształt katalogu (unikalność, sortowanie, 20–30 ikon, 8–14 kolorów, gradienty ≥ poziomu 15, domyślne odblokowane na 1), przerwy ≤ 3 poziomy, „co odblokowane na poziomie N” (1, 10, ≤ 0, 100), monotoniczność 1…50, zablokowane/nieznane id, `newlyUnlocked`, `resolved` z zachowaniem pseudonimu, round-trip w ustawieniach + stare ustawienia bez klucza + uszkodzony/niepełny awatar, normalizacja (pseudonim, puste id, NaN) i migracja, scalanie (nowszy wygrywa, niezależnie od profilu, `nil` nie kasuje), najdłuższa seria, postęp odznak, wejście odznak z historii.
- **Aplikacja `FluentNOWTests/Auth/AuthTests.swift` (27):** PBKDF2 (wektory 1 i 4096 iteracji), stały czas, losowość, base64url; e-mail i zasady hasła; `description` bez sekretów; rejestracja → logowanie; ten sam błąd dla złego hasła i braku konta; walidacja i duplikaty; reset przez nowe konto; **hasło nigdy jawnie** (brak hasła i adresu w pęku kluczy, algorytm, sól); usunięcie konta; Apple pamięta e-mail/imię; konto DEBUG (tylko skrót, wielkość liter); Google: konfiguracja i schemat, **wektor PKCE z RFC 7636**, parametry URL (bez sekretu), walidacja `state`/błędu/schematu, ciało żądania tokenu, `id_token` (`aud`, `nonce`, wygaśnięcie, dekodowanie odpowiedzi); kontroler: świeża instalacja → logowanie, dotychczasowy użytkownik → gość, zapamiętany gość, sesja w pęku kluczy po restarcie i nic osobowego w UserDefaults, wylogowanie, komunikaty błędów, czyszczenie sesji po ponownej instalacji, usunięcie konta.
- Skrypt `auth-check.mjs`: 34 pliki, 0 problemów.
