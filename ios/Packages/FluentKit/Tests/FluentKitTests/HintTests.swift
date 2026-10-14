import Foundation
import XCTest
@testable import FluentKit

/// Graded hints (FEEDBACK-1 F2): hints guide without giving the answer away.
final class HintTests: XCTestCase {

    // MARK: Helpers

    private func word(
        en: String,
        translation: String,
        pos: String = "rzeczownik",
        definition: String = "",
        context: String = "",
        scene: String? = nil,
        note: String = "",
        forms: String = "",
        examples: [String] = [],
        focus: [String]? = nil,
        acceptedAnswers: [String]? = nil
    ) -> Word {
        Word(
            id: "w",
            en: en,
            pos: pos,
            level: "A2",
            collection: "Test",
            note: note,
            forms: forms,
            created: 1,
            meanings: [Meaning(
                id: "m",
                scene: scene,
                exampleFocusEn: focus,
                acceptedAnswers: acceptedAnswers,
                pos: pos,
                translation: translation,
                definition: definition,
                examples: examples,
                context: context
            )]
        )
    }

    /// Letters and digits shown in a letter mask.
    private func shownLetters(_ text: String) -> Int {
        text.replacingOccurrences(of: "Pierwsze litery:", with: "")
            .replacingOccurrences(of: "Długość:", with: "")
            .filter { $0.isLetter || $0.isNumber }.count
    }

    private func letterCap(_ answer: String) -> Int {
        let letters = answer.filter { $0.isLetter || $0.isNumber }.count
        return letters >= 3 ? max(1, letters / 3) : 0
    }

    // MARK: Letter masks

    func testLetterMaskShowsFirstLettersAndAtMostAThird() {
        XCTAssertEqual(HintBuilder.letterMask("borrow"), "b _ _ _ _ _")
        XCTAssertEqual(HintBuilder.letterMask("get the hang of"), "g _ _   t _ _   h _ _ _   o _")
        XCTAssertEqual(HintBuilder.letterMask("bus"), "b _ _")
        XCTAssertEqual(HintBuilder.letterMask("am"), "_ _", "two letters: nothing shown")
        XCTAssertEqual(HintBuilder.letterMask("check-in"), "c _ _ _ _ - _ _")
        XCTAssertEqual(HintBuilder.letterMask("a lot"), "_   l _ _", "one-letter words stay hidden")
        let long = "not my cup of tea"
        XCTAssertLessThanOrEqual(shownLetters(HintBuilder.letterMask(long)), letterCap(long))
    }

    // MARK: Masking

    func testMaskHidesAnswerAndInflectedForms() {
        let masked = HintBuilder.mask("To borrow money; she borrowed it and is borrowing more.", answers: ["borrow"])
        XCTAssertEqual(masked, "To ___ money; she ___ it and is ___ more.")
        XCTAssertFalse(HintBuilder.reveals(masked, answers: ["borrow", "borrowed", "borrowing"]))
        // Polish inflection and compounds.
        XCTAssertEqual(HintBuilder.mask("Kolejka do odprawy przed lotem", answers: ["odprawa"]), "Kolejka do ___ przed lotem")
        XCTAssertEqual(HintBuilder.mask("To clean your teeth with a toothbrush.", answers: ["brush"]), "To clean your teeth with a ___.")
        // Unrelated short words are not touched.
        XCTAssertEqual(HintBuilder.mask("Go to the gate.", answers: ["gas"]), "Go to the gate.")
    }

    func testRevealsComparesFoldedWholeWords() {
        XCTAssertTrue(HintBuilder.reveals("Online CHECK-IN closes early.", answers: ["check in"]))
        XCTAssertTrue(HintBuilder.reveals("Załapać to trudne", answers: ["załapać"]))
        XCTAssertTrue(HintBuilder.reveals("zalapac", answers: ["załapać"]), "diacritics are folded")
        XCTAssertTrue(HintBuilder.reveals("I don’t know", answers: ["don't"]), "typographic apostrophe")
        XCTAssertFalse(HintBuilder.reveals("Checking the list", answers: ["check in"]))
        XCTAssertFalse(HintBuilder.reveals("b _ _ _ _ _", answers: ["borrow"]))
    }

