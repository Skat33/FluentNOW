import Foundation
import FluentKit

/// Deterministyczne dane przykładowe dla `#Preview` i testów: 30 słów z pięciu tematów
/// (jedno z dwoma znaczeniami, jedno w archiwum), różne etapy nauki, historia odpowiedzi
/// z 14 dni (z przerwą — seria 4 dni) i przerwana sesja słówek.
enum PreviewData {
    /// Stały „teraz” podglądu: 2026-10-05 10:00 UTC.
    static let now: Timestamp = 1_791_194_400_000
    private static let day = TimeConstants.dayMs

    static let collections = ["Lotnisko", "Restauracja", "U lekarza", "Praca w biurze", "Codzienne rozmowy"]

    /// Pełny stan przykładowy.
    static func state() -> LearnerState {
        let words = makeWords()
        return LearnerState(
            words: words,
            collections: collections,
            reviews: makeReviews(words: words),
            settings: LearnerSettings(goal: 20, reminder: "19:00", accent: "en-US", slow: false),
            session: makeSession(words: words)
        )
    }

    /// Pusty stan (nowy użytkownik).
    static func emptyState() -> LearnerState {
        .empty
    }

    // MARK: - Słowa

    private struct Seed {
        let id: String
        let en: String
        let ipa: String
        let pos: String
        let level: String
        let collection: String
        let pl: String
        let exampleEn: String
        let examplePl: String
        let focusEn: String
        let focusPl: String
    }

