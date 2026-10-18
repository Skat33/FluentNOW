# Raport: image-verify — weryfikacja zdjęć w ćwiczeniu „Słowo i zdjęcie”

Data: 2026-10-18. Obszar: `ios/FluentNOW/Services/Images/`, widoki zdjęć w `Features/Study/Picture/` (tylko to, co konieczne), nowe testy w `ios/FluentNOWTests/ImageVerify/`, `ios/docs/FUTURE.md`. `project.yml` nie wymagał zmian: Vision i CoreML to frameworki systemowe, linkowane automatycznie przez `import`. Nie uruchamiałem żadnych poleceń git.

## 0. Diagnoza — skąd brały się złe zdjęcia

Sprawdziłem na żywo (`curl`, 2026-10-18) obecne zapytanie: `q=<hasło>&license=cc0,by,by-sa&category=photograph&extension=jpg,png&mature=false&page_size=12`. Wyniki dla 8 haseł plus zapytania doprecyzowane są w §4. Przyczyny błędnych zdjęć, od najważniejszej:

1. **Jedyną kontrolą było „tytuł lub tag zawiera słowo”, a i tak była tylko sortowaniem.** `parseSearch` dzieliło wyniki na „mocne” i „słabe”, ale zwracało wszystkie (`strong + weak`). Gdy „mocne” zostały odrzucone zgłoszeniami albo były uszkodzone, aplikacja brała wyniki bez żadnego związku z hasłem.
2. **Słowo w tytule Flickra często nie jest tematem zdjęcia.** Przykład z wyszukiwania „phone”: `2021-phone-favourites-089`, tagi `iphone, phone`. Obejrzałem miniaturę: to kominek z płonącym drewnem, czyli zdjęcie zrobione telefonem. Podobnie:
   - „Acadia … (cell phone)”;
   - „can't come to the phone right now” (impreza uliczna);
   - „Phone Booth”;
   - „phone background”.
   W tej samej kategorii mieści się owad przy haśle „telefon”, który widział właściciel: makrofotografie z albumów typu „phone favourites” / „shot on iPhone”.
3. **Wieloznaczność i marki.** Na żywych danych:
   - „mouse” na wszystkich źródłach: Mickey/Minnie Mouse, „Mouse Lemur”, „Mouse Bird” — ani jednej myszy komputerowej;
   - „bat”: Hubble „Bat Shadow”, mgławica „Flying Bat”, biżuteria;
   - „apple” na źródłach stockowych: 10 z 12 to komputery i telefony Apple;
   - „apple” na wszystkich źródłach: „Apple tree”, „Apple River Lighthouse”;
   - „crane”: dźwigi przemieszane z żurawiami i origami;
   - „pen”: „Pen y Pass” (góry), aparat Olympus PEN.
4. **Kategoria `photograph` nie gwarantuje zdjęcia.** Rawpixel zwraca jako „photograph” XIX-wieczne ryciny i ilustracje (np. dla „bat” 7 z 12 wyników).
5. **Filtr „rzeczowników konkretnych” przepuszczał abstrakcje.** Odtworzyłem `PictureExercise.isPicturable` w Node i uruchomiłem go na wszystkich tematach: przepuszcza 2 550 różnych haseł, wśród nich voucher, spreadsheet, birthday, cashier, dose, rain check i ok. 150 zawodów i ról osób. Dla „spreadsheet” Openverse zwraca m.in. pszczoły na ostach.
6. **Brak sprawdzenia obrazu.** Nic nie patrzyło na zawartość pliku.

## 1. Warstwy weryfikacji (co zrobiono)

Zdjęcie trafia do ćwiczenia (`cachedMeaningIDs`, `image(for:)`) tylko wtedy, gdy przypisanie ma **zaakceptowany werdykt bieżącej wersji reguł**: `hasVerifiedChoice`, `WordImageVerifier.rulesVersion = 1`.

### Warstwa 0 — czy słowo w ogóle da się pokazać (`WordImageEligibility.swift`)

Działa jako filtr nad FluentKit `isPicturable`. Plik `PictureExercise` jest w FluentKit Sessions, czyli w obszarze ui-tweaks, więc go nie ruszałem. Elementy filtra:

