import SwiftUI
import AuthenticationServices

/// Ekran logowania przy pierwszym uruchomieniu (FEEDBACK-5 J3): Apple, Google, e-mail i hasło
/// oraz „Kontynuuj bez konta”. Pokazywany przez `AuthGate` przed wywiadem (G4).
struct AuthWelcomeScreen: View {
    @Environment(AuthController.self) private var auth
    @State private var message: String?
    @State private var showsEmail = false

    var body: some View {
        ScrollView {
            VStack(spacing: Spacing.l) {
                AuthWelcomeHeader()
                AuthProviderButtons(message: $message, showsEmail: $showsEmail)
                if let message {
                    AuthMessageView(text: message)
                }
                AuthGuestSection()
                #if DEBUG
                AuthDebugHint()
                #endif
                AuthPrivacyFooter()
            }
            .frame(maxWidth: 480)
            .padding(.horizontal, Spacing.screen)
            .padding(.vertical, Spacing.xl)
            .frame(maxWidth: .infinity)
        }
        .scrollBounceBehavior(.basedOnSize)
        .background(Palette.background.ignoresSafeArea())
        .sheet(isPresented: $showsEmail) {
            AuthEmailSheet()
        }
    }
}

/// Logo, nazwa i jedno zdanie o aplikacji.
private struct AuthWelcomeHeader: View {
    var body: some View {
        VStack(spacing: Spacing.s) {
            ZStack {
                Circle()
                    .fill(LinearGradient(colors: [Palette.heroStart, Palette.heroEnd], startPoint: .topLeading, endPoint: .bottomTrailing))
                Image(systemName: "character.bubble.fill")
                    .font(.system(size: 40, weight: .semibold))
                    .foregroundStyle(Color.white)
            }
            .frame(width: 88, height: 88)
            .accessibilityHidden(true)
            Text("FluentNOW")
                .font(FluentFont.display)
                .foregroundStyle(Palette.ink)
                .accessibilityAddTraits(.isHeader)
            Text("Angielski w krótkich sesjach — słowa z Twojego życia, powtórki we właściwym momencie.")
                .font(FluentFont.callout)
                .foregroundStyle(Palette.inkSecondary)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(.top, Spacing.l)
    }
}

/// Przyciski dostawców: Apple (systemowy), Google, e-mail.
private struct AuthProviderButtons: View {
    @Binding var message: String?
    @Binding var showsEmail: Bool

    @Environment(AuthController.self) private var auth
    @Environment(\.webAuthenticationSession) private var webAuthenticationSession

    var body: some View {
        VStack(spacing: Spacing.s) {
            AuthAppleButton(message: $message)
            AuthProviderButton(title: "Zaloguj przez Google", systemImage: "globe", isLoading: false) {
                signInWithGoogle()
            }
            AuthProviderButton(title: "E-mail i hasło", systemImage: "envelope.fill", isLoading: false) {
                message = nil
                showsEmail = true
            }
        }
        .disabled(auth.isWorking)
        .overlay {
            if auth.isWorking {
                ProgressView()
                    .controlSize(.large)
                    .accessibilityLabel(Text("Trwa logowanie"))
            }
        }
    }

    private func signInWithGoogle() {
        message = nil
        let session = webAuthenticationSession
        Task { @MainActor in
            let error: String? = await auth.signInWithGoogle(using: session)
            message = error
        }
    }
}

/// „Zaloguj przez Apple”: przycisk systemowy, a w buildzie bez uprawnienia — przycisk
/// w tym samym stylu, który wyjaśnia, czego brakuje (zamiast błędu systemu).
private struct AuthAppleButton: View {
    @Binding var message: String?

    @Environment(AuthController.self) private var auth
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        if auth.isAppleSignInAvailable {
            SignInWithAppleButton(.signIn) { (request: ASAuthorizationAppleIDRequest) in
                message = nil
                auth.prepareAppleRequest(request)
            } onCompletion: { (result: Result<ASAuthorization, Error>) in
                Task { @MainActor in
                    let error: String? = await auth.completeApple(result)
                    message = error
                }
            }
            .signInWithAppleButtonStyle(colorScheme == .dark ? .white : .black)
            .frame(height: HitTarget.buttonHeight)
            .clipShape(RoundedRectangle(cornerRadius: Radius.medium, style: .continuous))
        } else {
            Button {
                message = AuthError.appleNotConfigured.errorDescription
            } label: {
                AuthAppleFallbackLabel()
            }
            .buttonStyle(.plain)
            .accessibilityHint(Text("Wymaga konfiguracji aplikacji"))
        }
    }
}

