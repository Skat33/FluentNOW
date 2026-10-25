# Raport: core-content, shard C05

## 1. Co zrobiono

Plik: `ios/FluentNOW/Resources/Content/core/core-c05.json` (nowy, format §6 CONTENT-SCHEMA). Kategorie `core-c05.a2`, `.b1`, `.b2`, `.c1`. W każdej kategorii wpisy idą w kolejności z listy roboczej. Innych plików bazy nie zmieniałem.

| | Liczba |
|---|---|
| Haseł na liście sharda | 775 (397 `new`, 25 `partial`, 353 `check`) |
| Napisane hasła `new` | 397 / 397 |
| Uzupełnione hasła `partial` | 19 / 25 (6 pominiętych, zob. §3) |
| Hasła `check` z dopisanym ogólnym znaczeniem | 36 |
| Pominięte hasła `check` (ogólne znaczenie już jest w bazie) | 317 |
| **Wpisy (znaczenia)** | **490** (452 różne `term`) |
| **Przykłady** | **1745** (3 przykłady: 222 wpisy, 4: 261, 5: 7) |

Rozkład CEFR: A2 1 · B1 109 · B2 378 · C1 2.
Części mowy: przymiotnik 126, rzeczownik 100, czasownik frazowy 76, zwrot 75, przysłówek 48, czasownik 45, spójnik 6, idiom 5, przyimek 5, wykrzyknik 2, zaimek 2.

Walidator: `node ios/tools/validate-content.mjs --file …/core/core-c05.json` → **OK: plików 1, wpisów 490, błędów 0, ostrzeżeń 0**. Sprawdzone są też `duplicate-example` i `duplicate-term-translation` względem C01–C04 w stanie z chwili walidacji. Poprawiłem przykład w `core.in-contrast`, który zgłosił koordynator (był identyczny z przykładem w core-c02).

Narzędzi `build-index.mjs` i `build-core-master.mjs` (bez `--shard`) nie uruchamiałem. Gita też nie.

## 2. Decyzje redakcyjne

- **Wiele znaczeń jako osobne wpisy**, np.:
  - *be supposed to*: „mieć coś zrobić” / „podobno”,
  - *uncomfortable*: niewygodny / nieswojo,
  - *absorb*: wchłaniać / przyswoić,
  - *authority*: władza / władze / autorytet,
  - *identification*: identyfikacja / dokument tożsamości,
  - *pole*: słup / biegun,
  - *neat*: schludny / fajny (AmE),
  - *goodness*: dobroć / „o rany”,
  - *pity*: szkoda / litość,
  - *shame*: szkoda / wstyd,
  - *overlook*: przeoczyć / wychodzić na,
  - *at once*: natychmiast / naraz,
  - *dye* n./v., *dislike* n./v., *envy* n./v., *sacrifice* n./v., *understanding* n./adj.
- **Czasowniki frazowe z kilkoma znaczeniami**:
  - *cut down*: ograniczyć / ściąć,
  - *fall out*: pokłócić się / wypadać,
  - *give out*: rozdawać / odmówić posłuszeństwa,
  - *knock out*: znokautować / wyeliminować,
  - *pull out*: wycofać się / wyciągnąć,
  - *turn in*: oddać / iść spać,
  - *tear up*: podrzeć / wzruszyć się,
  - *wait on*: obsługiwać / czekać na,
  - *get around*: poruszać się / obejść,
  - *set out*: postanowić / wyruszyć,
  - *bring in*: wprowadzić / przynosić dochód,
  - *bring out*: wydać / wydobyć,
  - *break in*: włamać się / rozchodzić buty,
  - *put down*: odłożyć / poniżać,
  - *blow up*: wysadzić / nadmuchać,
  - *take down*: zdjąć / zanotować.
- **Hasła `check` z dopisanym ogólnym znaczeniem** (w bazie było tylko znaczenie tematyczne):
  - *for sure* „na pewno” (w bazie: „jasne”), *chew* „żuć”, *quit* „rzucić nałóg / przestać”, *recharge* „naładować akumulator” (w bazie: przenośnie),
  - *unlock* „otworzyć zamek”, *departure* „wyjazd / odejście”, *admission* „przyjęcie na studia”, *carrier* „przewoźnik / operator”, *clue* „wskazówka”,
  - *conscious* „świadomy”, *fiber* „włókno”, *flexibility* „elastyczność”, *interact* „kontaktować się”, *neat* ×2, *pole* ×2, *replacement* „następca / zamiennik”, *valid* „uzasadniony”,
  - *get by* „radzić sobie”, *take over* „przejąć”, *put down* ×2, *set off* „wyruszyć”, *bring up* „wychować”, *cut off* „odciąć”, *pay off* „opłacić się”, *run over* „przejechać”, *back up* „poprzeć”, *blow up* ×2, *take down* ×2, *follow up* „zająć się dalej”, *go with* „zdecydować się na”, *on board* „być za”,
  - *bitter* „rozgoryczony”, *dull* „nudny”, *handy* „przydatny”, *inspect* „skontrolować”, *outstanding* „wybitny”.
