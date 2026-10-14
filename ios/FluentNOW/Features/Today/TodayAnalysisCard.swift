import SwiftUI
import FluentKit

/// Zwięzła analiza na ekranie Dzisiaj: szacowany poziom z pewnością, tempo i mocna/słaba strona.
/// Pełna analiza jest w „Postępach” (`StatsAnalysisSection`). Dane liczone w tle (`TodaySnapshot`).
struct TodayAnalysisCard: View {
    let analysis: LearnerAnalysis

    @Environment(AppRouter.self) private var router

    var body: some View {
        if analysis.hasData {
            Card {
                TodayAnalysisHeader(level: analysis.level)
                TodayAnalysisLine(systemImage: "speedometer", text: analysis.pace.summaryPl)
                if let skills = analysis.skillsSummaryPl {
                    TodayAnalysisLine(systemImage: "chart.bar", text: skills)
                }
                Button {
                    router.select(.progress)
                } label: {
                    UsefulWordsMoreLabel(title: "Pełna analiza w Postępach")
                }
                .buttonStyle(.plain)
            }
        }
    }
}

/// Poziom + opis pewności.
private struct TodayAnalysisHeader: View {
    let level: LevelAssessment

    var body: some View {
        HStack(alignment: .center, spacing: Spacing.s) {
            Text(level.rangeText)
                .font(FluentFont.numberMedium)
                .foregroundStyle(Palette.ink)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
            VStack(alignment: .leading, spacing: 2) {
                Text("Twój poziom (szacunek)")
                    .font(FluentFont.headline)
                    .foregroundStyle(Palette.ink)
                Text(AnalysisDisplayText.capitalized(level.confidence.namePl))
                    .font(FluentFont.footnote)
                    .foregroundStyle(Palette.inkSecondary)
            }
            Spacer(minLength: 0)
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel(Text("Szacowany poziom \(level.rangeText), \(level.confidence.namePl)"))
    }
}

/// Jedna linia analizy z ikoną.
private struct TodayAnalysisLine: View {
    let systemImage: String
    let text: String

    var body: some View {
        Label {
            Text(AnalysisDisplayText.capitalized(text))
                .font(FluentFont.subheadline)
                .foregroundStyle(Palette.ink)
                .fixedSize(horizontal: false, vertical: true)
        } icon: {
            Image(systemName: systemImage)
                .foregroundStyle(Palette.accent)
        }
    }
}

/// Teksty analizy na ekranach (obszar recommendations).
enum AnalysisDisplayText {
    /// Pierwsza litera wielka („wysoka pewność” → „Wysoka pewność”).
    static func capitalized(_ text: String) -> String {
        guard let head = text.first else { return text }
        return head.uppercased() + String(text.dropFirst())
    }
}
