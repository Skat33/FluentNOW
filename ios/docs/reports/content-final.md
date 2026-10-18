# Raport: content-final — końcowe ujednolicenie bazy słówek

Zapisany przez koordynatora na podstawie odpowiedzi agenta (zapis `.md` był dla agenta zablokowany). Zakres: 142 tematy + `starter-words.json` (10 711 wpisów) oraz walidator.

**Wynik:** `validate-content.mjs` — 156 plików, 10 711 wpisów, **0 błędów, 0 ostrzeżeń** (także 5 nowych reguł); `--self-test` OK; `build-index.mjs` 142 tematy / 10 711 rekordów; `apply-reading-glossary.mjs --check` OK. Format JSON zachowany (test round-trip 143/143 plików bajt w bajt; liczba zmienionych linii = liczba zmian w każdym kroku).

## 1. CEFR — 223 zmiany
- **Kalibracja C1 → B2 (9):** habitat, perspective (sztuka), skim, gripping, vivid, conservation, it's crucial, strongly advise, assess. Większość innych zgłoszeń (bicker, squabble, memoir, quaint, read the room, low-hanging fruit…) zostaje C1 — słownictwo specjalistyczne, literackie lub idiomy nieprzejrzyste.
- **Spójność (214):** to samo hasło w tym samym znaczeniu ma w całej bazie jeden poziom — najczęstszy wśród ocen autorów, przy remisie niższy (wyjątek: acquaintance B2 wg EVP). Różne znaczenia (bug, library, rusty, channel) celowo mają różne poziomy. 209 obniżeń, 14 podwyższeń.
- Rozkład bazy po zmianach: A1 799, A2 2149, B1 3450, B2 3100, C1 1208, C2 5.

## 2. Jednolity format `forms` — 2068 pól (+2 `notePl`), 35 przypadków ręcznie
Konwencja opisana w `CONTENT-SCHEMA.md` §1 („Konwencja `forms`”):
- czasownik / phrasal verb / zwrot czasownikowy: **forma hasła – przeszła – imiesłów** (`go – went – gone`, `get the ball rolling – got the ball rolling – gotten the ball rolling`), nigdy od 3. os. lp.; grupa `; -ing` tylko przy pułapkach pisowni (`stop – stopped – stopped; stopping`);
- rzeczownik: liczba mnoga (`radii/radiuses`, `X (lp.)`, `(niepoliczalny)`, `(liczba mnoga)`);
- przymiotnik/przysłówek: `cozier – coziest`, `more polite – most polite`;
- separatory: ` – ` formy, `; ` grupy, `/` warianty; formy AmE (canceled, gotten, dove/dived).
- Zgodne z `HintBuilder.formVariants` (dzieli na `; / – ,`, usuwa nawiasy).

## 3. IPA — 546 wpisów (+5 w `notePl`)
Konwencja (CONTENT-SCHEMA §1 „Konwencja IPA”), doprecyzowana: sylaby zredukowane z jawnym /ə/ (`-ʃən, -bəl, -tən…`), bez akcentu pobocznego po głównym w obrębie wyrazu, nieakcentowane *your* → /jər/, /æ/ przed r w wyrazach typu *carry* (clarify, character, carousel, marriage, paramedic…). 54 hasła z różnym IPA w różnych tematach ujednolicone; 21 zwrotów dopasowanych do IPA słów składowych; office → /ˈɔːfɪs/. Różnice zależne od części mowy (record, invite, estimate…) zostawione. Słowniczki czytanek: te same reguły w `tools/data/reading-glossary.json` (18 linii, tylko `ipa`) + przegenerowane `readings.json`.

## 4. Identyczne tłumaczenia w jednym temacie — 33 doprecyzowania
Ze 114 par większość to prawdziwe synonimy (zostawione; kod nie podsuwa ich jako dystraktorów). Doprecyzowane m.in.: load → „porcja prania”, roast → „piec (mięso, warzywa)”, pull → „wyrwać”, ache → „ćmiący ból”, seed → „nasiono”, bye → „pa”, recognize → „rozpoznać”, celebrate → „świętować”, back down → „ustąpić”, sharp → „równo”, guidebook → „przewodnik (książka)”, degree → „dyplom ukończenia studiów”, get laid off → „stracić pracę przez redukcję etatów”, baby → „niemowlę”, keep someone in the loop → „włączać kogoś w obieg informacji”. Stare tłumaczenie zawsze zostało w `acceptedTranslations`.

## 5. Walidator — 5 nowych ostrzeżeń (+21 asercji, nowe fixture'y)
| reguła | co zgłasza |
|---|---|
| `comma-splice` | nowe zdanie główne po przecinku w EN (z wyjątkami: wstępy, zdania podrzędne, krótkie człony, kontrast po przeczeniu, cudzysłów) |
| `forms-base` | `forms` czasownika bez trzech form lub nie od formy hasła |
| `pl-english` | „Sorry/OK/okay” w polskim zdaniu |
| `pl-imperial-units` | liczba + mila/stopa/cal/funt/jard/uncja/galon/mph/°F w polskim zdaniu (wyjątek: hasła o samej jednostce/pomiarze) |
| `accepted-format` | pozycja AA/AT ze średnikiem |

Poprawki w treści: 162 comma splice (148 średnik, 14 podział wykrzyknikiem), 2 polskie zdania z „Sorry/OK”, 31 zdań z jednostkami imperialnymi przeliczonych naturalnie (mile → km, funty → kg/deko, °F → °C).

## 6. Ryzyka
- CEFR i wybór transkrypcji to ocena redakcyjna (bez dostępu do EVP/Oxford online).
- Heurystyka comma splice świadomie pomija przypadki z rzeczownikiem po przecinku (mniej fałszywych alarmów).

## 7. Prośba (otwarta)
`export-web-content.mjs` generuje `starter-words.json` od nowa — ponowny eksport skasowałby poprawki: starter.recommend i starter.take-your-time → A2; trzy formy dla starter.accomplish / recommend / figure-out; IPA starter.take-your-time `/ˌteɪk jər ˈtaɪm/` (prawdopodobnie także wcześniejsze poprawki english-qa w starter-words). Trzeba je przenieść do nadpisań eksportu.