- **lista haseł** wyłoniona z faktycznego wyniku `isPicturable` na treści. Obejmuje:
  - wydarzenia i święta;
  - czas, pojęcia cyfrowe (app, browser, wi-fi, playlist);
  - dokumenty i karty, które wyglądają tak samo (voucher, invoice, library card);
  - miary, gatunki muzyczne i literackie, sytuacje sportowe;
  - stany medyczne i narządy;
  - kształty;
- **role osób**: ok. 190 haseł plus nagłówki, np. `bus driver`, `flight attendant`. Nagłówki dobrane tak, żeby nie wycinać urządzeń: `record player` i `baby carrier` przechodzą;
- **nagłówki-pojęcia** fraz: `… party`, `… sale`, `… check`, `… call`, `… order`;
- **reguły przyrostków**: `-ing` (gerundium), `-ist`, `-ian`, `-ee`, z wyjątkami (building, ceiling, earring, pudding, coffee…);
- **sensy niemożliwe do pokazania** z tabeli znaczeń, np. „orange” jako kolor, „fan” jako kibic, „cloud” w temacie komputerów.

Wynik: z 2 550 haseł tematów zostaje 1 354. Wykluczone znaczenie dostaje trwałe `noPhotoReason` i nigdy nie jest wyszukiwane.

### Warstwa 1 — lepsze zapytanie i selekcja kandydatów

**Znaczenie** (`WordImageSenses.swift`):

- obejmuje ok. 60 wieloznacznych haseł: mouse, bat, crane, apple, pen, phone, glasses, nail, keyboard, seal, trunk, ring, fan, pepper, orange, chicken, fish, palm, pool…;
- sens wybierany jest w kolejności: plik tematu (`contentRef`) → polska wskazówka w tłumaczeniu (np. „myszk”, „nietoperz”, „dźwig”) → pierwszy wpis;
- każdy sens ma:
  - zapytanie, np. `computer mouse`, `mouse rodent`, `baseball bat`, `construction crane`, `crane bird`, `apple fruit`;
  - klasę tematu (przedmiot, zwierzę, jedzenie…);
  - etykiety Vision;
  - słowa „innego sensu”: marki Apple przy „apple”, `mickey`/`disney` przy „mouse”.

**Kolejne wyszukiwania** (`WordImageQueryPlanner`):

1. zapytanie doprecyzowane na `source=stocksnap,rawpixel,wikimedia`. Sprawdzone na żywo: czyste podpisy typu „Mobile Phone”, „Crane Bird”, „Mouse Computer”, „Notepad Pen”;
2. to samo zapytanie na wszystkich źródłach;
3. synonim lub gołe hasło (np. „telephone”).

Po 3 nieudanych wyszukiwaniach znaczenie jest trwale „bez zdjęcia”. Jeśli synonimu nie ma, kończy się po 2. Puste wyszukiwanie też liczy się jako próba; błąd sieci nie.

**Dopasowanie tytułu i tagów** (`WordImageMetadataMatcher`):

- tytuł:
  - bez nawiasów i bez fraz o aparacie („phone favourites”, „shot on iPhone”, „taken with”, „instagram”…);
  - hasło musi być osobnym słowem, z formą liczby mnogiej / pojedynczej (mice, boxes, cherries) albo w formie złączonej („cellphone”);
  - nie może za nim stać rzeczownik zmieniający znaczenie („apple tree”, „bat shadow”, „phone booth”), chyba że ten rzeczownik należy do zapytania sensu („crane bird”);
  - nie może go poprzedzać postać lub zabawka („mickey”, „lego”, „toy”);
- tagi:
  - z API rozdzielam tagi autora (`accuracy: null`) od tagów maszynowych (Clarifai, `accuracy ≥ 0.9`); nowe pola `WordImageRecord.tags` / `machineTags`;
  - zupa tagów (> 40) nie liczy się wcale;
- odrzucenie: znaki rysunku lub ryciny (etching, illustration, vector, cartoon, origami, toy…) i słowa innego sensu;
- poziomy dopasowania:
  - `strong` = tytuł albo tag maszynowy;
  - `weak` = tylko tag autora;
  - `unmatched` = odrzucone;