    func testFormsFromContentAreParsed() {
        XCTAssertEqual(HintBuilder.formVariants("checks in – checked in – checked in"), ["checks in", "checked in", "checked in"])
        XCTAssertEqual(HintBuilder.formVariants("drew; drawn; drawing"), ["drew", "drawn", "drawing"])
        XCTAssertEqual(HintBuilder.formVariants("(niepoliczalny) a piece of luggage"), ["a piece of luggage"])
        XCTAssertEqual(HintBuilder.formVariants("burned/burnt"), ["burned", "burnt"])
        XCTAssertEqual(HintBuilder.formVariants(""), [])
    }

    // MARK: Vocabulary hints

    func testVocabularyHintsAreGradedAndNeverUseTheNote() {
        let item = word(
            en: "check in",
            translation: "odprawić się",
            pos: "czasownik frazowy",
            definition: "To show your ticket and give your bags to the airline before you check in.",
            scene: "Stanowisko odprawy w hali odlotów",
            note: "Rzeczownik: „check-in” (odprawa).",
            forms: "checks in – checked in – checked in",
            examples: ["We checked in online.", "Check in at the desk."],
            focus: ["checked in", "Check in"]
        )
        let meaning = item.meanings[0]
        for type in [ExerciseType.recall, .cloze, .dictation] {
            let hints = HintBuilder.vocabularyHints(word: item, meaning: meaning, type: type, exampleIndex: 0)
            XCTAssertEqual(hints.count, 2, "\(type)")
            XCTAssertEqual(hints.visible(upTo: 1).count, 1)
            XCTAssertEqual(hints.visible(upTo: 2).count, 2)
            let first = hints.levels[0]
            XCTAssertTrue(first.contains("Część mowy: czasownik frazowy."), first)
            XCTAssertTrue(first.contains("Liczba słów: 2."), first)
            XCTAssertTrue(first.contains("Angielska definicja:"), first)
            XCTAssertFalse(first.contains("Rzeczownik"), "the note is never part of a hint")
            for level in hints.levels {
                XCTAssertFalse(HintBuilder.reveals(level, answers: ["check in", "checked in", "checks in", "check-in"]), level)
            }
            XCTAssertTrue(hints.levels[1].hasPrefix("Pierwsze litery: "), hints.levels[1])
        }
        let cloze = HintBuilder.vocabularyHints(word: item, meaning: meaning, type: .cloze, exampleIndex: 0)
        XCTAssertEqual(cloze.levels[1], "Pierwsze litery: c _ _ _ _ _ _   i _", "the form from the sentence (checked in)")
        let recall = HintBuilder.vocabularyHints(word: item, meaning: meaning, type: .recall, exampleIndex: 0)
        XCTAssertEqual(recall.levels[1], "Pierwsze litery: c _ _ _ _   i _")
        XCTAssertTrue(HintBuilder.vocabularyHints(word: item, meaning: meaning, type: .flashcard, exampleIndex: 0).levels.isEmpty)
    }

    func testMeaningHintsMaskPolishAnswersInContext() {
        let item = word(
            en: "check-in",
            translation: "odprawa",
            definition: "The process of showing your ticket before a flight.",
            context: "Odprawa przed lotem"
        )
        let hints = HintBuilder.vocabularyHints(word: item, meaning: item.meanings[0], type: .meaning, exampleIndex: 0)
        XCTAssertTrue(hints.levels[0].contains("Sytuacja: ___ przed lotem"), hints.levels[0])
        XCTAssertEqual(hints.levels[1], "Pierwsze litery: o _ _ _ _ _ _")
        for level in hints.levels {
            XCTAssertFalse(HintBuilder.reveals(level, answers: ["odprawa"]), level)
        }
    }

    func testLettersThatSpellAVariantFallBackToLength() {
        // „a … c …” = „A/C” (akceptowany skrót) — zostaje sama długość.
        let item = word(en: "air conditioning", translation: "klimatyzacja", acceptedAnswers: ["air conditioning", "AC", "A/C"])
        let hints = HintBuilder.vocabularyHints(word: item, meaning: item.meanings[0], type: .recall, exampleIndex: 0)
        XCTAssertEqual(hints.levels[1], "Długość: _ _ _   _ _ _ _ _ _ _ _ _ _ _ _")
        XCTAssertFalse(HintBuilder.reveals(hints.levels[1], answers: ["A/C"]))
        XCTAssertEqual(HintBuilder.formVariants("A/B tests"), ["B tests"], "a single letter is not a form")
    }

