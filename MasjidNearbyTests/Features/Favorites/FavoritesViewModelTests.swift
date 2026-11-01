import Foundation
import SwiftData
import Testing
@testable import MasjidNearby

@MainActor
struct FavoritesViewModelTests {
    @Test func loadsFromTheDeviceWithoutTheNetwork() async {
        let store = InMemoryOfflineStore()
        await store.saveFavorite(OfflineFixtures.masjid("a"), at: OfflineFixtures.noon)
        await store.replaceSchedule([Fixtures.times(on: "2026-10-21", fajrIqamah: "06:15", source: .manual)],
                                    masjidID: "a", syncedAt: OfflineFixtures.noon)
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
        #expect(items.first?.lastSyncedAt == OfflineFixtures.noon)
        #expect(viewModel.upcoming(for: items[0], at: OfflineFixtures.noon)?.prayer == .dhuhr)
    }

    @Test func favoriteWithoutSavedTimesShowsCalculatedTimes() async {
        let store = InMemoryOfflineStore()
        await store.saveFavorite(OfflineFixtures.masjid("a"), at: OfflineFixtures.noon)
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
        await store.saveFavorite(OfflineFixtures.masjid("a", name: "Al-Noor"), at: OfflineFixtures.noon)
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
        await store.saveFavorite(OfflineFixtures.masjid("a"), at: OfflineFixtures.noon)
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
        let fixedNow = OfflineFixtures.noon
        return FavoritesViewModel(
            sync: FavoritesSync(repository: repository, store: store),
            calculator: MockPrayerTimeCalculator(result: .success(Fixtures.times(on: "2026-10-21"))),
            now: { fixedNow }
        )
    }
}
