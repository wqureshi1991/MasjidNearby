import Foundation
import SwiftData
import Testing
@testable import MasjidNearby

/// 2026-10-21 12:00 in California.
private let noon = Fixtures.day("2026-10-21").startOfDayUTC.addingTimeInterval(19 * 3_600)

/// Both stores must behave the same, so every contract test runs against each.
private func makeStores() throws -> [any OfflineStore] {
    let container = try ModelContainer(
        for: FavoriteMasjidRecord.self, CachedScheduleDayRecord.self,
        configurations: ModelConfiguration(isStoredInMemoryOnly: true)
    )
    return [InMemoryOfflineStore(), SwiftDataOfflineStore(modelContainer: container)]
}

private func masjid(_ id: String, name: String = "Masjid") -> Masjid {
    let base = Fixtures.masjid(id: id, isVerified: true)
    return Masjid(id: id, name: name, address: base.address, coordinates: base.coordinates,
                  timeZoneIdentifier: base.timeZoneIdentifier, calculation: base.calculation,
                  jumuah: base.jumuah, isVerified: true)
}

struct OfflineStoreTests {
    @Test func savesAndListsFavoritesOldestFirst() async throws {
        for store in try makeStores() {
            try await store.saveFavorite(masjid("b"), at: noon.addingTimeInterval(60))
            try await store.saveFavorite(masjid("a"), at: noon)

            let favorites = try await store.favorites()
            #expect(favorites.map(\.id) == ["a", "b"], "\(type(of: store))")
            #expect(favorites.first?.masjid == masjid("a"), "\(type(of: store))")
            #expect(try await store.isFavorite(masjidID: "a"), "\(type(of: store))")
            #expect(try await !store.isFavorite(masjidID: "zzz"), "\(type(of: store))")
        }
    }

    @Test func savingAgainUpdatesDetailsAndKeepsAddedDate() async throws {
        for store in try makeStores() {
            try await store.saveFavorite(masjid("a", name: "Old Name"), at: noon)
            try await store.saveFavorite(masjid("a", name: "New Name"), at: noon.addingTimeInterval(3_600))

            let favorites = try await store.favorites()
            #expect(favorites.count == 1, "\(type(of: store))")
            #expect(favorites.first?.masjid.name == "New Name", "\(type(of: store))")
            #expect(favorites.first?.addedAt == noon, "\(type(of: store))")
        }
    }

    @Test func replacingAScheduleDropsOldDaysAndRecordsTheSync() async throws {
        var published = Fixtures.times(on: "2026-10-21", fajrIqamah: "06:15", source: .manual)
        published.updatedAt = noon.addingTimeInterval(-86_400)

        for store in try makeStores() {
            try await store.saveFavorite(masjid("a"), at: noon)
            try await store.replaceSchedule([Fixtures.times(on: "2026-10-01", source: .manual)],
                                            masjidID: "a", syncedAt: noon.addingTimeInterval(-3_600))
            try await store.replaceSchedule([Fixtures.times(on: "2026-10-22", source: .manual), published],
                                            masjidID: "a", syncedAt: noon)

            let all = try await store.cachedSchedule(masjidID: "a",
                                                     from: Fixtures.day("2026-09-01"),
                                                     through: Fixtures.day("2026-12-31"))
            #expect(all.map(\.day.key) == ["2026-10-21", "2026-10-22"], "\(type(of: store))")
            #expect(all.first == published, "\(type(of: store))")

            let today = try await store.cachedSchedule(masjidID: "a",
                                                       from: Fixtures.day("2026-10-21"),
                                                       through: Fixtures.day("2026-10-21"))
            #expect(today.count == 1, "\(type(of: store))")
            #expect(try await store.favorites().first?.lastSyncedAt == noon, "\(type(of: store))")
        }
    }

