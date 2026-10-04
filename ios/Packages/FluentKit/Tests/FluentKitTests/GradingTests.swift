import XCTest
@testable import FluentKit

final class GradingTests: XCTestCase {
    private func grade(_ answer: String, _ en: String, _ translation: String, type: ExerciseType = .meaning, accepted: [String]? = nil, acceptedTranslations: [String]? = nil, pos: String = "czasownik") -> GradeVerdict {
        let word = Word(id: "w", en: en, pos: pos, collection: "c", created: 0, meanings: [])
        let meaning = Meaning(id: "m", acceptedAnswers: accepted, acceptedTranslations: acceptedTranslations, translation: translation)
        return VocabularyGrader.localGrade(answer: answer, word: word, meaning: meaning, type: type).verdict
    }

    func testNormalizers() {
        XCTAssertEqual(TextNormalizer.normalize("  Hello,   World! "), "hello world")
        XCTAssertEqual(TextNormalizer.answerKey("POŻYCZYĆ  KOMUŚ!"), "pozyczyc komus")
        XCTAssertEqual(TextNormalizer.answerKey("Łódź’s"), "lodz's")
        XCTAssertEqual(TextNormalizer.answerKey("rachunek (AmE)"), "rachunek")
        XCTAssertEqual(TextNormalizer.withoutDialectLabel("rachunek (AmE)"), "rachunek")
        XCTAssertEqual(TextNormalizer.withoutDialectLabel("brać na wynos (BrE)"), "brać na wynos")
        XCTAssertEqual(TextNormalizer.withoutDialectLabel("zamek (w drzwiach)"), "zamek (w drzwiach)")
        XCTAssertEqual(TextNormalizer.englishAnswerKey("I don't know."), "i do not know")
        XCTAssertEqual(TextNormalizer.englishAnswerKey("We won't go"), "we will not go")
        XCTAssertEqual(TextNormalizer.englishAnswerKey("can't swim"), "cannot swim")
        XCTAssertEqual(TextNormalizer.englishAnswerKey("They're reading"), "they are reading")
        XCTAssertEqual(TextNormalizer.englishAnswerKey("She's"), "she's")
        XCTAssertEqual(TextNormalizer.searchKey("  À la   Carte ’n "), "a la carte 'n")
    }

    func testLevenshtein() {
        XCTAssertEqual(TextNormalizer.levenshtein("kitten", "sitting"), 3)
        XCTAssertEqual(TextNormalizer.levenshtein("", "abc"), 3)
        XCTAssertEqual(TextNormalizer.levenshtein("abc", ""), 3)
        XCTAssertEqual(TextNormalizer.levenshtein("pożyczyć", "pozyczyc"), 2)
        XCTAssertEqual(TextNormalizer.boundedLevenshtein(Array("boarding".utf8), Array("bording".utf8), limit: 2), 1)
        XCTAssertNil(TextNormalizer.boundedLevenshtein(Array("abc".utf8), Array("xyz".utf8), limit: 2))
    }

    func testLendAcceptsDirectionalVariantsOnly() {
        let seed = TestData.seed()
        guard let lend = seed.word(en: "lend") else { return XCTFail("missing lend") }
        let meaning = lend.meanings[0]
        func verdict(_ answer: String, _ type: ExerciseType, _ m: Meaning? = nil) -> GradeVerdict {
            VocabularyGrader.localGrade(answer: answer, word: lend, meaning: m ?? meaning, type: type).verdict
        }
        XCTAssertEqual(verdict("lend someone", .recall), .correct)
        XCTAssertEqual(verdict("to lend somebody", .recall), .correct)
        XCTAssertEqual(verdict("borrow from someone", .recall), .incorrect)
        XCTAssertNotEqual(verdict("never lend someone", .recall), .correct)
        XCTAssertEqual(verdict("lend someone", .cloze), .incorrect)
        XCTAssertEqual(verdict("to lend", .cloze), .incorrect)
        XCTAssertEqual(verdict("to lend", .dictation), .incorrect)
        XCTAssertEqual(verdict("lend", .dictation), .correct)
        var other = meaning
        other.translation = "nadawać wsparcie"
        XCTAssertEqual(verdict("lend someone", .recall, other), .incorrect)
        let swapped = VocabularyGrader.localGrade(answer: "borrow", word: lend, meaning: meaning, type: .recall)
        XCTAssertTrue(swapped.explanation.contains("Lend oznacza"))
        XCTAssertNil(swapped.closestAnswer)
    }

