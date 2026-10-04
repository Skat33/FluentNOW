import Foundation
import XCTest
@testable import FluentKit

/// Fixed clock used by all tests (2026-09-01 12:00 UTC).
let testNow: Timestamp = 1_788_264_000_000
let day: Double = 86_400_000

/// Deterministic id generator.
final class IDGenerator {
    private var counter = 0
    private let prefix: String

    init(prefix: String = "id") {
        self.prefix = prefix
    }

    func next() -> String {
        counter += 1
        return "\(prefix)-\(counter)"
    }
}

/// A generator that always returns the same value (`0` → `nextUnit() == 0`).
struct ConstantGenerator: RandomNumberGenerator {
    var value: UInt64 = 0
    mutating func next() -> UInt64 { value }
}

enum TestData {
    /// A word with one fresh meaning (port of `freshWord` from learning.test.mjs).
    static func freshWord(_ id: String, _ en: String, _ translation: String, example: String? = nil) -> Word {
        Word(
            id: id,
            en: en,
            pos: "czasownik",
            level: "A2",
            collection: "Własne",
            source: "test",
            created: 1,
            meanings: [Meaning(
                id: "m-\(id)",
                translation: translation,
                definition: translation,
                examples: [example ?? "I use \(en) every day."],
                context: "",
                register: "neutralny"
            )]
        )
    }

    static func emptyState() -> LearnerState {
        LearnerState(settings: LearnerSettings(goal: 20), demo: false)
    }

