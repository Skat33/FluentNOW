import SwiftUI
import FluentKit

/// Teksty i formatowanie raportu tygodniowego.
enum WeeklyReportFormat {
    static func weekTitle(offset: Int) -> String {
        switch offset {
        case 0: return "Ten tydzień"
        case 1: return "Poprzedni tydzień"
        default: return "\(offset) \(LibraryText.plural(offset, one: "tydzień", few: "tygodnie", many: "tygodni")) temu"
        }
    }

    static func range(_ report: WeeklyReport) -> String {
        let style = Date.FormatStyle.dateTime.day().month(.abbreviated)
        let start = report.start.formatted(style)
        let end = report.lastDay.formatted(style)
        return "\(start) – \(end)"
    }

    /// „+12 względem poprzedniego”, „−3 względem poprzedniego”, „tyle co poprzednio”.
    static func delta(_ current: Int, _ previous: Int) -> String {
        let difference = current - previous
        if difference > 0 { return "+\(difference) względem poprzedniego" }
        if difference < 0 { return "−\(-difference) względem poprzedniego" }
        return "tyle co poprzednio"
    }

    static func percent(_ value: Int?) -> String {
        guard let value else { return "—" }
        return "\(value)%"
    }

    static func level(_ report: WeeklyReport) -> String {
        if report.levelsGained > 0 {
            return "poziom \(report.levelStart.level) → \(report.levelEnd.level)"
        }
        return "poziom \(report.levelEnd.level)"
    }
}

/// Nagłówek: który tydzień, zakres dat, wybór tygodnia i podsumowanie słowne.
struct WeeklyReportHeaderCard: View {
    let report: WeeklyReport
    @Binding var offset: Int
    let availableWeeks: Int

    var body: some View {
        Card(style: .tinted(.accent)) {
            WeeklyReportWeekPicker(report: report, offset: $offset, availableWeeks: availableWeeks)
            Text(report.summaryPl)
                .font(FluentFont.callout)
                .foregroundStyle(Palette.ink)
                .fixedSize(horizontal: false, vertical: true)
        }
    }
}

/// Strzałki „starszy / nowszy tydzień” z tytułem i zakresem dat.
private struct WeeklyReportWeekPicker: View {
    let report: WeeklyReport
    @Binding var offset: Int
    let availableWeeks: Int

    private var canGoBack: Bool { offset + 1 < min(availableWeeks, WeeklyReportBuilder.maxWeeksBack) }
    private var canGoForward: Bool { offset > 0 }

    var body: some View {
        HStack(spacing: Spacing.xs) {
            WeeklyReportArrow(systemImage: "chevron.left", label: "Wcześniejszy tydzień", isEnabled: canGoBack) {
                offset += 1
            }
            VStack(spacing: 2) {
                Text(WeeklyReportFormat.weekTitle(offset: offset))
                    .font(FluentFont.headline)
                    .foregroundStyle(Palette.ink)
                Text(WeeklyReportFormat.range(report) + (report.isCurrentWeek ? " · w toku" : ""))
                    .font(FluentFont.subheadline)
                    .foregroundStyle(Palette.inkSecondary)
            }
            .frame(maxWidth: .infinity)
            .accessibilityElement(children: .combine)
            WeeklyReportArrow(systemImage: "chevron.right", label: "Późniejszy tydzień", isEnabled: canGoForward) {
                offset -= 1
            }
        }
    }
}

private struct WeeklyReportArrow: View {
    let systemImage: String
    let label: String
    let isEnabled: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: systemImage)
                .font(FluentFont.headline)
                .frame(minWidth: HitTarget.minimum, minHeight: HitTarget.minimum)
                .contentShape(Rectangle())
        }
        .buttonStyle(.borderless)
        .foregroundStyle(isEnabled ? Palette.accent : Palette.inkTertiary)
        .disabled(!isEnabled)
        .accessibilityLabel(Text(label))
    }
}

/// Kafelki liczb tygodnia z porównaniem do poprzedniego.
struct WeeklyReportNumbersGrid: View {
    let report: WeeklyReport

    private var current: WeeklyPeriodStats { report.current }
    private var previous: WeeklyPeriodStats { report.previous }