    @Test func removingAFavoriteClearsItsCache() async throws {
        for store in try makeStores() {
            try await store.saveFavorite(masjid("a"), at: noon)
            try await store.saveFavorite(masjid("b"), at: noon)
            try await store.replaceSchedule([Fixtures.times(on: "2026-10-21", source: .manual)],
                                            masjidID: "a", syncedAt: noon)
            try await store.replaceSchedule([Fixtures.times(on: "2026-10-21", source: .manual)],
                                            masjidID: "b", syncedAt: noon)

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

struct FavoritesSyncTests {
    @Test func windowRunsFromYesterdayForThirtyDays() {
        let window = FavoritesSync.window(for: masjid("a"), now: noon)
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
        await store.saveFavorite(masjid("a"), at: noon)
        let sync = FavoritesSync(repository: repository, store: store)

        try await sync.refresh(masjid("a"), now: noon)

        let cached = await store.cachedSchedule(masjidID: "a", from: Fixtures.day("2026-01-01"),
                                                through: Fixtures.day("2026-12-31"))
        #expect(cached.map(\.day.key) == ["2026-10-21"])
        #expect(await store.favorites().first?.lastSyncedAt == noon)
    }

    @Test func failedRefreshKeepsTheOldCache() async throws {
        let repository = MockMasjidRepository()
        let store = InMemoryOfflineStore()
        await store.saveFavorite(masjid("a"), at: noon)
        await store.replaceSchedule([Fixtures.times(on: "2026-10-21", source: .manual)], masjidID: "a", syncedAt: noon)
        await repository.failNextCall(with: .network)
        let sync = FavoritesSync(repository: repository, store: store)

        await #expect(throws: RepositoryError.network) {
            try await sync.refresh(masjid("a"), now: noon.addingTimeInterval(3_600))
        }
        #expect(await store.cachedSchedule(masjidID: "a", from: Fixtures.day("2026-10-21"),
                                           through: Fixtures.day("2026-10-21")).count == 1)
        #expect(await store.favorites().first?.lastSyncedAt == noon)
    }

    @Test func refreshAllReportsFailures() async throws {
        let repository = MockMasjidRepository()
        let store = InMemoryOfflineStore()
        await store.saveFavorite(masjid("a", name: "First"), at: noon)
        await store.saveFavorite(masjid("b", name: "Second"), at: noon.addingTimeInterval(1))
        await repository.failNextCall(with: .network)
        let sync = FavoritesSync(repository: repository, store: store)

        let failed = try await sync.refreshAll(now: noon)

        #expect(failed == ["First"])
    }
}

@MainActor
struct FavoritesViewModelTests {
    @Test func loadsFromTheDeviceWithoutTheNetwork() async {
        let store = InMemoryOfflineStore()
        await store.saveFavorite(masjid("a"), at: noon)
        await store.replaceSchedule([Fixtures.times(on: "2026-10-21", fajrIqamah: "06:15", source: .manual)],
                                    masjidID: "a", syncedAt: noon)
        let repository = MockMasjidRepository()
        await repository.failNextCall(with: .network)
        let viewModel = makeViewModel(repository: repository, store: store)

        await viewModel.load()

        guard case .loaded(let items) = viewModel.state else {
            Issue.record("Expected favorites")
            return
        }
        #expect(items.map(\.id) == ["a"])
        #expect(items.first?.today?.source == .manual)
        #expect(items.first?.lastSyncedAt == noon)
        #expect(viewModel.upcoming(for: items[0], at: noon)?.prayer == .dhuhr)
    }

    @Test func favoriteWithoutSavedTimesShowsCalculatedTimes() async {
        let store = InMemoryOfflineStore()
        await store.saveFavorite(masjid("a"), at: noon)
        let viewModel = makeViewModel(store: store)

        await viewModel.load()

        guard case .loaded(let items) = viewModel.state else {
            Issue.record("Expected favorites")
            return
        }
        #expect(items.first?.today?.source == .calculated)
    }

    @Test func refreshFailureKeepsSavedTimesAndExplains() async {
        let store = InMemoryOfflineStore()
        await store.saveFavorite(masjid("a", name: "Al-Noor"), at: noon)
        let repository = MockMasjidRepository()
        await repository.failNextCall(with: .network)
        let viewModel = makeViewModel(repository: repository, store: store)

        await viewModel.refresh()

        #expect(viewModel.refreshMessage?.contains("Al-Noor") == true)
        #expect(viewModel.state.isLoaded)
        #expect(!viewModel.isRefreshing)
    }

    @Test func removesAFavorite() async {
        let store = InMemoryOfflineStore()
        await store.saveFavorite(masjid("a"), at: noon)
        let viewModel = makeViewModel(store: store)
        await viewModel.load()
        guard case .loaded(let items) = viewModel.state, let first = items.first else {
            Issue.record("Expected favorites")
            return
        }

        await viewModel.remove(first)

        guard case .loaded(let remaining) = viewModel.state else {
            Issue.record("Expected favorites")
            return
        }
        #expect(remaining.isEmpty)
        #expect(await store.favorites().isEmpty)
    }

