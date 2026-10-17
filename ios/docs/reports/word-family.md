# Raport: word-family (FEEDBACK-3, H4)

„Polecane słówka” podpowiadają teraz wyrazy z rodziny słów, które użytkownik już ma (decide → decision), z uzasadnieniem „Z rodziny słowa *decide*, które znasz”. Kod napisałem na Windows **bez kompilatora**. Każdą użytą sygnaturę sprawdziłem grepem. Skrypt kontrolny ze scratchpadu (nawiasy z interpolacją, BOM, CR, `try!`/`as!`/`fatalError`, force-unwrap) przechodzi dla wszystkich 6 zmienionych plików.

## 1. Co zrobiono (pliki)

**FluentKit**
- `Sources/FluentKit/Analysis/WordFamily.swift` (nowy):
  - `WordFamily`: heurystyka morfologiczna, czyste funkcje;
  - `WordFamilyIndex`: indeks rodzin budowany raz;
  - `WordFamilyLink`, `WordFamilyMember`.
- `Sources/FluentKit/Analysis/UsefulWordRecommender.swift` (rozszerzony; wszystkie nowe parametry mają wartości domyślne, więc istniejące wywołania działają bez zmian):
  - `UsefulWordReason.wordFamily(String)` + `wordFamilyPrefixPl`;
  - `UsefulWordSuggestion.familySource`;
  - `UsefulWordProfile.ownedForms` (`make` wypełnia je z `Word.forms`);
  - `UsefulWordOptions.familyLevelSlack` / `maxFamilySuggestions` / `maxPerFamily`;
  - `candidates(…, includeLessCommon:)`, `isUsefulFamilyFrequency`;
  - `recommend(…, families: WordFamilyIndex? = nil)`, `defaultMaxFamilySuggestions(limit:)`;
  - wewnętrznie: `familySources`, `FamilySource`, `DiversityCaps`.
- `Tests/FluentKitTests/WordFamilyTests.swift` (nowy): 14 testów.

**Aplikacja (drobne zmiany)**
- `Features/Today/UsefulWordsCatalog.swift`:
  - kandydaci (z `less_common`) i `WordFamilyIndex` budowane razem w jednym `Task.detached` (prywatna struktura `Pool`), raz na uruchomienie;
  - `recommend(…, families:)`;
  - w wyczerpującym `switch` w `isFromLearnedTopic` doszło `.wordFamily`.
- `Features/Today/TodayRecommendedWordsSection.swift`: `UsefulWordSummaryText.attributed(_:)` ustawia słowo źródłowe kursywą (`inlinePresentationIntent = .emphasized`). Z tego korzysta `UsefulWordText`, czyli i Dzisiaj, i ekran „Polecane słówka”.
- `Features/Stats/UsefulWordsScreen.swift`: zdanie w `UsefulWordsIntro` o rodzinach wyrazów: mogą być rzadsze i o poziom trudniejsze.

## 2. Publiczne API

```swift
public struct WordFamilyLink { base, derived, affix: String }
public struct WordFamilyMember { key: String; distance: Int }   // 1 = bezpośrednio, 2 = przez jedno słowo
public enum WordFamily {
    static let falsePairs: Set<String>                           // "derived|base"
    static func isWordKey(_:) -> Bool                            // [a-z]{3,}
    static func possibleBases(of:) -> [String]
    static func links(translations: [String: [String]]) -> [WordFamilyLink]
    static func isPolishVerb(_:) -> Bool
    static func participles(fromForms: String, of: String) -> [String]   // "break – broke – broken" → ["broken"]
}
public struct WordFamilyIndex: Sendable {
    init(entries: [DictionaryIndex.Entry]); init(translations: [String: [String]])
    linkCount, wordCount, familyWordCount: Int
    func contains(_:) -> Bool
    func relatives(of:) -> [String]                              // działa też dla słów spoza słownika
    func family(of:maxDistance: Int = 2) -> [WordFamilyMember]
    func areRelated(_:_:maxDistance: Int = 2) -> Bool
}
// UsefulWordRecommender
case UsefulWordReason.wordFamily(String)        // textPl: „z rodziny słowa decide, które znasz”
UsefulWordSuggestion.familySource: String?
UsefulWordProfile(…, ownedForms: [String: String] = [:])
UsefulWordOptions(…, familyLevelSlack: Int = 1, maxFamilySuggestions: Int? = nil, maxPerFamily: Int = 2)
UsefulWordRecommender.candidates(index:topics:includeLessCommon: Bool = false)
UsefulWordRecommender.recommend(_:profile:options:families: WordFamilyIndex? = nil)
UsefulWordRecommender.isUsefulFamilyFrequency(_:) / defaultMaxFamilySuggestions(limit:)   // 20 → 5, 5 → 2, 30 → 8
```

