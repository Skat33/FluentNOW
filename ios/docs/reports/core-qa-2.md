# Raport: english-qa, zakres core-qa-2 (słownik rdzeniowy C03 + C04)

## 1. Zakres i wynik

| | core-c03.json | core-c04.json |
|---|---|---|
| Wpisy przejrzane ręcznie (przed korektą) | 548 | 475 |
| Przykłady przejrzane | 2007 | 1765 |
| Wpisy po korekcie (+ dopisane znaczenia) | 551 (+3) | 477 (+2) |
| Przykłady po korekcie | 2017 | 1772 |
| Zmienione pola | 170 | 161 |
| Wpisy z co najmniej jedną poprawką (bez nowych) | 79 (14,4%) | 84 (17,7%) |
| — w tym wpisy z błędem merytorycznym (bez samych notatek redakcyjnych, zob. niżej) | 63 (11,5%) | 84 (17,7%) |
| Walidator `--file` | 0 błędów, 0 ostrzeżeń | 0 błędów, 0 ostrzeżeń |

Każdy wpis i każdy przykład przeczytałem (kompaktowy widok porcjami po ~26 wpisów). Identyfikatory wpisów są bez zmian. Formatowanie pliku zostało zachowane: formatter ma test round-trip bajt w bajt na obu plikach, a przyrost linii zgadza się z liczbą dopisanych wpisów (c03 +76 linii = 3 wpisy − 1 usunięty przykład; c04 +51 = 2 wpisy). Nie uruchamiałem `build-index.mjs`, `build-core-master.mjs` ani git.

Rozkład CEFR po korekcie: C03 — A1 8 · A2 48 · B1 170 · B2 235 · C1 90; C04 — A1 6 · A2 73 · B1 183 · B2 120 · C1 94 · C2 1.

## 2. Poprawki wg kategorii (pola / wpisy)

| Kategoria | C03 | C04 |
|---|---|---|
| `acceptedTranslations` mieszające znaczenia lub kierunki | 26 / 26 | 42 / 41 |
| Naturalność EN (AmE, kolokacje, nienaturalne zdania) | 53 / 17 | 46 / 15 |
| Polskie tłumaczenia (kalki, rekcja, szyk, `focusPl`) | 35 / 19 | 34 / 17 |
| Zgodność przykładu ze znaczeniem hasła | 23 / 3 | 15 / 3 |
| Gramatyka EN (szyk, elipsa, przyimek) | 4 / 2 | 6 / 3 |
| Pola opisowe (synonimy, kolokacje, definicja, `notePl`, `contextPl`) | 25 / 25 | 9 / 9 |
| CEFR / frequency | 1 / 1 | 3 / 3 |
| IPA | — | 4 / 4 |
| Nowe znaczenia (pełne wpisy) | 3 | 2 |

Pole liczy się jako jedna zmiana, więc wymiana całego przykładu daje 2–4 zmiany. W C04 jedna zastąpiona wymiana (go-ahead) liczy się podwójnie.

## 3. Najważniejsze poprawki

- **Notatki redakcyjne widoczne dla ucznia (C03, 21 wpisów).** W `notePl` autorzy zostawili wewnętrzne adnotacje typu „CEFR obniżony z C1 na B2.” (sail, brilliant, grab, somewhat, variable, merely, core, self, prime, forth, fundamental, distinguish, substantial, occupy, dominate, ease, assure, strain, strip, resistance, entitled). Usunąłem je; merytoryczna część notki została.
- **`core.mate` (C03) — wpis był nieużywalny w lukach.** Wszystkie przykłady używały złożeń (roommate, classmates, teammates). `Cloze.span` szuka `focusEn` jako całego słowa, więc ćwiczenie wymagało wpisania „roommate” zamiast hasła *mate*. Przepisałem wpis na samodzielne AmE *mate* = „partner (zwierzęcia)”. Złożenia są w `notePl`, a przykład z pytaniem został.
- **`acceptedTranslations` akceptujące złe odpowiedzi**, np.:
  - give advice → „dać radę” (= poradzić sobie);
  - surprisingly → „nic dziwnego” (znaczenie odwrotne);
  - in general → „w ogóle” (to *at all*);
  - besides → „obok” (to *beside*);
  - assure → „upewnić” (to *ensure*).

  Usunąłem też warianty innego znaczenia: impression → „parodia”, tank → „czołg”, maker → „ekspres”, ski → „narty”, flag → „sygnał ostrzegawczy”, carbon → „dwutlenek węgla”, servant → „urzędnik państwowy”, estate → „nieruchomości” i in., oraz śmieci typu „gdzie indziej w”, „dźwięku”, „ukarać się”, „być”.
- **Przykład w innym znaczeniu niż hasło:**
  - impression (5. przykład o naśladowaniu) — usunięty;
  - disk („wheel is held on by a disk”) — zastąpiony;
  - go ahead („You go ahead” = iść przodem) — zastąpiony;
  - compromise-2 („compromise on safety” = iść na kompromis) — zastąpiony;
  - possession (narkotyki — treść drażliwa) — zastąpiony.
- **Naturalność / AmE (wybór):**
  - „Were you ill last week?” i „stores shut on Sundays” (brzmią BrE);
  - „banned from driving” → zawieszenie zawodnika;
  - „How many people approximately…” (szyk);
  - „Is it false that bats are blind?”, „Do you understand perfectly…?”;
  - „maximum number of eight people”, „only resort”, „they were nowhere”;
  - „The bus frequency is lower”, „such as for learning words”;
  - „plays in a Little League team” → *on a team*;
  - „voluntary work” → przykład AmE;
  - „have the same birthday in common”, „Spring is here at last, isn't it?”;
  - „treated us like royal guests”, „take it with a grain of salt” w miejsce dziwnego „grain of salt on your tongue”.
