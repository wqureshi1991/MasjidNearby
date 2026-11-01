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