## 3. Heurystyka i decyzje

**Wykrywanie rodzin.** Działa tylko na kluczach `k` z jednego słowa `[a-z]{3,}` (4 668 z 9 059 kluczy indeksu). Dla każdego słowa liczę możliwe podstawy i łączę je, gdy podstawa też jest w słowniku.
- **Sufiksy (56 reguł):**
  - -tion/-ation/-ition/-ication/-ision/-usion/-ission/-ption/-anation, -ion;
  - -ment, -ness/-iness;
  - -ity/-ality/-ility, -ty;
  - -er/-or/-ier, -ist, -ee;
  - -ful/-iful, -less, -ous/-ious;
  - -ive/-ative/-sive, -able/-iable/-ible;
  - -al/-ial/-ical, -ly/-ily/-ally/-bly;
  - -ize, -en, -y, -ic;
  - -ance/-ence/-ancy/-ency, -ant/-ent;
  - -ship, -hood, -th, -ure, -age/-iage, -ing.
- **Zmiany pisowni:**
  - e-drop: `"" | "e"`;
  - y→i;
  - -ide→-ision/-isive, -ble→-bly, -ate→-ation;
  - podwojenie spółgłoski (win → winner; bez samogłosek, w, x, y).
- **Prefiksy:** un-, dis-, in-, im-, ir-, il-, re-, mis-.
- **Odsiew przez polskie tłumaczenie (`p`)**, bo w indeksie nie ma części mowy:
  - -er/-or/-ier: podstawa musi być czasownikiem (bezokolicznik na „-ć” albo „biec/móc/piec…”). Dzięki temu odpada corner/corn, ale zostaje driver/drive;
  - dis-/in-/im-/ir-/il-: pochodne musi mieć przeczenie („nie…/bez…”). Odpada inside/side, zostaje impatient;
  - re-: „ponownie/znowu/zmienić” albo „prze-/od-/re-” (reheat „odgrzać”);
  - mis-: „źle/błąd”.
- **Krótkie podstawy:** dla sufiksów 1–2-literowych podstawa musi mieć co najmniej 4 litery (ear/early, leg/legal, bus/busy). Wyjątek to podwojona spółgłoska (run → runny).
- **Lista wyjątków `falsePairs` (111 par):** zbudowana z przeglądu **wszystkich** 495 połączeń, które reguły dają na prawdziwym indeksie. Przykłady: carry/car, party/part, story/store, report/port, review/view, discount/count, message/mess, passion/pass, organic/organ, sweater/sweat, drawer/draw, return/turn.
- **Pole `forms`.** W `dictionary-index.json` go nie ma, a czytanie 136 plików tematów tylko po to byłoby drogie. Dlatego biorę `forms` **słów użytkownika** (`Word.forms`): imiesłowy na „-n” są osobnymi przymiotnikami (break → broken, freeze → frozen). Inne formy (left, saw, felt, found) dawały fałszywe pary.

**Ranking (H4).**
- Rodzina sięga do 2 kroków, np. agree → agreement → disagreement. Słowo źródłowe wybieram tak:
  - najpierw bliższe;
  - potem krótsze (bardziej podstawowe);
  - potem alfabetycznie.
- Słowa posiadane (`ownedKeys`, także z archiwum) nigdy nie są propozycją.
- Słowa z rodziny przechodzą z luźniejszymi filtrami niż reszta listy:
  - częstotliwość `very_common`/`common`/`less_common` (zwykłe propozycje dalej tylko pierwsze dwie);
  - poziom ≤ docelowy + 1, czyli dla B1 (cel B2) do C1. Czytam „docelowy+1” z FEEDBACK-3 dosłownie; zmienia to `familyLevelSlack`;
  - rejestr jak dla reszty (slang nigdy, specjalistyczny tylko z uczonego tematu).