- ranking: podpis krótki i stockowy wyżej, zdjęcia osób przy przedmiotach niżej, bez duplikatów;
- **dopasowanie jest wymagane.** Słowo bez odpowiednika w taksonomii Vision wymaga `strong` już przy wyborze kandydatów; pozostałe wymagają co najmniej `weak`, a resztę potwierdza Vision;
- bez zmian zostały: licencje CC0/BY/BY-SA, `mature=false`, `category=photograph`, proporcje ≤ 2,4 i minimalny bok 160 px.

### Warstwa 2 — Vision na urządzeniu (`WordImageClassifier.swift`, `WordImageVerifier.swift`, `WordImageVisionLabels.swift`)

**Klasyfikator:**

- `VNClassifyImageRequest` (iOS 13+; rewizja 2 to domyślna rewizja na iOS 17+) na pobranej miniaturze, czyli na danych JPEG przez `VNImageRequestHandler(data:options:)`;
- działa offline, bez kluczy;
- liczy na prywatnej kolejce `utility` przez `withCheckedContinuation`: ani na głównym wątku, ani na wątku aktora;
- zostawiam etykiety ≥ 5% (do 25 najmocniejszych);
- taksonomię pobieram raz na uruchomienie z `supportedIdentifiers()` (iOS 15+);
- na symulatorze `setComputeDevice(.cpu, for: .main)` (iOS 17+, `MLComputeDevice.allComputeDevices`).

**Mapa etykiet:**

- 624 hasła → identyfikatory Vision, np. phone/telephone/cellphone/smartphone → `phone`, `payphone`; „computer mouse” → `computer_mouse`; „bat” sportowy → `baseball_bat`; „crane” budowlany → `crane_construction`;
- do tego identyfikatory wyprowadzane z hasła (`ice cream` → `ice_cream`, l.mn. → l.poj., rzeczownik główny frazy) — te liczą się tylko, jeśli istnieją w taksonomii urządzenia;
- grupy klas: zwierzęta/owady, ludzie, krajobraz, tekst/rysunek/mapa, ogień, jedzenie;
- **każdy z 676 użytych identyfikatorów sprawdziłem skryptem** względem zrzutu `supportedIdentifiers()` (1 303 identyfikatory). Brakujących: 0, zduplikowanych kluczy: 0.

**Decyzja** (`WordImageVerifier.decide`, czysta funkcja), reguły po kolei:

1. Vision niedostępny (np. plik się nie dekoduje): akceptacja tylko przy `strong` dopasowaniu tytułu (`metadata-no-vision`).
2. Oczekiwana etykieta ≥ 50% → **akceptacja** (`vision-match`).
3. Sprzeczna klasa powyżej progu → **odrzucenie** (`vision-conflict`). Progi zależą od klasy hasła, np. przy przedmiocie:
   - zwierzę/owad ≥ 60%;
   - osoba ≥ 85%;
   - krajobraz ≥ 80%;
   - tekst/rysunek ≥ 70%;
   - ogień ≥ 60%;
   - jedzenie ≥ 80%.

   Własne etykiety hasła nigdy nie są konfliktem: pszczoła to owad.
4. Oczekiwana etykieta ≥ 15% bez konfliktu → akceptacja (`vision-weak-match`).
5. Zwierzę i jedzenie muszą przynajmniej wyglądać jak zwierzę / jedzenie (`vision-wrong-kind`). Dzięki temu „bat” zwierzę (w taksonomii nie ma nietoperza) nigdy nie dostanie meczu baseballa.
6. Szersza etykieta ≥ 35% (np. `mammal`, `bird`) przy `strong` tytule → akceptacja (`vision-related`).
7. Hasło ma etykietę w taksonomii, a Vision jej nie widzi → **odrzucenie** (`vision-missing`).
8. Hasło bez odpowiednika w taksonomii: akceptacja tylko przy `strong` tytule i braku konfliktu (`metadata-only`).

**Przebieg w serwisie** (`WordImageService.ensureVerifiedPhoto`):

- pobranie miniatury → klasyfikacja → werdykt;
- akceptacja: plik zapisany;
- odrzucenie: plik nie jest zapisywany albo zostaje usunięty, zdjęcie trafia do `rejectedIDs`, licznik `verificationRejections` rośnie i brany jest następny kandydat (do 4 na hasło w jednym przebiegu);
- werdykt z etykietami (top 8), kodem i polskim powodem zapisuje się w `WordImageAssignment.verifications`;
- liczenie Vision nie blokuje sesji: sesja czyta wyłącznie gotowe pliki z dysku.

