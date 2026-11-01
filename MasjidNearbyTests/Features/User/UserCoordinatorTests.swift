import Foundation
import Testing
@testable import MasjidNearby

@MainActor
struct UserCoordinatorTests {
    @Test func selectingAMasjidOpensItsDetail() async {
        let dependencies = AppDependencies(
            authService: MockAuthService(),
            masjidRepository: DemoData.repository(),
            locationService: MockLocationService()
        )
        let coordinator = UserCoordinator(session: AuthSession(userID: "u1", role: .user, isGuest: true),
                                          dependencies: dependencies, onSignOut: {})
        await coordinator.nearby.loadNearCurrentLocation()
        guard case .loaded(let items) = coordinator.nearby.state, let first = items.first else {
            Issue.record("Expected results")
            return
        }

        coordinator.nearby.select(first)

        #expect(coordinator.path == [.masjidDetail(first.masjid, distanceMeters: first.distanceMeters)])
    }
}
