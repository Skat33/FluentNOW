# Poprawki po pierwszych testach na urządzeniu (runda 1)

Źródło: testy użytkownika na Macu/iPhonie (aplikacja kompiluje się i działa). To są **wymagania produktowe od właściciela aplikacji** — mają pierwszeństwo przed dotychczasowymi decyzjami w raportach.

## F1. Tematy nie są publicznym katalogiem — wyszukiwanie tematu przy dodawaniu (agent: topic-search)

**Jak ma być:**
1. Użytkownik dodaje słówka przez jeden punkt wejścia (przycisk „+” / szybkie dodawanie) z dwiema opcjami: **„Dodaj słowo”** (dotychczasowe szybkie dodawanie pojedynczego hasła) i **„Szukaj tematu”**.
2. W „Szukaj tematu” wpisuje po polsku (lub po angielsku) opis sytuacji, np. „zamawianie w restauracji”, „na lotnisku”, „rozmowa o pracę”, „u dentysty”.
3. Wynik: **wszystkie słowa i zwroty związane z tą sytuacją, posortowane od najistotniejszych do najmniej istotnych** (rdzeń komunikacyjny najpierw: częstotliwość w mowie, potem poziom CEFR). Najpierw najlepiej dopasowana kategoria tematu (np. „Zamawianie” w `restaurant`), potem pozostałe powiązane wpisy. Możliwość zaznaczenia (wszystkie / pojedyncze / filtr poziomu) i dodania do nauki — jak dotychczas w ekranie tematu.
4. Źródło wyników:
   - **najpierw wbudowana baza** (`topics/*.json` — ok. 130 tematów) + **lokalna pamięć wygenerowanych tematów**;
   - **jeśli w bazie nie ma dobrego dopasowania** i AI jest skonfigurowane (Gemini lub Apple on-device) → AI generuje temat dla tego zapytania, w tym samym formacie i standardzie jakości co baza (wzór: `web-source/lib/tutor-prompts.ts` — `TOPIC_PROMPT`, `TOPIC_HYDRATE_PROMPT`, `TOPIC_RESOLVE_PROMPT`; walidacja jak `ios/tools/validate-content.mjs`: focusEn/focusPl jako podciągi, poziomy, brak duplikatów);
   - **wynik AI jest od razu zapisywany do lokalnej pamięci tematów** (Application Support, format `TopicFile` z `CONTENT-SCHEMA.md`, zapytanie użytkownika jako alias), żeby kolejne wyszukiwanie tego samego/podobnego hasła było natychmiastowe i offline. Zapytania, które trafiły w istniejący temat, też zapisują się jako alias (szybsze dopasowanie).
   - **bez AI** i bez dopasowania: pokaż najbliższe propozycje z bazy + jasny komunikat „Włącz AI w Ustawieniach, żeby tworzyć nowe tematy”.
   - Generowanie dwuetapowe jak na stronie (`lib/topic-import.ts`): najpierw szybka lista haseł (pokazana od razu), uzupełnianie szczegółów (IPA, przykłady, tłumaczenia) w partiach po 5 dla zaznaczonych haseł, z postępem i możliwością przerwania; ukończone partie zostają w pamięci.
5. **Usuń publiczny katalog tematów**: segment „Tematy” w Słowniku i przeglądanie listy wszystkich tematów znikają. Wszystkie odwołania (`LibrarySection.topics`, deep link, przycisk „Przeglądaj tematy” na ekranie Dzisiaj, onboarding) przerób na wyszukiwanie tematu. Onboarding może zaproponować kilka przykładowych zapytań jako skróty (np. „przedstawianie się”, „w sklepie”, „w restauracji”) — ale nie listę wszystkich tematów.

## F2. Podpowiedzi zdradzają odpowiedź (agent: learning-fixes)