### Migracja istniejącego cache

- **Przypisania sprzed zmiany** (brak werdyktu albo werdykt starszej wersji reguł) są od razu **ukryte**: nie liczą się do `cachedMeaningIDs`, więc nie pojawią się w ćwiczeniu.
- Przy każdym przebiegu w tle `verifyLocalPhotos` sprawdza do 40 plików z dysku. Dzieje się to przed jakimkolwiek wyszukiwaniem, więc **działa też offline**.
- Zdjęcia, które przejdą, wracają. Te, które nie przejdą, są **usuwane z dysku**, a w ich miejsce brany jest następny kandydat albo nowe wyszukiwanie.
- Hasła, które teraz są wykluczone, dostają „bez zdjęcia”, a ich pliki są usuwane.
- Użytkownik nic nie musi robić.
- Przyszłe zmiany progów: wystarczy podbić `rulesVersion`.

### Zgłoszenia „Zdjęcie nie pasuje”

Zgłoszenia działają jak wcześniej. `ImageReport` dostał opcjonalne pola:

- `visionLabels` (np. „phone 82%”);
- `verificationReason`;
- `verificationCode`;
- `verifiedWithVision`;
- `imageTitle`.

Wypełnia je `ImageReport(…, verification:)`. `VocabPictureViews` przekazuje `option.image.verification` — to jedna linia; `WordImage` ma nowe pole `verification`. Stare pliki zgłoszeń dekodują się bez zmian.

### Diagnostyka w Ustawieniach

Zmiana jest w `StudyImageDiagnosticsRow`, czyli wierszu osadzonym w Ustawieniach → Dane; plik w `Features/Settings` jest bez zmian. Wiersz pokazuje nową linię: „Weryfikacja: odrzucone N · bez zdjęcia na stałe M · do sprawdzenia K”. `WordImageDiagnostics` dostał pola `noPhotoCount`, `verificationRejections`, `awaitingCheckCount`. Karta „Słowa i obrazki” (`StudyPicturesSnapshot`) nie liczy już znaczeń „bez zdjęcia” jako oczekujących.

## 2. Pliki

**Nowe** (`Services/Images/`):

| Plik | Zawartość |
|---|---|
| `WordImageTerms.swift` | `WordImageSubject`, `WordImageContext` (+ `init(meaning:)`), `WordImageText` (tokeny, formy l.mn., składanie polskich znaków), `WordImageTermProfile.make(term:context:)` |
| `WordImageSenses.swift` | tabela znaczeń wieloznacznych |
| `WordImageVisionLabels.swift` | mapa haseł na identyfikatory, synonimy, grupy klas |
| `WordImageMetadataMatcher.swift` | warstwa 1: `WordImageMetadataMatcher`, `WordImageCandidateFilter`, `WordImageQueryPlanner` |
| `WordImageVerifier.swift` | warstwa 2: decyzja, progi, reguły konfliktów |
| `WordImageEligibility.swift` | warstwa 0 |
| `WordImageClassifier.swift` | protokół `WordImageClassifying`, `VisionImageClassifier` |

**Zmienione:**

- `OpenverseClient.swift`:
  - parametr `sources`;
  - rozdział tagów na autora i maszynowe;
  - `parseSearch` zachowuje dotychczasowe zachowanie (stary test przechodzi).
- `WordImageModels.swift`:
  - `WordImageRecord.tags/machineTags`;
  - `WordImageAssignment.searchAttempts/verifications/noPhotoReason/context` i metody `verification(for:)`, `isVerified`, `hasVerifiedChoice`, `record(_:)`;
  - `WordImageLabel`, `WordImageVerification`;
  - `WordImageStoreFile.verificationRejections`, wersja 3;
  - `WordImagePrefetchReport.checks/rejected`;
  - nowe pola diagnostyki, `WordImage.verification`, pola `ImageReport`.
- `WordImageService.swift`:
  - warstwy w `prefetch`, migracja, próby, „bez zdjęcia”;
  - `unavailableMeaningIDs()`;
  - wstrzykiwany klasyfikator.
