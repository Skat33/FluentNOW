import XCTest
@testable import FluentKit

/// FEEDBACK-5 J3: avatar personalisation unlocked by level, avatar in the synced settings, badges.
final class AvatarCatalogTests: XCTestCase {
    // MARK: Catalog shape

    func testCatalogIsSortedUniqueAndStartsAtLevelOne() {
        let symbolIDs = AvatarCatalog.symbols.map { $0.id }
        XCTAssertEqual(Set(symbolIDs).count, symbolIDs.count, "Ikony bez duplikatów")
        let colorIDs = AvatarCatalog.colors.map { $0.id }
        XCTAssertEqual(Set(colorIDs).count, colorIDs.count, "Kolory bez duplikatów")

        let symbolLevels = AvatarCatalog.symbols.map { $0.unlockLevel }
        XCTAssertEqual(symbolLevels, symbolLevels.sorted())
        XCTAssertEqual(AvatarCatalog.colors.map { $0.unlockLevel }, AvatarCatalog.colors.map { $0.unlockLevel }.sorted())

        XCTAssertTrue((20...30).contains(AvatarCatalog.symbols.count), "20–30 ikon (FEEDBACK-5 J3)")
        XCTAssertTrue((8...14).contains(AvatarCatalog.colors.count), "8–12+ kolorów")
        XCTAssertTrue(AvatarCatalog.colors.contains { $0.isGradient }, "Gradienty na wyższych poziomach")
        XCTAssertTrue(AvatarCatalog.colors.filter { $0.isGradient }.allSatisfy { $0.unlockLevel >= 15 })

        XCTAssertTrue(AvatarCatalog.isUnlocked(symbol: AvatarCatalog.defaultSymbol, atLevel: 1))
        XCTAssertTrue(AvatarCatalog.isUnlocked(color: AvatarCatalog.defaultColor, atLevel: 1))
    }

    func testNewIconEveryOneToThreeLevels() {
        let levels = Array(Set(AvatarCatalog.symbols.map { $0.unlockLevel })).sorted()
        for (previous, next) in zip(levels, levels.dropFirst()) {
            XCTAssertLessThanOrEqual(next - previous, 3, "Przerwa \(previous) → \(next) dłuższa niż 3 poziomy")
        }
    }

    // MARK: What is unlocked at level N

    func testUnlockedAtLevel() {
        let first = AvatarCatalog.unlocked(atLevel: 1)
        XCTAssertEqual(first.symbols.count, 4)
        XCTAssertEqual(first.colors.map { $0.id }, ["violet", "ocean"])
        XCTAssertEqual(first.nextSymbol?.unlockLevel, 2)
        XCTAssertEqual(first.nextColor?.unlockLevel, 3)
        XCTAssertEqual(first.nextUnlockLevel, 2)

        let ten = AvatarCatalog.unlocked(atLevel: 10)
        XCTAssertTrue(ten.symbols.allSatisfy { $0.unlockLevel <= 10 })
        XCTAssertTrue(ten.symbols.contains { $0.id == "graduationcap.fill" })
        XCTAssertFalse(ten.colors.contains { $0.isGradient })

        let zeroOrNegative = AvatarCatalog.unlocked(atLevel: -5)
        XCTAssertEqual(zeroOrNegative.level, 1)
        XCTAssertEqual(zeroOrNegative.symbols, first.symbols)

        let max = AvatarCatalog.unlocked(atLevel: 100)
        XCTAssertEqual(max.symbols.count, AvatarCatalog.symbols.count)
        XCTAssertEqual(max.colors.count, AvatarCatalog.colors.count)
        XCTAssertNil(max.nextSymbol)
        XCTAssertNil(max.nextColor)
        XCTAssertNil(max.nextUnlockLevel)
    }

    func testUnlockedGrowsMonotonically() {
        var previousSymbols = 0
        var previousColors = 0
        for level in 1...50 {
            let unlocks = AvatarCatalog.unlocked(atLevel: level)
            XCTAssertGreaterThanOrEqual(unlocks.symbols.count, previousSymbols)
            XCTAssertGreaterThanOrEqual(unlocks.colors.count, previousColors)
            previousSymbols = unlocks.symbols.count
            previousColors = unlocks.colors.count
        }
    }

