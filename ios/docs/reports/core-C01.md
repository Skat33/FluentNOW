# Raport: core-content, shard C01

## 1. Co zrobiono

Plik: `ios/FluentNOW/Resources/Content/core/core-c01.json`. Jedyny plik bazy, który zmieniłem. 17 wzorcowych wpisów zostało bez zmian.

| | Liczba |
|---|---|
| Wpisy w pliku razem | **553** (17 wzorcowych + **536 nowych**) |
| Nowe hasła (lematy) | 398 |
| Przykłady w nowych wpisach | 2205 (3 przykłady: 20 wpisów, 4: 435, 5: 81) |
| Rozmiar pliku | ~866 KB (poniżej progu `core-size` 650 wpisów) |
| Walidator `--file` | **0 błędów, 0 ostrzeżeń** |

Rozkład CEFR nowych wpisów: A1 162 · A2 165 · B1 179 · B2 30. Cały plik: A1 162 · A2 165 · B1 181 · B2 42 · C1 3.
Części mowy (nowe): czasownik 193, rzeczownik 158, przymiotnik 75, przysłówek 55, przyimek 31, zaimek 12, spójnik 11, wykrzyknik 1.

Lista robocza `--shard C01` liczy 619 haseł: 259 `new`, 98 `partial`, 262 `check`.
- **new + partial:** zrobione wszystkie poza dwoma (zob. §3). Słowa wieloznaczne dostały osobne wpisy na każde ważne znaczenie, np. *get* ×5, *right* ×4, *as* ×4, *keep* ×3, *leave* ×3, *last* ×3, *break* ×3, *clear* ×3, *figure* ×3, *see* ×3, *take* ×3, *over* ×3.
- **check:** 43 hasła dostały ogólne znaczenie, którego brakowało, bo baza miała tylko wąskie znaczenie z jakiegoś tematu:
  *by* (przez / przy / sposób), *make* (sprawić), *time* (raz), *take* (wziąć / zająć czas / zabrać), *then* (wtedy), *look* (patrzeć), *mean* (mieć na myśli / zamierzać), *change* (zmienić / zmiana), *feel* (czuć), *part* (część), *little* (trochę), *meet* (spotkać się), *play* (bawić się), *course* (kurs), *case* (przypadek), *follow* (iść za), *run* (biegać / prowadzić firmę), *turn* (skręcić), *move* (ruszać się), *order* (kolejność), *hold* (trzymać / organizować), *spend* (spędzić czas), *side* (strona), *term* (termin), *lose* (zgubić, stracić), *rate* (wskaźnik), *fall* (spadać), *power* (władza), *stay* (zatrzymać się), *reach* (dotrzeć), *free* (wolny), *sale* (sprzedaż), *add* (dodać), *cover* (przykryć), *condition* (stan / warunek), *die* (umrzeć), *cut* (ciąć), *strong* (silny), *stage* (etap), *space* (miejsce), *save* (uratować), *pick* (wybrać), *contain* (zawierać).
  Pozostałe **219** haseł `check` pominąłem, bo ich ogólne znaczenie już jest w bazie: do, say, year, day, thing, child, tell, really, between, write, number, interesting, country, school, high, week, never, house, report, group, book, family, always, big, small, study, hand, however, area, read, friend, month, large, government, word, issue, pay, build, service, job, result, happen, offer, young, program, today, hour, student, idea, room, reason, car, learn, level, city, support, line, although, low, often, train, actually, consider, price, parent, party, local, already, product, story, yet, expect, deal, water, send, soon, watch, suggest, test, grow, mother, office, record, light, remember, sit, letter, decide, language, subject, class, half, minute, ago, win, color, period, history, eye, music, game, political, policy, body, team, full, black, rule, pass, short, agree, law, paper, position, computer, staff, war, account, sometimes, carry, father, decision, table, describe, available, community, role, join, detail, difference, health, draw, white, date, practice, model, raise, customer, door, economic, teacher, charge, finally, claim, relationship, nice, improve, happy, couple, project, road, wear, rest, kid, industry, education, national, field, security, percent, usually, data, single, performance, accept, mention, culture, material, listen, due, wrong, foot, arrive, patient, century, evidence, similar, wife, sport, discuss, response, voice, piece, finish, apply, president, fire, compare, court, police, store, arm, heart, source, employee, bank, cell, article, surprised, recently, related, miss, art, campaign, private, pause, forget, page, worried, summer, drink, opinion, manager, international, section, exactly, plant, paint, growth.

Sposób pracy: treść pisałem w zwięzłym formacie (`b01.txt` … `b21.txt` w scratchpadzie, katalog `c01w/`). Skrypt `conv.mjs` składał z nich JSON w formatowaniu pliku wzorcowego: kategorie A1–C2, kolejność haseł z listy, `id` z sufiksami `-2`, `-3`. Przy składaniu skrypt sam sprawdzał podciągi `focusEn`/`focusPl`, długość definicji (≤ 140) i `contextPl` (≤ 80), liczbę przykładów oraz to, czy `translation` jest w `acceptedTranslations`. Po każdej partii uruchamiałem walidator na moim pliku.

