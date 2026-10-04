# Problemy językowe w bankach przeniesionych ze strony (dla english-qa)

Źródło: `node ios/tools/validate-content.mjs` + ręczny przegląd podczas eksportu (`ios/tools/export-web-content.mjs`).
Stan walidatora na bankach: **0 błędów**, 1 ostrzeżenie (queue). Poniżej rzeczy, których walidator nie rozstrzyga albo które wymagają decyzji redakcyjnej.

**Gdzie poprawiać:** pliki banków są generowane — nie edytuj JSON-ów ręcznie, bo następny eksport je nadpisze. Dopisz poprawkę do tablic w `ios/tools/export-web-content.mjs` (`READING_FIXES`, `EXTRA_DISTRACTOR`, `IPA_GA`, `TRANSLATION_OVERRIDE`, albo nową, analogiczną tabelę) i uruchom eksport. Jeśli wolisz poprawiać bezpośrednio, ustal to z koordynatorem: od tego momentu eksport banków przestaje być źródłem prawdy.

## Już poprawione w eksporcie (do wiadomości)

| Plik | id | Było | Jest |
|---|---|---|---|
| readings.json | reading-v39-river-cleanup | rubbish (5×, także w opcjach i evidence) | trash |
| readings.json | reading-legacy-a-useful-interview-lesson | practised (3×) | practiced |
| readings.json | reading-legacy-when-efficiency-becomes-a-habit | recognised | recognized |
| exercises.json | legacy-grammar-2020375993 | dystraktor „would have travelled” | „would have traveled” |
| starter-words.json | starter.* | IPA brytyjskie (/ˈbɒrəʊ/, /ˈbɔːdɪŋ pɑːs/, /əˈkʌmplɪʃ/, /ˌrezəˈveɪʃən/, /teɪk jɔː taɪm/, /ˈfɪɡər aʊt/) | GA: /ˈbɑːroʊ/, /ˈbɔːrdɪŋ ˌpæs/, /əˈkɑːmplɪʃ/, /ˌrezərˈveɪʃən/, /ˌteɪk jʊr ˈtaɪm/, /ˌfɪɡjər ˈaʊt/ |
| starter-words.json | starter.bank | translation „bank — instytucja finansowa” | „bank” |
| starter-words.json | starter.deadline | register „zawodowy” (spoza enumu) | „neutralny” |
| starter-words.json | starter.get-the-hang-of | wariant „jak coś działa” (fragment po przecinku — błąd `polishAnswers` strony) | usunięty |

## Do decyzji english-qa

| Plik | id | Problem | Propozycja |
|---|---|---|---|
| grammar/B2–C2.json | 45 zadań z `hintPl: "analizować"` (np. grammar-36-B2-00-00, grammar-36-C2-05-00) | Podpowiedź „analizować”, a odpowiedź to formy **review** („had already reviewed”). `acceptedAnswers` jest puste, więc uczeń, który wpisze „had already analyzed”, dostanie błąd. Polskie tłumaczenia używają „przeanalizować”. | Dodać do `acceptedAnswers` odpowiadające formy *analyze* (to samo przekształcenie, co w `answer`) **albo** zmienić podpowiedź na „przejrzeć/przeglądać” (w `hintPl` i nawiasie w `context`). Pierwsza opcja jest bezpieczniejsza. |
| readings.json | reading-v39-waiting-list | „created a **queue** for patients…”, „divided between that queue and the online list”, pytanie „What did the new queue aim to address?” | W AmE naturalniej: „a phone-in waiting list” / „a separate call-in list”. Zmienić konsekwentnie w akapicie, pytaniu i evidence (np. regułą w `READING_FIXES`). |
| idioms.json | C2: „Set the cat among the pigeons”, „A curate's egg”, „Carry coals to Newcastle” | Idiomy wyraźnie brytyjskie (strona sama pisze „zwrot szczególnie brytyjski”); aplikacja uczy AmE. | Zastąpić idiomami znanymi w AmE na C2, np. „stir up a hornet's nest”, „a mixed bag”, „preach to the choir”. Wymaga zmiany `context`/`translation`/`explanation` i dystraktorów pozostałych pytań (dystraktory to znaczenia innych idiomów poziomu). |
| idioms.json | C2: „Hoist with his own petard” | W AmE częstsza forma „hoist by his own petard”. | Zmienić na „hoisted by his own petard” (w kontekście: „he was hoisted by his own petard”). |
| starter-words.json | starter.do-2 | `translation: "czasownik pomocniczy w pytaniach"` to opis gramatyczny, a nie tłumaczenie; w zadaniu PL→EN uczeń widzi opis. | Usunąć to znaczenie z zestawu startowego albo dać `translation: "(pytanie) Czy…?"` + `notePl` z wyjaśnieniem; `acceptedTranslations: ["czy"]`. |
| starter-words.json | 18 przykładów krótszych niż 6 słów (np. „Can I borrow your pen?”, „What did you say?”, „Do you like coffee?”, „A small bag will do.”) | Standard §7: przykłady 6–20 słów, osadzone w konkretnej scenie. | Rozbudować do 6–12 słów (np. „Can I borrow your pen for a minute?”), pamiętając o `pl`/`focusPl`. |
| starter-words.json | starter.make | Przykład „I want to make a cake.” ↔ „Chcę upiec ciasto.” (focusPl „upiec”) | OK znaczeniowo, ale `translation` „zrobić, stworzyć” nie obejmuje „upiec”. Ewentualnie zmienić przykład na „Let's make dinner together tonight.” |
| starter-words.json | starter.tell | `acceptedTranslations` przycięte do 8 z 10 wariantów strony (limit schematu). | Bez zmian: pełna lista jest w `answer-variants.json` i silnik ocen ją łączy. Do potwierdzenia przez core-engine. |
| readings.json | 12 czytanek `reading-legacy-*` | Na stronie od v39 nieużywane (martwy kod `tutor-local.ts`, `advanced-readings.ts`); `topic: ""`. | Przejrzeć jakość; uzupełnić `topic` (słowa kluczowe PL/EN jak w banku v39) lub usunąć z eksportu. |
| answer-variants.json | take your time | „nie spiesz się” i „nie śpiesz się” (obie formy poprawne) | Bez zmian. Informacyjnie: walidator nie traktuje już tego jako duplikatu. |

## Uwagi o heurystykach (dla english-qa uruchamiającego walidator)

- `british-vocab`, `british-spelling`, `article`, `repeated-word`, `ipa-british`, `term-case` to **ostrzeżenia**: mogą być fałszywe dla słów wieloznacznych (flat, lift, holiday, autumn).
- Gramatyka (1800 zadań) przeszła sprawdzenie pisowni BrE po wstawieniu odpowiedzi w lukę, sprawdzenie a/an i powtórzeń, sprawdzenie dystraktorów (≠ odpowiedź, bez duplikatów, poprawne diagnozy) — bez uwag. Walidator **nie** ocenia, czy polska podpowiedź odpowiada angielskiemu czasownikowi (patrz „analizować”).