    func testIsUnlockedRejectsUnknownAndLockedIDs() {
        XCTAssertFalse(AvatarCatalog.isUnlocked(symbol: "crown.fill", atLevel: 39))
        XCTAssertTrue(AvatarCatalog.isUnlocked(symbol: "crown.fill", atLevel: 40))
        XCTAssertFalse(AvatarCatalog.isUnlocked(symbol: "no.such.symbol", atLevel: 100))
        XCTAssertFalse(AvatarCatalog.isUnlocked(color: "galaxy", atLevel: 29))
        XCTAssertTrue(AvatarCatalog.isUnlocked(color: "galaxy", atLevel: 30))
        XCTAssertFalse(AvatarCatalog.isUnlocked(color: "plaid", atLevel: 100))
    }

    func testNewlyUnlockedBetweenLevels() {
        let delta = AvatarCatalog.newlyUnlocked(fromLevel: 4, toLevel: 5)
        XCTAssertEqual(delta.symbols.map { $0.id }, ["airplane"])
        XCTAssertEqual(delta.colors.map { $0.id }, ["sunset"])
        XCTAssertTrue(AvatarCatalog.newlyUnlocked(fromLevel: 5, toLevel: 5).isEmpty)
        XCTAssertTrue(AvatarCatalog.newlyUnlocked(fromLevel: 8, toLevel: 3).isEmpty)
        XCTAssertFalse(AvatarCatalog.newlyUnlocked(fromLevel: 1, toLevel: 2).symbols.isEmpty)
    }

    func testResolvedFallsBackForLockedOrUnknownChoice() {
        let chosen = LearnerAvatar(symbol: "crown.fill", color: "gold", nickname: "Ola", updatedAt: 5)
        let low = AvatarCatalog.resolved(chosen, level: 3)
        XCTAssertEqual(low.symbol, AvatarCatalog.defaultSymbol)
        XCTAssertEqual(low.color, AvatarCatalog.defaultColor)
        XCTAssertEqual(low.nickname, "Ola", "Pseudonim zostaje")
        XCTAssertEqual(AvatarCatalog.resolved(chosen, level: 40), chosen)

        let unknown = AvatarCatalog.resolved(LearnerAvatar(symbol: "x", color: "y"), level: 100)
        XCTAssertEqual(unknown.symbol, AvatarCatalog.defaultSymbol)
        XCTAssertEqual(unknown.color, AvatarCatalog.defaultColor)
        XCTAssertEqual(AvatarCatalog.resolved(nil, level: 1), LearnerAvatar())
        XCTAssertFalse(AvatarCatalog.stops(forColor: "nope").isEmpty)
    }

    // MARK: Avatar in settings (backward compatible, synced)

