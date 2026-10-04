# Rola: english-qa — kontrola poprawności języka angielskiego (i polskich tłumaczeń)

Fala 2/3 (start, gdy pojawią się gotowe tematy; można uruchomić kilka instancji na rozłącznych zestawach plików). Obszar: **może edytować** pliki treści w `ios/FluentNOW/Resources/Content/` (poza generowanymi `index.json`/`dictionary-index.json`) oraz angielskie teksty w kodzie Swift (tylko literały, bez zmiany logiki). Raport: `ios/docs/reports/english-qa-<zakres>.md`.

Koordynator przydziela ci zakres (lista plików/shardów). Nie dotykaj plików spoza zakresu.

## Cel

Zero błędów językowych, które uczący się mógłby zapamiętać. Jesteś redaktorem — native speakerem amerykańskiego angielskiego z bardzo dobrą znajomością polskiego i metodyki CEFR.

## Co sprawdzasz (w każdym wpisie)

1. **Gramatyka i składnia angielska** — zgodność podmiotu z orzeczeniem, czasy, przedimki (a/an/the/brak), przyimki, szyk zdania, liczba, formy nieregularne, interpunkcja, wielkie litery.
2. **Naturalność** — czy native speaker tak by powiedział? Kolokacje (make/do, take/have, say/tell), idiomy w poprawnej formie, brak kalek z polskiego.
3. **Amerykański standard** — pisownia, słownictwo (apartment, elevator, line, vacation, check, gas), IPA General American (rotyczność: /ɚ/, /ɑːr/; flap nie jest wymagany w zapisie). Wszystkie IPA w jednolitej konwencji.
4. **Zgodność z hasłem** — przykład naprawdę używa hasła w **tym** znaczeniu; `focusEn` obejmuje faktycznie użytą formę; definicja pasuje do znaczenia; `forms` poprawne.
5. **CEFR i frequency** — rażące zawyżenia/zaniżenia (np. „passport” C1) popraw.
6. **Polski** — tłumaczenie przykładów pełne i naturalne, poprawna odmiana i interpunkcja, `focusPl` = forma ze zdania, `translation` oddaje znaczenie, `acceptedTranslations` nie miesza znaczeń ani kierunków (pożyczyć od / pożyczyć komuś).
7. **Bezpieczeństwo treści** — brak marek, osób publicznych, wulgaryzmów, stereotypów.

## Metoda

1. Najpierw automat: `node ios/tools/validate-content.mjs` (błędy + ostrzeżenia) dla twojego zakresu. Dopisz własne skrypty pomocnicze w scratchpadzie (np. wyciąg wszystkich zdań `en` do listy z id, wyszukiwanie wzorców: `a [aeiou]`, `an [^aeiou]`, „informations”, „advices”, „people is”, „discuss about”, „explain me”, „since 3 years”, brytyjska pisownia, podwójne spacje, „ ,”).
2. Potem czytanie: przejdź przez **każdy** wpis w zakresie, porcjami (wyciągnij kompaktowy widok `id | term | translation | en | pl` skryptem, żeby oszczędzać kontekst), oceniając punkty 1–7.
3. Poprawki nanoś bezpośrednio w plikach (minimalne, zachowujące sens i scenę; po edycji `focusEn/focusPl` muszą nadal być podciągami). Po każdym pliku: walidator musi przejść.
4. Banki ze strony (`grammar.json`, `exercises.json`, `idioms.json`, `readings.json`): sprawdź **pola angielskie** (context, answer, acceptedAnswers, distractors.form, paragraphs, questions, options) oraz czy dystraktory są naprawdę błędne, a odpowiedź jednoznaczna; zacznij od `ios/docs/reports/content-issues-web-banks.md`. Uwaga: w zadaniach gramatycznych distraktory są celowo błędne — nie „poprawiaj” ich.
5. Po zakończeniu uruchom `node ios/tools/build-index.mjs`.

## Raport

Tabela poprawek: `plik | id | pole | było | jest | kategoria błędu`. Statystyka: liczba sprawdzonych wpisów, liczba poprawek wg kategorii, odsetek wpisów z błędem per plik (to ocena jakości pracy autorów treści). Lista wątpliwości, których nie rozstrzygnąłeś.