    func testTyposAreNotAcceptedButSuggested() {
        let seed = TestData.seed()
        guard let lend = seed.word(en: "lend") else { return XCTFail("missing lend") }
        let recall = VocabularyGrader.localGrade(answer: "lnd", word: lend, meaning: lend.meanings[0], type: .recall)
        let dictation = VocabularyGrader.localGrade(answer: "lnd", word: lend, meaning: lend.meanings[0], type: .dictation)
        XCTAssertEqual(recall.verdict, .incorrect)
        XCTAssertFalse(recall.spellingCorrect)
        XCTAssertEqual(recall.closestAnswer, "lend")
        XCTAssertEqual(dictation.verdict, .incorrect)
        XCTAssertFalse(dictation.spellingCorrect)
        XCTAssertTrue(recall.isFailure)
        XCTAssertFalse(Grade(verdict: .uncertain, explanation: "", spellingCorrect: true).isFailure)
        let gate = TestData.freshWord("gate", "gate", "bramka; wyjście")
        XCTAssertEqual(VocabularyGrader.localGrade(answer: "wyjście", word: gate, meaning: gate.meanings[0], type: .meaning).verdict, .correct)
        XCTAssertFalse(VocabularyGrader.localGrade(answer: "bramk", word: gate, meaning: gate.meanings[0], type: .meaning).spellingCorrect)
    }

    func testSavedAlternativesAndDiacritics() {
        let accepted = ["lend someone", "lend somebody"]
        for answer in ["pozyczyc komus", "POŻYCZYĆ  KOMUŚ!", "uzyczyc"] {
            XCTAssertEqual(grade(answer, "lend", "pożyczyć komuś; użyczyć", accepted: accepted), .correct, answer)
        }
        for answer in ["pozyczy", "pożyczyć od kogoś", "pozyczyc komus cos"] {
            XCTAssertEqual(grade(answer, "lend", "pożyczyć komuś; użyczyć", accepted: accepted), .incorrect, answer)
        }
        XCTAssertEqual(grade("lend somebody", "lend", "pożyczyć komuś; użyczyć", type: .recall, accepted: accepted), .correct)
        XCTAssertEqual(grade("lending somebody", "lend", "pożyczyć komuś; użyczyć", type: .recall, accepted: accepted), .incorrect)
        XCTAssertEqual(grade("lent", "lent", "x", type: .cloze), .correct)
        XCTAssertEqual(grade("lend", "lent", "x", type: .cloze), .incorrect)
        XCTAssertEqual(grade("", "lend", "x", type: .recall), .incorrect)
    }

