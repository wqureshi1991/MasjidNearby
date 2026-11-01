import Foundation
import Observation

@MainActor
@Observable
final class UserCoordinator {
    enum Tab: Hashable {
        case nearby
        case favorites
    }

    enum Route: Hashable {
        case masjidDetail(Masjid, distanceMeters: Double?)
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
    private let onSignOut: @MainActor () async -> Void

    init(session: AuthSession, dependencies: AppDependencies, onSignOut: @escaping @MainActor () async -> Void) {
        self.session = session
        self.dependencies = dependencies
        self.onSignOut = onSignOut
        let sync = FavoritesSync(repository: dependencies.masjidRepository, store: dependencies.offlineStore)
        favoritesSync = sync
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
            }
        }
        return viewModel
    }
}
