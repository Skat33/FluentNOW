# v38 — jednoznaczne odpowiedzi, lektor ćwiczeń i zgłoszenia

## Zachowanie

- Słowa w parach, ćwiczenia słownictwa i codzienna mieszanka korzystają wyłącznie z lokalnego klucza odpowiedzi. Nie wysyłają odpowiedzi do AI. Akceptowane są zapisane alternatywy, bez rozróżniania wielkości liter, nadmiarowych odstępów i polskich znaków. Literówka ani nieznany wariant nie zostają automatycznie zaliczone.
- Dla tłumaczenia na polski warianty pochodzą z tłumaczenia znaczenia (można rozdzielić je przecinkiem, średnikiem lub ukośnikiem). Angielskie alternatywy są zapisywane przy znaczeniu; w zadaniu z luką wymagany jest zapisany wariant gramatyczny z przykładu.
- Lektor przed sprawdzeniem pozostawia pauzę w luce i pomija polską podpowiedź z nawiasu. Po sprawdzeniu czyta poprawny klucz, również po błędnej odpowiedzi. Fiszki i rozpoznawanie mogą odczytać widoczne angielskie zdanie; dyktando odczytuje słowo będące treścią zadania.
- W ćwiczeniach stosujemy deterministyczny Azure Speech. Gdy jest niedostępny, nie przekazujemy luk do generatywnego lektora Gemini. Użytkownik może ponowić odtworzenie lub jawnie wybrać głos urządzenia. Microsoft SSML: https://learn.microsoft.com/azure/ai-services/speech-service/speech-synthesis-markup-structure
- Nagrania są przygotowywane w tle dla bieżącej treści. Wersja z luką i wersja poprawna mają różne klucze. IndexedDB zachowuje do 50 MiB audio między wizytami; najstarsze używane nagrania są usuwane po przekroczeniu pojemności. Dodatkowo działa współdzielony cache serwera. Pierwsze odtworzenie nowego tekstu nadal może wymagać pobrania. Wyczyszczenie danych przeglądarki usuwa lokalną kopię.
- „Zgłoś błąd w zadaniu” pojawia się przy wyniku. Zapisuje treść, odpowiedź użytkownika, oczekiwane warianty i komentarz. Ustawienia → Zgłoszenia pozwalają przeglądać, usuwać i eksportować JSON. Zgłoszenia są rozdzielone według konta na urządzeniu, nie są jeszcze wysyłane do obsługi, bazy ani pocztą. Nie synchronizują się między urządzeniami.

## Weryfikacja

- Testy sprawdzają diakrytykę, odrzucanie literówek/nieznanych wariantów, odmianę w luce, poprawny tekst przed i po sprawdzeniu, SSML z pauzą, rozdzielenie cache, brak generatywnego fallbacku w ćwiczeniach i trwały lokalny zapis zgłoszeń.
- Testy API korzystają z atrap dostawców. Nie stanowią odsłuchowego testu jakości głosu Azure na telefonie.
- Schemat stanu konta i migracje D1 pozostają bez zmian. Zgłoszenia nie wchodzą do synchronizowanego stanu.
