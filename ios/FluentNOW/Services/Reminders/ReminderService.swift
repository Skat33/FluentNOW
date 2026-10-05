import Foundation
import Observation
import UserNotifications
import FluentKit

/// Lokalne przypomnienia o nauce (`UNUserNotificationCenter`).
///
/// Zasady „bez spamu”: najwyżej jedno powiadomienie dziennie o porze z ustawień; jeśli dzisiejszy
/// cel jest osiągnięty albo pora minęła — pierwsze dopiero jutro. Planujemy pojedyncze
/// powiadomienia na kolejne dni (zamiast powtarzalnego), żeby móc pominąć dzisiejsze; plan
/// jest odświeżany przy każdym przejściu aplikacji w tło (z aktualną liczbą powtórek).
@MainActor
@Observable
final class ReminderService {
    enum Authorization {
        case notDetermined
        case authorized
        case denied
    }

    private(set) var authorization: Authorization = .notDetermined

    /// Otwarcie linku po dotknięciu powiadomienia (ustawia `FluentNOWApp` → `router.handle(url:)`).
    /// Link z powiadomienia dotkniętego, zanim UI ustawiło `onOpenURL` (zimny start) — dostarczany później.
    @ObservationIgnored var onOpenURL: (@MainActor (URL) -> Void)? {
        didSet {
            guard let onOpenURL, let url = pendingURL else { return }
            pendingURL = nil
            onOpenURL(url)
        }
    }
    @ObservationIgnored private var pendingURL: URL?

    /// Ile dni naprzód planujemy powiadomienia.
    nonisolated static let daysAhead = 14
    nonisolated static let identifierPrefix = "fluent.reminder."
    nonisolated static let deepLink = "fluentnow://study/start?mode=mixed"
    nonisolated static let deepLinkKey = "deeplink"

    @ObservationIgnored private let enabled: Bool
    @ObservationIgnored private let delegate = ReminderNotificationDelegate()

    /// - Parameter enabled: `false` w podglądzie i testach (bez systemowych powiadomień).
    init(enabled: Bool = true) {
        self.enabled = enabled
        guard enabled else { return }
        delegate.onOpen = { [weak self] url in
            guard let self else { return }
            if let handler = self.onOpenURL {
                handler(url)
            } else {
                self.pendingURL = url
            }
        }
        UNUserNotificationCenter.current().delegate = delegate
    }

    /// Odczytuje bieżący stan zgody (np. po powrocie z Ustawień systemu).
    func refreshAuthorization() async {
        guard enabled else { return }
        let settings = await UNUserNotificationCenter.current().notificationSettings()
        authorization = Self.map(settings.authorizationStatus)
    }

    /// Prosi o zgodę (tylko po akcji użytkownika, np. włączeniu przełącznika).
    func requestAuthorization() async -> Authorization {
        guard enabled else { return authorization }
        do {
            let granted = try await UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .badge])
            authorization = granted ? .authorized : .denied
        } catch {
            await refreshAuthorization()
        }
        return authorization
    }

    /// Planuje (lub usuwa) przypomnienia.
    func reschedule(settings: LearnerSettings, enabled isOn: Bool, dueCount: Int, goalReachedToday: Bool) async {
        guard enabled else { return }
        let center = UNUserNotificationCenter.current()
        let pending = await center.pendingNotificationRequests()
        let ours = pending.map(\.identifier).filter { $0.hasPrefix(Self.identifierPrefix) }
        center.removePendingNotificationRequests(withIdentifiers: ours)

        guard isOn else { return }
        await refreshAuthorization()
        guard authorization == .authorized else { return }

        let plan = Self.plan(
            now: Date(),
            hour: settings.reminderComponents.hour,
            minute: settings.reminderComponents.minute,
            goalReachedToday: goalReachedToday,
            days: Self.daysAhead
        )
        for (offset, components) in plan.enumerated() {
            let content = UNMutableNotificationContent()
            let isFirst = offset == 0
            content.title = "FluentNOW"
            content.body = Self.body(dueCount: isFirst ? dueCount : nil)
            content.sound = .default
            content.userInfo = [Self.deepLinkKey: Self.deepLink]
            content.threadIdentifier = "fluent.reminder"
            let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: false)
            let request = UNNotificationRequest(identifier: Self.identifierPrefix + String(offset), content: content, trigger: trigger)
            try? await center.add(request)
        }
    }

    /// Usuwa wszystkie zaplanowane przypomnienia.
    func cancelAll() async {
        guard enabled else { return }
        let center = UNUserNotificationCenter.current()
        let pending = await center.pendingNotificationRequests()
        center.removePendingNotificationRequests(withIdentifiers: pending.map(\.identifier).filter { $0.hasPrefix(Self.identifierPrefix) })
    }

    // MARK: - Logika (testowalna)

    /// Daty kolejnych przypomnień: dziś (jeśli pora jeszcze nie minęła i cel nieosiągnięty), potem codziennie.
    nonisolated static func plan(now: Date, hour: Int, minute: Int, goalReachedToday: Bool, days: Int, calendar: Calendar = .current) -> [DateComponents] {
        guard days > 0 else { return [] }
        let startOfToday = calendar.startOfDay(for: now)
        guard let todayAtTime = calendar.date(bySettingHour: hour, minute: minute, second: 0, of: startOfToday) else { return [] }
        let skipToday = goalReachedToday || todayAtTime <= now
        var result: [DateComponents] = []
        var dayOffset = skipToday ? 1 : 0
        while result.count < days {
            if let day = calendar.date(byAdding: .day, value: dayOffset, to: startOfToday) {
                var components = calendar.dateComponents([.year, .month, .day], from: day)
                components.hour = hour
                components.minute = minute
                result.append(components)
            }
            dayOffset += 1
            if dayOffset > days + 1 { break }
        }
        return result
    }

    /// Treść powiadomienia (z liczbą powtórek dla najbliższego).
    nonisolated static func body(dueCount: Int?) -> String {
        guard let dueCount, dueCount > 0 else {
            return "Czas na krótką powtórkę — 5 minut dziennie robi różnicę."
        }
        return "Masz \(dueCount) \(wordsForm(dueCount)) do powtórki. Wystarczy 5 minut."
    }

    /// Polska odmiana: 1 słówko, 2–4 słówka, 5+ słówek (12–14 słówek).
    nonisolated static func wordsForm(_ count: Int) -> String {
        if count == 1 { return "słówko" }
        let lastDigit = count % 10
        let lastTwo = count % 100
        if (2...4).contains(lastDigit) && !(12...14).contains(lastTwo) { return "słówka" }
        return "słówek"
    }

    private static func map(_ status: UNAuthorizationStatus) -> Authorization {
        switch status {
        case .notDetermined: return .notDetermined
        case .denied: return .denied
        case .authorized, .provisional, .ephemeral: return .authorized
        @unknown default: return .notDetermined
        }
    }
}

/// Delegat powiadomień: dotknięcie → deep link; w trakcie korzystania z aplikacji nie pokazujemy banera.
private final class ReminderNotificationDelegate: NSObject, UNUserNotificationCenterDelegate {
    var onOpen: (@MainActor (URL) -> Void)?

    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification,
        withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void
    ) {
        completionHandler([])
    }

    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        didReceive response: UNNotificationResponse,
        withCompletionHandler completionHandler: @escaping () -> Void
    ) {
        let link = response.notification.request.content.userInfo[ReminderService.deepLinkKey] as? String
        let callback = onOpen
        if let link, let url = URL(string: link) {
            Task { @MainActor in
                callback?(url)
            }
        }
        completionHandler()
    }
}