    private static let seeds: [Seed] = [
        Seed(id: "boarding-pass", en: "boarding pass", ipa: "/ˈbɔːrdɪŋ ˌpæs/", pos: "rzeczownik", level: "A2", collection: "Lotnisko", pl: "karta pokładowa",
             exampleEn: "Please have your boarding pass ready at the gate.", examplePl: "Prosimy mieć kartę pokładową gotową przy bramce.", focusEn: "boarding pass", focusPl: "kartę pokładową"),
        Seed(id: "carry-on", en: "carry-on", ipa: "/ˈkæri ɑːn/", pos: "rzeczownik", level: "B1", collection: "Lotnisko", pl: "bagaż podręczny",
             exampleEn: "My carry-on barely fit in the overhead bin.", examplePl: "Mój bagaż podręczny ledwo zmieścił się w schowku nad głową.", focusEn: "carry-on", focusPl: "bagaż podręczny"),
        Seed(id: "delay", en: "delay", ipa: "/dɪˈleɪ/", pos: "rzeczownik", level: "A2", collection: "Lotnisko", pl: "opóźnienie",
             exampleEn: "The delay was caused by bad weather.", examplePl: "Opóźnienie było spowodowane złą pogodą.", focusEn: "delay", focusPl: "Opóźnienie"),
        Seed(id: "check-in", en: "check in", ipa: "/ˌtʃek ˈɪn/", pos: "czasownik frazowy", level: "A2", collection: "Lotnisko", pl: "odprawić się",
             exampleEn: "We need to check in two hours before the flight.", examplePl: "Musimy odprawić się dwie godziny przed lotem.", focusEn: "check in", focusPl: "odprawić się"),
        Seed(id: "gate", en: "gate", ipa: "/ɡeɪt/", pos: "rzeczownik", level: "A2", collection: "Lotnisko", pl: "bramka",
             exampleEn: "Our flight leaves from gate 12.", examplePl: "Nasz lot odlatuje z bramki 12.", focusEn: "gate", focusPl: "bramki"),
        Seed(id: "layover", en: "layover", ipa: "/ˈleɪˌoʊvər/", pos: "rzeczownik", level: "B1", collection: "Lotnisko", pl: "przesiadka",
             exampleEn: "We have a three-hour layover in Chicago.", examplePl: "Mamy trzygodzinną przesiadkę w Chicago.", focusEn: "layover", focusPl: "przesiadkę"),
        Seed(id: "check", en: "check", ipa: "/tʃek/", pos: "rzeczownik", level: "A2", collection: "Restauracja", pl: "rachunek",
             exampleEn: "Could we get the check, please?", examplePl: "Czy możemy prosić o rachunek?", focusEn: "check", focusPl: "rachunek"),
        Seed(id: "tip", en: "tip", ipa: "/tɪp/", pos: "rzeczownik", level: "A2", collection: "Restauracja", pl: "napiwek",
             exampleEn: "We left a twenty percent tip for the waiter.", examplePl: "Zostawiliśmy kelnerowi dwudziestoprocentowy napiwek.", focusEn: "tip", focusPl: "napiwek"),
        Seed(id: "order", en: "order", ipa: "/ˈɔːrdər/", pos: "czasownik", level: "A1", collection: "Restauracja", pl: "zamówić",
             exampleEn: "I'd like to order the grilled salmon.", examplePl: "Chciałbym zamówić grillowanego łososia.", focusEn: "order", focusPl: "zamówić"),
        Seed(id: "appetizer", en: "appetizer", ipa: "/ˈæpəˌtaɪzər/", pos: "rzeczownik", level: "B1", collection: "Restauracja", pl: "przystawka",
             exampleEn: "Let's share an appetizer before the main course.", examplePl: "Weźmy jedną przystawkę na pół przed daniem głównym.", focusEn: "appetizer", focusPl: "przystawkę"),
        Seed(id: "to-go", en: "to go", ipa: "/tə ˈɡoʊ/", pos: "zwrot", level: "A2", collection: "Restauracja", pl: "na wynos",
             exampleEn: "Can I get a coffee to go?", examplePl: "Poproszę kawę na wynos.", focusEn: "to go", focusPl: "na wynos"),
        Seed(id: "leftovers", en: "leftovers", ipa: "/ˈleftˌoʊvərz/", pos: "rzeczownik", level: "B1", collection: "Restauracja", pl: "resztki jedzenia",
             exampleEn: "We took the leftovers home in a box.", examplePl: "Zabraliśmy resztki jedzenia do domu w pudełku.", focusEn: "leftovers", focusPl: "resztki jedzenia"),
        Seed(id: "appointment", en: "appointment", ipa: "/əˈpɔɪntmənt/", pos: "rzeczownik", level: "A2", collection: "U lekarza", pl: "wizyta",
             exampleEn: "I have a doctor's appointment at nine.", examplePl: "Mam wizytę u lekarza o dziewiątej.", focusEn: "appointment", focusPl: "wizytę"),
        Seed(id: "prescription", en: "prescription", ipa: "/prɪˈskrɪpʃən/", pos: "rzeczownik", level: "B1", collection: "U lekarza", pl: "recepta",
             exampleEn: "The doctor gave me a prescription for antibiotics.", examplePl: "Lekarz wypisał mi receptę na antybiotyk.", focusEn: "prescription", focusPl: "receptę"),
        Seed(id: "sore-throat", en: "sore throat", ipa: "/ˌsɔːr ˈθroʊt/", pos: "rzeczownik", level: "A2", collection: "U lekarza", pl: "ból gardła",
             exampleEn: "I have a sore throat and a slight fever.", examplePl: "Boli mnie gardło i mam lekką gorączkę.", focusEn: "sore throat", focusPl: "Boli mnie gardło"),
        Seed(id: "symptom", en: "symptom", ipa: "/ˈsɪmptəm/", pos: "rzeczownik", level: "B1", collection: "U lekarza", pl: "objaw",
             exampleEn: "Fatigue is a common symptom of the flu.", examplePl: "Zmęczenie to częsty objaw grypy.", focusEn: "symptom", focusPl: "objaw"),
        Seed(id: "get-over", en: "get over", ipa: "/ˌɡet ˈoʊvər/", pos: "czasownik frazowy", level: "B1", collection: "U lekarza", pl: "wyzdrowieć",
             exampleEn: "It took me a week to get over the flu.", examplePl: "Wyzdrowienie po grypie zajęło mi tydzień.", focusEn: "get over", focusPl: "Wyzdrowienie"),
        Seed(id: "deadline", en: "deadline", ipa: "/ˈdedˌlaɪn/", pos: "rzeczownik", level: "B1", collection: "Praca w biurze", pl: "termin",
             exampleEn: "The deadline for the report is Friday.", examplePl: "Termin oddania raportu mija w piątek.", focusEn: "deadline", focusPl: "Termin oddania"),
        Seed(id: "coworker", en: "coworker", ipa: "/ˈkoʊˌwɝːkər/", pos: "rzeczownik", level: "A2", collection: "Praca w biurze", pl: "współpracownik",
             exampleEn: "My coworker helped me fix the spreadsheet.", examplePl: "Współpracownik pomógł mi poprawić arkusz kalkulacyjny.", focusEn: "coworker", focusPl: "Współpracownik"),
        Seed(id: "meeting", en: "meeting", ipa: "/ˈmiːtɪŋ/", pos: "rzeczownik", level: "A1", collection: "Praca w biurze", pl: "spotkanie",
             exampleEn: "The meeting was moved to three o'clock.", examplePl: "Spotkanie przesunięto na trzecią.", focusEn: "meeting", focusPl: "Spotkanie"),
        Seed(id: "follow-up", en: "follow up", ipa: "/ˌfɑːloʊ ˈʌp/", pos: "czasownik frazowy", level: "B2", collection: "Praca w biurze", pl: "wrócić do sprawy",
             exampleEn: "I'll follow up with the client tomorrow.", examplePl: "Jutro wrócę do sprawy z klientem.", focusEn: "follow up", focusPl: "wrócę do sprawy"),
        Seed(id: "raise", en: "raise", ipa: "/reɪz/", pos: "rzeczownik", level: "B1", collection: "Praca w biurze", pl: "podwyżka",
             exampleEn: "She finally asked her boss for a raise.", examplePl: "W końcu poprosiła szefa o podwyżkę.", focusEn: "raise", focusPl: "podwyżkę"),
        Seed(id: "day-off", en: "day off", ipa: "/ˌdeɪ ˈɔːf/", pos: "rzeczownik", level: "A2", collection: "Praca w biurze", pl: "dzień wolny",
             exampleEn: "I'm taking a day off next Monday.", examplePl: "W przyszły poniedziałek biorę dzień wolny.", focusEn: "day off", focusPl: "dzień wolny"),
        Seed(id: "borrow", en: "borrow", ipa: "/ˈbɑːroʊ/", pos: "czasownik", level: "A2", collection: "Codzienne rozmowy", pl: "pożyczyć (od kogoś)",
             exampleEn: "Can I borrow your charger for a minute?", examplePl: "Mogę na chwilę pożyczyć twoją ładowarkę?", focusEn: "borrow", focusPl: "pożyczyć"),
        Seed(id: "lend", en: "lend", ipa: "/lend/", pos: "czasownik", level: "A2", collection: "Codzienne rozmowy", pl: "pożyczyć (komuś)",
             exampleEn: "Could you lend me twenty dollars until Friday?", examplePl: "Możesz mi pożyczyć dwadzieścia dolarów do piątku?", focusEn: "lend", focusPl: "pożyczyć"),
        Seed(id: "run-out-of", en: "run out of", ipa: "/ˌrʌn ˈaʊt əv/", pos: "czasownik frazowy", level: "B1", collection: "Codzienne rozmowy", pl: "skończyć się (o zapasach)",
             exampleEn: "We ran out of milk, so I went to the store.", examplePl: "Skończyło nam się mleko, więc poszedłem do sklepu.", focusEn: "ran out of", focusPl: "Skończyło nam się"),
        Seed(id: "figure-out", en: "figure out", ipa: "/ˌfɪɡjər ˈaʊt/", pos: "czasownik frazowy", level: "B1", collection: "Codzienne rozmowy", pl: "rozgryźć",
             exampleEn: "I can't figure out how this app works.", examplePl: "Nie mogę rozgryźć, jak działa ta aplikacja.", focusEn: "figure out", focusPl: "rozgryźć"),
        Seed(id: "actually", en: "actually", ipa: "/ˈæktʃuəli/", pos: "przysłówek", level: "A2", collection: "Codzienne rozmowy", pl: "właściwie",
             exampleEn: "I actually prefer tea to coffee.", examplePl: "Właściwie wolę herbatę od kawy.", focusEn: "actually", focusPl: "Właściwie"),
        Seed(id: "awkward", en: "awkward", ipa: "/ˈɔːkwərd/", pos: "przymiotnik", level: "B2", collection: "Codzienne rozmowy", pl: "niezręczny",
             exampleEn: "There was an awkward silence after his joke.", examplePl: "Po jego żarcie zapadła niezręczna cisza.", focusEn: "awkward", focusPl: "niezręczna"),
        Seed(id: "book", en: "book", ipa: "/bʊk/", pos: "czasownik", level: "A2", collection: "Restauracja", pl: "zarezerwować",
             exampleEn: "We booked a table for four at eight.", examplePl: "Zarezerwowaliśmy stolik dla czterech osób na ósmą.", focusEn: "booked", focusPl: "Zarezerwowaliśmy")
    ]

