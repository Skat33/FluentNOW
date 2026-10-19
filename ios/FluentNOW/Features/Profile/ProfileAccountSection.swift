import SwiftUI
import FluentKit

/// Konto: gość → „Zaloguj się”; zalogowany → „Wyloguj” i „Usuń konto” (wymóg App Store).
struct ProfileAccountSection: View {
    @Environment(AuthController.self) private var auth

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.s) {
            SectionHeader("Konto")
            if let session = auth.session {
                ProfileSignedInActions(session: session)
            } else {
                ProfileGuestCard()
            }
        }
    }
}

private struct ProfileGuestCard: View {
    @Environment(AuthController.self) private var auth
    @Environment(AppRouter.self) private var router

    var body: some View {
        Card {
            Text("Uczysz się bez konta. Słówka i postęp są na tym urządzeniu i w Twoim iCloud — po zalogowaniu wszystko zostaje.")
                .font(FluentFont.callout)
                .foregroundStyle(Palette.ink)
                .fixedSize(horizontal: false, vertical: true)
            PrimaryButton("Zaloguj się lub załóż konto", systemImage: "person.crop.circle.badge.plus") {
                router.dismissSheet()
                auth.showSignIn()
            }
        }
    }
}

private struct ProfileSignedInActions: View {
    let session: AuthSession

    @Environment(AuthController.self) private var auth
    @Environment(AppRouter.self) private var router
    @Environment(LearningStore.self) private var store
    @Environment(AppPreferences.self) private var preferences

    @State private var confirmsSignOut = false
    @State private var confirmsDelete = false
    @State private var errorMessage: String?

    var body: some View {
        Card {
            if session.isLocalOnly {
                Text("Konto jest na razie zapisane tylko na tym urządzeniu. Słówka i postęp synchronizują się przez iCloud, niezależnie od konta.")
                    .font(FluentFont.footnote)
                    .foregroundStyle(Palette.inkSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            SecondaryButton("Wyloguj", systemImage: "rectangle.portrait.and.arrow.right", isLoading: auth.isWorking) {
                confirmsSignOut = true
            }
            SecondaryButton("Usuń konto", systemImage: "trash", role: .destructive, isLoading: auth.isWorking) {
                confirmsDelete = true
            }
            if let errorMessage {
                Text(errorMessage)
                    .font(FluentFont.footnote)
                    .foregroundStyle(Palette.danger)
            }
        }
        .confirmationDialog("Wylogować się?", isPresented: $confirmsSignOut, titleVisibility: .visible) {
            Button("Wyloguj") {
                Task { @MainActor in await signOut() }
            }
            Button("Anuluj", role: .cancel) {}
        } message: {
            Text("Słówka i postęp zostaną na tym urządzeniu.")
        }
        .confirmationDialog("Usunąć konto?", isPresented: $confirmsDelete, titleVisibility: .visible) {
            Button("Usuń konto i dane nauki", role: .destructive) {
                Task { @MainActor in await deleteAccount(includingData: true) }
            }
            Button("Usuń tylko konto", role: .destructive) {
                Task { @MainActor in await deleteAccount(includingData: false) }
            }
            Button("Anuluj", role: .cancel) {}
        } message: {
            Text(deleteMessage)
        }
    }

    private var deleteMessage: String {
        var text = "Konto zostanie usunięte i nastąpi wylogowanie. „Usuń konto i dane nauki” kasuje też wszystkie słowa, postęp i historię — na tym urządzeniu i w iCloud. Tej operacji nie można cofnąć."
        if session.provider == .apple {
            text += " Dostęp aplikacji do Apple ID możesz też cofnąć w Ustawieniach iPhone’a → Apple ID → Zaloguj się przez Apple."
        }
        return text
    }

    private func signOut() async {
        errorMessage = nil
        await auth.signOut()
        router.dismissSheet()
        router.selectedTab = .today
    }

    private func deleteAccount(includingData: Bool) async {
        errorMessage = nil
        if includingData {
            do {
                try await store.deleteAllData()
                preferences.hasCompletedOnboarding = false
            } catch {
                errorMessage = "Nie udało się usunąć danych nauki: \(error.localizedDescription) Konto nie zostało usunięte."
                return
            }
        }
        if let error = await auth.deleteAccount() {
            errorMessage = error
            return
        }
        router.dismissSheet()
        router.selectedTab = .today
    }
}
