import SwiftUI
import FluentKit

/// Wynik testu: wynik %, szacowany poziom (z uczciwym opisem), wynik per typ zadania i per
/// umiejętność, lista błędów z poprawnymi odpowiedziami, akcje na słowach.
struct TestResultView: View {
    let model: TestSessionModel
    let onClose: () -> Void

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Spacing.l) {
                if let result = model.result {
                    TestResultHero(result: result, baseLevel: model.session?.baseLevel ?? "")
                    TestResultActions(model: model)
                    TestScoreList(title: "Typy zadań", rows: blockRows(result))
                    TestScoreList(title: "Umiejętności", rows: skillRows(result))
                    TestMistakesList(mistakes: result.mistakes)
                } else {
                    LoadingStateView("Liczę wynik…")
                }
                PrimaryButton("Zakończ", systemImage: "checkmark") {
                    model.dismissResult()
                    onClose()
                }
                Text("Wynik zapisaliśmy w Postępach (historia testów).")
                    .font(FluentFont.caption)
                    .foregroundStyle(Palette.inkSecondary)
                    .frame(maxWidth: .infinity)
            }
            .frame(maxWidth: Spacing.readableWidth)
            .frame(maxWidth: .infinity)
            .padding(.horizontal, Spacing.screen)
            .padding(.vertical, Spacing.m)
        }
    }

    private func blockRows(_ result: AssessmentResult) -> [TestScoreRow] {
        result.blocks.map { (item: AssessmentBlockScore) -> TestScoreRow in
            TestScoreRow(id: item.id, title: item.block.namePl, score: item.score)
        }
    }

    private func skillRows(_ result: AssessmentResult) -> [TestScoreRow] {
        result.skills.map { (item: AssessmentSkillScore) -> TestScoreRow in
            TestScoreRow(id: item.id, title: item.skill.namePl, score: item.score)
        }
    }
}

/// Wynik ogólny i poziom.
private struct TestResultHero: View {
    let result: AssessmentResult
    let baseLevel: String

    var body: some View {
        Card(style: .tinted(.accent), spacing: Spacing.m) {
            Text("Twój wynik")
                .fluentEyebrow()
                .foregroundStyle(Palette.inkSecondary)
            HStack(alignment: .firstTextBaseline, spacing: Spacing.m) {
                Text("\(result.overall.percent)%")
                    .font(FluentFont.numberLarge)
                    .foregroundStyle(Palette.ink)
                VStack(alignment: .leading, spacing: Spacing.xxs) {
                    Text("Szacowany poziom: \(result.level.levelText)")
                        .font(FluentFont.headline)
                        .foregroundStyle(Palette.ink)
                    Text("\(result.overall.pointsText) pkt · \(StudyFormat.duration(result.seconds))")
                        .font(FluentFont.footnote)
                        .foregroundStyle(Palette.inkSecondary)
                }
            }
            .accessibilityElement(children: .combine)
            Text(result.level.descriptionPl)
                .font(FluentFont.callout)
                .foregroundStyle(Palette.ink)
                .fixedSize(horizontal: false, vertical: true)
            if !baseLevel.isEmpty {
                Text("Test był dopasowany do poziomu \(baseLevel).")
                    .font(FluentFont.footnote)
                    .foregroundStyle(Palette.inkSecondary)
            }
        }
    }
}

/// „Dodaj błędne słowa do powtórek” / „Dodaj nowe słowa do nauki” i komunikat po akcji.
private struct TestResultActions: View {
    let model: TestSessionModel