    static func makeWords() -> [Word] {
        var words: [Word] = []
        for (index, seed) in seeds.enumerated() {
            let wordID = "preview.\(seed.id)"
            var meanings = [
                Meaning(
                    id: "\(wordID).m1",
                    exampleTranslations: [seed.examplePl],
                    exampleFocusEn: [seed.focusEn],
                    exampleFocusPl: [seed.focusPl],
                    acceptedAnswers: [seed.en],
                    level: seed.level,
                    pos: seed.pos,
                    translation: seed.pl,
                    examples: [seed.exampleEn],
                    scores: scores(pattern: index),
                    contentRef: nil
                )
            ]
            if seed.id == "book" {
                meanings.append(Meaning(
                    id: "\(wordID).m2",
                    exampleTranslations: ["Ta książka opowiada o małym miasteczku w Ohio."],
                    exampleFocusEn: ["book"],
                    exampleFocusPl: ["książka"],
                    acceptedAnswers: ["book"],
                    level: "A1",
                    pos: "rzeczownik",
                    translation: "książka",
                    examples: ["This book is about a small town in Ohio."],
                    scores: scores(pattern: 2)
                ))
            }
            let created = now - Double(30 - index) * day
            words.append(Word(
                id: wordID,
                en: seed.en,
                ipa: seed.ipa,
                pos: seed.pos,
                level: seed.level,
                collection: seed.collection,
                source: "Podgląd",
                archived: seed.id == "appetizer",
                created: created,
                updatedAt: created,
                meanings: meanings
            ))
        }
        // Najnowsze najpierw (jak w aplikacji).
        return words.reversed()
    }

