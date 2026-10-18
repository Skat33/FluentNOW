# Kontrakt treści wbudowanej (CONTENT-SCHEMA)

Wszystkie pliki w `ios/FluentNOW/Resources/Content/`. JSON UTF-8, klucze camelCase. Każdy plik najwyższego poziomu ma `"schemaVersion": 1`.
Walidator: `node ios/tools/validate-content.mjs` (pisze go data-pipeline; topic-content i english-qa muszą go uruchamiać).
Dekodery Swift w FluentKit (`Sources/FluentKit/Content/`) odpowiadają **dokładnie** temu dokumentowi. Zmiana schematu = zmiana tego pliku + walidatora + dekoderów, zgłoszona w raporcie.

## 1. Tematy słówek — `topics/<topicId>.json`

Jeden plik na temat. `topicId` = kebab-case po angielsku, np. `airport`, `doctor-visit`.

```json
{
  "schemaVersion": 1,
  "id": "airport",
  "namePl": "Lotnisko",
  "nameEn": "Airport",
  "group": "travel",
  "symbol": "airplane.departure",
  "summaryPl": "Odprawa, kontrola bezpieczeństwa, bramki, bagaż i opóźnienia.",
  "aliases": ["lotnisko", "port lotniczy", "odprawa", "airport", "lot"],
  "categories": [
    {
      "id": "airport.check-in",
      "namePl": "Odprawa i bagaż",
      "scenePl": "Stanowisko odprawy linii lotniczej przed wylotem",
      "entries": [ /* Entry, kolejność: od najczęstszych w mowie */ ]
    }
  ]
}
```

### Entry

```json
{
  "id": "airport.boarding-pass",
  "term": "boarding pass",
  "ipa": "/ˈbɔːrdɪŋ ˌpæs/",
  "pos": "rzeczownik",
  "level": "A2",
  "frequency": "common",
  "translation": "karta pokładowa",
  "definition": "A document that allows a passenger to get on a plane.",
  "register": "neutralny",
  "contextPl": "Odprawa i wejście na pokład",
  "natural": "",
  "forms": "boarding passes",
  "collocations": "print a boarding pass; mobile boarding pass; show your boarding pass",
  "synonyms": "boarding card",
  "antonyms": "",
  "notePl": "",
  "examples": [
    { "en": "Please have your boarding pass ready at the gate.", "pl": "Prosimy mieć kartę pokładową gotową przy bramce.", "focusEn": "boarding pass", "focusPl": "kartę pokładową" },
    { "en": "I downloaded my boarding pass to my phone last night.", "pl": "Wczoraj wieczorem pobrałem kartę pokładową na telefon.", "focusEn": "boarding pass", "focusPl": "kartę pokładową" }
  ],
  "acceptedAnswers": ["boarding pass", "boarding card"],
  "acceptedTranslations": ["karta pokładowa", "karta wejścia na pokład"]
}
```

Reguły (sprawdzane walidatorem):

| Pole | Reguła |
|---|---|
| `id` | `<topicId>.<kebab-term>`; unikalne w całej bazie; dla dwóch znaczeń tego samego słowa w temacie dodaj sufiks `-2` |
| `term` | angielskie hasło w formie słownikowej, małe litery (poza nazwami własnymi / „I”), bez kropki |
| `ipa` | General American, w `/.../`; dla długich zwrotów można pominąć (`""`) |
| `pos` | jedno z: `rzeczownik`, `czasownik`, `czasownik frazowy`, `przymiotnik`, `przysłówek`, `zwrot`, `idiom`, `przyimek`, `spójnik`, `zaimek`, `wykrzyknik`, `liczebnik` |
| `level` | `A1`…`C2` dla tego konkretnego znaczenia |
| `frequency` | `very_common`, `common`, `less_common`, `rare` (częstość w codziennej mowie amerykańskiej) |
| `translation` | krótkie polskie tłumaczenie tego znaczenia (bez „(AmE)”) |
| `definition` | proste angielskie wyjaśnienie, 1 zdanie, ≤ 140 znaków |
| `register` | `neutralny`, `potoczny`, `formalny`, `specjalistyczny`, `slangowy` |
| `contextPl` | kiedy się tego używa, po polsku, ≤ 80 znaków |
| `natural` | opcjonalnie: bardziej potoczny odpowiednik angielski, inaczej `""` |
| `forms` | formy nieregularne / liczba mnoga / odmiana czasownika (`go – went – gone`), inaczej `""` |
| `examples` | **dokładnie 2**; `focusEn` ⊂ `en`, `focusPl` ⊂ `pl` (dokładny podciąg, wielkość liter też); `en` kończy się `.`, `?` lub `!` |
| `acceptedAnswers` | angielskie warianty akceptowane przy przypominaniu (zawiera `term`) |
| `acceptedTranslations` | 1–8 polskich odpowiedników tego znaczenia (zawiera `translation` lub jego rdzeń), z parami aspektowymi gdy równoważne (`pożyczyć`, `pożyczać`) |
| Puste pola | zawsze `""` lub `[]`, nigdy `null` ani brak klucza |

