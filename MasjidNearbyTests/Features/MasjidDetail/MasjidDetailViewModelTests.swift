import Foundation
import Testing
@testable import MasjidNearby

@MainActor
struct MasjidDetailViewModelTests {
    /// 2026-10-21 12:00 in California.
    private let noon = Fixtures.day("2026-10-21").startOfDayUTC.addingTimeInterval(19 * 3_600)

    @Test func showsPublishedTimesWhenTheMasjidHasThem() async {
        let repository = MockMasjidRepository(
            masjids: [Fixtures.masjid(isVerified: true)],
            published: ["m1": [Fixtures.times(on: "2026-10-21", fajrIqamah: "06:15", source: .manual)]]
        )
        let viewModel = makeViewModel(repository: repository)

        await viewModel.load()

        #expect(viewModel.schedule?.today.source == .manual)
        #expect(!viewModel.isTodayCalculated)
        #expect(viewModel.notice == nil)
    }

    @Test func fallsBackToCalculatedTimes() async {
        let viewModel = makeViewModel(repository: MockMasjidRepository())

        await viewModel.load()

        #expect(viewModel.isTodayCalculated)
        #expect(viewModel.schedule?.tomorrow != nil)
    }

    @Test func repositoryFailureShowsCalculatedTimesWithANotice() async {
        let repository = MockMasjidRepository()
        await repository.failNextCall(with: .network)
        let viewModel = makeViewModel(repository: repository)

        await viewModel.load()

        #expect(viewModel.isTodayCalculated)
        #expect(viewModel.notice != nil)
    }

    @Test func calculationFailureShowsAnError() async {
        let fixedNow = noon
        let viewModel = MasjidDetailViewModel(
            masjid: Fixtures.masjid(isVerified: true),
            distanceMeters: nil,
            repository: MockMasjidRepository(),
            calculator: MockPrayerTimeCalculator(result: .failure(.sunDoesNotRiseOrSet)),
            now: { fixedNow }
        )

        await viewModel.load()

        #expect(viewModel.state.error as? PrayerCalculationError == .sunDoesNotRiseOrSet)
    }

    @Test func nextPrayerAtNoonIsDhuhr() async {
        let viewModel = makeViewModel(repository: MockMasjidRepository())
        await viewModel.load()

        #expect(viewModel.upcoming(at: noon)?.prayer == .dhuhr)
    }

    @Test func directionsOpenAppleMapsAtTheMasjid() throws {
        let viewModel = makeViewModel(repository: MockMasjidRepository())
        let url = try #require(viewModel.directionsURL)
        let items = URLComponents(url: url, resolvingAgainstBaseURL: false)?.queryItems ?? []

        #expect(url.host == "maps.apple.com")
        #expect(items.contains(URLQueryItem(name: "daddr", value: "37.3382,-121.8863")))
    }

    @Test func formatsDistance() {
        let viewModel = MasjidDetailViewModel(masjid: Fixtures.masjid(), distanceMeters: 5_210,
                                              repository: MockMasjidRepository(),
                                              calculator: AstronomicalPrayerTimeCalculator())
        #expect(viewModel.formattedDistance != nil)
    }

    private func makeViewModel(repository: MockMasjidRepository) -> MasjidDetailViewModel {
        let fixedNow = noon
        return MasjidDetailViewModel(
            masjid: Fixtures.masjid(isVerified: true),
            distanceMeters: 1_200,
            repository: repository,
            calculator: MockPrayerTimeCalculator(result: .success(Fixtures.times(on: "2026-10-21"))),
            now: { fixedNow }
        )
    }
}
