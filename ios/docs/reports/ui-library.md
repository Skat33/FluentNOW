# Raport: ui-library (fala 2)

Obszar: `ios/FluentNOW/Features/{Today,Words,AddWord,Topics,Collections,Stats,Settings}/`.
Kod napisany na Windows **bez kompilatora** — pierwsza kompilacja na Macu. Wszystkie sygnatury FluentKit, Services i DesignSystem sprawdzone grepem w kodzie (nie tylko w dokumentach).

## 1. Co zrobiono (pliki)

Usunięte zaślepki: `TodayRootPlaceholder`, `WordsRootPlaceholder`, `AddWordRootPlaceholder`, `TopicsRootPlaceholder`, `CollectionsRootPlaceholder`, `StatsRootPlaceholder`, `SettingsRootPlaceholder` (zaślepka `Study` należy do ui-learning — nietknięta).

**Today/**
- `TodayRootScreen.swift` — korzeń karty: stany ładowania (szkielet), błędu wczytania, onboardingu, pusty, treść; baner błędu zapisu (`lastSaveError` + „Spróbuj ponownie” → `retryFailedSave()`); haptyka „cel osiągnięty”; rejestruje trasy Słownika (push szczegółów słowa/kolekcji w karcie Dzisiaj).
- `TodaySnapshot.swift` — migawka ekranu liczona w `store.compute` (cel dzienny, przegląd, tydzień, kolekcje w toku, ostatnio dodane, sesja do wznowienia, rekomendacje).
- `TodayHeroCard.swift` — fioletowa karta sesji (`HeroBackground` + `ProgressRing`), „Zaczynam naukę” → `router.startStudy(.daily)` lub „Wznów sesję” → `.resumeLast`; układ pionowy przy rozmiarach dostępności; `TodayStatsGrid` (powtórki, seria, słownik, opanowane).
- `TodayWeekCard.swift` — „Twój tydzień” (Swift Charts, linia celu, etykiety VoiceOver). Używany też w Postępach.
- `TodaySections.swift` — „Gotowość na krok dalej?” (`LevelEstimator.recommendations` + `lookup(for:)` → `mergeSuggestions`), „Twoje kolekcje”, „Ostatnio dodane”.
- `TodayOnboardingView.swift` — pierwsze uruchomienie: poziom CEFR + 1–3 tematy → dodanie w tle (`TopicAdder`, do 30 najczęstszych wpisów na temat, poziom ≤ wybrany+1) → `hasCompletedOnboarding = true` → `startStudy(.daily)`; „Pomiń”.

**Words/**
- `WordsRootScreen.swift` — segmenty Słowa/Kolekcje/Tematy (`router.librarySection`), `QuickAddButton`, `.libraryNavigationDestinations()`, konsumpcja `consumeLibraryDestination()` → push trasy.
- `LibraryRoutes.swift` — `WordRoute`, `CollectionRoute`, `TopicRoute` + `View.libraryNavigationDestinations()`.
- `WordListModel.swift` — filtr/sortowanie/sekcje, `WordListBuilder.build` (czysta funkcja, w `compute`).
- `WordListView.swift` — `List` + `.searchable` (PL/EN/tagi, bez diakrytyków), debounce 180 ms, wyniki poza głównym wątkiem, przesunięcia (wymowa, trudne, archiwum), menu kontekstowe, szkielet `redacted`, stan pusty i „brak wyników”, „Ćwicz kolekcję” przy filtrze kolekcji.
- `WordFilterBar.swift` — chipy statusu (Wszystkie, Nowe, Uczę się, Trudne, Opanowane, Do odświeżenia, Ważne, Archiwum) + menu (sortowanie, poziom, kolekcja).
- `WordRowView.swift` — wiersz + `WordStatusLabel` (ikona + tekst).
- `WordDetailScreen.swift`, `WordDetailSections.swift`, `WordHistoryCard.swift` — szczegóły: nagłówek (IPA, wymowa normalna/wolna, poziom, status, kolekcja, tagi), znaczenia z 5 `SkillBar` („—” dla niećwiczonych), przykłady z tłumaczeniem i pogrubieniem (`VocabularyGrader.examplePair` + `HighlightedText`, „Pokaż wszystkie”), formy/kolokacje/synonimy/antonimy/notatka/źródło, następna powtórka, historia 20 ostatnich odpowiedzi (liczona w `compute`); menu: edytuj, ważne, trudne, archiwizuj/przywróć, usuń (dialog z alternatywą „Archiwizuj zamiast tego”).
- `WordDraft.swift`, `WordEditorSheet.swift` — edytor w arkuszu `.large`: wiele znaczeń, przykłady (EN/PL/fragmenty wyróżnione), rejestr, część mowy, poziom, kolekcja (pole + menu istniejących), tagi; walidacja na bieżąco (sekcja „Do poprawienia”), „Zapisz” nieaktywny przy błędach/bez zmian, `interactiveDismissDisabled` + pytanie przy „Anuluj”; bezpieczne powiązania tablic (bez crasha po usunięciu elementu).
- `WordMutations.swift` — archiwum/trudne/ważne/usuń/zastąp (zawsze `updatedAt`).
- `LibraryText.swift` — polska odmiana liczebników (słowo/słowa/słów…).

**AddWord/**
- `AddWordRootScreen.swift` — arkusz z własnym `NavigationStack`: pole (EN/PL) → `ContentLibrary.search` z debounce (i jedną ponowną próbą, gdy indeks się jeszcze buduje) → propozycje zgrupowane po haśle → `ContentLibrary.lookup` → wybór znaczeń (**żadne nie jest zaznaczone automatycznie**, znane oznaczone „już w słowniku” i zablokowane) → „Dodaj” (`mergeSuggestions`, `.bulk`). Brak w bazie → „Zapytaj asystenta AI” (gdy `activeProvider != .offline`) lub „Dodaj ręcznie”. Wybór kolekcji („Automatycznie” lub istniejąca). Podsumowanie „Dodano 2 znaczenia słowa „x” do kolekcji „Lotnisko”.” i arkusz zostaje otwarty na kolejne słowo. Detenty `.medium` → `.large` po wynikach; `interactiveDismissDisabled` przy zaznaczeniach/wpisanych danych.
- `AddWordModel.swift` — `AddWordCandidate.group`, `AddWordManualDraft` (walidacja, `lookup(collection:)`), `AddWordLogic` (znane znaczenia, sanityzacja propozycji AI, scalanie z podsumowaniem, źródło „Dodane ręcznie”).
- `AddWordSections.swift` — pole, propozycje, wybór znaczeń (z badge „Propozycja AI” i edycją propozycji przed dodaniem), formularz ręczny, wybór kolekcji.

**Topics/**
- `TopicsRootScreen.swift` — indeks z `topicIndex()`, grupy, `.searchable` (także `aliases` przez `TopicSummary.matches`), siatka adaptacyjna, licznik już dodanych wpisów na temat, szkielet, `ErrorBanner` z ponowieniem.
- `TopicCard.swift` — ikona SF Symbol, PL/EN, opis, `CEFRDistributionBar` (kolory CEFR + tekst + etykieta VoiceOver).
- `TopicDetailScreen.swift`, `TopicEntriesList.swift` — kategorie, wpisy (tłumaczenie, poziom, „już w słowniku”), chipy poziomów (filtr „tylko A2–B1”), „Zaznacz widoczne”, zaznacz/odznacz kategorię, podgląd wpisu.
- `TopicEntryPreviewSheet.swift` — wymowa, tłumaczenie, definicja, przykłady z odsłuchem, formy, kolokacje…; zaznaczanie z arkusza.
- `TopicAdder.swift` — dodawanie **w tle, partiami po 25** (każda partia liczona `store.compute`, stosowana `update(.bulk)`; gdy w międzyczasie zmienił się `revision` — przeliczana na bieżącym stanie, nic nie ginie); postęp 0…1; kolejność słów jak w temacie.
- `TopicAddBar.swift` — „Dodaj N słów do nauki”, pasek postępu, podsumowanie + „Ćwicz teraz” (`startStudy(… collection: temat)`).

**Collections/**
- `CollectionsRootScreen.swift` — karty kolekcji (postęp, słowa, do powtórki, nowe), „Nowa kolekcja”, baner „Podobne słowa, inna historia” (`ConfusableDetector.itemsWithPartners`, sesja `pairs`).
- `CollectionDetailScreen.swift` — pierścień postępu, „Ćwicz tę kolekcję” → `startStudy(StudyLaunchRequest(modes: ["mixed"], collection:))`, lista słów, zmiana nazwy, usunięcie (słowa zostają).
- `CollectionModel.swift` — podsumowania (`ProgressStatistics.collectionProgress`), `CollectionMutations` (create/rename/delete, walidacja nazwy).
- `CollectionNameAlert.swift` — alert z polem nazwy i walidacją.

**Stats/**
- `StatsRootScreen.swift` — przegląd, szacowany poziom CEFR z uczciwym opisem pewności, tydzień, kalendarz, „Warto do nich wrócić” (trudne słowa → szczegóły; „Przećwicz pomyłki” → `startStudy(.mistakes)`), umiejętności, postęp wg poziomu, przyrost opanowanych, prognoza, czytanie i gramatyka.
- `StatsSnapshot.swift` — jedna migawka z `ProgressStatistics.*` + `LevelEstimator` (w `compute`, przeliczana na `revision`).
- `StatsCharts.swift` — heatmapa 12 tygodni (własna siatka + legenda + jedna etykieta VoiceOver), przyrost tygodniowy (8 tyg.) i prognoza 7 dni (Swift Charts z etykietami dostępności).

**Settings/**
- `SettingsRootScreen.swift` — `Form` + `SettingsRoute` (voice, assistant, importData, exportData, about).
- `SettingsSections.swift` — cel dzienny, przypomnienie (prośba o zgodę, alert z linkiem do Ustawień systemu przy odmowie, `DatePicker` pory → `settings.reminder` „HH:mm”), wymowa (wolne tempo, „Wypróbuj głos”), motyw + wibracje (`AppPreferences`), status iCloud (`SyncMonitor`), dane (import/eksport, usuń wszystko: dialog + alert z wpisaniem „USUŃ”).
- `SettingsVoiceScreen.swift` — akcent (US/GB), lista głosów z odsłuchem (`availableVoices`, `preview(voice:)`), „Automatycznie”.
- `SettingsAssistantScreen.swift` — offline / Apple on-device (z powodem niedostępności) / Gemini: `SecureField`, „Połącz” (test + czytelny błąd), status, odłączenie; sekcja prywatności.
- `SettingsImportScreen.swift` — `fileImporter` (JSON/CSV/TSV/tekst, limit 8 MB, odczyt poza głównym wątkiem, UTF-8 z fallbackiem CP1250) lub wklejony tekst → podgląd (`previewImportJSON/Delimited`) → scal/zastąp (zastąpienie z potwierdzeniem) → podsumowanie.
- `SettingsExportScreen.swift` — `ShareLink` dla kopii JSON, CSV Anki, zgłoszeń błędów; usuwanie zgłoszeń.
- `SettingsAboutScreen.swift` — wersja, treści, prywatność (co trafia do Google przy Gemini), galeria komponentów tylko w `DEBUG`.

Każdy ekran ma `#Preview` na `fluentPreviewEnvironment()` (Dzisiaj także na `.previewEmpty` — onboarding).

## 2. Publiczne API / kontrakty (dla innych ról)

```swift
enum WordRoute: Hashable { case detail(id: String) }
enum CollectionRoute: Hashable { case detail(name: String) }
enum TopicRoute: Hashable { case detail(id: String) }
enum SettingsRoute: Hashable { case voice, assistant, importData, exportData, about }
extension View { func libraryNavigationDestinations() -> some View }   // raz na stos karty (Dzisiaj, Słownik, Postępy)

// Korzenie (kontrakt powłoki zachowany)
TodayRootScreen(), WordsRootScreen(), CollectionsRootScreen(), TopicsRootScreen(),
StatsRootScreen(), SettingsRootScreen(), AddWordRootScreen(prefill: String? = nil)

// Pomocnicze typy wewnętrzne modułu (mogą się przydać): WordDetailScreen(wordID:), WordEditorSheet(word:),
// CollectionDetailScreen(name:), TopicDetailScreen(topicID:),
// TopicAdder.add(topic:entryIDs:store:progress:) async -> TopicAddOutcome, LibraryText.words/meanings/count(_:one:few:many:)
```
Przejścia do nauki wyłącznie przez `router.startStudy(...)`: `.daily`, `.resumeLast`, `.mistakes`, `StudyLaunchRequest(modes: ["mixed"], collection:)`, `StudyLaunchRequest(modes: ["pairs"])`.

## 3. Odstępstwa od strony i dlaczego

1. **Usuwanie kolekcji** (strona nie miała): słowa zostają i trafiają do „Codzienne rozmowy” (lub „Inne”, gdy usuwana jest właśnie ta). Zmiana nazwy na istniejącą nazwę scala kolekcje.
2. **Usuwanie słowa** (strona miała tylko archiwum): dialog proponuje archiwizację zamiast usunięcia; historia odpowiedzi zostaje (seria i statystyki się nie zmieniają).
3. **Edycja:** zmiana tłumaczenia znaczenia czyści jego `acceptedTranslations`, zmiana hasła czyści `acceptedAnswers` (stare warianty przestałyby pasować); zmiana listy przykładów czyści `usedExamples` (indeksy wskazywałyby inne zdania). Wyniki umiejętności zostają. Dodatkowa walidacja: wyróżniony fragment musi występować w zdaniu.
4. **Formularz ręczny** wymaga tłumaczenia i przykładowego zdania (ta sama reguła co edytor strony: „tłumaczenie i przynajmniej jeden przykład”). Źródło słowa = „Dodane ręcznie”.
5. **Szybkie dodawanie:** arkusz po dodaniu zostaje otwarty z podsumowaniem (szybkie dodawanie kilku słów z rzędu); znaczenia, które użytkownik już ma, są widoczne i zablokowane (zamiast cichego pominięcia).
6. **Słownik:** dodatkowe filtry „Do odświeżenia”, poziom, sortowanie „Najbliższa powtórka”; wyszukiwanie także po tagach i bez polskich znaków.
7. **Onboarding** (strona startowała z danymi demo): zamiast demo — wybór poziomu i tematów, dodanie do 30 najczęstszych wpisów tematu do poziomu wybrany+1, potem od razu pierwsza sesja.
8. **Usuń wszystkie dane:** dwa kroki (dialog + wpisanie „USUŃ”); po sukcesie onboarding wraca.
9. **Postępy:** licznik „do powtórki” nie liczy nowych znaczeń (jak FluentKit §3.17) — nowe pokazane osobno („+ N nowych”).

## 4. Ryzyka / niesprawdzone (kompilacja)

- **Brak kompilacji.** Sprawdzone skryptem: nawiasy/stringi z interpolacją, brak BOM/CR, brak `!`/`try!`/`as!`/`fatalError`, brak kolizji nazw typów z FluentKit, Services, App, DesignSystem i ui-learning.
- Konstrukcje o mniejszej pewności:
  - `if case .failed(let message) = store.loadPhase` w `@ViewBuilder` (TodayRootScreen) — wspierane przez result buildery; w razie błędu zamienić na `switch`.
  - `.searchable` na widokach osadzonych w `VStack` pod segmentem (WordListView, TopicsRootScreen) — pole wyszukiwania powinno trafić do paska nawigacji karty; jeśli nie pojawi się na iOS 17, przenieść `.searchable` do `WordsRootScreen` z tekstem przekazywanym w dół.
  - `Button(...).disabled(...)` w `alert` (nazwa kolekcji, „USUŃ”) — działa od iOS 16; gdyby system ignorował `disabled`, akcja i tak sprawdza warunek (`issue == nil`, `isConfirmed`).
  - `AnyLayout(VStackLayout/HStackLayout)` w karcie sesji (iOS 16+).
  - `.background(.bar)` w `TopicAddBar`.
  - `ChartContent.accessibilityLabel/Value/Hidden` w wykresach.
- `TopicAdder`: jeśli w trakcie dodawania zmieni się stan (np. synchronizacja), partia jest przeliczana synchronicznie na głównym wątku (rzadkie, max 25 wpisów).
- `ConfusableDetector.itemsWithPartners` jest kwadratowy — licznik par liczony tylko do 2 500 znaczeń (powyżej baner bez liczby).
- Eksport (`exportJSONFile`, `exportAnkiCSVFile`) jest synchroniczny (kontrakt) — przy bardzo dużym słowniku wejście w „Eksport” może chwilę przyciąć.
- Usunięcie słowa nie modyfikuje przerwanej sesji (`state.session`/`combined`), która może zawierać jego zadania — patrz prośba do ui-learning.

## 5. Prośby do innych ról

- **ui-learning:** sesje (słownictwa i łączone) muszą pomijać zadania, których słowo/znaczenie już nie istnieje (usunięte w Słowniku lub na innym urządzeniu) — `Scheduler.recordAnswer` zwraca wtedy stan bez zmian, ale ekran nie powinien pokazywać pustego zadania. Obsługa `StudyLaunchRequest(modes: ["mixed"], collection:)` i `["pairs"]` jest używana przez Kolekcje i Tematy.
- **platform-services:** (1) użyłem API spoza CONTRACTS.md, które istnieje w kodzie: `AppEnvironment.refreshReminders()`, `SyncStatus.titlePl/detailPl/systemImage`, `AssistantProvider.detailPl`, `AssistantService.refreshAvailability()`, `appleOnDeviceUnavailableReason`, `AppEnvironment.previewEmpty`, `fluentPreviewEnvironment(_:)` — proszę traktować je jako część kontraktu. (2) Mile widziane asynchroniczne warianty eksportu (`exportJSONFile()` poza głównym wątkiem). (3) `ExerciseReportStore.exportFile()` — Ustawienia wołają go tylko, gdy są zgłoszenia.
- **design-shell:** brak komponentu „wiersz z polem wyboru” (checkbox) — zrobiłem lokalne (`TopicEntryRow`, `AddWordSenseRow`); warto dodać wspólny `SelectableRow`. Heatmapa używa `Palette.accent.opacity(0.35/0.65)` — jeśli potrzebne są oficjalne stopnie intensywności, proszę o tokeny `heatmap[0…3]`.
- **core-engine:** przydałaby się publiczna funkcja `CollectionOperations.rename/delete` i `WordEditing.apply` w FluentKit z testami (teraz logika żyje w UI: `CollectionMutations`, `WordDraft.applied`).
- **code-qa:** proponowane testy jednostkowe (czyste funkcje w module aplikacji): `WordListBuilder.build` (filtry, sortowanie, wyszukiwanie bez diakrytyków), `WordDraft.issues/applied`, `CollectionMutations`, `AddWordLogic.knownSenseIndices/sanitizedAssistantLookup/merge`, `AddWordCandidate.group`, `LibraryText.plural`, `TodayOnboardingView.starterEntryIDs`, `SettingsImportText.looksLikeJSON`.

## 6. Testy i uruchomione skrypty

- Testów XCTest nie dodawałem (katalog `FluentNOWTests/` nie należy do ui-library) — lista proponowanych w §5.
- Uruchomiony skrypt kontrolny (Node, scratchpad): balans nawiasów z obsługą interpolacji, BOM, CR, wzorce `try!`/`as!`/`fatalError`/force-unwrap — **0 problemów** we wszystkich 43 plikach obszaru.
- Kontrola kolizji nazw typów (grep): brak duplikatów w module aplikacji i z publicznymi typami FluentKit.
