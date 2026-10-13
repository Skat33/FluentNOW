# Raport: topic-content, shard S9

Status: **shard ukończony**: 12 z 12 tematów, 749 wpisów, 61 kategorii. Walidator nie zgłasza błędów ani ostrzeżeń dla żadnego pliku S9. Pełny przebieg `validate-content.mjs --errors-only` na całej bazie: 120 plików, 0 błędów. Na koniec uruchomiłem `node ios/tools/build-index.mjs`: 106 tematów, 8160 wpisów w tematach, 8181 rekordów słownika. Indeks objął też pliki S7/S8, które były na dysku w chwili uruchomienia.

## 1. Co zrobiono (pliki)

Wszystkie pliki leżą w `ios/FluentNOW/Resources/Content/topics/`:

| id | wpisów | kategorii | A1 | A2 | B1 | B2 | C1 | C2 |
|---|---|---|---|---|---|---|---|---|
| project-management | 74 | 6 | 0 | 2 | 20 | 32 | 20 | 0 |
| negotiations | 61 | 5 | 1 | 3 | 14 | 28 | 15 | 0 |
| presentations | 61 | 5 | 0 | 9 | 27 | 22 | 3 | 0 |
| marketing-sales | 62 | 5 | 0 | 2 | 16 | 24 | 20 | 0 |
| entrepreneurship | 61 | 5 | 0 | 0 | 11 | 24 | 24 | 2 |
| finance-accounting | 63 | 5 | 0 | 0 | 10 | 18 | 34 | 1 |
| law-contracts | 63 | 5 | 0 | 1 | 11 | 21 | 28 | 2 |
| government-offices | 62 | 5 | 0 | 7 | 25 | 21 | 9 | 0 |
| insurance | 60 | 5 | 0 | 3 | 15 | 22 | 18 | 2 |
| taxes | 61 | 5 | 0 | 3 | 10 | 17 | 30 | 1 |
| programming-it | 60 | 5 | 0 | 1 | 12 | 22 | 25 | 0 |
| artificial-intelligence | 61 | 5 | 0 | 2 | 12 | 24 | 23 | 0 |
| **razem** | **749** | **61** | 1 | 33 | 183 | 275 | 249 | 8 |

Pliki generowane `topics/index.json` i `dictionary-index.json` przebudowałem skryptem data-pipeline, nie edytowałem ich ręcznie. Tematów z „Pomysłów dodatkowych” nie brałem (zgodnie z poleceniem), więc plik `docs/topic-claims/S9.md` nie powstał.

## 2. Kontrakty

Schemat się nie zmienił, pliki trzymają się dokładnie formatu `CONTENT-SCHEMA.md` §1. Kilka konwencji:
- Każda kategoria ma konkretną scenę (`scenePl`). Oba przykłady wpisu dzieją się w tej scenie, w różnych momentach. Na przykład w ubezpieczeniach jest scena „rano po zalaniu kuchni przez pękniętą rurę”, a w urzędach „trzecia wizyta w tej samej sprawie”.
- `focusEn` bywa formą odmienioną albo wariantem hasła, np. `do our homework` dla `do your homework` albo `go to court` w pełnym zwrocie. Zawsze jest to dokładny podciąg zdania.
- Wielkie litery w hasłach są celowe (skróty i nazwy własne): Gantt chart, Q&A, SEO, A/B test, LLC, CFO, DMV, photo ID, state ID, Social Security number, IRS, IRS agent, Tax Day, W-2, Uncle Sam, AI, AI assistant, act of God, QA, UX designer, IT support. Hasło `1099` to nazwa formularza.
- Symbole SF: `checklist`, `person.2.wave.2`, `person.wave.2`, `megaphone`, `lightbulb`, `chart.line.uptrend.xyaxis`, `building.columns`, `doc.text`, `umbrella`, `percent`, `chevron.left.forwardslash.chevron.right`, `cpu`. Wszystkie pochodzą z SF Symbols 4 lub starszych, więc działają na iOS 17.

## 3. Odstępstwa od strony