- **Nawias w `translation` rozróżnia znaczenia**, np. „zaraz (coś zrobić)”, „mieć (coś zrobić)”, „lepiej (żeby)”, „naładować (akumulator)”, „otworzyć (zamek)”, „przyjęcie (na studia)”, „autorytet (ekspert)”, „farba (do włosów)”, „przyswoić (wiedzę)”, „ściąć (drzewo)”, „rozchodzić (buty)”, „przynosić (dochód)”, „wydać (produkt)”, „wykorzystywać (kogoś)”, „za (czymś)”, „od (tego czasu)”. W `acceptedTranslations` jest zawsze też wariant bez nawiasu.
- *contrary*: wpis przymiotnikowy (głównie w zwrocie *contrary to* = wbrew). Wpis *on the contrary* usunąłem, bo jest już w `opinions-agreeing`.
- *communist*: tylko przymiotnik, z przykładami historycznymi (PRL). Rzeczownik pominąłem, żeby nie wchodzić w politykę.
- Przy hasłach, w których polski odpowiednik zmienia część mowy, ten odpowiednik jest w `acceptedTranslations`, np. *be likely to* → „prawdopodobnie”, *willing* → „chętnie”, *awake* → „nie śpię”.

## 3. Pominięte hasła, zmiany CEFR i części mowy

**Pominięte `partial`.** Znaczenie jest już w bazie, tylko pod inną częścią mowy. Nowy wpis dałby `core-in-base`:

| Hasło | Co jest w bazie |
|---|---|
| *give someone a hand* | idiom „pomóc komuś” |
| *from time to time* | idiom „od czasu do czasu” |
| *by far* | przysłówek „zdecydowanie” |
| *for the time being* | idiom „na razie” |
| *take it or leave it* | zwrot „albo bierzesz, albo nie” |
| *get to the point* | zwrot „przejść do rzeczy” |

Proponuję, żeby koordynator przestawił te hasła na `done`.

**Hasło `partial` uzupełnione innym znaczeniem:** *up to date* dostało zwrot „na bieżąco” (keep someone up to date). W bazie jest tylko przymiotnik „zaktualizowany”. *inside out* dostało znaczenie „na wylot” (know something inside out). Znaczenie „na lewą stronę” jest już w bazie.

**CEFR inny niż w liście:**
- *hug* (rzeczownik): B1 → A2,
- *pity* „szkoda”, *shame* „szkoda”, *goodness* (wykrzyknik): B2 → B1,
- *departure* „wyjazd / odejście”: B1 → B2 (ogólne znaczenie),
- *pardon* (czasownik „ułaskawić”): C1. Dodatkowo *pardon* „słucham?” jako wykrzyknik B1,
- *authority* „autorytet (ekspert)”: C1,
- *understanding* (przymiotnik „wyrozumiały”): B2.

**Części mowy dodane spoza listy:** *understanding* (przymiotnik), *goodness* i *pardon* (wykrzyknik), drugie znaczenia frazowców wymienione w §2.

## 4. Ryzyka i wątpliwości dla QA

- Hasła z wielokropkiem w `term` (*not only... but also*, *neither... nor*) mają `focusEn` obejmujące cały fragment zdania między członami. `acceptedAnswers` zawiera też pojedyncze człony.
- Kilka wpisów przyjmuje tłumaczenie, które pokrywa się z innym hasłem core. Klucz term+tłumaczenie jest różny, więc walidator tego nie zgłasza. Przykłady: *once in a while* / *now and then* / *every now and then* (od czasu do czasu); *do without* / *go without*; *set off* / *set out-2* (wyruszyć).
- *shut up* i *naughty* mają w `notePl` uwagę o rejestrze.
- *bullet*, *punch*, *pardon* (ułaskawić) i *revenge* mają neutralne przykłady (filmy, sport, wiadomości), bez treści drastycznych.
- Przykłady są unikalne względem całej bazy w chwili walidacji. Jeśli C02 albo C04 dopiszą później identyczne zdanie, błąd pokaże się po ich stronie.

## 5. Prośby do innych ról

- **Koordynator:** po fali uruchomić `build-index.mjs` → `build-core-master.mjs` → pełny `validate-content.mjs`. Statusy 36 haseł `check` z dopisanymi znaczeniami i 6 pominiętych `partial` z §3 zaktualizują się dopiero po przeliczeniu.

## 6. Narzędzia robocze (poza repozytorium)

Scratchpad, katalog `…/scratchpad/c05w/`:
- `b01.txt` … `b14.txt` — treść w zwięzłym formacie,
- `conv.mjs` — konwerter oparty na skrypcie z C03, rozszerzony o kontrolę 6–20 słów, kropki, wymogu pytania lub przeczenia oraz obecności `translation` w `t:`,
- `fix.mjs` i `del.mjs` — podmiana linii i usuwanie wpisów,
- `stats.mjs` — statystyki pokrycia listy.
