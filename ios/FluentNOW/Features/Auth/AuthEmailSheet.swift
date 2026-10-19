import SwiftUI

/// Tryb arkusza e-mail.
enum AuthEmailMode: String, CaseIterable, Identifiable, Hashable {
    case signIn
    case register
    case forgot

    var id: String { rawValue }

    var title: String {
        switch self {
        case .signIn: return "Zaloguj się"
        case .register: return "Załóż konto"
        case .forgot: return "Nie pamiętam hasła"
        }
    }
}

/// E-mail i hasło (FEEDBACK-5 J3): logowanie, rejestracja i „Nie pamiętam hasła”.
/// Do czasu backendu konta są lokalne (sól + PBKDF2 w pęku kluczy).
struct AuthEmailSheet: View {
    @Environment(AuthController.self) private var auth
    @Environment(\.dismiss) private var dismiss

    @State private var mode: AuthEmailMode = .signIn
    @State private var form = AuthEmailForm()
    @State private var message: String?
    /// „Nie pamiętam hasła” bez serwera → nowe konto zastępuje lokalne o tym adresie.
    @State private var replacesExisting = false

    var body: some View {
        NavigationStack {
            Form {
                if mode != .forgot {
                    AuthModePicker(mode: $mode)
                }
                AuthEmailFields(mode: mode, form: $form, onSubmit: submit)
                if let message {
                    Section {
                        AuthMessageView(text: message)
                    }
                    .listRowInsets(EdgeInsets())
                    .listRowBackground(Color.clear)
                }
                AuthEmailActions(mode: mode, isWorking: auth.isWorking, replacesExisting: replacesExisting, onSubmit: submit, onForgot: openForgot, onBack: backToSignIn)
            }
            .scrollContentBackground(.hidden)
            .background(Palette.background)
            .navigationTitle(mode.title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Anuluj") { dismiss() }
                }
            }
            .onChange(of: mode) { (_: AuthEmailMode, _: AuthEmailMode) in
                message = nil
            }
        }
        .interactiveDismissDisabled(auth.isWorking)
    }

    private func openForgot() {
        message = nil
        replacesExisting = false
        mode = .forgot
    }

    private func backToSignIn() {
        replacesExisting = false
        mode = .signIn
    }

    private func submit() {
        guard !auth.isWorking else { return }
        message = nil
        let current = form
        let currentMode = mode
        let replace = replacesExisting
        Task { @MainActor in
            switch currentMode {
            case .signIn:
                let error: String? = await auth.signIn(email: current.email, password: current.password)
                finish(error)
            case .register:
                let error: String? = await auth.register(
                    email: current.email,
                    password: current.password,
                    confirmation: current.confirmation,
                    displayName: current.name,
                    replaceExisting: replace
                )
                finish(error)
            case .forgot:
                await requestReset(email: current.email)
            }
        }
    }

    private func finish(_ error: String?) {
        if let error {
            message = error
        } else {
            dismiss()
        }
    }

    private func requestReset(email: String) async {
        let result: Result<PasswordResetOutcome, AuthError> = await auth.requestPasswordReset(email: email)
        switch result {
        case .failure(let error):
            message = error.errorDescription
        case .success(.emailSent):
            message = "Jeśli konto z tym adresem istnieje, wysłaliśmy link do ustawienia nowego hasła."
        case .success(.localAccountCannotBeRecovered):
            // Bez serwera: nowe hasło = nowe konto lokalne z tym adresem (dane nauki zostają).
            replacesExisting = true
            form.password = ""
            form.confirmation = ""
            mode = .register
            message = "Konta e-mail są na razie zapisane tylko na tym urządzeniu, więc hasła nie da się przypomnieć. Ustaw nowe hasło — konto z tym adresem zostanie założone od nowa. Twoje słówka i postęp zostają."
        }
    }
}

