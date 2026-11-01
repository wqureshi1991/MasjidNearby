import Foundation
import SwiftData
import Testing
@testable import MasjidNearby

struct OfflineStoreTests {
    @Test func savesAndListsFavoritesOldestFirst() async throws {
        for store in try OfflineFixtures.makeStores() {
            try await store.saveFavorite(OfflineFixtures.masjid("b"), at: OfflineFixtures.noon.addingTimeInterval(60))
            try await store.saveFavorite(OfflineFixtures.masjid("a"), at: OfflineFixtures.noon)

            let favorites = try await store.favorites()
            #expect(favorites.map(\.id) == ["a", "b"], "\(type(of: store))")
            #expect(favorites.first?.masjid == OfflineFixtures.masjid("a"), "\(type(of: store))")
            #expect(try await store.isFavorite(masjidID: "a"), "\(type(of: store))")
            #expect(try await !store.isFavorite(masjidID: "zzz"), "\(type(of: store))")
        }
    }

    @Test func savingAgainUpdatesDetailsAndKeepsAddedDate() async throws {
        for store in try OfflineFixtures.makeStores() {
            try await store.saveFavorite(OfflineFixtures.masjid("a", name: "Old Name"), at: OfflineFixtures.noon)
            try await store.saveFavorite(OfflineFixtures.masjid("a", name: "New Name"), at: OfflineFixtures.noon.addingTimeInterval(3_600))

            let favorites = try await store.favorites()
            #expect(favorites.count == 1, "\(type(of: store))")
            #expect(favorites.first?.masjid.name == "New Name", "\(type(of: store))")
            #expect(favorites.first?.addedAt == OfflineFixtures.noon, "\(type(of: store))")
        }
    }

    @Test func replacingAScheduleDropsOldDaysAndRecordsTheSync() async throws {
        var published = Fixtures.times(on: "2026-10-21", fajrIqamah: "06:15", source: .manual)
        published.updatedAt = OfflineFixtures.noon.addingTimeInterval(-86_400)

        for store in try OfflineFixtures.makeStores() {
            try await store.saveFavorite(OfflineFixtures.masjid("a"), at: OfflineFixtures.noon)
            try await store.replaceSchedule([Fixtures.times(on: "2026-10-01", source: .manual)],
                                            masjidID: "a", syncedAt: OfflineFixtures.noon.addingTimeInterval(-3_600))
            try await store.replaceSchedule([Fixtures.times(on: "2026-10-22", source: .manual), published],
                                            masjidID: "a", syncedAt: OfflineFixtures.noon)

            let all = try await store.cachedSchedule(masjidID: "a",
                                                     from: Fixtures.day("2026-09-01"),
                                                     through: Fixtures.day("2026-12-31"))
            #expect(all.map(\.day.key) == ["2026-10-21", "2026-10-22"], "\(type(of: store))")
            #expect(all.first == published, "\(type(of: store))")

            let today = try await store.cachedSchedule(masjidID: "a",
                                                       from: Fixtures.day("2026-10-21"),
                                                       through: Fixtures.day("2026-10-21"))
            #expect(today.count == 1, "\(type(of: store))")
            #expect(try await store.favorites().first?.lastSyncedAt == OfflineFixtures.noon, "\(type(of: store))")
        }
    }

    @Test func removingAFavoriteClearsItsCache() async throws {
        for store in try OfflineFixtures.makeStores() {
            try await store.saveFavorite(OfflineFixtures.masjid("a"), at: OfflineFixtures.noon)
            try await store.saveFavorite(OfflineFixtures.masjid("b"), at: OfflineFixtures.noon)
            try await store.replaceSchedule([Fixtures.times(on: "2026-10-21", source: .manual)],
                                            masjidID: "a", syncedAt: OfflineFixtures.noon)
            try await store.replaceSchedule([Fixtures.times(on: "2026-10-21", source: .manual)],
                                            masjidID: "b", syncedAt: OfflineFixtures.noon)

            try await store.removeFavorite(masjidID: "a")

            let range = (Fixtures.day("2026-10-01"), Fixtures.day("2026-10-31"))
            #expect(try await store.favorites().map(\.id) == ["b"], "\(type(of: store))")
            #expect(try await store.cachedSchedule(masjidID: "a", from: range.0, through: range.1).isEmpty,
                    "\(type(of: store))")
            #expect(try await store.cachedSchedule(masjidID: "b", from: range.0, through: range.1).count == 1,
                    "\(type(of: store))")
        }
    }
}