Na temat: 60–120 wpisów, 4–9 kategorii, w kategorii od najczęstszych do najrzadszych; najpierw rdzeń bez którego nie da się funkcjonować w sytuacji. Pełny zakres A1–C2 bez sztucznego wyrównywania.

## 2. Indeks tematów — `topics/index.json` (GENEROWANY, nie edytować ręcznie)

`node ios/tools/build-index.mjs` tworzy:

```json
{
  "schemaVersion": 1,
  "generatedAt": "2026-10-03T12:00:00Z",
  "groups": [ { "id": "travel", "namePl": "Podróże", "symbol": "airplane" } ],
  "topics": [
    { "id": "airport", "namePl": "Lotnisko", "nameEn": "Airport", "group": "travel", "symbol": "airplane.departure",
      "summaryPl": "…", "aliases": ["…"], "entryCount": 96,
      "levels": { "A1": 10, "A2": 30, "B1": 31, "B2": 18, "C1": 6, "C2": 1 },
      "categories": [ { "id": "airport.check-in", "namePl": "Odprawa i bagaż", "entryCount": 18 } ] }
  ]
}
```

Grupy (stała lista, `id` → `namePl`): `basics` Podstawy, `travel` Podróże, `food` Jedzenie i picie, `home` Dom, `health` Zdrowie, `work` Praca i biznes, `education` Nauka, `technology` Technologia, `money` Pieniądze i zakupy, `services` Urzędy i usługi, `people` Ludzie i relacje, `daily` Codzienność, `leisure` Czas wolny, `nature` Przyroda, `society` Społeczeństwo, `communication` Komunikacja.

## 3. Indeks wyszukiwania słownika — `dictionary-index.json` (GENEROWANY)

Do szybkiego dodawania słowa (wpisz hasło → natychmiastowe propozycje znaczeń). Kompaktowy:

```json
{ "schemaVersion": 1,
  "entries": [ { "t": "boarding pass", "k": "boarding pass", "p": "karta pokładowa", "l": "A2", "f": "common", "r": "airport/airport.boarding-pass" } ] }
```
`k` = klucz znormalizowany (małe litery, bez diakrytyków, `’`→`'`, pojedyncze spacje). `r` = `<plik tematu bez .json>/<entry id>` albo `starter/<id>`. Wiele znaczeń jednego hasła = wiele rekordów z tym samym `k`. Posortowane po `k`.

## 4. Banki przeniesione ze strony (data-pipeline)

Nazwy pól **identyczne jak typy TypeScript** w `web-source/lib/tutor-types.ts` (camelCase). Każdy plik: `{ "schemaVersion": 1, "source": "web-v42", ... }`.