/// Wartości formularza.
struct AuthEmailForm: Equatable {
    var name = ""
    var email = ""
    var password = ""
    var confirmation = ""
}

private struct AuthModePicker: View {
    @Binding var mode: AuthEmailMode

    var body: some View {
        Section {
            Picker("Tryb", selection: $mode) {
                Text("Logowanie").tag(AuthEmailMode.signIn)
                Text("Nowe konto").tag(AuthEmailMode.register)
            }
            .pickerStyle(.segmented)
            .listRowBackground(Color.clear)
            .listRowInsets(EdgeInsets())
        }
    }
}

private enum AuthField: Hashable {
    case name, email, password, confirmation
}

private struct AuthEmailFields: View {
    let mode: AuthEmailMode
    @Binding var form: AuthEmailForm
    let onSubmit: () -> Void

    @FocusState private var focus: AuthField?

    var body: some View {
        Section {
            if mode == .register {
                TextField("Imię (opcjonalnie)", text: $form.name)
                    .textContentType(.name)
                    .submitLabel(.next)
                    .focused($focus, equals: .name)
                    .onSubmit { focus = .email }
            }
            TextField("E-mail", text: $form.email)
                .textContentType(.emailAddress)
                .keyboardType(.emailAddress)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
                .submitLabel(mode == .forgot ? .send : .next)
                .focused($focus, equals: .email)
                .onSubmit {
                    if mode == .forgot {
                        onSubmit()
                    } else {
                        focus = .password
                    }
                }
            if mode != .forgot {
                passwordFields
            }
        } footer: {
            footer
        }
    }

    @ViewBuilder
    private var passwordFields: some View {
        SecureField("Hasło", text: $form.password)
            .textContentType(mode == .register ? UITextContentType.newPassword : UITextContentType.password)
            .submitLabel(mode == .register ? .next : .go)
            .focused($focus, equals: .password)
            .onSubmit {
                if mode == .register {
                    focus = .confirmation
                } else {
                    onSubmit()
                }
            }
        if mode == .register {
            SecureField("Powtórz hasło", text: $form.confirmation)
                .textContentType(.newPassword)
                .submitLabel(.go)
                .focused($focus, equals: .confirmation)
                .onSubmit { onSubmit() }
        }
    }

    @ViewBuilder
    private var footer: some View {
        switch mode {
        case .signIn:
            EmptyView()
        case .register:
            Text("Hasło: co najmniej \(PasswordPolicy.minimumLength) znaków. Konto jest na razie zapisane tylko na tym urządzeniu.")
        case .forgot:
            Text("Podaj adres konta.")
        }
    }
}

private struct AuthEmailActions: View {
    let mode: AuthEmailMode
    let isWorking: Bool
    let replacesExisting: Bool
    let onSubmit: () -> Void
    let onForgot: () -> Void
    let onBack: () -> Void

    private var primaryTitle: String {
        switch mode {
        case .signIn: return "Zaloguj się"
        case .register: return replacesExisting ? "Ustaw nowe hasło" : "Załóż konto"
        case .forgot: return "Dalej"
        }
    }

    var body: some View {
        Section {
            PrimaryButton(primaryTitle, isLoading: isWorking, action: onSubmit)
                .listRowBackground(Color.clear)
                .listRowInsets(EdgeInsets())
            switch mode {
            case .signIn:
                Button("Nie pamiętam hasła", action: onForgot)
                    .frame(maxWidth: .infinity, minHeight: HitTarget.minimum)
                    .listRowBackground(Color.clear)
            case .register, .forgot:
                if mode == .forgot || replacesExisting {
                    Button("Wróć do logowania", action: onBack)
                        .frame(maxWidth: .infinity, minHeight: HitTarget.minimum)
                        .listRowBackground(Color.clear)
                }
            }
        }
    }
}

#Preview("E-mail") {
    AuthEmailSheet()
        .environment(AuthController.inMemory(status: .signedOut))
}