    var body: some View {
        LazyVGrid(columns: [GridItem(.adaptive(minimum: 150), spacing: Spacing.s)], spacing: Spacing.s) {
            StatTile(title: "Odpowiedzi", value: "\(current.answers)", systemImage: "checkmark.circle",
                     caption: WeeklyReportFormat.delta(current.answers, previous.answers))
            StatTile(title: "Skuteczność", value: WeeklyReportFormat.percent(current.accuracy), systemImage: "target",
                     caption: "poprzednio: \(WeeklyReportFormat.percent(previous.accuracy))", tone: .success)
            StatTile(title: "Czas nauki (szacunek)", value: "\(current.studyMinutes) min", systemImage: "clock",
                     caption: "poprzednio: \(previous.studyMinutes) min", tone: .info)
            StatTile(title: "Aktywne dni", value: "\(current.activeDays) z \(report.elapsedDays)", systemImage: "calendar",
                     caption: "poprzednio: \(previous.activeDays) z 7", tone: .info)
            StatTile(title: "Nowe znaczenia", value: "\(current.newMeanings)", systemImage: "sparkles",
                     caption: "dodane słowa: \(current.addedWords)", tone: .accent)
            StatTile(title: "Opanowane w tym tygodniu", value: "\(current.masteredMeanings)", systemImage: "checkmark.seal",
                     caption: WeeklyReportFormat.delta(current.masteredMeanings, previous.masteredMeanings), tone: .success)
            StatTile(title: "Doświadczenie", value: "+\(current.xp) XP", systemImage: "star",
                     caption: WeeklyReportFormat.level(report), tone: .accent)
            StatTile(title: "Seria", value: LibraryText.days(report.streak), systemImage: "flame", tone: .warning)
        }
    }
}

/// Umiejętności: skuteczność w tym tygodniu i kierunek zmiany.
struct WeeklyReportSkillsCard: View {
    let skills: [WeeklySkillTrend]

    var body: some View {
        if skills.contains(where: { $0.answers > 0 }) {
            Card {
                SectionHeader("Umiejętności", subtitle: "Skuteczność w tym tygodniu i zmiana względem poprzedniego")
                ForEach(skills) { (skill: WeeklySkillTrend) in
                    WeeklyReportSkillRow(skill: skill)
                }
            }
        }
    }
}

private struct WeeklyReportSkillRow: View {
    let skill: WeeklySkillTrend

    private var tone: SkillTone? { SkillTone(rawValue: skill.skill.rawValue) }

    var body: some View {
        HStack(spacing: Spacing.s) {
            Image(systemName: tone?.systemImage ?? "circle")
                .foregroundStyle(tone?.color ?? Palette.inkSecondary)
                .frame(width: 24)
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 2) {
                Text(skill.skill.namePl)
                    .font(FluentFont.subheadline)
                    .foregroundStyle(Palette.ink)
                Text(detail)
                    .font(FluentFont.caption)
                    .foregroundStyle(Palette.inkSecondary)
            }
            Spacer(minLength: Spacing.xs)
            Text(WeeklyReportFormat.percent(skill.accuracy))
                .font(FluentFont.numberSmall)
                .foregroundStyle(Palette.ink)
            WeeklyReportTrendIcon(trend: skill.trend)
        }
        .frame(minHeight: HitTarget.minimum)
        .accessibilityElement(children: .combine)
    }

    private var detail: String {
        guard skill.answers > 0 else { return "nie ćwiczono w tym tygodniu" }
        var text = WeeklyReportText.answers(skill.answers)
        if let change = skill.change {
            text += change == 0 ? " · bez zmian" : " · \(change > 0 ? "+" : "−")\(abs(change)) pkt"
        }
        return text
    }
}

private struct WeeklyReportTrendIcon: View {
    let trend: WeeklyTrend

    var body: some View {
        Image(systemName: symbol)
            .font(FluentFont.footnote.weight(.semibold))
            .foregroundStyle(color)
            .frame(width: 20)
            .accessibilityLabel(Text(label))
    }

    private var symbol: String {
        switch trend {
        case .up: return "arrow.up.right"
        case .down: return "arrow.down.right"
        case .steady: return "arrow.right"
        case .new: return "sparkles"
        case .none: return "minus"
        }
    }

