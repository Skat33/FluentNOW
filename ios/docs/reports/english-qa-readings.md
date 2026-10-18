# Raport: english-qa, zakres słowniczków czytanek

Zakres: słowniczki kontekstowe 42 czytanek (CONTENT-SCHEMA §5.4.1), źródło `ios/tools/data/reading-glossary.json`. Teksty czytanek, pytania, `topics/` i kod — bez zmian.

## Wynik
- Przejrzane ręcznie wszystkie **765 pozycji** (A1 → C2), każda obok swojego akapitu, z podglądem wpisu bazy dla `ref` i kandydatów z `topics/*.json` / `starter-words.json` dla pozycji bez `ref`.
- Po zmianach: 765 pozycji (4 usunięte, 4 dodane), 11–20 na tekst; `ref` 283 (było 294).
- `node ios/tools/apply-reading-glossary.mjs` → zapisano `readings.json`; `--check` → **OK: readings.json zgodny ze źródłem słowniczków**.
- `node ios/tools/validate-content.mjs` → **OK: plików 156, wpisów 10711, błędów 0, ostrzeżeń 0**.
- Zmienione pozycje: **79** w 36 czytankach (10,3%). Bez IPA ze skryptu: **36 pozycji (4,7%)** z poprawką merytoryczną.

Ogólna ocena: słowniczki są dobre. Tłumaczenia kontekstowe były trafne (*minutes* → „protokół”, *qualification* / *reservation* → „zastrzeżenie”, *argue* → „przekonywać”, *apparent* → „pozorny”, *owner* → „osoba odpowiedzialna”). Najwięcej problemów było w `ref`: wpisy bazy o węższym albo innym znaczeniu.

## Poprawki wg kategorii

| kategoria | pozycji |
|---|---|
| IPA — ujednolicenie skryptem (ɝ → ɜːr, ɛ → e) | 43 |
| IPA — ręcznie (æ przed r wg Oxford US, wymowa czasownika, samogłoska nieakcentowana) | 4 |
| `ref` usunięty: wpis bazy ma inne znaczenie | 13 |
| `ref` zamieniony na wpis o właściwym znaczeniu | 2 |
| `ref` dodany | 1 (+1 w nowej pozycji) |
| tłumaczenie w kontekście (osobno lub razem z `ref`) | 17 |
| dobór słów (usunięte banalne/przejrzyste ↔ dodane ważne) | 4 + 4 |

Lematy: zgodne. Każdy lemat z `ref` jest równy hasłu bazy, co ma znaczenie, bo tokenizer łączy słowo z moim słownikiem właśnie po lemacie. Pisownia lematów jest amerykańska.

## Najważniejsze poprawki

**`ref` o innym znaczeniu (usunięte lub zamienione)**
| czytanka | forma | było (`ref`) | powód |
|---|---|---|---|
| quiet-experiment | results | doctor-visit.result (wynik badania lekarskiego) | wyniki eksperymentu w biurze |
| quiet-experiment | measure | hobbies-crafts.measure (zmierzyć długość) | „measure the results” = ocenić |
| perfect-minutes | objections | marketing-sales.objection (obiekcja klienta przy sprzedaży) | sprzeciw na posiedzeniu komisji |
| repair-club | owners | pets.owner (właściciel zwierzęcia) | właściciele przedmiotów |
| menu-labels | equipment | fitness-gym.equipment (sprzęt do ćwiczeń) | sprzęt kuchenny |
| bike-repair | journey | train-travel.journey (długa podróż) | krótki przejazd mechaniczki → „przejazd, droga” |
| change-of-plans | email | business-email.email (wiadomość) | „in his email” = skrzynka mailowa |
| useful-interview-lesson | response | artificial-intelligence.response (odpowiedź AI) | „calm response” = reakcja |
| unwritten-contract | owed | personal-finance.owe (dług pieniężny) | dług moralny („owed it a continued concession”) |
| unwritten-contract | subsidy | economy.subsidy (dotacja rządowa) | nieformalna dopłata piekarni |
| night-trains | fraction | math.fraction (ułamek matematyczny) | „a fraction of costs” = niewielka część |
| borrowed-voice / guidebook | verdict / durable | sens prawniczy / fizyczna trwałość | użycie przenośne |
| table-six | ready | cooking.ready → **pharmacy.ready** | „stolik był gotowy” = przygotowany, nie ugotowany |
| useful-interview-lesson | practiced | music.practice → **school.practice** | ćwiczenie odpowiedzi, nie gra na instrumencie |
| bike-repair | picked it up | + **customer-service.pick-up** | odebrać rzecz z naprawy |

