import SwiftUI
import FluentKit

/// Kolory awatara z katalogu FluentKit (`AvatarCatalog`, `0xRRGGBB`) → SwiftUI.
enum ProfileAvatarPalette {
    static func color(_ hex: UInt32) -> Color {
        Color(
            .sRGB,
            red: Double((hex >> 16) & 0xFF) / 255,
            green: Double((hex >> 8) & 0xFF) / 255,
            blue: Double(hex & 0xFF) / 255,
            opacity: 1
        )
    }

    /// Wypełnienie: kolor jednolity albo gradient (od lewego górnego rogu).
    static func fill(forColor id: String) -> LinearGradient {
        let stops = AvatarCatalog.stops(forColor: id).map { (hex: UInt32) -> Color in color(hex) }
        let colors = stops.count > 1 ? stops : [stops.first ?? Palette.accentFill, stops.first ?? Palette.accentFill]
        return LinearGradient(colors: colors, startPoint: .topLeading, endPoint: .bottomTrailing)
    }
}

/// Okrągły awatar: ikona SF Symbols na kolorze/gradiencie. Pokazuje to, co podano —
/// rozstrzygnięcie blokad robi wywołujący (`AvatarCatalog.resolved`).
struct ProfileAvatarView: View {
    let avatar: LearnerAvatar
    var size: CGFloat = 40

    var body: some View {
        ZStack {
            Circle()
                .fill(ProfileAvatarPalette.fill(forColor: avatar.color))
            Image(systemName: avatar.symbol)
                .font(.system(size: size * 0.46, weight: .semibold))
                .foregroundStyle(Color.white)
        }
        .frame(width: size, height: size)
        .accessibilityHidden(true)
    }
}

/// Awatar w nagłówku ekranu Dzisiaj → panel użytkownika (arkusz `AppSheet.profile`).
/// Tani odczyt: tylko `settings.avatar` (bez liczenia poziomu — wybór w panelu i tak dopuszcza
/// wyłącznie odblokowane ikony; nieznane identyfikatory zastępuje domyślny wygląd).
struct ProfileAvatarButton: View {
    @Environment(LearningStore.self) private var store
    @Environment(AppRouter.self) private var router
    @Environment(AuthController.self) private var auth

    var body: some View {
        Button {
            router.presentProfile()
        } label: {
            ProfileAvatarView(avatar: AvatarCatalog.resolved(store.settings.avatar, level: XPRules.maxLevel), size: 32)
                .contentShape(Circle())
                .frame(minWidth: HitTarget.minimum, minHeight: HitTarget.minimum)
        }
        .buttonStyle(.plain)
        .accessibilityLabel(Text("Profil"))
        .accessibilityHint(Text(auth.isGuest ? "Poziom, odznaki i logowanie" : "Poziom, odznaki i konto"))
    }
}

#Preview("Awatary") {
    HStack(spacing: Spacing.s) {
        ProfileAvatarView(avatar: LearnerAvatar(), size: 56)
        ProfileAvatarView(avatar: LearnerAvatar(symbol: "cat.fill", color: "aurora"), size: 56)
        ProfileAvatarView(avatar: LearnerAvatar(symbol: "crown.fill", color: "gold"), size: 56)
    }
    .padding()
}
