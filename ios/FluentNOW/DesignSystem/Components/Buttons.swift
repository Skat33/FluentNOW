import SwiftUI

/// Główny przycisk ekranu (pełna szerokość domyślnie). Jeden na ekran.
///
/// ```swift
/// PrimaryButton("Zaczynam naukę", systemImage: "play.fill") { startSession() }
/// PrimaryButton("Zapisz", isLoading: store.isSaving) { save() }
/// ```
struct PrimaryButton: View {
    private let title: String
    private let systemImage: String?
    private let isLoading: Bool
    private let fillsWidth: Bool
    private let action: () -> Void

    init(
        _ title: String,
        systemImage: String? = nil,
        isLoading: Bool = false,
        fillsWidth: Bool = true,
        action: @escaping () -> Void
    ) {
        self.title = title
        self.systemImage = systemImage
        self.isLoading = isLoading
        self.fillsWidth = fillsWidth
        self.action = action
    }

    var body: some View {
        Button(action: action) {
            FluentButtonLabel(title: title, systemImage: systemImage, isLoading: isLoading, fillsWidth: fillsWidth)
        }
        .fluentButtonStyle(.primary)
        .disabled(isLoading)
        .accessibilityValue(isLoading ? Text("Trwa wykonywanie") : Text(""))
    }
}

/// Przycisk drugorzędny (np. „Pokaż podpowiedź”, „Pomiń”). Wariant niszczący: `role: .destructive`.
struct SecondaryButton: View {
    private let title: String
    private let systemImage: String?
    private let role: ButtonRole?
    private let isLoading: Bool
    private let fillsWidth: Bool
    private let action: () -> Void

    init(
        _ title: String,
        systemImage: String? = nil,
        role: ButtonRole? = nil,
        isLoading: Bool = false,
        fillsWidth: Bool = true,
        action: @escaping () -> Void
    ) {
        self.title = title
        self.systemImage = systemImage
        self.role = role
        self.isLoading = isLoading
        self.fillsWidth = fillsWidth
        self.action = action
    }

    var body: some View {
        Button(role: role, action: action) {
            FluentButtonLabel(title: title, systemImage: systemImage, isLoading: isLoading, fillsWidth: fillsWidth)
        }
        .fluentButtonStyle(role == .destructive ? .destructive : .secondary)
        .disabled(isLoading)
        .accessibilityValue(isLoading ? Text("Trwa wykonywanie") : Text(""))
    }
}

/// Wspólna etykieta przycisków: ikona lub wskaźnik ładowania + tytuł.
private struct FluentButtonLabel: View {
    let title: String
    let systemImage: String?
    let isLoading: Bool
    let fillsWidth: Bool

    var body: some View {
        HStack(spacing: Spacing.xs) {
            if isLoading {
                ProgressView()
                    .accessibilityHidden(true)
            } else if let systemImage {
                Image(systemName: systemImage)
                    .accessibilityHidden(true)
            }
            Text(title)
                .lineLimit(2)
        }
        .frame(maxWidth: fillsWidth ? .infinity : nil)
    }
}

#Preview("Przyciski") {
    VStack(spacing: Spacing.m) {
        PrimaryButton("Zaczynam naukę", systemImage: "play.fill") {}
        PrimaryButton("Zapisywanie", isLoading: true) {}
        SecondaryButton("Pokaż podpowiedź", systemImage: "lightbulb") {}
        SecondaryButton("Usuń kolekcję", systemImage: "trash", role: .destructive) {}
        HStack {
            SecondaryButton("Pomiń", fillsWidth: false) {}
            PrimaryButton("Sprawdź", fillsWidth: false) {}
        }
    }
    .padding(Spacing.screen)
    .background(Palette.background)
}