| Plik | Zawartość | Typ TS |
|---|---|---|
| `grammar/<poziom>.json` (zamiast `grammar.json`, patrz §5.1) | `{ "version": 36, "level": "A1", "rules": […], "items": [ProductionItem…] }` | `ProductionItem` (z `grammar-bank.json`) |
| `exercises.json` | `{ "levels": { "A1": [ProductionItem…] } }` | z `lib/data/exercise-bank.ts` (wiersze rozwinięte do obiektów) |
| `idioms.json` | `{ "levels": { "A1": [PracticeQuestion…] } }` | z `idiom-bank.ts` + `idiom-expansion.ts` (rozwinięte do pytań tak, jak robi to strona) |
| `readings.json` | `{ "readings": [Reading & {topic}] }` | z `readings/*.json` + `advanced-readings.ts` |
| `starter-words.json` | `{ "words": [Entry…] }` w formacie Entry z §1 (id z prefiksem `starter.`) | z `seed()` i `STARTER` w `learning.ts`/`tutor-local.ts` |
| `recommendations.json` | `{ "items": [Recommendation…] }` | „trudniejsze pokrewne słowa” z `tutor-local.ts` |
| `answer-variants.json` | `{ "polishSenseVariants": […], "polishAspectPairs": […], "englishAliases": {…} }` | `lib/answer-variants.ts`, aliasy z `tutor-local.ts` |

Szczegóły, których ta tabela nie rozstrzyga, data-pipeline dopisuje poniżej w sekcji „§5 Ustalenia data-pipeline” (nie zmieniając sensu §1–§3).

## 5. Ustalenia data-pipeline

Generowane przez `node ios/tools/export-web-content.mjs` (nie edytować ręcznie — poprawki treści banków wprowadza się w eksporcie albo w zgłoszeniach `ios/docs/reports/content-issues-web-banks.md`). Każdy plik banku ma nagłówek `"schemaVersion": 1, "source": "web-v42"`. Pola opcjonalne w TS (`?`) mogą **nie występować** w JSON (dekoder Swift: `decodeIfPresent`); wszystkie pozostałe klucze są zawsze obecne, nigdy `null`. Formatowanie: obiekty z wcięciem 2 spacji, każdy element tablicy obiektów w jednej linii (małe pliki, czytelne diffy).

Typy wspólne (nazwy pól jak w `web-source/lib/tutor-types.ts`):

```text
ProductionItem   { bankId: String, scenarioId?: String, context: String, hintPl: String, answer: String,
                   acceptedAnswers: [String], distractors: [Distractor], rule: String, explanation: String, translation: String }
Distractor       { form: String, diagnosis: "wrong_tense"|"wrong_aspect"|"wrong_voice"|"wrong_agreement"|"wrong_word", explanation: String }
PracticeQuestion { format?: "choice"|"input", inputHint?: String, acceptedAnswers?: [String], bankId?: String, scenarioId?: String,
                   category: "grammar"|"idiom", prompt: String, context: String, options: [String] (4), answer: Int (0..3),
                   explanation: String, translation: String }
Reading          { id: String, title: String, level: "A1".."C2", topic: String, paragraphs: [String],
                   questions: [{ question, options: [String] (4), answer: Int, explanation, evidence, meaningId? }], source: "starter",
                   glossary?: [GlossaryEntry] }            ← słowniczek kontekstowy, §5.4 (nie pochodzi ze strony)
GlossaryEntry    { form: String, lemma: String, translation: String, ipa?: String, ref?: String }
```

### 5.1 Gramatyka — `grammar/A1.json` … `grammar/C2.json` (decyzja: podział)

Bank strony ma 1800 zadań; jeden plik `grammar.json` miałby ~1,96 MB nawet bez wcięć (> progu 1,5 MB), więc jest **podzielony na poziomy** (285–402 KB każdy). Aplikacja ładuje tylko potrzebny poziom (leniwie, poza głównym wątkiem). Pliku `grammar.json` **nie ma**.

```json
{
  "schemaVersion": 1, "source": "web-v42", "version": 36, "level": "A1",
  "rules": ["present simple", "present continuous", "…"],
  "items": [
    {"bankId":"grammar-36-A1-00-00","scenarioId":"A1-0","context":"On Saturdays, we usually ________ (pakować) the bags for the trip.","hintPl":"pakować","answer":"pack","acceptedAnswers":[],"distractors":[{"form":"packs","diagnosis":"wrong_word","explanation":"…"}],"rule":"present simple","explanation":"…","translation":"W soboty zwykle pakujemy torby na wyjazd."}
  ]
}
```

