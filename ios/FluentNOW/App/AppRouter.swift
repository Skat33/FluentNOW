import SwiftUI
import Observation

/// Arkusze prezentowane globalnie nad kartami.
enum AppSheet: Identifiable, Hashable {
    /// Szybkie dodawanie słowa (opcjonalnie z wypełnionym polem).
    case quickAdd(prefill: String?)

    var id: String {
        switch self {
        case .quickAdd: return "quickAdd"
        }
    }
}

/// Stan nawigacji aplikacji: wybrana karta, stos `NavigationPath` każdej karty, arkusz globalny
/// i „prośby” do ekranów (start sesji, cel w Słowniku), które ekran konsumuje po odczycie.
///
/// Wstrzykiwany do środowiska: `.environment(router)`; odczyt: `@Environment(AppRouter.self) var router`.
/// Ekrany dodają własne trasy (typy `Hashable`) do ścieżki swojej karty, np.
/// `router.push(WordRoute.detail(id), on: .words)` + `.navigationDestination(for: WordRoute.self)`.
@MainActor
@Observable
final class AppRouter {
    var selectedTab: AppTab = .today
    var librarySection: LibrarySection = .words

    var todayPath = NavigationPath()
    var wordsPath = NavigationPath()
    var studyPath = NavigationPath()
    var progressPath = NavigationPath()
    var settingsPath = NavigationPath()

    /// Arkusz nad całą aplikacją (np. szybkie dodawanie).
    var activeSheet: AppSheet?

    /// Prośba o start/wznowienie sesji — konsumuje ekran Nauka (`consumeStudyLaunch()`).
    private(set) var pendingStudyLaunch: StudyLaunchRequest?
    /// Cel w Słowniku z deep linku — konsumuje ekran Słownika (`consumeLibraryDestination()`).
    private(set) var pendingLibraryDestination: LibraryDestination?

    init(selectedTab: AppTab = .today) {
        self.selectedTab = selectedTab
    }

    // MARK: Karty i ścieżki

    /// Programowy wybór karty. Ponowny wybór aktywnej karty wraca do jej korzenia
    /// (dotknięcie aktywnej karty na pasku robi to samo systemowo).
    func select(_ tab: AppTab) {
        if tab == selectedTab {
            popToRoot(tab)
        } else {
            selectedTab = tab
        }
    }

    func path(for tab: AppTab) -> NavigationPath {
        switch tab {
        case .today: return todayPath
        case .words: return wordsPath
        case .study: return studyPath
        case .progress: return progressPath
        case .settings: return settingsPath
        }
    }

    func setPath(_ path: NavigationPath, for tab: AppTab) {
        switch tab {
        case .today: todayPath = path
        case .words: wordsPath = path
        case .study: studyPath = path
        case .progress: progressPath = path
        case .settings: settingsPath = path
        }
    }

    /// Dodaje trasę do stosu karty (i przełącza na nią).
    func push<Route: Hashable>(_ route: Route, on tab: AppTab) {
        var path = self.path(for: tab)
        path.append(route)
        setPath(path, for: tab)
        selectedTab = tab
    }

    func popToRoot(_ tab: AppTab) {
        setPath(NavigationPath(), for: tab)
    }

    func pop(on tab: AppTab) {
        var path = self.path(for: tab)
        guard !path.isEmpty else { return }
        path.removeLast()
        setPath(path, for: tab)
    }

    // MARK: Akcje wysokiego poziomu

    /// Przełącza na Naukę i zostawia prośbę o start sesji.
    func startStudy(_ request: StudyLaunchRequest = .daily) {
        activeSheet = nil
        popToRoot(.study)
        pendingStudyLaunch = request
        selectedTab = .study
    }

    /// Zwraca i czyści prośbę o sesję (wywołuje ekran Nauka w `.onChange`/`.task`).
    func consumeStudyLaunch() -> StudyLaunchRequest? {
        let request = pendingStudyLaunch
        pendingStudyLaunch = nil
        return request
    }

    /// Otwiera Słownik na danym segmencie (i opcjonalnie konkretnym celu).
    func openLibrary(_ section: LibrarySection, destination: LibraryDestination? = nil) {
        activeSheet = nil
        librarySection = section
        if destination != nil {
            popToRoot(.words)
        }
        pendingLibraryDestination = destination
        selectedTab = .words
    }

    /// Zwraca i czyści cel w Słowniku.
    func consumeLibraryDestination() -> LibraryDestination? {
        let destination = pendingLibraryDestination
        pendingLibraryDestination = nil
        return destination
    }

    func presentQuickAdd(prefill: String? = nil) {
        activeSheet = .quickAdd(prefill: prefill)
    }

    func dismissSheet() {
        activeSheet = nil
    }

    // MARK: Deep linki

    /// Obsługuje URL `fluentnow://…`. Zwraca `false`, gdy link jest nieznany (ignorowany).
    @discardableResult
    func handle(url: URL) -> Bool {
        guard let link = DeepLink(url: url) else { return false }
        open(link)
        return true
    }

    func open(_ link: DeepLink) {
        switch link {
        case .tab(let tab):
            activeSheet = nil
            selectedTab = tab
        case .library(let section, let destination):
            openLibrary(section, destination: destination)
        case .study(let request):
            startStudy(request)
        case .quickAdd(let prefill):
            presentQuickAdd(prefill: prefill)
        }
    }
}