Podpowiedź po błędnej odpowiedzi „najczęściej pokazuje całe hasło”. Przyczyny w kodzie: `VocabExerciseContent.hintText` dokleja `word.note` (notatki często zawierają hasło), pokazuje 2 litery + długość (dla krótkich słów to prawie całe słowo); podobne ryzyko w `CombinedQuestionModel.hintText` (`inputHint` z banku) i innych ćwiczeniach.

**Jak ma być:** podpowiedź naprowadza, nie zdradza. Stopniowana:
- 1. poziom (pierwsza podpowiedź): wskazówka znaczeniowa bez hasła — np. kontekst/scena, część mowy, liczba słów w zwrocie, angielska definicja z **zamaskowanym** hasłem i jego formami;
- 2. poziom (dopiero przy kolejnej prośbie / drugiej błędnej próbie): tylko pierwsza litera każdego słowa + maska długości (`b _ _ _ _ _`, dla zwrotu `g _ _   t _ _   h _ _ _   o _`), nigdy więcej niż ~1/3 liter.
- Żaden tekst podpowiedzi nigdy nie zawiera odpowiedzi ani jej akceptowanych wariantów/form (porównanie po normalizacji) — **test w FluentKit sprawdzający to dla wszystkich wpisów bazy i wszystkich zadań banków**.
- Logika podpowiedzi w FluentKit (czysta funkcja + testy), UI tylko wyświetla.

## F3. Fiszka: „Pamiętam / Nie pamiętam” ma od razu przejść dalej (agent: learning-fixes)

Teraz po wyborze ekran przewija się w dół, pokazuje wyjaśnienie znaczenia i komunikat „jeszcze nie pamiętasz”. **Ma być:** wybór zapisuje odpowiedź (jak teraz, przez `Scheduler.recordAnswer`) i **natychmiast przechodzi do następnego zadania** (krótka haptyka/animacja przejścia, bez panelu wyjaśnienia, bez przewijania). Odsłonięcie tyłu fiszki (tłumaczenie, przykład) przed wyborem zostaje.

## F4. Czytanki: za mało pytań (agent: learning-fixes)

Przy tekście na kilkanaście zdań jest tylko 1 pytanie ABCD. Przyczyna: `CombinedSessionBuilder` (tryb `reading`) bierze `reading.questions.prefix(remaining)` — w sesji mieszanej budżet trybu bywa 1. **Ma być:** czytanka w każdej sesji ma **co najmniej 3 pytania** (wszystkie pytania tekstu, jeśli ma ich 3–6), pytania jednej czytanki idą **bezpośrednio po sobie** (także przy losowej kolejności), budżet czasu liczy czytankę jako blok. Sprawdź też samodzielne ćwiczenie czytania. Testy w FluentKit.

## F5. Analiza poziomu w tle + polecane słówka (agent: recommendations)

- W tle (po sesji, przy starcie — poza głównym wątkiem) analiza: szacowany poziom CEFR z pewnością, mocne/słabe umiejętności, tempo nauki, obszary tematyczne. Pokazana zwięźle (karta na „Dzisiaj” i pełniej w „Postępach”).
- **„Polecane słówka”**: propozycje słów do dodania, które **naprawdę przydają się w życiu**: z wbudowanej bazy, `frequency` = `very_common`/`common`, poziom ≤ poziom docelowy użytkownika (szacowany +1), rejestr nie-specjalistyczny (chyba że użytkownik uczy się danego tematu), nie te, które już ma; preferuj tematy, z których użytkownik już ma słowa, i tematy codzienne (podstawy, codzienność, komunikacja, jedzenie, podróże, zdrowie, zakupy). Nigdy rzadkie (`rare`/`less_common`) ani niszowe. Dodanie jednym dotknięciem (lub zaznacz kilka → dodaj). Krótkie uzasadnienie przy propozycji („często używane”, „pasuje do Twojego poziomu B1”, „z tematu Restauracja, którego się uczysz”).
- Logika (analiza + ranking) w FluentKit jako czyste funkcje z testami.
