# v41 — warianty odpowiedzi i pliki audio

`Meaning.acceptedTranslations?: string[]` to opcjonalna lista polskich odpowiedników znaczenia, niezależna od angielskiego `acceptedAnswers`. Starsze eksporty nadal przechodzą walidację; nie uruchamiamy migracji AI wszystkich słów. Lokalne, opracowane warianty i pary aspektowe działają od razu także dla starych znaczeń. Nowe lookup/hydratacje zapisują obie listy. Własne warianty można edytować w istniejącym formularzu znaczenia.

Migracja usuwa wyłącznie dopiski `(AmE)` i `(BrE)` w polu tłumaczenia. Zachowuje nawiasy rozróżniające znaczenia, identyfikatory, historię i wyniki wcześniejszych odpowiedzi. Test wczytuje rzeczywisty eksport `state-v31.json`, porównuje dane, zapisuje nowe warianty i ponownie odczytuje eksport. Nie są potrzebne zmiany tabel D1: znaczenia są częścią istniejącego agregatu JSON.

R2 binding `AUDIO` przechowuje binarne MP3/WAV pod `speech/v3/<hash>`. Hash zawiera tekst, stan luki, tryb, model/akcent i wersję wymowy. Nie ma publicznej listy ani bezpośredniej trasy obiektów. Odczyt przechodzi przez dotychczasowy endpoint mowy. Gotowe pliki są współdzielone dla identycznego klucza, nie zużywają limitu generowania. Przy braku pliku pozostają zwykłe reguły limitów i generowania.

Kolejność: pamięć przeglądarki/IndexedDB (50 MiB z LRU), cache serwera, plik R2, dostawca mowy. Nowo wygenerowane nagrania zapisują się w R2 w tle. Nagrania istniejące wyłącznie w starej pamięci przeglądarki nie są automatycznie wysyłane na serwer. Awaria zapisu pliku jest logowana i nie blokuje odsłuchu; może wtedy być potrzebna ponowna generacja. Wersja klucza pozwala odświeżyć nagrania po zmianie głosu lub zasad czytania.

Testy sprawdzają identyczne bajty po ponownym uruchomieniu workerd z R2 i brak wywołania Azure oraz obciążenia limitu przy trafieniu w plik. Nie gwarantujemy pojedynczej generacji dla równoczesnych pierwszych żądań na różnych serwerach; gotowe pliki ograniczają kolejne wywołania.
