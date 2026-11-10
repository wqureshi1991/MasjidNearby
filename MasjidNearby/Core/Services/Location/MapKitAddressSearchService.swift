import Foundation
import MapKit

/// Address search with MapKit. Hands back only a `Sendable` coordinate.
struct MapKitAddressSearchService: AddressSearchService {
    func coordinates(for address: String) async throws -> Coordinates? {
        let query = address.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !query.isEmpty else { return nil }

        let request = MKLocalSearch.Request()
        request.naturalLanguageQuery = query
        let response: MKLocalSearch.Response
        do {
            response = try await MKLocalSearch(request: request).start()
        } catch let error as MKError where error.code == .placemarkNotFound {
            return nil
        } catch {
            throw RepositoryError.unknown(error.localizedDescription)
        }
        guard let coordinate = response.mapItems.first?.location.coordinate else { return nil }
        return Coordinates(latitude: coordinate.latitude, longitude: coordinate.longitude)
    }
}