- `WordImagePrefetcher.swift`:
  - `WordImagePrefetchBatch`: kandydaci i konteksty liczone razem w `store.compute`;
  - weryfikacja liczy się jako postęp przebiegu.
- `Features/Study/Picture/VocabPictureViews.swift`: jedna linia, przekazanie werdyktu do zgłoszenia.
- `Features/Study/Picture/StudyImageDiagnosticsRow.swift`: linia weryfikacji.
- `Features/Study/Picture/StudyPicturesCard.swift`: pomija „bez zdjęcia”.
- `docs/FUTURE.md`.

**Testy** (nowe, `FluentNOWTests/ImageVerify/`):

- `WordImageMatchingTests.swift`;
- `WordImageVerifierTests.swift`;
- `WordImageVerificationServiceTests.swift`.

## 3. Publiczne API / kontrakty

```swift
protocol WordImageClassifying: Sendable {
    func labels(for imageData: Data) async -> [WordImageLabel]?
    func taxonomy() async -> Set<String>?
}
WordImageService.init(networkEnabled:storeURL:cacheDirectory:session:searchInterval:classifier: (any WordImageClassifying)? = nil)
WordImageService.prefetch(_ candidates: [PictureCandidate], contexts: [String: WordImageContext] = [:]) async -> WordImagePrefetchReport
WordImageService.unavailableMeaningIDs() -> Set<String>
OpenverseClient.searchURL(query:sources: [String]? = nil), search(query:sources:)
WordImageTermProfile.make(term:context:) / WordImageVerifier.decide(profile:metadata:labels:taxonomy:) -> WordImageDecision
WordImageEligibility.exclusionReason(term:) -> String?
ImageReport.init(…, record:, verification: WordImageVerification? = nil, comment:)
```

Wszystkie nowe parametry mają wartości domyślne, więc istniejące wywołania i testy kompilują się bez zmian.

## 4. Wyniki na żywych danych Openverse (2026-10-18)

Warstwę 1 (port JS 1:1 tabel ze źródeł Swift) uruchomiłem na odpowiedziach API zapisanych tego dnia. Warstwy Vision nie da się uruchomić na Windows. Kolumna „zostaje” to kandydaci po warstwie 1; dopiero oni idą do Vision.

| Hasło (sens) | Zapytanie / źródła | Wyniki → zostaje | Co odpadło / pierwszy kandydat |
|---|---|---|---|
| phone | `phone` / wszystkie (stare) | 12 → 10 | odpada „phone background”, „Phone booth”. „…phone-favourites…” spada na ostatnie miejsce (tylko tag); Vision odrzuca ją jako ogień |
| phone | `phone` / stock (próba 1) | 12 → 11 | 1. „Iphone Phone”, „Phone Hand”, „Mobile Phone” (stocksnap) |
| pen | `pen` / wszystkie | 12 → 7 | odpada „Pen y Pass”, „Llyn … Pen”, „PEN”, „Olympus PEN”; 1. „Notepad Pen” |
| pen | `pen` / stock | 12 → 12 | same „Notepad Pen”, „Pens Pencils” |
| apple | `apple` / stock (stare zapytanie) | 12 → 2 | 10 × Apple Mac/iPhone/iPad odpada; zostaje „Apple Slices” (+ „Apple Textbooks”, który przy jabłku zaakceptuje Vision) |
| apple | `apple fruit` / wszystkie | 12 → 12 | „Apples Fruits”, „Apple Fruit” (stocksnap, rawpixel) |
| apple | `apple` / wszystkie | 12 → 1 | odpada „Apple tree” ×8, „Apple River Lighthouse”, „Apple Fat Mac” |
| chair | `chair` / stock | 12 → 12 | „Table Chairs”, „Chair Dentist”… |
| bridge | `bridge` / stock | 12 → 12 | „Bridge Structure”, „Brooklyn Bridge”… |
| mouse (komputer) | `mouse` / wszystkie (stare) | 12 → **0** | Mickey/Minnie, „Mouse Lemur”, „Mouse Bird”, „Wood mouse” — wszystkie odrzucone |
| mouse (komputer) | `computer mouse` / stock | 12 → 12 | 1. „Mouse Computer” (tytuł); 11 słabych („Macbook Laptop” z tagiem mouse) czeka na `computer_mouse` w Vision |
| mouse (zwierzę) | `mouse rodent` / stock | 6 → 3 | odpadają 3 ryciny; zostaje „Brown mouse walking ground”, „Cute mouse…”, „Sweet mouse” |
| bat (zwierzę) | `bat` / wszystkie | 12 → 5 | odpada Hubble „Bat Shadow” ×2, Halloween, „At the Bat” (baseball) |
| bat (zwierzę) | `bat` / stock | 12 → 7 | odpada 5 rycin; 1. „Closeup bat cage”, „bat roaring white background” |
| bat (zwierzę) | `bat animal` / wszystkie | 12 → **0** | same koty i krajobrazy — dlatego sens „bat” szuka gołego `bat` na źródłach stockowych |
| bat (kij) | `baseball bat` / wszystkie | 12 → 6 | odpada „Baseball bat cactus” ×2 i zupy tagów |
| crane (dźwig) | `construction crane` / stock | 12 → 11 | „Construction Crane” ×4… |
| crane (dźwig) | `crane` / wszystkie | 12 → 8 | odpada „Crested Crane” (ptak), „NCS Sky Crane” (LEGO), „Sandhill Crane” (tag „birds”) |
| crane (ptak) | `crane` / stock | 12 → 3 | 9 dźwigów odpada; zostaje „Crane Bird” ×3 |
| crane (ptak) | `crane bird` / wszystkie | 12 → 12 | „Crane Bird”, „common crane birding…” |

