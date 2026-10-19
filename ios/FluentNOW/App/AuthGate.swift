import SwiftUI

/// Bramka logowania (FEEDBACK-5 J3): przy pierwszym uruchomieniu ekran logowania, potem aplikacja
/// (a w niej — przy pustym słowniku — wywiad G4 na ekranie Dzisiaj). Gość i zalogowany widzą to samo;
/// dane nauki są niezależne od konta.
struct AuthGate<Content: View>: View {
    @Environment(AuthController.self) private var auth
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    private let content: Content

    init(@ViewBuilder content: () -> Content) {
        self.content = content()
    }

    var body: some View {
        ZStack {
            gateContent
        }
        .animation(Motion.resolved(Motion.standard, reduceMotion: reduceMotion, fallback: Motion.reducedFade), value: phase)
    }

    @ViewBuilder
    private var gateContent: some View {
        switch phase {
        case .loading:
            AuthGateLaunchView()
        case .signIn:
            AuthWelcomeScreen()
                .transition(.opacity)
        case .app:
            content
                .transition(.opacity)
        }
    }

    private var phase: AuthGatePhase {
        switch auth.status {
        case .loading: return .loading
        case .signedOut: return .signIn
        case .guest, .signedIn: return .app
        }
    }
}

private enum AuthGatePhase: Hashable {
    case loading
    case signIn
    case app
}

/// Tło na czas odczytu sesji (bez spinnera — trwa ułamek sekundy).
private struct AuthGateLaunchView: View {
    var body: some View {
        Palette.background
            .ignoresSafeArea()
            .accessibilityHidden(true)
    }
}