- `rules` = `productionRules[level]` ze strony (lista konstrukcji dozwolonych na poziomie; strona używa jej też jako `allowedRules` dla AI).
- `context` zawiera lukę `________` (8 podkreślników) i podpowiedź `(hintPl)`; w trybie wyboru strona usuwa ` (hintPl)` z kontekstu (`starterPractice`).
- Pula zadań „produkcji” poziomu na stronie (`productionPool`) = `exercises.json[level]` **+** `grammar/<level>.json.items` (w tej kolejności).

### 5.2 Ćwiczenia — `exercises.json`

```json
{ "schemaVersion": 1, "source": "web-v42", "version": 1,
  "levels": { "A1": [ProductionItem…], "A2": […], "B1": […], "B2": […], "C1": […], "C2": […] } }
```

Zawiera startery z `lib/production.ts` + wiersze `lib/data/exercise-bank.ts` rozwinięte przez `additionalProduction` (12 na poziom). `bankId` = identyfikator nadawany przez stronę (`grammarTaskId` → `legacy-grammar-<fnv1a(context)>`) — zgodny z `grammarSeen` w stanie zaimportowanym ze strony. Każde zadanie ma **≥ 3 dystraktory**: 11 zadań miało na stronie tylko 2, a trzeci strona dokładała w locie z zaszytej mapy w `starterPractice` — eksport zapisuje go w danych (np. `would travel` → `would travels`).

Zadanie wyboru tworzy się z `ProductionItem` jak `starterPractice` na stronie: `options = [answer] + pierwsze 3 dystraktory` (potem tasowanie), `context` bez ` (hintPl)`, `inputHint` = treść nawiasu, `prompt` = „Wybierz formę pasującą do kontekstu. Konstrukcja: <rule>.”.

### 5.3 Idiomy — `idioms.json`

```json
{ "schemaVersion": 1, "source": "web-v42",
  "levels": { "A1": [ {"bankId":"idiom-v1-A1-00","category":"idiom","prompt":"Co oznacza „You're welcome” w tym kontekście?","context":"Thanks for the tea! — You're welcome.","options":["Nie ma za co","Do zobaczenia","Baw się dobrze","Oczywiście"],"answer":0,"explanation":"…","translation":"Dziękuję za herbatę! — Nie ma za co."} ] } }
```

- Wygenerowane przez `idiomPool(level, 0)` strony (18 na poziom: 6 bazowych + 12 z `idiom-expansion.ts`). **`answer` jest zawsze `0`** (poprawna odpowiedź pierwsza) — aplikacja MUSI tasować `options` przy wyświetlaniu (strona robi to rotacją w `starterPractice`).
- `bankId` (`idiom-v1-<poziom>-<nn>`) dodany przez eksport (strona go nie miała) — do śledzenia „widzianych”.

### 5.4 Czytanki — `readings.json`

```json
{ "schemaVersion": 1, "source": "web-v42",
  "readings": [ {"id":"reading-v39-blue-bag","title":"The blue bag","level":"A1","topic":"lotnisko podróż airport","paragraphs":["…"],"questions":[{"question":"…","options":["…","…","…","…"],"answer":1,"explanation":"…","evidence":"…"}],"source":"starter"} ] }
```

- 30 czytanek banku v39 (`readings/*.json`, 5 na poziom) + 12 dawnych czytanek (`tutor-local.ts` `readings`/`extraReadings` i `advanced-readings.ts`, na stronie już nieużywane) z `id` `reading-legacy-<kebab-tytułu>` i `topic: ""`. Posortowane po poziomie.
- `topic` = słowa kluczowe PL/EN do dopasowania tematu (strona: `selectBankReading`); może być `""`.
- `answer` w zakresie `options`; `evidence` to (zwykle dosłowny) fragment tekstu. Strona przy ponownym przejściu rotuje odpowiedzi o `historyLength % 4`.