    private var color: Color {
        switch trend {
        case .up: return Palette.success
        case .down: return Palette.warning
        case .steady: return Palette.inkSecondary
        case .new: return Palette.accent
        case .none: return Palette.inkTertiary
        }
    }

    private var label: String {
        switch trend {
        case .up: return "lepiej niż tydzień wcześniej"
        case .down: return "słabiej niż tydzień wcześniej"
        case .steady: return "podobnie jak tydzień wcześniej"
        case .new: return "nowa w tym tygodniu"
        case .none: return "brak odpowiedzi"
        }
    }
}

/// Najtrudniejsze słowa tygodnia + „Powtórz je” (sesja pomyłek).
struct WeeklyReportHardWordsCard: View {
    let words: [WeeklyHardWord]
    let onPractice: () -> Void

    var body: some View {
        if !words.isEmpty {
            Card {
                SectionHeader("Najtrudniejsze słowa", subtitle: "Najwięcej pomyłek lub podpowiedzi w tym tygodniu")
                ForEach(words) { (word: WeeklyHardWord) in
                    NavigationLink(value: WordRoute.detail(id: word.wordId)) {
                        WeeklyReportHardWordRow(word: word)
                    }
                    .buttonStyle(.plain)
                }
                PrimaryButton("Powtórz je", systemImage: "arrow.counterclockwise", action: onPractice)
            }
        }
    }
}

private struct WeeklyReportHardWordRow: View {
    let word: WeeklyHardWord

    var body: some View {
        HStack(spacing: Spacing.s) {
            VStack(alignment: .leading, spacing: 2) {
                Text(word.term)
                    .font(FluentFont.bodyEmphasized)
                    .foregroundStyle(Palette.ink)
                if !word.translation.isEmpty {
                    Text(word.translation)
                        .font(FluentFont.footnote)
                        .foregroundStyle(Palette.inkSecondary)
                        .lineLimit(2)
                }
            }
            Spacer(minLength: Spacing.xs)
            Text("\(word.mistakes) z \(word.answers)")
                .font(FluentFont.numberSmall)
                .foregroundStyle(Palette.warning)
                .accessibilityLabel(Text("pomyłki: \(word.mistakes) z \(word.answers) odpowiedzi"))
            Image(systemName: "chevron.right")
                .font(FluentFont.footnote.weight(.semibold))
                .foregroundStyle(Palette.inkTertiary)
                .accessibilityHidden(true)
        }
        .frame(minHeight: HitTarget.minimum)
        .contentShape(Rectangle())
        .accessibilityElement(children: .combine)
    }
}

/// Jak liczymy (uczciwość liczb).
struct WeeklyReportFootnote: View {
    var body: some View {
        Text("Tydzień trwa od poniedziałku do niedzieli w Twojej strefie czasowej. Czas nauki to szacunek z długości odpowiedzi i ukończonych zestawów.")
            .font(FluentFont.footnote)
            .foregroundStyle(Palette.inkSecondary)
            .fixedSize(horizontal: false, vertical: true)
    }
}

/// Wejście do raportu z ekranu Postępy.
struct StatsWeeklyReportEntry: View {
    var body: some View {
        NavigationLink(value: StatsRoute.weeklyReport(weekOffset: 0)) {
            HStack(spacing: Spacing.s) {
                Image(systemName: "calendar.badge.clock")
                    .font(FluentFont.headline)
                    .foregroundStyle(Palette.accent)
                    .frame(width: 34, height: 34)
                    .background(Palette.accentSoft, in: RoundedRectangle(cornerRadius: Radius.small, style: .continuous))
                    .accessibilityHidden(true)
                VStack(alignment: .leading, spacing: 2) {
                    Text("Raport tygodniowy")
                        .font(FluentFont.headline)
                        .foregroundStyle(Palette.ink)
                    Text("Ten tydzień w porównaniu z poprzednim")
                        .font(FluentFont.footnote)
                        .foregroundStyle(Palette.inkSecondary)
                }
                Spacer(minLength: Spacing.xs)
                Image(systemName: "chevron.right")
                    .font(FluentFont.footnote.weight(.semibold))
                    .foregroundStyle(Palette.inkTertiary)
                    .accessibilityHidden(true)
            }
            .padding(Spacing.m)
            .frame(maxWidth: .infinity, alignment: .leading)
            .fluentCardBackground()
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}
