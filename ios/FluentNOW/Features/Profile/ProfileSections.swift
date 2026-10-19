import SwiftUI
import FluentKit

// MARK: - Nagłówek: awatar, nazwa, konto

/// Awatar (→ wybór awatara), nazwa (edytowalna), e-mail i dostawca logowania.
struct ProfileHeaderCard: View {
    let level: Int

    @Environment(LearningStore.self) private var store
    @Environment(AuthController.self) private var auth
    @State private var isEditingName = false
    @State private var nameDraft = ""

    private var avatar: LearnerAvatar {
        AvatarCatalog.resolved(store.settings.avatar, level: level)
    }

    private var displayName: String {
        if let nickname = store.settings.avatar?.nickname { return nickname }
        if let name = auth.session?.preferredName { return name }
        return auth.isGuest ? "Gość" : "Uczeń"
    }

    var body: some View {
        Card {
            HStack(spacing: Spacing.m) {
                NavigationLink(value: ProfileRoute.avatar) {
                    ProfileAvatarEditBadge(avatar: avatar)
                }
                .buttonStyle(.plain)
                .accessibilityLabel(Text("Zmień awatar"))
                VStack(alignment: .leading, spacing: Spacing.xxs) {
                    ProfileNameRow(name: displayName, onEdit: startEditing)
                    ProfileAccountLine()
                }
                Spacer(minLength: 0)
            }
        }
        .alert("Twoje imię", isPresented: $isEditingName) {
            TextField("Imię lub pseudonim", text: $nameDraft)
                .textContentType(.nickname)
            Button("Zapisz") { saveName() }
            Button("Anuluj", role: .cancel) {}
        } message: {
            Text("Widoczne tylko w Twoim profilu. Puste pole przywraca nazwę z konta.")
        }
    }

    private func startEditing() {
        nameDraft = store.settings.avatar?.nickname ?? auth.session?.preferredName ?? ""
        isEditingName = true
    }

    private func saveName() {
        let nickname: String? = LearnerAvatar.cleanNickname(nameDraft)
        let now: Timestamp = store.now()
        store.update(.edit) { (state: inout LearnerState) in
            var updated = state.settings.avatar ?? LearnerAvatar()
            updated.nickname = nickname
            updated.updatedAt = now
            state.settings.avatar = updated
        }
    }
}

private struct ProfileAvatarEditBadge: View {
    let avatar: LearnerAvatar

    var body: some View {
        ProfileAvatarView(avatar: avatar, size: 72)
            .overlay(alignment: .bottomTrailing) {
                Image(systemName: "pencil.circle.fill")
                    .font(.system(size: 22))
                    .symbolRenderingMode(.palette)
                    .foregroundStyle(Color.white, Palette.accentFill)
                    .accessibilityHidden(true)
            }
    }
}

private struct ProfileNameRow: View {
    let name: String
    let onEdit: () -> Void

    var body: some View {
        HStack(spacing: Spacing.xs) {
            Text(name)
                .font(FluentFont.title)
                .foregroundStyle(Palette.ink)
                .lineLimit(2)
            Button(action: onEdit) {
                Image(systemName: "pencil")
                    .font(FluentFont.callout)
                    .frame(minWidth: HitTarget.minimum, minHeight: HitTarget.minimum)
            }
            .buttonStyle(.borderless)
            .accessibilityLabel(Text("Zmień imię"))
        }
    }
}

/// „Zalogowano przez Apple · adres” albo „Bez konta (gość)”.
private struct ProfileAccountLine: View {
    @Environment(AuthController.self) private var auth

    var body: some View {
        if let session = auth.session {
            Label {
                Text(accountText(session))
            } icon: {
                Image(systemName: session.provider.systemImage)
            }
            .font(FluentFont.footnote)
            .foregroundStyle(Palette.inkSecondary)
            .lineLimit(2)
        } else {
            Label("Bez konta (gość)", systemImage: "person.crop.circle.badge.questionmark")
                .font(FluentFont.footnote)
                .foregroundStyle(Palette.inkSecondary)
        }
    }

    private func accountText(_ session: AuthSession) -> String {
        let provider = "Zalogowano: \(session.provider.namePl)"
        guard let email = session.email, !email.isEmpty else { return provider }
        return "\(provider) · \(email)"
    }
}

// MARK: - Poziom i ranga

/// Poziom, ranga (G5), postęp do następnego poziomu i najbliższa nagroda.
struct ProfileLevelCard: View {
    let level: XPLevel
    let todayXP: Int

    private var nextUnlock: Int? {
        AvatarCatalog.unlocked(atLevel: level.level).nextUnlockLevel
    }

    var body: some View {
        Card(style: .tinted(.accent)) {
            HStack(alignment: .firstTextBaseline) {
                Label(level.rank.namePl, systemImage: level.rank.systemImage)
                    .font(FluentFont.headline)
                    .foregroundStyle(Palette.accentSoftInk)
                Spacer(minLength: Spacing.xs)
                Text("Poziom \(level.level)")
                    .font(FluentFont.numberSmall)
                    .foregroundStyle(Palette.accentSoftInk)
            }
            LinearProgressBar(progress: level.fraction)
            Text(progressText)
                .font(FluentFont.footnote)
                .foregroundStyle(Palette.ink)
            if let nextUnlock {
                Label("Poziom \(nextUnlock): nowe wzory awatara", systemImage: "lock.open")
                    .font(FluentFont.caption)
                    .foregroundStyle(Palette.inkSecondary)
            }
        }
        .accessibilityElement(children: .combine)
    }