#### 5.4.1 Słowniczek kontekstowy — `glossary` (FEEDBACK-2 G1)

Każda czytanka ma pole `glossary` (ostatnie pole obiektu): 8–20 słów przydatnych i trudniejszych dla poziomu tekstu, z tłumaczeniem **w znaczeniu z tego tekstu**. Aplikacja podświetla je w tekście (kropkowane podkreślenie; słowa z mojego słownika — tło i linia ciągła) i po dotknięciu pokazuje arkusz z tłumaczeniem w kontekście, formą bazową, IPA, odsłuchem i „Dodaj do nauki”.

```json
"glossary": [
  {"form":"booked","lemma":"book","translation":"zarezerwować","ipa":"/bʊk/","ref":"restaurant/restaurant.book"},
  {"form":"in a hurry","lemma":"be in a hurry","translation":"spieszyć się","ipa":"/bi ɪn ə ˈhɝːi/"}
]
```

| Pole | Wymagane | Znaczenie |
|---|---|---|
| `form` | tak | forma **dokładnie** jak w akapicie (podciąg z zachowaniem wielkości liter, na granicy słów); może być wyrażeniem („took a photo”) |
| `lemma` | tak | forma bazowa („take a photo”); brak w JSON → dekoder używa `form` |
| `translation` | tak | polskie tłumaczenie w znaczeniu z tego tekstu (np. *minutes* → „protokół”, *chair* → „przewodniczący”) |
| `ipa` | nie | wymowa formy bazowej, General American, w `/…/` |
| `ref` | nie | `r` z `dictionary-index.json` (`<plik tematu>/<id>` lub `starter/<id>`) — tylko gdy wpis bazy ma **to samo znaczenie**; wtedy „Dodaj do nauki” dodaje pełny wpis bazy |

Zasady: brak duplikatów `form` w czytance (bez względu na wielkość liter); dłuższa forma wygrywa przy nakładaniu (podświetlanie jak `ReadingTokenizer`: najdłuższe dopasowanie, nigdy wewnątrz słowa). Pole opcjonalne i wstecznie zgodne — dekoder Swift: brak/`null` → `[]`, uszkodzona pozycja jest pomijana (bez `form` lub `translation`). Zapisane sesje ze starszym `Reading` (bez słowniczka) dostają słowniczek z banku po `id` w chwili wyświetlenia.

**Źródło i scalanie.** `readings.json` jest generowany ze strony, więc słowniczek **nie jest edytowany w `readings.json`**. Źródło prawdy: `ios/tools/data/reading-glossary.json` (`{ "schemaVersion": 1, "readings": { "<id czytanki>": [GlossaryEntry…] } }`). Scalanie:
- `node ios/tools/apply-reading-glossary.mjs` — wpisuje słowniczki do `readings.json` (idempotentne; `--check` = kod 1, gdy `readings.json` jest nieaktualny);
- `export-web-content.mjs` scala słowniczki sam (ponowny eksport ich nie kasuje). Poprawki english-qa zmieniają potem akapity, więc pełna kolejność: eksport → `fixes/english-qa-banks-fix.mjs` (2×) → `fixes/readings-ame-fix.mjs` → `apply-reading-glossary.mjs` → `build-index.mjs` → `validate-content.mjs`.

Walidator (`lib/reading-glossary.mjs`, wołany z `validateReadings`): błędy `glossary-form` (forma nie występuje dosłownie w akapicie), `glossary-duplicate`, `glossary-empty`, `glossary-type`, `ipa-format`, `glossary-ref` (zły format lub brak `ref` w `dictionary-index.json`); ostrzeżenia `glossary-count` (poza 8–20), `glossary-missing`, `glossary-stale` (`readings.json` różni się od pliku źródłowego).

### 5.5 Słowa startowe — `starter-words.json`

