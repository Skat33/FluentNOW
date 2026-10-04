# Lista tematów słówek (master)

Kolumny: `id` (nazwa pliku `topics/<id>.json`), grupa, nazwa PL, zakres (żeby tematy się nie dublowały), shard.
Shardy S1–S6 = fala 1 (priorytet), S7–S12 = fala 2. Agent treści bierze **tylko swój shard**. Jeśli skończy wcześniej, może wziąć tematy z sekcji „Pomysły dodatkowe”: najpierw sprawdza pliki `ios/docs/topic-claims/*.md` (czy nikt go nie zajął), potem dopisuje id do własnego `ios/docs/topic-claims/<shard>.md`, i dopiero wtedy tworzy temat.

Słowo może wystąpić w kilku tematach tylko wtedy, gdy przykłady są osadzone w scenie danego tematu (np. „ticket” na lotnisku i w kinie). Nie kopiuj wpisów między tematami.

| id | grupa | nazwa PL | zakres | shard |
|---|---|---|---|---|
| greetings-introductions | basics | Powitania i przedstawianie się | cześć, przedstawianie, pożegnania, uprzejmości | S1 |
| numbers-time | basics | Liczby, godziny i daty | liczebniki, zegar, dni, miesiące, kalendarz | S1 |
| colors-shapes-sizes | basics | Kolory, kształty i rozmiary | opis wyglądu przedmiotów | S1 |
| family | people | Rodzina | członkowie rodziny, relacje, wydarzenia rodzinne | S1 |
| personality | people | Charakter i osobowość | cechy charakteru, zachowanie | S1 |
| appearance | people | Wygląd zewnętrzny | twarz, sylwetka, włosy, opis osoby | S1 |
| emotions | people | Emocje i uczucia | stany emocjonalne, reakcje | S1 |
| daily-routine | daily | Codzienna rutyna | poranek, dzień, wieczór, nawyki | S1 |
| weather | daily | Pogoda | zjawiska, prognoza, temperatura | S1 |
| clothes-fashion | daily | Ubrania i moda | części garderoby, przymierzanie, styl | S1 |
| small-talk | communication | Small talk | rozpoczynanie rozmowy, pogawędki, tematy neutralne | S1 |
| opinions-agreeing | communication | Opinie, zgoda i niezgoda | wyrażanie zdania, argumenty, zgoda | S1 |
| airport | travel | Lotnisko | odprawa, bezpieczeństwo, bramki, bagaż, opóźnienia | S2 |
| flight | travel | Na pokładzie samolotu | lot, załoga, turbulencje, posiłek na pokładzie | S2 |
| hotel | travel | Hotel | rezerwacja, zameldowanie, pokój, obsługa, skargi | S2 |
| train-travel | travel | Podróż pociągiem | dworzec, bilety, peron, przesiadki | S2 |
| public-transport | travel | Komunikacja miejska | autobus, metro, tramwaj, taxi, aplikacje przejazdów | S2 |
| driving | travel | Samochód i jazda | prowadzenie, drogi, przepisy, parkowanie, stacja benzynowa | S2 |
| directions | travel | Pytanie o drogę | kierunki, orientacja w mieście, mapy | S2 |
| sightseeing | travel | Zwiedzanie | atrakcje, wycieczki z przewodnikiem, zabytki | S2 |
| beach-vacation | travel | Wakacje nad morzem | plaża, słońce, pływanie, kurort | S2 |
| camping-hiking | travel | Kemping i wędrówki | namiot, szlak, góry, sprzęt | S2 |
| border-immigration | travel | Granica i wizy | paszport, kontrola, cło, wizy, pobyt | S2 |
| car-rental | travel | Wypożyczalnia samochodów | umowa, ubezpieczenie, odbiór i zwrot auta | S2 |
| restaurant | food | Restauracja | rezerwacja, zamawianie, rachunek, napiwek | S3 |
| cafe-bakery | food | Kawiarnia i piekarnia | kawa, wypieki, zamawianie na wynos | S3 |
| cooking | food | Gotowanie | czynności kuchenne, przepisy, sprzęty | S3 |
| grocery-shopping | food | Zakupy spożywcze | supermarket, działy, kasa, opakowania | S3 |
| fruits-vegetables | food | Owoce i warzywa | nazwy, dojrzałość, przygotowanie | S3 |
| meat-fish-dairy | food | Mięso, ryby i nabiał | produkty, stopień wysmażenia, sklep mięsny | S3 |
| drinks-bar | food | Napoje i bar | napoje, bar, zamawianie drinków | S3 |
| diet-nutrition | food | Dieta i odżywianie | składniki odżywcze, alergie, diety | S3 |
| house-rooms | home | Dom i pomieszczenia | pokoje, części domu, opis mieszkania | S3 |
| furniture-household | home | Meble i wyposażenie | meble, AGD, przedmioty codziennego użytku | S3 |
| cleaning-chores | home | Sprzątanie i obowiązki domowe | sprzątanie, pranie, porządki | S3 |
| renting-apartment | home | Wynajem mieszkania | ogłoszenia, umowa, kaucja, właściciel | S3 |
| doctor-visit | health | Wizyta u lekarza | rejestracja, objawy, badanie, recepta | S4 |
| symptoms-illness | health | Objawy i choroby | dolegliwości, choroby, przeziębienie | S4 |
| body-parts | health | Części ciała | anatomia podstawowa i ruchy | S4 |
| pharmacy | health | Apteka i leki | leki, dawkowanie, bez recepty | S4 |
| hospital-emergency | health | Szpital i nagłe wypadki | SOR, karetka, urazy, pierwsza pomoc | S4 |
| dentist | health | Dentysta | zęby, zabiegi, ból zęba | S4 |
| fitness-gym | health | Siłownia i fitness | ćwiczenia, sprzęt, trening | S4 |
| mental-health | health | Zdrowie psychiczne | stres, samopoczucie, terapia | S4 |
| sleep | health | Sen | zasypianie, bezsenność, nawyki snu | S4 |
| sports | leisure | Sport | dyscypliny, zawody, kibicowanie | S4 |
| pets | nature | Zwierzęta domowe | opieka, weterynarz, karma | S4 |
| animals | nature | Zwierzęta | dzikie i hodowlane, zachowania | S4 |
| job-search | work | Szukanie pracy i rozmowa kwalifikacyjna | CV, ogłoszenia, rozmowa, oferta | S5 |
| office-work | work | Praca w biurze | zadania, sprzęt biurowy, terminy | S5 |
| meetings | work | Spotkania | prowadzenie spotkań, agenda, ustalenia | S5 |
| business-email | work | Korespondencja służbowa | maile, uprzejme formuły, załączniki | S5 |
| phone-calls | communication | Rozmowy telefoniczne | dzwonienie, łączenie, wiadomości | S5 |
| remote-work | work | Praca zdalna | wideokonferencje, narzędzia, home office | S5 |
| coworkers | work | Relacje w pracy | współpracownicy, przełożony, feedback | S5 |
| salary-benefits | work | Wynagrodzenie i benefity | pensja, podwyżka, urlop, umowa | S5 |
| customer-service | work | Obsługa klienta | reklamacje, zwroty, pomoc | S5 |
| complaints-problems | communication | Skargi i zgłaszanie problemów | opisywanie problemu, żądanie rozwiązania | S5 |
| requests-favors | communication | Prośby i przysługi | uprzejme prośby, propozycje, odmowa | S5 |
| apologies-politeness | communication | Przeprosiny i uprzejmość | przepraszanie, dziękowanie, takt | S5 |
| smartphones-apps | technology | Smartfon i aplikacje | telefon, ustawienia, aplikacje, bateria | S6 |
| computers-internet | technology | Komputer i internet | sprzęt, przeglądarka, pliki, Wi-Fi | S6 |
| social-media | technology | Media społecznościowe | posty, obserwujący, udostępnianie | S6 |
| cybersecurity | technology | Bezpieczeństwo w sieci | hasła, oszustwa, ochrona danych | S6 |
| banking | money | Bank | konto, przelewy, karty, kredyt | S6 |
| shopping-clothes | money | Zakupy w sklepie | przymierzalnia, rozmiary, wyprzedaż, kasa | S6 |
| online-shopping | money | Zakupy online | zamówienie, dostawa, zwrot, płatność | S6 |
| personal-finance | money | Finanse osobiste | budżet, oszczędzanie, długi, wydatki | S6 |
| post-office | services | Poczta i przesyłki | listy, paczki, kurier, nadawanie | S6 |
| police-crime | services | Policja i przestępstwa | zgłoszenie, kradzież, świadek | S6 |
| school | education | Szkoła | lekcje, klasa, nauczyciel, oceny | S6 |
| university | education | Studia | wykłady, egzaminy, kierunki, kampus | S6 |
| movies-tv | leisure | Filmy i seriale | gatunki, oglądanie, streaming, recenzje | S7 |
| music | leisure | Muzyka | gatunki, instrumenty, koncerty | S7 |
| books-reading | leisure | Książki i czytanie | gatunki, fabuła, biblioteka | S7 |
| art-museum | leisure | Sztuka i muzea | wystawy, malarstwo, galeria | S7 |
| hobbies-crafts | leisure | Hobby i rękodzieło | zainteresowania, majsterkowanie, szycie | S7 |
| photography | leisure | Fotografia | aparat, ujęcia, edycja zdjęć | S7 |
| video-games | leisure | Gry wideo | rozgrywka, konsola, gry online | S7 |
| football | leisure | Piłka nożna | mecz, drużyna, zasady, kibice | S7 |
| concerts-festivals | leisure | Koncerty i festiwale | bilety, scena, tłum, wydarzenia | S7 |
| theater | leisure | Teatr | spektakl, aktorzy, scena, widownia | S7 |
| parties-celebrations | people | Imprezy i uroczystości | urodziny, zaproszenia, prezenty | S7 |
| holidays-traditions | daily | Święta i tradycje | święta, zwyczaje, życzenia | S7 |
| friendship | people | Przyjaźń | przyjaciele, wsparcie, spotkania | S8 |
| dating-relationships | people | Randki i związki | randki, związek, rozstanie | S8 |
| wedding | people | Ślub i wesele | zaręczyny, ceremonia, przyjęcie | S8 |
| parenting | people | Rodzicielstwo i dzieci | opieka nad dziećmi, wychowanie | S8 |
| arguments-conflict | communication | Kłótnie i rozwiązywanie konfliktów | spór, kompromis, pogodzenie się | S8 |
| giving-advice | communication | Rady i sugestie | doradzanie, ostrzeżenia, zalecenia | S8 |
| storytelling | communication | Opowiadanie historii | narracja, kolejność zdarzeń, reakcje słuchacza | S8 |
| beauty-hairdresser | daily | Fryzjer i uroda | strzyżenie, kosmetyki, salon | S8 |
| repairs-diy | home | Naprawy i majsterkowanie | narzędzia, awarie, fachowiec | S8 |
| utilities-bills | home | Rachunki i media | prąd, woda, gaz, internet, opłaty | S8 |
| moving-house | home | Przeprowadzka | pakowanie, transport, nowe miejsce | S8 |
| garden-plants | home | Ogród i rośliny | sadzenie, podlewanie, narzędzia ogrodowe | S8 |
| project-management | work | Zarządzanie projektami | plan, terminy, ryzyka, zasoby | S9 |
| negotiations | work | Negocjacje | oferta, ustępstwa, warunki, umowa | S9 |
| presentations | work | Prezentacje i wystąpienia | slajdy, pytania, przekonywanie | S9 |
| marketing-sales | work | Marketing i sprzedaż | kampanie, klienci, marka, lejki | S9 |
| entrepreneurship | work | Własna firma i startupy | biznesplan, inwestorzy, wzrost | S9 |
| finance-accounting | work | Finanse i księgowość | faktury, budżet firmy, raporty | S9 |
| law-contracts | services | Prawo i umowy | umowa, klauzule, prawnik, sąd | S9 |
| government-offices | services | Urzędy i formalności | wnioski, dokumenty, kolejki | S9 |
| insurance | money | Ubezpieczenia | polisa, szkoda, składka, odszkodowanie | S9 |
| taxes | money | Podatki | zeznanie, ulgi, urząd skarbowy | S9 |
| programming-it | technology | Programowanie i IT | kod, błędy, wdrożenie, zespół IT | S9 |
| artificial-intelligence | technology | Sztuczna inteligencja | modele, dane, automatyzacja | S9 |
| environment-climate | nature | Środowisko i klimat | zmiany klimatu, recykling, energia | S10 |
| nature-landscape | nature | Krajobraz i przyroda | góry, rzeki, lasy, zjawiska | S10 |
| natural-disasters | nature | Klęski żywiołowe | powódź, trzęsienie ziemi, ewakuacja | S10 |
| space-astronomy | nature | Kosmos i astronomia | planety, gwiazdy, misje | S10 |
| farming-countryside | nature | Wieś i rolnictwo | gospodarstwo, uprawy, zwierzęta | S10 |
| news-media | society | Wiadomości i media | dziennikarstwo, nagłówki, źródła | S10 |
| politics-elections | society | Polityka i wybory | partie, głosowanie, kampania | S10 |
| economy | society | Gospodarka | inflacja, rynek, bezrobocie | S10 |
| history | society | Historia | epoki, wydarzenia, źródła | S10 |
| city-life | society | Życie w mieście | dzielnice, usługi, hałas, korki | S10 |
| volunteering-charity | society | Wolontariat i pomoc | zbiórki, organizacje, pomoc innym | S10 |
| religion-beliefs | society | Religia i przekonania | wierzenia, obrzędy, szacunek | S10 |
| science | education | Nauka i badania | eksperyment, hipoteza, laboratorium | S11 |
| exams-tests | education | Egzaminy | przygotowanie, wyniki, ściąganie | S11 |
| language-learning | education | Nauka języków | gramatyka, wymowa, płynność | S11 |
| math | education | Matematyka | działania, ułamki, wykresy | S11 |
| countries-nationalities | basics | Kraje i narodowości | państwa, języki, pochodzenie | S11 |
| jobs-professions | work | Zawody | nazwy zawodów, obowiązki | S11 |
| materials-objects | basics | Materiały i przedmioty | z czego coś jest zrobione, opis rzeczy | S11 |
| cycling | travel | Rower | jazda, części roweru, ścieżki | S11 |
| cruise-ferry | travel | Rejs i prom | statek, kajuta, port | S11 |
| car-problems | travel | Awaria samochodu i mechanik | usterki, warsztat, holowanie | S11 |
| fast-food-takeaway | food | Fast food i jedzenie na wynos | zamawianie, dostawa, aplikacje | S12 |
| board-games-puzzles | leisure | Gry planszowe i łamigłówki | zasady, ruch, wygrana | S12 |
| neighbors-community | home | Sąsiedzi i okolica | sąsiedztwo, spory, pomoc | S12 |
| elderly-care | health | Opieka nad seniorami | opieka, dom seniora, zdrowie | S12 |
| babies | people | Niemowlęta | opieka, karmienie, rozwój | S12 |
| shopping-mall | money | Galeria handlowa | sklepy, promocje, food court | S12 |
| emergencies-safety | services | Bezpieczeństwo i sytuacje awaryjne | pożar, alarm, numer alarmowy | S12 |
| describing-places | communication | Opisywanie miejsc | przymiotniki, porównania, atmosfera | S12 |
| feelings-reactions-phrases | communication | Reakcje w rozmowie | wykrzyknienia, potoczne reakcje | S12 |
| work-idioms | work | Idiomy w pracy | popularne idiomy biurowe i biznesowe | S12 |
| everyday-phrasal-verbs | communication | Czasowniki frazowe na co dzień | najczęstsze phrasal verbs w codziennych sytuacjach | S12 |
| slang-informal | communication | Potoczny amerykański angielski | powszechny, niewulgarny slang | S12 |

## Pomysły dodatkowe (do wzięcia po skończeniu sharda)

wine-tasting, skiing, fishing, yoga-meditation, nursing-care, architecture, real-estate, stock-market, journalism, military, aviation-pilots, sailing, horse-riding, gardening-advanced, interior-design, car-buying, wedding-planning, job-quitting, retirement, childcare-school-run, tourism-industry, hospitality-industry, construction, medicine-advanced, legal-courtroom, psychology, philosophy, literature-analysis, debate-rhetoric, academic-writing.