    func testDictationLoanwordTranslationIsDropped() {
        let item = word(en: "pizza", translation: "pizza", definition: "An Italian dish of flat bread with cheese.", context: "W pizzerii")
        let hints = HintBuilder.vocabularyHints(word: item, meaning: item.meanings[0], type: .dictation, exampleIndex: 0)
        XCTAssertFalse(hints.levels[0].contains("Znaczenie:"), hints.levels[0])
        for level in hints.levels {
            XCTAssertFalse(HintBuilder.reveals(level, answers: ["pizza"]), level)
        }
    }

    // MARK: Practice hints

    func testProductionHintsUseRuleAndLetters() {
        let item = ProductionItem(
            context: "Last Saturday, we ________ (pakować) the bags.",
            hintPl: "pakować",
            answer: "packed",
            rule: "past simple",
            translation: "W zeszłą sobotę spakowaliśmy torby."
        )
        let question = PracticeBuilder.practiceQuestion(from: item)
        let practice = HintBuilder.practiceHints(question: question)
        XCTAssertTrue(practice.levels[0].contains("Wskazówka: pakować."), practice.levels[0])
        XCTAssertEqual(practice.levels[1], "Pierwsze litery: p _ _ _ _ _")
        let production = HintBuilder.practiceHints(question: question, production: item)
        XCTAssertTrue(production.levels[0].contains("Konstrukcja: past simple."), production.levels[0])
        XCTAssertFalse(production.levels[0].contains("Czasownik:"), "the verb is already in the sentence")
        for level in practice.levels + production.levels {
            XCTAssertFalse(HintBuilder.reveals(level, answers: ["packed"]), level)
        }
    }

    func testIdiomHintMasksTheMeaningInTheTranslation() {
        let question = PracticeQuestion(
            format: .input,
            category: .idiom,
            prompt: "Co oznacza „Break the ice”?",
            context: "The teacher told a funny story to break the ice.",
            options: ["Przełamać pierwsze lody", "Czuć się niewyraźnie"],
            answer: 0,
            explanation: "Humor zmniejszył skrępowanie na początku spotkania.",
            translation: "Nauczyciel opowiedział zabawną historię, aby przełamać pierwsze lody."
        )
        let hints = HintBuilder.practiceHints(question: question)
        XCTAssertTrue(hints.levels[0].contains("aby ___."), hints.levels[0])
        for level in hints.levels {
            XCTAssertFalse(HintBuilder.reveals(level, answers: ["Przełamać pierwsze lody"]), level)
        }
    }

    // MARK: All built-in content

    /// Every entry of `topics/*.json` and `starter-words.json`, every exercise type and example:
    /// no hint level contains an accepted answer (after normalisation) and the letter mask shows
    /// at most a third of the letters.
    func testNoHintRevealsTheAnswerForAnyBuiltInEntry() throws {
        let variants = try ContentDecoder.answerVariants(from: try TestData.contentData("answer-variants.json"))
        var sources: [(file: String, scene: String, entry: TopicEntry)] = []
        let topicsURL = TestData.contentDirectory.appendingPathComponent("topics")
        let names = (try? FileManager.default.contentsOfDirectory(atPath: topicsURL.path)) ?? []
        let topicNames = names.filter { $0.hasSuffix(".json") && $0 != "index.json" }.sorted()
        guard !topicNames.isEmpty else { throw XCTSkip("Brak plików tematów") }
        for name in topicNames {
            let topic = try ContentDecoder.topicFile(from: try TestData.contentData("topics/\(name)"))
            for category in topic.categories {
                for entry in category.entries {
                    sources.append((name, category.scenePl, entry))
                }
            }
        }
        let starter = try ContentDecoder.starterWords(from: try TestData.contentData("starter-words.json"))
        for entry in starter.words {
            sources.append(("starter-words.json", "", entry))
        }

        var failures: [String] = []
        var checked = 0
        for source in sources {
            guard var item = VocabularyMerger.starterWords([source.entry]).first, var meaning = item.meanings.first else {
                failures.append("\(source.file): \(source.entry.id) — brak znaczenia")
                continue
            }
            meaning.scene = source.scene.isEmpty ? nil : source.scene
            item.meanings = [meaning]
            var tasks: [(ExerciseType, Int)] = [(.recall, 0), (.meaning, 0), (.dictation, 0)]
            for index in meaning.examples.indices {
                tasks.append((.cloze, index))
            }
            for (type, index) in tasks {
                let hints = HintBuilder.vocabularyHints(word: item, meaning: meaning, type: type, exampleIndex: index, variants: variants)
                let answers = checkAnswers(word: item, meaning: meaning, type: type, exampleIndex: index, variants: variants)
                checked += 1
                if hints.count != 2 {
                    failures.append("\(source.file): \(source.entry.id) \(type) — \(hints.count) poziomów")
                }
                for (number, level) in hints.levels.enumerated() where HintBuilder.reveals(level, answers: answers) {
                    failures.append("\(source.file): \(source.entry.id) \(type) poziom \(number + 1): \(level)")
                }
                if let letters = hints.levels.last, hints.count == 2 {
                    let primary = HintBuilder.primaryVocabularyAnswer(word: item, meaning: meaning, type: type, exampleIndex: index)
                    if shownLetters(letters) > letterCap(primary) {
                        failures.append("\(source.file): \(source.entry.id) \(type) — za dużo liter: \(letters)")
                    }
                }
            }
        }
        XCTAssertGreaterThan(checked, 1_000)
        XCTAssertTrue(failures.isEmpty, "\(failures.count) problemów, np.:\n" + failures.prefix(20).joined(separator: "\n"))
    }

