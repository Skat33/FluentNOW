# Raport: topic-content, shard S2

## 1. Co zrobiono

Ukończono wszystkie 12 tematów sharda S2 (grupa `travel`). Pliki znajdują się w `ios/FluentNOW/Resources/Content/topics/`:

| id | wpisy | kategorie | A1 | A2 | B1 | B2 | C1 | C2 | walidator |
|---|---|---|---|---|---|---|---|---|---|
| airport | 105 | 7 | 4 | 35 | 45 | 19 | 2 | 0 | 0 błędów, 0 ostrzeżeń |
| flight | 89 | 6 | 5 | 20 | 36 | 26 | 2 | 0 | 0 błędów, 0 ostrzeżeń |
| hotel | 86 | 6 | 6 | 35 | 26 | 18 | 1 | 0 | 0 błędów, 0 ostrzeżeń |
| train-travel | 63 | 5 | 4 | 22 | 23 | 14 | 0 | 0 | 0 błędów, 0 ostrzeżeń |
| public-transport | 61 | 5 | 6 | 16 | 19 | 18 | 2 | 0 | 0 błędów, 0 ostrzeżeń |
| driving | 77 | 6 | 4 | 19 | 31 | 19 | 4 | 0 | 0 błędów, 0 ostrzeżeń |
| directions | 65 | 5 | 14 | 30 | 15 | 4 | 2 | 0 | 0 błędów, 0 ostrzeżeń |
| sightseeing | 63 | 5 | 5 | 14 | 25 | 17 | 2 | 0 | 0 błędów, 0 ostrzeżeń |
| beach-vacation | 63 | 5 | 5 | 19 | 22 | 14 | 3 | 0 | 0 błędów, 0 ostrzeżeń |
| camping-hiking | 62 | 5 | 1 | 18 | 26 | 12 | 5 | 0 | 0 błędów, 0 ostrzeżeń |
| border-immigration | 63 | 5 | 1 | 7 | 23 | 21 | 11 | 0 | 0 błędów, 0 ostrzeżeń |
| car-rental | 66 | 6 | 1 | 9 | 17 | 32 | 7 | 0 | 0 błędów, 0 ostrzeżeń |
| **razem** | **863** | **66** | | | | | | | |

Nierozpoczęte lub niedokończone: brak. Nie brałem tematów z listy „Pomysły dodatkowe”, więc nie powstał plik `topic-claims/S2.md`.

## 2. Kontrakty

Format jest dokładnie taki jak w `CONTENT-SCHEMA.md` §1. Schematu nie zmieniałem.

- Każdy plik ma `schemaVersion: 1`, grupę `travel` i symbol SF. Użyte symbole: `airplane.departure`, `airplane`, `bed.double`, `train.side.front.car`, `bus`, `car`, `map`, `building.columns`, `beach.umbrella`, `tent`, `person.text.rectangle`, `car.2`.
- Identyfikatory wpisów mają postać `<topicId>.<kebab-term>`. Sufiks `-2` pojawia się tylko raz: `airport.check-in-2`, czyli czasownik frazowy „check in” obok rzeczownika „check-in”.
- Każda kategoria ma `scenePl`. Oba przykłady każdego wpisu dzieją się w tej scenie. `focusEn` i `focusPl` są dokładnymi podciągami zdań, bo generator wycina je z zaznaczeń w nawiasach kwadratowych.

## 3. Odstępstwa i decyzje redakcyjne

