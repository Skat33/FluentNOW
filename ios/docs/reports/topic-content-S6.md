# Raport: topic-content, shard S6

Status: **shard ukończony** – 12/12 tematów, 815 wpisów, 0 błędów i 0 ostrzeżeń walidatora (pełny przebieg `validate-content.mjs` na całej bazie: 86 plików, 0 błędów). Po zakończeniu uruchomiono `node ios/tools/build-index.mjs` (72 tematy, 5755 wpisów w tematach, 5776 rekordów słownika).

## 1. Co zrobiono (pliki)

Wszystkie pliki w `ios/FluentNOW/Resources/Content/topics/`:

| id | wpisów | kategorii | A1 | A2 | B1 | B2 | C1 | C2 |
|---|---|---|---|---|---|---|---|---|
| smartphones-apps | 109 | 7 | 9 | 34 | 51 | 13 | 2 | 0 |
| computers-internet | 83 | 6 | 3 | 22 | 40 | 12 | 6 | 0 |
| social-media | 62 | 5 | 1 | 12 | 27 | 13 | 9 | 0 |
| cybersecurity | 62 | 5 | 1 | 10 | 23 | 18 | 10 | 0 |
| banking | 67 | 5 | 2 | 15 | 27 | 18 | 5 | 0 |
| shopping-clothes | 62 | 5 | 8 | 17 | 23 | 12 | 2 | 0 |
| online-shopping | 62 | 5 | 3 | 13 | 27 | 13 | 5 | 1 |
| personal-finance | 61 | 5 | 1 | 8 | 23 | 16 | 13 | 0 |
| post-office | 61 | 5 | 6 | 15 | 19 | 18 | 3 | 0 |
| police-crime | 61 | 5 | 1 | 14 | 22 | 16 | 8 | 0 |
| school | 63 | 5 | 9 | 19 | 23 | 10 | 2 | 0 |
| university | 62 | 5 | 1 | 5 | 19 | 27 | 9 | 1 |
| **razem** | **815** | **63** | 45 | 184 | 324 | 186 | 74 | 2 |

Pliki generowane (nie edytowane ręcznie, tylko przebudowane skryptem data-pipeline): `topics/index.json`, `dictionary-index.json`.

Nie brałem tematów z „Pomysłów dodatkowych” (zgodnie z poleceniem koordynatora), więc `docs/topic-claims/S6.md` nie powstał.

## 2. Kontrakty

Bez zmian – pliki są dokładnie w formacie `CONTENT-SCHEMA.md` §1. Kilka konwencji, z których mogą korzystać inni:
- Dwa znaczenia tego samego hasła w temacie mają sufiks `-2` (`social-media.post` / `post-2`, `school.grade` = klasa (rocznik) / `grade-2` = ocena, `post-office.mail` = czasownik / `mail-2` = rzeczownik).
- `focusEn` czasem jest formą odmienioną lub wariantem hasła (np. `put my phone on silent` dla `put your phone on silent`) – zawsze dokładny podciąg zdania.
- Symbole SF: `iphone`, `desktopcomputer`, `bubble.left.and.bubble.right`, `lock.shield`, `building.columns`, `bag`, `cart`, `banknote`, `envelope`, `shield`, `backpack` (SF Symbols 4, iOS 16+), `graduationcap`.

## 3. Odstępstwa od strony

- Treść pisana ręcznie zamiast generowania przez Gemini (TOPIC_PROMPT + TOPIC_HYDRATE_PROMPT). Każda kategoria ma konkretną scenę (`scenePl`), a oba przykłady dzieją się w niej w dwóch różnych momentach.
- Realia amerykańskie świadomie: checking account, routing number, direct deposit, zip code, PO box, certified mail, sales tax, GPA, honor roll, freshman, dorm itp. W `notePl` dodane są wyjaśnienia różnic AmE/BrE i fałszywych przyjaciół (borrow/lend, fit/suit, on sale/for sale, ring/call, „recipe” nie dotyczy).
- W temacie police-crime pominięte są drastyczne słowa (np. „mug”, przemoc). Zostały kradzieże, włamania, wandalizm i procedury.

## 4. Znane ryzyka / rzeczy niesprawdzone

- IPA pisana ręcznie (GA, z ɝ/ər, ɑː dla „lot”, ɔː dla „thought”). Nie przeszła weryfikacji przez słownik zewnętrzny, warto, żeby english-qa wyrywkowo ją sprawdził.
- CEFR i `frequency` to ocena redakcyjna. Najmniej pewne są hasła potoczne i kulturowe (porch pirate C1, restocking fee C2, valedictorian C2, doomscrolling C1, loaded C1).
- Hasła z wielkimi literami są celowe (nazwy własne lub skróty): Bluetooth, Wi-Fi, Ethernet cable, PDF, DM, FOMO, VPN, ATM, PIN, Black Friday, GPA, PO box, straight A's. Walidator ich nie zgłasza.
- Część pojęć powtarza się w kilku tematach, w innych scenach i z innymi przykładami, co dopuszcza TOPICS-MASTER: steal, refund, receipt, freeze, password, lock, delete, share, package, check-out/checkout, paper, deadline. Walidator sprawdza duplikaty przykładów między plikami i obecnie nie ma żadnych. Dwa moje przykłady pokrywały się z `customer-service.json` (S5), więc je przepisałem.
- Treść źródłowa (format kompaktowy + generator `gen.mjs`) leży tylko w scratchpadzie sesji. Źródłem prawdy są pliki JSON w repo.

## 5. Prośby do innych ról

- **english-qa**: wyrywkowa kontrola IPA i CEFR (patrz pkt 4), zwłaszcza w smartphones-apps (największy plik, 109 wpisów).
- **data-pipeline**: brak. Walidator i build-index działały bez problemów.
- **ui-library**: brak. W `TOPICS-MASTER` są niezależne tematy shopping-clothes (proces zakupów w sklepie) i clothes-fashion (S1, nazwy ubrań), więc przeglądarka tematów może je pokazywać obok siebie w grupie „Pieniądze i zakupy” / „Codzienność”.

## 6. Testy i wynik skryptów

- `node ios/tools/validate-content.mjs --file <plik>` dla każdego z 12 plików: `OK`, 0 błędów, 0 ostrzeżeń.
- `node ios/tools/validate-content.mjs --errors-only` (cała baza): `OK: plików 86, wpisów 5776, błędów 0`.
- `node ios/tools/build-index.mjs`: `tematów: 72, wpisów w tematach: 5755, rekordów słownika: 5776`.
- Generator S6 dodatkowo sprawdzał: dokładnie dwa przykłady, znaczniki fokusu, 6–20 słów w zdaniu EN, brytyjskie formy, długość definicji i contextPl, unikalność id i przykładów w temacie.