    /// Every grammar / exercises item (as a practice question and as a production task) and every
    /// idiom: no hint level contains the key or an accepted answer.
    func testNoHintRevealsTheAnswerForAnyBankItem() throws {
        let content = try TestData.practiceContent()
        var failures: [String] = []
        var checked = 0
        for level in CEFR.levels {
            let items = content.exercises.items(level: level) + content.grammar.items(level: level)
            for item in items {
                let answers = [item.answer] + item.acceptedAnswers
                let practice = PracticeBuilder.practiceQuestion(from: item)
                let combined = PracticeQuestion(
                    format: .input,
                    inputHint: item.rule,
                    acceptedAnswers: item.acceptedAnswers,
                    category: .grammar,
                    prompt: "Uzupełnij zdanie właściwą formą czasownika.",
                    context: item.context,
                    options: Array(([item.answer] + item.distractors.map { $0.form }).prefix(4)),
                    answer: 0,
                    explanation: item.explanation,
                    translation: item.translation
                )
                let sets = [
                    HintBuilder.practiceHints(question: practice),
                    HintBuilder.practiceHints(question: combined, production: item)
                ]
                for hints in sets {
                    checked += 1
                    for hint in hints.levels where HintBuilder.reveals(hint, answers: answers) {
                        failures.append("\(item.bankId ?? item.context): \(hint)")
                    }
                    if let letters = hints.levels.last, shownLetters(letters) > letterCap(item.answer) {
                        failures.append("\(item.bankId ?? item.context) — za dużo liter: \(letters)")
                    }
                }
            }
            for question in content.idioms.items(level: level) {
                checked += 1
                let answers = [question.correctOption] + (question.acceptedAnswers ?? [])
                for hint in HintBuilder.practiceHints(question: question).levels where HintBuilder.reveals(hint, answers: answers) {
                    failures.append("\(question.bankId ?? question.prompt): \(hint)")
                }
            }
        }
        XCTAssertGreaterThanOrEqual(checked, 3_600)
        XCTAssertTrue(failures.isEmpty, "\(failures.count) problemów, np.:\n" + failures.prefix(20).joined(separator: "\n"))
    }

    /// Independent list of what must not leak: what the grader accepts for this exercise,
    /// the term, the form in the sentence and the forms listed in the content.
    private func checkAnswers(word: Word, meaning: Meaning, type: ExerciseType, exampleIndex: Int, variants: AnswerVariants) -> [String] {
        let task = VocabTask(wordId: word.id, meaningId: meaning.id, type: type, example: exampleIndex)
        let grading = VocabularyGrader.gradingWord(word: word, meaning: meaning, task: task)
        if type == .meaning {
            return VocabularyGrader.vocabularyAnswers(word: grading, meaning: meaning, type: .meaning, variants: variants)
        }
        var answers = [word.en, grading.en]
        answers += VocabularyGrader.vocabularyAnswers(word: grading, meaning: meaning, type: type, variants: variants)
        answers += VocabularyGrader.vocabularyAnswers(word: word, meaning: meaning, type: .recall, variants: variants)
        answers += HintBuilder.formVariants(word.forms)
        return answers
    }
}
