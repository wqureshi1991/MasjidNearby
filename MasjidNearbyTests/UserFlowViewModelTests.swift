import Foundation
import Testing
@testable import MasjidNearby

@MainActor
struct NearbyMasjidsViewModelTests {
    /// The Simulator's default location, Apple Park in Cupertino.
    private let applePark = Coordinates(latitude: 37.3349, longitude: -122.0090)

    @Test func listsVerifiedMasjidsNearestFirst() async {
        let viewModel = makeViewModel()

        await viewModel.loadNearCurrentLocation()

        guard case .loaded(let items) = viewModel.state else {
            Issue.record("Expected results, got \(viewModel.state)")
            return
        }
        #expect(items.map(\.id) == ["sample-santa-clara", "sample-downtown", "sample-milpitas"])
        #expect(abs((items.first?.distanceMeters ?? 0) - 5_210) < 100)
        #expect(viewModel.originDescription == "Near you")
    }

    @Test func excludesUnverifiedAndFarAwayMasjids() async {
        let unverifiedNearby = Fixtures.masjid(id: "pending", isVerified: false)
        let farAway = Masjid(
            id: "sf", name: "Far", address: "San Francisco",
            coordinates: Coordinates(latitude: 37.7749, longitude: -122.4194),
            timeZoneIdentifier: "America/Los_Angeles", calculation: CalculationParameters(method: .isna),
            jumuah: [], isVerified: true
        )
        let viewModel = makeViewModel(repository: MockMasjidRepository(masjids: [unverifiedNearby, farAway]))

        await viewModel.loadNearCurrentLocation()

        guard case .loaded(let items) = viewModel.state else {
            Issue.record("Expected results")
            return
        }
        #expect(items.isEmpty)
    }

    @Test func deniedLocationOffersSearchInstead() async {
        let viewModel = makeViewModel(location: MockLocationService(result: .failure(.denied)))

        await viewModel.loadNearCurrentLocation()

        #expect(viewModel.isLocationDenied)
        #expect(!viewModel.state.isLoading)
        #expect(viewModel.state.error == nil)
    }

    @Test func searchesAroundATypedPlace() async {
        let milpitas = Coordinates(latitude: 37.4323, longitude: -121.8996)
        let viewModel = makeViewModel(search: MockAddressSearchService(results: ["Milpitas": milpitas]))
        viewModel.searchText = " Milpitas "

        await viewModel.searchPlace()

        guard case .loaded(let items) = viewModel.state else {
            Issue.record("Expected results")
            return
        }
        #expect(items.first?.id == "sample-milpitas")
        #expect(viewModel.originDescription == "Near Milpitas")
    }

    @Test func unknownPlaceShowsAnError() async {
        let viewModel = makeViewModel()
        viewModel.searchText = "Atlantis"

        await viewModel.searchPlace()

        #expect(viewModel.state.error as? NearbyMasjidsViewModel.SearchError == .placeNotFound("Atlantis"))
    }

    @Test func repositoryFailureShowsAnError() async {
        let repository = DemoData.repository()
        await repository.failNextCall(with: .network)
        let viewModel = makeViewModel(repository: repository)

        await viewModel.loadNearCurrentLocation()

        #expect(viewModel.state.error as? RepositoryError == .network)
    }

    @Test func loadsAutomaticallyOnlyOnce() async {
        let viewModel = makeViewModel()
        await viewModel.loadIfNeeded()
        viewModel.searchText = "ignored"
        await viewModel.loadIfNeeded()

        #expect(viewModel.originDescription == "Near you")
    }

    @Test func selectingForwardsTheItem() async {
        var selected: NearbyMasjidsViewModel.Item?
        let viewModel = makeViewModel()
        viewModel.onSelect = { selected = $0 }
        await viewModel.loadNearCurrentLocation()

        guard case .loaded(let items) = viewModel.state, let first = items.first else {
            Issue.record("Expected results")
            return
        }
        viewModel.select(first)

        #expect(selected == first)
    }

    private func makeViewModel(repository: MockMasjidRepository = DemoData.repository(),
                               location: MockLocationService? = nil,
                               search: MockAddressSearchService = MockAddressSearchService()) -> NearbyMasjidsViewModel {
        NearbyMasjidsViewModel(
            repository: repository,
            locationService: location ?? MockLocationService(result: .success(applePark)),
            addressSearch: search
        )
    }
}

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