`{ "schemaVersion": 1, "source": "web-v42", "words": [Entry…] }` — **Entry dokładnie jak §1**, `id` = `starter.<kebab-term>` (kolejne znaczenia: `-2`, `-3`). Źródło: `seed()` + `starterLookup()` (przykłady z `pairs`, warianty EN z `aliases`, PL z `polishAnswers`). Uzupełnione przez eksport: IPA General American, `frequency`, `forms` w formacie `do – did – done`, listy oddzielone `; `. Pominięte: wyniki/recenzje demo, kolekcje, tagi. Walidowane tak samo jak tematy.

### 5.6 Rekomendacje — `recommendations.json`

```json
{ "schemaVersion": 1, "source": "web-v42",
  "items": [ {"known":"figure out","term":"ascertain","level":"C1","translation":"ustalić, dowiedzieć się","difference":"…","example":"We need to ascertain the cause of the problem.","examplePl":"Musimy ustalić przyczynę problemu.","ipa":"/ˌæsərˈteɪn/"} ] }
```

`Recommendation` z `tutor-types.ts` + dodatkowe pole `ipa` (z `recommendationLookup`). Strona proponuje element, gdy słowo `known` jest opanowane, ma niższy poziom niż `level`, a `term` nie jest jeszcze w słowniku (maks. 3).

### 5.7 Warianty odpowiedzi — `answer-variants.json`

```json
{ "schemaVersion": 1, "source": "web-v42",
  "polishSenseVariants": [ {"term":"borrow","variants":["pożyczyć od kogoś","pożyczać od kogoś","pożyczyć","…"]} ],
  "polishAspectPairs": [ ["kupić","kupować"], ["sprzedać","sprzedawać"] ],
  "englishAliases": { "lend": ["lend someone","lend somebody","…"] } }
```

Semantyka jak `polishAnswers()` w `lib/answer-variants.ts`: grupa `polishSenseVariants` dla danego `term` jest dołączana tylko wtedy, gdy któryś z jej wariantów (po `answerKey`) jest już kotwicą (tłumaczenie lub jego część po `, ; /`) — to rozdziela znaczenia (bank-finanse vs bank-rzeka). Pary aspektowe dołączane, gdy którakolwiek forma jest kotwicą. `englishAliases` = `aliases` z `tutor-local.ts` (akceptowane odpowiedzi EN dla haseł startowych).

### 5.8 Indeksy (§2, §3)

Generuje `node ios/tools/build-index.mjs` (idempotentny; `--check` zwraca 1, gdy indeksy są nieaktualne). Szczegóły: grupy w `topics/index.json` zawsze wszystkie 16, w kolejności z §2, z symbolami SF (`basics` textformat.abc, `travel` airplane, `food` fork.knife, `home` house, `health` heart.text.square, `work` briefcase, `education` graduationcap, `technology` desktopcomputer, `money` cart, `services` building.columns, `people` person.2, `daily` sun.max, `leisure` theatermasks, `nature` leaf, `society` globe, `communication` bubble.left.and.bubble.right). Tematy posortowane: kolejność grup, potem kolejność z `TOPICS-MASTER.md`, potem `namePl`. `levels` zawsze ma wszystkie 6 kluczy. Pliki tematów z błędnym JSON-em lub `id` ≠ nazwa pliku są pomijane (z ostrzeżeniem). `dictionary-index.json`: rekordy posortowane po `k`, potem `r`; `generatedAt` zmienia się tylko przy zmianie treści.

### 5.9 Wydajność

| Plik | Rozmiar | Ładowanie |
|---|---|---|
| `grammar/<poziom>.json` | 285–402 KB | leniwie, tylko bieżący poziom |
| `readings.json` | ~205 KB (ze słowniczkami, 765 pozycji) | leniwie (ekran czytania) |
| `exercises.json`, `idioms.json` | ~68 / ~57 KB | leniwie (ćwiczenia) |
| `starter-words.json`, `recommendations.json`, `answer-variants.json` | < 20 KB | przy starcie (tanie) |
| `topics/index.json`, `dictionary-index.json` | rośnie z tematami | indeks przy starcie w tle; pliki tematów leniwie |