private struct AuthAppleFallbackLabel: View {
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        let isDark = colorScheme == .dark
        HStack(spacing: Spacing.xs) {
            Image(systemName: "apple.logo")
                .accessibilityHidden(true)
            Text("Zaloguj przez Apple")
        }
        .font(FluentFont.button)
        .foregroundStyle(isDark ? Color.black : Color.white)
        .frame(maxWidth: .infinity, minHeight: HitTarget.buttonHeight)
        .background(isDark ? Color.white : Color.black, in: RoundedRectangle(cornerRadius: Radius.medium, style: .continuous))
        .contentShape(RoundedRectangle(cornerRadius: Radius.medium, style: .continuous))
    }
}

/// Przycisk dostawcy w stylu obramowanej karty (Google, e-mail).
struct AuthProviderButton: View {
    let title: String
    let systemImage: String
    let isLoading: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: Spacing.xs) {
                if isLoading {
                    ProgressView()
                        .accessibilityHidden(true)
                } else {
                    Image(systemName: systemImage)
                        .accessibilityHidden(true)
                }
                Text(title)
            }
            .font(FluentFont.button)
            .foregroundStyle(Palette.ink)
            .frame(maxWidth: .infinity, minHeight: HitTarget.buttonHeight)
            .background(Palette.surface, in: RoundedRectangle(cornerRadius: Radius.medium, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: Radius.medium, style: .continuous)
                    .strokeBorder(Palette.separator, lineWidth: 1)
            }
            .contentShape(RoundedRectangle(cornerRadius: Radius.medium, style: .continuous))
        }
        .buttonStyle(.plain)
    }
}

/// Komunikat pod przyciskami (błąd lub informacja, np. brak konfiguracji Google).
struct AuthMessageView: View {
    let text: String

    var body: some View {
        HStack(alignment: .top, spacing: Spacing.xs) {
            Image(systemName: "info.circle.fill")
                .foregroundStyle(Palette.info)
                .accessibilityHidden(true)
            Text(text)
                .font(FluentFont.footnote)
                .foregroundStyle(Palette.ink)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(Spacing.s)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Palette.infoSoft, in: RoundedRectangle(cornerRadius: Radius.small, style: .continuous))
        .accessibilityElement(children: .combine)
    }
}

/// „Kontynuuj bez konta” — tryb gościa (dane lokalnie i w iCloud, jak dotąd).
private struct AuthGuestSection: View {
    @Environment(AuthController.self) private var auth

    var body: some View {
        VStack(spacing: Spacing.xxs) {
            Button("Kontynuuj bez konta") {
                auth.continueAsGuest()
            }
            .font(FluentFont.button)
            .foregroundStyle(Palette.accent)
            .frame(maxWidth: .infinity, minHeight: HitTarget.minimum)
            .disabled(auth.isWorking)
            Text("Słówka i postęp zostaną na tym urządzeniu i w Twoim iCloud. Zalogować się możesz później w profilu.")
                .font(FluentFont.caption)
                .foregroundStyle(Palette.inkSecondary)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
        }
    }
}

private struct AuthPrivacyFooter: View {
    var body: some View {
        Text("Hasła i dane logowania są przechowywane tylko w pęku kluczy tego urządzenia.")
            .font(FluentFont.caption)
            .foregroundStyle(Palette.inkTertiary)
            .multilineTextAlignment(.center)
            .fixedSize(horizontal: false, vertical: true)
    }
}

#if DEBUG
/// Podpowiedź konta testowego — tylko w buildach DEBUG.
private struct AuthDebugHint: View {
    var body: some View {
        Label {
            Text("DEBUG: konto testowe \(LocalAuthService.DebugAccount.email) / \(LocalAuthService.DebugAccount.password)")
        } icon: {
            Image(systemName: "hammer.fill")
        }
        .font(FluentFont.caption)
        .foregroundStyle(Palette.warning)
        .padding(Spacing.xs)
        .frame(maxWidth: .infinity)
        .background(Palette.warningSoft, in: RoundedRectangle(cornerRadius: Radius.small, style: .continuous))
    }
}
#endif

#Preview("Logowanie") {
    AuthWelcomeScreen()
        .environment(AuthController.inMemory(status: .signedOut))
        .fluentPreviewEnvironment(.previewEmpty)
}