## 2. Kontrakty
Bez zmian w schemacie. Format jest zgodny z CONTENT-SCHEMA §6. `id` mają postać `core.<hasło>`, `core.<hasło>-2` itd.

## 3. Pominięte, zmiany CEFR i części mowy, wątpliwości

**Pominięte hasła new/partial:**
- *far* (partial, brak przysłówka). Wpis `directions.far` ma tłumaczenie „daleko” i przykłady przysłówkowe, ale `pos` = przymiotnik. Mój wpis o tym samym znaczeniu dałby ostrzeżenie `core-in-base`. Lepiej poprawić `pos` w temacie (zob. §5).
- *several* (partial, brak zaimka). `numbers-time.several` „kilka” (liczebnik) to już to samo znaczenie.

**Zmiany względem listy (części mowy i znaczenia):**
- *first*: tylko przysłówek „najpierw”. Przymiotnik „pierwszy” jest już jako liczebnik.
- *little*: dodałem „a little = trochę” (zaimek). „mały” jest już w bazie.
- Dodatkowe znaczenia spoza listy, każde jako osobny wpis:
  - *as* jako przysłówek („tak … jak”),
  - *over* jako przymiotnik („skończony”),
  - *well* jako przymiotnik („zdrowy”),
  - *while* jako rzeczownik („chwila”),
  - *plan* jako rzeczownik (w bazie było tylko „pakiet”),
  - *interest* jako rzeczownik („zainteresowanie”),
  - *hard* jako przymiotnik („trudny”),
  - *late* jako przymiotnik („późny”),
  - *work* jako czasownik („pracować”; w bazie tylko „działać”),
  - *like* jako czasownik („lubić”; w bazie tylko „polubić” z mediów społecznościowych),
  - *answer* jako czasownik („odpowiedzieć”),
  - *note* jako rzeczownik („notatka”),
  - *top* jako rzeczownik („góra, szczyt”),
  - *return* jako czasownik („wrócić”),
  - *drop* jako czasownik („upuścić”),
  - *limit* jako rzeczownik,
  - *point* jako rzeczownik („sens”).
- **CEFR inny niż w liście:**
  - *as*: znaczenia „gdy” i „ponieważ” → B1,
  - *get*: „rozumieć” → B1,
  - *mean*: „zamierzać” → B1,
  - *great*: „wielki” → B1,
  - *state*: „stwierdzić” → B2,
  - *value*: czasownik → B2,
  - *appear*: „wydawać się” → B2,
  - *nature*: „charakter” → B2,
  - *figure*: „postać” i „sądzić” → B2,
  - *individual*: rzeczownik → B2,
  - *benefit*: czasownik → B2.

**Wątpliwości dla QA:**
- Niektóre `translation` mają dopiski w nawiasie, żeby odróżnić znaczenia: „przez (kogoś)”, „za pomocą (sposób)”, „zająć (czas)”, „dużo (a lot of)”, „trochę (a little)”. Hasło *as-2* ma tłumaczenie „tak … jak”. W `acceptedTranslations` są zawsze warianty bez nawiasów.
- *lot* i *little* mają `term` w formie słownikowej, a w `acceptedAnswers` są też „a lot”, „a lot of” i „a little”.
- *by* (sposób): po polsku zwykle narzędnik bez przyimka. `focusPl` to wtedy forma rzeczownika („autobusem”, „kartą”), a wyjaśnienie jest w `notePl`.
- Około 24 przykładów ma 4–5 słów (np. „Where do you live?”, „Who broke the window?”). Mieści się to w progu walidatora (4–25), ale jest poniżej zalecanych 6–20.
- Przykłady są unikalne względem całej bazy, łącznie z core-c02 i core-c03 w chwili walidacji. Jeśli C02/C03 dopiszą później identyczne zdanie, błąd zgłosi walidator po ich stronie.

## 4. Ryzyka
- Kontekstu do wyboru znaczeń brałem z narzędzia `dictionary-index.json` (`look.mjs`). Indeks może być nieaktualny po falach innych agentów.
- IPA porównałem automatycznie z bazą dla tych samych haseł. Różnice wynikają tylko z innej części mowy, i to celowo: *live* v. /lɪv/, *close* v. /kloʊz/, *increase* n. /ˈɪnkriːs/, *present* v. /prɪˈzent/, *produce* v. /prəˈduːs/, *address* v. /əˈdres/.

## 5. Prośby do innych ról
- **english-qa / content-final:** w `topics/directions.json`, we wpisie `directions.far`, zmienić `pos` na „przysłówek” (tłumaczenie „daleko” i przykłady są przysłówkowe) albo tłumaczenie na „daleki”.
- **Koordynator / core-pipeline:** po fali uruchomić `build-index.mjs` i `build-core-master.mjs` (ja ich nie uruchamiałem), a potem pełne `validate-content.mjs`.

## 6. Wynik walidatora
`node ios/tools/validate-content.mjs --file …/core/core-c01.json` → `OK: plików 1, wpisów 553, błędów 0, ostrzeżeń 0`.