- **Polski (wybór):**
  - „kształciła się w uczelni” → na uczelni;
  - „opowiada o dwojgu młodych kochanków” → kochankach;
  - „Nie wyglądasz dziś na siebie” → Nie jesteś dziś sobą;
  - „zawsze zdominuje rozmowę” → dominuje w rozmowie;
  - „zależy mu na jego pracy” → swojej;
  - „Kto jest sponsorem” dla *Who are the sponsors* → Kim są sponsorzy;
  - „pożyczki studenckie” → kredyt studencki (+ „kredyt” w AT);
  - „random question” → „pytanie z innej beczki”;
  - „wręcz przeciwnie” dla *in fact* → „w gruncie rzeczy”;
  - „Obraziła się o mój żart” → Poczuła się urażona moim żartem.
- **IPA:**
  - immigration → /ˌɪmɪˈɡreɪʃən/, jak w bazie;
  - subsequently → /ˈsʌbsɪkwəntli/, spójnie z *subsequent*;
  - lead to /ˈliːd tə/, thanks to /ˈθæŋks tə/ — słaba forma przyimka wg konwencji.
- **CEFR:**
  - burst, mutual, jury: C1 → B2 (wpisy przeniesione do kategorii B2);
  - breast: frequency less_common → common.
- **Kolokacje:** usunięte nieidiomatyczne lub drażliwe: *time framework*, *tower block* i *towel rail* (BrE), *early detected*, *comprise of*, *gas chamber*, *swear to God*, *bring together and unite*.

## 4. Dopisane znaczenia (format §6, 3–4 przykłady, walidator OK)

| id | hasło | znaczenie | CEFR |
|---|---|---|---|
| core.swing-2 | swing (n.) | huśtawka | A2 |
| core.spare-2 | spare (v.) | poświęcić (czas), odstąpić | B1 |
| core.evil-2 | evil (n.) | zło | B2 |
| core.take-out-2 | take out | wynieść (śmieci) | A2 |
| core.fool-2 | fool (v.) | nabrać | B2 |

Sprawdziłem pokrycie znaczeń około 90 częstych haseł obu shardów w całej bazie (attach, insist, approve, recover, rely, plot, sheet, fat, crash, chip, pick up, set up, check out, work out, gear, bat, chest, cap i in.). Pozostałe ważne znaczenia są już w tematach albo w C01–C08.

## 5. Wątpliwości (nierozstrzygnięte)

- **Długość przykładów.** Około 95 zdań w C03 i 70 w C04 ma 4–5 słów, a AGENTS-BRIEF §7 mówi o 6–20. To naturalne, krótkie zdania (np. „Are your grandparents still alive?”), walidator ich nie zgłasza i nie zmieniałem ich. Jeśli limit ma być twardy, potrzebna jest reguła walidatora i osobna fala.
- **Odpowiedniki o innej części mowy w `acceptedTranslations`** (bath → „wykąpać”, divorce → „rozwieść się”, harm → „zaszkodzić”, careful → „uważać”). Zostawiłem je zgodnie z 03b-core-content („jeśli najlepszy polski odpowiednik zmienia część mowy — dopisz”). Usuwałem tylko warianty innego znaczenia lub odwrotnego kierunku.
- **IPA *cigarette*** /ˌsɪɡəˈret/ — obie wymowy AmE są poprawne; Oxford US podaje najpierw /ˈsɪɡəret/. Nie ma tego hasła w bazie, więc zostawiłem.
- **`core.sanction` C2** — pewnie uczciwiej C1, ale to jedyny wpis kategorii `core-c04.c2`. Przeniesienie zostawiłoby pustą kategorię, a to błąd walidatora `category-empty`. Decyzja należy do koordynatora (wtedy trzeba usunąć kategorię).
- **`core.offense` /əˈfens/** różni się od `sports.offense` /ˈɑːfens/. To zamierzone: różne znaczenia mają różną wymowę.
- **Polski znak tłumaczeń z nawiasem** (peak, cloud, bubble, journal, take out…) — zgodnie z instrukcją; wariant bez nawiasu jest w AT.

## 6. Narzędzia (scratchpad `cqa2\`, poza repo)

`view.mjs` (kompaktowy widok), `cmp.mjs` (IPA/CEFR względem bazy), `pat.mjs` (wzorce: a/an, BrE, długość, spacje), `q.mjs` (znaczenia hasła w bazie), `fmt.mjs` + `apply.mjs` (poprawki semantyczne z zachowaniem formatu; walidacja podciągów `focusEn`/`focusPl`; dziennik `log-core-c03.tsv`, `log-core-c04.tsv` — pełna lista zmian pole po polu), `fixes-c03.mjs`, `fixes-c04.mjs`, `fixes-c04-b.mjs`.

## 7. Prośby

- **Koordynator:** po fali uruchomić `build-index.mjs` → `build-core-master.mjs` → pełny `validate-content.mjs`. Doszło 5 nowych wpisów core i zmieniły się poziomy burst, mutual i jury.
- **Autorzy pozostałych shardów i core-qa-1:** sprawdzić `notePl` pod kątem adnotacji „CEFR obniżony/podniesiony…” (w C03 było ich 21). Unikać przykładów, w których hasło występuje tylko w złożeniu (problem jak *mate*), bo luka go nie znajdzie.