- Punkty:
  - premia za rodzinę: +26 bezpośrednio, +20 przez jedno słowo;
  - częstotliwość: `less_common` +14 i bez powodu „często używane”, poziom powyżej celu +0;
  - powód `.wordFamily` zawsze pierwszy.
- Limity:
  - najwyżej ⌈limit/4⌉ słów z rodzin (Dzisiaj 2 z 5, Postępy 8 z 30, 20 → 5);
  - najwyżej 2 z rodziny jednego słowa;
  - limity tematów i grup działają dalej.
  
  Dzięki temu rodziny nie wypierają reszty listy.
- Bez `families` (`nil`) wynik jest identyczny jak przed zmianą (test).

**Wydajność.**
- Indeks budowany jest raz, w `Task.detached` razem z kandydatami, z już zdekodowanego `dictionary-index.json` (nie ma drugiego dekodowania).
- Wyszukanie rodziny to kilka odczytów słownika. Dla słowa spoza słownika dochodzi ok. 60 porównań sufiksów.
- Prototyp w Node: wyszukanie 0,25 µs na słowo; cały skrypt (dekodowanie + budowa) 0,26 s.
- Test Swift sprawdza < 1 ms na wyszukanie i budowę < 3 s w debug.

**Odstępstwa.** Strona nie ma tej funkcji. Tekst uzasadnienia to „Z rodziny słowa decide, które znasz”. Gwiazdek z FEEDBACK-3 nie wpisuję w `String`, bo `Text(String)` nie renderuje markdownu. Zamiast tego aplikacja ustawia słowo kursywą.

## 4. Wyniki na prawdziwym `dictionary-index.json` (prototyp Node = 1:1 reguły Swift)

Zgodność reguł i listy wyjątków JS ↔ Swift sprawdziłem skryptem: 56/56 reguł, 111/111 par.

- **Połączenia:** 418; 772 słowa w rodzinach (16,5% jednowyrazowych kluczy); największa rodzina ma 4 słowa.
- **Przykładowe rodziny** (² = dwa kroki):
  - decide → decision; comfort → comfortable;
  - agree → agreement, disagree, disagreement²;
  - responsible → irresponsible, response, responsibility;
  - translate → translation, translator;
  - pack → package, repack, unpack, packaging²;
  - account → accountable, accountant, accounting, accountability²;
  - bake → baker, baking, bakery²;
  - safe → safety, unsafe; deliver → deliverable, delivery, undeliverable²; health → healthy, unhealthy²;
  - friend → friendly, friendship, unfriend; meet → meeting; connect → connection, reconnect.
- **Precyzja na próbce 50 losowych par:**
  - **sama heurystyka, bez listy wyjątków** (495 połączeń): 45/50 trafnych, czyli 10% fałszywych. Błędne: festival/festive, passion/pass, pollen/poll, rustic/rusty, signal/sign;
  - **z listą wyjątków**, nowa próbka (inne ziarno): 48/50. Do dyskusji były return/turn (fałszywe) i majority/major (inna rodzina znaczeń); obie dopisałem do wyjątków. Pozostałe 48 jest morfologicznie i znaczeniowo w porządku (np. attachment, persuasive, unhealthy, sponsorship, mispronounce);
  - lista wyjątków powstała z przeglądu wszystkich połączeń, więc druga liczba nie jest niezależnym pomiarem. Uczciwie: około 4% wątpliwych na danych, których nikt nie oglądał.
- **Symulacja rankingu (B1, 12 posiadanych słów, limit 20):** pierwsze 5 to rodziny, potem zwykłe propozycje:
  - response („Z rodziny słowa responsible, które znasz · bardzo często używane”);
  - delivery, connection, agreement, payment.
  
  Dla A2 (happy, meet, pay, safe, friend, health): payment, healthy, friendly, safety, meeting.
