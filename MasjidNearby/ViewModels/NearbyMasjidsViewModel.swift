import Foundation
import Observation

/// Finds verified masjids near the user, or near a place they search for.
@MainActor
@Observable
final class NearbyMasjidsViewModel {
    struct Item: Identifiable, Hashable, Sendable {
        let masjid: Masjid
        let distanceMeters: Double
        var id: String { masjid.id }
    }

    enum DisplayMode: Hashable {
        case list
        case map
    }

    enum SearchError: Error, LocalizedError, Equatable {
        case placeNotFound(String)

        var errorDescription: String? {
            switch self {
            case .placeNotFound(let query):
                "Couldn't find \"\(query)\". Try a city name or a full address."
            }
        }
    }

    static let searchRadiusMeters = 25_000.0

    private(set) var state: LoadState<[Item]> = .idle
    /// Where the current results are measured from, e.g. "Near you".
    private(set) var originDescription: String? = nil
    private(set) var isLocationDenied = false
    var searchText = ""
    var displayMode: DisplayMode = .list

    @ObservationIgnored var onSelect: (@MainActor (Item) -> Void)?
    @ObservationIgnored private var hasLoadedOnce = false

    private let repository: any MasjidRepository
    private let locationService: any LocationService
    private let addressSearch: any AddressSearchService

    init(repository: any MasjidRepository,
         locationService: any LocationService,
         addressSearch: any AddressSearchService) {
        self.repository = repository
        self.locationService = locationService
        self.addressSearch = addressSearch
    }

    /// First appearance: look near the user's location once.
    func loadIfNeeded() async {
        guard !hasLoadedOnce else { return }
        hasLoadedOnce = true
        await loadNearCurrentLocation()
    }

    func loadNearCurrentLocation() async {
        guard !state.isLoading else { return }
        state = .loading
        do {
            let coordinates = try await locationService.currentCoordinates()
            isLocationDenied = false
            await search(around: coordinates, description: "Near you")
        } catch LocationError.denied {
            isLocationDenied = true
            state = .idle
        } catch {
            state = .failed(error)
        }
    }

    func searchPlace() async {
        let query = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !query.isEmpty, !state.isLoading else { return }
        state = .loading
        do {
            guard let coordinates = try await addressSearch.coordinates(for: query) else {
                state = .failed(SearchError.placeNotFound(query))
                return
            }
            await search(around: coordinates, description: "Near \(query)")
        } catch {
            state = .failed(error)
        }
    }

    func select(_ item: Item) {
        onSelect?(item)
    }

    private func search(around center: Coordinates, description: String) async {
        do {
            let masjids = try await repository.verifiedMasjids(near: center, radiusMeters: Self.searchRadiusMeters)
            let items = masjids
                .map { Item(masjid: $0, distanceMeters: $0.coordinates.distance(to: center)) }
                .sorted { $0.distanceMeters < $1.distanceMeters }
            originDescription = description
            state = .loaded(items)
        } catch {
            state = .failed(error)
        }
    }
}
