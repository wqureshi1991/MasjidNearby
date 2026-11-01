import Foundation
import SwiftData
import Testing
@testable import MasjidNearby

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
        published.updatedAt = OfflineFixtures.noon.addingTimeInterval(-2 * 86_400)
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
        let fixedNow = OfflineFixtures.noon
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