- Treść napisałem ręcznie, zamiast generować ją przez Gemini (TOPIC_PROMPT i TOPIC_HYDRATE_PROMPT).
- Realia są świadomie amerykańskie: IRS, W-2, 1099, Tax Day, filing status, itemize, standard deduction, DMV, state ID, Social Security number, LLC, net 30, accounts payable/receivable, homeowners insurance, copay, umbrella policy, attorney, notary. W `notePl` dodałem odpowiedniki polskie: PESEL, PIT-11, NIP, sp. z o.o., OC/AC, ZUS, termin 30 kwietnia. Opisałem też różnice AmE/BrE: licence/license, extension lead, small print, financial year, year-on-year, overheads.
- Wydzieliłem znaczenia, które łatwo pomylić, i opisałem je w `notePl`: tax return a tax refund, tax evasion a tax avoidance, tax credit a tax deduction, persuade a convince, revenue a profit, „table a proposal” w AmE (= odłożyć sprawę), marriage certificate a marriage license, damages a damage.

## 4. Znane ryzyka i rzeczy niesprawdzone

- IPA pisałem ręcznie (GA). Nikt jej nie porównał ze słownikiem zewnętrznym. Długie zwroty mają celowo pustą IPA (`""`), np. `make up for lost time`, `on time and on budget`, `today I'm going to talk about`, `death and taxes`.
- CEFR i `frequency` to moja ocena redakcyjna. Tematy specjalistyczne (finance-accounting, taxes, law-contracts) mają z natury dużo poziomu C1. Tego nie wyrównywałem. Najmniej pewne oceny to: walk-away point (C1, rare), bootstrap i valuation (C2), proof of loss i umbrella policy (C2), statute of limitations (C2), withhold (C1), deliverable (C1).
- Niektóre hasła występują też w innych tematach, w innym znaczeniu albo w innej scenie, co TOPICS-MASTER dopuszcza. Przykłady: contract (salary-benefits), insurance/coverage/deductible/liability (car-rental), premium (salary-benefits), fine print (car-rental, renting-apartment), budget i risk (personal-finance), bandwidth i buffer (computers-internet, tam w znaczeniu technicznym). Przykłady zdań są wszędzie unikalne, co potwierdza walidator. Kilka idiomów S9 pokrywa się z tematem arguments-conflict z równoległego shardu S8: middle ground, common ground, hear someone out. W S9 dzieją się one w scenie negocjacji handlowych.
- Generator S9 ma listę „brytyjskich form”, która daje fałszywe alarmy na słowa „realistic” i „programmers”. Walidator data-pipeline ich nie zgłasza.
- Treść źródłowa (format kompaktowy, generator `S9/gen.mjs`, skrypty pomocnicze `fx.mjs`, `ins.mjs`, `mv.mjs`) leży tylko w scratchpadzie sesji. Źródłem prawdy są pliki JSON w repo.

## 5. Prośby do innych ról

- **english-qa**: proszę o wyrywkową kontrolę IPA i CEFR, zwłaszcza w taxes, finance-accounting i law-contracts, gdzie jest najwięcej wpisów C1–C2. Warto też sprawdzić polskie terminy specjalistyczne: „uposażony”, „franszyza redukcyjna/udział własny”, „likwidator szkód”, „okres karencji”, „rok obrotowy”, „należności/zobowiązania”.
- **data-pipeline**: build-index trzeba uruchomić ponownie, gdy S7 i S8 skończą swoje pliki. Mój przebieg objął tylko to, co było wtedy na dysku.
- **ui-library**: brak próśb.

## 6. Testy i wynik skryptów

- `node ios/tools/validate-content.mjs --file <plik>` dla każdego z 12 plików: `OK`, 0 błędów, 0 ostrzeżeń.
- `node ios/tools/validate-content.mjs --errors-only` na całej bazie: `OK: plików 120, wpisów 8181, błędów 0, ostrzeżeń 0`.
- `node ios/tools/build-index.mjs`: `tematów: 106, wpisów w tematach: 8160, rekordów słownika: 8181`.
- Generator S9 dodatkowo sprawdzał: dokładnie dwa przykłady na wpis, jeden znacznik fokusu na stronę, 6–20 słów w zdaniu EN, długość `definition` i `contextPl`, liczbę 1–8 `acceptedTranslations` oraz unikalność id i przykładów w temacie.
- Osobnym skryptem sprawdziłem pokrycie haseł S9 z pozostałymi 94 tematami (wynik w pkt 4).