**Tłumaczenia**
- *trial* (silent-terminal, quiet-experiment): „okres próbny” (po polsku zwykle o pracowniku) → „próba, test (pilotaż)” / „okres testowy, próba”.
- *accommodating* (exception): „ustępliwy, uległy” (zabarwienie negatywne) → „uczynny, elastyczny (chętnie przyjmujący zadania)”.
- *reversal* (waiting-list): „odwrócenie” → „zwrot w drugą stronę, wycofanie się”.
- *gate*: „wyjście (bramka) na lotnisku” → „wyjście (do samolotu)”; *remember* („so he will remember it”): „zapamiętać” → „pamiętać (nie zapomnieć)”; *have coffee* → „iść na kawę, wypić kawę”; *lack of effort* → „brak starań, zbyt małe zaangażowanie”; *replacement* → „zamiennik, część zamienna”; *cancellations* → „odwołana wizyta (zwolniony termin)”.

**Dobór słów (C1–C2)**
- unwritten-contract: − *flour* (A2) + *diminished* → „osłabić, umniejszyć”.
- perfect-minutes: − *falsified* (przejrzysty internacjonalizm) + *outstanding* („the outstanding questions”) → „otwarty, nierozstrzygnięty (o kwestii)”. Fałszywy przyjaciel: Polak czyta to jako „wybitny”.
- recommendation: − *research position* (przejrzyste) + *sweeping* („less sweeping than her original draft”) → „ogólnikowy, zbyt daleko idący (o ocenie)”.
- borrowed-voice: − *mutual help* + *siblings* → „brat lub siostra (tu: rodzeństwo)”, `ref` family.sibling.

**IPA**
- Skrypt (43 pozycje): *finish work, first day, turn on/off, hurry, worry, certain, earn, research, confirm, encourage, verdict, circumstances, infer, interpret, merchant, commercial…* (ɝ → ɜːr) oraz *library, shelf, collect, forget, investigate, attendance, share, measure, exhibition* (ɛ → e).
- Ręcznie: *baggage carousel* /ˈbæɡɪdʒ ˌkerəˌsel/ → /ˈbæɡɪdʒ ˌkærəsel/ (jeden akcent poboczny), *barrier* → /ˈbæriər/, *apparent* → /əˈpærənt/ (Oxford US pisze æ przed r, tak jak baza: *carry* /ˈkæri/), *document* (czasownik) → /ˈdɑːkjument/, *omission* → /əˈmɪʃən/.
- Sprawdzone bez zmian: wszystkie 283 IPA przy `ref` są identyczne z bazą. Rzeczowniki i czasowniki rozróżnione poprawnie: *extract* (n.) /ˈekstrækt/, *close* (v.) /kloʊz/, *estimate* (n.) /ˈestɪmət/, *attribute* (v.) /əˈtrɪbjuːt/. Monosylaby bez znaku akcentu, tak jak w bazie.

## Wątpliwości (nierozstrzygnięte)
- **`ref` z definicją węższą niż użycie w tekście** zostawione, bo sens leksykalny jest ten sam. Dotyczy: *endorse* → politics.endorse („poprzeć kandydata”; w tekstach poparcie planu albo rozwiązania), *debate* → politics.debate (debata z kandydatami), *rule* → football.rule (zasada w grze; w tekście zasada domowa), *regret* → drinks-bar.regret, *restore* → utilities-bills.restore, *cancellation* → airport.cancellation, *tours* → sightseeing.tour, *anxiety* → mental-health.anxiety. Jeśli właściciel woli ściślej, to kandydaci do usunięcia `ref`.
- **Baza (poza zakresem):** *clarify* /ˈklerəˌfaɪ/ (Oxford US /ˈklærəfaɪ/) i niejednolite -ʃn / -ʃən (*cancellation*, *connection* /kəˈnekʃn/). Glossary celowo kopiuje IPA z bazy, więc warto poprawić je w `topics/` — prośba do english-qa tematów.
- **Teksty (poza zakresem):** brytyjskie *at short notice* (night-trains; w AmE częściej *on short notice*), *did not waste her journey* (bike-repair) i *free entry* (museum-after-dark; w AmE częściej *free admission*). To prośba do english-qa-banks.
- *an end in itself* /ən ˈend ɪn ɪtˌself/: akcent główny zostawiony na *end*. Możliwa jest też wersja z akcentem na *-self*.
