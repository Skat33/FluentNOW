# Raport: vocab-idioms — idiomy amerykańskie (FEEDBACK-10 P4)

Raport agenta vocab-idioms (zapis `.md` przez subagenta był zablokowany — zapisał koordynator, w skrócie).

## 1. Wynik

| plik | B1 | B2 | C1 | C2 | razem | przykłady |
|---|---|---|---|---|---|---|
| core-c10 (ciało, emocje, zwierzęta) | 5 | 110 | 92 | 5 | **212** | 645 |
| core-c11 (jedzenie, natura i kolory, pieniądze i biznes, sport i gry, czas i dom, przedmioty, przysłowia) | 6 | 112 | 110 | 1 | **229** | 693 |
| **razem** | 11 | 222 | 202 | 6 | **441** | **1338** |

- Format jak `core-c09`; `pos: "idiom"` (wyjątek: *sugarcoat* — czasownik). Walidator `--file` 0/0 dla obu plików.
- Każdy wpis: 3–5 przykładów w różnych czasach i konstrukcjach, polski odpowiednik (najlepiej polski idiom: *wbić komuś nóż w plecy, robić z igły widły, z deszczu pod rynnę*), warianty opisowe w `acceptedTranslations`, definicja EN, `contextPl`, rejestr, kolokacje, synonimy; `notePl` przy wariantach BrE, fałszywych przyjaciołach (*a gray area* ≠ „szara strefa”), rejestrze.
- IPA GA ze słabymi formami przyimków i zaimków; `forms` wg CONTENT-SCHEMA §1.

## 2. Duplikaty i granice

- 1057 kandydatów porównanych z bazą (term + `acceptedAnswers` + `dictionary-index.json`, warianty *someone/something*, *one's/your*); ok. 70 odrzuconych jako już obecne.
- Usunięte `acceptedAnswers` kolidujące z innym znaczeniem w bazie (*heads up*, *breathtaking*, *mind-blowing*, *thick-skinned*, *penny-pincher*, *honeymoon phase*).
- Granica z vocab-phrases uzgodniona: zwroty konwersacyjne (*no sweat, it is what it is, you can say that again…*) i wyrażenia graniczne (*at the end of the day, on the other hand*) — po stronie vocab-phrases; *on the house, in a nutshell, not the end of the world* — tutaj.

## 3. Wątpliwości (dla vocab-qa)

1. Bliskoznaczne pary (PL→EN mogą się mylić): *eat crow / eat your words*, *work like a dog / work your fingers to the bone*, *see red / make someone's blood boil / drive someone up the wall*, *a shot in the dark / a long shot*, *on top of the world / over the moon*.
2. Ok. 40 przysłów — `focusEn` obejmuje całe przysłowie (długa luka).
3. Rejestr/temat: *kick the bucket, don't have a cow* (slang), *the hair of the dog, drink like a fish* (alkohol), *the birds and the bees*.
4. CEFR graniczne: *hands down, the upper hand, a no-brainer, wing it* (B2).
5. Warianty BrE tylko w `acceptedAnswers` (dla zrozumienia): *spilt milk, a storm in a teacup, a drop in the ocean…*.

Skrypty: scratchpad `vidioms\` (lib/check/d01–d08/gen.mjs). Pełna lista haseł — w plikach `core-c10.json`, `core-c11.json`.