    /// Port of the web `seed()` starter state (17 words, bank with two senses, demo reviews).
    static func seed(now: Timestamp = testNow) -> LearnerState {
        typealias Row = (en: String, tr: String, def: String, ex: String, collection: String, level: String, ipa: String, pos: String, reg: String, value: Int)
        let rows: [Row] = [
            ("get the hang of", "załapać, jak coś działa", "To learn how to do something through practice.", "You will get the hang of it with a little practice.|I want to get the hang of this new app.", "Codzienne rozmowy", "B2", "/ɡet ðə hæŋ əv/", "zwrot", "potoczny", 64),
            ("borrow", "pożyczyć od kogoś", "To take something temporarily and return it.", "Can I borrow your pen?|I often borrow books from the library.", "Codzienne rozmowy", "A2", "/ˈbɑːroʊ/", "czasownik", "neutralny", 38),
            ("lend", "pożyczyć komuś", "To give something temporarily to someone.", "Could you lend me your umbrella?|I can lend you my bike.", "Codzienne rozmowy", "A2", "/lend/", "czasownik", "neutralny", 45),
            ("boarding pass", "karta pokładowa", "A document that lets you board a plane.", "Please show me your boarding pass.|Keep your boarding pass ready.", "W podróży", "A2", "/ˈbɔːrdɪŋ pæs/", "rzeczownik", "neutralny", 88),
            ("accomplish", "osiągnąć, zrealizować", "To successfully complete a task or goal.", "We can accomplish a lot together.|What do you want to accomplish this year?", "W pracy", "B2", "/əˈkɑːmplɪʃ/", "czasownik", "formalny", 72),
            ("it depends", "to zależy", "Used when an answer changes with the situation.", "It depends on the weather.|It depends on how much time we have.", "Codzienne rozmowy", "A2", "/ɪt dɪˈpendz/", "zwrot", "neutralny", 0),
            ("bank", "bank — instytucja finansowa", "An institution where people keep or borrow money.", "The bank closes at five.|There is a bank near my office.", "Codzienne rozmowy", "A1", "/bæŋk/", "rzeczownik", "neutralny", 55),
            ("reservation", "rezerwacja", "An arrangement to keep a room or table for someone.", "I have a reservation for two.|Can I change my reservation?", "W podróży", "A2", "/ˌrezərˈveɪʃən/", "rzeczownik", "neutralny", 83),
            ("deadline", "termin wykonania", "The latest time by which something must be finished.", "The deadline is next Friday.|We need to meet the deadline.", "W pracy", "B1", "/ˈdedlaɪn/", "rzeczownik", "zawodowy", 65),
            ("say", "powiedzieć coś", "To express something using words.", "What did you say?|Please say that again.", "Codzienne rozmowy", "A1", "/seɪ/", "czasownik", "neutralny", 36),
            ("tell", "powiedzieć komuś", "To give information to a person.", "Please tell me the truth.|Can you tell us a story?", "Codzienne rozmowy", "A1", "/tel/", "czasownik", "neutralny", 40),
            ("make", "zrobić, stworzyć", "To create or produce something.", "Let’s make a plan.|I want to make a cake.", "Codzienne rozmowy", "A1", "/meɪk/", "czasownik", "neutralny", 62),
            ("do", "wykonywać czynność", "To perform an activity or task.", "I need to do my homework.|Can you do the shopping today?", "Codzienne rozmowy", "A1", "/duː/", "czasownik", "neutralny", 48),
            ("appointment", "umówiona wizyta", "An arrangement to meet someone at a particular time.", "I have an appointment with the doctor.|Can I book an appointment?", "U lekarza", "A2", "/əˈpɔɪntmənt/", "rzeczownik", "neutralny", 74),
            ("recommend", "polecać", "To suggest that someone or something is a good choice.", "What dish do you recommend?|I recommend the vegetable soup.", "W restauracji", "B1", "/ˌrekəˈmend/", "czasownik", "neutralny", 80),
            ("strength", "mocna strona", "A positive quality or ability.", "My greatest strength is patience.|Teamwork is a real strength of mine.", "Rozmowa o pracę", "B1", "/streŋθ/", "rzeczownik", "neutralny", 60),
            ("take your time", "nie spiesz się", "Used to say that someone does not need to hurry.", "Take your time. There is no rush.|Please take your time with the exercise.", "Codzienne rozmowy", "B1", "/teɪk jʊr taɪm/", "zwrot", "neutralny", 90),
            ("figure out", "rozgryźć, zrozumieć", "To understand or solve something by thinking.", "Let’s figure out what went wrong.|I need to figure out how this works.", "W pracy", "B1", "/ˈfɪɡjər aʊt/", "czasownik frazowy", "potoczny", 0)
        ]
        var words: [Word] = []
        for (i, row) in rows.enumerated() {
            var scores = SkillScores()
            if row.value > 0 {
                for skill in [Skill.recognition, .recall, .spelling, .listening] {
                    let interval: Double = row.value > 80 ? 14 : 3
                    scores[skill] = Score(
                        value: Mastery.fromInterval(interval),
                        interval: interval,
                        due: now + Double(i % 3 == 0 ? 3 : -1) * day,
                        correct: Int((Double(row.value) / 10).rounded()),
                        wrong: (i == 1 || i == 2) ? 4 : ((i == 9 || i == 10) ? 2 : 0),
                        hinted: 0,
                        last: now - Double(1 + i % 4) * day,
                        slow: 0
                    )
                }
            }
            var forms = ""
            switch row.en {
            case "borrow": forms = "borrowed · borrowed"
            case "lend": forms = "lent · lent"
            case "say": forms = "said · said"
            case "tell": forms = "told · told"
            case "make": forms = "made · made"
            case "do": forms = "did · done"
            default: forms = ""
            }
            let note = i == 1 ? "Borrow = biorę, lend = daję. Po borrow użyj from, po lend — to." : (i == 9 ? "Say something, ale tell someone something." : "")
            words.append(Word(
                id: "w\(i)",
                en: row.en,
                ipa: row.ipa,
                pos: row.pos,
                level: row.level,
                collection: row.collection,
                tags: i < 3 ? ["przydatne"] : [],
                source: "Zestaw startowy",
                note: note,
                forms: forms,
                important: i == 0,
                hard: i == 1 || i == 2,
                archived: false,
                created: now - Double(i) * 3_600_000,
                meanings: [Meaning(
                    id: "m\(i)",
                    translation: row.tr,
                    definition: row.def,
                    examples: row.ex.components(separatedBy: "|"),
                    context: row.collection,
                    register: row.reg,
                    natural: row.en == "accomplish" ? "get something done" : "",
                    scores: scores
                )]
            ))
        }
        words[6].meanings.append(Meaning(
            id: "m6b",
            translation: "brzeg rzeki",
            definition: "The land along the side of a river.",
            examples: ["We sat on the river bank.", "Flowers grow along the bank."],
            context: "Natura i krajobraz",
            register: "neutralny"
        ))
        var reviews: [Review] = []
        let perDay = [8, 12, 0, 15, 10, 18, 6]
        for dayIndex in stride(from: 6, through: 0, by: -1) {
            let n = perDay[6 - dayIndex]
            for j in 0..<n {
                let word = words[j % words.count]
                reviews.append(Review(
                    id: "demo-\(dayIndex)-\(j)",
                    wordId: word.id,
                    meaningId: word.meanings[0].id,
                    skill: .recall,
                    correct: j % 9 != 0,
                    at: now - Double(dayIndex) * day - Double(j) * 30_000,
                    seconds: 7,
                    confidence: 2,
                    hint: false,
                    error: j % 9 == 0 ? "Przypominanie" : "",
                    before: 30,
                    after: 40,
                    masteryVersion: nil,
                    demo: true
                ))
            }
        }
        return LearnerState(
            words: words,
            collections: ["Codzienne rozmowy", "W podróży", "W pracy", "Rozmowa o pracę", "U lekarza", "W restauracji"],
            reviews: reviews,
            settings: LearnerSettings(goal: 20, reminder: "19:00", accent: "en-US", slow: false, voiceRevision: 2),
            demo: true
        )
    }

