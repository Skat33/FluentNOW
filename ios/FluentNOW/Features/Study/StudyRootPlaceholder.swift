import SwiftUI

/// ZAŚLEPKA (design-shell) — fala 2 zastąpi ją ekranem „Na co masz dziś ochotę?”.
/// Pokazuje wzorzec konsumowania prośby o sesję z routera.
struct StudyRootPlaceholder: View {
    @Environment(AppRouter.self) private var router
    @State private var lastRequest: StudyLaunchRequest?

    var body: some View {
        ScrollView {
            VStack(spacing: Spacing.l) {
                EmptyStateView(
                    systemImage: "brain.head.profile",
                    title: "Nauka",
                    message: "Tu wybierzesz tryby i czas sesji (5/10/15 minut)."
                )
                if let lastRequest {
                    Card(style: .tinted(.accent)) {
                        Text("Prośba o sesję")
                            .font(FluentFont.headline)
                        Text(describe(lastRequest))
                            .font(FluentFont.callout)
                            .foregroundStyle(Palette.inkSecondary)
                    }
                }
            }
            .padding(Spacing.screen)
        }
        .navigationTitle("Nauka")
        .onChange(of: router.pendingStudyLaunch, initial: true) { _, newValue in
            guard newValue != nil else { return }
            lastRequest = router.consumeStudyLaunch()
        }
    }

    private func describe(_ request: StudyLaunchRequest) -> String {
        if request.resume {
            return "Wznów przerwaną sesję"
        }
        let modes = request.modes.isEmpty ? "mixed" : request.modes.joined(separator: ", ")
        let minutes = request.minutes.map { "\($0) min" } ?? "czas domyślny"
        return "Tryby: \(modes) · \(minutes)"
    }
}

#Preview("Nauka — zaślepka") {
    NavigationStack {
        StudyRootPlaceholder()
    }
    .environment(AppRouter())
}