    private var progressText: String {
        let today = todayXP > 0 ? "Dziś +\(todayXP) XP. " : ""
        if level.isMaxLevel { return "\(today)Najwyższy poziom — gratulacje!" }
        return "\(today)Do poziomu \(level.level + 1): \(level.xpToNextLevel) XP (razem \(level.totalXP) XP)."
    }
}

// MARK: - Statystyki skrótowe

struct ProfileStatsGrid: View {
    let snapshot: ProfileSnapshot

    private let columns = [GridItem(.flexible(), spacing: Spacing.s), GridItem(.flexible(), spacing: Spacing.s)]

    var body: some View {
        LazyVGrid(columns: columns, spacing: Spacing.s) {
            StatTile(title: "Słowa", value: "\(snapshot.wordCount)", systemImage: "text.book.closed")
            StatTile(title: "Opanowane", value: "\(snapshot.masteredMeanings)", systemImage: "checkmark.seal", tone: .success)
            StatTile(title: "Seria", value: LibraryText.plural(snapshot.streak, one: "\(snapshot.streak) dzień", few: "\(snapshot.streak) dni", many: "\(snapshot.streak) dni"), systemImage: "flame", tone: .warning)
            StatTile(title: "Dni nauki", value: "\(snapshot.studyDays)", systemImage: "calendar", tone: .info)
        }
    }
}

// MARK: - Odznaki

struct ProfileBadgesSection: View {
    let achievements: [ProfileAchievement]

    private let columns = [GridItem(.adaptive(minimum: 100), spacing: Spacing.s)]

    private var earnedCount: Int {
        achievements.filter { $0.isEarned }.count
    }

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.s) {
            SectionHeader("Odznaki", subtitle: "\(earnedCount) z \(achievements.count)")
            LazyVGrid(columns: columns, spacing: Spacing.s) {
                ForEach(achievements) { (achievement: ProfileAchievement) in
                    ProfileBadgeCell(achievement: achievement)
                }
            }
        }
    }
}

private struct ProfileBadgeCell: View {
    let achievement: ProfileAchievement

    var body: some View {
        VStack(spacing: Spacing.xxs) {
            ZStack {
                Circle()
                    .fill(achievement.isEarned ? Palette.accentSoft : Palette.surfaceMuted)
                Image(systemName: achievement.isEarned ? achievement.systemImage : "lock.fill")
                    .font(.system(size: 20, weight: .semibold))
                    .foregroundStyle(achievement.isEarned ? Palette.accent : Palette.inkTertiary)
            }
            .frame(width: 48, height: 48)
            Text(achievement.titlePl)
                .font(FluentFont.caption)
                .foregroundStyle(Palette.ink)
                .multilineTextAlignment(.center)
                .lineLimit(2)
            Text(achievement.isEarned ? achievement.detailPl : "\(min(achievement.current, achievement.target))/\(achievement.target)")
                .font(FluentFont.caption)
                .foregroundStyle(Palette.inkSecondary)
                .multilineTextAlignment(.center)
                .lineLimit(2)
        }
        .padding(Spacing.xs)
        .frame(maxWidth: .infinity, minHeight: 132, alignment: .top)
        .fluentCardBackground(.solid, cornerRadius: Radius.medium)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text(accessibilityText))
    }

    private var accessibilityText: String {
        if achievement.isEarned {
            return "Odznaka \(achievement.titlePl), zdobyta. \(achievement.detailPl)."
        }
        return "Odznaka \(achievement.titlePl), jeszcze nie zdobyta. \(achievement.detailPl). Postęp \(min(achievement.current, achievement.target)) z \(achievement.target)."
    }
}

// MARK: - Skróty

/// Profil nauki (G4), Postępy, Ustawienia.
struct ProfileLinksSection: View {
    @Environment(AppRouter.self) private var router

    var body: some View {
        Card(padding: 0, spacing: 0) {
            NavigationLink(value: ProfileRoute.learningProfile) {
                ProfileLinkRow(title: "Twój profil nauki", systemImage: "person.text.rectangle", detail: "Cele, poziom, zainteresowania")
            }
            .buttonStyle(.plain)
            Divider().padding(.leading, Spacing.m)
            Button {
                open(.progress)
            } label: {
                ProfileLinkRow(title: "Postępy", systemImage: AppTab.progress.systemImage, detail: "Wykresy, XP i raport tygodnia")
            }
            .buttonStyle(.plain)
            Divider().padding(.leading, Spacing.m)
            Button {
                open(.settings)
            } label: {
                ProfileLinkRow(title: "Ustawienia", systemImage: AppTab.settings.systemImage, detail: "Cel, przypomnienia, głos, dane")
            }
            .buttonStyle(.plain)
        }
    }

    private func open(_ tab: AppTab) {
        router.dismissSheet()
        router.selectedTab = tab
    }
}

private struct ProfileLinkRow: View {
    let title: String
    let systemImage: String
    let detail: String

    var body: some View {
        HStack(spacing: Spacing.s) {
            Image(systemName: systemImage)
                .font(FluentFont.headline)
                .foregroundStyle(Palette.accent)
                .frame(width: 28)
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(FluentFont.bodyEmphasized)
                    .foregroundStyle(Palette.ink)
                Text(detail)
                    .font(FluentFont.caption)
                    .foregroundStyle(Palette.inkSecondary)
            }
            Spacer(minLength: 0)
            Image(systemName: "chevron.right")
                .font(FluentFont.footnote)
                .foregroundStyle(Palette.inkTertiary)
                .accessibilityHidden(true)
        }
        .padding(Spacing.m)
        .frame(minHeight: HitTarget.minimum)
        .contentShape(Rectangle())
    }
}
