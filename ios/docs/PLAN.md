# Plan pracy agentów — FluentNOW iOS

Prompt główny: `AGENTS-BRIEF.md`. Prompty ról: `agents/*.md`. Kontrakt treści: `CONTENT-SCHEMA.md`. Tematy: `TOPICS-MASTER.md`.

| Fala | Agent | Rola | Zależy od |
|---|---|---|---|
| 1 | core-engine | FluentKit: modele, algorytm powtórek, sesje, ocenianie, import/eksport, statystyki + testy | — |
| 1 | data-pipeline | walidator treści, indeksy, przeniesienie banków strony do JSON | — |
| 1 | design-shell | project.yml (XcodeGen), design system, ikona, szkielet nawigacji, DESIGN.md | — |
| 1 | topic-content S1–S6 | „tester treści”: tematy słówek (≈70 tematów w fali 1) | walidator (data-pipeline) |
| 2 | — koordynator — | `CONTRACTS.md` z API FluentKit + LearningStore/serwisy | raport core-engine |
| 2 | platform-services | SwiftData+iCloud, LearningStore, ContentLibrary, mowa, wymowa, przypomnienia, AI, Keychain, import/eksport | CONTRACTS |
| 2 | ui-learning | sesje i wszystkie ćwiczenia, czytanie, gramatyka, produkcja, wymowa | CONTRACTS, DESIGN |
| 2 | ui-library | Dzisiaj, Słownik, Szybkie dodawanie, Tematy, Kolekcje, Postępy, Ustawienia | CONTRACTS, DESIGN |
| 2 | topic-content S7–S12 | kolejne ≈70 tematów | — |
| 2/3 | english-qa (×N) | korekta angielskiego i polskiego we wszystkich treściach | gotowe tematy/banki |
| 3 | code-qa A/B | „kompilator w głowie”, błędy, testy, plan testów ręcznych | fala 2 |
| 4 | Mac (użytkownik) | `xcodegen`, build, testy, poprawki błędów kompilacji z pomocą agenta | wszystko |