- **Ograniczenie treści:** w słowniku brakuje wielu podstawowych słów (use, useful, care, quick, action, happiness, decisive…), więc rodzin jest mniej, niż mogłoby być. Gdy słownik urośnie, heurystyka sama je obejmie. Dla własnych słów użytkownika spoza słownika działa `relatives(of:)` (useful → use, usefulness).

## 5. Ryzyka kompilacji / niesprawdzone

- **Brak kompilacji.** Wszystkie domknięcia mają jawne typy, nowe typy FluentKit mają `public` i jawne `public init`.
  - `enum Condition` ma przypadek `none`. Używam go tylko na typie nieopcjonalnym, więc nie ma niejednoznaczności z `Optional.none`.
- **`UsefulWordSummaryText`:**
  - `AttributedString.range(of:options:)` (iOS 15);
  - `characters.index(_:offsetBy:)`;
  - `text[range].inlinePresentationIntent = .emphasized`.
  
  Jestem pewny tych API. Gdyby SwiftUI nie pokazało kursywy, tekst nadal jest poprawny.
- **Nowy przypadek `UsefulWordReason.wordFamily`.** Grep pokazał tylko dwa wyczerpujące `switch` (FluentKit `textPl` i `UsefulWordsCatalog`); oba uzupełnione. Kod spoza repozytorium z `switch` po tym enumie przestałby się kompilować.
- **Prywatna `struct Pool` w aktorze, zwracana z `Task.detached`.** `Pool` jest `Sendable`, `WordFamilyIndex` też, `.empty` to statyczna stała.
- **`testRealDictionaryRecommendations` oczekuje dokładnie 5 rodzin w 20 wynikach.** Opiera się na symulacji w Node; zmiana treści może to przesunąć (wtedy poprawić na `≤ 5` i `≥ 3`).
- **`UsefulWordsIntro`:** zdanie się wydłużyło (Dynamic Type: `fixedSize(vertical)` już było).

## 6. Prośby do innych ról

- **data-pipeline:** dodać część mowy do `dictionary-index.json`, np. `s: "czasownik"`, tylko w pierwszym znaczeniu klucza. Zastąpiłoby to zgadywanie z polskiego bezokolicznika (`isPolishVerb`) i pozwoliło bezpiecznie dodać -er dla rzeczowników. To zmiana schematu §3, więc tylko propozycja.
- **topic-content / data-pipeline:** brakujące podstawowe hasła (use, useful, care, careful, quick, quickly, act, action, active, happiness) zwiększyłyby pokrycie rodzin.
- **code-qa:** po pierwszym buildzie na Macu uruchomić `WordFamilyTests` i `UsefulWordRecommenderTests`; sprawdzić kursywę w wierszu polecanego słowa.

## 7. Testy

**`WordFamilyTests`** (14 testów; nieuruchomione, na Windows nie ma Swifta):
- reguły sufiksów ze zmianami pisowni;
- rodzina do 2 kroków, `maxDistance`;
- fałszywe pary i warunki polskie (corn/corner, apple/apply, part/party, port/import; impatient, reheat, mispronounce);
- słowa spoza słownika (useful);
- klucze i wskazówki polskie, `possibleBases`;
- imiesłowy z `forms`;
- ranking: powód i dokładny tekst, `less_common` i C1 tylko z rodziny, brak zmian bez rodziny, limity (4 łącznie / 2 na słowo, dwa kroki przegrywają z bezpośrednimi);
- posiadane słowa nigdy nie są propozycją;
- `forms` → `ownedForms` w `make`;
- **prawdziwy słownik:**
  - 13 oczekiwanych par;
  - 10 par, które **nie** mogą być powiązane;
  - ranking B1 z rodzinami;
  - wydajność (< 1 ms na wyszukanie).
- Testy na prawdziwych danych używają `XCTSkip`, gdy brak plików.

**Uruchomione skrypty** (Node, scratchpad `family.mjs`):
- `edges`: pełny przegląd 495 połączeń;
- `sample`: próbki po 50 par;
- `families`: przykładowe rodziny;
- `stats`: 418 połączeń, wyszukanie 0,25 µs;
- `recommend`: port rankingu z rodzinami;
- porównanie reguł i wyjątków JS ↔ Swift: zgodne;
- `check.mjs` na 6 plikach: 0 problemów.