    func testAvatarRoundTripsAndOldSettingsDecode() throws {
        var settings = LearnerSettings(goal: 20)
        settings.avatar = LearnerAvatar(symbol: "cat.fill", color: "mint", nickname: "Kasia", updatedAt: 42)
        let data = try JSONEncoder().encode(settings)
        let decoded = try JSONDecoder().decode(LearnerSettings.self, from: data)
        XCTAssertEqual(decoded.avatar, settings.avatar)

        let old = Data(#"{"goal":20,"reminder":"19:00","accent":"en-US","slow":false}"#.utf8)
        let legacy = try JSONDecoder().decode(LearnerSettings.self, from: old)
        XCTAssertNil(legacy.avatar)
        let reencoded = try JSONEncoder().encode(legacy)
        XCTAssertFalse(String(decoding: reencoded, as: UTF8.self).contains("avatar"), "Brak awatara → klucz pominięty w eksporcie")

        let broken = Data(#"{"goal":20,"avatar":"zepsute"}"#.utf8)
        XCTAssertNil(try JSONDecoder().decode(LearnerSettings.self, from: broken).avatar)

        let partial = Data(#"{"goal":20,"avatar":{"symbol":"star.fill"}}"#.utf8)
        let filled = try JSONDecoder().decode(LearnerSettings.self, from: partial).avatar
        XCTAssertEqual(filled?.symbol, "star.fill")
        XCTAssertEqual(filled?.color, AvatarCatalog.defaultColor)
    }

    func testNormalizationTrimsNickname() {
        let long = String(repeating: "a", count: 80)
        let avatar = LearnerAvatar(symbol: "  ", color: "", nickname: "  \(long)\n", updatedAt: .nan).normalized()
        XCTAssertEqual(avatar.symbol, AvatarCatalog.defaultSymbol)
        XCTAssertEqual(avatar.color, AvatarCatalog.defaultColor)
        XCTAssertEqual(avatar.nickname?.count, LearnerAvatar.maxNicknameLength)
        XCTAssertEqual(avatar.updatedAt, 0)
        XCTAssertNil(LearnerAvatar.cleanNickname("   \n "))
        XCTAssertEqual(LearnerAvatar.cleanNickname(" Jan\nKowalski "), "Jan Kowalski")

        var state = LearnerState(settings: LearnerSettings(goal: 20))
        state.settings.avatar = LearnerAvatar(nickname: "  Ola  ")
        XCTAssertEqual(StateMigration.migrate(state).settings.avatar?.nickname, "Ola")
    }

    func testMergeKeepsNewerAvatarIndependentlyOfProfile() {
        var local = LearnerState(settings: LearnerSettings(goal: 20))
        var remote = LearnerState(settings: LearnerSettings(goal: 20))
        local.settings.avatar = LearnerAvatar(symbol: "star.fill", updatedAt: 10)
        remote.settings.avatar = LearnerAvatar(symbol: "leaf.fill", updatedAt: 20)
        local.settings.profile = LearnerProfile(goals: [.travel], updatedAt: 30)
        remote.settings.profile = LearnerProfile(goals: [.work], updatedAt: 5)

        let merged = StateSync.mergeStates(local: local, remote: remote)
        XCTAssertEqual(merged.settings.avatar?.symbol, "leaf.fill", "Nowszy awatar z drugiego urządzenia")
        XCTAssertEqual(merged.settings.profile?.goals, [.travel], "Profil scalany osobno")

        let reverse = StateSync.mergeStates(local: remote, remote: local)
        XCTAssertEqual(reverse.settings.avatar?.symbol, "leaf.fill")

        var bare = LearnerState(settings: LearnerSettings(goal: 20))
        bare.settings.avatar = nil
        XCTAssertEqual(StateSync.mergeStates(local: bare, remote: remote).settings.avatar?.symbol, "leaf.fill", "Brak awatara lokalnie nie kasuje zdalnego")
    }

    // MARK: Badges

    func testLongestStreak() {
        XCTAssertEqual(ProfileAchievements.longestStreak(days: []), 0)
        XCTAssertEqual(ProfileAchievements.longestStreak(days: [5]), 1)
        XCTAssertEqual(ProfileAchievements.longestStreak(days: [3, 1, 2, 2, 10, 11]), 3)
        XCTAssertEqual(ProfileAchievements.longestStreak(days: [1, 3, 5]), 1)
    }

    func testAchievementsProgress() {
        let input = AchievementInput(wordCount: 120, masteredMeanings: 10, longestStreak: 7, level: 4, readingsCompleted: 0)
        let badges = ProfileAchievements.evaluate(input)
        XCTAssertEqual(Set(badges.map { $0.id }).count, badges.count)
        func badge(_ id: String) -> ProfileAchievement? { badges.first { $0.id == id } }
        XCTAssertEqual(badge("first-word")?.isEarned, true)
        XCTAssertEqual(badge("words-100")?.isEarned, true)
        XCTAssertEqual(badge("words-500")?.isEarned, false)
        XCTAssertEqual(badge("streak-7")?.isEarned, true)
        XCTAssertEqual(badge("streak-30")?.isEarned, false)
        XCTAssertEqual(badge("mastered-50")?.progress ?? 0, 0.2, accuracy: 0.0001)
        XCTAssertEqual(badge("reader-10")?.progress, 0)
        let fresh = ProfileAchievements.evaluate(AchievementInput(level: 1))
        XCTAssertEqual(fresh.filter { $0.isEarned }.count, 0, "Nowy użytkownik nie ma odznak")
    }

    func testAchievementInputFromHistory() {
        var reviews: [Review] = []
        for d in 0..<8 where d != 3 {
            reviews.append(Review(id: "r\(d)", wordId: "w1", meaningId: "m1", skill: .recall, correct: true, at: testNow + Double(d) * day, seconds: 5, confidence: 2, hint: false, error: "", before: 0, after: 10))
        }
        let state = LearnerState(reviews: reviews, settings: LearnerSettings(goal: 20))
        let input = ProfileAchievements.input(from: state)
        XCTAssertEqual(input.longestStreak, 4, "Dni 4–7 bez przerwy")
        XCTAssertEqual(input.wordCount, 0)
        XCTAssertGreaterThanOrEqual(input.level, 1)
    }
}