    /// The web v31 export fixture.
    static func fixtureData(_ name: String = "state-v31") throws -> Data {
        guard let url = Bundle.module.url(forResource: name, withExtension: "json", subdirectory: "Fixtures")
            ?? Bundle.module.url(forResource: name, withExtension: "json") else {
            throw XCTSkip("Brak fixture \(name).json")
        }
        return try Data(contentsOf: url)
    }

    /// `ios/FluentNOW/Resources/Content` located relative to this source file.
    static var contentDirectory: URL {
        URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent() // FluentKitTests
            .deletingLastPathComponent() // Tests
            .deletingLastPathComponent() // FluentKit
            .deletingLastPathComponent() // Packages
            .deletingLastPathComponent() // ios
            .appendingPathComponent("FluentNOW/Resources/Content")
    }

    /// Reads a content file of the app; skips the test when the file is not available.
    static func contentData(_ relativePath: String) throws -> Data {
        let url = contentDirectory.appendingPathComponent(relativePath)
        guard FileManager.default.fileExists(atPath: url.path) else {
            throw XCTSkip("Brak pliku treści \(relativePath)")
        }
        return try Data(contentsOf: url)
    }

    /// Practice content built from the app's bank files (skips when unavailable).
    static func practiceContent(levels: [String] = CEFR.levels) throws -> PracticeContent {
        var grammarFiles: [GrammarLevelFile] = []
        for level in levels {
            grammarFiles.append(try ContentDecoder.grammarLevel(from: try contentData("grammar/\(level).json")))
        }
        return PracticeContent(
            grammarFiles: grammarFiles,
            exercises: try ContentDecoder.exercises(from: try contentData("exercises.json")),
            idioms: try ContentDecoder.idioms(from: try contentData("idioms.json")),
            readings: try ContentDecoder.readings(from: try contentData("readings.json"))
        )
    }

    /// Small synthetic practice content that always exists (no files needed).
    static func syntheticContent() -> PracticeContent {
        var grammar: [String: [ProductionItem]] = [:]
        var idioms: [String: [PracticeQuestion]] = [:]
        var readings: [Reading] = []
        let rules = ["present simple", "past simple", "present perfect", "future", "passive", "conditional"]
        for level in CEFR.levels {
            grammar[level] = (0..<30).map { index in
                ProductionItem(
                    bankId: "g-\(level)-\(index)",
                    scenarioId: "\(level)-\(index % 7)",
                    context: "Sentence \(level) \(index): they ________ (robić) it every day.",
                    hintPl: "robić",
                    answer: "do\(index)",
                    distractors: [
                        ProductionDistractor(form: "does\(index)", diagnosis: .wrongAgreement, explanation: "Zła osoba."),
                        ProductionDistractor(form: "did\(index)", diagnosis: .wrongTense, explanation: "Zły czas."),
                        ProductionDistractor(form: "doing\(index)", diagnosis: .wrongWord, explanation: "Zła forma.")
                    ],
                    rule: rules[index % rules.count],
                    explanation: "Wyjaśnienie \(index).",
                    translation: "Tłumaczenie \(index)."
                )
            }
            idioms[level] = (0..<18).map { index in
                PracticeQuestion(
                    bankId: "idiom-\(level)-\(index)",
                    category: .idiom,
                    prompt: "Co oznacza idiom \(index)?",
                    context: "Context \(level) \(index).",
                    options: ["Znaczenie \(index)", "Inne A", "Inne B", "Inne C"],
                    answer: 0,
                    explanation: "Wyjaśnienie.",
                    translation: "Tłumaczenie."
                )
            }
            for index in 0..<5 {
                readings.append(Reading(
                    id: "reading-\(level)-\(index)",
                    title: "Title \(level) \(index)",
                    level: level,
                    paragraphs: ["Paragraph of reading \(index)."],
                    questions: (0..<4).map { q in
                        ReadingQuestion(question: "Q\(q)?", options: ["A\(q)", "B\(q)", "C\(q)", "D\(q)"], answer: q % 4, explanation: "E", evidence: "Paragraph")
                    },
                    topic: index == 2 ? "lotnisko podróż airport" : ""
                ))
            }
        }
        return PracticeContent(
            grammar: ProductionBank(version: 36, levels: grammar),
            exercises: ProductionBank(),
            idioms: IdiomBank(levels: idioms),
            readings: ReadingBank(readings: readings)
        )
    }
}

extension LearnerState {
    /// Test helper: first word with the given English text.
    func word(en: String) -> Word? {
        words.first { $0.en == en }
    }
}