    /// Etapy nauki: nowe, uczę się, opanowane, trudne, w trakcie, do odświeżenia.
    private static func scores(pattern: Int) -> SkillScores {
        func score(interval: Double, dueInDays: Double, correct: Int, wrong: Int) -> Score {
            let due = now + dueInDays * day
            return Score(
                value: Mastery.fromInterval(interval),
                interval: interval,
                due: due,
                correct: correct,
                wrong: wrong,
                hinted: 0,
                last: due - interval * day,
                slow: 0
            )
        }
        switch pattern % 6 {
        case 0:
            return SkillScores()
        case 1:
            return SkillScores([
                .recognition: score(interval: 2, dueInDays: -1, correct: 2, wrong: 1),
                .recall: score(interval: 1, dueInDays: 1, correct: 1, wrong: 1)
            ])
        case 2:
            return SkillScores([
                .recognition: score(interval: 35, dueInDays: 12, correct: 7, wrong: 0),
                .recall: score(interval: 30, dueInDays: 9, correct: 6, wrong: 1),
                .usage: score(interval: 25, dueInDays: 6, correct: 5, wrong: 0),
                .listening: score(interval: 28, dueInDays: 8, correct: 5, wrong: 0)
            ])
        case 3:
            return SkillScores([
                .recognition: score(interval: 0.5, dueInDays: -0.1, correct: 1, wrong: 4),
                .recall: score(interval: 0.2, dueInDays: -0.2, correct: 0, wrong: 3)
            ])
        case 4:
            return SkillScores([
                .recognition: score(interval: 6, dueInDays: 3, correct: 3, wrong: 0),
                .recall: score(interval: 4, dueInDays: 2, correct: 3, wrong: 1),
                .spelling: score(interval: 3, dueInDays: 1, correct: 2, wrong: 0)
            ])
        default:
            return SkillScores([
                .recognition: score(interval: 14, dueInDays: -5, correct: 4, wrong: 0),
                .recall: score(interval: 10, dueInDays: -3, correct: 4, wrong: 1)
            ])
        }
    }