Dodatkowo, dla haseł wykluczonych w warstwie 0:

- „voucher” na źródłach stockowych: 9 rycin bonów z 1920 r. (słusznie wykluczone);
- „spreadsheet”: pszczoły na ostach, koty i okulary.

## 5. Testy

Nowe testy obejmują:

- **`WordImageMatchingTests` (11 testów):**
  - formy l.mn. i nieregularne, składanie polskich znaków;
  - frazy aparatu i nawiasy;
  - złożenia i postacie: Apple tree, Mickey Mouse, Bat Shadow, Phone Booth; „Crane Bird” z `allowedNext`;
  - tagi tylko całymi słowami;
  - profile sensów: mouse, bat, crane, apple, orange według tematu i tłumaczenia;
  - etykiety, synonimy, klasa;
  - ocena żywych przykładów (favourites → `weak`, machine tag → `strong`, Apple Mac → inny sens, rycina → rysunek);
  - ranking z duplikatami;
  - plan zapytań i URL `source=`;
  - rozdział tagów przy parsowaniu;
  - lista wykluczeń w obie strony.
- **`WordImageVerifierTests` (11 testów):**
  - owad i kominek przy „phone” → odrzucenie;
  - rozpoznany telefon i synonim → akceptacja;
  - portret przy słabym dopasowaniu → odrzucenie;
  - `vision-missing`, `metadata-only`, `vision-wrong-kind`, `vision-related`;
  - własna klasa nie jest konfliktem;
  - brak Vision;
  - taksonomia ogranicza oczekiwane etykiety;
  - progi zależne od klasy.
- **`WordImageVerificationServiceTests` (7 testów; atrapa klasyfikatora + `OpenverseStubProtocol`):**
  - odrzucone zdjęcie zastąpione kolejnym (owad nigdy nie trafia na dysk, licznik odrzuceń);
  - stary cache ukryty, sprawdzony i wyczyszczony, a następny kandydat użyty bez wyszukiwania;
  - czyszczenie cache **offline**;
  - wykluczone słowo nigdy nie jest wyszukiwane;
  - 3 próby (ostatnia z `q=telephone`) → trwale „bez zdjęcia”, odrzucone zdjęcie nie jest pobierane ponownie;
  - zgłoszenie niesie etykiety i powód;
  - stary plik przypisań i stare zgłoszenia się dekodują.

Stare testy (`WordImageServiceTests`, `StudyPolishAppTests`) przeanalizowałem pod nowe reguły:

- przy fałszywym JPEG Vision zwraca `nil`, a tytuł „Wooden chair” daje `strong`, więc zdjęcie jest akceptowane (`metadata-no-vision`);
- liczniki i 429 działają bez zmian;
- pola dodałem tylko z wartościami domyślnymi.

Skrypty uruchomione w Node:

