# Runda 10 — decyzje właściciela po propozycjach code-qa-9

Wybrane: propozycja **2** („Twoje typowe błędy”), **4** (wymowa w ćwiczeniach) oraz **rozbudowa słownictwa** (idiomy, dłuższe zwroty typu *on the other hand*, *on top of that*, oraz pojedyncze słowa). Przy okazji: dwie szybkie poprawki wydajności z code-qa-9 §7 (pkt 2 i 3).

## P1. „Twoje typowe błędy” (agent: practice-plus)
- Zapis konkretnych błędnych odpowiedzi (nie tylko licznika): typ zadania, oczekiwane vs podane, rodzaj błędu (forma czasownika, przyimek, przedimek, literówka, inne słowo, kolejność, znaczenie), data. Limit historii (np. 500 ostatnich), synchronizacja jak reszta stanu (CloudKit/payload), eksport/import.
- Klasyfikacja błędów — czysta logika w FluentKit (diff tokenów, `FuzzyMatcher` dla literówek, listy przyimków/przedimków/form nieregularnych z `ScrambleDecoys`).
- Ekran/sekcja „Twoje typowe błędy” (w trybie pomyłek / Postępach): grupy wg rodzaju z krótkim wyjaśnieniem po polsku i przykładem („Mylisz *in / on / at* — 7 razy”), przycisk „Przećwicz” uruchamia sesję z tych słów/zdań.
- Rozsypanka adaptacyjna: preferuje dystraktory tego rodzaju, który uczeń myli (`ScrambleDecoyKind` + statystyka).
- „Przypomnij sobie”: przy literówce komunikat „prawie — literówka” spójny z progami `FuzzyMatcher`.

## P2. Wymowa w ćwiczeniach (agent: practice-plus)
- Po poprawnym „Ułóż zdanie” (i opcjonalnie po innych zadaniach ze zdaniem) etap „Powiedz to zdanie na głos” z oceną (`PronunciationService`, rozpoznawanie mowy en-US): wynik słowo po słowie (zielone/pomarańczowe), „Posłuchaj” (TTS) i „Spróbuj ponownie”, „Pomiń”. Wynik **nie** wpływa na opanowanie słowa (jak na stronie), ale liczy się do XP za wymowę/statystyk.
- Ustawienie: „Ćwicz wymowę w sesjach” (wł./wył., domyślnie wł.), automatyczne pominięcie bez uprawnień do mikrofonu lub w trybie cichym; nie koliduje z mikrofonem wyszukiwania (`VoiceSearchController`) ani TTS.

## P3. Wydajność (agent: practice-plus)
- `MeaningOptions.options` — poza głównym wątkiem albo cache indeksu kluczy per rewizja stanu.
- Rozgrzanie indeksu podpowiedzi przy otwarciu arkusza „+” (szkielet listy zamiast pustki).

## P4. Rozbudowa słownictwa (agenci: vocab-idioms, vocab-phrases, vocab-words; potem vocab-qa)
Nowe shardy core (format jak `core-c01..c09`, wg `docs/agents/03b-core-content.md`, 3–5 przykładów na wpis):
- `core-c10.json`, `core-c11.json` — **idiomy** (przenośne, częste w AmE: *hit the nail on the head*, *the ball is in your court*, *cut corners*…), ok. 350–450 nowych.
- `core-c12.json`, `core-c13.json` — **zwroty i wyrażenia wielowyrazowe niedosłowne lub stałe**: łączniki i markery dyskursu (*on the other hand*, *on top of that*, *in the long run*, *as a matter of fact*), wyrażenia przyimkowe (*on purpose*, *on behalf of*, *in charge of*, *by no means*), stałe kolokacje (*make a decision*, *take a risk*), zwroty konwersacyjne (*I'm afraid…*, *It's up to you*), brakujące czasowniki frazowe; ok. 400–500 nowych.
- `core-c14.json`, `core-c15.json` — **pojedyncze słowa** spoza bazy: częste słowa ogólne B1–C2, słownictwo z list o otwartej licencji (np. NGSL-Spoken, BSL — Business Service List, TSL — TOEIC Service List; CC BY-SA, zweryfikuj licencję), słowa „życiowe”; ok. 500–600 nowych.
Podział: idiom = znaczenie przenośne, nie do wywnioskowania ze słów; zwrot = reszta wyrażeń wielowyrazowych. Każdy agent przed pisaniem sprawdza duplikaty z całą bazą (`dictionary-index.json` + pliki tworzone równolegle).
Na koniec korekta english-qa nowych shardów (vocab-qa).
