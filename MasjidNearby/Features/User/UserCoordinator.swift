import Foundation
import Observation
import OSLog

@MainActor
@Observable
final class UserCoordinator {
    enum Tab: Hashable {
        case nearby
        case favorites
    }

    enum Route: Hashable {
        case masjidDetail(Masjid, distanceMeters: Double?)
        case prayerAlerts
    }

    var selectedTab: Tab = .nearby
    /// Navigation in the Nearby tab.
    var path: [Route] = []
    var favoritesPath: [Route] = []
    let session: AuthSession
    /// Root ViewModels, kept for the life of the flow so they survive navigation and tab switches.
    let nearby: NearbyMasjidsViewModel
    let favorites: FavoritesViewModel

    private let dependencies: AppDependencies
    private let favoritesSync: FavoritesSync
    private let alertSync: PrayerAlertSync
    private static let logger = Logger(subsystem: "MasjidNearby", category: "PrayerAlerts")
    private let onSignOut: @MainActor () async -> Void

    init(session: AuthSession, dependencies: AppDependencies, onSignOut: @escaping @MainActor () async -> Void) {
        self.session = session
        self.dependencies = dependencies
        self.onSignOut = onSignOut
        let sync = FavoritesSync(repository: dependencies.masjidRepository, store: dependencies.offlineStore)
        favoritesSync = sync
        alertSync = PrayerAlertSync(
            store: dependencies.offlineStore,
            settings: dependencies.alertSettingsStore,
            scheduler: dependencies.notificationScheduler,
            calculator: dependencies.prayerTimeCalculator
        )
        nearby = NearbyMasjidsViewModel(
            repository: dependencies.masjidRepository,
            locationService: dependencies.locationService,
            addressSearch: dependencies.addressSearch
        )
        favorites = FavoritesViewModel(sync: sync, calculator: dependencies.prayerTimeCalculator)
        nearby.onSelect = { [weak self] item in
            self?.path.append(.masjidDetail(item.masjid, distanceMeters: item.distanceMeters))
        }
        favorites.onSelect = { [weak self] masjid in
            self?.favoritesPath.append(.masjidDetail(masjid, distanceMeters: nil))
        }
        favorites.onFavoritesChanged = { [weak self] in
            Task { [weak self] in
                await self?.rescheduleAlerts()
            }
        }
    }

    func signOut() async {
        await onSignOut()
    }

    func makeDetailViewModel(masjid: Masjid, distanceMeters: Double?) -> MasjidDetailViewModel {
        let viewModel = MasjidDetailViewModel(
            masjid: masjid,
            distanceMeters: distanceMeters,
            repository: dependencies.masjidRepository,
            calculator: dependencies.prayerTimeCalculator,
            favorites: favoritesSync
        )
        viewModel.onFavoritesChanged = { [weak self] in
            Task { [weak self] in
                await self?.favorites.load()
                await self?.rescheduleAlerts()
            }
        }
        return viewModel
    }

    // MARK: - Prayer alerts

    func showPrayerAlerts() {
        favoritesPath.append(.prayerAlerts)
    }

    func makePrayerAlertsViewModel() -> PrayerAlertsViewModel {
        PrayerAlertsViewModel(sync: alertSync)
    }

    /// Rebuilds pending alerts from favorites' saved times. Called when the app becomes
    /// active and whenever favorites change, so alerts never run on stale schedules.
    func rescheduleAlerts() async {
        do {
            try await alertSync.reschedule(now: Date())
        } catch {
            Self.logger.error("Couldn't reschedule alerts: \(error.localizedDescription, privacy: .public)")
        }
    }
}