    // MARK: - Historia odpowiedzi (14 dni)

    static func makeReviews(words: [Word]) -> [Review] {
        let practiced = words.filter { word in
            !word.archived && !(word.meanings.first?.scores.isEmpty ?? true)
        }
        guard !practiced.isEmpty else { return [] }
        let skills: [Skill] = [.recognition, .recall, .usage, .listening, .spelling]
        var reviews: [Review] = []
        for dayOffset in 0..<14 where dayOffset != 4 {
            let count = 6 + (dayOffset * 5) % 9
            for item in 0..<count {
                let word = practiced[(dayOffset * 7 + item * 3) % practiced.count]
                guard let meaning = word.meanings.first else { continue }
                let correct = (dayOffset + item) % 5 != 0
                let at = now - Double(dayOffset) * day - 2 * TimeConstants.hourMs - Double(item + 1) * 90_000
                reviews.append(Review(
                    id: "preview.review.\(dayOffset).\(item)",
                    wordId: word.id,
                    meaningId: meaning.id,
                    skill: skills[(dayOffset + item) % skills.count],
                    correct: correct,
                    at: at,
                    seconds: 4 + Double(item % 5),
                    confidence: correct ? 3 : 1,
                    hint: false,
                    before: 40,
                    after: correct ? 48 : 30
                ))
            }
        }
        return reviews.sorted { $0.at < $1.at }
    }

    // MARK: - Przerwana sesja

    static func makeSession(words: [Word]) -> VocabSession? {
        let candidates = words.filter { !$0.archived && !($0.meanings.first?.scores.isEmpty ?? true) }
        let types: [ExerciseType] = [.flashcard, .meaning, .recall, .cloze, .dictation, .flashcard]
        var tasks: [VocabTask] = []
        for (index, word) in candidates.prefix(types.count).enumerated() {
            guard let meaning = word.meanings.first else { continue }
            tasks.append(VocabTask(wordId: word.id, meaningId: meaning.id, type: types[index], example: 0))
        }
        guard tasks.count >= 3 else { return nil }
        return VocabSession(tasks: tasks, index: 2, correct: 2, minutes: 5, mode: "mixed")
    }

    // MARK: - Zgłoszenia

    static let reports: [ExerciseReport] = [
        ExerciseReport(
            id: "preview.report.1",
            createdAt: now - 2 * day,
            mode: "Przypominanie",
            question: "pożyczyć (komuś)",
            answer: "borrow",
            expected: ["lend"],
            wordId: "preview.lend",
            meaningId: "preview.lend.m1",
            comment: "Wydaje mi się, że to też powinno być zaliczone."
        )
    ]
}
