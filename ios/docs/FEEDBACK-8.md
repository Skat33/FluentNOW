# Runda 8 — uwagi właściciela po testach na symulatorze

## M1. Wyróżnienie słów w czytance wygląda jak błędy
Obecnie słowa ze słowniczka mają przerywane podkreślenie + jasne tło — wygląda to jak podkreślenie błędów pisowni. Zmienić styl:
- słowa ze słowniczka (dotknij → tłumaczenie): **bez podkreślenia i bez tła**, tylko kolor akcentu (lekko przyciemniony, czytelny w trybie ciemnym), ewentualnie medium weight; wskazówka „dotknij słowa, by zobaczyć tłumaczenie” raz nad tekstem;
- słowa polecane (do nauki): pogrubione + inny kolor (zgodnie z FEEDBACK-6), bez podkreślenia;
- własne słowa ucznia: kolor + subtelna kropka/znacznik lub semibold — ma być odróżnialne od polecanych;
- legenda pod tytułem (2–3 kolorowe próbki) zamiast podkreśleń.
Żadnego `underlineStyle` z wzorem dash/dot. Kontrast WCAG AA w jasnym i ciemnym motywie.

## M2. Jedna siatka „Ćwiczenia”, wybór pojedynczy
Wszystkie rodzaje zajęć mają być **osobnymi ćwiczeniami** w jednej sekcji „Ćwiczenia” na ekranie Nauka (wybór jednego kafelka = start). Łączenie wielu typów naraz ma być tylko w **Teście**. W siatce: typy słownictwa (Wybierz znaczenie, Przypomnij sobie, Uzupełnij lukę, Ułóż zdanie, Słuchanie, Dopasuj pary…), a także: Codzienna mieszanka, Tryb pomyłek, Słowa w parach, Czytanie, Gramatyka, Idiomy, Miks językowy, Produkcja. Nigdzie nie może zostać wielokrotny wybór typów („Zaznacz jeden lub kilka…”) ani przycisk „Wybierz ćwiczenie”.

## M3. Dodaj słowo — bez wybierania duplikatów
Gdy hasło ma kilka wpisów z **tym samym tłumaczeniem** (np. *catch up* „nadrobić zaległości” w 3 tematach + core), arkusz „Dodaj słowo” pokazuje **jedno** znaczenie na unikalne tłumaczenie (po normalizacji). Dodanie go dołącza automatycznie **wszystkie** przykładowe zdania ze wszystkich zgrupowanych wpisów (bez duplikatów zdań). Wybór zostaje tylko między **różnymi** znaczeniami (np. *catch up* „dogonić” vs „nadrobić zaległości”). To samo w wynikach skanowania i w „Szukaj tematu” (posiadane = wyszarzone, bez powtórzeń).