    func testReviewedPolishEquivalentsPreserveSense() {
        let cases: [(String, String, [String], [String])] = [
            ("borrow", "pożyczyć od kogoś", ["pożyczać", "pozyczac", "wypożyczyć", " POŻYCZYĆ. "], ["pożyczyć komuś", "oddać", "nie pożyczać"]),
            ("lend", "pożyczyć komuś", ["pożyczać", "pozyczyc komus", "udzielić pożyczki"], ["pożyczyć od kogoś", "zabrać"]),
            ("bank", "brzeg rzeki", ["brzeg", "brzeg rzeczny"], ["bank finansowy", "instytucja finansowa"]),
            ("bank", "bank", ["instytucja finansowa", "bank finansowy"], ["brzeg", "brzeg rzeki"]),
            ("recommend", "polecać", ["polecić", "rekomendowac", "zalecać"], ["odradzać", "nie polecać"]),
            ("boarding pass", "karta pokładowa", ["bilet pokładowy", "KARTA POKLADOWA!"], ["paszport", "bilet lotniczy"]),
            ("deadline", "termin wykonania", ["ostateczny termin", "termin"], ["rezerwacja", "termin rozpoczęcia"]),
            ("check", "rachunek (AmE)", ["rachunek", "rachunek do zaplaty"], ["sprawdzić", "paragon"]),
            ("check", "sprawdzić", ["sprawdzać", "skontrolować"], ["rachunek", "rachunek do zapłaty"]),
            ("receipt", "paragon", ["pokwitowanie", "potwierdzenie zaplaty"], ["rachunek", "menu"]),
            ("appointment", "umówiona wizyta", ["wizyta", "termin wizyty"], ["umówione spotkanie", "rezerwacja"]),
            ("turn down", "odrzucić", ["odmówić", "odrzucać"], ["ściszyć", "zmniejszyć głośność"]),
            ("turn down", "ściszyć", ["zmniejszyć głośność", "ściszać"], ["odmówić", "odrzucić"]),
            ("look after", "opiekować się", ["dbać o", "zaopiekowac sie"], ["szukać", "patrzeć za"]),
            ("take your time", "nie spiesz się", ["nie śpiesz się", "bez pospiechu"], ["spiesz się", "spokojnie idź"]),
            ("get the hang of", "załapać, jak to działa", ["nabrać wprawy", "opanować"], ["bardzo rzadko", "odpuścić"]),
            ("do", "czasownik pomocniczy w pytaniach", ["czasownik pomocniczy w pytaniach"], ["zrobić", "wystarczyć"])
        ]
        for (en, translation, yes, no) in cases {
            for answer in yes { XCTAssertEqual(grade(answer, en, translation), .correct, "\(en)/\(translation): \(answer)") }
            for answer in no { XCTAssertEqual(grade(answer, en, translation), .incorrect, "\(en)/\(translation): \(answer)") }
        }
        XCTAssertEqual(grade("SKRUPULATNY.", "meticulous", "niezwykle staranny", acceptedTranslations: ["skrupulatny", "bardzo dokładny"]), .correct)
        XCTAssertEqual(grade("meticulous", "meticulous", "niezwykle staranny", acceptedTranslations: ["skrupulatny"]), .incorrect)
    }

    func testAspectPairsWithoutGuessing() {
        let pairs: [(String, String, String)] = [("buy", "kupić", "kupować"), ("sell", "sprzedawać", "sprzedać"), ("pay", "zapłacić", "płacić"), ("forget", "zapomnieć", "zapominać"), ("learn", "uczyć się", "nauczyć się"), ("leave", "wyjść", "wychodzić"), ("clean", "posprzątać", "sprzątać"), ("bake", "upiec", "piec"), ("refuse", "odmówić", "odmawiać"), ("agree", "zgodzić się", "zgadzać się")]
        for (en, base, variant) in pairs {
            XCTAssertEqual(grade(variant, en, base), .correct, en)
            XCTAssertEqual(grade("nie " + variant, en, base), .incorrect, en)
        }
        XCTAssertEqual(grade("pamiętać", "forget", "zapomnieć"), .incorrect)
        XCTAssertEqual(grade("uczyć", "learn", "uczyć się"), .incorrect)
    }

    func testVariantsFromContentFileMatchBuiltIn() throws {
        let decoded = try ContentDecoder.answerVariants(from: try TestData.contentData("answer-variants.json"))
        XCTAssertEqual(decoded.polishSenseVariants, AnswerVariants.builtIn.polishSenseVariants)
        XCTAssertEqual(decoded.polishAspectPairs, AnswerVariants.builtIn.polishAspectPairs)
        XCTAssertEqual(decoded.englishAliases, AnswerVariants.builtIn.englishAliases)
    }

    func testGradingWordForCloze() {
        let word = TestData.freshWord("b", "borrow", "pożyczyć", example: "I borrowed your pen.")
        let target = VocabularyGrader.gradingWord(word: word, meaning: word.meanings[0], task: VocabTask(wordId: "b", meaningId: "m-b", type: .cloze, example: 0))
        XCTAssertEqual(target.en, "borrowed")
        XCTAssertEqual(VocabularyGrader.localGrade(answer: "Borrowed", word: target, meaning: word.meanings[0], type: .cloze).verdict, .correct)
    }

