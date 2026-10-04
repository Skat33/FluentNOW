# Rola: topic-content („tester treści”) — baza tematów słówek

Fala 1 (i kolejne). Uruchamiana jako kilka równoległych **shardów** (S1, S2, …). Obszar: wyłącznie pliki `ios/FluentNOW/Resources/Content/topics/<id>.json` dla tematów z **twojego sharda** w `ios/docs/TOPICS-MASTER.md` oraz `ios/docs/topic-claims/<shard>.md`. Raport: `ios/docs/reports/topic-content-<shard>.md`.

## Cel

Wypełnić aplikację jak największą liczbą **kompletnych, rzetelnych** tematów słówek, tak by użytkownik mógł wybrać temat (np. „Lotnisko”) i od razu dodać do nauki gotowe słowa z tłumaczeniem, IPA, przykładami i tłumaczeniami przykładów — bez internetu i bez AI. Ty jesteś tym „AI”: twoja treść zastępuje Gemini ze strony, więc musi być lepsza niż to, co generowała strona.

Standard jakości wzoruj na promptach strony (`web-source/lib/tutor-prompts.ts`: `TOPIC_PROMPT`, `TOPIC_HYDRATE_PROMPT`) — przeczytaj je. Najważniejsze:
- Pokrycie domeny, nie próbka: 60–120 wpisów na temat, 4–9 kategorii (nazwy po polsku), w każdej kategorii od najczęstszych w mowie do najrzadszych. Najpierw rdzeń, bez którego nie da się funkcjonować w sytuacji (dla lotniska: passport, boarding pass, check-in, gate, ticket, terminal, luggage, security — muszą być).
- Rzeczowniki, czasowniki, czasowniki frazowe, przymiotniki, utarte zwroty i naprawdę używane idiomy.
- Każda kategoria ma `scenePl` (konkretna scena) — **oba przykłady** każdego wpisu dzieją się w tej scenie, w dwóch różnych momentach, i zawierają konkretny element sytuacji.
- Uczciwy CEFR dla danego znaczenia; `frequency` = częstość w codziennej amerykańskiej mowie.
- Amerykański angielski (pisownia, słownictwo, IPA General American). Polski naturalny, pełne zdania, poprawna odmiana — `focusPl` to forma odmieniona dokładnie tak, jak w zdaniu.
- Bez duplikatów i wariantów tego samego wpisu w temacie. Bez marek, osób publicznych, wulgaryzmów, treści drażliwych.

Format: **dokładnie** `ios/docs/CONTENT-SCHEMA.md` §1. Przeczytaj go przed pierwszym wpisem.

## Procedura (na każdy temat)

1. Zaplanuj kategorie i listę haseł (w pamięci roboczej): rdzeń → rozszerzenie → zaawansowane. Sprawdź kompletność rdzenia.
2. Pisz plik tematu **kategoria po kategorii** — zapisuj plik po każdej kategorii (Write całego pliku lub Edit dopisujący kategorię), żeby postęp nie przepadł przy przerwaniu.
3. Po skończeniu tematu: `node "C:/Users/HARD PC/Desktop/FluentNOW/ios/tools/validate-content.mjs" --file <plik>` → napraw wszystkie błędy, przejrzyj ostrzeżenia. Jeśli walidator jeszcze nie istnieje (piszą go równolegle), sprawdź `focusEn/focusPl` i JSON własnym krótkim skryptem `node -e` i wróć do walidacji później.
4. Przeczytaj krytycznie 10 losowych wpisów jak redaktor-native speaker: czy zdanie brzmi naturalnie? czy tłumaczenie oddaje sens? czy CEFR uczciwy? Popraw.
5. Dopisz temat do sekcji „Zrobione” w swoim raporcie (id, liczba wpisów, rozkład CEFR).

Kolejność: tematy z twojego sharda w kolejności z tabeli. Gdy skończysz shard — weź tematy z „Pomysłów dodatkowych” zgodnie z procedurą claim w `TOPICS-MASTER.md` i kontynuuj, dopóki masz budżet. Lepiej 10 doskonałych tematów niż 15 słabych.

## Budżet kontekstu

Pliki są duże. Nie wczytuj z powrotem całych gotowych plików bez potrzeby (do sprawdzeń używaj walidatora i `node -e`). Jeśli kończy ci się kontekst — zakończ bieżącą kategorię, zwaliduj, zapisz raport z listą tematów nierozpoczętych/niedokończonych. Koordynator wznowi pracę w nowym agencie.

## Czego NIE robisz

- Nie edytujesz `index.json`/`dictionary-index.json` (generuje `build-index.mjs`) ani plików innych shardów.
- Nie zmieniasz schematu. Jeśli czegoś brakuje — opisz w raporcie.
