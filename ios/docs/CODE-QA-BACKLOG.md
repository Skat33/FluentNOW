# Backlog dla code-qa (zebrane z raportów fali 1–2)

Każdy punkt sprawdzić i naprawić lub uzasadnić w raporcie code-qa.

- [ ] DesignSystem: `ConfidencePicker` i `TagChip` wywołują haptykę mimo wyłączenia jej w ustawieniach (`AppPreferences.hapticsEnabled`) — zgłoszenie ui-learning.
- [ ] FluentKit: `gradingWord` używa surowego indeksu przykładu, UI używa zawiniętego (modulo) — ui-learning normalizuje w UI; rozważyć poprawkę w FluentKit + test (zgłoszenie ui-learning).
- [ ] FluentKit: `ContentSearch` trzyma tablice krotek w typie `Sendable`; przekazanie lokalnej funkcji `add` jako nie-ucieczkowego parametru — ryzyka kompilacji (core-engine §4).
- [ ] FluentKit: testy `testFiveConsecutiveSessionsInterleaveAndFillBudget`, `testInterleaveKeepsAllTasksAndAlternates` — porównać port `TaskInterleaver` z `interleaveTasks` w `web-source/lib/learning.ts` (core-engine §4).
- [ ] ui-learning ryzyka kompilacji (raport ui-learning §5): atrybuty underline/link w tekście czytanki, wywołania `@MainActor` z closure'ów gestów, `@FocusState` w widokach z innych plików.
- [ ] design-shell ryzyka kompilacji: raport design-shell §4.
- [ ] Spójność kontraktu: rzeczywiste sygnatury w `Services/` vs użycie w `Features/` (grep każdego wywołania).
- [ ] **Poprawność (ważne):** przerwana sesja (słownictwo/combined) zawierająca zadanie dla słowa usuniętego w Słowniku — sesja musi pominąć takie zadanie bez crasha i bez zablokowania (zgłoszenie ui-library). Sprawdzić ścieżkę w ui-learning i FluentKit (`VocabSession`, `CombinedSession`), dodać test.
- [ ] ui-library ryzyka kompilacji: `.searchable` w widokach pod segmentowanym pickerem (fallback: przenieść do `WordsRootScreen`), `if case` w ViewBuilder w `TodayRootScreen`, `.disabled` na przyciskach w `alert`.
- [ ] ui-library używa API platform-services spoza CONTRACTS.md (`refreshReminders()`, `SyncStatus.titlePl/detailPl/systemImage`, `AssistantProvider.detailPl`, `refreshAvailability()`, `appleOnDeviceUnavailableReason`, `.previewEmpty`) — potwierdzić, że istnieją z tymi sygnaturami.
- [ ] Testy jednostkowe czystych funkcji z obszaru ui-library (lista w raporcie ui-library).
- [ ] Drobne (opcjonalne): wspólny wiersz-checkbox i tokeny kolorów heatmapy w DesignSystem (zgłoszenie ui-library).
- [ ] platform-services prośby i ryzyka: raport platform-services §4–§5 (powiadomienia synchronizacji SwiftData, FoundationModels vs SDK iOS 26.0, import JSON na głównym wątku).

## Runda 2 (po FEEDBACK-1/2)
- [ ] XP/seria/cel dzienny liczone w dniach UTC — nauka 0:00–2:00 czasu PL wpada w następny dzień; przejść na kalendarz użytkownika (onboarding-progress §6).
- [ ] Sesja łączona: etap „tylko tekst” czytanki nie jest zapisywany — po wznowieniu tekst pokazuje się ponownie (reading-redesign).
- [ ] `verify-export.mjs` powinien ignorować pole `glossary` czytanek.
- [ ] Filtr „rzeczownik do sfotografowania” przepuszcza abstrakcje (voucher, spreadsheet) — dopracować na podstawie `image-reports.json`.
- [ ] Profil: `preferredExerciseTypes()` i `ProfileLevel.estimate` niepodpięte do budowania sesji / czytania / gramatyki (opcjonalne).
- [ ] Ryzyka kompilacji rundy 1–2: raporty topic-search §, learning-fixes, recommendations, practice-modes §4, onboarding-progress §6, reading-redesign (AttributedString w ReadingHighlighting.swift).
- [x] (naprawione: identyczne tłumaczenia były już wykluczone; dodano kierunek odwrotny — akceptowane odpowiedzi dystraktora vs tłumaczenie celu) Dystraktory w „Wybierz znaczenie”: pomijać hasła z identycznym `translation` jak poprawna odpowiedź (np. keep someone posted / keep someone in the loop) — zgłoszenie english-qa-T3; sprawdzić, czy `PolishAnswerIndex` już to pokrywa.
- [ ] **starter-words.json:** ponowny eksport (`export-web-content.mjs`) skasuje poprawki english-qa i content-final w słowach startowych — przenieść je do nadpisań eksportu (lista w `reports/content-final.md` §7).
- [ ] Przenieść listę wykluczeń zdjęć (`WordImageEligibility`) do `PictureExercise.isPicturable` w FluentKit, żeby sesja nie losowała zadań zdjęciowych dla haseł „bez zdjęcia” (prośba image-verify). Dostroić progi pewności Vision na prawdziwych zdjęciach.

## Runda 4 (FEEDBACK-4)
- [ ] Deep link `fluentnow://progress/weekly` — powiadomienie o raporcie tygodniowym otwiera dziś tylko kartę Postępy (insights-scan).
- [ ] `StudyLaunchRequest.wordIDs` — „Powtórz je” w raporcie tygodniowym uruchamia ogólną sesję pomyłek zamiast słów z danego tygodnia (insights-scan).
- [ ] Testy jednostkowe logiki skanowania (`Features/Scan/`) w FluentNOWTests; etykiety metod delegata `DataScannerViewController` sprawdzić na prawdziwym iPhonie (insights-scan).
- [ ] Test poziomujący: dobierać słowa także ze słownika rdzeniowego (`core/`) — w `Features/Study/Test/TestLoader.swift` wywołać `coreFileIDs()`, wczytać shardy przez `topic(id:)` i przekazać do `AssessmentBuilder.bankEntries(topic:band:fromLearnerTopics: false)`; zrobić po napisaniu treści core (test-mode).
- [ ] Polecane słówka ze słownika rdzeniowego: (1) `UsefulWordRecommender.candidates` pomija wpisy core (brak tematu) — gałąź `reference.isCore` z `CoreVocabulary.collectionName`, grupa "basics"; (2) `UsefulWordsCatalog.readDetails` czyta tylko `topics/` — użyć `ContentReference.relativePath` i `ContentDecoder.coreFile(from:)` (CONTENT-SCHEMA §6). Zrobić razem z podłączeniem core do testu, po napisaniu treści core.
