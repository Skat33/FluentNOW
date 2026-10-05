import SwiftUI

/// Lista odpowiedzi do wyboru (ABCD) — gramatyka, idiomy, czytanie, warianty znaczeń.
///
/// - `selected`: wybrana opcja (lub `nil`);
/// - `correct`: indeks poprawnej odpowiedzi pokazywany dopiero, gdy `isRevealed`;
/// - `usesKeyboardShortcuts`: klawisze 1–4 na klawiaturze sprzętowej (wyłącz, gdy obok jest pole tekstowe).
struct StudyChoiceList: View {
    enum Marker { case letters, numbers }

    let options: [String]
    let selected: Int?
    let correct: Int?
    let isRevealed: Bool
    let isEnabled: Bool
    var marker: Marker = .letters
    var usesKeyboardShortcuts: Bool = true
    let onSelect: (Int) -> Void

    var body: some View {
        VStack(spacing: Spacing.xs) {
            ForEach(Array(options.enumerated()), id: \.offset) { index, option in
                StudyChoiceRow(
                    marker: marker == .letters ? StudyFormat.letter(index) : "\(index + 1)",
                    text: option,
                    state: state(for: index),
                    isEnabled: isEnabled,
                    shortcut: shortcut(for: index)
                ) {
                    onSelect(index)
                }
            }
        }
    }

    private func shortcut(for index: Int) -> KeyEquivalent? {
        guard usesKeyboardShortcuts, isEnabled, index < 9 else { return nil }
        return KeyEquivalent(Character("\(index + 1)"))
    }

    private func state(for index: Int) -> StudyChoiceRow.RowState {
        if isRevealed {
            if index == correct { return .correct }
            if index == selected { return .wrong }
            return .idle
        }
        return index == selected ? .chosen : .idle
    }
}

/// Jeden wiersz odpowiedzi.
struct StudyChoiceRow: View {
    enum RowState { case idle, chosen, correct, wrong }

    let marker: String
    let text: String
    let state: RowState
    let isEnabled: Bool
    let shortcut: KeyEquivalent?
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(alignment: .firstTextBaseline, spacing: Spacing.s) {
                Text(marker)
                    .font(FluentFont.numberSmall)
                    .foregroundStyle(markerColor)
                    .frame(minWidth: 24)
                Text(text)
                    .font(FluentFont.body)
                    .foregroundStyle(Palette.ink)
                    .multilineTextAlignment(.leading)
                    .fixedSize(horizontal: false, vertical: true)
                Spacer(minLength: Spacing.xs)
                if let icon {
                    Image(systemName: icon)
                        .foregroundStyle(markerColor)
                        .accessibilityHidden(true)
                }
            }
            .padding(.horizontal, Spacing.m)
            .padding(.vertical, Spacing.s)
            .frame(maxWidth: .infinity, minHeight: HitTarget.minimum, alignment: .leading)
            .background(background, in: RoundedRectangle(cornerRadius: Radius.medium, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: Radius.medium, style: .continuous)
                    .strokeBorder(border, lineWidth: state == .idle ? 1 : 1.5)
            }
            .contentShape(RoundedRectangle(cornerRadius: Radius.medium, style: .continuous))
        }
        .buttonStyle(.plain)
        .disabled(!isEnabled)
        .modifier(StudyOptionalShortcut(key: shortcut))
        .accessibilityLabel(Text("\(marker). \(text)"))
        .accessibilityValue(Text(accessibilityValue))
        .accessibilityAddTraits(state == .chosen ? .isSelected : [])
    }

    private var icon: String? {
        switch state {
        case .idle: return nil
        case .chosen: return "checkmark"
        case .correct: return "checkmark.circle.fill"
        case .wrong: return "xmark.circle.fill"
        }
    }

    private var markerColor: Color {
        switch state {
        case .idle: return Palette.inkSecondary
        case .chosen: return Palette.accent
        case .correct: return Palette.success
        case .wrong: return Palette.danger
        }
    }

    private var background: Color {
        switch state {
        case .idle: return Palette.surface
        case .chosen: return Palette.accentSoft
        case .correct: return Palette.successSoft
        case .wrong: return Palette.dangerSoft
        }
    }

    private var border: Color {
        switch state {
        case .idle: return Palette.separator
        case .chosen: return Palette.accent
        case .correct: return Palette.success
        case .wrong: return Palette.danger
        }
    }

    private var accessibilityValue: String {
        switch state {
        case .idle: return ""
        case .chosen: return "Wybrano"
        case .correct: return "Poprawna odpowiedź"
        case .wrong: return "Twoja odpowiedź, niepoprawna"
        }
    }
}

/// Skrót klawiaturowy bez modyfikatorów tylko wtedy, gdy podano klawisz.
struct StudyOptionalShortcut: ViewModifier {
    let key: KeyEquivalent?

    @ViewBuilder
    func body(content: Content) -> some View {
        if let key {
            content.keyboardShortcut(key, modifiers: [])
        } else {
            content
        }
    }
}

#Preview("Odpowiedzi ABCD") {
    ScrollView {
        VStack(spacing: Spacing.l) {
            StudyChoiceList(options: ["has been", "was", "is", "were"], selected: 1, correct: nil, isRevealed: false, isEnabled: true) { _ in }
            StudyChoiceList(options: ["has been", "was", "is", "were"], selected: 1, correct: 0, isRevealed: true, isEnabled: false) { _ in }
        }
        .padding(Spacing.screen)
    }
    .background(Palette.background)
    .fluentPreviewEnvironment()
}
