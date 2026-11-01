import Foundation
import SwiftData
import Testing
@testable import MasjidNearby

struct FavoritesSyncTests {
    @Test func windowRunsFromYesterdayForThirtyDays() {
        let window = FavoritesSync.window(for: OfflineFixtures.masjid("a"), now: OfflineFixtures.noon)
        #expect(window.lowerBound.key == "2026-10-20")
        #expect(window.upperBound.key == "2026-11-19")
    }

    @Test func refreshCachesThePublishedWindow() async throws {
        let repository = MockMasjidRepository(published: ["a": [
            Fixtures.times(on: "2026-10-19", source: .manual),
            Fixtures.times(on: "2026-10-21", source: .manual),
            Fixtures.times(on: "2026-12-25", source: .manual),
        ]])
        let store = InMemoryOfflineStore()
        await store.saveFavorite(OfflineFixtures.masjid("a"), at: OfflineFixtures.noon)
        let sync = FavoritesSync(repository: repository, store: store)

        try await sync.refresh(OfflineFixtures.masjid("a"), now: OfflineFixtures.noon)

        let cached = await store.cachedSchedule(masjidID: "a", from: Fixtures.day("2026-01-01"),
                                                through: Fixtures.day("2026-12-31"))
        #expect(cached.map(\.day.key) == ["2026-10-21"])
        #expect(await store.favorites().first?.lastSyncedAt == OfflineFixtures.noon)
    }

    @Test func failedRefreshKeepsTheOldCache() async throws {
        let repository = MockMasjidRepository()
        let store = InMemoryOfflineStore()
        await store.saveFavorite(OfflineFixtures.masjid("a"), at: OfflineFixtures.noon)
        await store.replaceSchedule([Fixtures.times(on: "2026-10-21", source: .manual)], masjidID: "a", syncedAt: OfflineFixtures.noon)
        await repository.failNextCall(with: .network)
        let sync = FavoritesSync(repository: repository, store: store)

        await #expect(throws: RepositoryError.network) {
            try await sync.refresh(OfflineFixtures.masjid("a"), now: OfflineFixtures.noon.addingTimeInterval(3_600))
        }
        #expect(await store.cachedSchedule(masjidID: "a", from: Fixtures.day("2026-10-21"),
                                           through: Fixtures.day("2026-10-21")).count == 1)
        #expect(await store.favorites().first?.lastSyncedAt == OfflineFixtures.noon)
    }

    @Test func refreshAllReportsFailures() async throws {
        let repository = MockMasjidRepository()
        let store = InMemoryOfflineStore()
        await store.saveFavorite(OfflineFixtures.masjid("a", name: "First"), at: OfflineFixtures.noon)
        await store.saveFavorite(OfflineFixtures.masjid("b", name: "Second"), at: OfflineFixtures.noon.addingTimeInterval(1))
        await repository.failNextCall(with: .network)
        let sync = FavoritesSync(repository: repository, store: store)

        let failed = try await sync.refreshAll(now: OfflineFixtures.noon)

        #expect(failed == ["First"])
    }
}
