import Foundation
import Testing
@testable import MasjidNearby

@MainActor
struct AlertTapTests {
    private func makeCoordinator(favorites: [Masjid], alertTaps: AlertTapRouter) async throws -> UserCoordinator {
        let dependencies = AppDependencies(authService: MockAuthService(),
                                           offlineStore: try await AlertFixtures.store(with: favorites))
        return UserCoordinator(session: AuthSession(userID: "u1", role: .user, isGuest: true),
                               dependencies: dependencies, alertTaps: alertTaps, onSignOut: {})
    }

    @Test func tappingAnAlertOpensItsMasjidOnFavorites() async throws {
        let masjid = Fixtures.masjid(id: "m1", isVerified: true)
        let alertTaps = AlertTapRouter()
        let coordinator = try await makeCoordinator(favorites: [masjid], alertTaps: alertTaps)

        alertTaps.alertTapped(masjidID: "m1")
        await coordinator.openPendingAlert()

        #expect(coordinator.selectedTab == .favorites)
        #expect(coordinator.favoritesPath == [.masjidDetail(masjid, distanceMeters: nil)])
        #expect(alertTaps.pendingMasjidID == nil)
    }

    @Test func aTapBeforeTheFlowExistsIsHeldForIt() async throws {
        let masjid = Fixtures.masjid(id: "m1", isVerified: true)
        let alertTaps = AlertTapRouter()
        alertTaps.alertTapped(masjidID: "m1")

        let coordinator = try await makeCoordinator(favorites: [masjid], alertTaps: alertTaps)
        await coordinator.openPendingAlert()

        #expect(coordinator.favoritesPath == [.masjidDetail(masjid, distanceMeters: nil)])
    }

    @Test func aMasjidNoLongerInFavoritesIsIgnored() async throws {
        let alertTaps = AlertTapRouter()
        let coordinator = try await makeCoordinator(favorites: [], alertTaps: alertTaps)

        alertTaps.alertTapped(masjidID: "gone")
        await coordinator.openPendingAlert()

        #expect(coordinator.selectedTab == .nearby)
        #expect(coordinator.favoritesPath.isEmpty)
        #expect(alertTaps.pendingMasjidID == nil)
    }
}
