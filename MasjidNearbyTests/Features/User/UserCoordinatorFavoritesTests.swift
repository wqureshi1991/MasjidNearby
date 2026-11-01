import Foundation
import SwiftData
import Testing
@testable import MasjidNearby

@MainActor
struct UserCoordinatorFavoritesTests {
    @Test func selectingAFavoriteOpensItInTheFavoritesTab() async {
        let store = InMemoryOfflineStore()
        await store.saveFavorite(OfflineFixtures.masjid("a"), at: OfflineFixtures.noon)
        let coordinator = UserCoordinator(
            session: AuthSession(userID: "u1", role: .user),
            dependencies: AppDependencies(authService: MockAuthService(), offlineStore: store),
            onSignOut: {}
        )
        await coordinator.favorites.load()
        guard case .loaded(let items) = coordinator.favorites.state, let first = items.first else {
            Issue.record("Expected favorites")
            return
        }

        coordinator.favorites.select(first)

        #expect(coordinator.favoritesPath == [.masjidDetail(OfflineFixtures.masjid("a"), distanceMeters: nil)])
        #expect(coordinator.path.isEmpty)
    }
}
