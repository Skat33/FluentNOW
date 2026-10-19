import SwiftUI
import FluentKit

/// Wybór ikony i koloru awatara (FEEDBACK-5 J3). Zablokowane wzory są widoczne z kłódką
/// i „Poziom N”; wybór zapisuje się od razu w `settings.avatar` (synchronizacja iCloud).
struct AvatarPickerScreen: View {
    let level: Int

    @Environment(LearningStore.self) private var store

    private var current: LearnerAvatar {
        AvatarCatalog.resolved(store.settings.avatar, level: level)
    }

    private var unlocks: AvatarUnlocks {
        AvatarCatalog.unlocked(atLevel: level)
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Spacing.l) {
                AvatarPickerPreview(avatar: current, level: level, nextUnlockLevel: unlocks.nextUnlockLevel)
                SectionHeader("Ikona", subtitle: "\(unlocks.symbols.count) z \(AvatarCatalog.symbols.count) odblokowanych")
                AvatarSymbolGrid(selected: current.symbol, color: current.color, level: level, onSelect: selectSymbol)
                SectionHeader("Kolor", subtitle: "\(unlocks.colors.count) z \(AvatarCatalog.colors.count) odblokowanych")
                AvatarColorGrid(selected: current.color, level: level, onSelect: selectColor)
            }
            .frame(maxWidth: Spacing.readableWidth)
            .padding(Spacing.screen)
            .frame(maxWidth: .infinity)
        }
        .background(Palette.background.ignoresSafeArea())
        .navigationTitle("Awatar")
        .navigationBarTitleDisplayMode(.inline)
    }

    private func selectSymbol(_ id: String) {
        guard AvatarCatalog.isUnlocked(symbol: id, atLevel: level) else { return }
        save { (avatar: inout LearnerAvatar) in avatar.symbol = id }
    }

    private func selectColor(_ id: String) {
        guard AvatarCatalog.isUnlocked(color: id, atLevel: level) else { return }
        save { (avatar: inout LearnerAvatar) in avatar.color = id }
    }

    private func save(_ change: (inout LearnerAvatar) -> Void) {
        var updated = current
        change(&updated)
        updated.nickname = store.settings.avatar?.nickname
        updated.updatedAt = store.now()
        let value = updated
        store.update(.edit) { (state: inout LearnerState) in
            state.settings.avatar = value
        }
    }
}

private struct AvatarPickerPreview: View {
    let avatar: LearnerAvatar
    let level: Int
    let nextUnlockLevel: Int?

    var body: some View {
        HStack(spacing: Spacing.m) {
            ProfileAvatarView(avatar: avatar, size: 88)
            VStack(alignment: .leading, spacing: Spacing.xxs) {
                Text("Poziom \(level)")
                    .font(FluentFont.headline)
                    .foregroundStyle(Palette.ink)
                Text(caption)
                    .font(FluentFont.footnote)
                    .foregroundStyle(Palette.inkSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .accessibilityElement(children: .combine)
    }

    private var caption: String {
        guard let next = nextUnlockLevel else { return "Wszystkie wzory odblokowane." }
        return "Nowe ikony i kolory odblokowujesz, zdobywając XP. Następne na poziomie \(next)."
    }
}

private struct AvatarSymbolGrid: View {
    let selected: String
    let color: String
    let level: Int
    let onSelect: (String) -> Void

    private let columns = [GridItem(.adaptive(minimum: 64), spacing: Spacing.s)]

    var body: some View {
        LazyVGrid(columns: columns, spacing: Spacing.s) {
            ForEach(AvatarCatalog.symbols) { (option: AvatarSymbolOption) in
                AvatarSymbolCell(option: option, color: color, isSelected: option.id == selected, isLocked: option.unlockLevel > level) {
                    onSelect(option.id)
                }
            }
        }
    }
}

private struct AvatarSymbolCell: View {
    let option: AvatarSymbolOption
    let color: String
    let isSelected: Bool
    let isLocked: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: Spacing.xxs) {
                ZStack {
                    if isLocked {
                        Circle().fill(Palette.surfaceMuted)
                        Image(systemName: option.id)
                            .font(.system(size: 22, weight: .semibold))
                            .foregroundStyle(Palette.inkTertiary)
                    } else {
                        ProfileAvatarView(avatar: LearnerAvatar(symbol: option.id, color: color), size: 52)
                    }
                }
                .frame(width: 52, height: 52)
                .overlay {
                    Circle()
                        .strokeBorder(isSelected ? Palette.accent : Color.clear, lineWidth: 3)
                        .padding(-4)
                }
                AvatarLockCaption(isLocked: isLocked, unlockLevel: option.unlockLevel, name: option.namePl)
            }
            .frame(maxWidth: .infinity, minHeight: 84)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .disabled(isLocked)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text(option.namePl))
        .accessibilityValue(Text(isLocked ? "Zablokowane, poziom \(option.unlockLevel)" : (isSelected ? "Wybrane" : "")))
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }
}

private struct AvatarColorGrid: View {
    let selected: String
    let level: Int
    let onSelect: (String) -> Void

    private let columns = [GridItem(.adaptive(minimum: 64), spacing: Spacing.s)]

    var body: some View {
        LazyVGrid(columns: columns, spacing: Spacing.s) {
            ForEach(AvatarCatalog.colors) { (option: AvatarColorOption) in
                AvatarColorCell(option: option, isSelected: option.id == selected, isLocked: option.unlockLevel > level) {
                    onSelect(option.id)
                }
            }
        }
    }
}

private struct AvatarColorCell: View {
    let option: AvatarColorOption
    let isSelected: Bool
    let isLocked: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: Spacing.xxs) {
                ZStack {
                    Circle()
                        .fill(ProfileAvatarPalette.fill(forColor: option.id))
                        .opacity(isLocked ? 0.35 : 1)
                    if isLocked {
                        Image(systemName: "lock.fill")
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundStyle(Color.white)
                    }
                }
                .frame(width: 44, height: 44)
                .overlay {
                    Circle()
                        .strokeBorder(isSelected ? Palette.accent : Color.clear, lineWidth: 3)
                        .padding(-4)
                }
                AvatarLockCaption(isLocked: isLocked, unlockLevel: option.unlockLevel, name: option.namePl)
            }
            .frame(maxWidth: .infinity, minHeight: 76)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .disabled(isLocked)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text(option.isGradient ? "\(option.namePl), gradient" : option.namePl))
        .accessibilityValue(Text(isLocked ? "Zablokowane, poziom \(option.unlockLevel)" : (isSelected ? "Wybrane" : "")))
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }
}

/// Podpis pod wzorem: nazwa albo kłódka i „Poziom N”.
private struct AvatarLockCaption: View {
    let isLocked: Bool
    let unlockLevel: Int
    let name: String

    var body: some View {
        if isLocked {
            Label("Poziom \(unlockLevel)", systemImage: "lock.fill")
                .labelStyle(.titleAndIcon)
                .font(FluentFont.caption)
                .foregroundStyle(Palette.inkSecondary)
                .lineLimit(1)
                .minimumScaleFactor(0.8)
        } else {
            Text(name)
                .font(FluentFont.caption)
                .foregroundStyle(Palette.ink)
                .lineLimit(1)
                .minimumScaleFactor(0.8)
        }
    }
}

#Preview("Awatar — poziom 6") {
    NavigationStack {
        AvatarPickerScreen(level: 6)
    }
    .fluentPreviewEnvironment()
}
