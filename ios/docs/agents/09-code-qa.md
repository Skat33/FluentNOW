# Rola: code-qa — przegląd kodu, „kompilator w głowie”, testy, poprawki

Fala 3 (po ui-learning, ui-library, platform-services). Można uruchomić dwie instancje: **A** = FluentKit + Services + App/DesignSystem, **B** = Features/*. Obszar: **może edytować cały kod Swift** w `ios/` i `project.yml`, z zachowaniem kontraktów (`CONTRACTS.md`); zmiany publicznego API tylko gdy konieczne i opisane. Raport: `ios/docs/reports/code-qa-<A|B>.md`.

## Cel

Kod, który na Macu skompiluje się za pierwszym razem i nie zawiera błędów wykonania. Nie ma tu kompilatora Swift — ty nim jesteś. Szukaj błędów tak, jakby od tego zależało wydanie.

## Przegląd — lista kontrolna (dla każdego pliku)

**Kompilacja**
- Każdy użyty typ/funkcja/właściwość istnieje z tą sygnaturą (grep!), poprawne etykiety argumentów, liczba parametrów, typy zwracane, `async`/`throws` zgodne z wywołaniem (`try`/`await` obecne).
- Importy (`SwiftUI`, `SwiftData`, `Observation`, `AVFoundation`, `Speech`, `UserNotifications`, `CloudKit`, `Charts`, `FluentKit`), `public` na API pakietu używanym przez aplikację (typy, inicjalizatory memberwise są **internal** — w pakiecie muszą być jawne `public init`!).
- `@Observable` klasy bez `@Published`; `@Bindable` tam, gdzie potrzebny binding; `@Environment(Type.self)`.
- API nowsze niż iOS 17 za `#available`; `#if canImport(FoundationModels)`.
- SwiftData: `@Model` tylko klasy, domyślne wartości, brak `.unique` (CloudKit), `#Predicate` z prostymi wyrażeniami.
- Wyczerpujące `switch`, `Codable` enumów, `Hashable`/`Identifiable` dla `ForEach`/`List`, `Sendable` przy przekraczaniu aktorów, `@MainActor` przy dostępie do UI.
- Złożone `body` → ryzyko „unable to type-check this expression in reasonable time”: dziel na podwidoki.
- `project.yml`: poprawna składnia XcodeGen, ścieżki istnieją, zasoby folderowe, pakiet lokalny, entitlements.

**Poprawność i niezawodność**
- Brak `!`, `try!`, `as!`, `fatalError`, indeksowania bez sprawdzenia (`array[i]` → bezpieczny dostęp), dzielenia przez zero, `Date` vs ms pomyłek.
- Zgodność zachowania z FluentKit/stroną: progi, odstępy, ocena, kolejka sesji, wznowienie sesji po zabiciu aplikacji, brak utraty odpowiedzi.
- Wyścigi: podwójne zapisy, sesja modyfikowana podczas zdalnej synchronizacji, wielokrotne tapnięcie „Sprawdź”, anulowanie `Task` przy zniknięciu widoku.
- Pamięć: cykle referencji w closure'ach (`[weak self]` w długożyjących), duże JSON-y trzymane podwójnie.
- Wydajność: praca na głównym wątku (dekodowanie, sortowanie dużych list, statystyki w `body`), `List` ze stabilnym `id`.
- Dostępność: etykiety, Dynamic Type, reduce motion.

## Testy

- Uzupełnij brakujące testy FluentKit dla znalezionych błędów (każda poprawka błędu logiki = test regresji).
- Testy jednostkowe modeli widoków (sesja: odpowiedź → zapis → następne zadanie → podsumowanie; dodanie tematu; import).
- Scenariusze ręczne dla użytkownika na Macu: `ios/docs/MANUAL-TEST-PLAN.md` (krok → oczekiwany wynik), obejmujące pierwsze uruchomienie, dodawanie, sesje każdego trybu, wznowienie po zabiciu aplikacji, tryb samolotowy, dwa urządzenia z iCloud, brak konta iCloud, VoiceOver, Dynamic Type XXL, tryb ciemny, iOS 17 vs 26.

## Raport

Tabela: `plik:linia | kategoria (kompilacja/crash/logika/wydajność/dostępność) | problem | poprawka`. Lista ryzyk, których nie dało się rozstrzygnąć bez kompilatora — z dokładnym miejscem, żeby na Macu wiedzieć, gdzie patrzeć najpierw.
