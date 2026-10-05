import SwiftUI

/// Pole odpowiedzi w ćwiczeniach: bez autokorekty i wielkich liter, „Gotowe” = sprawdź,
/// klawiatura ASCII dla odpowiedzi po angielsku (apostrof typograficzny normalizuje FluentKit).
/// Fokus kontroluje ekran (`focus`), żeby po pojawieniu się zadania klawiatura była od razu gotowa.
struct StudyAnswerField: View {
    enum Language { case english, polish }

    @Binding var text: String
    let placeholder: String
    let language: Language
    let isEnabled: Bool
    let focus: FocusState<Bool>.Binding
    let onSubmit: () -> Void

    var body: some View {
        TextField(placeholder, text: $text)
            .font(FluentFont.body)
            .foregroundStyle(Palette.ink)
            .textFieldStyle(.plain)
            .autocorrectionDisabled()
            .textInputAutocapitalization(.never)
            .keyboardType(language == .english ? .asciiCapable : .default)
            .submitLabel(.done)
            .focused(focus)
            .disabled(!isEnabled)
            .onSubmit(onSubmit)
            .onChange(of: text) { _, newValue in
                let limited = StudyFormat.limitedInput(newValue)
                if limited != newValue {
                    text = limited
                }
            }
            .padding(.horizontal, Spacing.m)
            .frame(minHeight: HitTarget.buttonHeight)
            .background(Palette.surfaceMuted, in: RoundedRectangle(cornerRadius: Radius.medium, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: Radius.medium, style: .continuous)
                    .strokeBorder(focus.wrappedValue ? Palette.accent : Palette.separator, lineWidth: focus.wrappedValue ? 1.5 : 1)
            }
            .accessibilityLabel(Text(language == .english ? "Twoja odpowiedź po angielsku" : "Twoja odpowiedź po polsku"))
    }
}

private struct StudyAnswerFieldPreview: View {
    @State private var text = ""
    @FocusState private var focused: Bool

    var body: some View {
        VStack(spacing: Spacing.m) {
            StudyAnswerField(text: $text, placeholder: "Wpisz swoją odpowiedź…", language: .english, isEnabled: true, focus: $focused) {}
            StudyAnswerField(text: .constant("pożyczyć"), placeholder: "Wpisz polskie znaczenie…", language: .polish, isEnabled: false, focus: $focused) {}
        }
        .padding(Spacing.screen)
        .background(Palette.background)
    }
}

#Preview("Pole odpowiedzi") {
    StudyAnswerFieldPreview()
        .fluentPreviewEnvironment()
}
