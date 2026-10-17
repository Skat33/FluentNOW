# Raport: english-qa, zakres QA-T3 (shardy S5 + S6, 24 tematy)

Zapisany przez koordynatora na podstawie odpowiedzi agenta (agent nie mógł zapisać pliku `.md`). Pełny dziennik 203 zmian pól: `english-qa-T3-changes.md`.

## Wynik
- 24 tematy, 1711 wpisów przejrzanych ręcznie; walidator 0 błędów / 0 ostrzeżeń; indeksy przebudowane (142 tematy, 10 711 rekordów słownika). Identyfikatory bez zmian.
- **IPA**: wspólna konwencja z T2 (styl Oxford Learner's US: /e/ zamiast /ɛ/, /ɜːr/ akcentowane, /ər/ nieakcentowane, bez ɝ/ɚ) zastosowana w 363 wpisach (`ipa` + transkrypcje w `forms`/`notePl`); ręcznie poprawiony akcent w 11 złożeniach (portable charger, human resources, academic advisor…).
- **Poprawki merytoryczne**: 135 wpisów (7,9%), 203 pola.

| kategoria | wpisów |
|---|---|
| acceptedAnswers / acceptedTranslations mieszające znaczenia (toner→„tusz”, frozen→„zamarznąć”, warranty→„rękojmia”, thief→„robber”…) | 46 |
| polskie tłumaczenia (kalki, rekcja po przeczeniu, opisowe → naturalne: cabin fever → „syndrom czterech ścian”) | 42 |
| gramatyka i interpunkcja EN (comma splice ~20×, cudzysłowy, czasy, mowa zależna) | 27 |
| CEFR i rejestr | 14 |
| IPA — akcent (ręcznie) | 11 |
| przykład niepasujący do znaczenia (reference, keep happening, wire transfer) | 4 |
| naturalność EN | 4 |
| focusPl niezgodny ze zdaniem | 3 |

Najwięcej błędów: smartphones-apps 14,7%, salary-benefits 13,7%; najmniej: coworkers 2,9%, banking 3,0%.

## CEFR
- restocking fee, valedictorian: C2/rare → C1/less_common.
- C1 → B2: FOMO, clickbait, call out, deactivate, footage, charge (zarzut), GPA, live paycheck to paycheck, Ethernet cable.
- B2 → B1: typo, worksheet. Rejestr „fire” (zwolnić): potoczny → neutralny.
- Bez zmian (uczciwe): porch pirate, doomscrolling, loaded (C1).

## Wątpliwości
- Identyczne tłumaczenia w jednym temacie (keep someone posted / keep someone in the loop = „informować na bieżąco”) — ryzyko dwóch poprawnych odpowiedzi, gdy jedno trafi jako dystraktor drugiego.
- Przecinek kontrastowy („I didn't block him, I just muted him.”) zostawiony — standard AmE.
- Korporacyjne zapożyczenia (benefity, onboarding, feedback) zostawione, z polskimi wariantami w `acceptedTranslations`.
- CEFR haseł kulturowych USA i IPA — ocena redakcyjna, bez dostępu do słownika zewnętrznego.

## Prośby
- Pozostałe zakresy english-qa: zamienić ok. 190 ɝ/ɚ (i ɛ) wg konwencji.
- core-engine / ui-learning: przy losowaniu dystraktorów pomijać hasła z identycznym `translation` jak poprawna odpowiedź.
