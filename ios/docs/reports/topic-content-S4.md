# Raport: topic-content, shard S4

Stan: **shard ukończony** – 12/12 tematów, 979 wpisów. Wszystkie pliki przechodzą `node ios/tools/validate-content.mjs` z 0 błędami. Indeks przebudowany (`node ios/tools/build-index.mjs`: 65 tematów, 5138 wpisów w tematach, 5159 rekordów słownika).

## 1. Zrobione (pliki `ios/FluentNOW/Resources/Content/topics/`)

| id | grupa | wpisów | kategorii | CEFR |
|---|---|---|---|---|
| doctor-visit | health | 105 | 6 | A1 1, A2 36, B1 40, B2 25, C1 3 |
| symptoms-illness | health | 95 | 6 | A1 3, A2 16, B1 39, B2 34, C1 3 |
| body-parts | health | 89 | 6 | A1 21, A2 22, B1 31, B2 14, C1 1 |
| pharmacy | health | 74 | 6 | A1 3, A2 16, B1 25, B2 22, C1 8 |
| hospital-emergency | health | 74 | 6 | A1 3, A2 12, B1 23, B2 23, C1 13 |
| dentist | health | 63 | 6 | A1 3, A2 8, B1 19, B2 21, C1 11, C2 1 |
| fitness-gym | health | 77 | 6 | A1 4, A2 16, B1 28, B2 22, C1 7 |
| mental-health | health | 79 | 6 | A1 2, A2 6, B1 22, B2 36, C1 13 |
| sleep | health | 74 | 6 | A1 7, A2 16, B1 14, B2 29, C1 8 |
| sports | leisure | 88 | 6 | A1 16, A2 24, B1 24, B2 16, C1 8 |
| pets | nature | 75 | 6 | A1 7, A2 16, B1 20, B2 26, C1 6 |
| animals | nature | 86 | 6 | A1 16, A2 29, B1 22, B2 14, C1 5 |
| **razem** | | **979** | 72 | |

Każda kategoria ma własną scenę (`scenePl`), oba przykłady wpisu dzieją się w tej scenie; w każdej kategorii wpisy od najczęstszych do rzadszych. Ostatnia kategoria większości tematów to utarte zwroty/idiomy osadzone w konkretnej sytuacji.

Nie brałem tematów z „Pomysłów dodatkowych” (zgodnie z poleceniem koordynatora), więc nie utworzyłem `ios/docs/topic-claims/S4.md`.

## 2. Kontrakty

Brak nowego API. Pliki zgodne z `CONTENT-SCHEMA.md` §1 (identyfikatory `<topicId>.<kebab-term>`, dla drugiego znaczenia sufiks `-2`, np. `dentist.bite-2` = zgryz). Symbole SF użyte w polu `symbol`: `stethoscope`, `thermometer.medium`, `figure.stand`, `pills`, `cross.case`, `mouth`, `dumbbell`, `brain.head.profile`, `bed.double`, `sportscourt`, `pawprint`, `hare` (wszystkie istnieją w SF Symbols 4+/iOS 16+; `mouth` i `dumbbell` są od iOS 16, więc na iOS 17 działają).

## 3. Odstępstwa od strony / decyzje redakcyjne

- Treść pisana ręcznie (zastępuje Gemini). Ten sam wyraz występuje w kilku tematach tylko z innym znaczeniem lub w innej scenie, np. `numb` (doctor-visit / dentist), `chew` (pharmacy: rozgryźć tabletkę / pets: gryźć przedmioty), `bug` (symptoms-illness: wirus / animals: robak), `relax` (body-parts: rozluźnić mięsień / mental-health: odpocząć).
- Terminy wielkimi literami tam, gdzie to skrótowiec: `photo ID`, `CPR`, `IV`, `CT scan`, `ICU`, `catch some Z's` (mój własny skrypt ostrzegał, walidator projektu nie).
- Rzeczowniki zwykle używane w liczbie mnogiej mają hasło w liczbie mnogiej, gdy tak się ich używa (`weights`, `braces`, `dentures`, `sneakers`, `pajamas`, `chills`, `mood swings`); pozostałe w liczbie pojedynczej z formą mnogą w `forms`.

## 4. Znane ryzyka / rzeczy niesprawdzone

- Pozostałe ostrzeżenia walidatora dla S4 (6) to fałszywe alarmy heurystyki BrE: „tube” (tubka maści/pasty, nie metro) w `pharmacy.tube`, `pharmacy.ointment`, `dentist.toothpaste` oraz „trainers” w `forms` hasła `fitness-gym.personal-trainer` (liczba mnoga od „trainer”, nie buty). Celowo nie zmieniałem.
- IPA General American wpisywane ręcznie; ujednolicone do zapisu z „ɜːr” (nie „ɝ”). Warto, żeby english-qa wyrywkowo sprawdziło IPA długich zwrotów.
- Poziomy CEFR i `frequency` to ocena redakcyjna, nie wynik korpusowy.
- Temat `mental-health` celowo pomija treści o samookaleczeniach / myślach samobójczych; depresja, lęk, atak paniki ujęte neutralnie.

## 5. Prośby do innych ról

- **data-pipeline**: heurystyka „the tube → subway” w `validate-content.mjs` daje fałszywe alarmy dla „tube of cream/toothpaste”; można ją zawęzić (np. ignorować, gdy po „tube” następuje „of”, lub gdy w tym samym wpisie występuje „cream/ointment/toothpaste”). Podobnie „trainers” w polu `forms`.
- **english-qa**: wyrywkowa kontrola IPA i polskich tłumaczeń idiomów (np. `like herding cats` → „jak pilnowanie worka pcheł”, `in a funk` → „w dołku”).

## 6. Testy i wynik skryptów

- `node ios/tools/validate-content.mjs --file <12 plików S4>` → `OK: plików 12, wpisów 979, błędów 0, ostrzeżeń 6` (opisane wyżej).
- Pełna walidacja bazy `node ios/tools/validate-content.mjs` → `OK: plików 79, wpisów 5159, błędów 0` (brak kolizji id między shardami).
- `node ios/tools/build-index.mjs` → zapisano `topics/index.json` i `dictionary-index.json` (65 tematów, 5159 rekordów słownika).
- Dodatkowo własny konwerter (w scratchpadzie, poza repo) sprawdzał przy budowie: dokładnie jeden fokus w każdym zdaniu (gwarantuje `focusEn ⊂ en`, `focusPl ⊂ pl`), interpunkcję końcową, długości `definition`/`contextPl`, enumeracje `pos/level/frequency/register`, liczbę `acceptedTranslations` ≤ 8, duplikaty haseł, długość przykładów 6–20 słów (wszystkie krótsze poprawione).