- walidacja identyfikatorów Vision (676 użytych, 0 brakujących);
- symulacja `isPicturable` + `WordImageEligibility` (2 550 → 1 354);
- port warstwy 1 na żywych danych (tabela §4).

Testów Swift nie da się uruchomić na Windows.

## 6. Ryzyka kompilacji i działania (do sprawdzenia na Macu)

1. **`WordImageClassifier.swift`:**
   - `request.setComputeDevice(cpu, for: .main)` i `MLComputeDevice.allComputeDevices` (iOS 17, `import CoreML`), za `#if targetEnvironment(simulator)`;
   - `if case .cpu = device` (wzorzec bez wiązania wartości).

   Jeśli kompilator zaprotestuje, blok można usunąć. Bez niego Vision na symulatorze może zwracać błąd i wtedy działa ścieżka „tylko tytuł” (`metadata-no-vision`), nadal bezpieczniejsza niż wcześniej.
2. **Vision na symulatorze vs. urządzeniu.** Właściwą weryfikację obrazu trzeba sprawdzić na iPhonie. Na symulatorze możliwa jest degradacja do warstwy 1.
3. **`WordImageSenses.swift`:** literał ok. 60 krotek z ok. 107 wywołaniami `WordImageSense(...)` z argumentami domyślnymi (typ jawny `[(String, [WordImageSense])]`). Kolejność etykiet argumentów sprawdziłem skryptem: 0 błędów. Gdyby kompilacja była wolna, można podzielić tabelę na kilka `static let`. Duże tabele etykiet i wykluczeń są tekstem parsowanym przy pierwszym użyciu, więc nie obciążają kompilatora.
4. **`WordImageService.ensureVerifiedPhoto`:**
   - `let data: Data` przypisywane w `do`, z `catch WordImageError.notAnImage { continue }` i `catch WordImageError.http(let code) where …`;
   - niedopasowane błędy propagują (funkcja `throws`).

   To wzorzec z poprzedniej wersji, ale tu połączony z definite initialization.
5. **Zmiana nazwy przypadku enuma:** `WordImageMetadataMatch` ma przypadek `.unmatched` (nie `.none`), żeby uniknąć kolizji z `Optional.none`.
6. **Progi pewności** (0,5 / 0,15 / 0,35, konflikty 0,6–0,9) nie są dostrojone na prawdziwych etykietach Vision. Możliwe są nadmiarowe odrzucenia, np. talerz z jedzeniem (`food` ≥ 80% bez etykiety `plate`) albo telefon w dłoni z `people` ≥ 85%. Skutek: mniej zdjęć, nigdy złe zdjęcie. Dostrajanie na eksporcie zgłoszeń opisałem w FUTURE.
7. **Liczba zapytań.** Każda próba to jedno wyszukiwanie z dziennego limitu 150. Maksymalnie 3 na znaczenie, potem trwałe „bez zdjęcia”. Weryfikacja zwiększa liczbę pobrań miniatur (do 4 na hasło w przebiegu); limity dzienne pozostają.
8. **Atrapa sieci w testach:** testy używają współdzielonego `OpenverseStubProtocol` ze `StudyPolishAppTests.swift`, ze statycznym handlerem. Testy XCTest idą sekwencyjnie, więc to działa; przy równoległym uruchamianiu klas trzeba by to wydzielić.

## 7. Odstępstwa od strony

Strona nie miała zdjęć. Względem poprzedniej wersji aplikacji:

- puste wyszukiwanie nie wraca po 14 dniach, tylko przechodzi do następnej próby, a po 3 próbach jest trwałe „bez zdjęcia”;
- niezweryfikowane zdjęcia nie są pokazywane.

## 8. Prośby do innych ról

- **core-engine / ui-tweaks** (FluentKit `Sessions/PictureExercise.swift`, nie dotykałem): przenieść `WordImageEligibility` do `isPicturable`, albo dodać parametr `excluding`. Wtedy `pendingCount` i karta od razu pomijają wykluczone słowa. Dziś robi to aplikacja przez trwałe „bez zdjęcia” (`settledMeaningIDs`, `unavailableMeaningIDs`).
- **data-pipeline / content:** opcjonalne pola `picturable: false` i `imageQuery` we wpisach tematów (zmiana `CONTENT-SCHEMA.md`). Zastąpiłyby heurystyki redakcyjną decyzją.
