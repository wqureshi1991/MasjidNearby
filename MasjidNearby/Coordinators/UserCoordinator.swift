import Foundation
import Observation

@MainActor
@Observable
final class UserCoordinator {
    enum Route: Hashable {
        case masjidDetail(Masjid, distanceMeters: Double?)
    }

    var path: [Route] = []
    let session: AuthSession
    /// The root screen's ViewModel, kept for the life of the flow so results survive navigation.
    let nearby: NearbyMasjidsViewModel

    private let dependencies: AppDependencies
    private let onSignOut: @MainActor () async -> Void

    init(session: AuthSession, dependencies: AppDependencies, onSignOut: @escaping @MainActor () async -> Void) {
        self.session = session
        self.dependencies = dependencies
        self.onSignOut = onSignOut
        nearby = NearbyMasjidsViewModel(
            repository: dependencies.masjidRepository,
            locationService: dependencies.locationService,
            addressSearch: dependencies.addressSearch
        )
        nearby.onSelect = { [weak self] item in
            self?.path.append(.masjidDetail(item.masjid, distanceMeters: item.distanceMeters))
        }
    }

    func signOut() async {
        await onSignOut()
    }

    func makeDetailViewModel(masjid: Masjid, distanceMeters: Double?) -> MasjidDetailViewModel {
        MasjidDetailViewModel(
            masjid: masjid,
            distanceMeters: distanceMeters,
            repository: dependencies.masjidRepository,
            calculator: dependencies.prayerTimeCalculator
        )
    }
}