    func testExamplePair() {
        var meaning = Meaning(id: "m", translation: "karta pokładowa", examples: ["Show your boarding pass."])
        let word = Word(id: "w", en: "boarding pass", collection: "c", created: 0)
        XCTAssertNil(VocabularyGrader.examplePair(word: word, meaning: meaning, index: 0))
        meaning.exampleTranslations = ["Pokaż kartę pokładową."]
        meaning.exampleFocusPl = ["kartę pokładową"]
        let pair = VocabularyGrader.examplePair(word: word, meaning: meaning, index: 0)
        XCTAssertEqual(pair?.focusEn, "boarding pass")
        XCTAssertEqual(pair?.focusPl, "kartę pokładową")
        XCTAssertNil(VocabularyGrader.examplePair(word: word, meaning: meaning, index: 5))
    }

    // MARK: Production

    private func item(_ answer: String, rule: String, context: String, distractors: [ProductionDistractor] = [], accepted: [String] = []) -> ProductionItem {
        ProductionItem(context: context, hintPl: "x", answer: answer, acceptedAnswers: accepted, distractors: distractors, rule: rule, explanation: "Wyjaśnienie.")
    }

    func testProductionContractions() {
        let base = item("had been flying", rule: "past perfect continuous", context: "They ________ (latać) continuously for three hours when the storm hit.")
        XCTAssertEqual(ProductionGrader.normalize("didn't", item: base), "did not")
        XCTAssertEqual(ProductionGrader.normalize("they'd called", item: item("had called", rule: "third conditional", context: "If they ________ (zadzwonić) yesterday, we would have come.")), "had called")
        XCTAssertEqual(ProductionGrader.normalize("I'd help", item: item("would help", rule: "second conditional", context: "If you asked, I ________ (pomóc).")), "would help")
        XCTAssertEqual(ProductionGrader.normalize("she's studying", item: item("is studying", rule: "present continuous", context: "She ________ (uczyć się) now.")), "is studying")
        XCTAssertEqual(ProductionGrader.normalize("she's studied", item: item("has studied", rule: "present perfect", context: "She ________ (uczyć się) today.")), "has studied")
    }

    func testProductionGradingOrder() {
        let flying = item(
            "had been flying",
            rule: "past perfect continuous",
            context: "They ________ (latać) continuously for three hours when the storm hit.",
            distractors: [
                ProductionDistractor(form: "have been flying", diagnosis: .wrongTense, explanation: "Have been flying odnosi trwanie do teraz."),
                ProductionDistractor(form: "flew", diagnosis: .wrongAspect, explanation: "Flew nie pokazuje trwania.")
            ]
        )
        XCTAssertTrue(ProductionGrader.grade("had been flying", item: flying).correct)
        XCTAssertTrue(ProductionGrader.grade("They’d been flying!", item: flying).correct)
        let typo = ProductionGrader.grade("had been flyng", item: flying)
        XCTAssertTrue(typo.correct)
        XCTAssertFalse(typo.spellingCorrect)
        XCTAssertEqual(typo.diagnosis, .spelling)
        let aspect = ProductionGrader.grade("flew", item: flying)
        XCTAssertFalse(aspect.correct)
        XCTAssertEqual(aspect.diagnosis, .wrongAspect)
        XCTAssertEqual(aspect.explanation, "Flew nie pokazuje trwania.")
        XCTAssertEqual(ProductionGrader.grade("have been flying", item: flying).diagnosis, .wrongTense)
        let near = item("is flying", rule: "present continuous", context: "Look, the bird ________ (latać) now.", distractors: [ProductionDistractor(form: "was flying", diagnosis: .wrongTense, explanation: "Przeszłość.")])
        XCTAssertFalse(ProductionGrader.grade("was flying", item: near).correct)
        XCTAssertFalse(ProductionGrader.grade("are flying", item: near).correct, "a different auxiliary is grammar, not a typo")
        XCTAssertFalse(ProductionGrader.grade("is not flying", item: near).correct, "negation is never a typo")
        XCTAssertFalse(ProductionGrader.grade("", item: flying).correct)
        XCTAssertEqual(ProductionGrader.grade("completely wrong", item: flying).diagnosis, .general)
    }

