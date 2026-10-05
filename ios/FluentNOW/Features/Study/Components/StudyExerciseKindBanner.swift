import SwiftUI

/// Nagłówek „Rodzaj ćwiczenia” (jak `ExerciseKind` strony): ikona + rodzaj + szczegół.
struct StudyExerciseKindBanner: View {
    enum Kind: String {
        case vocabulary = "Słownictwo"
        case listening = "Słuchanie"
        case grammar = "Gramatyka"
        case idioms = "Idiomy"
        case reading = "Czytanie"

        var systemImage: String {
            switch self {
            case .vocabulary: return "character.book.closed"
            case .listening: return "headphones"
            case .grammar: return "pencil.line"
            case .idioms: return "text.bubble"
            case .reading: return "book"
            }
        }
    }

    let kind: Kind
    let detail: String?

    init(_ kind: Kind, detail: String? = nil) {
        self.kind = kind
        self.detail = detail
    }

    var body: some View {
        HStack(spacing: Spacing.xs) {
            Image(systemName: kind.systemImage)
                .font(FluentFont.headline)
                .foregroundStyle(Palette.accent)
                .frame(width: 28)
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 2) {
                Text("Rodzaj ćwiczenia")
                    .fluentEyebrow()
                    .foregroundStyle(Palette.inkSecondary)
                Text(label)
                    .font(FluentFont.subheadline.weight(.semibold))
                    .foregroundStyle(Palette.ink)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: 0)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text("Rodzaj ćwiczenia: \(label)"))
    }

    private var label: String {
        guard let detail, !detail.isEmpty else { return kind.rawValue }
        return "\(kind.rawValue) · \(detail)"
    }
}

#Preview("Rodzaj ćwiczenia") {
    VStack(alignment: .leading, spacing: Spacing.m) {
        StudyExerciseKindBanner(.vocabulary, detail: "Fiszka")
        StudyExerciseKindBanner(.listening, detail: "Dyktando")
        StudyExerciseKindBanner(.grammar, detail: "Wpisz odpowiedź")
    }
    .padding(Spacing.screen)
    .background(Palette.background)
    .fluentPreviewEnvironment()
}
