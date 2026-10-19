# Runda 5 — uwagi właściciela

Wymagania właściciela — pierwszeństwo przed wcześniejszymi decyzjami.

## J1. Nowe ćwiczenia się nie pokazują (agent: study-access)
Diagnoza koordynatora: `SessionBuilder.allowedTaskTypes` odblokowuje rozsypankę dopiero po rozpoznaniu ×2 (osobne dni przy FSRS) i przypominaniu, a słuchanie jeszcze później; dopasuj pary wymaga ≥2 poprawnych rozpoznań. U nowego użytkownika pojawiają się po wielu dniach. **Ma być:**
- Wcześniejsze wprowadzenie: „Dopasuj pary” i „Zrozum ze słuchu” od pierwszego poprawnego rozpoznania (to zadania rozpoznawcze), „Ułóż zdanie” po pierwszym poprawnym rozpoznaniu lub przypominaniu; zachowaj sensowną różnorodność (żadna sesja nie składa się z samego „Wybierz znaczenie”). Zaktualizuj testy progresji z uzasadnieniem.
- Na ekranie Nauka sekcja **„Ćwicz wybrany typ”**: kafelki dla każdego typu ćwiczenia słówek (Wybierz znaczenie, Przypomnij sobie, Uzupełnij lukę, Ułóż zdanie, Dopasuj pary, Zrozum ze słuchu, Dyktando; „Słowo i zdjęcie” wyszarzone „W budowie”) → krótka sesja (5/10 min) tylko z tym typem dla słów, dla których da się go zbudować (wymagalne → znane → nowe); gdy brak słów — jasny komunikat.

## J2. Polecane słówka (agent: study-access)
- Usuń sekcję polecanych słówek z ekranu **Dzisiaj** (zostają w Słowniku → Polecane). Zostaw najwyżej dyskretny link „Polecane słówka” na Dzisiaj, jeśli pasuje do układu — albo nic.
- W Słowniku → Polecane: **bez nieskończonego przewijania** — strony po ~6–8 słów przewijane poziomo (swipe, `TabView` w stylu `.page` z kropkami lub własny pager), maks. kilka stron; przycisk **„Odśwież propozycje”** losuje nowy zestaw (z tej samej puli rankingu, z pominięciem już pokazanych w tym tygodniu); zaznaczanie i dodawanie bez zmian.

## J3. Logowanie i panel użytkownika (agent: auth-profile)
- **Ekran logowania** przy pierwszym uruchomieniu (przed wywiadem z FEEDBACK-2 G4): „Zaloguj przez Apple”, „Zaloguj przez Google”, „E-mail i hasło” (logowanie + rejestracja + „Nie pamiętam hasła”), oraz „Kontynuuj bez konta” (tryb gościa, dane lokalne/iCloud jak teraz).
- **Architektura pod przyszły backend** (baza zostanie podpięta później): protokół `AuthService` z dostawcami; sesja (identyfikator, e-mail, nazwa, dostawca, token) w Keychain; wylogowanie; usunięcie konta (wymóg App Store przy logowaniu). Dane nauki na razie nadal lokalne/iCloud, przypisane do urządzenia — zaznacz w kodzie miejsca, gdzie backend przejmie synchronizację.
  - **Apple:** natywnie `AuthenticationServices` (`SignInWithAppleButton`), entitlement „Sign in with Apple” w `project.yml` (opisz w README, że wymaga płatnego konta deweloperskiego; bez niego przycisk pokazuje komunikat).
  - **Google:** bez zewnętrznego SDK — OAuth 2.0 PKCE przez `ASWebAuthenticationSession`; identyfikator klienta z konfiguracji (puste → przycisk pokazuje „Logowanie Google będzie dostępne po konfiguracji”); instrukcja konfiguracji w README.
  - **E-mail:** do czasu backendu lokalny dostawca. **Konto testowe tylko w buildach DEBUG** (`#if DEBUG`): `admin@admin.pl` / `admin` — nigdy w wydaniu; w DEBUG mała podpowiedź na ekranie logowania. Hasła lokalnych kont tylko jako hash z solą w Keychain, nigdy jawnie.
- **Panel użytkownika** (nowa zakładka „Profil” albo wejście z ekranu Dzisiaj przez awatar — wybierz najlepsze dla 5 kart; najlepiej awatar w nagłówku Dzisiaj → arkusz/ekran Profil): awatar, nazwa (edytowalna), e-mail/dostawca, poziom i ranga z XP (FEEDBACK-2 G5), statystyki skrótowe, profil nauki (link do istniejącego), Ustawienia, Wyloguj, Usuń konto.
- **Personalizacja odblokowywana poziomem:** ikony awatara (SF Symbols, np. 20–30 do odblokowania co 1–3 poziomy) i kolory/motywy akcentu awatara (np. 8–12, w tym gradienty na wyższych poziomach); zablokowane widoczne z kłódką i „Poziom N”; wybór zapisany w profilu (synchronizowany). Opcjonalnie odznaki za osiągnięcia (seria 7 dni, 100 słów…), jeśli tanio.