    func testCheckPracticeInput() {
        let question = PracticeQuestion(format: .input, category: .grammar, prompt: "p", context: "I ________ him for years.", options: ["have known", "knew", "know", "am knowing"], answer: 0)
        XCTAssertEqual(ProductionGrader.checkPracticeInput(question, value: "have known").choice, 0)
        XCTAssertTrue(ProductionGrader.checkPracticeInput(question, value: "Have known!").correct)
        XCTAssertFalse(ProductionGrader.checkPracticeInput(question, value: "definitely not").correct)
        XCTAssertEqual(ProductionGrader.checkPracticeInput(question, value: "knew").choice, 1)
        XCTAssertFalse(ProductionGrader.checkPracticeInput(question, value: "").correct)
        var withAlternatives = question
        withAlternatives.acceptedAnswers = ["another saved form"]
        XCTAssertTrue(ProductionGrader.checkPracticeInput(withAlternatives, value: "ANOTHER SAVED FORM").correct)
        for (full, short) in [("do not know", "don't know"), ("will not go", "won't go"), ("cannot swim", "can't swim"), ("are reading", "'re reading")] {
            let q = PracticeQuestion(category: .grammar, prompt: "", context: "", options: [full], answer: 0)
            XCTAssertTrue(ProductionGrader.checkPracticeInput(q, value: short).correct, short)
            XCTAssertEqual(ProductionGrader.checkPracticeInput(q, value: full.replacingOccurrences(of: "not ", with: "")).correct, !full.contains("not "))
        }
        let idiom = PracticeQuestion(format: .input, category: .idiom, prompt: "", context: "The exam was a piece of cake.", options: ["coś bardzo łatwego", "x", "y", "z"], answer: 0)
        XCTAssertTrue(ProductionGrader.checkPracticeInput(idiom, value: "bułka z masłem").correct)
        XCTAssertFalse(ProductionGrader.checkPracticeInput(idiom, value: "trudne").correct)
    }

    // MARK: Audio and reading

    func testAudioGapsAndKey() {
        let gap = ExerciseAudio.speechGap
        let question = "If I had time, I ________ (podróżować) more."
        XCTAssertEqual(ExerciseAudio.exerciseAudioText(context: question, solved: false, correctAnswer: "would travel"), "If I had time, I \(gap) more.")
        XCTAssertEqual(ExerciseAudio.exerciseAudioText(context: question, solved: true, correctAnswer: "would travel"), "If I had time, I would travel more.")
        XCTAssertEqual(ExerciseAudio.exerciseAudioText(context: "She broke the ice.", solved: false, correctAnswer: "x"), "She broke the ice.")
        XCTAssertEqual(ExerciseAudio.vocabularyAudioText(example: "Can you lend me a pen?", focus: "lend", hidden: true), "Can you \(gap) me a pen?")
        XCTAssertEqual(ExerciseAudio.vocabularyAudioText(example: "Can you lend me a pen?", focus: "lend", hidden: false), "Can you lend me a pen?")
        XCTAssertEqual(ExerciseAudio.vocabularyAudioText(example: "She borrowed a pen.", focus: "borrowed", hidden: true), "She \(gap) a pen.")
        XCTAssertEqual(ExerciseAudio.vocabularyAudioText(example: "She borrowed a pen.", focus: "lend", hidden: true), "")
        XCTAssertEqual(ExerciseAudio.vocabularyAudioText(example: "She borrowed a pen.", focus: "borrow", hidden: true), "")
        XCTAssertEqual(ExerciseAudio.vocabularyAudioText(example: "Lend, please lend!", focus: "lend", hidden: true), "\(gap), please \(gap)!")
    }

    func testReadingHighlightsWholePhrases() {
        let template = TestData.seed().words[0]
        var bank = template
        bank.id = "bank"
        bank.en = "bank"
        bank.meanings = [Meaning(id: "sense-bank", exampleFocusEn: ["banks"], translation: "bank")]
        var pass = template
        pass.id = "pass"
        pass.en = "boarding pass"
        var hidden = template
        hidden.id = "hidden"
        hidden.en = "passport"
        hidden.archived = true
        let text = "My boarding pass is in the bank; banking apps and banks work. Passport."
        let tokens = ReadingTokenizer.tokens(text: text, words: [bank, pass, hidden])
        XCTAssertEqual(tokens.map { $0.text }.joined(), text)
        XCTAssertEqual(tokens.filter { $0.wordId != nil }.map { $0.text }, ["boarding pass", "bank", "banks"])
        XCTAssertEqual(ReadingTokenizer.tokens(text: "Plain.", words: []), [ReadingToken(text: "Plain.")])
    }
}
