import SwiftUI

/// Stan pusty: ikona, tytuł, opis i (opcjonalnie) jedno wezwanie do działania.
/// Ton: zachęcający, konkretny, bez wykrzykników („Nie masz jeszcze słów. Dodaj temat, by zacząć.”).
///
/// ```swift
/// EmptyStateView(
///     systemImage: "text.book.closed",
///     title: "Twój słownik jest pusty",
///     message: "Dodaj pierwsze słowo lub cały temat — nauka zacznie się od razu.",
///     actionTitle: "Przeglądaj tematy"
/// ) { router.openLibrary(.topics) }
/// ```
struct EmptyStateView: View {
    private let systemImage: String
    private let title: String
    private let message: String?
    private let actionTitle: String?
    private let action: (() -> Void)?

    init(
        systemImage: String,
        title: String,
        message: String? = nil,
        actionTitle: String? = nil,
        action: (() -> Void)? = nil
    ) {
        self.systemImage = systemImage
        self.title = title
        self.message = message
        self.actionTitle = actionTitle
        self.action = action
    }

    var body: some View {
        VStack(spacing: Spacing.m) {
            Image(systemName: systemImage)
                .font(.system(size: 44, weight: .regular))
                .foregroundStyle(Palette.accent)
                .frame(width: 88, height: 88)
                .background(Palette.accentSoft, in: Circle())
                .accessibilityHidden(true)
            VStack(spacing: Spacing.xs) {
                Text(title)
                    .font(FluentFont.title)
                    .foregroundStyle(Palette.ink)
                    .accessibilityAddTraits(.isHeader)
                if let message {
                    Text(message)
                        .font(FluentFont.callout)
                        .foregroundStyle(Palette.inkSecondary)
                }
            }
            .multilineTextAlignment(.center)
            .fixedSize(horizontal: false, vertical: true)
            if let actionTitle, let action {
                PrimaryButton(actionTitle, fillsWidth: false, action: action)
                    .padding(.top, Spacing.xs)
            }
        }
        .frame(maxWidth: Spacing.readableWidth)
        .padding(.horizontal, Spacing.l)
        .padding(.vertical, Spacing.xxl)
        .frame(maxWidth: .infinity)
        .accessibilityElement(children: .contain)
    }
}

/// Stan ładowania: wskaźnik + krótki opis. Pokazuj dopiero po ~300 ms (unikaj migania);
/// dla list preferuj szkielet (`.redacted(reason: .placeholder)`).
struct LoadingStateView: View {
    private let message: String

    init(_ message: String = "Wczytywanie…") {
        self.message = message
    }

    var body: some View {
        VStack(spacing: Spacing.s) {
            ProgressView()
                .controlSize(.large)
                .tint(Palette.accent)
            Text(message)
                .font(FluentFont.callout)
                .foregroundStyle(Palette.inkSecondary)
        }
        .frame(maxWidth: .infinity, minHeight: 160)
        .accessibilityElement(children: .combine)
    }
}

/// Baner błędu z akcją „Spróbuj ponownie” i/lub zamknięciem. Komunikat po polsku, konkretny,
/// mówi co się stało i co zrobić (dane nie giną).
///
/// ```swift
/// ErrorBanner(message: "Nie udało się zapisać zmian. Twoje dane są bezpieczne na urządzeniu.",
///             onRetry: { store.retrySave() }, onDismiss: { store.clearError() })
/// ```
struct ErrorBanner: View {
    private let title: String
    private let message: String
    private let retryTitle: String
    private let onRetry: (() -> Void)?
    private let onDismiss: (() -> Void)?

    init(
        title: String = "Coś poszło nie tak",
        message: String,
        retryTitle: String = "Spróbuj ponownie",
        onRetry: (() -> Void)? = nil,
        onDismiss: (() -> Void)? = nil
    ) {
        self.title = title
        self.message = message
        self.retryTitle = retryTitle
        self.onRetry = onRetry
        self.onDismiss = onDismiss
    }

    var body: some View {
        HStack(alignment: .top, spacing: Spacing.s) {
            Image(systemName: "exclamationmark.triangle.fill")
                .foregroundStyle(Palette.danger)
                .font(FluentFont.headline)
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: Spacing.xxs) {
                Text(title)
                    .font(FluentFont.headline)
                    .foregroundStyle(Palette.ink)
                Text(message)
                    .font(FluentFont.subheadline)
                    .foregroundStyle(Palette.inkSecondary)
                    .fixedSize(horizontal: false, vertical: true)
                if let onRetry {
                    Button(retryTitle, action: onRetry)
                        .font(FluentFont.button)
                        .foregroundStyle(Palette.danger)
                        .frame(minHeight: HitTarget.minimum)
                }
            }
            Spacer(minLength: 0)
            if let onDismiss {
                Button(action: onDismiss) {
                    Image(systemName: "xmark")
                        .font(FluentFont.footnote.weight(.semibold))
                        .foregroundStyle(Palette.inkSecondary)
                        .frame(width: HitTarget.minimum, height: HitTarget.minimum)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel(Text("Zamknij komunikat"))
            }
        }
        .padding(Spacing.m)
        .fluentCardBackground(.tinted(.danger), cornerRadius: Radius.medium)
        .accessibilityElement(children: .contain)
    }
}

#Preview("Stany: pusty, ładowanie, błąd") {
    ScrollView {
        VStack(spacing: Spacing.l) {
            ErrorBanner(
                message: "Nie udało się zapisać zmian. Twoje dane są bezpieczne na urządzeniu.",
                onRetry: {},
                onDismiss: {}
            )
            LoadingStateView("Wczytywanie tematów…")
            EmptyStateView(
                systemImage: "text.book.closed",
                title: "Twój słownik jest pusty",
                message: "Dodaj pierwsze słowo lub cały temat — nauka zacznie się od razu.",
                actionTitle: "Przeglądaj tematy"
            ) {}
        }
        .padding(Spacing.screen)
    }
    .background(Palette.background)
}