    private func makeViewModel(repository: MockMasjidRepository = MockMasjidRepository(),
                               store: InMemoryOfflineStore) -> FavoritesViewModel {
        let fixedNow = noon
        return FavoritesViewModel(
            sync: FavoritesSync(repository: repository, store: store),
            calculator: MockPrayerTimeCalculator(result: .success(Fixtures.times(on: "2026-10-21"))),
            now: { fixedNow }
        )
    }
}

@MainActor
struct MasjidDetailFavoritesTests {
    @Test func starringSavesTheMasjidAndItsSchedule() async {
        let store = InMemoryOfflineStore()
        let repository = MockMasjidRepository(published: ["m1": [Fixtures.times(on: "2026-10-21", source: .manual)]])
        let viewModel = makeViewModel(repository: repository, store: store)
        var changes = 0
        viewModel.onFavoritesChanged = { changes += 1 }
        await viewModel.load()
        #expect(!viewModel.isFavorite)

        await viewModel.toggleFavorite()

        #expect(viewModel.isFavorite)
        #expect(changes == 1)
        #expect(await store.isFavorite(masjidID: "m1"))
        #expect(await store.cachedSchedule(masjidID: "m1", from: Fixtures.day("2026-10-21"),
                                           through: Fixtures.day("2026-10-21")).count == 1)

        await viewModel.toggleFavorite()

        #expect(!viewModel.isFavorite)
        #expect(changes == 2)
        #expect(await store.favorites().isEmpty)
    }

    @Test func offlineFavoriteShowsSavedTimes() async {
        let store = InMemoryOfflineStore()
        let repository = MockMasjidRepository(published: ["m1": [
            Fixtures.times(on: "2026-10-21", fajrIqamah: "06:15", source: .manual),
        ]])
        let viewModel = makeViewModel(repository: repository, store: store)
        await viewModel.toggleFavorite()
        await repository.failNextCall(with: .network)

        await viewModel.load()

        #expect(viewModel.schedule?.today.source == .manual)
        #expect(viewModel.schedule?.today.fajr.iqamah == Fixtures.time("06:15"))
        #expect(viewModel.notice?.contains("offline") == true)
    }

    @Test func offlineNonFavoriteFallsBackToCalculated() async {
        let repository = MockMasjidRepository()
        await repository.failNextCall(with: .network)
        let viewModel = makeViewModel(repository: repository, store: InMemoryOfflineStore())

        await viewModel.load()

        #expect(viewModel.isTodayCalculated)
        #expect(viewModel.notice?.contains("calculated") == true)
    }

    @Test func publishedTimesSayWhenTheyWereUpdated() async {
        var published = Fixtures.times(on: "2026-10-21", source: .manual)
        published.updatedAt = noon.addingTimeInterval(-2 * 86_400)
        let viewModel = makeViewModel(repository: MockMasjidRepository(published: ["m1": [published]]),
                                      store: InMemoryOfflineStore())

        await viewModel.load()

        #expect(viewModel.lastUpdatedText?.hasPrefix("Updated by the masjid") == true)
    }

    @Test func calculatedTimesHaveNoUpdatedText() async {
        let viewModel = makeViewModel(repository: MockMasjidRepository(), store: InMemoryOfflineStore())
        await viewModel.load()
        #expect(viewModel.lastUpdatedText == nil)
    }

    private func makeViewModel(repository: MockMasjidRepository, store: InMemoryOfflineStore) -> MasjidDetailViewModel {
        let fixedNow = noon
        return MasjidDetailViewModel(
            masjid: Fixtures.masjid(isVerified: true),
            distanceMeters: nil,
            repository: repository,
            calculator: MockPrayerTimeCalculator(result: .success(Fixtures.times(on: "2026-10-21"))),
            favorites: FavoritesSync(repository: repository, store: store),
            now: { fixedNow }
        )
    }
}

@MainActor
struct UserCoordinatorFavoritesTests {
    @Test func selectingAFavoriteOpensItInTheFavoritesTab() async {
        let store = InMemoryOfflineStore()
        await store.saveFavorite(masjid("a"), at: noon)
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

        #expect(coordinator.favoritesPath == [.masjidDetail(masjid("a"), distanceMeters: nil)])
        #expect(coordinator.path.isEmpty)
    }
}