- **Narzędzie autorskie.** Treść pisałem w kompaktowym formacie tekstowym (jedna linia na wpis plus dwie linie przykładów). Mój skrypt `gen.mjs` zamieniał ją na JSON zgodny ze schematem i sprawdzał liczbę pól, przykłady, focus, enumy oraz długości. Źródła i generator leżą w scratchpadzie sesji (`…/scratchpad/src/<topic>/*.txt`, `gen.mjs`), a nie w repozytorium. Jedynym produktem są pliki JSON.
- **Wielkie litery w hasłach.** Hasła `ID`, `X-ray machine`, `GPS`, `SPF`, `SUV`, `RV`, `ID card` i `U-turn` są zapisane wielkimi literami, bo to skrótowce i ustalona pisownia. Walidator ich nie zgłasza.
- **Zamiany na angielski amerykański.** Z ostrzeżeń walidatora o słownictwie brytyjskim wynikły zamiany: `return ticket` → `onward ticket` (border), `rail replacement bus` → `shuttle bus`, „ground floor” → „first floor”, „full stop” → „complete stop”, „on holidays” → „on public holidays”. Formy brytyjskie zostały tylko w `notePl` jako informacja.
- **Hasła usunięte lub zmienione.**
  - `handicapped parking` zastąpiłem współczesnym `accessible parking`; stara forma została w `acceptedAnswers`.
  - Z `acceptedTranslations` usunąłem markę („wars”) i nietrafne „kuszetka”.
  - `Wi-Fi` usunąłem z tematu flight (należy do S6) i wstawiłem tam `refill`.
- **Słowa w kilku tematach.** Część haseł występuje w więcej niż jednym temacie S2, np. passport, window seat, extend, drop off, pick up, transfer, fare. W każdym temacie mają własne przykłady osadzone w jego scenie, zgodnie z zasadą z `TOPICS-MASTER.md`. Walidator nie zgłosił żadnych zdublowanych przykładów. Dwa przypadkowe duplikaty zdań z tematami S3 (restaurant, cafe-bakery) wykrył i poprawiłem.
- **Brak poziomu C2.** Żaden temat sharda nie ma wpisów C2, bo słownictwo podróżne naturalnie kończy się na C1. Nie dodawałem sztucznie rzadkich słów.
- **Rozkład CEFR w directions.** Temat directions ma dużo wpisów A1–A2, bo taka jest ta domena. W border-immigration jest odwrotnie: przeważają B2–C1, bo to słownictwo urzędowe.

## 4. Znane ryzyka i rzeczy niesprawdzone

- IPA pisałem z pamięci w General American. Walidator sprawdza tylko format i typowe brytyjskie cechy, więc english-qa powinien wyrywkowo przejrzeć dłuższe zwroty.
- Przykłady w scenach z kwotami i jednostkami (mile, funty, °F) mają w tłumaczeniu polskim czasem wartości przeliczone na kilometry i °C, czasem oryginalne. To świadoma decyzja dla naturalności, ale jest niejednolita.
- Kilka tłumaczeń to opisowe równoważniki bez jednego polskiego słowa, np. `backseat driver` → „pasażer, który poucza kierowcę”, `outdoorsy` → „lubiący przyrodę”, `uptown` → „w kierunku północnej części miasta”.
- Liczba wpisów: ostatnie tematy mają po 61–66 wpisów, czyli blisko dolnej granicy. Można je rozbudować w kolejnej fali.

## 5. Prośby do innych ról

- **english-qa:** przegląd IPA zwrotów wielowyrazowych oraz ocena naturalności polskich równoważników opisowych (lista w pkt 4).
- **data-pipeline:** brak próśb. Walidator i `build-index.mjs` działają poprawnie z plikami S2.

## 6. Testy i wyniki skryptów

- `node ios/tools/validate-content.mjs --file <plik>` dla każdego z 12 tematów: 0 błędów, 0 ostrzeżeń.
- `node ios/tools/build-index.mjs`: zapisano `topics/index.json` i `dictionary-index.json` (67 tematów, 5391 wpisów w tematach, 5412 rekordów słownika).
- `node ios/tools/validate-content.mjs` dla całej bazy: 81 plików, 5412 wpisów, 0 błędów, 0 ostrzeżeń.
- Ręczny przegląd redakcyjny objął wpisy w trakcie pisania oraz wyrywkową próbę 10 wpisów na koniec. Poprawki dotyczyły m.in. polskiej składni, przypadków w `focusPl`, rozdzielonych focusów czasowników frazowych i zdań cytowanych bez końcowej interpunkcji.