    var body: some View {
        let wrongOwned = model.wrongOwnedCount
        let newWords = model.newWordReferences.count
        if wrongOwned > 0 || newWords > 0 || model.actionNotice != nil {
            VStack(alignment: .leading, spacing: Spacing.s) {
                if wrongOwned > 0 && !model.markedWrongWords {
                    SecondaryButton("Dodaj błędne słowa do powtórek (\(wrongOwned))", systemImage: "arrow.clockwise") {
                        model.markWrongWords()
                    }
                    .accessibilityHint(Text("Twoje słowa z błędną odpowiedzią zostaną oznaczone jako trudne."))
                }
                if newWords > 0 && !model.addedNewWords {
                    SecondaryButton("Dodaj nowe słowa do nauki (\(newWords))", systemImage: "plus", isLoading: model.isAddingWords) {
                        Task { @MainActor in
                            await model.addNewWords()
                        }
                    }
                    .accessibilityHint(Text("Słowa z bazy, które sprawiły trudność, trafią do Twojego słownika."))
                }
                if let notice = model.actionNotice {
                    Text(notice)
                        .font(FluentFont.callout)
                        .foregroundStyle(Palette.inkSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
        }
    }
}

/// Jeden wiersz wyniku częściowego.
struct TestScoreRow: Identifiable, Hashable {
    let id: String
    let title: String
    let score: AssessmentScore
}

/// Lista wyników częściowych z paskiem.
private struct TestScoreList: View {
    let title: String
    let rows: [TestScoreRow]

    var body: some View {
        if !rows.isEmpty {
            Card(spacing: Spacing.s) {
                SectionHeader(title)
                ForEach(rows) { (row: TestScoreRow) in
                    TestScoreLine(row: row)
                }
            }
        }
    }
}

private struct TestScoreLine: View {
    let row: TestScoreRow

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.xxs) {
            HStack(alignment: .firstTextBaseline) {
                Text(row.title)
                    .font(FluentFont.subheadline)
                    .foregroundStyle(Palette.ink)
                Spacer(minLength: Spacing.xs)
                Text("\(row.score.pointsText) · \(row.score.percent)%")
                    .font(FluentFont.numberSmall)
                    .foregroundStyle(Palette.inkSecondary)
            }
            LinearProgressBar(progress: row.score.ratio, tint: tint)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text(row.title))
        .accessibilityValue(Text("\(row.score.percent) procent"))
    }

    private var tint: Color {
        switch row.score.percent {
        case 80...: return Palette.success
        case 50..<80: return Palette.accent
        default: return Palette.warning
        }
    }
}

/// Błędy z poprawnymi odpowiedziami.
private struct TestMistakesList: View {
    let mistakes: [AssessmentMistake]

    var body: some View {
        Card(spacing: Spacing.s) {
            SectionHeader("Błędy", subtitle: mistakes.isEmpty ? "Bez błędów — świetnie!" : "Poprawne odpowiedzi do zapamiętania")
            ForEach(mistakes) { (mistake: AssessmentMistake) in
                TestMistakeRow(mistake: mistake)
            }
        }
    }
}

private struct TestMistakeRow: View {
    let mistake: AssessmentMistake

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.xxs) {
            HStack(alignment: .firstTextBaseline, spacing: Spacing.xs) {
                Text(mistake.block.namePl)
                    .font(FluentFont.caption)
                    .foregroundStyle(Palette.inkSecondary)
                Spacer(minLength: Spacing.xs)
                if mistake.block.isVocabulary {
                    TagChip(mistake.owned ? "Twoje słowo" : "Z bazy", tone: mistake.owned ? .accent : .neutral)
                }
            }
            if !mistake.prompt.isEmpty {
                Text(mistake.prompt)
                    .font(FluentFont.callout)
                    .foregroundStyle(Palette.ink)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Text("Poprawnie: **\(VocabFeedbackSummary.escaped(mistake.expected))**")
                .font(FluentFont.callout)
                .foregroundStyle(Palette.success)
                .fixedSize(horizontal: false, vertical: true)
            Text("Twoja odpowiedź: \(mistake.given)")
                .font(FluentFont.footnote)
                .foregroundStyle(Palette.inkSecondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(.vertical, Spacing.xxs)
        .accessibilityElement(children: .combine)
    }
}
